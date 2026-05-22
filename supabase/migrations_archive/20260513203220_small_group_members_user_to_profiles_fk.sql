
-- Direct FK so PostgREST can embed `profile:profiles!user_id`.
-- The existing FK to auth.users(id) stays; cascade semantics preserved.
do $$ begin
  alter table public.small_group_members
    add constraint small_group_members_user_profiles_fkey
    foreign key (user_id) references public.profiles(id) on delete cascade;
exception when duplicate_object then null; end $$;

notify pgrst, 'reload schema';
