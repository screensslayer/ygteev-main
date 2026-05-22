
-- Additive columns for the new student-led outreach flow.
--   pastor_phone     — captured when the student texts the pastor
--   referral_channel — 'sms' | 'email' | NULL.
--     NULL means "student didn't message the pastor directly; this is
--     either a legacy row from the old form or a CMS-initiated lead,
--     so our cold-outreach email pipeline (send-lead-welcome-email)
--     should still fire."
--     Set means "the student is handling outreach themselves; don't
--     double-message the pastor."

alter table public.youth_group_submissions
  add column if not exists pastor_phone     text,
  add column if not exists referral_channel text
    check (referral_channel is null or referral_channel in ('sms','email'));

-- Suppress the lead-welcome-email trigger when the student has
-- already messaged the pastor themselves.
create or replace function public.tg_send_lead_welcome_email()
returns trigger
language plpgsql
security definer
set search_path = public, net
as $function$
declare
  _url text := 'https://tkesywmshaicjmywbovn.supabase.co/functions/v1/send-lead-welcome-email';
begin
  -- New: skip the cold-outreach email when the student handled
  -- the outreach (SMS or email) directly from the iOS sheet.
  if NEW.referral_channel is not null then
    return NEW;
  end if;

  perform net.http_post(
    url     := _url,
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body    := jsonb_build_object('submission_id', NEW.id::text)
  );
  return NEW;
end $function$;
