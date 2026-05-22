-- Weekly ranking snapshots + report RPCs for CMS. Snapshots are
-- captured every Monday 00:05 UTC for the just-ended week, so reports
-- can be pulled for any past week. Live current-week stats still come
-- from ranking_top_groups_in_my_class / ranking_top_users_in_group.

-- ============================================================================
-- Snapshot tables
-- ============================================================================
create table if not exists public.weekly_ranking_snapshots (
  id uuid primary key default gen_random_uuid(),
  week_start date not null,
  group_id uuid not null references public.youth_groups(id) on delete cascade,
  class text not null,
  active_count int not null,
  week_xp bigint not null,
  multiplier numeric(5,2) not null,
  adjusted_xp bigint not null,
  rank_in_class int not null,
  total_groups_in_class int not null,
  created_at timestamptz not null default now(),
  unique (week_start, group_id)
);

create index if not exists weekly_ranking_snapshots_class_idx
  on public.weekly_ranking_snapshots (week_start, class, rank_in_class);
create index if not exists weekly_ranking_snapshots_group_idx
  on public.weekly_ranking_snapshots (group_id, week_start desc);

create table if not exists public.weekly_user_ranking_snapshots (
  id uuid primary key default gen_random_uuid(),
  week_start date not null,
  group_id uuid not null references public.youth_groups(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  week_xp bigint not null,
  rank_in_group int not null,
  created_at timestamptz not null default now(),
  unique (week_start, group_id, user_id)
);

create index if not exists weekly_user_ranking_snapshots_group_week_idx
  on public.weekly_user_ranking_snapshots (group_id, week_start desc, rank_in_group);

-- RLS: enable but no public policies. All access via SECURITY DEFINER RPCs.
alter table public.weekly_ranking_snapshots enable row level security;
alter table public.weekly_user_ranking_snapshots enable row level security;

-- ============================================================================
-- The snapshot worker — idempotent, snapshots the JUST-ENDED week
-- ============================================================================
create or replace function public.snapshot_last_week_rankings()
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  v_this_monday date  := (date_trunc('week', now() at time zone 'UTC'))::date;
  v_last_monday date  := v_this_monday - 7;
  v_window_start timestamptz := (v_last_monday::timestamp)::timestamptz at time zone 'UTC';
  v_window_end   timestamptz := (v_this_monday::timestamp)::timestamptz at time zone 'UTC';
begin
  if exists (select 1 from public.weekly_ranking_snapshots where week_start = v_last_monday) then
    return;  -- idempotent
  end if;

  -- Group rankings
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
             where rp.last_opened_at >= v_window_end - interval '90 days'
           )::int as active_count,
           coalesce(sum(g.amount), 0)::bigint as week_xp
    from related_pairs rp
    left join public.user_xp_grants g
      on g.user_id = rp.user_id
     and g.awarded_at >= v_window_start
     and g.awarded_at <  v_window_end
    group by rp.group_id
  ),
  classed as (
    select pg.group_id, pg.active_count, pg.week_xp,
           public.xp_class_for(pg.active_count) as class
    from per_group pg
    where pg.active_count > 0
  ),
  class_meta as (
    select class, max(active_count) as max_active, count(*) as total_in_class
    from classed
    group by class
  ),
  with_multiplier as (
    select c.group_id, c.active_count, c.week_xp, c.class,
           cm.max_active, cm.total_in_class,
           least(
             case when c.active_count = 0 then 1.0
                  else (cm.max_active::numeric / c.active_count::numeric)
             end,
             3.00::numeric
           ) as multiplier
    from classed c
    join class_meta cm on cm.class = c.class
  ),
  ranked as (
    select wm.*,
           floor(wm.week_xp * wm.multiplier)::bigint as adjusted_xp,
           row_number() over (
             partition by wm.class
             order by floor(wm.week_xp * wm.multiplier) desc, wm.multiplier asc
           )::int as rank_in_class
    from with_multiplier wm
  )
  insert into public.weekly_ranking_snapshots
    (week_start, group_id, class, active_count, week_xp,
     multiplier, adjusted_xp, rank_in_class, total_groups_in_class)
  select v_last_monday, group_id, class, active_count, week_xp,
         round(multiplier, 2), adjusted_xp, rank_in_class, total_in_class
  from ranked;

  -- Top 25 users per group (only users with > 0 XP that week)
  with related_pairs as (
    select yg.id as group_id, p.id as user_id
    from public.youth_groups yg
    join public.youth_group_members ygm on ygm.group_id = yg.id
    join public.profiles p on p.id = ygm.user_id
    where yg.is_default_ygteev = false
    union
    select yg.id, parent_p.id
    from public.youth_groups yg
    join public.youth_group_members child_ygm on child_ygm.group_id = yg.id
    join public.family_members fm_child
      on fm_child.user_id = child_ygm.user_id and fm_child.role = 'child'
    join public.family_members fm_parent
      on fm_parent.family_id = fm_child.family_id and fm_parent.role = 'parent'
    join public.profiles parent_p on parent_p.id = fm_parent.user_id
    where yg.is_default_ygteev = false
  ),
  per_user as (
    select rp.group_id, rp.user_id,
           coalesce(sum(g.amount), 0)::bigint as week_xp
    from related_pairs rp
    left join public.user_xp_grants g
      on g.user_id = rp.user_id
     and g.awarded_at >= v_window_start
     and g.awarded_at <  v_window_end
    group by rp.group_id, rp.user_id
  ),
  ranked_users as (
    select pu.group_id, pu.user_id, pu.week_xp,
           row_number() over (
             partition by pu.group_id
             order by pu.week_xp desc, pu.user_id
           )::int as rank
    from per_user pu
    where pu.week_xp > 0
  )
  insert into public.weekly_user_ranking_snapshots
    (week_start, group_id, user_id, week_xp, rank_in_group)
  select v_last_monday, group_id, user_id, week_xp, rank
  from ranked_users
  where rank <= 25;
