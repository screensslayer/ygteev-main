
-- Add an explicit FK from messages.sender_id to profiles.id so PostgREST
-- can embed `sender:profiles(...)` on the messages select.
-- The existing FK to auth.users(id) remains; cascade semantics preserved.
do $$ begin
  alter table public.messages
    add constraint messages_sender_id_profiles_fkey
    foreign key (sender_id) references public.profiles(id) on delete cascade;
exception when duplicate_object then null; end $$;
