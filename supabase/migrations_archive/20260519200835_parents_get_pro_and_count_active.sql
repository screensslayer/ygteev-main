-- Parents of an active child in any non-default youth group should
--   (a) be Pro themselves, while they remain active (last_opened_at
--       within the last 90 days), and
--   (b) count toward that group's pastor billing active-user total.
-- "Parent" = a profile linked via family_members.role='parent' to a
-- family that has at least one family_members.role='child' whose
-- child is in the relevant youth group (and active).

-- ---------------------------------------------------------------------------
-- is_pro: add parent-of-active-child branch
-- ---------------------------------------------------------------------------
create or replace function public.is_pro(_user_id uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select
    -- Direct: active Apple subscription
    exists (
      select 1 from public.apple_subscriptions
      where user_id = _user_id
        and status in ('active', 'in_grace')
        and (expires_at is null or expires_at > now())
    )
    -- Direct: user is themselves an active member of a non-default group
    or exists (
      select 1
      from public.youth_group_members ygm
      join public.youth_groups yg on yg.id = ygm.group_id
      join public.profiles p       on p.id  = ygm.user_id
      where ygm.user_id = _user_id
        and yg.is_default_ygteev = false
        and p.last_opened_at >= now() - interval '90 days'
    )
    -- NEW: caller is a parent whose child is in a non-default youth
    --      group, and the parent themselves is active.
    or exists (
      select 1
      from public.family_members fm_parent
      join public.family_members fm_child
        on fm_child.family_id = fm_parent.family_id
       and fm_child.role = 'child'
      join public.youth_group_members child_ygm
        on child_ygm.user_id = fm_child.user_id
      join public.youth_groups yg on yg.id = child_ygm.group_id
      join public.profiles parent_profile on parent_profile.id = fm_parent.user_id
      where fm_parent.user_id = _user_id
        and fm_parent.role    = 'parent'
        and yg.is_default_ygteev = false
        and parent_profile.last_opened_at >= now() - interval '90 days'
    );
$$;

-- ---------------------------------------------------------------------------
-- pastor_active_user_count: include parents of children in each of
-- this pastor's groups. Parents only count while their own
-- last_opened_at is within the last 90 days, matching the kids' rule.
-- ---------------------------------------------------------------------------
create or replace function public.pastor_active_user_count(_pastor_user_id uuid)
returns integer
language sql stable security definer
set search_path = public
as $$
  with pastor_groups as (
    select group_id
    from public.youth_group_members
    where user_id = _pastor_user_id and role = 'pastor'
  ),
  direct_active as (
    -- Members / leaders / pastor themselves, recently active
    select distinct p.id as user_id
    from public.youth_group_members ygm
    join public.profiles p on p.id = ygm.user_id
    where ygm.group_id in (select group_id from pastor_groups)
      and p.last_opened_at >= now() - interval '90 days'
  ),
  parent_active as (
    -- Parents of children in any of this pastor's groups, gated on
    -- the parent's own activity.
    select distinct parent_p.id as user_id
    from public.youth_group_members child_ygm
    join public.family_members fm_child
      on fm_child.user_id = child_ygm.user_id and fm_child.role = 'child'
    join public.family_members fm_parent
      on fm_parent.family_id = fm_child.family_id and fm_parent.role = 'parent'
    join public.profiles parent_p on parent_p.id = fm_parent.user_id
    where child_ygm.group_id in (select group_id from pastor_groups)
      and parent_p.last_opened_at >= now() - interval '90 days'
  )
  select count(*)::int from (
    select user_id from direct_active
    union
    select user_id from parent_active
  ) all_active;
$$;
