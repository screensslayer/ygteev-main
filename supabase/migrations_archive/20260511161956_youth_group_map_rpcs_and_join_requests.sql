
-- ---------- 1. Extend youth_groups_near with meeting_time + counts ----------
-- (drop required because RETURNS TABLE shape changed)
drop function if exists public.youth_groups_near(double precision, double precision, numeric);

create function public.youth_groups_near(
  _lat    double precision,
  _lng    double precision,
  _meters numeric default 40234     -- ~25 miles
)
returns table (
  id                uuid,
  name              text,
  church_name       text,
  description       text,
  address           text,
  meeting_time      text,
  logo_url          text,
  gradient_from     text,
  gradient_to       text,
  latitude          double precision,
  longitude         double precision,
  distance_m        double precision,
  member_count      integer,
  small_group_count integer
)
language sql stable security definer set search_path = public as $$
  with origin as (
    select st_setsrid(st_makepoint(_lng, _lat), 4326)::geography as g
  )
  select
    yg.id, yg.name, yg.church_name, yg.description, yg.address,
    yg.meeting_time, yg.logo_url, yg.gradient_from, yg.gradient_to,
    yg.latitude, yg.longitude,
    st_distance(yg.location, origin.g) as distance_m,
    (select count(*)::int from public.youth_group_members where group_id = yg.id) as member_count,
    (select count(*)::int from public.small_groups where youth_group_id = yg.id) as small_group_count
  from public.youth_groups yg, origin
  where yg.location is not null
    and yg.is_public = true
    and yg.is_default_ygteev = false
    and st_dwithin(yg.location, origin.g, _meters)
  order by yg.location <-> origin.g;
$$;

-- ---------- 2. Public-profile RPC for the group detail view ----------
create or replace function public.youth_group_public_profile(_group_id uuid)
returns table (
  id                uuid,
  name              text,
  church_name       text,
  description       text,
  address           text,
  meeting_time      text,
  logo_url          text,
  gradient_from     text,
  gradient_to       text,
  latitude          double precision,
  longitude         double precision,
  member_count      integer,
  small_group_count integer,
  leaders           jsonb,
  upcoming_events   jsonb
)
language sql stable security definer set search_path = public as $$
  select
    yg.id, yg.name, yg.church_name, yg.description, yg.address,
    yg.meeting_time, yg.logo_url, yg.gradient_from, yg.gradient_to,
    yg.latitude, yg.longitude,
    (select count(*)::int from public.youth_group_members where group_id = yg.id),
    (select count(*)::int from public.small_groups where youth_group_id = yg.id),
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',           p.id,
        'display_name', p.display_name,
        'avatar_url',   p.avatar_url,
        'role',         ygm.role
      ) order by case ygm.role when 'pastor' then 0 when 'leader' then 1 else 2 end, p.display_name)
      from public.youth_group_members ygm
      join public.profiles p on p.id = ygm.user_id
      where ygm.group_id = yg.id and ygm.role in ('pastor','leader')
    ), '[]'::jsonb),
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',        e.id,
        'title',     e.title,
        'starts_at', e.starts_at,
        'location',  e.location,
        'cover_url', e.cover_url
      ) order by e.starts_at)
      from public.events e
      where e.group_id = yg.id
        and e.starts_at >= now()
        and e.visibility = 'public'
    ), '[]'::jsonb)
  from public.youth_groups yg
  where yg.id = _group_id
    and yg.is_public = true
    and yg.is_default_ygteev = false;
$$;

-- ---------- 3. Join-request workflow ----------
do $$ begin
  create type public.join_request_status as enum ('pending','approved','denied','cancelled');
exception when duplicate_object then null; end $$;

create table if not exists public.youth_group_join_requests (
  id           uuid primary key default gen_random_uuid(),
  group_id     uuid not null references public.youth_groups(id) on delete cascade,
  user_id      uuid not null references auth.users(id)          on delete cascade,
  status       public.join_request_status not null default 'pending',
  message      text,
  requested_at timestamptz not null default now(),
  decided_at   timestamptz,
  decided_by   uuid references auth.users(id) on delete set null
);
alter table public.youth_group_join_requests enable row level security;

create index if not exists ygjr_group_status_idx
  on public.youth_group_join_requests(group_id, status);
