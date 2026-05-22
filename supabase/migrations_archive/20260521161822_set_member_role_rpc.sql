
-- Lets a pastor (or site admin) change a member's role within their
-- group. Three guards:
--   1. Caller must be the group's pastor (or site admin).
--   2. Caller cannot change their OWN role here — forces a separate
--      "transfer ownership" / co-pastor add flow rather than allowing
--      a pastor to accidentally demote themselves out of the role.
--   3. Cannot demote the LAST pastor of a group — every active group
--      must always have at least one pastor.
--
-- Co-pastors are allowed: pastor A can promote leader B to pastor.
-- After that promotion, B can edit roles freely (subject to guards 2
-- and 3). To demote a pastor, another pastor or a site admin must do
-- it.
--
-- Returns the updated youth_group_members row so the CMS can refresh
-- its roster without a second fetch.

create or replace function public.set_member_role(
  _group_id uuid,
  _user_id  uuid,
  _new_role text
)
returns table (
  id        uuid,
  group_id  uuid,
  user_id   uuid,
  role      text,
  joined_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller        uuid := auth.uid();
  v_is_site_admin boolean := is_site_admin(v_caller);
  v_is_pastor     boolean;
  v_target_role   text;
  v_pastor_count  int;
begin
  if v_caller is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  if _new_role not in ('pastor','leader','member') then
    raise exception 'invalid_role: %', _new_role using errcode = '22023';
  end if;

  v_is_pastor := is_group_pastor(v_caller, _group_id);
  if not (v_is_pastor or v_is_site_admin) then
    raise exception 'forbidden: not a pastor of this group' using errcode = '42501';
  end if;

  -- Guard 2: self-edit
  if v_caller = _user_id and not v_is_site_admin then
    raise exception 'cannot_change_own_role' using errcode = '42501';
  end if;

  -- Look up current role + check the target membership exists
  select role::text into v_target_role
  from public.youth_group_members
  where group_id = _group_id and user_id = _user_id;

  if v_target_role is null then
    raise exception 'member_not_found' using errcode = '22023';
  end if;

  -- No-op short-circuit
  if v_target_role = _new_role then
    return query
      select ygm.id, ygm.group_id, ygm.user_id, ygm.role::text, ygm.joined_at
      from public.youth_group_members ygm
      where ygm.group_id = _group_id and ygm.user_id = _user_id;
    return;
  end if;

  -- Guard 3: last-pastor demotion
  if v_target_role = 'pastor' and _new_role <> 'pastor' then
    select count(*) into v_pastor_count
    from public.youth_group_members
    where group_id = _group_id and role = 'pastor';
    if v_pastor_count <= 1 then
      raise exception 'cannot_demote_last_pastor' using errcode = '42501';
    end if;
  end if;

  update public.youth_group_members
  set role = _new_role::group_role
  where group_id = _group_id and user_id = _user_id;

  return query
    select ygm.id, ygm.group_id, ygm.user_id, ygm.role::text, ygm.joined_at
    from public.youth_group_members ygm
    where ygm.group_id = _group_id and ygm.user_id = _user_id;
end;
$$;

grant execute on function public.set_member_role(uuid, uuid, text) to authenticated;
