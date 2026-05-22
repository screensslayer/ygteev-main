
-- =============================================================================
-- Pastor dashboard surface: real data for the iOS pastor home + members view.
--   1. pastor_dashboard(group_id)       — single-object header stats
--   2. pastor_recent_activity(group_id) — union feed of plan/event/join events
--   3. pastor_list_join_requests(group_id)
--   4. pastor_approve_join_request(request_id)
--   5. pastor_deny_join_request(request_id)
--   6. pastor_list_group_members(group_id, role_filter, active_only)
--   7. pastor_list_small_groups(group_id)
-- =============================================================================

-- Drop the stale overload (without _visibility) to remove ambiguity
drop function if exists public.pastor_create_plan(uuid, text, int, int);


-- Helper: caller is pastor of this youth group (or site admin)
create or replace function public._pastor_can_view_group(_group_id uuid)
returns boolean
language sql stable security definer set search_path = public as $func$
  select public.is_site_admin(auth.uid())
      or public.is_group_pastor(auth.uid(), _group_id);
$func$;
grant execute on function public._pastor_can_view_group(uuid) to authenticated;


-- =====================================================================
-- 1. pastor_dashboard(_group_id) — header card stats
-- =====================================================================
create or replace function public.pastor_dashboard(_group_id uuid)
returns table (
  group_id              uuid,
  group_name            text,
  logo_url              text,
  member_count          int,
  small_group_count     int,
  pending_request_count int,
  active_this_week      int,
  active_last_week      int,
  active_this_week_pct  int,  -- rounded percent of member_count
  active_last_week_pct  int,
  total_group_xp        bigint,
  total_group_water     bigint
)
language sql
stable
security definer
set search_path = public
as $func$
  with allowed as (select public._pastor_can_view_group(_group_id) as ok)
  select
    yg.id           as group_id,
    yg.name         as group_name,
    yg.logo_url     as logo_url,
    (select count(*)::int from public.youth_group_members where group_id = yg.id) as member_count,
    (select count(*)::int from public.small_groups        where youth_group_id = yg.id) as small_group_count,
    (select count(*)::int from public.youth_group_join_requests
       where group_id = yg.id and status = 'pending') as pending_request_count,
    (select count(*)::int
       from public.youth_group_members ygm
       join public.profiles p on p.id = ygm.user_id
      where ygm.group_id = yg.id
        and p.last_opened_at >= now() - interval '7 days') as active_this_week,
    (select count(*)::int
       from public.youth_group_members ygm
       join public.profiles p on p.id = ygm.user_id
      where ygm.group_id = yg.id
        and p.last_opened_at >= now() - interval '14 days'
        and p.last_opened_at  < now() - interval '7 days') as active_last_week,
    (select case when count(*) = 0 then 0
            else round((count(*) filter (where p.last_opened_at >= now() - interval '7 days'))::numeric
                       / count(*)::numeric * 100)::int end
       from public.youth_group_members ygm
       join public.profiles p on p.id = ygm.user_id
      where ygm.group_id = yg.id) as active_this_week_pct,
    (select case when count(*) = 0 then 0
            else round((count(*) filter (
                          where p.last_opened_at >= now() - interval '14 days'
                            and p.last_opened_at  < now() - interval '7 days'))::numeric
                       / count(*)::numeric * 100)::int end
       from public.youth_group_members ygm
       join public.profiles p on p.id = ygm.user_id
      where ygm.group_id = yg.id) as active_last_week_pct,
    (select coalesce(sum(p.xp), 0)::bigint
       from public.youth_group_members ygm
       join public.profiles p on p.id = ygm.user_id
      where ygm.group_id = yg.id) as total_group_xp,
    (select coalesce(sum(p.water), 0)::bigint
       from public.youth_group_members ygm
       join public.profiles p on p.id = ygm.user_id
      where ygm.group_id = yg.id) as total_group_water
  from public.youth_groups yg, allowed
  where yg.id = _group_id and allowed.ok;
$func$;
grant execute on function public.pastor_dashboard(uuid) to authenticated;


