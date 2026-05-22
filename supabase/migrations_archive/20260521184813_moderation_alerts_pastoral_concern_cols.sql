
-- Additive only. Existing rows stay null. Existing queries unaffected.
-- These columns power the new pastoral-concern classifier without
-- changing how OpenAI-policy flags get tracked.

alter table public.moderation_alerts
  add column if not exists concern_category   text,
  add column if not exists concern_confidence numeric,
  add column if not exists concern_reason     text;

-- Small index for the Lovable queue if it ever wants to filter to
-- only pastoral-concern rows. Cheap, no harm if unused.
create index if not exists moderation_alerts_concern_category_idx
  on public.moderation_alerts (concern_category)
  where concern_category is not null;
