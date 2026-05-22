drop function if exists public.pastor_list_group_members(uuid, text, boolean);
drop function if exists public.pastor_list_join_requests(uuid);

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
  role text,
  grade_year int,
  is_parent boolean,
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
    ygm.joined_at,
    p.last_opened_at,
    p.xp, p.water, p.streak,
    (p.last_opened_at >= now() - interval '7 days')  as is_active_week
  from public.youth_group_members ygm
  join public.profiles p on p.id = ygm.user_id
  where ygm.group_id = _group_id
    and (_role_filter = 'all' or ygm.role::text = _role_filter)
    and (not _active_only or p.last_opened_at >= now() - interval '90 days')
    and (
      public.is_site_admin(auth.uid())
      or public.is_group_pastor(auth.uid(), _group_id)
    )
  order by
    case ygm.role::text when 'pastor' then 0 when 'leader' then 1 else 2 end,
    p.display_name nulls last;
$$;

create or replace function public.pastor_list_join_requests(_group_id uuid)
returns table(
  request_id uuid,
  user_id uuid,
  display_name text,
  avatar_url text,
  email text,
  grade_year int,
  is_parent boolean,
  message text,
  requested_at timestamptz
)
language sql stable security definer
set search_path = public
as $$
  with allowed as (select public._pastor_can_view_group(_group_id) as ok)
  select
    r.id          as request_id,
    r.user_id,
    p.display_name,
    p.avatar_url,
    p.email,
    p.grade_year,
    exists (
      select 1 from public.profiles c
      where c.parent_account_id = p.id
    )             as is_parent,
    r.message,
    r.requested_at
  from public.youth_group_join_requests r
  join public.profiles p on p.id = r.user_id
  cross join allowed
  where r.group_id = _group_id
    and r.status   = 'pending'
    and allowed.ok
  order by r.requested_at desc;
$$;
