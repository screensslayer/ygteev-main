
-- Promo codes that override the default 14-day free trial on pastor
-- signup. Keyed by short text code (used in the shareable signup URL).
-- We track uses_count for analytics and support optional expiry/cap so
-- the site admin can run limited campaigns later. The initial v1 row is
-- `founders` → 90 days, unlimited, never expires.

create table if not exists public.pastor_signup_promos (
  id          uuid        primary key default gen_random_uuid(),
  code        text        not null unique,
  trial_days  integer     not null check (trial_days between 1 and 365),
  label       text,            -- public-facing copy, e.g. "Founders early access"
  description text,            -- internal note
  active      boolean     not null default true,
  expires_at  timestamptz,     -- nullable = never expires
  max_uses    integer,         -- nullable = unlimited
  uses_count  integer     not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists pastor_signup_promos_code_lower_idx
  on public.pastor_signup_promos (lower(code));

alter table public.pastor_signup_promos enable row level security;

-- Anonymous + authenticated can READ via the validation RPC below; no
-- direct table access. Site admin can manage (insert/update/delete).
create policy "promos: admin manage"
  on public.pastor_signup_promos
  for all
  using (is_site_admin(auth.uid()))
  with check (is_site_admin(auth.uid()));

-- Seed the first private code.
insert into public.pastor_signup_promos (code, trial_days, label, description)
values (
  'founders',
  90,
  'Founders Early Access',
  'Private 90-day trial link for the first wave of youth pastors.'
)
on conflict (code) do nothing;

-- Public-callable lookup. Returns the promo if valid, else nulls. The
-- Lovable signup page calls this to show the right "X-day free trial"
-- copy before the user hits checkout.
create or replace function public.get_pastor_signup_promo(_code text)
returns table (
  code        text,
  trial_days  integer,
  label       text,
  valid       boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.code,
    p.trial_days,
    p.label,
    (
      p.active = true
      and (p.expires_at is null or p.expires_at > now())
      and (p.max_uses   is null or p.uses_count < p.max_uses)
    ) as valid
  from public.pastor_signup_promos p
  where lower(p.code) = lower(coalesce(_code, ''))
  limit 1;
$$;

grant execute on function public.get_pastor_signup_promo(text) to anon, authenticated;
