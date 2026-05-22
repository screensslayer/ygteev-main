
-- Drop the old 3-arg version. The new 4-arg version has bio defaulting
-- to null so it's fully backward compatible. Keeping both creates
-- PostgREST ambiguity.
drop function if exists public.update_managed_profile(uuid, text, text);

select pg_get_function_identity_arguments(oid)
from pg_proc where proname='update_managed_profile';
