
-- Swap the functional unique index (event_id, lower(email)) for a plain
-- unique constraint on (event_id, email). PostgREST's `onConflict=event_id,email`
-- in supabase-js upserts can only target a unique constraint on the literal
-- columns, not a functional index. The public-rsvp-event Edge Function already
-- lowercases `email` before insert, so this preserves the case-insensitive
-- intent without the functional-index limitation.

drop index if exists public.event_external_rsvps_event_email_idx;

alter table public.event_external_rsvps
  add constraint event_external_rsvps_event_email_unique
  unique (event_id, email);
