-- Extend event_rsvp_summary so each participant row carries the user's
-- role in this event's youth group (pastor / leader / member) and
-- their `profiles.grade_year`. Pastors viewing the RSVP list need both
-- to triage who's coming. "leader" here = small-group leader anywhere
-- inside this youth group; "pastor" trumps "leader" trumps "member".

create or replace function public.event_rsvp_summary(_event_id uuid)
returns table(
  going_count    int,
  maybe_count    int,
  declined_count int,
  total_count    int,
  going    jsonb,
  maybe    jsonb,
  declined jsonb,
  viewer_status text
)
language plpgsql stable security definer
set search_path = public
as $$
declare
  v_event public.events;
  v_uid uuid := auth.uid();
  v_can_see boolean;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select * into v_event from public.events where id = _event_id;
  if v_event.id is null then raise exception 'event_not_found'; end if;

  v_can_see :=
       public.is_site_admin(v_uid)
    or public.is_group_member(v_uid, v_event.group_id)
    or v_event.visibility = 'public';
  if not v_can_see then raise exception 'forbidden' using errcode = '42501'; end if;

  return query
  with rs as (
    select r.user_id, r.status, r.created_at,
           p.display_name, p.handle, p.avatar_url, p.grade_year,
           ygm.role::text as yg_role,
           exists (
             select 1
             from public.small_group_members sgm
             join public.small_groups sg on sg.id = sgm.small_group_id
             where sgm.user_id = r.user_id
               and sgm.role    = 'leader'
               and sg.youth_group_id = v_event.group_id
           ) as is_sg_leader
    from public.event_rsvps r
    join public.profiles p on p.id = r.user_id
    left join public.youth_group_members ygm
      on ygm.user_id = r.user_id and ygm.group_id = v_event.group_id
    where r.event_id = _event_id
  ),
  rs_with_role as (
    select
      user_id, status, created_at,
      display_name, handle, avatar_url, grade_year,
      case
        when yg_role = 'pastor' then 'pastor'
        when is_sg_leader        then 'leader'
        when yg_role is not null then 'member'
        else null
      end as role_label
    from rs
  )
  select
    (select count(*)::int from rs_with_role where status = 'going')              as going_count,
    (select count(*)::int from rs_with_role where status = 'maybe')              as maybe_count,
    (select count(*)::int from rs_with_role where status = 'declined')           as declined_count,
    (select count(*)::int from rs_with_role)                                     as total_count,
    coalesce(
      (select jsonb_agg(jsonb_build_object(
         'user_id', user_id, 'display_name', display_name,
         'handle', handle, 'avatar_url', avatar_url,
         'grade_year', grade_year, 'role', role_label,
         'rsvp_at', created_at) order by created_at)
       from rs_with_role where status = 'going'),
      '[]'::jsonb) as going,
    coalesce(
      (select jsonb_agg(jsonb_build_object(
         'user_id', user_id, 'display_name', display_name,
         'handle', handle, 'avatar_url', avatar_url,
         'grade_year', grade_year, 'role', role_label,
         'rsvp_at', created_at) order by created_at)
       from rs_with_role where status = 'maybe'),
      '[]'::jsonb) as maybe,
    coalesce(
      (select jsonb_agg(jsonb_build_object(
         'user_id', user_id, 'display_name', display_name,
         'handle', handle, 'avatar_url', avatar_url,
         'grade_year', grade_year, 'role', role_label,
         'rsvp_at', created_at) order by created_at)
       from rs_with_role where status = 'declined'),
      '[]'::jsonb) as declined,
    (select status::text from rs_with_role where user_id = v_uid limit 1) as viewer_status;
end;
$$;