-- =====================================================================
-- 2. pastor_recent_activity(_group_id, _limit)
--    Union feed of: plan completions, day completions, event RSVPs,
--    new approvals (members joining), attendance taken.
-- =====================================================================
create or replace function public.pastor_recent_activity(
  _group_id uuid, _limit int default 20
) returns table (
  event_id      text,           -- stable string id for SwiftUI Identifiable
  kind          text,           -- 'plan_completed'|'day_completed'|'joined'|'event_rsvp'|'attendance_taken'
  user_id       uuid,
  display_name  text,
  avatar_url    text,
  headline      text,           -- short label suitable for the feed row
  occurred_at   timestamptz,
  xp_delta      int             -- optional XP badge value, 0 if n/a
)
language sql
stable
security definer
set search_path = public
as $func$
  with allowed as (select public._pastor_can_view_group(_group_id) as ok),
  members as (
    select ygm.user_id from public.youth_group_members ygm where ygm.group_id = _group_id
  ),
  plan_completions as (
    select
      'pc:' || c.id::text as event_id,
      'plan_completed'    as kind,
      c.user_id,
      p.display_name,
      p.avatar_url,
      'finished '         || coalesce(bp.title, 'a plan') as headline,
      c.completed_at      as occurred_at,
      coalesce(bp.xp_reward, 0)::int as xp_delta
    from public.bible_plan_completions c
    join public.profiles p on p.id = c.user_id
    join public.bible_plans bp on bp.id = c.plan_id
    where c.user_id in (select user_id from members)
  ),
  day_completions as (
    select
      'dc:' || d.id::text as event_id,
      'day_completed'     as kind,
      d.user_id,
      p.display_name,
      p.avatar_url,
      'finished a day of ' || coalesce(bp.title, 'a plan') as headline,
      d.completed_at      as occurred_at,
      (d.step_xp_earned + 100)::int as xp_delta  -- + daily bonus
    from public.bible_plan_day_progress d
    join public.profiles p on p.id = d.user_id
    left join public.bible_plans bp on bp.id = d.plan_id
    where d.user_id in (select user_id from members)
  ),
  recent_joins as (
    select
      'jn:' || ygm.user_id::text || ':' || extract(epoch from ygm.joined_at)::text as event_id,
      'joined'            as kind,
      ygm.user_id,
      p.display_name,
      p.avatar_url,
      'joined the group'  as headline,
      ygm.joined_at       as occurred_at,
      0                   as xp_delta
    from public.youth_group_members ygm
    join public.profiles p on p.id = ygm.user_id
    where ygm.group_id = _group_id
  ),
  rsvps as (
    select
      'rs:' || r.id::text as event_id,
      'event_rsvp'        as kind,
      r.user_id,
      p.display_name,
      p.avatar_url,
      'RSVPed to '        || coalesce(e.title, 'an event') as headline,
      r.created_at        as occurred_at,
      0                   as xp_delta
    from public.event_rsvps r
    join public.profiles p on p.id = r.user_id
    left join public.events e on e.id = r.event_id
    where r.user_id in (select user_id from members)
  ),
  attendance as (
    select
      'at:' || ae.id::text as event_id,
      'attendance_taken'   as kind,
      ae.created_by        as user_id,
      coalesce(p.display_name, 'Leader') as display_name,
      p.avatar_url,
      'took attendance: '  || coalesce(ae.title, 'session') as headline,
      ae.occurred_at       as occurred_at,
      0                    as xp_delta
    from public.attendance_events ae
    left join public.profiles p on p.id = ae.created_by
    join public.small_groups sg on sg.id = ae.small_group_id
    where sg.youth_group_id = _group_id
  ),
  unioned as (
    select * from plan_completions
    union all select * from day_completions
    union all select * from recent_joins
    union all select * from rsvps
    union all select * from attendance
  )
  select u.* from unioned u, allowed
  where allowed.ok
  order by u.occurred_at desc
  limit greatest(1, least(_limit, 100));
$func$;
grant execute on function public.pastor_recent_activity(uuid, int) to authenticated;