end;
$$;

-- ============================================================================
-- Schedule: every Monday at 00:05 UTC (5-min buffer for late grants)
-- ============================================================================
do $$
begin
  perform cron.schedule(
    'snapshot-weekly-rankings',
    '5 0 * * 1',
    'select public.snapshot_last_week_rankings()'
  );
exception when undefined_function or undefined_table then
  -- pg_cron not installed in this env — skip silently. Manual call
  -- still works via SELECT.
  null;
end $$;

-- ============================================================================
-- Reports
-- ============================================================================

-- Site admin: every group's snapshot for a given week, class-by-class
create or replace function public.admin_weekly_ranking_report(
  _week_start date default null
)
returns table(
  week_start date,
  class text,
  class_label text,
  total_groups_in_class int,
  rank_in_class int,
  group_id uuid,
  group_name text,
  church_name text,
  logo_url text,
  active_count int,
  week_xp bigint,
  multiplier numeric,
  adjusted_xp bigint
)
language plpgsql stable security definer
set search_path = public
as $$
declare
  v_week date := coalesce(_week_start,
    (date_trunc('week', now() at time zone 'UTC')::date - 7));
begin
  if not public.is_site_admin(auth.uid()) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  return query
  select s.week_start,
         s.class,
         initcap(s.class)            as class_label,
         s.total_groups_in_class,
         s.rank_in_class,
         s.group_id,
         yg.name                     as group_name,
         yg.church_name,
         yg.logo_url,
         s.active_count, s.week_xp, s.multiplier, s.adjusted_xp
  from public.weekly_ranking_snapshots s
  join public.youth_groups yg on yg.id = s.group_id
  where s.week_start = v_week
  order by s.class, s.rank_in_class;
end;
$$;

grant execute on function public.admin_weekly_ranking_report(date) to authenticated, service_role;

