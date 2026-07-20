-- Safety net: every user eventually receives the 3000 XP welcome bonus,
-- even if the iOS client never calls complete_onboarding() (bug seen
-- 2026-07-20: three signups finished onboarding with no server calls,
-- missing both the welcome bonus and question XP).
--
-- Hourly pg_cron sweep grants the 3000 to any account >24h old with no
-- onboarding_completed_at and no welcome-bonus-type grant. The 24h grace
-- period keeps it from firing on brand-new users mid-onboarding (their
-- client still grants at completion). Stamping onboarding_completed_at
-- means the existing complete_onboarding() guard prevents double-grants
-- in either direction.
--
-- Applied to prod (tkesywmshaicjmywbovn) + staging (nmdfmlcmhauqbbairkjw)
-- on 2026-07-20; initial prod sweep granted 65 (6 recent + 59 legacy).

create or replace function public.sweep_welcome_bonus()
returns int
language plpgsql security definer set search_path = public as $$
declare _n int := 0; r record;
begin
  for r in
    select p.id from profiles p
    join auth.users u on u.id = p.id
    where p.onboarding_completed_at is null
      and u.created_at < now() - interval '24 hours'
      and not exists (
        select 1 from user_xp_grants g
        where g.user_id = p.id
          and g.source in ('onboarding_welcome_bonus', 'onboarding_backfill', 'onboarding_welcome_sweep')
      )
    for update of p skip locked
  loop
    update profiles
      set xp = xp + 3000,
          lifetime_xp = lifetime_xp + 3000,
          onboarding_completed_at = now(),
          updated_at = now()
      where id = r.id;
    insert into user_xp_grants (user_id, amount, source)
      values (r.id, 3000, 'onboarding_welcome_sweep');
    _n := _n + 1;
  end loop;
  return _n;
end $$;

revoke execute on function public.sweep_welcome_bonus() from public, anon, authenticated;

select cron.schedule('sweep-welcome-bonus', '15 * * * *', $$select public.sweep_welcome_bonus()$$);
