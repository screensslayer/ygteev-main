-- Surface group_type + grades on the map and profile RPCs so the iOS
-- card and public view can show the right audience label. Also add a
-- server-side eligibility backstop on the join request RPC.

drop function if exists public.youth_groups_near(double precision, double precision, numeric);
create or replace function public.youth_groups_near(
  _lat double precision, _lng double precision, _meters numeric default 40234
) returns table(
  id uuid, name text, church_name text, description text, address text,
  meeting_time text, logo_url text, gradient_from text, gradient_to text,
  latitude double precision, longitude double precision,
  distance_m double precision, member_count integer, small_group_count integer,
  group_type text, grades integer[]
)
language sql stable security definer
set search_path = public
as $$
  with origin as (
    select st_setsrid(st_makepoint(_lng, _lat), 4326)::geography as g
  )
  select
    yg.id, yg.name, yg.church_name, yg.description, yg.address,
    yg.meeting_time, yg.logo_url, yg.gradient_from, yg.gradient_to,
    yg.latitude, yg.longitude,
    st_distance(yg.location, origin.g) as distance_m,
    (select count(*)::int from public.youth_group_members where group_id = yg.id) as member_count,
    (select count(*)::int from public.small_groups where youth_group_id = yg.id) as small_group_count,
    yg.group_type,
    yg.grades
  from public.youth_groups yg, origin
  where yg.location is not null
    and yg.is_public = true
    and yg.is_default_ygteev = false
    and st_dwithin(yg.location, origin.g, _meters)
  order by yg.location <-> origin.g;
$$;

drop function if exists public.youth_group_public_profile(uuid);
create or replace function public.youth_group_public_profile(_group_id uuid)
returns table(
  id uuid, name text, church_name text, description text, address text,
  meeting_time text, logo_url text, gradient_from text, gradient_to text,
  latitude double precision, longitude double precision,
  member_count integer, small_group_count integer,
  leaders jsonb, upcoming_events jsonb,
  viewer_is_member boolean, viewer_pending_request boolean,
  group_type text, grades integer[]
)
language sql stable security definer
set search_path = public
as $$
  select
    yg.id, yg.name, yg.church_name, yg.description, yg.address,
    yg.meeting_time, yg.logo_url, yg.gradient_from, yg.gradient_to,
    yg.latitude, yg.longitude,
    (select count(*)::int from public.youth_group_members where group_id = yg.id),
    (select count(*)::int from public.small_groups       where youth_group_id = yg.id),
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id, 'display_name', p.display_name,
        'avatar_url', p.avatar_url, 'role', ygm.role
      ) order by case ygm.role when 'pastor' then 0 when 'leader' then 1 else 2 end, p.display_name)
      from public.youth_group_members ygm
      join public.profiles p on p.id = ygm.user_id
      where ygm.group_id = yg.id and ygm.role in ('pastor','leader')
    ), '[]'::jsonb),
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', e.id, 'title', e.title, 'description', e.description,
        'starts_at', e.starts_at, 'location', e.location,
        'cover_url', e.cover_url, 'capacity', e.capacity,
        'rsvp_audience', e.rsvp_audience
      ) order by e.starts_at)
      from public.events e
      where e.group_id = yg.id
        and e.starts_at >= now()
        and e.visibility = 'public'
    ), '[]'::jsonb),
    exists (
      select 1 from public.youth_group_members
      where group_id = yg.id and user_id = auth.uid()
    ),
    exists (
      select 1 from public.youth_group_join_requests
      where group_id = yg.id and user_id = auth.uid() and status = 'pending'
    ),
    yg.group_type,
    yg.grades
  from public.youth_groups yg
  where yg.id = _group_id
    and yg.is_public = true
    and yg.is_default_ygteev = false;
$$;

-- Eligibility backstop. Adults (grade_year IS NULL) and groups without
-- an audience configured (grades IS NULL) are unaffected — the gate
-- only fires when both sides are populated AND the student's grade
-- isn't in the group's allowed set.
create or replace function public.request_to_join_group(_group_id uuid, _message text default null)
returns public.youth_group_join_requests
language plpgsql security definer
set search_path = public
as $function$
declare
  _uid    uuid := auth.uid();
  _yg     public.youth_groups;
  _grade  integer;
  _result public.youth_group_join_requests;
begin
  if _uid is null then raise exception 'not_authenticated'; end if;

  select * into _yg from public.youth_groups where id = _group_id;
  if _yg.id is null              then raise exception 'group_not_found';            end if;
  if _yg.is_default_ygteev       then raise exception 'cannot_request_default_group'; end if;
  if not _yg.is_public           then raise exception 'group_not_public';            end if;

  if exists (
    select 1 from public.youth_group_members where group_id = _group_id and user_id = _uid
  ) then
    raise exception 'already_member';
  end if;

  -- Audience gate: only enforce when the group has declared its grades
  -- AND the requester has a recorded grade. Adults / "not a student"
  -- users pass through; pastor approval is the final filter for them.
  if _yg.grades is not null then
    select grade_year into _grade from public.profiles where id = _uid;
    if _grade is not null and not (_grade = any(_yg.grades)) then
      raise exception 'grade_not_eligible' using errcode = '42501';
    end if;
  end if;

  select * into _result
  from public.youth_group_join_requests
  where group_id = _group_id and user_id = _uid and status = 'pending';
  if _result.id is not null then return _result; end if;

  insert into public.youth_group_join_requests (group_id, user_id, message)
  values (_group_id, _uid, _message)
  returning * into _result;

  return _result;
end $function$;
