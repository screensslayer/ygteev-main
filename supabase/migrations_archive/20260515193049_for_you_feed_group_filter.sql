
-- =============================================================================
-- for_you_feed: accept an optional _group_id filter so the top-of-home group
-- selector can scope For You, Events, and Ranking together.
--   _group_id null  → unchanged behavior (every group the user is in + official)
--   _group_id = default-YGTeeV group → only scope='ygteev_official' posts
--   _group_id = any other group     → only scope='group' posts for that group
-- =============================================================================

drop function if exists public.for_you_feed(int, timestamptz);

create or replace function public.for_you_feed(
  _limit    int          default 20,
  _before   timestamptz  default null,
  _group_id uuid         default null
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
  video_id          uuid,
  mux_playback_id   text,
  duration_sec      numeric,
  aspect_ratio      text,
  slideshow_seconds_per_photo numeric,
  photos            jsonb,
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
  selected_is_default as (
    select coalesce(
      (select is_default_ygteev from public.youth_groups where id = _group_id),
      false
    ) as v
  ),
  visible as (
    select fp.*
    from public.feed_posts fp
    where fp.status = 'published'
      and (_before is null or fp.published_at < _before)
      and (
        case
          -- No selection: every group I'm in + official
          when _group_id is null then
            fp.scope = 'ygteev_official'
            or (fp.scope = 'group' and fp.group_id in (select group_id from mine))
          -- Selected the YGTeeV default group: only official content
          when (select v from selected_is_default) then
            fp.scope = 'ygteev_official'
          -- Selected any other group: only that group's posts (and only if I'm a member)
          else
            fp.scope = 'group'
            and fp.group_id = _group_id
            and fp.group_id in (select group_id from mine)
        end
      )
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
         from public.feed_post_photos ph where ph.post_id = fp.id),
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
  left join public.feed_post_engagement eng
    on eng.post_id = fp.id and eng.user_id = auth.uid()
  order by fp.published_at desc
  limit greatest(1, least(_limit, 50));
$func$;

grant execute on function public.for_you_feed(int, timestamptz, uuid) to authenticated;
notify pgrst, 'reload schema';
