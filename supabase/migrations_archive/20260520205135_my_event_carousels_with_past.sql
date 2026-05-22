
-- v2 of my_event_carousels: returns both upcoming and past events per
-- person. Past = starts_at < now() but within the last 90 days, so the
-- "Past Events" carousel stays bounded.

create or replace function public.my_event_carousels()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid      uuid := auth.uid();
  v_self     jsonb;
  v_children jsonb;
begin
  if v_uid is null then
    raise exception 'not-authenticated';
  end if;

  with self_profile as (
    select id, display_name, avatar_url
    from public.profiles where id = v_uid
  ),
  self_events as (
    select
      r.status::text                                    as my_status,
      e.id                                              as event_id,
      e.title,
      e.description,
      e.starts_at,
      e.location,
      e.cover_url,
      yg.id                                             as group_id,
      yg.name                                           as group_name,
      yg.church_name                                    as group_church_name,
      yg.logo_url                                       as group_logo_url,
      yg.gradient_from                                  as group_gradient_from,
      yg.gradient_to                                    as group_gradient_to,
      (
        (select count(*)::int from public.event_rsvps r2
          where r2.event_id = e.id and r2.status::text = 'going')
        +
        (select count(*)::int from public.event_external_rsvps x
          where x.event_id = e.id and x.status = 'going'
            and x.converted_to_user_id is null)
      )                                                 as going_count,
      (e.starts_at > now())                             as is_upcoming
    from public.event_rsvps r
    join public.events e        on e.id  = r.event_id
    join public.youth_groups yg on yg.id = e.group_id
    where r.user_id = v_uid
      and r.status::text in ('going','maybe')
      and e.starts_at > now() - interval '90 days'
  )
  select jsonb_build_object(
    'user_id',      sp.id,
    'display_name', coalesce(sp.display_name, 'You'),
    'avatar_url',   sp.avatar_url,
    'upcoming',     coalesce(
      (select jsonb_agg(to_jsonb(se) order by se.starts_at asc)
       from self_events se where se.is_upcoming),
      '[]'::jsonb
    ),
    'past',         coalesce(
      (select jsonb_agg(to_jsonb(se) order by se.starts_at desc)
       from self_events se where not se.is_upcoming),
      '[]'::jsonb
    )
  )
  into v_self
  from self_profile sp;

  with my_families as (
    select family_id from public.family_members
    where user_id = v_uid and role = 'parent'
  ),
  kid_ids as (
    select distinct user_id
    from public.family_members
    where family_id in (select family_id from my_families)
      and role = 'child'
  ),
  kid_events as (
    select
      p.id                                              as kid_user_id,
      coalesce(p.display_name, p.handle, 'Family member') as kid_display_name,
      p.avatar_url                                      as kid_avatar_url,
      r.status::text                                    as my_status,
      e.id                                              as event_id,
      e.title,
      e.description,
      e.starts_at,
      e.location,
      e.cover_url,
      yg.id                                             as group_id,
      yg.name                                           as group_name,
      yg.church_name                                    as group_church_name,
      yg.logo_url                                       as group_logo_url,
      yg.gradient_from                                  as group_gradient_from,
      yg.gradient_to                                    as group_gradient_to,
      (
        (select count(*)::int from public.event_rsvps r2
          where r2.event_id = e.id and r2.status::text = 'going')
        +
        (select count(*)::int from public.event_external_rsvps x
          where x.event_id = e.id and x.status = 'going'
            and x.converted_to_user_id is null)
      )                                                 as going_count,
      (e.starts_at > now())                             as is_upcoming
    from public.profiles p
    join public.event_rsvps r on r.user_id = p.id
    join public.events e         on e.id  = r.event_id
    join public.youth_groups yg  on yg.id = e.group_id
    where p.id in (select user_id from kid_ids)
      and r.status::text in ('going','maybe')
      and e.starts_at > now() - interval '90 days'
  ),
  kid_blocks as (
    select
      ke.kid_user_id      as user_id,
      ke.kid_display_name as display_name,
      ke.kid_avatar_url   as avatar_url,
      coalesce((
        select jsonb_agg(
                 to_jsonb(t) - 'kid_user_id' - 'kid_display_name' - 'kid_avatar_url'
                 order by t.starts_at asc
               )
        from kid_events t
        where t.kid_user_id = ke.kid_user_id and t.is_upcoming
      ), '[]'::jsonb) as upcoming,
      coalesce((
        select jsonb_agg(
                 to_jsonb(t) - 'kid_user_id' - 'kid_display_name' - 'kid_avatar_url'
                 order by t.starts_at desc
               )
        from kid_events t
        where t.kid_user_id = ke.kid_user_id and not t.is_upcoming
      ), '[]'::jsonb) as past
    from kid_events ke
    group by ke.kid_user_id, ke.kid_display_name, ke.kid_avatar_url
  ),
  kid_blocks_all as (
    -- Include kids with zero events so we can still show their empty-state.
    select
      p.id                                                as user_id,
      coalesce(p.display_name, p.handle, 'Family member') as display_name,
      p.avatar_url                                        as avatar_url,
      coalesce(kb.upcoming, '[]'::jsonb)                  as upcoming,
      coalesce(kb.past,     '[]'::jsonb)                  as past
    from public.profiles p
    left join kid_blocks kb on kb.user_id = p.id
    where p.id in (select user_id from kid_ids)
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'user_id',      kb.user_id,
        'display_name', kb.display_name,
        'avatar_url',   kb.avatar_url,
        'upcoming',     kb.upcoming,
        'past',         kb.past
      )
      order by kb.display_name asc
    ),
    '[]'::jsonb
  )
  into v_children
  from kid_blocks_all kb;

  return jsonb_build_object(
    'self',     v_self,
    'children', v_children
  );
end;
$$;

grant execute on function public.my_event_carousels() to authenticated;
