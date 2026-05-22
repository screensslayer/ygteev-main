-- Narrow the IG-import dedup constraint to group-scoped rows only.
-- Original intent: prevent the Instagram scraper from importing the
-- same (handle, ig_post_id) pair twice into a group's feed. After
-- admin_approve_to_official copies those identifiers into a
-- 'ygteev_official' row for provenance, the unscoped uniqueness
-- collided and broke promotion. Scope='group' guard restores both
-- behaviors.

drop index if exists public.feed_posts_source_post_unique_idx;

create unique index feed_posts_source_post_unique_idx
  on public.feed_posts (source_handle, source_post_id)
  where source_post_id is not null and scope = 'group';
