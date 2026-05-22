
-- Pastor moderation actions on flagged messages.
--
-- approve_message: flip moderation_status from flagged_blocked (or
-- flagged_allowed) to 'clean' so member clients will surface it. The
-- pastor is taking responsibility for the call — server doesn't second-
-- guess OpenAI here, but we do require the caller is the pastor of the
-- thread's group (or a site admin).
--
-- reject_message: hard-delete the message. Messages has no deleted_at
-- column, so this is permanent. A rejected message is identical to one
-- that never existed (no audit trail yet — flagged for follow-up later).

create or replace function public.pastor_approve_message(_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller uuid := auth.uid();
  v_msg    public.messages;
  v_thread public.chat_threads;
  v_group_id uuid;
begin
  if v_caller is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  select * into v_msg from public.messages where id = _id;
  if v_msg.id is null then
    raise exception 'message_not_found' using errcode = '22023';
  end if;

  select * into v_thread from public.chat_threads where id = v_msg.thread_id;
  if v_thread.id is null then
    raise exception 'thread_not_found' using errcode = '22023';
  end if;

  -- Resolve the moderating youth_group_id. A thread is either tied to a
  -- youth group directly (group_main, dm_pastor, parent_chat) or to a
  -- small group (small_group_main, dm_leader). Small-group threads
  -- moderation falls to the host youth-group pastor.
  v_group_id := coalesce(
    v_thread.group_id,
    (select sg.youth_group_id from public.small_groups sg where sg.id = v_thread.small_group_id)
  );
  if v_group_id is null then
    raise exception 'thread_has_no_group' using errcode = '22023';
  end if;

  if not (is_group_pastor(v_caller, v_group_id) or is_site_admin(v_caller)) then
    raise exception 'forbidden: not a pastor of this group' using errcode = '42501';
  end if;

  update public.messages
  set moderation_status = 'clean'::moderation_status
  where id = _id;

  return jsonb_build_object(
    'ok',        true,
    'id',        _id,
    'new_status','clean'
  );
end;
$$;

grant execute on function public.pastor_approve_message(uuid) to authenticated;


create or replace function public.pastor_reject_message(_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller uuid := auth.uid();
  v_msg    public.messages;
  v_thread public.chat_threads;
  v_group_id uuid;
begin
  if v_caller is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  select * into v_msg from public.messages where id = _id;
  if v_msg.id is null then
    raise exception 'message_not_found' using errcode = '22023';
  end if;

  select * into v_thread from public.chat_threads where id = v_msg.thread_id;
  if v_thread.id is null then
    raise exception 'thread_not_found' using errcode = '22023';
  end if;

  v_group_id := coalesce(
    v_thread.group_id,
    (select sg.youth_group_id from public.small_groups sg where sg.id = v_thread.small_group_id)
  );
  if v_group_id is null then
    raise exception 'thread_has_no_group' using errcode = '22023';
  end if;

  if not (is_group_pastor(v_caller, v_group_id) or is_site_admin(v_caller)) then
    raise exception 'forbidden: not a pastor of this group' using errcode = '42501';
  end if;

  delete from public.messages where id = _id;

  return jsonb_build_object(
    'ok',      true,
    'id',      _id,
    'deleted', true
  );
end;
$$;

grant execute on function public.pastor_approve_message(uuid) to authenticated;
grant execute on function public.pastor_reject_message(uuid) to authenticated;
