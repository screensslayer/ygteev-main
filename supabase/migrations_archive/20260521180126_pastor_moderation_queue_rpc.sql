
-- One-call moderation queue for the pastor CMS. Returns every flagged
-- message (allowed OR blocked) across every thread tied to the youth
-- group — main, small-group, 1:1 DMs, parent chat — with all the
-- context the UI needs to render rows without further joins:
--   • message body, status, OpenAI categories
--   • sender name + email + avatar
--   • thread kind + small group name (if applicable)
--
-- SECURITY DEFINER, scoped to the pastor (or site admin) of the group.

create or replace function public.pastor_moderation_queue(_group_id uuid)
returns table (
  message_id          uuid,
  body                text,
  moderation_status   text,
  moderation_categories jsonb,
  created_at          timestamptz,
  thread_id           uuid,
  thread_kind         text,
  small_group_id      uuid,
  small_group_name    text,
  sender_id           uuid,
  sender_display_name text,
  sender_email        text,
  sender_avatar_url   text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    m.id                          as message_id,
    m.body                        as body,
    m.moderation_status::text     as moderation_status,
    m.moderation_categories       as moderation_categories,
    m.created_at                  as created_at,
    ct.id                         as thread_id,
    ct.kind::text                 as thread_kind,
    sg.id                         as small_group_id,
    sg.name                       as small_group_name,
    p.id                          as sender_id,
    p.display_name                as sender_display_name,
    p.email                       as sender_email,
    p.avatar_url                  as sender_avatar_url
  from public.messages m
  join public.chat_threads ct      on ct.id = m.thread_id
  left join public.small_groups sg on sg.id = ct.small_group_id
  left join public.profiles p      on p.id  = m.sender_id
  where m.moderation_status::text in ('flagged_blocked','flagged_allowed')
    and (
      ct.group_id = _group_id
      or sg.youth_group_id = _group_id
    )
    and (
      is_group_pastor(auth.uid(), _group_id)
      or is_site_admin(auth.uid())
    )
  order by m.created_at desc;
$$;

grant execute on function public.pastor_moderation_queue(uuid) to authenticated;
