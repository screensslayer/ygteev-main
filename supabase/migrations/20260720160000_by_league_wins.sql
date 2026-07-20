-- Weekly Garden League winners: by_league_wins records one winner per
-- completed week (winner = highest fairness-adjusted score, falling back
-- to raw berries for pre-fairness weeks via greatest(adjusted, berries)).
-- Recorded idempotently by a Monday 00:10 UTC cron (by-close-league-week),
-- with an inline backfill for weeks completed before this migration.
-- Surfaced to the game as by_garden_pulse().league_wins — drawn as the
-- floating "N WINS" gold text above the community-garden countdown.
--
-- Applied to staging + prod 2026-07-20 (staging backfilled 1 winner).

create table if not exists public.by_league_wins (
  week_start date primary key,
  group_id uuid not null references public.youth_groups(id) on delete cascade,
  berries int not null default 0,
  adjusted int not null default 0,
  decided_at timestamptz not null default now()
);
alter table public.by_league_wins enable row level security;
create policy select_all_by_league_wins on public.by_league_wins for select to authenticated using (true);

create or replace function public.by_close_league_week()
returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into by_league_wins (week_start, group_id, berries, adjusted)
  select distinct on (l.week_start)
         l.week_start, l.group_id, l.berries, greatest(l.adjusted, l.berries)
  from by_league_weeks l
  where l.week_start < (date_trunc('week', now() at time zone 'utc'))::date
  order by l.week_start, greatest(l.adjusted, l.berries) desc, l.berries desc, l.group_id
  on conflict (week_start) do nothing;
end $$;

revoke execute on function public.by_close_league_week() from public, anon, authenticated;
select cron.schedule('by-close-league-week', '10 0 * * 1', $$select public.by_close_league_week()$$);
select public.by_close_league_week();

-- by_garden_pulse gains 'league_wins' (see function body in the applied
-- migration of the same name — full recreate with the added key).
