-- Welcome bonus moves to signup time: every new profile gets +3000 XP
-- the moment it's created, rather than waiting for the client to finish
-- onboarding (which a client bug silently skipped for some users) or for
-- the hourly sweep's grace period.
--
-- Three coordinated pieces so nothing double-grants:
--   1. AFTER INSERT trigger on profiles → +3000, logged 'signup_welcome_bonus'.
--      Covers every creation path (email signup, child accounts). Errors
--      degrade to a warning so the bonus can never block account creation.
--   2. complete_onboarding() skips its bonus when any welcome-type grant
--      exists — still stamps completion, still reports honestly
--      (xp_awarded: 0). Onboarding UX is otherwise unchanged.
--   3. sweep_welcome_bonus() treats 'signup_welcome_bonus' as satisfied,
--      drops the 24h grace (the trigger makes it moot), and no longer
--      stamps onboarding_completed_at (that's the client flow's job).
--      Kept on hourly pg_cron purely as backup for trigger failures.
--
-- Applied to prod (tkesywmshaicjmywbovn) + staging (nmdfmlcmhauqbbairkjw)
-- 2026-07-20. Verified on staging with a synthetic signup: profile landed
-- with xp 3000 and one signup_welcome_bonus grant; test user deleted.

create or replace function public.tg_grant_signup_welcome_bonus()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update profiles
    set xp = xp + 3000, lifetime_xp = lifetime_xp + 3000
    where id = new.id;
  insert into user_xp_grants (user_id, amount, source)
    values (new.id, 3000, 'signup_welcome_bonus');
  return new;
exception when others then
  -- never let the bonus block account creation; the sweep will catch it
  raise warning 'signup welcome bonus failed for %: %', new.id, sqlerrm;
  return new;
end $$;

drop trigger if exists profiles_signup_welcome_bonus on public.profiles;
create trigger profiles_signup_welcome_bonus
  after insert on public.profiles
  for each row execute function public.tg_grant_signup_welcome_bonus();

create or replace function public.complete_onboarding()
returns jsonb
language plpgsql security definer set search_path = public as $$
declare _uid uuid := auth.uid(); _p profiles; _bonus int := 3000;
begin
  if _uid is null then raise exception 'not_authenticated'; end if;
  select * into _p from profiles where id = _uid for update;
  if _p.onboarding_completed_at is not null then
    return jsonb_build_object('already_completed', true, 'xp_awarded', 0, 'total_xp', _p.xp);
  end if;
  if exists (
    select 1 from user_xp_grants
    where user_id = _uid
      and source in ('signup_welcome_bonus', 'onboarding_welcome_bonus', 'onboarding_backfill', 'onboarding_welcome_sweep')
  ) then
    _bonus := 0; -- already granted at signup (or by backfill/sweep)
  end if;
  update profiles set
    onboarding_completed_at = now(), xp = xp + _bonus, lifetime_xp = lifetime_xp + _bonus,
    updated_at = now() where id = _uid returning * into _p;
  if _bonus > 0 then
    insert into user_xp_grants (user_id, amount, source) values (_uid, _bonus, 'onboarding_welcome_bonus');
  end if;
  return jsonb_build_object('already_completed', false, 'xp_awarded', _bonus, 'total_xp', _p.xp);
end $$;

create or replace function public.sweep_welcome_bonus()
returns int
language plpgsql security definer set search_path = public as $$
declare _n int := 0; r record;
begin
  for r in
    select p.id from profiles p
    where p.onboarding_completed_at is null
      and not exists (
        select 1 from user_xp_grants g
        where g.user_id = p.id
          and g.source in ('signup_welcome_bonus', 'onboarding_welcome_bonus', 'onboarding_backfill', 'onboarding_welcome_sweep')
      )
    for update of p skip locked
  loop
    update profiles
      set xp = xp + 3000,
          lifetime_xp = lifetime_xp + 3000,
          updated_at = now()
      where id = r.id;
    insert into user_xp_grants (user_id, amount, source)
      values (r.id, 3000, 'onboarding_welcome_sweep');
    _n := _n + 1;
  end loop;
  return _n;
end $$;
