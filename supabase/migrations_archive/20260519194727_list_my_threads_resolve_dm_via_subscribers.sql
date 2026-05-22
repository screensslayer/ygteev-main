-- list_my_threads previously read `chat_threads.dm_user_a / dm_user_b`
-- to resolve the "other person" in a DM. But ensure_parent_chat_subscriptions
-- creates dm_parent_pastor / dm_parent_leader threads without touching
-- those columns — just inserts two subscribers. Result: iOS rendered
-- "Direct message" because dm_other_display came back NULL.
--
-- Authoritative source for "who's in this DM" is thread_subscribers.
-- Resolve via that instead. Works for every DM kind whether or not
-- dm_user_a is set, and is harmless if both methods agree.

create or replace function public.list_my_threads()
returns table(
  thread_id uuid, kind thread_kind,
  group_id uuid, group_name text,
  group_gradient_from text, group_gradient_to text,
  small_group_id uuid, small_group_name text,
  dm_other_user_id uuid, dm_other_display text,
  dm_other_avatar_url text, dm_other_role text,
  last_message_body text, last_message_sender text,
  last_message_at timestamptz, unread_count integer
)
language sql stable security definer
set search_path = public
as $$
  with my_subs as (
    select s.thread_id, s.last_read_at
    from public.thread_subscribers s
    where s.user_id = auth.uid()
  ),
  last_msgs as (
    select distinct on (m.thread_id)
      m.thread_id, m.body, m.sender_id, m.created_at
    from public.messages m
    join my_subs ms on ms.thread_id = m.thread_id
    order by m.thread_id, m.created_at desc
  ),
  dm_other as (
    -- For any DM-kind thread the caller is in, the "other" user is the
    -- only subscriber that isn't the caller. Two-person threads only.
    select ts.thread_id, ts.user_id, p.display_name, p.avatar_url
    from public.thread_subscribers ts
    join public.chat_threads t on t.id = ts.thread_id
    join public.profiles p on p.id = ts.user_id
    where ts.user_id <> auth.uid()
      and t.kind in ('dm_pastor'::thread_kind,
                     'dm_leader'::thread_kind,
                     'dm_parent_pastor'::thread_kind,
                     'dm_parent_leader'::thread_kind)
      and ts.thread_id in (select thread_id from my_subs)
  )
  select
    t.id,
    t.kind,
    t.group_id,
    yg.name,
    yg.gradient_from,
    yg.gradient_to,
    t.small_group_id,
    sg.name,
    dmo.user_id        as dm_other_user_id,
    dmo.display_name   as dm_other_display,
    dmo.avatar_url     as dm_other_avatar_url,
    case t.kind
      when 'dm_pastor'        then 'pastor'
      when 'dm_parent_pastor' then 'pastor'
      when 'dm_leader'        then 'leader'
      when 'dm_parent_leader' then 'leader'
    end as dm_other_role,
    lm.body,
    case when lm.sender_id = auth.uid() then 'You'
         else (select display_name from public.profiles where id = lm.sender_id) end,
    lm.created_at,
    coalesce((
      select count(*)::int from public.messages m2
      where m2.thread_id = t.id
        and m2.created_at > coalesce(ms.last_read_at, '-infinity'::timestamptz)
        and m2.sender_id <> auth.uid()
    ), 0)
  from public.chat_threads t
  join my_subs ms on ms.thread_id = t.id
  left join public.youth_groups yg on yg.id = t.group_id
  left join public.small_groups  sg on sg.id = t.small_group_id
  left join last_msgs            lm on lm.thread_id = t.id
  left join dm_other             dmo on dmo.thread_id = t.id
  order by coalesce(lm.created_at, t.created_at) desc;
$$;
