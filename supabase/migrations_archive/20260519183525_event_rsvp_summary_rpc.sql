-- Single round-trip for an event detail screen: counts, ordered name +
-- avatar lists per status, and the caller's own RSVP. Caller must be a
-- group member (or the event must be public) to see anything beyond
-- their own status.

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
           p.display_name, p.handle, p.avatar_url
    from public.event_rsvps r
    join public.profiles p on p.id = r.user_id
    where r.event_id = _event_id
  )
  select
    (select count(*)::int from rs where status = 'going')              as going_count,
    (select count(*)::int from rs where status = 'maybe')              as maybe_count,
    (select count(*)::int from rs where status = 'declined')           as declined_count,
    (select count(*)::int from rs)                                     as total_count,
    coalesce(
      (select jsonb_agg(jsonb_build_object(
         'user_id', user_id, 'display_name', display_name,
         'handle', handle, 'avatar_url', avatar_url,
         'rsvp_at', created_at) order by created_at)
       from rs where status = 'going'),
      '[]'::jsonb) as going,
    coalesce(
      (select jsonb_agg(jsonb_build_object(
         'user_id', user_id, 'display_name', display_name,
         'handle', handle, 'avatar_url', avatar_url,
         'rsvp_at', created_at) order by created_at)
       from rs where status = 'maybe'),
      '[]'::jsonb) as maybe,
    coalesce(
      (select jsonb_agg(jsonb_build_object(
         'user_id', user_id, 'display_name', display_name,
         'handle', handle, 'avatar_url', avatar_url,
         'rsvp_at', created_at) order by created_at)
       from rs where status = 'declined'),
      '[]'::jsonb) as declined,
    (select status::text from rs where user_id = v_uid limit 1) as viewer_status;
end;
$$;

grant execute on function public.event_rsvp_summary(uuid) to authenticated, service_role;
