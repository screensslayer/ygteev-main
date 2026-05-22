
-- Bootstrap is complete (service_role_key is in _internal_secrets).
-- Drop the writer RPC so nothing can re-set the value via the public
-- function surface. _get_service_role_key stays — it's the read path
-- the cron + trigger depend on.
drop function if exists public._bootstrap_set_service_key(text);
