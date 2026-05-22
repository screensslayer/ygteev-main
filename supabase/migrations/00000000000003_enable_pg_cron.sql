-- pg_cron extension. Prod has it (installed via dashboard before our
-- migration history started); the public-schema baseline pg_dump didn't
-- include it because pg_cron lives in pg_catalog.
--
-- Idempotent: no-op when applied to any environment that already has it.

create extension if not exists pg_cron;
