-- Post-baseline cleanup: revoke direct access to _internal_secrets from
-- the public-facing roles. The secrets table is server-only — readable
-- only by SECURITY DEFINER helpers like public._get_service_role_key().
--
-- pg_dump emits these revokes only when they differ from defaults, so they
-- need to be explicit in the migration record to keep staging in sync.

revoke all on table "public"."_internal_secrets" from "anon";
revoke all on table "public"."_internal_secrets" from "authenticated";
