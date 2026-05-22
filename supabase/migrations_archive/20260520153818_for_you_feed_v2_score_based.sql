-- For You feed v2 — score-based ranking. Drop-in replacement; signature
-- and return shape are identical to v1 so iOS needs no changes.
--
-- Score = seen_freshness + publish_recency + global_engagement
--       + caller_affinity + tiny_jitter - diversity_penalty
--
-- See the team doc for tuning. Coefficients chosen so seen_freshness
-- still dominates (unseen pinned high, just-watched pushed down hard),
-- but engagement/affinity can swap two equally-fresh posts.

create or replace function public.for_you_feed(
  _limit  integer default 20,
  _offset integer default 0,
  _group_id uuid default null
)
returns table(
  post_id uuid, post_type text, scope text, group_id uuid, group_name text,
  source_kind text, source_url text, source_handle text,
  title text, caption text,
  video_id uuid, mux_playback_id text, duration_sec numeric, aspect_ratio text,
  slideshow_seconds_per_photo numeric, photos jsonb,
  author_id uuid, author_name text, author_avatar text,
  views_count integer, likes_count integer,
  has_viewed boolean, has_liked boolean,
  published_at timestamp with time zone
)
language sql stable security definer
set search_path = public
as $function$
  with mine as (
    select group_id from public.youth_group_members where user_id = auth.uid()
  ),
  selected_is_default as (
    select coalesce(
      (select is_default_ygteev from public.youth_groups where id = _group_id),
      false
    ) as v
  ),
  -- Same visibility rules as v1 (do not change without checking
  -- ygteev_official curation flow + group-private guarantees).
  visible as (
    select fp.*
    from public.feed_posts fp
    where fp.status = 'published'
      and (
        case
          when _group_id is null then
            fp.scope = 'ygteev_official'
            or (fp.scope = 'group' and fp.group_id in (select group_id from mine))
          when (select v from selected_is_default) then
            fp.scope = 'ygteev_official'
          else
            fp.scope = 'group'
            and fp.group_id = _group_id
            and fp.group_id in (select group_id from mine)
        end
      )
  ),
  -- Pre-compute per-post completion counts once.
  global_eng as (
    select e.post_id,
           count(*) filter (where e.watch_completed_at is not null)::int as completes
    from public.feed_post_engagement e
    group by e.post_id
  ),
  -- Caller's per-group completion share over last 30 days. Drives
  -- caller_affinity boost — users who actually finish a group's
  -- content get more of that group.
  user_affinity_raw as (
    select fp.group_id, count(*) filter (where e.watch_completed_at is not null)::int as my_completes
    from public.feed_post_engagement e
    join public.feed_posts fp on fp.id = e.post_id
    where e.user_id = auth.uid()
      and e.first_viewed_at >= now() - interval '30 days'
    group by fp.group_id
  ),
  user_affinity_total as (
    select coalesce(sum(my_completes), 0)::numeric as total
    from user_affinity_raw
  ),
  -- Score each visible post.
  scored as (
    select
      fp.*,
      eng.first_viewed_at as eng_first_viewed_at,
      eng.liked_at        as eng_liked_at,
      -- 1) seen_freshness
      case
        when eng.first_viewed_at is null                        then  1000::numeric
        when eng.first_viewed_at >  now() - interval '24 hours' then -2000::numeric
        when eng.first_viewed_at >  now() - interval '7 days'   then  -500::numeric
        when eng.first_viewed_at >  now() - interval '21 days'  then     0::numeric
        else                                                          200::numeric
      end as s_freshness,
      -- 2) publish_recency — half-life 7 days
      greatest(
        0,
        100 * exp(- (extract(epoch from now() - fp.published_at) / 86400.0) / 7)
      )::numeric as s_recency,
      -- 3) global_engagement — rate-based, normalized
      case when fp.views_count > 0 then
        (40 * (fp.likes_count::numeric / fp.views_count::numeric))
        + (60 * (coalesce(ge.completes, 0)::numeric / fp.views_count::numeric))
      else 0::numeric end as s_engagement,
      -- 4) caller_affinity — fraction of caller's completions that
      -- belonged to this post's group, capped via 80*(share).
      case when (select total from user_affinity_total) > 0 then
        80 * (coalesce(ua.my_completes, 0)::numeric / (select total from user_affinity_total))
      else 0::numeric end as s_affinity,
      -- 5) jitter — keeps sessions feeling fresh once a user has
      -- exhausted their library.
      (random() * 10)::numeric as s_jitter
    from visible fp
    left join public.feed_post_engagement eng
      on eng.post_id = fp.id and eng.user_id = auth.uid()
    left join global_eng ge        on ge.post_id  = fp.id
    left join user_affinity_raw ua on ua.group_id = fp.group_id
  ),
  -- 6) diversity penalty — N posts in a row from the same group lose
  -- 15 * (rank - 1) points within the group.
  with_pos as (
    select s.*,
           row_number() over (
             partition by s.group_id
             order by (s.s_freshness + s.s_recency + s.s_engagement
                       + s.s_affinity + s.s_jitter) desc,
                      s.published_at desc,
                      s.id desc
           ) as group_pos
    from scored s
  ),
  final as (
    select s.*,
      (s.s_freshness + s.s_recency + s.s_engagement + s.s_affinity + s.s_jitter
       - greatest(0, (s.group_pos - 1) * 15))::numeric as final_score
    from with_pos s
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
    p.avatar_url   as author_avatar,
    fp.views_count,
    fp.likes_count,
    coalesce(fp.eng_first_viewed_at is not null, false) as has_viewed,
    coalesce(fp.eng_liked_at        is not null, false) as has_liked,
    fp.published_at
  from final fp
  left join public.youth_groups yg on yg.id = fp.group_id
  left join public.videos       v  on v.id  = fp.video_id
  left join public.profiles     p  on p.id  = fp.created_by
  order by fp.final_score desc, fp.published_at desc, fp.id desc
  offset greatest(0, _offset)
  limit  greatest(1, least(_limit, 50));
$function$;

grant execute on function public.for_you_feed(integer, integer, uuid) to authenticated, service_role;
