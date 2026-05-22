-- Bring pastor_dashboard in line with pastor_list_group_members:
-- "members" now includes both direct youth_group_members rows AND
-- parents of children in this group. XP / water totals stay
-- member-only (parents don't earn group XP).

create or replace function public.pastor_dashboard(_group_id uuid)
returns table(
  group_id uuid, group_name text, logo_url text,
  member_count integer, small_group_count integer,
  pending_request_count integer,
  active_this_week integer, active_last_week integer,
  active_this_week_pct integer, active_last_week_pct integer,
  total_group_xp bigint, total_group_water bigint
)
language sql stable security definer
set search_path = public
as $$
  with allowed as (select public._pastor_can_view_group(_group_id) as ok),
  -- Every user counted toward "members" of this group: direct + parents
  related_users as (
    select p.id as user_id, p.last_opened_at
    from public.youth_group_members ygm
    join public.profiles p on p.id = ygm.user_id
    where ygm.group_id = _group_id
    union
    select parent_p.id, parent_p.last_opened_at
    from public.youth_group_members child_ygm
    join public.family_members fm_child
      on fm_child.user_id = child_ygm.user_id and fm_child.role = 'child'
    join public.family_members fm_parent
      on fm_parent.family_id = fm_child.family_id and fm_parent.role = 'parent'
    join public.profiles parent_p on parent_p.id = fm_parent.user_id
    where child_ygm.group_id = _group_id
  )
  select
    yg.id           as group_id,
    yg.name         as group_name,
    yg.logo_url     as logo_url,
    (select count(*)::int from related_users)                                 as member_count,
    (select count(*)::int from public.small_groups
       where youth_group_id = yg.id)                                          as small_group_count,
    (select count(*)::int from public.youth_group_join_requests
       where group_id = yg.id and status = 'pending')                         as pending_request_count,
    (select count(*)::int from related_users
       where last_opened_at >= now() - interval '7 days')                     as active_this_week,
    (select count(*)::int from related_users
       where last_opened_at >= now() - interval '14 days'
         and last_opened_at  < now() - interval '7 days')                     as active_last_week,
    (select case when count(*) = 0 then 0
            else round((count(*) filter (where last_opened_at >= now() - interval '7 days'))::numeric
                       / count(*)::numeric * 100)::int end
       from related_users)                                                    as active_this_week_pct,
    (select case when count(*) = 0 then 0
            else round((count(*) filter (
                          where last_opened_at >= now() - interval '14 days'
                            and last_opened_at  < now() - interval '7 days'))::numeric
                       / count(*)::numeric * 100)::int end
       from related_users)                                                    as active_last_week_pct,
    -- Group XP/water totals remain MEMBERS-ONLY by design — parents
    -- don't earn XP from this group's plans.
    (select coalesce(sum(p.xp), 0)::bigint
       from public.youth_group_members ygm
       join public.profiles p on p.id = ygm.user_id
      where ygm.group_id = yg.id)                                             as total_group_xp,
    (select coalesce(sum(p.water), 0)::bigint
       from public.youth_group_members ygm
       join public.profiles p on p.id = ygm.user_id
      where ygm.group_id = yg.id)                                             as total_group_water
  from public.youth_groups yg, allowed
  where yg.id = _group_id and allowed.ok;
$$;
