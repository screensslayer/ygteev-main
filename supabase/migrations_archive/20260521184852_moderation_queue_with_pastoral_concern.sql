
drop function if exists public.pastor_moderation_queue(uuid);

create or replace function public.pastor_moderation_queue(_group_id uuid)
returns table (
  alert_id               uuid,
  message_id             uuid,
  preview                text,
  moderation_status      text,
  moderation_categories  jsonb,
  concern_category       text,
  concern_confidence     numeric,
  concern_reason         text,
  created_at             timestamptz,
  thread_id              uuid,
  thread_kind            text,
  small_group_id         uuid,
  small_group_name       text,
  sender_id              uuid,
  sender_display_name    text,
  sender_email           text,
  sender_avatar_url      text,
  recipient_id           uuid,
  recipient_display_name text,
  recipient_email        text,
  recipient_avatar_url   text,
  recipient_role         text
)
language sql
stable
security definer
set search_path = public
as $$
  with base as (
    select
      a.id                          as alert_id,
      a.message_id                  as message_id,
      a.preview                     as preview,
      a.status::text                as moderation_status,
      a.categories                  as moderation_categories,
      a.concern_category            as concern_category,
      a.concern_confidence          as concern_confidence,
      a.concern_reason              as concern_reason,
      a.created_at                  as created_at,
      ct.id                         as thread_id,
      ct.kind::text                 as thread_kind,
      sg.id                         as small_group_id,
      sg.name                       as small_group_name,
      sp.id                         as sender_id,
      sp.display_name               as sender_display_name,
      sp.email                      as sender_email,
      sp.avatar_url                 as sender_avatar_url,
      case
        when ct.kind::text in ('dm_pastor','dm_leader') then (
          select ts.user_id
          from public.thread_subscribers ts
          where ts.thread_id = ct.id
            and ts.user_id <> a.sender_id
          order by ts.joined_at asc
          limit 1
        )
        else null
      end as r_recipient_id,
      a.group_id                    as a_group_id
    from public.moderation_alerts a
    join public.chat_threads ct       on ct.id = a.thread_id
    left join public.small_groups sg  on sg.id = ct.small_group_id
    left join public.profiles sp      on sp.id = a.sender_id
    where a.group_id = _group_id
      and a.acknowledged_at is null
  )
  select
    b.alert_id, b.message_id, b.preview, b.moderation_status,
    b.moderation_categories,
    b.concern_category, b.concern_confidence, b.concern_reason,
    b.created_at,
    b.thread_id, b.thread_kind, b.small_group_id, b.small_group_name,
    b.sender_id, b.sender_display_name, b.sender_email, b.sender_avatar_url,
    b.r_recipient_id                       as recipient_id,
    rp.display_name                         as recipient_display_name,
    rp.email                                as recipient_email,
    rp.avatar_url                           as recipient_avatar_url,
    rygm.role::text                         as recipient_role
  from base b
  left join public.profiles rp           on rp.id  = b.r_recipient_id
  left join public.youth_group_members rygm
       on rygm.user_id = b.r_recipient_id and rygm.group_id = b.a_group_id
  where
    is_group_pastor(auth.uid(), _group_id)
    or is_site_admin(auth.uid())
  order by b.created_at desc;
$$;

grant execute on function public.pastor_moderation_queue(uuid) to authenticated;
