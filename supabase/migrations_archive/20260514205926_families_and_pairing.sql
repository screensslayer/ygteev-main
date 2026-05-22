
-- =============================================================================
-- Families / Parent feature (corrected: index predicate uses no now())
-- =============================================================================

alter table public.profiles
  add column if not exists age_verified_at timestamptz;

create table if not exists public.families (
  id          uuid primary key default gen_random_uuid(),
  name        text not null default 'My Family',
  created_by  uuid not null references public.profiles(id) on delete cascade,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);

create table if not exists public.family_members (
  id         uuid primary key default gen_random_uuid(),
  family_id  uuid not null references public.families(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  role       text not null check (role in ('parent','child')),
  joined_at  timestamptz not null default now(),
  unique (family_id, user_id)
);
create index if not exists family_members_user_idx on public.family_members(user_id);

create table if not exists public.family_invites (
  id              uuid primary key default gen_random_uuid(),
  family_id       uuid not null references public.families(id) on delete cascade,
  pairing_code    text not null,
  status          text not null default 'pending'
                  check (status in ('pending','accepted','expired','cancelled')),
  invited_user_id uuid references public.profiles(id) on delete cascade,
  invited_email   text,
  created_by      uuid not null references public.profiles(id) on delete cascade,
  created_at      timestamptz not null default now(),
  expires_at      timestamptz not null default (now() + interval '10 minutes'),
  accepted_by     uuid references public.profiles(id) on delete set null,
  accepted_at     timestamptz
);

-- Unique active code (status='pending'); the create_family_invite RPC sweeps
-- expired-pending rows to 'expired' before inserting so this never blocks.
create unique index if not exists family_invites_pending_code_uniq
  on public.family_invites (pairing_code)
  where status = 'pending';

create index if not exists family_invites_family_idx
  on public.family_invites(family_id, status);

alter table public.families       enable row level security;
alter table public.family_members enable row level security;
alter table public.family_invites enable row level security;

create or replace function public.is_in_family(_family_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.family_members
    where family_id = _family_id and user_id = auth.uid()
  );
$$;
grant execute on function public.is_in_family(uuid) to authenticated;

drop policy if exists "families: members read" on public.families;
create policy "families: members read" on public.families
  for select using (public.is_site_admin(auth.uid()) or public.is_in_family(id));

drop policy if exists "families: parent update" on public.families;
create policy "families: parent update" on public.families
  for update using (
    public.is_site_admin(auth.uid())
    or exists (
      select 1 from public.family_members
      where family_id = families.id and user_id = auth.uid() and role = 'parent'
    )
  );

drop policy if exists "family_members: in-family read" on public.family_members;
create policy "family_members: in-family read" on public.family_members
  for select using (public.is_site_admin(auth.uid()) or public.is_in_family(family_id));

drop policy if exists "family_invites: family read" on public.family_invites;
create policy "family_invites: family read" on public.family_invites
  for select using (
    public.is_site_admin(auth.uid())
    or public.is_in_family(family_id)
    or invited_user_id = auth.uid()
  );


-- start_family ----------------------------------------------------------------
create or replace function public.start_family(_name text default 'My Family')
returns uuid language plpgsql security definer set search_path = public as $func$
declare v_caller uuid := auth.uid(); v_verified timestamptz; v_family_id uuid;
begin
  if v_caller is null then raise exception 'not_authenticated'; end if;
  select age_verified_at into v_verified from public.profiles where id = v_caller;
  if v_verified is null then
    raise exception 'age_verification_required'
      using errcode = '22023',
            hint = 'Pay the $0.99 StoreKit IAP and stamp profiles.age_verified_at first.';
  end if;

  insert into public.families (name, created_by)
    values (coalesce(nullif(trim(_name), ''), 'My Family'), v_caller)
  returning id into v_family_id;

  insert into public.family_members (family_id, user_id, role)
    values (v_family_id, v_caller, 'parent');

  insert into public.user_roles (user_id, role)
    values (v_caller, 'parent'::app_role)
    on conflict do nothing;

  return v_family_id;
end;
$func$;
grant execute on function public.start_family(text) to authenticated;


-- remove_family ---------------------------------------------------------------
create or replace function public.remove_family(_family_id uuid)
returns void language plpgsql security definer set search_path = public as $func$
declare v_caller uuid := auth.uid(); v_still_parent boolean;
begin
  if v_caller is null then raise exception 'not_authenticated'; end if;
  if not exists (
    select 1 from public.family_members
    where family_id = _family_id and user_id = v_caller and role = 'parent'
  ) then raise exception 'forbidden' using errcode = '42501'; end if;

  delete from public.families where id = _family_id;

  select exists (select 1 from public.family_members
                 where user_id = v_caller and role = 'parent') into v_still_parent;
  if not v_still_parent then
    delete from public.user_roles
    where user_id = v_caller and role = 'parent'::app_role;
  end if;
end;
$func$;
grant execute on function public.remove_family(uuid) to authenticated;


-- create_family_invite --------------------------------------------------------
create or replace function public.create_family_invite(
  _family_id uuid,
  _invited_user_id uuid default null,
  _invited_email text default null
) returns jsonb
language plpgsql security definer set search_path = public as $func$
declare
  v_caller uuid := auth.uid();
  v_code text;
  v_invite_id uuid;
  v_attempts int := 0;
begin
  if v_caller is null then raise exception 'not_authenticated'; end if;
  if not exists (
    select 1 from public.family_members
    where family_id = _family_id and user_id = v_caller and role = 'parent'
  ) then raise exception 'forbidden: must be a parent' using errcode = '42501'; end if;

  -- Sweep stale pending invites to free up codes
  update public.family_invites
     set status = 'expired'
   where status = 'pending' and expires_at <= now();

  loop
    v_attempts := v_attempts + 1;
    v_code := lpad((floor(random() * 10000))::text, 4, '0');
    begin
      insert into public.family_invites
        (family_id, pairing_code, invited_user_id, invited_email, created_by)
      values (_family_id, v_code, _invited_user_id, nullif(trim(_invited_email), ''), v_caller)
      returning id into v_invite_id;
      exit;
    exception when unique_violation then
      if v_attempts > 10 then raise exception 'could_not_generate_unique_code'; end if;
    end;
  end loop;

  return jsonb_build_object(
    'invite_id', v_invite_id,
    'pairing_code', v_code,
    'expires_at', now() + interval '10 minutes'
  );
end;
$func$;
grant execute on function public.create_family_invite(uuid, uuid, text) to authenticated;


-- accept_family_invite --------------------------------------------------------
create or replace function public.accept_family_invite(_code text)
returns uuid language plpgsql security definer set search_path = public as $func$
declare v_caller uuid := auth.uid(); v_invite public.family_invites;
begin
  if v_caller is null then raise exception 'not_authenticated'; end if;

  -- Sweep stale pending before lookup
  update public.family_invites
     set status = 'expired'
   where status = 'pending' and expires_at <= now();

  select * into v_invite
    from public.family_invites
   where pairing_code = _code
     and status = 'pending'
   order by created_at desc
   limit 1
   for update;

  if v_invite.id is null then
    raise exception 'invalid_or_expired_code' using errcode = '22023';
  end if;
  if v_invite.invited_user_id is not null and v_invite.invited_user_id <> v_caller then
    raise exception 'code_belongs_to_another_user' using errcode = '42501';
  end if;

  insert into public.family_members (family_id, user_id, role)
    values (v_invite.family_id, v_caller, 'child')
    on conflict (family_id, user_id) do nothing;

  update public.family_invites
     set status='accepted', accepted_by=v_caller, accepted_at=now()
   where id = v_invite.id;

  return v_invite.family_id;
end;
$func$;
grant execute on function public.accept_family_invite(text) to authenticated;


-- list_my_families ------------------------------------------------------------
create or replace function public.list_my_families()
returns table (
  family_id uuid, family_name text, my_role text, members jsonb, created_at timestamptz
)
language sql stable security definer set search_path = public as $func$
  with mine as (
    select fm.family_id, fm.role as my_role
    from public.family_members fm where fm.user_id = auth.uid()
  )
  select f.id, f.name, m.my_role,
    coalesce(
      (select jsonb_agg(jsonb_build_object(
                'user_id', fm.user_id, 'role', fm.role, 'joined_at', fm.joined_at,
                'display_name', p.display_name, 'avatar_url', p.avatar_url, 'email', p.email
              ) order by fm.role desc, fm.joined_at)
         from public.family_members fm
         join public.profiles p on p.id = fm.user_id
         where fm.family_id = f.id),
      '[]'::jsonb),
    f.created_at
  from public.families f
  join mine m on m.family_id = f.id
  where f.deleted_at is null
  order by f.created_at desc;
$func$;
grant execute on function public.list_my_families() to authenticated;


-- =============================================================================
-- Auto-subscribe parents to their kids' parent_chat / dm_parent_pastor /
-- dm_parent_leader threads when family_members rows are inserted.
-- =============================================================================
create or replace function public.ensure_parent_chat_subscriptions(_parent_id uuid, _family_id uuid)
returns void language plpgsql security definer set search_path = public as $func$
declare
  v_yg uuid; v_pastor uuid; v_sg uuid; v_leader uuid; v_thread uuid;
begin
  for v_yg in
    select distinct ygm.group_id
    from public.family_members fm
    join public.youth_group_members ygm on ygm.user_id = fm.user_id
    where fm.family_id = _family_id and fm.role = 'child'
  loop
    -- parent_chat per youth group
    select id into v_thread from public.chat_threads
      where kind = 'parent_chat'::thread_kind and group_id = v_yg limit 1;
    if v_thread is null then
      insert into public.chat_threads (kind, group_id)
        values ('parent_chat'::thread_kind, v_yg) returning id into v_thread;
      insert into public.thread_subscribers (thread_id, user_id)
        select v_thread, ygm.user_id
        from public.youth_group_members ygm
        where ygm.group_id = v_yg and ygm.role in ('pastor','leader')
        on conflict do nothing;
    end if;
    insert into public.thread_subscribers (thread_id, user_id)
      values (v_thread, _parent_id) on conflict do nothing;

    -- dm_parent_pastor for each pastor
    for v_pastor in
      select user_id from public.youth_group_members
      where group_id = v_yg and role = 'pastor'
    loop
      select t.id into v_thread
      from public.chat_threads t
      where t.kind = 'dm_parent_pastor'::thread_kind and t.group_id = v_yg
        and exists (select 1 from public.thread_subscribers
                     where thread_id = t.id and user_id = _parent_id)
        and exists (select 1 from public.thread_subscribers
                     where thread_id = t.id and user_id = v_pastor)
      limit 1;
      if v_thread is null then
        insert into public.chat_threads (kind, group_id)
          values ('dm_parent_pastor'::thread_kind, v_yg) returning id into v_thread;
        insert into public.thread_subscribers (thread_id, user_id)
          values (v_thread, _parent_id), (v_thread, v_pastor)
          on conflict do nothing;
      end if;
    end loop;

    -- dm_parent_leader for each small group the child(ren) belong to
    for v_sg, v_leader in
      select sg.id, sgm_leader.user_id
      from public.family_members fm
      join public.small_group_members sgm on sgm.user_id = fm.user_id and sgm.role = 'member'
      join public.small_groups sg on sg.id = sgm.small_group_id
      join public.small_group_members sgm_leader
        on sgm_leader.small_group_id = sg.id and sgm_leader.role = 'leader'
      where fm.family_id = _family_id and fm.role = 'child'
        and sg.youth_group_id = v_yg
    loop
      select t.id into v_thread
      from public.chat_threads t
      where t.kind = 'dm_parent_leader'::thread_kind and t.small_group_id = v_sg
        and exists (select 1 from public.thread_subscribers
                     where thread_id = t.id and user_id = _parent_id)
        and exists (select 1 from public.thread_subscribers
                     where thread_id = t.id and user_id = v_leader)
      limit 1;
      if v_thread is null then
        insert into public.chat_threads (kind, group_id, small_group_id)
          values ('dm_parent_leader'::thread_kind, v_yg, v_sg) returning id into v_thread;
        insert into public.thread_subscribers (thread_id, user_id)
          values (v_thread, _parent_id), (v_thread, v_leader)
          on conflict do nothing;
      end if;
    end loop;
  end loop;
end;
$func$;
grant execute on function public.ensure_parent_chat_subscriptions(uuid, uuid) to authenticated;

create or replace function public.tg_family_members_subscribe_parents()
returns trigger language plpgsql security definer set search_path = public as $func$
declare v_parent uuid;
begin
  for v_parent in
    select user_id from public.family_members
    where family_id = new.family_id and role = 'parent'
  loop
    perform public.ensure_parent_chat_subscriptions(v_parent, new.family_id);
  end loop;
  return new;
end;
$func$;

drop trigger if exists trg_family_members_subscribe_parents on public.family_members;
create trigger trg_family_members_subscribe_parents
after insert on public.family_members
for each row execute function public.tg_family_members_subscribe_parents();

notify pgrst, 'reload schema';
