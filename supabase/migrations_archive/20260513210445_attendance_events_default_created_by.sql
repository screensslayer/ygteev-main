
-- Auto-stamp attendance_events.created_by with auth.uid() when the caller
-- doesn't supply it. Keeps the iOS client free of audit plumbing.

create or replace function public.tg_attendance_events_default_creator()
returns trigger
language plpgsql
security definer
set search_path = public
as $func$
begin
  if new.created_by is null then
    new.created_by := auth.uid();
  end if;
  return new;
end;
$func$;

drop trigger if exists trg_attendance_events_default_creator on public.attendance_events;
create trigger trg_attendance_events_default_creator
before insert on public.attendance_events
for each row
execute function public.tg_attendance_events_default_creator();

-- Backfill: for any historical attendance row missing created_by, attribute it
-- to the small group's leader (the only person who could have taken roll).
update public.attendance_events ae
set created_by = (
  select sgm.user_id
  from public.small_group_members sgm
  where sgm.small_group_id = ae.small_group_id
    and sgm.role = 'leader'
  order by sgm.joined_at
  limit 1
)
where ae.created_by is null;

notify pgrst, 'reload schema';
