
-- ---------- 1. RSVP audience enum + column ----------
do $$ begin
  create type public.event_rsvp_audience as enum ('members_only', 'public');
exception when duplicate_object then null; end $$;

alter table public.events
  add column if not exists rsvp_audience public.event_rsvp_audience not null default 'members_only';

-- Consistency: a group-private event cannot have a public RSVP audience.
do $$ begin
  alter table public.events
    add constraint events_rsvp_audience_consistent
    check (visibility = 'public' or rsvp_audience = 'members_only');
exception when duplicate_object then null; end $$;

-- ---------- 2. Refresh RSVP RLS so public events accept non-member RSVPs ----------
drop policy if exists "rsvps: member self insert"      on public.event_rsvps;
drop policy if exists "rsvps: read by group members"   on public.event_rsvps;
drop policy if exists "rsvps: self update"             on public.event_rsvps;
drop policy if exists "rsvps: self delete"             on public.event_rsvps;

create policy "rsvps: self insert" on public.event_rsvps for insert
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.events e
      where e.id = event_id
        and (
          public.is_group_member(auth.uid(), e.group_id)
          or (e.rsvp_audience = 'public' and e.visibility = 'public')
        )
    )
  );

create policy "rsvps: read" on public.event_rsvps for select using (
  user_id = auth.uid()
  or public.is_site_admin(auth.uid())
  or exists (
    select 1 from public.events e
    where e.id = event_id
      and public.is_group_member(auth.uid(), e.group_id)
  )
);

create policy "rsvps: self update" on public.event_rsvps for update
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "rsvps: self delete" on public.event_rsvps for delete
  using (auth.uid() = user_id);

-- ---------- 3. event-covers storage bucket ----------
-- Path convention: {group_id}/{filename}
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'event-covers',
  'event-covers',
  true,
  5242880,
  array['image/png','image/jpeg','image/webp','image/svg+xml']
)
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "event-covers: public read"          on storage.objects;
drop policy if exists "event-covers: pastor/admin write"   on storage.objects;
drop policy if exists "event-covers: pastor/admin update"  on storage.objects;
drop policy if exists "event-covers: pastor/admin delete"  on storage.objects;

create policy "event-covers: public read"
  on storage.objects for select using (bucket_id = 'event-covers');

create policy "event-covers: pastor/admin write"
  on storage.objects for insert
  with check (
    bucket_id = 'event-covers'
    and (
      public.is_site_admin(auth.uid())
      or public.is_group_pastor(
           auth.uid(),
           public.try_parse_uuid(split_part(name, '/', 1))
         )
    )
  );

create policy "event-covers: pastor/admin update"
  on storage.objects for update
  using (
    bucket_id = 'event-covers'
    and (
      public.is_site_admin(auth.uid())
      or public.is_group_pastor(
           auth.uid(),
           public.try_parse_uuid(split_part(name, '/', 1))
         )
    )
  );

create policy "event-covers: pastor/admin delete"
  on storage.objects for delete
  using (
    bucket_id = 'event-covers'
    and (
      public.is_site_admin(auth.uid())
      or public.is_group_pastor(
           auth.uid(),
           public.try_parse_uuid(split_part(name, '/', 1))
         )
    )
  );

-- ---------- 4. Surface rsvp_audience + capacity in the public-profile RPC ----------
create or replace function public.youth_group_public_profile(_group_id uuid)
returns table (
  id                uuid,
  name              text,
  church_name       text,
  description       text,
  address           text,
  meeting_time      text,
  logo_url          text,
  gradient_from     text,
  gradient_to       text,
  latitude          double precision,
  longitude         double precision,
  member_count      integer,
  small_group_count integer,
  leaders           jsonb,
  upcoming_events   jsonb
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
        'id',           p.id,
        'display_name', p.display_name,
        'avatar_url',   p.avatar_url,
        'role',         ygm.role
      ) order by case ygm.role when 'pastor' then 0 when 'leader' then 1 else 2 end, p.display_name)
      from public.youth_group_members ygm
      join public.profiles p on p.id = ygm.user_id
      where ygm.group_id = yg.id and ygm.role in ('pastor','leader')
    ), '[]'::jsonb),
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',            e.id,
        'title',         e.title,
        'description',   e.description,
        'starts_at',     e.starts_at,
        'location',      e.location,
        'cover_url',     e.cover_url,
        'capacity',      e.capacity,
        'rsvp_audience', e.rsvp_audience
      ) order by e.starts_at)
      from public.events e
      where e.group_id = yg.id
        and e.starts_at >= now()
        and e.visibility = 'public'
    ), '[]'::jsonb)
  from public.youth_groups yg
  where yg.id = _group_id
    and yg.is_public = true
    and yg.is_default_ygteev = false;
$$;
