-- supabase/seed.sql
--
-- Staging-only seed data. Runs via `supabase db reset` locally, and is
-- applied manually to the staging project (see STAGING_SETUP.md).
-- Never applied to prod by `supabase db push`.
--
-- Phase A: minimal viable seed (just the default group + reset infra).
-- Phase B (TODO when QA actually needs it): test pastors, members,
-- bible plans, sample chat threads, sample moderation alerts.

-- ---------- 1. Default YGTeeV group ----------
-- Every new user auto-joins this group via trigger. It's the only group
-- that does NOT grant Pro entitlement.
insert into public.youth_groups (id, name, church_name, is_default_ygteev, is_public)
values (
  'adb5f366-0474-49d7-b912-cc9e41258720',  -- same UUID as prod for parity
  'YGTeeV',
  'YGTeeV',
  true,
  true
)
on conflict (id) do nothing;

-- ---------- 2. reset_staging_data() placeholder ----------
-- Phase A version: no-op with a safety check so it can never accidentally
-- run on prod. Phase B will fill in the actual user-gen wipe + reseed.
create or replace function public.reset_staging_data() returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_project_url text;
begin
  -- Safety: refuse to run unless _internal_secrets says we're on staging.
  -- (Set via the staging setup script — see STAGING_SETUP.md.)
  select value into v_project_url
    from public._internal_secrets
   where key = 'project_url';

  if v_project_url is null or v_project_url not like '%nmdfmlcmhauqbbairkjw%' then
    raise exception 'reset_staging_data: refusing to run, _internal_secrets.project_url is not staging (%)', coalesce(v_project_url, '<unset>');
  end if;

  -- TODO Phase B: TRUNCATE user-generated tables (messages, moderation_alerts,
  -- event_rsvps, youth_group_join_requests, user_plan_progress, garden state,
  -- non-seeded auth.users, etc.) and re-run this seed.sql block above.
  raise notice 'reset_staging_data: Phase A placeholder, no rows touched';
end;
$$;

revoke all on function public.reset_staging_data() from public, anon, authenticated;

-- ---------- 3. Sunday-night reset cron ----------
-- Runs Sunday 23:00 UTC. Idempotent: unschedule any prior version first.
do $$
begin
  perform cron.unschedule('staging-weekly-reset')
   where exists (select 1 from cron.job where jobname = 'staging-weekly-reset');
exception when others then null;
end $$;

select cron.schedule(
  'staging-weekly-reset',
  '0 23 * * 0',
  $cmd$select public.reset_staging_data();$cmd$
);
