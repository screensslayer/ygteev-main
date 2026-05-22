-- Surface parents of children-in-this-group alongside direct members.
-- Parents appear with role='parent' and a `linked_child_names` array so
-- the pastor can see whose parent they are. iOS already renders the
-- existing role pills; 'parent' just needs to be added to the switch.

drop function if exists public.pastor_list_group_members(uuid, text, boolean);

create or replace function public.pastor_list_group_members(
  _group_id uuid,
  _role_filter text default 'all',
  _active_only boolean default false
)
returns table(
  user_id uuid,
  display_name text,
  email text,
  avatar_url text,
  role text,                -- 'pastor' | 'leader' | 'member' | 'parent'
  grade_year int,
  is_parent boolean,
  linked_child_names text[],  -- only populated for role='parent'
  joined_at timestamptz,
  last_opened_at timestamptz,
  xp integer,
  water integer,
  streak integer,
  is_active_week boolean
)
language sql stable security definer
set search_path = public
as $$
  with pastor_ok as (
    select (public.is_site_admin(auth.uid())
            or public.is_group_pastor(auth.uid(), _group_id)) as ok
  ),
  direct_rows as (
    -- Anyone in `youth_group_members` for this group
    select
      p.id            as user_id,
      p.display_name,
      p.email,
      p.avatar_url,
      ygm.role::text  as role,
      p.grade_year,
      exists (
        select 1 from public.profiles c
        where c.parent_account_id = p.id
      )               as is_parent,
      null::text[]    as linked_child_names,
      ygm.joined_at,
      p.last_opened_at,
      p.xp, p.water, p.streak,
      (p.last_opened_at >= now() - interval '7 days') as is_active_week
    from public.youth_group_members ygm
    join public.profiles p on p.id = ygm.user_id
    where ygm.group_id = _group_id
  ),
  parent_rows as (
    -- Parents of children in this group, NOT already a direct member
    select
      parent_p.id     as user_id,
      parent_p.display_name,
      parent_p.email,
      parent_p.avatar_url,
      'parent'::text  as role,
      parent_p.grade_year,
      true            as is_parent,
      array_agg(distinct coalesce(child_p.display_name, child_p.email)
                order by coalesce(child_p.display_name, child_p.email))
                      as linked_child_names,
      min(fm_child.joined_at) as joined_at,
      parent_p.last_opened_at,
      parent_p.xp, parent_p.water, parent_p.streak,
      (parent_p.last_opened_at >= now() - interval '7 days') as is_active_week
    from public.youth_group_members child_ygm
    join public.family_members fm_child
      on fm_child.user_id = child_ygm.user_id and fm_child.role = 'child'
    join public.family_members fm_parent
      on fm_parent.family_id = fm_child.family_id and fm_parent.role = 'parent'
    join public.profiles parent_p on parent_p.id = fm_parent.user_id
    join public.profiles child_p  on child_p.id  = child_ygm.user_id
    where child_ygm.group_id = _group_id
      and not exists (
        select 1 from public.youth_group_members ygm
        where ygm.group_id = _group_id and ygm.user_id = parent_p.id
      )
    group by parent_p.id, parent_p.display_name, parent_p.email,
             parent_p.avatar_url, parent_p.grade_year,
             parent_p.last_opened_at, parent_p.xp, parent_p.water, parent_p.streak
  ),
  combined as (
    select * from direct_rows
    union all
    select * from parent_rows
  )
  select *
  from combined
  where (select ok from pastor_ok)
    and (_role_filter = 'all' or role = _role_filter)
    and (not _active_only or last_opened_at >= now() - interval '90 days')
  order by
    case role
      when 'pastor' then 0
      when 'leader' then 1
      when 'member' then 2
      when 'parent' then 3
    end,
    display_name nulls last;
$$;
