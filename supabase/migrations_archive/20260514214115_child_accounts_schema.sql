
-- =============================================================================
-- Under-13 child account support
--   • profiles.date_of_birth, grade_year, parent_account_id, is_managed_child
--   • child_pairing_tokens: one-time QR/numeric code → session exchange
--   • CHECK constraint: under-13 profiles must have parent_account_id
--   • RLS: parents can read/write their kids' profiles
-- Adult cutoff: 18 → grade_year is null for adults
-- =============================================================================

-- 1. New profile columns
alter table public.profiles
  add column if not exists date_of_birth     date,
  add column if not exists grade_year        int check (grade_year is null or (grade_year between 1 and 20)),
  add column if not exists parent_account_id uuid references public.profiles(id) on delete set null,
  add column if not exists is_managed_child  boolean not null default false;

create index if not exists profiles_parent_account_idx
  on public.profiles(parent_account_id) where parent_account_id is not null;

-- 2. CHECK constraint — under-13 must be a managed child with a parent.
--    NOT VALID so existing rows aren't blocked; only enforced on new data.
do $$
begin
  if not exists (select 1 from pg_constraint
                 where conname = 'profiles_under_13_needs_parent') then
    alter table public.profiles
      add constraint profiles_under_13_needs_parent
      check (
        date_of_birth is null
        or date_of_birth <= current_date - interval '13 years'
        or (parent_account_id is not null and is_managed_child = true)
      ) not valid;
  end if;
end $$;

-- 3. child_pairing_tokens
create table if not exists public.child_pairing_tokens (
  id                      uuid primary key default gen_random_uuid(),
  child_user_id           uuid not null references public.profiles(id) on delete cascade,
  token                   text not null unique,           -- 32-char hex
  numeric_code            text not null,                  -- 8-digit fallback
  created_by              uuid not null references public.profiles(id) on delete cascade,
  created_at              timestamptz not null default now(),
  expires_at              timestamptz not null default (now() + interval '5 minutes'),
  redeemed_at             timestamptz,
  redeemed_from_user_agent text
);

create index if not exists child_pairing_tokens_token_active_idx
  on public.child_pairing_tokens(token) where redeemed_at is null;
create index if not exists child_pairing_tokens_numeric_active_idx
  on public.child_pairing_tokens(numeric_code) where redeemed_at is null;

alter table public.child_pairing_tokens enable row level security;

-- Parent who created can SELECT their tokens (to display QR + numeric code)
drop policy if exists "child_pairing_tokens: creator read" on public.child_pairing_tokens;
create policy "child_pairing_tokens: creator read" on public.child_pairing_tokens
  for select using (created_by = auth.uid());

-- No client-side writes; redemption happens via service-role Edge Function.

-- 4. Parent can read + write their child's profile
drop policy if exists "profiles: parent of child read"   on public.profiles;
create policy "profiles: parent of child read" on public.profiles
  for select using (
    parent_account_id = auth.uid()
  );

drop policy if exists "profiles: parent of child update" on public.profiles;
create policy "profiles: parent of child update" on public.profiles
  for update using (parent_account_id = auth.uid())
            with check (parent_account_id = auth.uid());

-- 5. Convenience: derived age helpers
create or replace function public.profile_is_under_13(_dob date)
returns boolean
language sql immutable as $$
  select _dob is not null and _dob > current_date - interval '13 years';
$$;

create or replace function public.profile_is_adult(_dob date)
returns boolean
language sql immutable as $$
  select _dob is null or _dob <= current_date - interval '18 years';
$$;

grant execute on function public.profile_is_under_13(date) to authenticated;
grant execute on function public.profile_is_adult(date) to authenticated;

notify pgrst, 'reload schema';
