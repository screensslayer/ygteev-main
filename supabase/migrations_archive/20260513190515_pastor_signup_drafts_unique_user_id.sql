
-- One draft per pastor (allows NULL → multiple anonymous pre-auth drafts).
-- Matches Lovable's likely upsert intent.
do $$ begin
  alter table public.pastor_signup_drafts
    add constraint pastor_signup_drafts_user_id_key unique (user_id);
exception when duplicate_object then null; end $$;
