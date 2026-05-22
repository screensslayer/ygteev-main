
create or replace function public._bootstrap_set_service_key(_value text)
returns text
language plpgsql
security definer
set search_path = public
as $$
begin
  if _value is null or length(_value) < 20 then
    return 'rejected: value too short';
  end if;
  if length(coalesce(current_setting('app.settings.service_role_key', true), '')) >= 20 then
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
