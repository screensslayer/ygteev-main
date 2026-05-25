-- on_auth_user_created trigger on auth.users.
--
-- Prod has this trigger; staging didn't get it because the baseline
-- pg_dump used --schema public, and triggers attached to tables in
-- other schemas live with their host table, not with the function
-- they call. handle_new_user() itself is in public and is in the
-- baseline — only the trigger attachment is missing.
--
-- handle_new_user() runs on every new auth.users row and:
--   - inserts a profiles row with a generated handle, starting XP/water
--   - inserts a user_roles row with role='member'
--   - auto-joins the default YGTeeV youth group
--   - claims any pre-signup external RSVPs that match the email
--
-- Idempotent.

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
