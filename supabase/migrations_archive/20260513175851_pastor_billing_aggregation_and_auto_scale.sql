
-- ---------- One active subscription per pastor, not per group ----------
-- Drop the strict group_id NOT-NULL (was already nullable, but make it
-- explicit that group_id is now informational only — the first group
-- the pastor created during onboarding).
alter table public.stripe_subscriptions
  alter column group_id drop not null;

-- New: a subscription belongs to a pastor; only one active per pastor.
create unique index if not exists ss_one_active_per_pastor
  on public.stripe_subscriptions(pastor_user_id)
  where status in ('trialing','active','past_due');

-- Pending downgrade tracking (we defer downgrades to current_period_end)
alter table public.stripe_subscriptions
  add column if not exists pending_tier_id          text references public.subscription_tiers(id),
  add column if not exists pending_effective_at     timestamptz,
  add column if not exists last_synced_at           timestamptz;

-- ---------- Helper: count active users a pastor is billed for ----------
-- Sums distinct profiles with last_opened_at within 90d across every
-- youth_group_members row where the pastor has role='pastor'.
create or replace function public.pastor_active_user_count(_pastor_user_id uuid)
returns int
language sql stable security definer set search_path = public as $$
  select count(distinct p.id)::int
  from public.youth_group_members owner
  join public.youth_group_members member on member.group_id = owner.group_id
  join public.profiles p on p.id = member.user_id
  where owner.user_id = _pastor_user_id
    and owner.role = 'pastor'
    and p.last_opened_at >= now() - interval '90 days';
$$;

-- ---------- Helper: target tier id for a given active count ----------
-- Walks subscription_tiers in display_order; returns the lowest tier
-- whose max_active >= count. Skips contact-only tiers; if count > all
-- paid tiers' max_active, returns 'mega' (which is is_contact_only).
create or replace function public.target_tier_for_count(_count int)
returns text
language sql stable as $$
  with sorted as (
    select id, max_active, is_contact_only, display_order
    from public.subscription_tiers
    where active = true
    order by display_order
  )
  select id
  from sorted
  where (is_contact_only = false and max_active >= _count) or is_contact_only = true
  order by case when is_contact_only then 1 else 0 end, display_order
  limit 1;
$$;

-- ---------- Pastor billing summary view (for dashboard widgets) ----------
create or replace view public.pastor_billing_summary as
select
  ss.id as subscription_id,
  ss.pastor_user_id,
  ss.status,
  ss.tier_id as current_tier_id,
  t.name as current_tier_name,
  t.range_label as current_range,
  t.max_active as current_max_active,
  public.pastor_active_user_count(ss.pastor_user_id) as active_count,
  public.target_tier_for_count(public.pastor_active_user_count(ss.pastor_user_id)) as target_tier_id,
  ss.pending_tier_id,
  ss.pending_effective_at,
  ss.current_period_end,
  ss.trial_end,
  ss.cancel_at_period_end
from public.stripe_subscriptions ss
left join public.subscription_tiers t on t.id = ss.tier_id;

-- View RLS isn't directly applicable; restrict via the underlying
-- stripe_subscriptions policy. Pastors already read their own row.
grant select on public.pastor_billing_summary to authenticated;

-- ---------- pg_cron daily sync ----------
create extension if not exists pg_cron;

-- Unschedule any previous run to keep things idempotent.
do $$ begin
  perform cron.unschedule('sync-pastor-billing-daily');
exception when others then null; end $$;

-- Daily at 03:00 UTC — kicks the edge function which does the actual
-- per-subscription work.
select cron.schedule(
  'sync-pastor-billing-daily',
  '0 3 * * *',
  $cron$
  select net.http_post(
    url := 'https://tkesywmshaicjmywbovn.supabase.co/functions/v1/sync-pastor-billing',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := jsonb_build_object('triggered_by', 'pg_cron')
  );
  $cron$
);
