
-- Private key-value store for runtime secrets that triggers / cron jobs
-- need to read from inside Postgres. Only SECURITY DEFINER functions
-- should touch it; we lock it down with RLS so anon/authenticated have
-- no access at all.

create table if not exists public._internal_secrets (
  key   text primary key,
  value text not null,
  updated_at timestamptz not null default now()
);

alter table public._internal_secrets enable row level security;
-- No policies = no access for any non-admin role. SECURITY DEFINER
-- functions bypass RLS so the cron + trigger still read freely.

revoke all on public._internal_secrets from anon, authenticated;

-- Replace the bootstrap RPC to write to the table instead of ALTER DATABASE.
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
  if exists (
    select 1 from public._internal_secrets
    where key = 'service_role_key' and length(value) >= 20
  ) then
    return 'already_set';
  end if;
  insert into public._internal_secrets (key, value)
  values ('service_role_key', _value)
  on conflict (key) do update set value = excluded.value, updated_at = now();
  return 'ok';
end;
$$;

-- Helper that returns the stored service role key. Locked-down to
-- SECURITY DEFINER callers (cron / triggers); not granted to
-- authenticated or anon.
create or replace function public._get_service_role_key()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select value from public._internal_secrets where key = 'service_role_key';
$$;

revoke all on function public._get_service_role_key() from public;
revoke all on function public._get_service_role_key() from anon, authenticated;