-- Pastor: their group's snapshot for a given week + top 25 members
create or replace function public.pastor_weekly_ranking_report(
  _group_id uuid,
  _week_start date default null
)
returns jsonb
language plpgsql stable security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_week date := coalesce(_week_start,
    (date_trunc('week', now() at time zone 'UTC')::date - 7));
  v_group public.weekly_ranking_snapshots;
  v_members jsonb;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if not (public.is_site_admin(v_uid)
          or public.is_group_pastor(v_uid, _group_id)) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  select * into v_group
  from public.weekly_ranking_snapshots
  where week_start = v_week and group_id = _group_id;

  if v_group.id is null then
    return jsonb_build_object(
      'week_start', v_week,
      'group_id', _group_id,
      'has_data', false
    );
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'rank',          u.rank_in_group,
    'user_id',       u.user_id,
    'display_name',  p.display_name,
    'handle',        p.handle,
    'avatar_url',    p.avatar_url,
    'role',          case
      when exists (select 1 from public.youth_group_members ygm
                   where ygm.group_id = _group_id and ygm.user_id = u.user_id and ygm.role = 'pastor')
        then 'pastor'
      when exists (select 1 from public.small_group_members sgm
                   join public.small_groups sg on sg.id = sgm.small_group_id
                   where sgm.user_id = u.user_id and sgm.role = 'leader'
                     and sg.youth_group_id = _group_id)
        then 'leader'
      when exists (select 1 from public.family_members fm_parent
                   join public.family_members fm_child
                     on fm_child.family_id = fm_parent.family_id and fm_child.role = 'child'
                   join public.youth_group_members child_ygm
                     on child_ygm.user_id = fm_child.user_id and child_ygm.group_id = _group_id
                   where fm_parent.user_id = u.user_id and fm_parent.role = 'parent')
        then 'parent'
      when p.grade_year is not null then 'student'
      else 'member'
    end,
    'grade_year',    p.grade_year,
    'week_xp',       u.week_xp
  ) order by u.rank_in_group), '[]'::jsonb)
  into v_members
  from public.weekly_user_ranking_snapshots u
  join public.profiles p on p.id = u.user_id
  where u.week_start = v_week and u.group_id = _group_id;

  return jsonb_build_object(
    'week_start',             v_group.week_start,
    'group_id',               v_group.group_id,
    'has_data',               true,
    'class',                  v_group.class,
    'class_label',            initcap(v_group.class),
    'rank_in_class',          v_group.rank_in_class,
    'total_groups_in_class',  v_group.total_groups_in_class,
    'active_count',           v_group.active_count,
    'week_xp',                v_group.week_xp,
    'multiplier',             v_group.multiplier,
    'adjusted_xp',            v_group.adjusted_xp,
    'top_members',            v_members
  );
end;
$$;

grant execute on function public.pastor_weekly_ranking_report(uuid, date) to authenticated, service_role;

-- Pastor: last N weeks of their group's snapshots (for trend chart)
create or replace function public.pastor_weekly_ranking_history(
  _group_id uuid,
  _weeks int default 12
)
returns table(
  week_start date,
  class text,
  class_label text,
  rank_in_class int,
  total_groups_in_class int,
  active_count int,
  week_xp bigint,
  multiplier numeric,
  adjusted_xp bigint
)
language plpgsql stable security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if not (public.is_site_admin(v_uid)
          or public.is_group_pastor(v_uid, _group_id)) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  return query
  select s.week_start, s.class, initcap(s.class) as class_label,
         s.rank_in_class, s.total_groups_in_class,
         s.active_count, s.week_xp, s.multiplier, s.adjusted_xp
  from public.weekly_ranking_snapshots s
  where s.group_id = _group_id
  order by s.week_start desc
  limit greatest(_weeks, 1);
end;
$$;

grant execute on function public.pastor_weekly_ranking_history(uuid, int) to authenticated, service_role;
