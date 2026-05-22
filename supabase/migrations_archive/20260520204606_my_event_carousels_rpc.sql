
-- Profile "My Events" + per-child carousels. One round trip from iOS.
--
-- Returns jsonb shaped:
--   {
--     "self": { user_id, display_name, avatar_url, events: [...] },
--     "children": [
--       { user_id, display_name, avatar_url, events: [...] },
--       ...
--     ]
--   }
--
-- Each event row carries enough to render a card without further joins.
-- Filter: rsvp status going|maybe, starts_at > now(). Sort: starts_at asc.
--
-- Children = family_members.role='child' in any family where caller is
-- a parent. SECURITY DEFINER so we can read the child's RSVPs + group
-- without bumping into RLS on those tables.

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
    from public.profiles
    where id = v_uid
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
      )                                                 as going_count
    from public.event_rsvps r
    join public.events e        on e.id  = r.event_id
    join public.youth_groups yg on yg.id = e.group_id
    where r.user_id = v_uid
      and r.status::text in ('going','maybe')
      and e.starts_at > now()
  )
  select jsonb_build_object(
    'user_id',      sp.id,
    'display_name', coalesce(sp.display_name, 'You'),
    'avatar_url',   sp.avatar_url,
    'events',       coalesce(
      (select jsonb_agg(to_jsonb(se) order by se.starts_at asc) from self_events se),
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
  kid_blocks as (
    select
      p.id                                              as user_id,
      coalesce(p.display_name, p.handle, 'Family member') as display_name,
      p.avatar_url,
      coalesce((
        select jsonb_agg(to_jsonb(t) order by t.starts_at asc)
        from (
          select
            r.status::text                              as my_status,
            e.id                                        as event_id,
            e.title,
            e.description,
            e.starts_at,
            e.location,
            e.cover_url,
            yg.id                                       as group_id,
            yg.name                                     as group_name,
            yg.church_name                              as group_church_name,
            yg.logo_url                                 as group_logo_url,
            yg.gradient_from                            as group_gradient_from,
            yg.gradient_to                              as group_gradient_to,
            (
              (select count(*)::int from public.event_rsvps r2
                where r2.event_id = e.id and r2.status::text = 'going')
              +
              (select count(*)::int from public.event_external_rsvps x
                where x.event_id = e.id and x.status = 'going'
                  and x.converted_to_user_id is null)
            )                                           as going_count
          from public.event_rsvps r
          join public.events e        on e.id  = r.event_id
          join public.youth_groups yg on yg.id = e.group_id
          where r.user_id = p.id
            and r.status::text in ('going','maybe')
            and e.starts_at > now()
        ) t
      ), '[]'::jsonb)                                    as events
    from public.profiles p
    where p.id in (select user_id from kid_ids)
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'user_id',      kb.user_id,
        'display_name', kb.display_name,
        'avatar_url',   kb.avatar_url,
        'events',       kb.events
      )
      order by kb.display_name asc
    ),
    '[]'::jsonb
  )
  into v_children
  from kid_blocks kb;

  return jsonb_build_object(
    'self',     v_self,
    'children', v_children
  );
end;
$$;

grant execute on function public.my_event_carousels() to authenticated;
