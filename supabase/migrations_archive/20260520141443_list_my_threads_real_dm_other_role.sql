-- list_my_threads previously labeled dm_other_role from the THREAD
-- KIND, which is the wrong side of the relationship: for a leader
-- viewing a dm_leader thread, the OTHER person is the member, not
-- another leader. Same for dm_parent_*.
--
-- Resolve the label from the other user's actual position in the
-- thread's youth group: pastor > small-group leader > parent (of any
-- child in this group) > member. Falls back to nil if none apply.

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
    -- Derived from the OTHER user's actual position in this group:
    --   pastor → 'pastor'
    --   small-group leader (anywhere in this YG) → 'leader'
    --   parent of a child in this YG → 'parent'
    --   plain member → 'member'
    case
      when dmo.user_id is null then null
      when exists (
        select 1 from public.youth_group_members ygm
        where ygm.group_id = t.group_id
          and ygm.user_id = dmo.user_id
          and ygm.role = 'pastor'
      ) then 'pastor'
      when exists (
        select 1
        from public.small_group_members sgm
        join public.small_groups sg2 on sg2.id = sgm.small_group_id
        where sgm.user_id = dmo.user_id
          and sgm.role = 'leader'
          and sg2.youth_group_id = t.group_id
      ) then 'leader'
      when exists (
        select 1
        from public.family_members fm_parent
        join public.family_members fm_child
          on fm_child.family_id = fm_parent.family_id and fm_child.role = 'child'
        join public.youth_group_members child_ygm
          on child_ygm.user_id = fm_child.user_id and child_ygm.group_id = t.group_id
        where fm_parent.user_id = dmo.user_id and fm_parent.role = 'parent'
      ) then 'parent'
      when exists (
        select 1 from public.youth_group_members ygm
        where ygm.group_id = t.group_id
          and ygm.user_id = dmo.user_id
      ) then 'member'
      else null
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
