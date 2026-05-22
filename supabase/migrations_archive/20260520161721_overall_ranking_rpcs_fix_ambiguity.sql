create or replace function public.ranking_top_groups_overall(
  _limit int default 10
)
returns table(
  rank int,
  group_id uuid,
  name text,
  church_name text,
  logo_url text,
  gradient_from text,
  gradient_to text,
  active_count int,
  week_xp bigint,
  is_my_group boolean
)
language plpgsql stable security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_week_start timestamptz :=
    (date_trunc('week', now() at time zone 'UTC')) at time zone 'UTC';
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  return query
  with related_pairs as (
    select yg.id as r_group_id, p.id as r_user_id, p.last_opened_at as r_last_opened_at
    from public.youth_groups yg
    join public.youth_group_members ygm on ygm.group_id = yg.id
    join public.profiles p on p.id = ygm.user_id
    where yg.is_default_ygteev = false
    union
    select yg.id, parent_p.id, parent_p.last_opened_at
    from public.youth_groups yg
    join public.youth_group_members child_ygm on child_ygm.group_id = yg.id
    join public.family_members fm_child
      on fm_child.user_id = child_ygm.user_id and fm_child.role = 'child'
    join public.family_members fm_parent
      on fm_parent.family_id = fm_child.family_id and fm_parent.role = 'parent'
    join public.profiles parent_p on parent_p.id = fm_parent.user_id
    where yg.is_default_ygteev = false
  ),
  per_group as (
    select rp.r_group_id,
           count(distinct rp.r_user_id) filter (
             where rp.r_last_opened_at >= now() - interval '90 days'
           )::int as r_active_count,
           coalesce(sum(g.amount), 0)::bigint as r_week_xp
    from related_pairs rp
    left join public.user_xp_grants g
      on g.user_id = rp.r_user_id and g.awarded_at >= v_week_start
    group by rp.r_group_id
  ),
  mine as (
    select ygm.group_id as r_mine_group_id
    from public.youth_group_members ygm
    where ygm.user_id = v_uid
  )
  select
    (row_number() over (order by pg.r_week_xp desc, yg.name nulls last))::int as rank,
    yg.id              as group_id,
    yg.name            as name,
    yg.church_name     as church_name,
    yg.logo_url        as logo_url,
    yg.gradient_from   as gradient_from,
    yg.gradient_to     as gradient_to,
    pg.r_active_count  as active_count,
    pg.r_week_xp       as week_xp,
    (yg.id in (select m.r_mine_group_id from mine m)) as is_my_group
  from per_group pg
  join public.youth_groups yg on yg.id = pg.r_group_id
  order by pg.r_week_xp desc, yg.name nulls last
  limit greatest(_limit, 1);
end;
$$;

create or replace function public.ranking_top_users_overall(
  _limit int default 10
)
returns table(
  rank int,
  user_id uuid,
  display_name text,
  handle text,
  avatar_url text,
  group_id uuid,
  group_name text,
  week_xp bigint,
  is_me boolean
)
language plpgsql stable security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_week_start timestamptz :=
    (date_trunc('week', now() at time zone 'UTC')) at time zone 'UTC';
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  return query
  with per_user as (
    select g.user_id as r_user_id,
           sum(g.amount)::bigint as r_week_xp
    from public.user_xp_grants g
    where g.awarded_at >= v_week_start
    group by g.user_id
    having sum(g.amount) > 0
  ),
  user_group as (
    select distinct on (ygm.user_id)
           ygm.user_id as r_user_id,
           ygm.group_id as r_group_id,
           yg.name as r_group_name
    from public.youth_group_members ygm
    join public.youth_groups yg on yg.id = ygm.group_id
    where yg.is_default_ygteev = false
    order by ygm.user_id, ygm.joined_at
  )
  select
    (row_number() over (order by pu.r_week_xp desc,
                                  p.display_name nulls last))::int  as rank,
    p.id              as user_id,
    p.display_name    as display_name,
    p.handle          as handle,
    p.avatar_url      as avatar_url,
    ug.r_group_id     as group_id,
    ug.r_group_name   as group_name,
    pu.r_week_xp      as week_xp,
    (p.id = v_uid)    as is_me
  from per_user pu
  join public.profiles p on p.id = pu.r_user_id
  left join user_group ug on ug.r_user_id = pu.r_user_id
  order by pu.r_week_xp desc, p.display_name nulls last
  limit greatest(_limit, 1);
end;
$$;