-- =====================================================================
-- 3. pastor_list_join_requests(_group_id)
-- =====================================================================
create or replace function public.pastor_list_join_requests(_group_id uuid)
returns table (
  request_id   uuid,
  user_id      uuid,
  display_name text,
  avatar_url   text,
  email        text,
  message      text,
  requested_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $func$
  with allowed as (select public._pastor_can_view_group(_group_id) as ok)
  select
    r.id          as request_id,
    r.user_id,
    p.display_name,
    p.avatar_url,
    p.email,
    r.message,
    r.requested_at
  from public.youth_group_join_requests r
  join public.profiles p on p.id = r.user_id
  cross join allowed
  where r.group_id = _group_id
    and r.status   = 'pending'
    and allowed.ok
  order by r.requested_at desc;
$func$;
grant execute on function public.pastor_list_join_requests(uuid) to authenticated;


-- =====================================================================
-- 4. pastor_approve_join_request(_request_id)
--    Approves the request, inserts youth_group_members row, stamps decision.
-- =====================================================================
create or replace function public.pastor_approve_join_request(_request_id uuid)
returns uuid    -- returns the new youth_group_members.user_id, or null on no-op
language plpgsql
security definer
set search_path = public
as $func$
declare
  v_caller uuid := auth.uid();
  v_req public.youth_group_join_requests;
begin
  if v_caller is null then raise exception 'not_authenticated'; end if;

  select * into v_req from public.youth_group_join_requests where id = _request_id;
  if v_req.id is null then raise exception 'request_not_found'; end if;

  if not public._pastor_can_view_group(v_req.group_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  if v_req.status <> 'pending' then
    raise exception 'request_already_decided';
  end if;

  -- Add as a member (idempotent on conflict)
  insert into public.youth_group_members (group_id, user_id, role)
  values (v_req.group_id, v_req.user_id, 'member')
  on conflict (group_id, user_id) do nothing;

  update public.youth_group_join_requests
     set status      = 'approved',
         decided_at  = now(),
         decided_by  = v_caller
   where id = _request_id;

  return v_req.user_id;
end;
$func$;
grant execute on function public.pastor_approve_join_request(uuid) to authenticated;


-- =====================================================================
-- 5. pastor_deny_join_request(_request_id)
-- =====================================================================
create or replace function public.pastor_deny_join_request(_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $func$
declare
  v_caller uuid := auth.uid();
  v_req public.youth_group_join_requests;
begin
  if v_caller is null then raise exception 'not_authenticated'; end if;

  select * into v_req from public.youth_group_join_requests where id = _request_id;
  if v_req.id is null then raise exception 'request_not_found'; end if;

  if not public._pastor_can_view_group(v_req.group_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  if v_req.status <> 'pending' then return; end if;

  update public.youth_group_join_requests
     set status      = 'denied',
         decided_at  = now(),
         decided_by  = v_caller
   where id = _request_id;
end;
$func$;
grant execute on function public.pastor_deny_join_request(uuid) to authenticated;


-- =====================================================================
-- 6. pastor_list_group_members(_group_id, _role_filter, _active_only)
--    Powers the "All / Leaders" tabs in the Members view.
--    _role_filter: 'all' | 'pastor' | 'leader' | 'member' | 'parent'
--    _active_only: when true, only members with last_opened_at within 7 days
-- =====================================================================
create or replace function public.pastor_list_group_members(
  _group_id uuid,
  _role_filter text default 'all',
  _active_only boolean default false
) returns table (
  user_id        uuid,
  display_name   text,
  email          text,
  avatar_url     text,
  role           text,
  joined_at      timestamptz,
  last_opened_at timestamptz,
  xp             int,
  water          int,
  streak         int,
  is_active_week boolean
)
language sql
stable
security definer
set search_path = public
as $func$
  with allowed as (select public._pastor_can_view_group(_group_id) as ok)
  select
    p.id                                   as user_id,
    p.display_name,
    p.email,
    p.avatar_url,
    ygm.role::text                         as role,
    ygm.joined_at,
    p.last_opened_at,
    p.xp,
    p.water,
    p.streak,
    (p.last_opened_at >= now() - interval '7 days') as is_active_week
  from public.youth_group_members ygm
  join public.profiles p on p.id = ygm.user_id
  cross join allowed
  where ygm.group_id = _group_id
    and allowed.ok
    and (_role_filter = 'all' or ygm.role::text = _role_filter)
    and (not _active_only or p.last_opened_at >= now() - interval '7 days')
  order by ygm.role, p.display_name nulls last, p.email;
$func$;
grant execute on function public.pastor_list_group_members(uuid, text, boolean) to authenticated;


-- =====================================================================
-- 7. pastor_list_small_groups(_group_id)
--    Powers the "Small Groups" tab.
-- =====================================================================
create or replace function public.pastor_list_small_groups(_group_id uuid)
returns table (
  small_group_id   uuid,
  name             text,
  description      text,
  meeting_day      text,
  meeting_time     text,
  member_count     int,
  leader_count     int,
  leader_names     text[],
  created_at       timestamptz
)
language sql
stable
security definer
set search_path = public
as $func$
  with allowed as (select public._pastor_can_view_group(_group_id) as ok)
  select
    sg.id            as small_group_id,
    sg.name,
    sg.description,
    sg.meeting_day,
    sg.meeting_time,
    (select count(*)::int from public.small_group_members where small_group_id = sg.id) as member_count,
    (select count(*)::int from public.small_group_members
        where small_group_id = sg.id and role = 'leader') as leader_count,
    (select coalesce(array_agg(coalesce(p.display_name, p.email)
              order by p.display_name nulls last, p.email),
              array[]::text[])
       from public.small_group_members sgm
       join public.profiles p on p.id = sgm.user_id
      where sgm.small_group_id = sg.id and sgm.role = 'leader') as leader_names,
    sg.created_at
  from public.small_groups sg
  cross join allowed
  where sg.youth_group_id = _group_id
    and allowed.ok
  order by sg.name;
$func$;
grant execute on function public.pastor_list_small_groups(uuid) to authenticated;


notify pgrst, 'reload schema';
