-- Bug: RETURNS TABLE output column names collide with CTE column names
-- inside the body, raising `column reference "user_id" is ambiguous` at
-- call time. Fix by qualifying every reference with the source CTE
-- alias and (defensively) renaming the loop-locals.

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
  role text,
  week_xp bigint,
  is_me boolean
)
language plpgsql stable security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_yg public.youth_groups;
  v_week_start timestamptz :=
    (date_trunc('week', now() at time zone 'UTC')) at time zone 'UTC';
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
    select p.id as r_user_id, p.display_name as r_display_name,
           p.handle as r_handle, p.avatar_url as r_avatar_url,
           p.grade_year as r_grade_year, 'direct'::text as r_src
    from public.youth_group_members ygm
    join public.profiles p on p.id = ygm.user_id
    where ygm.group_id = _group_id
    union
    select parent_p.id, parent_p.display_name, parent_p.handle,
           parent_p.avatar_url, parent_p.grade_year, 'parent'::text
    from public.youth_group_members child_ygm
    join public.family_members fm_child
      on fm_child.user_id = child_ygm.user_id and fm_child.role = 'child'
    join public.family_members fm_parent
      on fm_parent.family_id = fm_child.family_id and fm_parent.role = 'parent'
    join public.profiles parent_p on parent_p.id = fm_parent.user_id
    where child_ygm.group_id = _group_id
  ),
  scored as (
    select r.r_user_id, r.r_display_name, r.r_handle, r.r_avatar_url,
           r.r_grade_year, r.r_src,
           coalesce(sum(g.amount), 0)::bigint as r_week_xp
    from related r
    left join public.user_xp_grants g
      on g.user_id = r.r_user_id and g.awarded_at >= v_week_start
    group by r.r_user_id, r.r_display_name, r.r_handle, r.r_avatar_url,
             r.r_grade_year, r.r_src
  ),
  roled as (
    select s.r_user_id, s.r_display_name, s.r_handle, s.r_avatar_url,
           s.r_grade_year, s.r_src, s.r_week_xp,
      case
        when exists (select 1 from public.youth_group_members ygm2
                     where ygm2.group_id = _group_id and ygm2.user_id = s.r_user_id and ygm2.role = 'pastor')
          then 'pastor'
        when exists (select 1 from public.small_group_members sgm
                     join public.small_groups sg on sg.id = sgm.small_group_id
                     where sgm.user_id = s.r_user_id and sgm.role = 'leader'
                       and sg.youth_group_id = _group_id)
          then 'leader'
        when s.r_src = 'parent' then 'parent'
        when s.r_grade_year is not null then 'student'
        else 'member'
      end as r_role_label
    from scored s
  )
  select
    (row_number() over (order by roled.r_week_xp desc,
                                  roled.r_display_name nulls last))::int  as rank,
    roled.r_user_id                                                       as user_id,
    roled.r_display_name                                                  as display_name,
    roled.r_handle                                                        as handle,
    roled.r_avatar_url                                                    as avatar_url,
    roled.r_role_label                                                    as role,
    roled.r_week_xp                                                       as week_xp,
    (roled.r_user_id = v_uid)                                             as is_me
  from roled
  order by roled.r_week_xp desc, roled.r_display_name nulls last
  limit greatest(_limit, 1);
end;
$$;

grant execute on function public.ranking_top_users_in_group(uuid, int) to authenticated, service_role;


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
  v_week_start timestamptz :=
    (date_trunc('week', now() at time zone 'UTC')) at time zone 'UTC';
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_yg from public.youth_groups where id = _group_id;
  if v_yg.id is null then raise exception 'group_not_found'; end if;
  if v_yg.is_default_ygteev then raise exception 'cannot_rank_default_group'; end if;
  if not (public.is_site_admin(v_uid) or public.is_group_member(v_uid, _group_id)) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

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
           )::int                                     as r_active_count,
           coalesce(sum(g.amount), 0)::bigint         as r_week_xp
    from related_pairs rp
    left join public.user_xp_grants g
      on g.user_id = rp.r_user_id and g.awarded_at >= v_week_start
    group by rp.r_group_id
  ),
  classed as (
    select pg.r_group_id, pg.r_active_count, pg.r_week_xp,
           public.xp_class_for(pg.r_active_count) as r_class
    from per_group pg
  ),
  my_class as (
    select c.r_class as c from classed c where c.r_group_id = _group_id
  ),
  class_max as (
    select c.r_class, max(c.r_active_count) as r_max_active
    from classed c
    where c.r_class is not null
    group by c.r_class
  ),
  in_class as (
    select c.r_group_id, c.r_active_count, c.r_week_xp, c.r_class,
           cm.r_max_active,
           least(
             case when c.r_active_count = 0 then 1.0
                  else (cm.r_max_active::numeric / c.r_active_count::numeric)
             end,
             3.00::numeric
           ) as r_multiplier
    from classed c
    join class_max cm on cm.r_class = c.r_class
    where c.r_class = (select c from my_class)
  )
  select
    (row_number() over (
       order by (ic.r_week_xp * ic.r_multiplier) desc,
                ic.r_multiplier asc,
                yg.name nulls last
     ))::int                                              as rank,
    yg.id                                                 as group_id,
    yg.name                                               as name,
    yg.church_name                                        as church_name,
    yg.logo_url                                           as logo_url,
    yg.gradient_from                                      as gradient_from,
    yg.gradient_to                                        as gradient_to,
    ic.r_class                                            as class,
    initcap(ic.r_class)                                   as class_label,
    ic.r_active_count                                     as active_count,
    ic.r_max_active                                       as max_active_in_class,
    round(ic.r_multiplier, 2)                             as multiplier,
    ic.r_week_xp                                          as week_xp,
    floor(ic.r_week_xp * ic.r_multiplier)::bigint         as adjusted_xp,
    (yg.id = _group_id)                                   as is_my_group
  from in_class ic
  join public.youth_groups yg on yg.id = ic.r_group_id
  order by (ic.r_week_xp * ic.r_multiplier) desc,
           ic.r_multiplier asc,
           yg.name nulls last
  limit greatest(_limit, 1);
end;
$$;

grant execute on function public.ranking_top_groups_in_my_class(uuid, int) to authenticated, service_role;
