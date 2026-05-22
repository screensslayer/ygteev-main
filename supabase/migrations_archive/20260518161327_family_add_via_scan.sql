-- One-shot QR-scan family add. Replaces the pending-invite roundtrip for the
-- QR flow only — pairing-code path keeps `create_family_invite` /
-- `accept_family_invite`. The QR scan itself is the consent signal: both
-- devices have to be present in the room.
create or replace function public.family_add_via_scan(
  _family_id uuid,
  _scanned_user_id uuid
) returns uuid
language plpgsql security definer
set search_path = public
as $function$
declare
  v_caller uuid := auth.uid();
begin
  if v_caller is null then
    raise exception 'not_authenticated';
  end if;
  if v_caller = _scanned_user_id then
    raise exception 'cannot_add_self' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.family_members
    where family_id = _family_id and user_id = v_caller and role = 'parent'
  ) then
    raise exception 'forbidden: must be a parent' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.profiles where id = _scanned_user_id and deleted_at is null
  ) then
    raise exception 'scanned_user_not_found' using errcode = '22023';
  end if;

  insert into public.family_members (family_id, user_id, role)
    values (_family_id, _scanned_user_id, 'child')
    on conflict (family_id, user_id) do nothing;

  return _family_id;
end;
$function$;

grant execute on function public.family_add_via_scan(uuid, uuid) to authenticated, service_role;
