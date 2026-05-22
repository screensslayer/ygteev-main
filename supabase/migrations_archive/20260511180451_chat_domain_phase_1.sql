
-- ---------- Enums ----------
do $$ begin
  create type public.thread_kind as enum (
    'group_main', 'small_group', 'parent_chat',
    'dm_pastor', 'dm_leader', 'dm_parent_pastor', 'dm_parent_leader'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.thread_moderation_policy as enum ('block', 'allow_alert');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.moderation_status as enum ('clean', 'flagged_allowed', 'flagged_blocked');
exception when duplicate_object then null; end $$;

-- ---------- chat_threads ----------
create table if not exists public.chat_threads (
  id                uuid primary key default gen_random_uuid(),
  group_id          uuid not null references public.youth_groups(id) on delete cascade,
  small_group_id    uuid references public.small_groups(id) on delete cascade,
  kind              public.thread_kind not null,
  moderation_policy public.thread_moderation_policy not null default 'block',
  dm_user_a         uuid references auth.users(id) on delete cascade,
  dm_user_b         uuid references auth.users(id) on delete cascade,
  last_message_at   timestamptz,
  created_at        timestamptz not null default now()
);

do $$ begin
  alter table public.chat_threads
    add constraint chat_threads_dm_canonical_order
    check (dm_user_a is null or dm_user_b is null or dm_user_a < dm_user_b);
exception when duplicate_object then null; end $$;

create unique index if not exists chat_threads_one_main_per_group
  on public.chat_threads(group_id) where kind = 'group_main';

create unique index if not exists chat_threads_one_per_small_group
  on public.chat_threads(small_group_id) where kind = 'small_group';

create unique index if not exists chat_threads_dm_unique
  on public.chat_threads(group_id, kind, dm_user_a, dm_user_b)
  where dm_user_a is not null;

create index if not exists chat_threads_group_idx on public.chat_threads(group_id);

alter table public.chat_threads enable row level security;

-- ---------- thread_subscribers ----------
create table if not exists public.thread_subscribers (
  id           uuid primary key default gen_random_uuid(),
  thread_id    uuid not null references public.chat_threads(id) on delete cascade,
  user_id      uuid not null references auth.users(id) on delete cascade,
  joined_at    timestamptz not null default now(),
  last_read_at timestamptz,
  unique (thread_id, user_id)
);
alter table public.thread_subscribers enable row level security;
create index if not exists thread_subscribers_user_idx on public.thread_subscribers(user_id);

-- ---------- messages ----------
create table if not exists public.messages (
  id                    uuid primary key default gen_random_uuid(),
  thread_id             uuid not null references public.chat_threads(id) on delete cascade,
  sender_id             uuid not null references auth.users(id) on delete cascade,
  body                  text not null check (length(body) between 1 and 4000),
  moderation_status     public.moderation_status not null default 'clean',
  moderation_categories jsonb,
  created_at            timestamptz not null default now()
);
alter table public.messages enable row level security;
create index if not exists messages_thread_idx on public.messages(thread_id, created_at desc);

-- ---------- moderation_alerts ----------
create table if not exists public.moderation_alerts (
  id              uuid primary key default gen_random_uuid(),
  thread_id       uuid not null references public.chat_threads(id) on delete cascade,
  message_id      uuid references public.messages(id) on delete set null,
  group_id        uuid not null references public.youth_groups(id) on delete cascade,
  sender_id       uuid references auth.users(id) on delete set null,
  status          public.moderation_status not null,
  categories      jsonb,
  preview         text,
  acknowledged_at timestamptz,
  acknowledged_by uuid references auth.users(id) on delete set null,
  created_at      timestamptz not null default now()
);
alter table public.moderation_alerts enable row level security;
create index if not exists moderation_alerts_group_idx on public.moderation_alerts(group_id, created_at desc);

-- =====================================================
-- RLS
-- =====================================================

-- Threads
drop policy if exists "threads: subscriber read" on public.chat_threads;
create policy "threads: subscriber read" on public.chat_threads for select using (
  public.is_site_admin(auth.uid())
  or public.is_group_pastor(auth.uid(), group_id)
  or exists (
    select 1 from public.thread_subscribers s
    where s.thread_id = chat_threads.id and s.user_id = auth.uid()
  )
);
-- Writes: triggers/edge function only via service_role.

-- Subscribers
drop policy if exists "subs: read" on public.thread_subscribers;
create policy "subs: read" on public.thread_subscribers for select using (
  user_id = auth.uid()
  or public.is_site_admin(auth.uid())
  or exists (
    select 1 from public.chat_threads t
    where t.id = thread_id and public.is_group_pastor(auth.uid(), t.group_id)
  )
);

drop policy if exists "subs: self mark read" on public.thread_subscribers;
create policy "subs: self mark read" on public.thread_subscribers for update
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Messages (read-only for clients; writes via edge function w/ service_role)
drop policy if exists "messages: subscriber read" on public.messages;
create policy "messages: subscriber read" on public.messages for select using (
  public.is_site_admin(auth.uid())
  or exists (
    select 1 from public.thread_subscribers s
    where s.thread_id = messages.thread_id and s.user_id = auth.uid()
  )
  or exists (
    select 1 from public.chat_threads t
    where t.id = messages.thread_id and public.is_group_pastor(auth.uid(), t.group_id)
  )
);

drop policy if exists "messages: client insert blocked" on public.messages;
create policy "messages: client insert blocked" on public.messages for insert with check (false);

-- Moderation alerts
drop policy if exists "alerts: pastor/admin read" on public.moderation_alerts;
create policy "alerts: pastor/admin read" on public.moderation_alerts for select using (
  public.is_site_admin(auth.uid()) or public.is_group_pastor(auth.uid(), group_id)
);
drop policy if exists "alerts: pastor/admin update" on public.moderation_alerts;
create policy "alerts: pastor/admin update" on public.moderation_alerts for update using (
  public.is_site_admin(auth.uid()) or public.is_group_pastor(auth.uid(), group_id)
) with check (
  public.is_site_admin(auth.uid()) or public.is_group_pastor(auth.uid(), group_id)
);

-- =====================================================
-- HELPERS
-- =====================================================

create or replace function public.ensure_group_main_thread(_group_id uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare _tid uuid;
begin
  select id into _tid from public.chat_threads where group_id = _group_id and kind = 'group_main';
  if _tid is not null then return _tid; end if;
  insert into public.chat_threads(group_id, kind, moderation_policy)
  values (_group_id, 'group_main', 'block') returning id into _tid;
  return _tid;
end $$;

create or replace function public.ensure_small_group_thread(_small_group_id uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare _tid uuid; _gid uuid;
begin
  select id into _tid from public.chat_threads where small_group_id = _small_group_id and kind = 'small_group';
  if _tid is not null then return _tid; end if;
  select youth_group_id into _gid from public.small_groups where id = _small_group_id;
  insert into public.chat_threads(group_id, small_group_id, kind, moderation_policy)
  values (_gid, _small_group_id, 'small_group', 'block') returning id into _tid;
  return _tid;
end $$;

create or replace function public.ensure_dm_thread(
  _group_id uuid, _kind public.thread_kind, _u1 uuid, _u2 uuid
) returns uuid language plpgsql security definer set search_path = public as $$
declare _ua uuid := least(_u1, _u2); _ub uuid := greatest(_u1, _u2); _tid uuid;
begin
  if _u1 = _u2 then return null; end if;
  select id into _tid from public.chat_threads
    where group_id = _group_id and kind = _kind and dm_user_a = _ua and dm_user_b = _ub;
  if _tid is not null then return _tid; end if;
  insert into public.chat_threads(group_id, kind, moderation_policy, dm_user_a, dm_user_b)
  values (_group_id, _kind,
          case when _kind in ('dm_pastor','dm_leader') then 'allow_alert'::public.thread_moderation_policy
               else 'block'::public.thread_moderation_policy end,
          _ua, _ub)
  returning id into _tid;
  insert into public.thread_subscribers(thread_id, user_id) values (_tid, _ua), (_tid, _ub)
  on conflict do nothing;
  return _tid;
end $$;

-- =====================================================
-- TRIGGERS — auto-subscription on membership changes
-- =====================================================

create or replace function public.tg_chat_on_youth_group_member_insert()
returns trigger language plpgsql security definer set search_path = public as $$
declare _main_thread_id uuid; _peer record;
begin
  if exists (select 1 from public.youth_groups where id = NEW.group_id and is_default_ygteev = true) then
    return NEW;
  end if;

  _main_thread_id := public.ensure_group_main_thread(NEW.group_id);
  insert into public.thread_subscribers(thread_id, user_id) values (_main_thread_id, NEW.user_id) on conflict do nothing;

  if NEW.role = 'member' then
    for _peer in select user_id from public.youth_group_members
                 where group_id = NEW.group_id and role = 'pastor' loop
      perform public.ensure_dm_thread(NEW.group_id, 'dm_pastor', NEW.user_id, _peer.user_id);
    end loop;
  end if;

  if NEW.role = 'pastor' then
    for _peer in select user_id from public.youth_group_members
                 where group_id = NEW.group_id and role = 'member' loop
      perform public.ensure_dm_thread(NEW.group_id, 'dm_pastor', NEW.user_id, _peer.user_id);
    end loop;
  end if;

  return NEW;
end $$;

drop trigger if exists chat_on_ygm_insert on public.youth_group_members;
create trigger chat_on_ygm_insert
  after insert on public.youth_group_members
  for each row execute function public.tg_chat_on_youth_group_member_insert();

create or replace function public.tg_chat_on_small_group_member_insert()
returns trigger language plpgsql security definer set search_path = public as $$
declare _thread_id uuid; _group_id uuid; _peer record;
begin
  select youth_group_id into _group_id from public.small_groups where id = NEW.small_group_id;
  _thread_id := public.ensure_small_group_thread(NEW.small_group_id);
  insert into public.thread_subscribers(thread_id, user_id) values (_thread_id, NEW.user_id) on conflict do nothing;

  if NEW.role = 'member' then
    for _peer in select user_id from public.small_group_members
                 where small_group_id = NEW.small_group_id and role = 'leader' loop
      perform public.ensure_dm_thread(_group_id, 'dm_leader', NEW.user_id, _peer.user_id);
    end loop;
  end if;

  if NEW.role = 'leader' then
    for _peer in select user_id from public.small_group_members
                 where small_group_id = NEW.small_group_id and role = 'member' loop
      perform public.ensure_dm_thread(_group_id, 'dm_leader', NEW.user_id, _peer.user_id);
    end loop;
  end if;

  return NEW;
end $$;

drop trigger if exists chat_on_sgm_insert on public.small_group_members;
create trigger chat_on_sgm_insert
  after insert on public.small_group_members
  for each row execute function public.tg_chat_on_small_group_member_insert();

-- =====================================================
-- BACKFILL — existing memberships
-- =====================================================

do $$
declare _g record; _r record; _t uuid;
begin
  for _g in select id from public.youth_groups where is_default_ygteev = false loop
    _t := public.ensure_group_main_thread(_g.id);
    for _r in select user_id from public.youth_group_members where group_id = _g.id loop
      insert into public.thread_subscribers(thread_id, user_id) values (_t, _r.user_id) on conflict do nothing;
    end loop;
    for _r in
      select pastor.user_id as pu, member.user_id as mu
      from public.youth_group_members pastor
      join public.youth_group_members member on member.group_id = pastor.group_id
      where pastor.group_id = _g.id and pastor.role = 'pastor' and member.role = 'member'
    loop
      perform public.ensure_dm_thread(_g.id, 'dm_pastor', _r.pu, _r.mu);
    end loop;
  end loop;
end $$;

do $$
declare _sg record; _t uuid; _r record;
begin
  for _sg in select id as sgid, youth_group_id as gid from public.small_groups loop
    _t := public.ensure_small_group_thread(_sg.sgid);
    for _r in select user_id from public.small_group_members where small_group_id = _sg.sgid loop
      insert into public.thread_subscribers(thread_id, user_id) values (_t, _r.user_id) on conflict do nothing;
    end loop;
    for _r in
      select leader.user_id as lu, member.user_id as mu
      from public.small_group_members leader
      join public.small_group_members member on member.small_group_id = leader.small_group_id
      where leader.small_group_id = _sg.sgid and leader.role = 'leader' and member.role = 'member'
    loop
      perform public.ensure_dm_thread(_sg.gid, 'dm_leader', _r.lu, _r.mu);
    end loop;
  end loop;
end $$;

-- =====================================================
-- list_my_threads() RPC for the iOS Messages tab
-- =====================================================

create or replace function public.list_my_threads()
returns table (
  thread_id            uuid,
  kind                 public.thread_kind,
  group_id             uuid,
  group_name           text,
  group_gradient_from  text,
  group_gradient_to    text,
  small_group_id       uuid,
  small_group_name     text,
  dm_other_user_id     uuid,
  dm_other_display     text,
  dm_other_avatar_url  text,
  dm_other_role        text,
  last_message_body    text,
  last_message_sender  text,
  last_message_at      timestamptz,
  unread_count         integer
)
language sql stable security definer set search_path = public as $$
  with my_subs as (
    select s.thread_id, s.last_read_at
    from public.thread_subscribers s
    where s.user_id = auth.uid()
  ),
  last_msgs as (
    select distinct on (m.thread_id)
      m.thread_id, m.body, m.sender_id, m.created_at
    from public.messages m
    join my_subs ms on ms.thread_id = m.thread_id
    order by m.thread_id, m.created_at desc
  )
  select
    t.id,
    t.kind,
    t.group_id,
    yg.name,
    yg.gradient_from,
    yg.gradient_to,
    t.small_group_id,
    sg.name,
    case when t.dm_user_a is not null then
      case when t.dm_user_a = auth.uid() then t.dm_user_b else t.dm_user_a end
    end,
    case when t.dm_user_a is not null then
      (select display_name from public.profiles where id =
        case when t.dm_user_a = auth.uid() then t.dm_user_b else t.dm_user_a end)
    end,
    case when t.dm_user_a is not null then
      (select avatar_url from public.profiles where id =
        case when t.dm_user_a = auth.uid() then t.dm_user_b else t.dm_user_a end)
    end,
    case t.kind when 'dm_pastor' then 'pastor'
                when 'dm_parent_pastor' then 'pastor'
                when 'dm_leader' then 'leader'
                when 'dm_parent_leader' then 'leader' end,
    lm.body,
    case when lm.sender_id = auth.uid() then 'You'
         else (select display_name from public.profiles where id = lm.sender_id) end,
    lm.created_at,
    coalesce((
      select count(*)::int from public.messages m2
      where m2.thread_id = t.id
        and m2.created_at > coalesce(ms.last_read_at, '-infinity'::timestamptz)
        and m2.sender_id <> auth.uid()
    ), 0)
  from public.chat_threads t
  join my_subs ms on ms.thread_id = t.id
  left join public.youth_groups yg on yg.id = t.group_id
  left join public.small_groups sg on sg.id = t.small_group_id
  left join last_msgs lm on lm.thread_id = t.id
  order by coalesce(lm.created_at, t.created_at) desc;
$$;

create or replace function public.mark_thread_read(_thread_id uuid)
returns void language sql security definer set search_path = public as $$
  update public.thread_subscribers
     set last_read_at = now()
   where thread_id = _thread_id and user_id = auth.uid();
$$;
