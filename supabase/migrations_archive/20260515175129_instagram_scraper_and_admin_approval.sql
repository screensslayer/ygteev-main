
-- =============================================================================
-- Phase 3 + 4: Instagram scraper + cross-group approval to YGTeeV official
-- =============================================================================

-- 1. Per-group IG source config -------------------------------------------
create table if not exists public.instagram_sources (
  id              uuid primary key default gen_random_uuid(),
  group_id        uuid not null references public.youth_groups(id) on delete cascade,
  handle          text not null,                       -- e.g. "gracecityyouth" (no @)
  is_active       boolean not null default true,
  added_by        uuid references public.profiles(id) on delete set null,
  added_at        timestamptz not null default now(),
  last_scraped_at timestamptz,
  unique (group_id, handle)
);
create index if not exists instagram_sources_active_idx
  on public.instagram_sources(group_id) where is_active = true;

alter table public.instagram_sources enable row level security;

drop policy if exists "ig_sources: pastor manage" on public.instagram_sources;
create policy "ig_sources: pastor manage" on public.instagram_sources
  for all using (
    public.is_site_admin(auth.uid())
    or public.is_group_pastor(auth.uid(), group_id)
  ) with check (
    public.is_site_admin(auth.uid())
    or public.is_group_pastor(auth.uid(), group_id)
  );


-- 2. Scrape job audit log -------------------------------------------------
create table if not exists public.instagram_scrape_jobs (
  id               uuid primary key default gen_random_uuid(),
  source_id        uuid references public.instagram_sources(id) on delete set null,
  apify_run_id     text,
  apify_dataset_id text,
  status           text not null default 'started'
                   check (status in ('started','succeeded','failed','timeout')),
  started_at       timestamptz not null default now(),
  finished_at      timestamptz,
  new_posts_count  int default 0,
  error_message    text
);
create index if not exists instagram_scrape_jobs_started_idx
  on public.instagram_scrape_jobs(started_at desc);
create index if not exists instagram_scrape_jobs_run_idx
  on public.instagram_scrape_jobs(apify_run_id);

alter table public.instagram_scrape_jobs enable row level security;
drop policy if exists "ig_jobs: pastor/admin read" on public.instagram_scrape_jobs;
create policy "ig_jobs: pastor/admin read" on public.instagram_scrape_jobs
  for select using (
    public.is_site_admin(auth.uid())
    or exists (
      select 1 from public.instagram_sources s
      where s.id = instagram_scrape_jobs.source_id
        and public.is_group_pastor(auth.uid(), s.group_id)
    )
  );


-- 3. RPCs for the pastor/admin to manage IG sources ------------------------
create or replace function public.pastor_set_instagram_source(
  _group_id uuid,
  _handle   text
) returns uuid
language plpgsql security definer set search_path = public as $func$
declare
  v_caller uuid := auth.uid();
  v_clean text;
  v_id uuid;
begin
  if v_caller is null then raise exception 'not_authenticated'; end if;
  if not (public.is_site_admin(v_caller) or public.is_group_pastor(v_caller, _group_id)) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  -- Sanitize: strip leading @ and whitespace
  v_clean := regexp_replace(coalesce(_handle, ''), '^[\s@]+|\s+$', '', 'g');
  v_clean := lower(v_clean);
  if v_clean = '' then raise exception 'handle_required'; end if;

  insert into public.instagram_sources (group_id, handle, added_by, is_active)
    values (_group_id, v_clean, v_caller, true)
    on conflict (group_id, handle) do update
      set is_active = true,
          added_by  = excluded.added_by
    returning id into v_id;

  return v_id;
end;
$func$;
grant execute on function public.pastor_set_instagram_source(uuid, text) to authenticated;


create or replace function public.pastor_clear_instagram_source(_source_id uuid)
returns void
language plpgsql security definer set search_path = public as $func$
declare v_group uuid;
begin
  select group_id into v_group from public.instagram_sources where id = _source_id;
  if v_group is null then raise exception 'source_not_found'; end if;

  if not (public.is_site_admin(auth.uid()) or public.is_group_pastor(auth.uid(), v_group)) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  update public.instagram_sources set is_active = false where id = _source_id;
end;
$func$;
grant execute on function public.pastor_clear_instagram_source(uuid) to authenticated;


