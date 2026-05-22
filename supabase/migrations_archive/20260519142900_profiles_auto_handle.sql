-- Fortnite-style auto handles: <Adjective><Noun><1-99> e.g. DangerousTable41.
-- Generated server-side on signup, stored on profiles.handle, locked from
-- client edits. Uniqueness is case-insensitive.

alter table public.profiles
  add column if not exists handle text;

create unique index if not exists profiles_handle_lower_idx
  on public.profiles (lower(handle));

-- Generator. Pulls from inline adjective + noun arrays for portability.
-- Retries up to 10 times with 2-digit suffix, then up to 40 more with
-- 4-digit suffix; should effectively never throw at our scale.
create or replace function public.generate_random_handle()
returns text
language plpgsql
volatile
as $$
declare
  adjectives text[] := array[
    'Dangerous','Sneaky','Quick','Brave','Mighty','Stealth','Crystal','Phantom',
    'Cosmic','Frosty','Mystic','Wild','Lucky','Brilliant','Calm','Golden',
    'Silent','Swift','Eager','Fierce','Loyal','Bold','Sharp','Royal',
    'Epic','Smooth','Crafty','Daring','Nimble','Witty','Cheerful','Jolly',
    'Plucky','Zesty','Spry','Cunning','Bouncy','Speedy','Lively','Curious',
    'Sturdy','Vibrant','Radiant','Stoic','Hearty','Breezy','Sunny','Friendly',
    'Snappy','Clever'
  ];
  nouns text[] := array[
    'Table','Penguin','Wizard','Tiger','Eagle','Knight','Falcon','Lion',
    'Bear','Wolf','Fox','Cobra','Hawk','Panda','Otter','Dragon',
    'Phoenix','Hammer','Compass','Anchor','Beacon','Comet','Meteor','Lantern',
    'Glider','Rocket','Pirate','Ninja','Captain','Ranger','Scout','Hunter',
    'Warrior','Pilot','Sailor','Cowboy','Jester','Robot','Astronaut','Guardian',
    'Mariner','Voyager','Pioneer','Champion','Defender','Striker','Drifter','Maverick',
    'Sentry','Sage'
  ];
  candidate text;
  attempt int := 0;
begin
  loop
    attempt := attempt + 1;
    -- First 10 attempts: 2-digit suffix
    if attempt <= 10 then
      candidate :=
        adjectives[1 + floor(random() * array_length(adjectives, 1))::int]
        || nouns[1 + floor(random() * array_length(nouns, 1))::int]
        || (1 + floor(random() * 99))::text;
    else
      -- Fall back to 4-digit suffix
      candidate :=
        adjectives[1 + floor(random() * array_length(adjectives, 1))::int]
        || nouns[1 + floor(random() * array_length(nouns, 1))::int]
        || (100 + floor(random() * 9900))::text;
    end if;

    if not exists (
      select 1 from public.profiles where lower(handle) = lower(candidate)
    ) then
      return candidate;
    end if;

    if attempt > 50 then
      raise exception 'could_not_generate_unique_handle';
    end if;
  end loop;
end;
$$;

grant execute on function public.generate_random_handle() to service_role;

-- Re-create handle_new_user to also assign a fresh handle on signup.
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer
set search_path = public
as $function$
declare
  default_group_id uuid;
  v_handle text;
begin
  v_handle := public.generate_random_handle();

  insert into public.profiles (id, email, display_name, handle, xp, water)
  values (
    new.id, new.email,
    coalesce(new.raw_user_meta_data->>'display_name', new.email),
    v_handle,
    3000, 27
  );
  insert into public.user_roles (user_id, role) values (new.id, 'member');

  select id into default_group_id from public.youth_groups where is_default_ygteev = true limit 1;
  if default_group_id is not null then
    insert into public.youth_group_members (group_id, user_id, role)
    values (default_group_id, new.id, 'member') on conflict do nothing;
  end if;
  return new;
end $function$;

-- Lock handle from client edits. Site admins can still change it (e.g.
-- to handle an inappropriate auto-generation).
create or replace function public.tg_profiles_lock_handle()
returns trigger
language plpgsql security definer
set search_path = public
as $function$
begin
  if tg_op = 'UPDATE'
     and old.handle is not null
     and new.handle is distinct from old.handle
     and not coalesce(public.is_site_admin(auth.uid()), false)
  then
    raise exception 'handle_locked' using errcode = '42501';
  end if;
  return new;
end $function$;

drop trigger if exists trg_profiles_lock_handle on public.profiles;
create trigger trg_profiles_lock_handle
  before update on public.profiles
  for each row execute function public.tg_profiles_lock_handle();

-- Backfill every existing profile that doesn't have a handle yet.
do $$
declare r record;
begin
  for r in select id from public.profiles where handle is null loop
    update public.profiles set handle = public.generate_random_handle() where id = r.id;
  end loop;
end $$;

-- Make non-null going forward.
alter table public.profiles
  alter column handle set not null;
