
-- ---------- subscription_tiers (admin-managed, design slider reads from here) ----------
create table if not exists public.subscription_tiers (
  id              text primary key,        -- slug, e.g. 'starter'
  display_order   int not null,            -- 0..5
  name            text not null,           -- 'Starter', 'Growing', ...
  range_label     text not null,           -- '1—19', '20—49', ...
  max_active      int  not null,           -- ceiling; 200 for the open-ended top tier
  price_cents     int  not null,           -- monthly price in cents
  currency        text not null default 'usd',
  stripe_price_id text,                    -- populated after creating prices in Stripe dashboard
  active          boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
alter table public.subscription_tiers enable row level security;

drop policy if exists "tiers: public read"  on public.subscription_tiers;
drop policy if exists "tiers: admin write"  on public.subscription_tiers;
create policy "tiers: public read" on public.subscription_tiers for select using (active = true);
create policy "tiers: admin write" on public.subscription_tiers for all
  using (public.is_site_admin(auth.uid()))
  with check (public.is_site_admin(auth.uid()));

drop trigger if exists touch_subscription_tiers on public.subscription_tiers;
create trigger touch_subscription_tiers before update on public.subscription_tiers
  for each row execute function public.touch_updated_at();

insert into public.subscription_tiers (id, display_order, name, range_label, max_active, price_cents)
values
  ('starter',     0, 'Starter',     '1—19',    19,  2900),
  ('growing',     1, 'Growing',     '20—49',   49,  5900),
  ('established', 2, 'Established', '50—99',   99,  9900),
  ('big',         3, 'Big',         '100—149', 149, 12900),
  ('bigger',      4, 'Bigger',      '150—199', 199, 15900),
  ('mega',        5, 'Mega',        '200+',    200, 18900)
on conflict (id) do update
  set display_order = excluded.display_order,
      name          = excluded.name,
      range_label   = excluded.range_label,
      max_active    = excluded.max_active,
      price_cents   = excluded.price_cents;

-- ---------- pastor_signup_drafts (partial-save so abandoned signups resume) ----------
do $$ begin
  create type public.pastor_signup_stage as enum
    ('account','group','brand','tours','pricing','checkout','converted','abandoned');
exception when duplicate_object then null; end $$;

create table if not exists public.pastor_signup_drafts (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid references auth.users(id) on delete set null,
  email           text,                 -- captured before auth user exists, in case
  first_name      text,
  last_name       text,
  -- group data
  church_name     text,
  address_line    text,
  address_city    text,
  latitude        double precision,
  longitude       double precision,
  meeting_day     text,
  meeting_time    text,
  -- brand data
  group_name      text,
  description     text,
  gradient_idx    int default 0,
  logo_url        text,
  public_on_map   boolean default true,
  -- pricing
  tier_id         text references public.subscription_tiers(id),
  -- progress
  stage           public.pastor_signup_stage not null default 'account',
  resumed_at      timestamptz,
  reminder_sent_at timestamptz,
  finalized_youth_group_id uuid references public.youth_groups(id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index if not exists psd_user_idx on public.pastor_signup_drafts(user_id);
create index if not exists psd_email_idx on public.pastor_signup_drafts(lower(email));
create index if not exists psd_stage_idx on public.pastor_signup_drafts(stage);
alter table public.pastor_signup_drafts enable row level security;

drop trigger if exists touch_psd on public.pastor_signup_drafts;
create trigger touch_psd before update on public.pastor_signup_drafts
  for each row execute function public.touch_updated_at();

drop policy if exists "psd: self read"   on public.pastor_signup_drafts;
drop policy if exists "psd: self upsert" on public.pastor_signup_drafts;
drop policy if exists "psd: admin read"  on public.pastor_signup_drafts;

create policy "psd: self read" on public.pastor_signup_drafts for select using (
  user_id = auth.uid() or public.is_site_admin(auth.uid())
);
create policy "psd: self upsert" on public.pastor_signup_drafts for all using (
  user_id = auth.uid() or public.is_site_admin(auth.uid())
) with check (
  user_id = auth.uid() or public.is_site_admin(auth.uid())
);
