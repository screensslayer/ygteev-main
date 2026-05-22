
-- Replace the moderation queue + approve/reject flow to query
-- moderation_alerts instead of messages.
--
-- Why this matters: the send-message Edge Function REJECTS
-- flagged_blocked messages before they're inserted into the messages
-- table. So joining the queue to messages can never surface blocked
-- content. The full flagged-message audit trail lives in
-- moderation_alerts, which has both flagged_allowed and flagged_blocked
-- rows plus a `preview` snapshot of the original text.
--
-- For "approve":
--   • If the alert links to a real message row (status=flagged_allowed),
--     flip that message's status → clean.
--   • If the alert has no message row (status=flagged_blocked), insert
--     a new clean message using the preview as the body and the
--     original sender/thread metadata. Pastor is now the moral author
--     of letting it through.
-- For "reject":
--   • If a message row exists, delete it. Always mark the alert
--     acknowledged so it falls off the queue.

-- Drop the old message-id based functions; they only worked for
-- flagged_allowed and were misleading.
drop function if exists public.pastor_approve_message(uuid);
drop function if exists public.pastor_reject_message(uuid);
drop function if exists public.pastor_moderation_queue(uuid);


create or replace function public.pastor_moderation_queue(_group_id uuid)
returns table (
  alert_id              uuid,
  message_id            uuid,
  preview               text,
  moderation_status     text,
  moderation_categories jsonb,
  created_at            timestamptz,
  thread_id             uuid,
  thread_kind           text,
  small_group_id        uuid,
  small_group_name      text,
  sender_id             uuid,
  sender_display_name   text,
  sender_email          text,
  sender_avatar_url     text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    a.id                          as alert_id,
    a.message_id                  as message_id,
    a.preview                     as preview,
    a.status::text                as moderation_status,
    a.categories                  as moderation_categories,
    a.created_at                  as created_at,
    ct.id                         as thread_id,
    ct.kind::text                 as thread_kind,
    sg.id                         as small_group_id,
    sg.name                       as small_group_name,
    p.id                          as sender_id,
    p.display_name                as sender_display_name,
    p.email                       as sender_email,
    p.avatar_url                  as sender_avatar_url
  from public.moderation_alerts a
  join public.chat_threads ct       on ct.id = a.thread_id
  left join public.small_groups sg  on sg.id = ct.small_group_id
  left join public.profiles p       on p.id  = a.sender_id
  where a.group_id = _group_id
    and a.acknowledged_at is null
    and (
      is_group_pastor(auth.uid(), _group_id)
      or is_site_admin(auth.uid())
    )
  order by a.created_at desc;
$$;

grant execute on function public.pastor_moderation_queue(uuid) to authenticated;


create or replace function public.pastor_approve_alert(_alert_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller   uuid := auth.uid();
  v_alert    public.moderation_alerts;
  v_new_id   uuid;
begin
  if v_caller is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  select * into v_alert from public.moderation_alerts where id = _alert_id;
  if v_alert.id is null then
    raise exception 'alert_not_found' using errcode = '22023';
  end if;
  if not (is_group_pastor(v_caller, v_alert.group_id) or is_site_admin(v_caller)) then
    raise exception 'forbidden: not a pastor of this group' using errcode = '42501';
  end if;

  if v_alert.message_id is not null then
    -- Allowed flag: message already exists in messages table; just
    -- mark it clean so it stops looking flagged in chat.
    update public.messages
    set moderation_status = 'clean'::moderation_status
    where id = v_alert.message_id;
    v_new_id := v_alert.message_id;
  else
    -- Blocked flag: never made it to messages. Insert the original
    -- text now under the pastor's override.
    insert into public.messages (
      thread_id, sender_id, body,
      moderation_status, moderation_categories
    )
    values (
      v_alert.thread_id, v_alert.sender_id,
      coalesce(v_alert.preview, ''),
      'clean'::moderation_status,
      coalesce(v_alert.categories, '{}'::jsonb)
                          || jsonb_build_object('pastor_override', true)
    )
    returning id into v_new_id;

    -- Bump the thread's last_message_at so the chat surfaces it.
    update public.chat_threads
    set last_message_at = now()
    where id = v_alert.thread_id;
  end if;

  update public.moderation_alerts
  set acknowledged_at = now(),
      acknowledged_by = v_caller
  where id = _alert_id;

  return jsonb_build_object(
    'ok',           true,
    'alert_id',     _alert_id,
    'message_id',   v_new_id,
    'inserted_new', v_alert.message_id is null
  );
end;
$$;

grant execute on function public.pastor_approve_alert(uuid) to authenticated;


create or replace function public.pastor_reject_alert(_alert_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller uuid := auth.uid();
  v_alert  public.moderation_alerts;
begin
  if v_caller is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  select * into v_alert from public.moderation_alerts where id = _alert_id;
  if v_alert.id is null then
    raise exception 'alert_not_found' using errcode = '22023';
  end if;
  if not (is_group_pastor(v_caller, v_alert.group_id) or is_site_admin(v_caller)) then
    raise exception 'forbidden: not a pastor of this group' using errcode = '42501';
  end if;

  -- If a message row exists (allowed flag), delete it.
  if v_alert.message_id is not null then
    delete from public.messages where id = v_alert.message_id;
  end if;

  update public.moderation_alerts
  set acknowledged_at = now(),
      acknowledged_by = v_caller
  where id = _alert_id;

  return jsonb_build_object(
    'ok',       true,
    'alert_id', _alert_id,
    'deleted',  v_alert.message_id is not null
  );
end;
$$;

grant execute on function public.pastor_reject_alert(uuid) to authenticated;
