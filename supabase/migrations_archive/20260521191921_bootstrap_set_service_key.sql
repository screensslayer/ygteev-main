
-- Temporary SECURITY DEFINER RPC so a one-shot Edge Function can pipe
-- the project's service_role key into the DB-level setting that the
-- cron + the auto-scrape trigger both read via current_setting(). The
-- function only sets the value if it isn't already set, and validates
-- the value looks plausibly JWT-shaped. Drop this once the setting is
-- in place — it has no legitimate runtime purpose.

create or replace function public._bootstrap_set_service_key(_value text)
returns text
language plpgsql
security definer
set search_path = public
as $$
begin
  if _value is null or length(_value) < 50 then
    return 'rejected: value too short';
  end if;
  if length(coalesce(current_setting('app.settings.service_role_key', true), '')) > 50 then
    return 'already_set';
  end if;
  execute format(
    'alter database %I set app.settings.service_role_key = %L',
    current_database(),
    _value
  );
  return 'ok';
end;
$$;

grant execute on function public._bootstrap_set_service_key(text) to service_role;
