
-- ---------- profile bio ----------
alter table public.profiles
  add column if not exists bio text;

do $$ begin
  alter table public.profiles
    add constraint profiles_bio_length check (bio is null or char_length(bio) <= 280);
exception when duplicate_object then null; end $$;

-- Extend the existing managed-profile RPC to accept _bio (backward-compatible: optional param)
create or replace function public.update_managed_profile(
  _target_user_id uuid,
  _display_name   text default null,
  _avatar_url     text default null,
  _bio            text default null
)
returns public.profiles
language plpgsql security definer set search_path = public as $$
declare _result public.profiles;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not public.can_manage_user_profile(auth.uid(), _target_user_id) then
    raise exception 'not_authorized';
  end if;
  if _bio is not null and char_length(_bio) > 280 then
    raise exception 'bio_too_long';
  end if;

  update public.profiles
     set display_name = coalesce(_display_name, display_name),
         avatar_url   = coalesce(_avatar_url,   avatar_url),
         bio          = coalesce(_bio,          bio),
         updated_at   = now()
   where id = _target_user_id
   returning * into _result;
  if _result.id is null then raise exception 'profile_not_found'; end if;
  return _result;
end $$;

-- ---------- Let small group leaders edit their own small_groups row ----------
drop policy if exists "small_groups: leader update" on public.small_groups;
create policy "small_groups: leader update" on public.small_groups for update
  using (public.is_small_group_leader(auth.uid(), id))
  with check (public.is_small_group_leader(auth.uid(), id));

-- ---------- attendance_events + attendance_records ----------
create table if not exists public.attendance_events (
  id             uuid primary key default gen_random_uuid(),
  small_group_id uuid not null references public.small_groups(id) on delete cascade,
  title          text not null,
  occurred_at    timestamptz not null default now(),
  notes          text,
  created_by     uuid references auth.users(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index if not exists ae_small_group_idx
  on public.attendance_events(small_group_id, occurred_at desc);
alter table public.attendance_events enable row level security;

drop trigger if exists touch_attendance_events on public.attendance_events;
create trigger touch_attendance_events before update on public.attendance_events
  for each row execute function public.touch_updated_at();

create table if not exists public.attendance_records (
  id          uuid primary key default gen_random_uuid(),
  event_id    uuid not null references public.attendance_events(id) on delete cascade,
  user_id     uuid not null references auth.users(id) on delete cascade,
  present     boolean not null,
  notes       text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (event_id, user_id)
);
create index if not exists ar_event_idx on public.attendance_records(event_id);
create index if not exists ar_user_idx  on public.attendance_records(user_id);
alter table public.attendance_records enable row level security;

drop trigger if exists touch_attendance_records on public.attendance_records;
create trigger touch_attendance_records before update on public.attendance_records
  for each row execute function public.touch_updated_at();

-- Helper: can the caller take roll for this small group?
create or replace function public.can_take_attendance(_user_id uuid, _small_group_id uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_small_group_leader(_user_id, _small_group_id)
      or public.can_manage_small_groups(_user_id, _small_group_id);
$$;

-- ---------- RLS: attendance_events ----------
drop policy if exists "ae: read"  on public.attendance_events;
drop policy if exists "ae: write" on public.attendance_events;

create policy "ae: read" on public.attendance_events for select using (
  public.is_site_admin(auth.uid())
  or public.can_take_attendance(auth.uid(), small_group_id)
  -- members of the small group can also see the event headers (so they
  -- could view their own attendance history later).
  or public.is_in_small_group(auth.uid(), small_group_id)
);

create policy "ae: write" on public.attendance_events for all
  using (public.can_take_attendance(auth.uid(), small_group_id))
  with check (public.can_take_attendance(auth.uid(), small_group_id));

-- ---------- RLS: attendance_records ----------
drop policy if exists "ar: read"  on public.attendance_records;
drop policy if exists "ar: write" on public.attendance_records;

create policy "ar: read" on public.attendance_records for select using (
  public.is_site_admin(auth.uid())
  or user_id = auth.uid()  -- a member sees their own attendance
  or exists (
    select 1 from public.attendance_events e
    where e.id = event_id
      and public.can_take_attendance(auth.uid(), e.small_group_id)
  )
);

create policy "ar: write" on public.attendance_records for all
  using (
    exists (
      select 1 from public.attendance_events e
      where e.id = event_id
        and public.can_take_attendance(auth.uid(), e.small_group_id)
    )
  )
  with check (
    exists (
      select 1 from public.attendance_events e
      where e.id = event_id
        and public.can_take_attendance(auth.uid(), e.small_group_id)
    )
  );

-- ---------- Convenience: save_attendance RPC (atomic save of full roster) ----------
-- Pass an array of { user_id, present, notes }. Upserts all in one call.
create or replace function public.save_attendance(
  _event_id uuid,
  _records  jsonb           -- e.g. [{"user_id":"...","present":true,"notes":null}, ...]
)
returns int
language plpgsql security definer set search_path = public as $$
declare
  _event public.attendance_events;
  _r jsonb;
  _written int := 0;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;

  select * into _event from public.attendance_events where id = _event_id;
  if _event.id is null then raise exception 'event_not_found'; end if;
  if not public.can_take_attendance(auth.uid(), _event.small_group_id) then
    raise exception 'not_authorized';
  end if;

  for _r in select * from jsonb_array_elements(_records) loop
    insert into public.attendance_records (event_id, user_id, present, notes)
    values (
      _event_id,
      (_r->>'user_id')::uuid,
      (_r->>'present')::boolean,
      nullif(_r->>'notes', '')
    )
    on conflict (event_id, user_id) do update
      set present = excluded.present,
          notes   = excluded.notes,
          updated_at = now();
    _written := _written + 1;
  end loop;

  -- Bump the event's updated_at so list views resort correctly
  update public.attendance_events set updated_at = now() where id = _event_id;
  return _written;
end $$;

-- ---------- View: per-event attendance summary (for pastor dashboards) ----------
create or replace view public.attendance_event_summary as
select
  e.id                as event_id,
  e.small_group_id,
  sg.name             as small_group_name,
  sg.youth_group_id,
  e.title,
  e.occurred_at,
  e.created_by,
  count(r.*)                                   as roster_total,
  count(r.*) filter (where r.present = true)   as present_count,
  count(r.*) filter (where r.present = false)  as absent_count,
  e.created_at,
  e.updated_at
from public.attendance_events e
left join public.attendance_records r on r.event_id = e.id
left join public.small_groups sg on sg.id = e.small_group_id
group by e.id, sg.name, sg.youth_group_id;

grant select on public.attendance_event_summary to authenticated;
