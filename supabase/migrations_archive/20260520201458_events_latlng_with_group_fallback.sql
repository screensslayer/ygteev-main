
-- Events get their own optional lat/lng so off-site events (camp,
-- bowling, retreat) can show in the right place on the map. The
-- public_events_nearby RPC prefers the event coords and falls back
-- to the host group's coords when null — that keeps every event
-- showing up somewhere, even if iOS's CLGeocoder couldn't resolve
-- the address string.

alter table public.events
  add column if not exists latitude  double precision,
  add column if not exists longitude double precision;

create index if not exists events_lat_lng_idx
  on public.events (latitude, longitude)
  where latitude is not null and longitude is not null;

-- Backfill existing public events from their host group's coords so
-- nothing regresses on the carousel after this migration.
update public.events e
set latitude  = yg.latitude,
    longitude = yg.longitude
from public.youth_groups yg
where yg.id = e.group_id
  and e.latitude  is null
  and e.longitude is null
  and e.visibility::text    = 'public'
  and e.rsvp_audience::text = 'public'
  and yg.latitude  is not null
  and yg.longitude is not null;

-- Re-create public_events_nearby preferring event coords when set.
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
      -- Prefer the event's own pin; fall back to the host group's.
      coalesce(e.latitude,  yg.latitude)                as r_use_lat,
      coalesce(e.longitude, yg.longitude)               as r_use_lng,
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
      and coalesce(yg.is_public, false) = true
      and coalesce(yg.is_default_ygteev, false) = false
      and coalesce(e.latitude,  yg.latitude)  is not null
      and coalesce(e.longitude, yg.longitude) is not null
  ),
  with_geo as (
    select
      b.*,
      (
        6371000.0 * 2 * asin(
          sqrt(
            power(sin(radians((b.r_use_lat - _lat) / 2)), 2)
            + cos(radians(_lat)) * cos(radians(b.r_use_lat))
              * power(sin(radians((b.r_use_lng - _lng) / 2)), 2)
          )
        )
      ) as r_distance_m
    from base b
  ),
  with_counts as (
    select
      g.*,
      coalesce((
        select count(*)::int
        from public.event_rsvps r
        where r.event_id   = g.r_event_id
          and r.status::text = 'going'
      ), 0)
      + coalesce((
        select count(*)::int
        from public.event_external_rsvps x
        where x.event_id   = g.r_event_id
          and x.status     = 'going'
          and x.converted_to_user_id is null
      ), 0) as r_going_count
    from with_geo g
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
