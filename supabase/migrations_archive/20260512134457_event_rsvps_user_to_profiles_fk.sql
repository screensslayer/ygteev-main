
do $$ begin
  alter table public.event_rsvps
    add constraint event_rsvps_user_profiles_fkey
    foreign key (user_id) references public.profiles(id) on delete cascade;
exception when duplicate_object then null; end $$;

notify pgrst, 'reload schema';
