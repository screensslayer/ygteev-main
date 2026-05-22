
-- QR-scan "instant join" path for youth groups. The expectation is
-- that the user is physically at the church and the pastor has
-- displayed the group's QR — scanning it skips the pending-approval
-- flow and inserts the user directly as a member.
--
-- Permission model (v1, the simple one):
--   • Caller must be authenticated
--   • Group must be is_public = true (anyone scanning an unverified
--     group's QR just gets a friendly error rather than silently
--     joining a non-listed group)
--   • Default YGTeeV group is allowed too — students can use the QR
--     pattern as a fallback if they don't have a real church group
--
-- Idempotent: if the user is already a member, returns the existing
-- membership without error.
--
-- Auto-approves a previously-submitted pending request from the same
-- user — if they hit "Request to Join" earlier and never got accepted,
-- scanning the QR completes that lap.

create or replace function public.join_group_via_qr_scan(_group_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid             uuid := auth.uid();
  v_yg              public.youth_groups;
  v_existing_member uuid;
  v_pending_request uuid;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  select * into v_yg from public.youth_groups where id = _group_id;
  if v_yg.id is null then
    raise exception 'group_not_found' using errcode = '22023';
  end if;
  if coalesce(v_yg.is_public, false) = false then
    raise exception 'group_not_public' using errcode = '42501';
  end if;

  -- Already a member? Idempotent return.
  select id into v_existing_member
  from public.youth_group_members
  where group_id = _group_id and user_id = v_uid;

  if v_existing_member is not null then
    return jsonb_build_object(
      'ok',             true,
      'group_id',       _group_id,
      'group_name',     v_yg.name,
      'already_member', true,
      'newly_joined',   false
    );
  end if;

  -- Auto-approve any pending request from this user for this group.
  -- Without this, the request_to_join_group flow would leave a stale
  -- pending row hanging around forever once they're joined.
  update public.youth_group_join_requests
  set status      = 'approved',
      decided_at  = now(),
      decided_by  = v_uid  -- self-approved via QR scan
  where group_id = _group_id
    and user_id  = v_uid
    and status   = 'pending'
  returning id into v_pending_request;

  -- Insert membership. The chat_on_ygm_insert trigger handles
  -- subscribing the user to the relevant chat threads (group_main,
  -- dm_pastor, etc.) automatically.
  insert into public.youth_group_members (group_id, user_id, role)
  values (_group_id, v_uid, 'member');

  return jsonb_build_object(
    'ok',                 true,
    'group_id',           _group_id,
    'group_name',         v_yg.name,
    'already_member',     false,
    'newly_joined',       true,
    'pending_request_auto_approved', v_pending_request is not null
  );
end;
$$;

grant execute on function public.join_group_via_qr_scan(uuid) to authenticated;
