-- Public RSVP funnel:
--   1. event_external_rsvps  — landing pad for RSVPs from
--      non-users (friend gets an invite link, submits email + grade).
--   2. public_event_summary RPC — anonymous-friendly event detail
--      payload for the Lovable share page (no PII surfaced).
--   3. handle_new_user merge — on signup, claim any matching email's
--      external RSVPs into real event_rsvps rows so the user lands in
--      the app with their RSVP'd events already on the calendar.

create table if not exists public.event_external_rsvps (
  id                  uuid primary key default gen_random_uuid(),
  event_id            uuid not null references public.events(id) on delete cascade,
  email               text not null,
  display_name        text,
  grade_year          int check (grade_year is null or (grade_year between 6 and 12)),
  status              text not null default 'going'
                       check (status in ('going','maybe','declined')),
  inviter_user_id     uuid references public.profiles(id) on delete set null,
  source              text not null default 'invite_link',
  converted_to_user_id uuid references public.profiles(id) on delete set null,
  converted_at        timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create unique index if not exists event_external_rsvps_event_email_idx
  on public.event_external_rsvps (event_id, lower(email));
create index if not exists event_external_rsvps_email_idx
  on public.event_external_rsvps (lower(email)) where converted_to_user_id is null;

alter table public.event_external_rsvps enable row level security;
-- No public read/write. All access via SECURITY DEFINER Edge Function
-- + admin/pastor RPCs.

-- updated_at trigger
drop trigger if exists touch_event_external_rsvps on public.event_external_rsvps;
create trigger touch_event_external_rsvps
  before update on public.event_external_rsvps
  for each row execute function public.touch_updated_at();

-- ============================================================================
-- public_event_summary: anonymous-accessible event detail.
--   Returns the event basics + going_count (members + external) so the
--   share page can render Partiful-style.
-- ============================================================================
create or replace function public.public_event_summary(_event_id uuid)
returns jsonb
language plpgsql stable security definer
set search_path = public
as $$
declare
  v_event public.events;
  v_group public.youth_groups;
  v_inside int;
  v_outside int;
  v_maybe int;
  v_decline int;
begin
  select * into v_event from public.events where id = _event_id;
  if v_event.id is null then
    return jsonb_build_object('found', false);
  end if;

  -- Only public-visible events have a shareable page. Members-only or
  -- groupPrivate events return a stub so the browser page can show
  -- "this event is private" rather than leaking details.
  if v_event.visibility::text <> 'public' or v_event.rsvp_audience::text <> 'public' then
    return jsonb_build_object(
      'found', true,
      'public', false,
      'event_id', v_event.id,
      'title', v_event.title
    );
  end if;

  select * into v_group from public.youth_groups where id = v_event.group_id;

  select count(*)::int into v_inside  from public.event_rsvps
    where event_id = _event_id and status::text = 'going';
  select count(*)::int into v_maybe   from public.event_rsvps
    where event_id = _event_id and status::text = 'maybe';
  select count(*)::int into v_decline from public.event_rsvps
    where event_id = _event_id and status::text = 'declined';
  select count(*)::int into v_outside from public.event_external_rsvps
    where event_id = _event_id and status = 'going'
      and converted_to_user_id is null;

  return jsonb_build_object(
    'found',         true,
    'public',        true,
    'event_id',      v_event.id,
    'title',         v_event.title,
    'description',   v_event.description,
    'starts_at',     v_event.starts_at,
    'location',      v_event.location,
    'cover_url',     v_event.cover_url,
    'group', jsonb_build_object(
      'id',            v_group.id,
      'name',          v_group.name,
      'church_name',   v_group.church_name,
      'logo_url',      v_group.logo_url,
      'gradient_from', v_group.gradient_from,
      'gradient_to',   v_group.gradient_to
    ),
    'going_count',   v_inside + v_outside,
    'maybe_count',   v_maybe,
    'declined_count',v_decline
  );
end;
$$;

grant execute on function public.public_event_summary(uuid) to anon, authenticated, service_role;

-- ============================================================================
-- Extend handle_new_user: on signup, attach any pre-existing external
-- RSVPs (matching email) to the new profile. Inserts real event_rsvps
-- rows so the user sees the event in their app immediately.
-- ============================================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer
set search_path = public
as $function$
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
    3000, 27
  );
  insert into public.user_roles (user_id, role) values (new.id, 'member');

  select id into default_group_id from public.youth_groups where is_default_ygteev = true limit 1;
  if default_group_id is not null then
    insert into public.youth_group_members (group_id, user_id, role)
    values (default_group_id, new.id, 'member') on conflict do nothing;
  end if;

  -- NEW: claim any external RSVPs that match the signup email.
  if new.email is not null and length(new.email) > 0 then
    for v_ext in
      select * from public.event_external_rsvps
       where lower(email) = lower(new.email)
         and converted_to_user_id is null
    loop
      -- Mirror into the real event_rsvps table so the user sees the
      -- event in their account. on-conflict-do-nothing in case they
      -- already RSVPed via the app between us recording the external
      -- one and them signing up.
      begin
        insert into public.event_rsvps (event_id, user_id, status)
        values (v_ext.event_id, new.id, v_ext.status::rsvp_status)
        on conflict (event_id, user_id) do nothing;
      exception when others then
        -- Skip silently; we don't want signup to fail because of a
        -- bad enum cast or a missing event row.
        null;
      end;

      update public.event_external_rsvps
         set converted_to_user_id = new.id,
             converted_at = now()
       where id = v_ext.id;
    end loop;
  end if;

  return new;
end $function$;
