
drop function if exists public.youth_group_public_profile(uuid);

create function public.youth_group_public_profile(_group_id uuid)
returns table (
  id                       uuid,
  name                     text,
  church_name              text,
  description              text,
  address                  text,
  meeting_time             text,
  logo_url                 text,
  gradient_from            text,
  gradient_to              text,
  latitude                 double precision,
  longitude                double precision,
  member_count             integer,
  small_group_count        integer,
  leaders                  jsonb,
  upcoming_events          jsonb,
  viewer_is_member         boolean,
  viewer_pending_request   boolean
)
language sql stable security definer set search_path = public as $$
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
    )
  from public.youth_groups yg
  where yg.id = _group_id
    and yg.is_public = true
    and yg.is_default_ygteev = false;
$$;
