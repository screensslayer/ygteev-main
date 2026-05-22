
-- Stash the resolved promo code on the draft so the wizard survives
-- mid-flow refreshes / returns. The Edge Function reads from the
-- request body (which Lovable sources from the draft), so this column
-- exists purely for persistence + analytics.
alter table public.pastor_signup_drafts
  add column if not exists promo_code text;
