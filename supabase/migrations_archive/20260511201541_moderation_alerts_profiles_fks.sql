
-- Direct FKs to profiles so PostgREST can embed sender/acknowledger.
do $$ begin
  alter table public.moderation_alerts
    add constraint moderation_alerts_sender_profiles_fkey
    foreign key (sender_id) references public.profiles(id) on delete set null;
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.moderation_alerts
    add constraint moderation_alerts_ack_profiles_fkey
    foreign key (acknowledged_by) references public.profiles(id) on delete set null;
exception when duplicate_object then null; end $$;

notify pgrst, 'reload schema';
