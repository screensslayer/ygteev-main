
-- ---------- Stripe customer id on youth groups ----------
alter table public.youth_groups
  add column if not exists stripe_customer_id text;

-- ---------- stripe_subscriptions table ----------
do $$ begin
  create type public.stripe_subscription_status as enum (
    'trialing','active','past_due','canceled','incomplete','incomplete_expired','unpaid','paused'
  );
exception when duplicate_object then null; end $$;

create table if not exists public.stripe_subscriptions (
  id                       uuid primary key default gen_random_uuid(),
  group_id                 uuid references public.youth_groups(id) on delete cascade,
  pastor_user_id           uuid references auth.users(id) on delete set null,
  draft_id                 uuid references public.pastor_signup_drafts(id) on delete set null,
  stripe_customer_id       text not null,
  stripe_subscription_id   text not null unique,
  stripe_price_id          text not null,
  tier_id                  text references public.subscription_tiers(id),
  status                   public.stripe_subscription_status not null,
  trial_end                timestamptz,
  current_period_start     timestamptz,
  current_period_end       timestamptz,
  cancel_at_period_end     boolean not null default false,
  canceled_at              timestamptz,
  raw_payload              jsonb,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now()
);
create index if not exists ss_group_idx    on public.stripe_subscriptions(group_id);
create index if not exists ss_customer_idx on public.stripe_subscriptions(stripe_customer_id);
create index if not exists ss_status_idx   on public.stripe_subscriptions(status);
alter table public.stripe_subscriptions enable row level security;

drop trigger if exists touch_ss on public.stripe_subscriptions;
create trigger touch_ss before update on public.stripe_subscriptions
  for each row execute function public.touch_updated_at();

drop policy if exists "ss: pastor read"   on public.stripe_subscriptions;
drop policy if exists "ss: admin read"    on public.stripe_subscriptions;
drop policy if exists "ss: no client write" on public.stripe_subscriptions;
create policy "ss: pastor read" on public.stripe_subscriptions for select using (
  pastor_user_id = auth.uid()
  or public.is_site_admin(auth.uid())
  or (group_id is not null and public.is_group_pastor(auth.uid(), group_id))
);
create policy "ss: no client write" on public.stripe_subscriptions for insert with check (false);

-- ---------- stripe_events (webhook idempotency) ----------
create table if not exists public.stripe_events (
  id              text primary key,  -- the Stripe event id
  type            text not null,
  received_at     timestamptz not null default now(),
  payload         jsonb not null,
  processed_at    timestamptz,
  error_message   text
);

-- ---------- finalize_pastor_signup RPC ----------
-- Called by the stripe-webhook function (security definer; bypasses RLS).
-- Idempotent on draft_id: re-runs return the already-finalized group id.
create or replace function public.finalize_pastor_signup(_draft_id uuid)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  _draft public.pastor_signup_drafts;
  _gradient_pairs text[][] := array[
    array['#6B2BFF', '#FF3DA5'],  -- 0
    array['#00E0FF', '#6B2BFF'],  -- 1
    array['#B4FF3C', '#00E0FF'],  -- 2
    array['#FFD60A', '#FF6B35']   -- 3
  ];
  _gradient_from text;
  _gradient_to   text;
  _group_id uuid;
  _full_address text;
begin
  select * into _draft from public.pastor_signup_drafts where id = _draft_id for update;
  if _draft.id is null then raise exception 'draft_not_found'; end if;
  if _draft.finalized_youth_group_id is not null then
    return _draft.finalized_youth_group_id;
  end if;
  if _draft.user_id is null then raise exception 'draft_has_no_user'; end if;

  _gradient_from := _gradient_pairs[coalesce(_draft.gradient_idx, 0) + 1][1];
  _gradient_to   := _gradient_pairs[coalesce(_draft.gradient_idx, 0) + 1][2];
  _full_address  := concat_ws(', ', _draft.address_line, _draft.address_city);

  insert into public.youth_groups (
    name, church_name, description, address, meeting_time,
    latitude, longitude, logo_url,
    gradient_from, gradient_to, is_public,
    is_default_ygteev, created_by
  ) values (
    coalesce(nullif(trim(_draft.group_name), ''), _draft.church_name, 'Untitled Group'),
    coalesce(nullif(trim(_draft.church_name), ''), 'Untitled Church'),
    _draft.description,
    nullif(_full_address, ''),
    nullif(concat_ws(' ', _draft.meeting_day, _draft.meeting_time), ' '),
    _draft.latitude, _draft.longitude,
    _draft.logo_url,
    _gradient_from, _gradient_to,
    coalesce(_draft.public_on_map, true),
    false,
    _draft.user_id
  )
  returning id into _group_id;

  insert into public.youth_group_members (group_id, user_id, role)
  values (_group_id, _draft.user_id, 'pastor')
  on conflict (group_id, user_id) do update set role = 'pastor';

  insert into public.user_roles (user_id, role)
  values (_draft.user_id, 'pastor')
  on conflict (user_id, role) do nothing;

  update public.pastor_signup_drafts
     set stage = 'converted',
         finalized_youth_group_id = _group_id,
         updated_at = now()
   where id = _draft_id;

  return _group_id;
end $$;
