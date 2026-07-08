-- Remove the 3,000 XP seed at signup.
--
-- The reimagined onboarding flow (M15-M18) shows the user their real
-- earned XP: trivia + welcome bonus. Pre-seeding 3,000 XP on the
-- profile row via the handle_new_user trigger inflated the M18 total
-- so the counter rolled from 4,277 → 7,277 instead of showing the
-- +3,000 welcome bonus as the celebratory delta it's meant to be.
--
-- New behavior: users start at xp = 0. Trivia awards run as before
-- (250 XP per correct answer × 5 questions = up to 1,250 XP) and the
-- welcome bonus at Day 1 Complete lands at +3,000. Total post-M18 =
-- earned trivia + 3,000, which is what the design HTML calls out.
--
-- water stays at 27 — that's the game economy baseline and not
-- what this change is about.
--
-- Idempotent: CREATE OR REPLACE FUNCTION.

create or replace function public.handle_new_user() returns trigger
    language plpgsql security definer
    set search_path to 'public'
    as $$
declare
  default_group_id uuid;
  v_handle text;
  v_ext record;
begin
  v_handle := public.generate_random_handle();

  insert into public.profiles (id, email, display_name, handle, xp, water)
  values (
    new.id, new.email,
    coalesce(new.raw_user_meta_data->>'display_name', new.email),
    v_handle,
    0, 27
  );
  insert into public.user_roles (user_id, role) values (new.id, 'member');

  select id into default_group_id from public.youth_groups where is_default_ygteev = true limit 1;
  if default_group_id is not null then
    insert into public.youth_group_members (group_id, user_id, role)
    values (default_group_id, new.id, 'member') on conflict do nothing;
  end if;

  -- Claim any external RSVPs that match the signup email — unchanged
  -- from the baseline. Kept in-place so this migration can drop in
  -- as a full function replacement without changing side effects.
  if new.email is not null and length(new.email) > 0 then
    for v_ext in
      select * from public.event_external_rsvps
       where lower(email) = lower(new.email)
         and converted_to_user_id is null
    loop
      begin
        insert into public.event_rsvps (event_id, user_id, status)
        values (v_ext.event_id, new.id, v_ext.status::rsvp_status)
        on conflict (event_id, user_id) do nothing;
      exception when others then
        null;
      end;

      update public.event_external_rsvps
         set converted_to_user_id = new.id,
             converted_at = now()
       where id = v_ext.id;
    end loop;
  end if;

  return new;
end $$;
