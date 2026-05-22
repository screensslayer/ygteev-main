-- Add a "YGTeeV Showcase" pseudo-group that exists solely as a
-- destination for site-admin-curated Instagram channel scrapes
-- (e.g. FGTeeV). Posts land in `feed_posts` scoped to this group
-- with status='published'; the existing admin_list_all_group_posts
-- surfaces them for review, and admin_approve_to_official promotes
-- the keepers to the YGTeeV-official feed.
--
-- Also: add a per-source results_limit so admin channels can pull
-- more than the default 25 on first scrape. Existing pastor sources
-- keep their 25-post default.

alter table public.instagram_sources
  add column if not exists results_limit integer not null default 25
  check (results_limit between 1 and 200);

-- Showcase group. is_public=false hides it from the map; no members
-- needed; created_by points at the site admin.
insert into public.youth_groups
  (name, church_name, description, gradient_from, gradient_to,
   is_public, is_default_ygteev, created_by)
values
  ('YGTeeV Showcase',
   'YGTeeV',
   'Site-admin staging for featured-channel content. Not visible to members.',
   '#6B2BFF', '#FF3DA5',
   false, false,
   'd0586523-d207-44dc-8d25-196d3649583d'::uuid)
on conflict do nothing
returning id, name;

-- Seed FGTeeV as an instagram_source for the showcase group with a
-- 50-post initial pull. We have to look up the new group id by name.
insert into public.instagram_sources
  (group_id, handle, is_active, results_limit, added_by)
select
  (select id from public.youth_groups
   where name = 'YGTeeV Showcase' and is_default_ygteev = false limit 1),
  'fgteev',
  true,
  50,
  'd0586523-d207-44dc-8d25-196d3649583d'::uuid
where not exists (
  select 1 from public.instagram_sources s
  join public.youth_groups yg on yg.id = s.group_id
  where yg.name = 'YGTeeV Showcase' and s.handle = 'fgteev'
)
returning id, handle, results_limit;
