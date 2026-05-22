
-- ---------- event_media kind enum ----------
do $$ begin
  create type public.event_media_kind as enum ('photo','video');
exception when duplicate_object then null; end $$;

-- ---------- event_media table ----------
create table if not exists public.event_media (
  id           uuid primary key default gen_random_uuid(),
  event_id     uuid not null references public.events(id) on delete cascade,
  kind         public.event_media_kind not null,
  storage_path text,
  video_id     uuid references public.videos(id) on delete set null,
  caption      text,
  uploaded_by  uuid references auth.users(id) on delete set null,
  created_at   timestamptz not null default now(),
  constraint event_media_payload_check check (
    (kind = 'photo' and storage_path is not null) or
    (kind = 'video' and (storage_path is not null or video_id is not null))
  )
);

create index if not exists event_media_event_idx on public.event_media(event_id);
create index if not exists event_media_kind_idx  on public.event_media(kind);

alter table public.event_media enable row level security;

drop policy if exists "event_media: members read"        on public.event_media;
drop policy if exists "event_media: pastor/admin manage" on public.event_media;

-- Read: members of the event's group, or site admin
create policy "event_media: members read" on public.event_media for select using (
  public.is_site_admin(auth.uid())
  or exists (
    select 1 from public.events e
    where e.id = event_id
      and public.is_group_member(auth.uid(), e.group_id)
  )
);

-- Write: pastor/leader of the event's group, or site admin
create policy "event_media: pastor/admin manage" on public.event_media for all using (
  public.is_site_admin(auth.uid())
  or exists (
    select 1 from public.events e
    where e.id = event_id
      and public.is_group_pastor(auth.uid(), e.group_id)
  )
) with check (
  public.is_site_admin(auth.uid())
  or exists (
    select 1 from public.events e
    where e.id = event_id
      and public.is_group_pastor(auth.uid(), e.group_id)
  )
);

-- ---------- event-media storage bucket (PRIVATE, signed URLs) ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'event-media',
  'event-media',
  false,
  52428800,
  array['image/png','image/jpeg','image/webp','image/heic','image/heif','video/mp4','video/quicktime']
)
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "event-media: members read"   on storage.objects;
drop policy if exists "event-media: pastor write"   on storage.objects;
drop policy if exists "event-media: pastor update"  on storage.objects;
drop policy if exists "event-media: pastor delete"  on storage.objects;

-- Members of the group at folder[0] can generate signed URLs
create policy "event-media: members read"
  on storage.objects for select using (
    bucket_id = 'event-media'
    and (
      public.is_site_admin(auth.uid())
      or exists (
        select 1 from public.youth_group_members
        where user_id = auth.uid()
          and group_id = public.try_parse_uuid(split_part(name, '/', 1))
      )
    )
  );

create policy "event-media: pastor write"
  on storage.objects for insert with check (
    bucket_id = 'event-media'
    and (
      public.is_site_admin(auth.uid())
      or public.is_group_pastor(auth.uid(), public.try_parse_uuid(split_part(name, '/', 1)))
    )
  );

create policy "event-media: pastor update"
  on storage.objects for update using (
    bucket_id = 'event-media'
    and (
      public.is_site_admin(auth.uid())
      or public.is_group_pastor(auth.uid(), public.try_parse_uuid(split_part(name, '/', 1)))
    )
  );

create policy "event-media: pastor delete"
  on storage.objects for delete using (
    bucket_id = 'event-media'
    and (
      public.is_site_admin(auth.uid())
      or public.is_group_pastor(auth.uid(), public.try_parse_uuid(split_part(name, '/', 1)))
    )
  );
