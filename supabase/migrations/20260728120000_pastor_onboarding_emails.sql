-- Pastor onboarding drip — send log for send-pastor-onboarding-email.
-- unique(group_id, email_no) is the idempotency lock: the dispatcher claims
-- the row BEFORE sending, so an email can never go out twice per group.
-- Server-only table (RLS on, no policies; service role bypasses).
--
-- Emails 1-5 go out on days 1, 3, 5, 7, 9 after group creation, driven by a
-- daily pg_cron job that POSTs {dispatch:true} to the edge function
-- (cron NOT yet scheduled — enable after email copy is approved).
--
-- Applied to staging + prod 2026-07-28.

create table if not exists public.pastor_onboarding_emails (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.youth_groups(id) on delete cascade,
  email_no int not null check (email_no between 1 and 5),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (group_id, email_no)
);
alter table public.pastor_onboarding_emails enable row level security;
