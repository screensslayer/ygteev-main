
-- =============================================================================
-- For You feed — Phase 2 RPCs:
--   • for_you_feed(_limit, _before)              — paginated mixed feed
--   • pastor_create_feed_slideshow_post          — slideshow draft
--   • pastor_attach_slideshow_photos             — bulk-insert photo rows
--   • pastor_attach_video_to_post                — link an existing video row
--   • pastor_publish_feed_post                   — flip to published
--   • pastor_archive_feed_post / pastor_delete_feed_post
--   • feed_post_record_view                      — first_viewed_at
--   • feed_post_record_watch_complete            — watched ≥ 80%
--   • feed_post_toggle_like                      — returns new like state
-- =============================================================================

-- Helper: caller can manage this feed_post (pastor of its group or site admin)
create or replace function public._can_manage_feed_post(_post_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $func$
  select
    public.is_site_admin(auth.uid())
    or exists (
      select 1 from public.feed_posts fp
      where fp.id = _post_id
        and fp.scope = 'group'
        and public.is_group_pastor(auth.uid(), fp.group_id)
    );
$func$;
grant execute on function public._can_manage_feed_post(uuid) to authenticated;


-- 1. for_you_feed -----------------------------------------------------------
create or replace function public.for_you_feed(
  _limit  int          default 20,
  _before timestamptz  default null
)
returns table (
  post_id           uuid,
  post_type         text,
  scope             text,
  group_id          uuid,
  group_name        text,
  source_kind       text,
  source_url        text,
  source_handle     text,
  title             text,
  caption           text,

  -- video fields (null if slideshow)
  video_id          uuid,
  mux_playback_id   text,
  duration_sec      numeric,
  aspect_ratio      text,

  -- slideshow fields (null if video)
  slideshow_seconds_per_photo numeric,
  photos            jsonb,    -- array of {storage_path, display_order, alt_text, public_url}

  -- author + engagement
  author_id         uuid,
  author_name       text,
  author_avatar     text,
  views_count       int,
  likes_count       int,
  has_viewed        boolean,
  has_liked         boolean,
  published_at      timestamptz
)
language sql
stable
security definer
set search_path = public
as $func$
  with mine as (
    select group_id from public.youth_group_members where user_id = auth.uid()
  ),
  visible as (
    select fp.*
    from public.feed_posts fp
    where fp.status = 'published'
      and (
        fp.scope = 'ygteev_official'
        or (fp.scope = 'group' and fp.group_id in (select group_id from mine))
      )
      and (_before is null or fp.published_at < _before)
  )
  select
    fp.id as post_id,
    fp.post_type,
    fp.scope,
    fp.group_id,
    yg.name as group_name,
    fp.source_kind,
    fp.source_url,
    fp.source_handle,
    fp.title,
    fp.caption,
    fp.video_id,
    v.mux_playback_id,
    v.duration_sec,
    v.aspect_ratio,
    fp.slideshow_seconds_per_photo,
    coalesce(
      (select jsonb_agg(jsonb_build_object(
                'storage_path', ph.storage_path,
                'display_order', ph.display_order,
                'alt_text', ph.alt_text,
                'public_url',
                  'https://tkesywmshaicjmywbovn.supabase.co/storage/v1/object/public/feed-photos/' || ph.storage_path
              ) order by ph.display_order)
         from public.feed_post_photos ph
         where ph.post_id = fp.id),
      '[]'::jsonb
    ) as photos,
    fp.created_by as author_id,
    p.display_name as author_name,
    p.avatar_url as author_avatar,
    fp.views_count,
    fp.likes_count,
    coalesce(eng.first_viewed_at is not null, false) as has_viewed,
    coalesce(eng.liked_at is not null, false) as has_liked,
    fp.published_at
  from visible fp
  left join public.youth_groups yg on yg.id = fp.group_id
  left join public.videos       v  on v.id  = fp.video_id
  left join public.profiles     p  on p.id  = fp.created_by
  left join public.feed_post_engagement eng on eng.post_id = fp.id and eng.user_id = auth.uid()
  order by fp.published_at desc
  limit greatest(1, least(_limit, 50));
$func$;
grant execute on function public.for_you_feed(int, timestamptz) to authenticated;


-- 2. pastor_create_feed_slideshow_post --------------------------------------
create or replace function public.pastor_create_feed_slideshow_post(
  _group_id uuid,
  _title    text default null,
  _caption  text default null
) returns uuid
language plpgsql security definer set search_path = public as $func$
declare
  v_caller uuid := auth.uid();
  v_post_id uuid;
begin
  if v_caller is null then raise exception 'not_authenticated'; end if;
  if not (public.is_site_admin(v_caller) or public.is_group_pastor(v_caller, _group_id)) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  insert into public.feed_posts (
    post_type, scope, group_id, source_kind,
    title, caption, status, created_by
  ) values (
    'slideshow', 'group', _group_id, 'pastor_upload',
    nullif(trim(_title), ''), nullif(trim(_caption), ''),
    'draft', v_caller
  )
  returning id into v_post_id;

  return v_post_id;
end;
$func$;
grant execute on function public.pastor_create_feed_slideshow_post(uuid, text, text) to authenticated;


-- 3. pastor_attach_slideshow_photos -----------------------------------------
-- _photos: jsonb array of {storage_path, display_order, alt_text?}
create or replace function public.pastor_attach_slideshow_photos(
  _post_id uuid,
  _photos  jsonb
) returns int
language plpgsql security definer set search_path = public as $func$
declare
  v_inserted int := 0;
  v_row jsonb;
  v_existing_count int;
begin
  if not public._can_manage_feed_post(_post_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  -- Validate the parent post is a slideshow
  if not exists (
    select 1 from public.feed_posts
    where id = _post_id and post_type = 'slideshow'
  ) then
    raise exception 'post_not_slideshow';
  end if;

  -- Replace any existing photos (simpler model: reset every save)
  delete from public.feed_post_photos where post_id = _post_id;

  for v_row in select * from jsonb_array_elements(_photos)
  loop
    insert into public.feed_post_photos
      (post_id, storage_path, display_order, alt_text)
    values (
      _post_id,
      v_row->>'storage_path',
      coalesce((v_row->>'display_order')::int, v_inserted),
      v_row->>'alt_text'
    );
    v_inserted := v_inserted + 1;
  end loop;

  return v_inserted;
end;
$func$;
grant execute on function public.pastor_attach_slideshow_photos(uuid, jsonb) to authenticated;


-- 4. pastor_attach_video_to_post --------------------------------------------
-- Used when the Mux upload flow has yielded a video_id and we want to bind
-- it to a feed_post. The video_id must already be owned by the caller.
create or replace function public.pastor_attach_video_to_post(
  _post_id uuid,
  _video_id uuid
) returns void
language plpgsql security definer set search_path = public as $func$
begin
  if not public._can_manage_feed_post(_post_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.videos
    where id = _video_id and (created_by = auth.uid() or public.is_site_admin(auth.uid()))
  ) then
    raise exception 'video_not_owned';
  end if;

  update public.feed_posts
    set video_id = _video_id,
        updated_at = now()
    where id = _post_id and post_type = 'video';
end;
$func$;
grant execute on function public.pastor_attach_video_to_post(uuid, uuid) to authenticated;


-- 5. pastor_publish_feed_post -----------------------------------------------
create or replace function public.pastor_publish_feed_post(_post_id uuid)
returns void
language plpgsql security definer set search_path = public as $func$
declare
  v_post public.feed_posts;
  v_video public.videos;
  v_photo_count int;
begin
  if not public._can_manage_feed_post(_post_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  select * into v_post from public.feed_posts where id = _post_id;

  if v_post.post_type = 'video' then
    if v_post.video_id is null then raise exception 'video_not_attached'; end if;
    select * into v_video from public.videos where id = v_post.video_id;
    if v_video.status::text <> 'ready' then
      raise exception 'video_not_ready (current status: %)', v_video.status;
    end if;
  elsif v_post.post_type = 'slideshow' then
    select count(*) into v_photo_count
      from public.feed_post_photos where post_id = _post_id;
    if v_photo_count = 0 then raise exception 'slideshow_has_no_photos'; end if;
  end if;

  update public.feed_posts
    set status = 'published',
        published_at = coalesce(published_at, now()),
        updated_at = now()
  where id = _post_id;
end;
$func$;
grant execute on function public.pastor_publish_feed_post(uuid) to authenticated;


-- 6. pastor_archive_feed_post / pastor_delete_feed_post ---------------------
create or replace function public.pastor_archive_feed_post(_post_id uuid)
returns void
language plpgsql security definer set search_path = public as $func$
begin
  if not public._can_manage_feed_post(_post_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  update public.feed_posts set status = 'archived', updated_at = now() where id = _post_id;
end;
$func$;
grant execute on function public.pastor_archive_feed_post(uuid) to authenticated;

create or replace function public.pastor_delete_feed_post(_post_id uuid)
returns void
language plpgsql security definer set search_path = public as $func$
begin
  if not public._can_manage_feed_post(_post_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  delete from public.feed_posts where id = _post_id;
end;
$func$;
grant execute on function public.pastor_delete_feed_post(uuid) to authenticated;


-- 7. Engagement RPCs --------------------------------------------------------
create or replace function public.feed_post_record_view(_post_id uuid)
returns void
language plpgsql security definer set search_path = public as $func$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  insert into public.feed_post_engagement (post_id, user_id, first_viewed_at)
    values (_post_id, v_uid, now())
    on conflict (post_id, user_id) do update
      set first_viewed_at = coalesce(public.feed_post_engagement.first_viewed_at, now());
end;
$func$;
grant execute on function public.feed_post_record_view(uuid) to authenticated;

create or replace function public.feed_post_record_watch_complete(_post_id uuid)
returns void
language plpgsql security definer set search_path = public as $func$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  insert into public.feed_post_engagement (post_id, user_id, first_viewed_at, watch_completed_at)
    values (_post_id, v_uid, now(), now())
    on conflict (post_id, user_id) do update
      set first_viewed_at    = coalesce(public.feed_post_engagement.first_viewed_at, now()),
          watch_completed_at = coalesce(public.feed_post_engagement.watch_completed_at, now());
end;
$func$;
grant execute on function public.feed_post_record_watch_complete(uuid) to authenticated;

-- Toggle like; returns the new like state (true = liked)
create or replace function public.feed_post_toggle_like(_post_id uuid)
returns boolean
language plpgsql security definer set search_path = public as $func$
declare
  v_uid uuid := auth.uid();
  v_existing public.feed_post_engagement;
  v_now timestamptz := now();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select * into v_existing from public.feed_post_engagement
    where post_id = _post_id and user_id = v_uid;

  if v_existing.id is null then
    insert into public.feed_post_engagement (post_id, user_id, first_viewed_at, liked_at)
      values (_post_id, v_uid, v_now, v_now);
    return true;
  end if;

  if v_existing.liked_at is not null then
    update public.feed_post_engagement
      set liked_at = null
      where id = v_existing.id;
    return false;
  else
    update public.feed_post_engagement
      set liked_at = v_now,
          first_viewed_at = coalesce(first_viewed_at, v_now)
      where id = v_existing.id;
    return true;
  end if;
end;
$func$;
grant execute on function public.feed_post_toggle_like(uuid) to authenticated;

notify pgrst, 'reload schema';
