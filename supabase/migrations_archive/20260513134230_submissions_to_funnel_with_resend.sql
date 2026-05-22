
-- Funnel-stage columns
alter table public.youth_group_submissions
  add column if not exists lead_stage       text,
  add column if not exists emailed_at       timestamptz,
  add column if not exists email_provider_id text,            -- Resend message id
  add column if not exists last_followup_at timestamptz,
  add column if not exists followup_count   int not null default 0,
  add column if not exists converted_at     timestamptz,
  add column if not exists lost_at          timestamptz,
  add column if not exists lost_reason      text;

-- Migrate any existing rows to the funnel stage values
update public.youth_group_submissions
   set lead_stage = case status
       when 'pending'   then 'new_lead'
       when 'contacted' then 'emailed'
       when 'approved'  then 'converted'
       when 'rejected'  then 'dead'
       else 'new_lead' end
 where lead_stage is null;

-- Make NOT NULL with a default after backfill
alter table public.youth_group_submissions
  alter column lead_stage set default 'new_lead',
  alter column lead_stage set not null;

-- Constrain to the canonical 5 funnel stages
do $$ begin
  alter table public.youth_group_submissions
    add constraint youth_group_submissions_lead_stage_check
    check (lead_stage in ('new_lead','emailed','following_up','converted','dead'));
exception when duplicate_object then null; end $$;

create index if not exists ygs_lead_stage_idx on public.youth_group_submissions(lead_stage);

-- pg_net for outbound HTTP from triggers
create extension if not exists pg_net;

-- Trigger function: POST submission_id to the send-lead-welcome-email Edge Function
create or replace function public.tg_send_lead_welcome_email()
returns trigger
language plpgsql security definer set search_path = public, net as $$
declare
  _url text := 'https://tkesywmshaicjmywbovn.supabase.co/functions/v1/send-lead-welcome-email';
begin
  -- Fire-and-forget. The function validates the submission via service role.
  perform net.http_post(
    url     := _url,
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body    := jsonb_build_object('submission_id', NEW.id::text)
  );
  return NEW;
end $$;

drop trigger if exists send_lead_email_on_insert on public.youth_group_submissions;
create trigger send_lead_email_on_insert
  after insert on public.youth_group_submissions
  for each row execute function public.tg_send_lead_welcome_email();
