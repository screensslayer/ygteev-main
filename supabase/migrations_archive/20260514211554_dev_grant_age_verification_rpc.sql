
-- =============================================================================
-- Dev-only bypass: stamp profiles.age_verified_at without going through the
-- $0.99 StoreKit IAP. Used by the iOS family-setup paywall's "Skip (dev)"
-- button so the flow is testable in the simulator.
--
-- ⚠️ DROP THIS BEFORE PRODUCTION. Any authenticated user can call it on
--    themselves. Safe in dev/staging where there's no real $ at stake.
-- =============================================================================

create or replace function public._dev_grant_age_verification()
returns timestamptz
language plpgsql
security definer
set search_path = public
as $func$
declare
  v_caller uuid := auth.uid();
  v_when timestamptz := now();
begin
  if v_caller is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  update public.profiles
    set age_verified_at = v_when,
        updated_at      = now()
    where id = v_caller;

  return v_when;
end;
$func$;

grant execute on function public._dev_grant_age_verification() to authenticated;
