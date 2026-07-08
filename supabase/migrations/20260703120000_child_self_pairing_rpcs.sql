-- Under-13 onboarding: child-first "signup handoff" flow.
--
-- The reimagined under-13 flow never signs the child up on their
-- own device. The kid device stays anonymous; the PARENT scans a
-- QR and calls `create-child-account` to mint the child. The kid
-- device then polls a shared handoff row and, once the parent's
-- flow completes, redeems the resulting pairing token via the
-- existing `redeem-child-pairing-token` edge function to install
-- a session locally.
--
-- The handoff row is what lets both devices refer to the same
-- in-progress signup before the child account exists:
--
--   1. Kid device (anon) → `create_signup_handoff(...)` inserts a
--      row with a random nonce + demographics the kid already
--      collected on their device (display_name, grade_year, dob).
--   2. Kid device shows QR encoding `ygteev://claim-child?nonce=X`
--      + a human-readable format of the nonce for typed fallback.
--   3. Parent device scans → deep-link handler → calls
--      `create-child-account` with the `signup_handoff_nonce`.
--      The edge function reads demographics from the handoff row
--      (server-side; ignores whatever the parent client sent for
--      those fields) and mints the child account + pairing token.
--      It stamps `child_user_id`, `pairing_token`, `numeric_code`,
--      `redeemed_at` back onto the handoff row.
--   4. Kid device polls `poll_signup_handoff(_nonce)` every 3s.
--      When status = "ready" and `pairing_token` is populated, the
--      kid device calls `redeem-child-pairing-token(token: ...)`,
--      which returns a session and refreshes currentUser.
--
-- The existing parent-first flow (parent taps "Add a kid" without
-- a QR) still works unchanged — the handoff nonce is optional on
-- create-child-account.

-- =============================================================
-- child_signup_handoffs
-- =============================================================
create table if not exists public.child_signup_handoffs (
    id             uuid primary key default gen_random_uuid(),
    nonce          text unique not null,
    expires_at     timestamptz not null default now() + interval '15 minutes',
    redeemed_at    timestamptz,
    child_user_id  uuid,
    pairing_token  text,
    numeric_code   text,
    display_name   text,
    grade_year     int,
    date_of_birth  date,
    created_at     timestamptz not null default now(),
    constraint child_signup_handoffs_grade_check
        check (grade_year is null or (grade_year between 1 and 20))
);

alter table public.child_signup_handoffs owner to postgres;
alter table public.child_signup_handoffs enable row level security;

-- No public policies — all access goes through SECURITY DEFINER
-- RPCs below (poll_signup_handoff for the kid, and service-role
-- writes from the create-child-account edge function). This keeps
-- the raw table sealed off from clients even though the RPCs
-- themselves are anon-callable.

create index if not exists child_signup_handoffs_nonce_active_idx
  on public.child_signup_handoffs (nonce)
  where redeemed_at is null;

-- =============================================================
-- create_signup_handoff — anon-callable
-- =============================================================
--
-- Inserts a handoff row on behalf of an unauthenticated kid device
-- and returns the nonce it should show the parent. Demographics
-- (display_name, grade_year, date_of_birth) are captured now so
-- the parent's `create-child-account` call can pull them
-- server-side; the kid device doesn't have to re-transmit them
-- through the parent's request.
--
-- Bounded retry on unique_violation for the extremely rare nonce
-- collision. 8 hex chars → ~4 billion possibilities × 5 retries;
-- the odds are cosmological.

create or replace function public.create_signup_handoff(
    _display_name text default null,
    _grade_year int default null,
    _date_of_birth date default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  _fresh_nonce text;
  _fresh_expires timestamptz;
begin
  for i in 1..5 loop
    -- 8 hex chars, uppercased. Human-typeable at ~"A3F72C81".
    _fresh_nonce := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
    begin
      insert into public.child_signup_handoffs (
        nonce, display_name, grade_year, date_of_birth
      ) values (
        _fresh_nonce,
        nullif(trim(coalesce(_display_name, '')), ''),
        _grade_year,
        _date_of_birth
      )
      returning expires_at into _fresh_expires;

      return jsonb_build_object(
        'nonce', _fresh_nonce,
        'expires_at', _fresh_expires
      );
    exception when unique_violation then
      continue;
    end;
  end loop;

  raise exception 'nonce_generation_exhausted' using errcode = '55000';
end
$$;

alter function public.create_signup_handoff(text, int, date) owner to postgres;

grant execute on function public.create_signup_handoff(text, int, date) to anon;
grant execute on function public.create_signup_handoff(text, int, date) to authenticated;
grant execute on function public.create_signup_handoff(text, int, date) to service_role;

-- =============================================================
-- poll_signup_handoff — anon-callable
-- =============================================================
--
-- Returns one of:
--   { status: "unknown" }                 — nonce doesn't match a row
--   { status: "pending" }                 — row exists, not redeemed
--   { status: "expired" }                 — row expired without redemption
--   { status: "ready",
--     pairing_token: "...",
--     numeric_code:  "..." }              — parent finished; go redeem
--
-- Nonce matching is case-insensitive (upper()) so a hand-typed
-- lowercase nonce still hits the row.

create or replace function public.poll_signup_handoff(_nonce text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  _row public.child_signup_handoffs;
begin
  select * into _row
    from public.child_signup_handoffs
   where upper(nonce) = upper(coalesce(trim(_nonce), ''))
   limit 1;

  if not found then
    return jsonb_build_object('status', 'unknown');
  end if;

  if _row.redeemed_at is not null and _row.pairing_token is not null then
    return jsonb_build_object(
      'status', 'ready',
      'pairing_token', _row.pairing_token,
      'numeric_code', _row.numeric_code
    );
  end if;

  if _row.expires_at < now() then
    return jsonb_build_object('status', 'expired');
  end if;

  return jsonb_build_object('status', 'pending');
end
$$;

alter function public.poll_signup_handoff(text) owner to postgres;

grant execute on function public.poll_signup_handoff(text) to anon;
grant execute on function public.poll_signup_handoff(text) to authenticated;
grant execute on function public.poll_signup_handoff(text) to service_role;
