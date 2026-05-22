
-- =====================================================================
-- Account purge: admin-initiated hard delete + daily auto-purge cron.
--
-- Soft-delete contract (already in place):
--   - User taps Delete Account in iOS → public.request_account_deletion()
--     stamps profiles.deleted_at = now() and signs them out.
--   - Auth.users row is intentionally left intact for the cooling-off
--     window so admins can audit / restore on request.
--
-- This migration adds the second half:
--   1. public.admin_hard_delete_user(uuid)  — manual override
--   2. public.purge_soft_deleted_profiles() — automated, deletes anything
--      whose profiles.deleted_at is more than 30 days old
--   3. pg_cron job 'purge-soft-deleted-profiles' running daily 03:00 UTC
--
-- Cascade chain when auth.users row is deleted:
--   auth.users  →  public.profiles  (CASCADE)
--                  ├─ public.event_rsvps         (CASCADE)
--                  ├─ public.messages            (CASCADE)
--                  ├─ public.small_group_members (CASCADE)
--                  └─ public.moderation_alerts   (SET NULL on sender / ack)
-- =====================================================================

-- 1. Admin manual override --------------------------------------------------

create or replace function public.admin_hard_delete_user(_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $func$
declare
  v_caller uuid := auth.uid();
begin
  if v_caller is null or not public.is_site_admin(v_caller) then
    raise exception 'forbidden: site admin required'
      using errcode = '42501';
  end if;

  if _user_id is null then
    raise exception 'user_id is required'
      using errcode = '22023';
  end if;

  -- Cascade does the rest.
  delete from auth.users where id = _user_id;
end;
$func$;

revoke all on function public.admin_hard_delete_user(uuid) from public;
grant execute on function public.admin_hard_delete_user(uuid) to authenticated;


-- 2. Automated purge --------------------------------------------------------
-- Returns the number of profiles purged so the cron run is observable in
-- cron.job_run_details.return_message.

create or replace function public.purge_soft_deleted_profiles()
returns integer
language plpgsql
security definer
set search_path = public, auth
as $func$
declare
  v_count integer := 0;
  v_id uuid;
begin
  for v_id in
    select p.id
    from public.profiles p
    where p.deleted_at is not null
      and p.deleted_at < now() - interval '30 days'
  loop
    delete from auth.users where id = v_id;
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$func$;

revoke all on function public.purge_soft_deleted_profiles() from public;
-- Only callable by the cron supervisor (postgres) or an admin via RPC.
grant execute on function public.purge_soft_deleted_profiles() to postgres;


-- 3. Schedule the cron ------------------------------------------------------

-- Make the migration idempotent: unschedule any prior job with the same name.
do $$
begin
  if exists (select 1 from cron.job where jobname = 'purge-soft-deleted-profiles') then
    perform cron.unschedule('purge-soft-deleted-profiles');
  end if;
end $$;

select cron.schedule(
  'purge-soft-deleted-profiles',
  '0 3 * * *',
  $cron$ select public.purge_soft_deleted_profiles(); $cron$
);

notify pgrst, 'reload schema';
