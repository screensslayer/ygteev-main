
-- =============================================================================
-- For You feed — Phase 1: foundation (corrected: uses inline touch fn)
-- =============================================================================

create table if not exists public.feed_posts (
  id            uuid primary key default gen_random_uuid(),
  post_type     text not null check (post_type in ('video','slideshow')),
  scope         text not null check (scope in ('ygteev_official','group')),
  group_id      uuid references public.youth_groups(id) on delete cascade,
  source_kind   text not null
                check (source_kind in (
                  'pastor_upload','ygteev_curated','instagram_scrape','cross_group_approved'
                )),
  source_url     text,
  source_handle  text,
  source_post_id text,
  title         text,
  caption       text,
  video_id      uuid references public.videos(id) on delete set null,
  slideshow_seconds_per_photo numeric default 3.0
    check (slideshow_seconds_per_photo is null
           or slideshow_seconds_per_photo between 1 and 10),
  status        text not null default 'draft'
                check (status in ('draft','pending_approval','published','archived')),
  published_at  timestamptz,
  views_count   int not null default 0,
  likes_count   int not null default 0,
  created_by    uuid references public.profiles(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint feed_posts_scope_group_check check (
    (scope = 'group'           and group_id is not null)
    or
    (scope = 'ygteev_official' and group_id is null)
  )
);

create index if not exists feed_posts_published_idx
  on public.feed_posts(published_at desc nulls last) where status = 'published';
create index if not exists feed_posts_group_published_idx
  on public.feed_posts(group_id, published_at desc nulls last) where status = 'published';
create unique index if not exists feed_posts_source_post_unique_idx
  on public.feed_posts(source_handle, source_post_id) where source_post_id is not null;

-- Inline touch_updated_at helper (idempotent)
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;

drop trigger if exists trg_feed_posts_touch on public.feed_posts;
create trigger trg_feed_posts_touch
before update on public.feed_posts
for each row execute function public.set_updated_at();


create table if not exists public.feed_post_photos (
  id            uuid primary key default gen_random_uuid(),
  post_id       uuid not null references public.feed_posts(id) on delete cascade,
  storage_path  text not null,
  display_order int not null default 0,
  alt_text      text,
  created_at    timestamptz not null default now(),
  unique (post_id, display_order)
);
create index if not exists feed_post_photos_post_idx on public.feed_post_photos(post_id);


create table if not exists public.feed_post_engagement (
  id                 uuid primary key default gen_random_uuid(),
  post_id            uuid not null references public.feed_posts(id) on delete cascade,
  user_id            uuid not null references public.profiles(id) on delete cascade,
  first_viewed_at    timestamptz,
  watch_completed_at timestamptz,
  liked_at           timestamptz,
  unique (post_id, user_id)
);
create index if not exists feed_post_engagement_user_idx on public.feed_post_engagement(user_id);
create index if not exists feed_post_engagement_post_idx on public.feed_post_engagement(post_id);

create or replace function public.tg_feed_post_engagement_recount()
returns trigger language plpgsql security definer set search_path = public as $func$
declare v_post uuid;
begin
  v_post := coalesce(new.post_id, old.post_id);
  update public.feed_posts
    set views_count = (select count(*) from public.feed_post_engagement
                        where post_id = v_post and first_viewed_at is not null),
        likes_count = (select count(*) from public.feed_post_engagement
                        where post_id = v_post and liked_at is not null),
        updated_at  = now()
    where id = v_post;
  return coalesce(new, old);
end;
$func$;

drop trigger if exists trg_feed_post_engagement_recount on public.feed_post_engagement;
create trigger trg_feed_post_engagement_recount
after insert or update or delete on public.feed_post_engagement
for each row execute function public.tg_feed_post_engagement_recount();


-- RLS ------------------------------------------------------------------------
alter table public.feed_posts            enable row level security;
alter table public.feed_post_photos      enable row level security;
alter table public.feed_post_engagement  enable row level security;

drop policy if exists "feed_posts: read" on public.feed_posts;
create policy "feed_posts: read" on public.feed_posts
for select using (
  public.is_site_admin(auth.uid())
  or (status = 'published' and (
        scope = 'ygteev_official'
        or (scope = 'group' and exists (
              select 1 from public.youth_group_members ygm
              where ygm.group_id = feed_posts.group_id
                and ygm.user_id = auth.uid()))
  ))
  or (scope = 'group' and public.is_group_pastor(auth.uid(), group_id))
);

drop policy if exists "feed_posts: pastor manage" on public.feed_posts;
create policy "feed_posts: pastor manage" on public.feed_posts
for all using (
  public.is_site_admin(auth.uid())
  or (scope = 'group' and public.is_group_pastor(auth.uid(), group_id))
) with check (
  public.is_site_admin(auth.uid())
  or (scope = 'group' and public.is_group_pastor(auth.uid(), group_id))
);

drop policy if exists "feed_post_photos: read" on public.feed_post_photos;
create policy "feed_post_photos: read" on public.feed_post_photos
for select using (
  exists (
    select 1 from public.feed_posts fp
    where fp.id = feed_post_photos.post_id
      and (
        public.is_site_admin(auth.uid())
        or (fp.status = 'published' and (
              fp.scope = 'ygteev_official'
              or (fp.scope = 'group' and exists (
                    select 1 from public.youth_group_members
                    where group_id = fp.group_id and user_id = auth.uid()))
        ))
        or (fp.scope = 'group' and public.is_group_pastor(auth.uid(), fp.group_id))
      )
  )
);

drop policy if exists "feed_post_photos: pastor manage" on public.feed_post_photos;
create policy "feed_post_photos: pastor manage" on public.feed_post_photos
for all using (
  exists (
    select 1 from public.feed_posts fp
    where fp.id = feed_post_photos.post_id
      and (
        public.is_site_admin(auth.uid())
        or (fp.scope = 'group' and public.is_group_pastor(auth.uid(), fp.group_id))
      )
  )
) with check (
  exists (
    select 1 from public.feed_posts fp
    where fp.id = feed_post_photos.post_id
      and (
        public.is_site_admin(auth.uid())
        or (fp.scope = 'group' and public.is_group_pastor(auth.uid(), fp.group_id))
      )
  )
);

drop policy if exists "feed_post_engagement: self read"   on public.feed_post_engagement;
create policy "feed_post_engagement: self read" on public.feed_post_engagement
for select using (user_id = auth.uid() or public.is_site_admin(auth.uid()));

drop policy if exists "feed_post_engagement: self write"  on public.feed_post_engagement;
create policy "feed_post_engagement: self write" on public.feed_post_engagement
for insert with check (user_id = auth.uid());

drop policy if exists "feed_post_engagement: self update" on public.feed_post_engagement;
create policy "feed_post_engagement: self update" on public.feed_post_engagement
for update using (user_id = auth.uid()) with check (user_id = auth.uid());


-- Storage bucket for slideshow photos ---------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'feed-photos', 'feed-photos', true, 10485760,
  array['image/png','image/jpeg','image/webp','image/heic','image/heif']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "feed-photos: public read" on storage.objects;
create policy "feed-photos: public read" on storage.objects
for select using (bucket_id = 'feed-photos');

drop policy if exists "feed-photos: pastor write" on storage.objects;
create policy "feed-photos: pastor write" on storage.objects
for insert with check (
  bucket_id = 'feed-photos' and (
    public.is_site_admin(auth.uid())
    or exists (
      select 1 from public.feed_posts fp
      where fp.id = public.try_parse_uuid(split_part(name, '/', 1))
        and fp.scope = 'group'
        and public.is_group_pastor(auth.uid(), fp.group_id)
    )
  )
);

drop policy if exists "feed-photos: pastor update" on storage.objects;
create policy "feed-photos: pastor update" on storage.objects
for update using (
  bucket_id = 'feed-photos' and (
    public.is_site_admin(auth.uid())
    or exists (
      select 1 from public.feed_posts fp
      where fp.id = public.try_parse_uuid(split_part(name, '/', 1))
        and fp.scope = 'group'
        and public.is_group_pastor(auth.uid(), fp.group_id)
    )
  )
);

drop policy if exists "feed-photos: pastor delete" on storage.objects;
create policy "feed-photos: pastor delete" on storage.objects
for delete using (
  bucket_id = 'feed-photos' and (
    public.is_site_admin(auth.uid())
    or exists (
      select 1 from public.feed_posts fp
      where fp.id = public.try_parse_uuid(split_part(name, '/', 1))
        and fp.scope = 'group'
        and public.is_group_pastor(auth.uid(), fp.group_id)
    )
  )
);

notify pgrst, 'reload schema';
