drop function if exists public.pastor_my_groups();
create or replace function public.pastor_my_groups()
returns table(group_id uuid, name text, address text, member_count integer)
language sql stable security definer
set search_path = public
as $$
  with related as (
    select yg.id as group_id, yg.name, yg.address, p.id as user_id
    from public.youth_groups yg
    join public.youth_group_members ygm on ygm.group_id = yg.id
    join public.profiles p on p.id = ygm.user_id
    union
    select yg.id, yg.name, yg.address, parent_p.id
    from public.youth_groups yg
    join public.youth_group_members child_ygm on child_ygm.group_id = yg.id
    join public.family_members fm_child
      on fm_child.user_id = child_ygm.user_id and fm_child.role = 'child'
    join public.family_members fm_parent
      on fm_parent.family_id = fm_child.family_id and fm_parent.role = 'parent'
    join public.profiles parent_p on parent_p.id = fm_parent.user_id
  )
  select
    yg.id   as group_id,
    yg.name,
    yg.address,
    (select count(*)::int from related r where r.group_id = yg.id) as member_count
  from public.youth_groups yg
  join public.youth_group_members me on me.group_id = yg.id
  where me.user_id = auth.uid()
    and me.role = 'pastor'
  order by yg.name;
$$;
