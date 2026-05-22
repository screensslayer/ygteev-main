
create or replace function public.public_events_nearby(
  _lat       double precision,
  _lng       double precision,
  _radius_m  integer default 50000,
  _limit     integer default 20
)
returns table (
  event_id            uuid,
  title               text,
  description         text,
  starts_at           timestamptz,
  location            text,
  cover_url           text,
  group_id            uuid,
  group_name          text,
  group_church_name   text,
  group_logo_url      text,
  group_gradient_from text,
  group_gradient_to   text,
  going_count         integer,
  distance_m          double precision,
  is_my_group_event   boolean
)
language sql
stable
security definer
set search_path = public
as $$
  with base as (
    select
      e.id                                              as r_event_id,
      e.title                                           as r_title,
      e.description                                     as r_description,
      e.starts_at                                       as r_starts_at,
      e.location                                        as r_location,
      e.cover_url                                       as r_cover_url,
      yg.id                                             as r_group_id,
      yg.name                                           as r_group_name,
      yg.church_name                                    as r_group_church_name,
      yg.logo_url                                       as r_group_logo_url,
      yg.gradient_from                                  as r_group_gradient_from,
      yg.gradient_to                                    as r_group_gradient_to,
      (
        6371000.0 * 2 * asin(
          sqrt(
            power(sin(radians((yg.latitude - _lat) / 2)), 2)
            + cos(radians(_lat)) * cos(radians(yg.latitude))
              * power(sin(radians((yg.longitude - _lng) / 2)), 2)
          )
        )
      ) as r_distance_m,
      exists (
        select 1 from public.youth_group_members ygm
        where ygm.group_id = yg.id
          and ygm.user_id  = auth.uid()
      ) as r_is_my_group_event
    from public.events e
    join public.youth_groups yg on yg.id = e.group_id
    where e.visibility::text    = 'public'
      and e.rsvp_audience::text = 'public'
      and e.starts_at > now()
      and yg.latitude  is not null
      and yg.longitude is not null
      and coalesce(yg.is_public, false) = true
      and coalesce(yg.is_default_ygteev, false) = false
  ),
  with_counts as (
    select
      b.*,
      coalesce((
        select count(*)::int
        from public.event_rsvps r
        where r.event_id   = b.r_event_id
          and r.status::text = 'going'
      ), 0)
      + coalesce((
        select count(*)::int
        from public.event_external_rsvps x
        where x.event_id   = b.r_event_id
          and x.status     = 'going'
          and x.converted_to_user_id is null
      ), 0) as r_going_count
    from base b
  )
  select
    r_event_id, r_title, r_description, r_starts_at, r_location, r_cover_url,
    r_group_id, r_group_name, r_group_church_name, r_group_logo_url,
    r_group_gradient_from, r_group_gradient_to,
    r_going_count, r_distance_m, r_is_my_group_event
  from with_counts
  where r_distance_m <= _radius_m
  order by r_starts_at asc, r_distance_m asc
  limit greatest(_limit, 1);
$$;

grant execute on function public.public_events_nearby(double precision, double precision, integer, integer)
  to authenticated;


create or replace function public.rsvp_public_event(
  _event_id uuid,
  _status   text default 'going'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid     uuid := auth.uid();
  v_event   public.events;
  v_going   integer;
  v_outside integer;
begin
  if v_uid is null then
    raise exception 'not-authenticated';
  end if;
  if _status not in ('going','maybe','declined') then
    raise exception 'invalid-status: %', _status;
  end if;

  select * into v_event from public.events where id = _event_id;
  if v_event.id is null then
    raise exception 'event-not-found';
  end if;
  if v_event.visibility::text <> 'public' or v_event.rsvp_audience::text <> 'public' then
    raise exception 'event-not-public';
  end if;

  insert into public.event_rsvps (event_id, user_id, status)
  values (_event_id, v_uid, _status::event_rsvp_status)
  on conflict (event_id, user_id) do update
    set status = excluded.status;

  select count(*)::int into v_going
  from public.event_rsvps
  where event_id = _event_id and status::text = 'going';

  select count(*)::int into v_outside
  from public.event_external_rsvps
  where event_id = _event_id and status = 'going'
    and converted_to_user_id is null;

  return jsonb_build_object(
    'ok',           true,
    'event_id',     _event_id,
    'my_status',    _status,
    'going_count',  v_going + v_outside
  );
end;
$$;

grant execute on function public.rsvp_public_event(uuid, text) to authenticated;
