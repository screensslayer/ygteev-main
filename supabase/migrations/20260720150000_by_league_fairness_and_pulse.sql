-- Backyard Garden League fairness: one global leaderboard with a
-- size-fairness multiplier, STORED on by_league_weeks and refreshed by
-- the existing 5-minute berry cron — by_get_league stays a cheap read.
--
--   multiplier = min(max_active_in_league / group_active, 3.0)
--   active     = group MEMBERS with last_opened_at within 90 days
--                (members only — unlike home Rankings, parents don't
--                plant glowberries, so they don't count here)
--   adjusted   = floor(berries * multiplier)  ← league rank key
--
-- Also adds by_garden_pulse(_gid): players today (global + group),
-- trees alive/planted today, top 3 planters this week — powers the
-- in-game live pulse pill and the League Board detail card.
--
-- Applied to staging (nmdfmlcmhauqbbairkjw) + prod (tkesywmshaicjmywbovn)
-- on 2026-07-20; verified on both.

alter table public.by_league_weeks
  add column if not exists active_count int not null default 0,
  add column if not exists multiplier numeric not null default 1.0,
  add column if not exists adjusted int not null default 0;

create or replace function public.by_refresh_league_fairness()
returns void
language plpgsql security definer set search_path = public as $$
declare _week date := (date_trunc('week', now() at time zone 'utc'))::date;
begin
  with actives as (
    select ygm.group_id,
           count(distinct ygm.user_id) filter (
             where p.last_opened_at >= now() - interval '90 days'
           )::int as ac
    from youth_group_members ygm
    join profiles p on p.id = ygm.user_id
    group by ygm.group_id
  ),
  wk as (
    select l.group_id, greatest(coalesce(a.ac, 0), 1) as ac
    from by_league_weeks l
    left join actives a on a.group_id = l.group_id
    where l.week_start = _week
  ),
  mx as (select max(ac) as m from wk)
  update by_league_weeks l
     set active_count = wk.ac,
         multiplier   = round(least(mx.m::numeric / wk.ac::numeric, 3.0), 2),
         adjusted     = floor(l.berries * least(mx.m::numeric / wk.ac::numeric, 3.0))::int
  from wk, mx
  where l.group_id = wk.group_id and l.week_start = _week;
end $$;

revoke execute on function public.by_refresh_league_fairness() from public, anon, authenticated;

create or replace function public.by_accrue_berries()
returns integer
language plpgsql security definer set search_path = public as $$
declare
  _p record;
  _total int;
  _delta int;
  _week date := (date_trunc('week', now() at time zone 'utc'))::date;
  _credited int := 0;
begin
  for _p in
    select * from by_plots where status = 'active' for update skip locked
  loop
    _total := greatest(0, floor(
      extract(epoch from (least(now(), _p.expires_at) - _p.matures_at)) / _p.yield_interval_seconds
    ))::int;
    _delta := _total - _p.berries_credited;
    if _delta > 0 then
      update by_plots set berries_credited = berries_credited + _delta where id = _p.id;
      insert into by_league_weeks (week_start, group_id, berries, fund)
      values (_week, _p.group_id, _delta, _delta * 35)
      on conflict (week_start, group_id) do update set
        berries = by_league_weeks.berries + excluded.berries,
        fund = by_league_weeks.fund + excluded.fund,
        updated_at = now();
      _credited := _credited + _delta;
    end if;
    if now() >= _p.expires_at then
      update by_plots set status = 'expired' where id = _p.id;
    end if;
  end loop;
  perform by_refresh_league_fairness();
  return _credited;
end $$;

drop function if exists public.by_get_league(date);
create or replace function public.by_get_league(_week_start date default null)
returns table(group_id uuid, group_name text, berries integer, fund integer, rank integer,
              active_count integer, multiplier numeric, adjusted integer)
language sql stable security definer set search_path = public as $$
  with wk as (
    select coalesce(_week_start, (date_trunc('week', now() at time zone 'utc'))::date) as w
  )
  select l.group_id, yg.name, l.berries, l.fund,
         (rank() over (order by l.adjusted desc, l.berries desc, l.group_id))::int,
         l.active_count, l.multiplier, l.adjusted
  from by_league_weeks l
  join youth_groups yg on yg.id = l.group_id
  cross join wk
  where l.week_start = wk.w
  order by l.adjusted desc, l.berries desc, l.group_id;
$$;

create or replace function public.by_garden_pulse(_gid uuid default null)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  _day timestamptz := (date_trunc('day', now() at time zone 'utc')) at time zone 'utc';
  _week timestamptz := (date_trunc('week', now() at time zone 'utc')) at time zone 'utc';
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  return jsonb_build_object(
    'players_today', (
      select count(distinct user_id) from by_saves
      where key = 'garden-state' and updated_at >= _day
    ),
    'group_players_today', case when _gid is null then 0 else (
      select count(distinct s.user_id)
      from by_saves s
      join youth_group_members m on m.user_id = s.user_id and m.group_id = _gid
      where s.key = 'garden-state' and s.updated_at >= _day
    ) end,
    'trees_alive', case when _gid is null then 0 else (
      select count(*) from by_plots where group_id = _gid and status = 'active'
    ) end,
    'trees_today', case when _gid is null then 0 else (
      select count(*) from by_plots where group_id = _gid and planted_at >= _day
    ) end,
    'top_planters', case when _gid is null then '[]'::jsonb else coalesce((
      select jsonb_agg(x) from (
        select coalesce(pr.display_name, 'Gardener') as name, count(*)::int as trees
        from by_plots bp
        join profiles pr on pr.id = bp.planted_by
        where bp.group_id = _gid and bp.planted_at >= _week
        group by 1 order by 2 desc limit 3
      ) x
    ), '[]'::jsonb) end
  );
end $$;
