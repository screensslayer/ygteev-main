
-- ---------- 1. PostGIS + lat/lng/location on youth_groups ----------
create extension if not exists postgis;

alter table public.youth_groups
  add column if not exists latitude  double precision,
  add column if not exists longitude double precision;

do $$ begin
  alter table public.youth_groups
    add constraint youth_groups_lat_range
    check (latitude  is null or latitude  between -90  and 90);
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.youth_groups
    add constraint youth_groups_lng_range
    check (longitude is null or longitude between -180 and 180);
exception when duplicate_object then null; end $$;

alter table public.youth_groups
  add column if not exists location geography(point, 4326)
  generated always as (
    case when latitude is not null and longitude is not null
         then st_setsrid(st_makepoint(longitude, latitude), 4326)::geography
    end
  ) stored;

create index if not exists youth_groups_location_idx
  on public.youth_groups using gist (location);

-- ---------- 2. youth_groups_near() RPC ----------
create or replace function public.youth_groups_near(
  _lat    double precision,
  _lng    double precision,
  _meters numeric default 25000
)
returns table (
  id            uuid,
  name          text,
  church_name   text,
  description   text,
  address       text,
  logo_url      text,
  gradient_from text,
  gradient_to   text,
  latitude      double precision,
  longitude     double precision,
  distance_m    double precision
)
language sql stable security definer set search_path = public as $$
  with origin as (
    select st_setsrid(st_makepoint(_lng, _lat), 4326)::geography as g
  )
  select
    yg.id, yg.name, yg.church_name, yg.description, yg.address,
    yg.logo_url, yg.gradient_from, yg.gradient_to,
    yg.latitude, yg.longitude,
    st_distance(yg.location, origin.g) as distance_m
  from public.youth_groups yg, origin
  where yg.location is not null
    and yg.is_public = true
    and yg.is_default_ygteev = false
    and st_dwithin(yg.location, origin.g, _meters)
  order by yg.location <-> origin.g;
$$;

-- ---------- 3. UUID-parse helper for storage policies ----------
create or replace function public.try_parse_uuid(_s text)
returns uuid language plpgsql immutable as $$
begin
  return _s::uuid;
exception when others then
  return null;
end $$;

-- ---------- 4. youth-group-logos storage bucket ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'youth-group-logos',
  'youth-group-logos',
  true,
  5242880,
  array['image/png','image/jpeg','image/webp','image/svg+xml']
)
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "logos: public read"         on storage.objects;
drop policy if exists "logos: pastor/admin write"  on storage.objects;
drop policy if exists "logos: pastor/admin update" on storage.objects;
drop policy if exists "logos: pastor/admin delete" on storage.objects;

create policy "logos: public read"
  on storage.objects for select
  using (bucket_id = 'youth-group-logos');

create policy "logos: pastor/admin write"
  on storage.objects for insert
  with check (
    bucket_id = 'youth-group-logos'
    and (
      public.is_site_admin(auth.uid())
      or public.is_group_pastor(
           auth.uid(),
           public.try_parse_uuid(split_part(name, '/', 1))
         )
    )
  );

create policy "logos: pastor/admin update"
  on storage.objects for update
  using (
    bucket_id = 'youth-group-logos'
    and (
      public.is_site_admin(auth.uid())
      or public.is_group_pastor(
           auth.uid(),
           public.try_parse_uuid(split_part(name, '/', 1))
         )
    )
  );

create policy "logos: pastor/admin delete"
  on storage.objects for delete
  using (
    bucket_id = 'youth-group-logos'
    and (
      public.is_site_admin(auth.uid())
      or public.is_group_pastor(
           auth.uid(),
           public.try_parse_uuid(split_part(name, '/', 1))
         )
    )
  );