-- 4. Site-admin RPC: list every group's published posts for cross-group review
create or replace function public.admin_list_all_group_posts(_limit int default 100)
returns table (
  post_id        uuid,
  post_type      text,
  group_id       uuid,
  group_name     text,
  title          text,
  caption        text,
  source_kind    text,
  source_handle  text,
  video_id       uuid,
  mux_playback_id text,
  duration_sec   numeric,
  photos         jsonb,
  views_count    int,
  likes_count    int,
  published_at   timestamptz,
  already_in_official boolean
)
language sql stable security definer set search_path = public as $func$
  select
    fp.id, fp.post_type, fp.group_id, yg.name, fp.title, fp.caption,
    fp.source_kind, fp.source_handle,
    fp.video_id, v.mux_playback_id, v.duration_sec,
    coalesce(
      (select jsonb_agg(jsonb_build_object(
                'storage_path', ph.storage_path,
                'display_order', ph.display_order,
                'public_url',
                  'https://tkesywmshaicjmywbovn.supabase.co/storage/v1/object/public/feed-photos/' || ph.storage_path
              ) order by ph.display_order)
         from public.feed_post_photos ph where ph.post_id = fp.id),
      '[]'::jsonb
    ),
    fp.views_count, fp.likes_count, fp.published_at,
    exists (
      select 1 from public.feed_posts dup
      where dup.scope = 'ygteev_official'
        and dup.video_id is not distinct from fp.video_id
        and dup.title is not distinct from fp.title
    )
  from public.feed_posts fp
  left join public.youth_groups yg on yg.id = fp.group_id
  left join public.videos v on v.id = fp.video_id
  where fp.scope = 'group' and fp.status = 'published'
    and public.is_site_admin(auth.uid())
  order by fp.published_at desc nulls last
  limit greatest(1, least(_limit, 500));
$func$;
grant execute on function public.admin_list_all_group_posts(int) to authenticated;


-- 5. Site-admin RPC: approve a group post into the YGTeeV official feed -----
-- Duplicates the post under scope='ygteev_official' + cross_group_approved.
-- Video posts share the same video_id (Mux asset is reused, not re-uploaded).
-- Slideshow posts get fresh feed_post_photos rows pointing to the same storage paths.
create or replace function public.admin_approve_to_official(_source_post_id uuid)
returns uuid    -- new official post id
language plpgsql security definer set search_path = public as $func$
declare
  v_src public.feed_posts;
  v_new_id uuid;
begin
  if not public.is_site_admin(auth.uid()) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  select * into v_src from public.feed_posts where id = _source_post_id;
  if v_src.id is null then raise exception 'post_not_found'; end if;

  insert into public.feed_posts (
    post_type, scope, group_id, source_kind, source_url, source_handle, source_post_id,
    title, caption, video_id, slideshow_seconds_per_photo,
    status, published_at, created_by
  ) values (
    v_src.post_type, 'ygteev_official', null,
    'cross_group_approved', v_src.source_url, v_src.source_handle, v_src.source_post_id,
    v_src.title, v_src.caption, v_src.video_id, v_src.slideshow_seconds_per_photo,
    'published', now(), auth.uid()
  )
  returning id into v_new_id;

  -- For slideshows: copy the photo rows over (same storage_paths)
  if v_src.post_type = 'slideshow' then
    insert into public.feed_post_photos (post_id, storage_path, display_order, alt_text)
    select v_new_id, storage_path, display_order, alt_text
    from public.feed_post_photos where post_id = _source_post_id;
  end if;

  return v_new_id;
end;
$func$;
grant execute on function public.admin_approve_to_official(uuid) to authenticated;


-- 6. Cron: every 6 hours, hit the trigger-instagram-scrapes Edge Function ---
-- Uses pg_net with the project's anon key as the bearer; the Edge Function
-- verify_jwt is on and the cron also passes a shared CRON_SECRET header so we
-- can tell apart real cron calls from random anon calls.
do $$
begin
  if exists (select 1 from cron.job where jobname = 'instagram-scraper-6h') then
    perform cron.unschedule('instagram-scraper-6h');
  end if;
end $$;

select cron.schedule(
  'instagram-scraper-6h',
  '0 */6 * * *',
  $cron$
  select net.http_post(
    url := 'https://tkesywmshaicjmywbovn.supabase.co/functions/v1/trigger-instagram-scrapes',
    headers := jsonb_build_object(
      'Content-Type','application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
    ),
    body := '{"trigger":"cron"}'::jsonb
  );
  $cron$
);

notify pgrst, 'reload schema';