create index if not exists ygjr_user_idx
  on public.youth_group_join_requests(user_id);
-- Only one pending request per user per group
create unique index if not exists ygjr_one_pending_per_user_group
  on public.youth_group_join_requests(group_id, user_id)
  where status = 'pending';

drop policy if exists "ygjr: read"            on public.youth_group_join_requests;
drop policy if exists "ygjr: self insert"     on public.youth_group_join_requests;
drop policy if exists "ygjr: pastor/admin update" on public.youth_group_join_requests;
drop policy if exists "ygjr: self cancel"     on public.youth_group_join_requests;

-- Read: the requester, the group's pastor/leader, or site admin
create policy "ygjr: read" on public.youth_group_join_requests for select
  using (
    user_id = auth.uid()
    or public.is_site_admin(auth.uid())
    or public.is_group_pastor(auth.uid(), group_id)
  );

-- Self-insert only (the RPC enforces uniqueness + group eligibility)
create policy "ygjr: self insert" on public.youth_group_join_requests for insert
  with check (user_id = auth.uid() and status = 'pending');

-- Pastor / admin can update status to approve / deny
create policy "ygjr: pastor/admin update" on public.youth_group_join_requests for update
  using (public.is_site_admin(auth.uid()) or public.is_group_pastor(auth.uid(), group_id))
  with check (public.is_site_admin(auth.uid()) or public.is_group_pastor(auth.uid(), group_id));

-- User can cancel their own pending request
create policy "ygjr: self cancel" on public.youth_group_join_requests for update
  using (user_id = auth.uid() and status = 'pending')
  with check (user_id = auth.uid() and status = 'cancelled');

-- ---------- 4. RPCs that drive the join-request workflow ----------

-- User-initiated: returns the (possibly pre-existing pending) request row
create or replace function public.request_to_join_group(_group_id uuid, _message text default null)
returns public.youth_group_join_requests
language plpgsql security definer set search_path = public as $$
declare
  _uid    uuid := auth.uid();
  _yg     public.youth_groups;
  _result public.youth_group_join_requests;
begin
  if _uid is null then raise exception 'not_authenticated'; end if;

  select * into _yg from public.youth_groups where id = _group_id;
  if _yg.id is null              then raise exception 'group_not_found';           end if;
  if _yg.is_default_ygteev       then raise exception 'cannot_request_default_group'; end if;
  if not _yg.is_public           then raise exception 'group_not_public';          end if;

  if exists (
    select 1 from public.youth_group_members where group_id = _group_id and user_id = _uid
  ) then
    raise exception 'already_member';
  end if;

  -- Idempotent: return existing pending request if any
  select * into _result
  from public.youth_group_join_requests
  where group_id = _group_id and user_id = _uid and status = 'pending';
  if _result.id is not null then return _result; end if;

  insert into public.youth_group_join_requests (group_id, user_id, message)
  values (_group_id, _uid, _message)
  returning * into _result;

  return _result;
end $$;

-- Pastor / leader / admin: approve or deny
create or replace function public.respond_to_join_request(_request_id uuid, _approve boolean)
returns public.youth_group_join_requests
language plpgsql security definer set search_path = public as $$
declare
  _uid uuid := auth.uid();
  _req public.youth_group_join_requests;
begin
  if _uid is null then raise exception 'not_authenticated'; end if;

  select * into _req
  from public.youth_group_join_requests
  where id = _request_id
  for update;

  if _req.id is null                                                              then raise exception 'request_not_found';        end if;
  if _req.status <> 'pending'                                                     then raise exception 'request_already_decided';  end if;
  if not (public.is_site_admin(_uid) or public.is_group_pastor(_uid, _req.group_id)) then raise exception 'not_authorized';         end if;

  if _approve then
    insert into public.youth_group_members (group_id, user_id, role)
    values (_req.group_id, _req.user_id, 'member')
    on conflict (group_id, user_id) do nothing;

    update public.youth_group_join_requests
       set status = 'approved', decided_at = now(), decided_by = _uid
     where id = _request_id
     returning * into _req;
  else
    update public.youth_group_join_requests
       set status = 'denied', decided_at = now(), decided_by = _uid
     where id = _request_id
     returning * into _req;
  end if;

  return _req;
end $$;
