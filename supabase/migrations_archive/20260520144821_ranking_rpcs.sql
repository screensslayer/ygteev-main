-- Top users in a youth group by current-week XP (Mon-Sun UTC).
-- Caller must be a member of the group (or site admin). Default
-- YGTeeV group excluded.
create or replace function public.ranking_top_users_in_group(
  _group_id uuid,
  _limit int default 10
)
returns table(
  rank int,
  user_id uuid,
  display_name text,
  handle text,
  avatar_url text,
  role text,                 -- 'pastor' | 'leader' | 'parent' | 'student' | 'member'
  week_xp bigint,
  is_me boolean
)
language plpgsql stable security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_yg public.youth_groups;
  v_week_start timestamptz := date_trunc('week', now() at time zone 'UTC') at time zone 'UTC';
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select * into v_yg from public.youth_groups where id = _group_id;
  if v_yg.id is null then raise exception 'group_not_found'; end if;
  if v_yg.is_default_ygteev then raise exception 'cannot_rank_default_group'; end if;

  if not (public.is_site_admin(v_uid) or public.is_group_member(v_uid, _group_id)) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  return query
  with related as (
    -- direct + parents (matches pastor_active_user_count rule)
    select p.id as user_id, p.display_name, p.handle, p.avatar_url, p.grade_year,
           'direct' as src
    from public.youth_group_members ygm
    join public.profiles p on p.id = ygm.user_id
    where ygm.group_id = _group_id
    union
    select parent_p.id, parent_p.display_name, parent_p.handle, parent_p.avatar_url, parent_p.grade_year,
           'parent'
    from public.youth_group_members child_ygm
    join public.family_members fm_child
      on fm_child.user_id = child_ygm.user_id and fm_child.role = 'child'
    join public.family_members fm_parent
      on fm_parent.family_id = fm_child.family_id and fm_parent.role = 'parent'
    join public.profiles parent_p on parent_p.id = fm_parent.user_id
    where child_ygm.group_id = _group_id
  ),
  scored as (
    select r.user_id, r.display_name, r.handle, r.avatar_url, r.grade_year, r.src,
           coalesce(sum(g.amount), 0)::bigint as week_xp
    from related r
    left join public.user_xp_grants g
      on g.user_id = r.user_id and g.awarded_at >= v_week_start
    group by r.user_id, r.display_name, r.handle, r.avatar_url, r.grade_year, r.src
  ),
  roled as (
    select s.*,
      case
        when exists (select 1 from public.youth_group_members ygm2
                     where ygm2.group_id = _group_id and ygm2.user_id = s.user_id and ygm2.role = 'pastor')
          then 'pastor'
        when exists (select 1 from public.small_group_members sgm
                     join public.small_groups sg on sg.id = sgm.small_group_id
                     where sgm.user_id = s.user_id and sgm.role = 'leader'
                       and sg.youth_group_id = _group_id)
          then 'leader'
        when s.src = 'parent' then 'parent'
        when s.grade_year is not null then 'student'
        else 'member'
      end as role_label
    from scored s
  )
  select
    (row_number() over (order by week_xp desc, display_name nulls last))::int as rank,
    user_id,
    display_name,
    handle,
    avatar_url,
    role_label,
    week_xp,
    (user_id = v_uid) as is_me
  from roled
  order by week_xp desc, display_name nulls last
  limit greatest(_limit, 1);
end;
$$;

grant execute on function public.ranking_top_users_in_group(uuid, int) to authenticated, service_role;


-- Top groups in the SAME class as _group_id, weekly XP, handicap
-- multiplier, adjusted score. Caller must be a member of _group_id.
create or replace function public.ranking_top_groups_in_my_class(
  _group_id uuid,
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
  class text,
  class_label text,
  active_count int,
  max_active_in_class int,
  multiplier numeric,
  week_xp bigint,
  adjusted_xp bigint,
  is_my_group boolean
)
language plpgsql stable security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_yg public.youth_groups;
  v_week_start timestamptz := date_trunc('week', now() at time zone 'UTC') at time zone 'UTC';
  v_my_class text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_yg from public.youth_groups where id = _group_id;
  if v_yg.id is null then raise exception 'group_not_found'; end if;
  if v_yg.is_default_ygteev then raise exception 'cannot_rank_default_group'; end if;
  if not (public.is_site_admin(v_uid) or public.is_group_member(v_uid, _group_id)) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  -- Compute every non-default group's active count + week_xp
  return query
  with related_pairs as (
    select yg.id as group_id, p.id as user_id, p.last_opened_at
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
    select rp.group_id,
           count(distinct rp.user_id) filter (
             where rp.last_opened_at >= now() - interval '90 days'
           )::int as active_count,
           coalesce(sum(g.amount), 0)::bigint as week_xp
    from related_pairs rp
    left join public.user_xp_grants g
      on g.user_id = rp.user_id and g.awarded_at >= v_week_start
    group by rp.group_id
  ),
  classed as (
    select pg.group_id, pg.active_count, pg.week_xp,
           public.xp_class_for(pg.active_count) as class
    from per_group pg
  ),
  my_class as (
    select class as c from classed where group_id = _group_id
  ),
  class_max as (
    select class, max(active_count) as max_active
    from classed
    where class is not null
    group by class
  ),
  in_class as (
    select c.group_id, c.active_count, c.week_xp, c.class,
           cm.max_active as max_active_in_class,
           least(
             case when c.active_count = 0 then 1.0
                  else (cm.max_active::numeric / c.active_count::numeric)
             end,
             3.00::numeric
           ) as multiplier
    from classed c
    join class_max cm on cm.class = c.class
    where c.class = (select c from my_class)
  )
  select
    (row_number() over (
       order by (week_xp * multiplier) desc, multiplier asc, name nulls last
     ))::int as rank,
    yg.id,
    yg.name,
    yg.church_name,
    yg.logo_url,
    yg.gradient_from,
    yg.gradient_to,
    ic.class,
    initcap(ic.class) as class_label,
    ic.active_count,
    ic.max_active_in_class,
    round(ic.multiplier, 2) as multiplier,
    ic.week_xp,
    floor(ic.week_xp * ic.multiplier)::bigint as adjusted_xp,
    (yg.id = _group_id) as is_my_group
  from in_class ic
  join public.youth_groups yg on yg.id = ic.group_id
  order by adjusted_xp desc, multiplier asc, yg.name nulls last
  limit greatest(_limit, 1);
end;
$$;

grant execute on function public.ranking_top_groups_in_my_class(uuid, int) to authenticated, service_role;
