-- Two follow-ups to the leave-group flow:
--   1. When a child is removed from a youth group, unsubscribe their
--      parent(s) from the related parent_chat / dm_parent_pastor /
--      dm_parent_leader threads — UNLESS the parent still has another
--      child in that group.
--   2. Block pastors from self-deleting their own membership row.
--      Site admins and other pastors removing them is still allowed.

-- ============================================================================
-- 1) Extend tg_chat_on_youth_group_member_delete with parent cleanup
-- ============================================================================
create or replace function public.tg_chat_on_youth_group_member_delete()
returns trigger
language plpgsql security definer
set search_path = public
as $function$
declare
  _thread_id uuid;
  v_parent uuid;
begin
  -- Default YGTeeV group: nothing to clean up (members never get
  -- group-specific chat subscriptions for it).
  if exists (select 1 from public.youth_groups
             where id = OLD.group_id and is_default_ygteev = true) then
    return OLD;
  end if;

  -- Existing cleanup: leaving user's own subscriptions
  select id into _thread_id from public.chat_threads
    where group_id = OLD.group_id and kind = 'group_main';
  if _thread_id is not null then
    delete from public.thread_subscribers
      where thread_id = _thread_id and user_id = OLD.user_id;
  end if;

  delete from public.thread_subscribers ts
  using public.chat_threads ct
  where ts.thread_id = ct.id
    and ct.group_id = OLD.group_id
    and ct.kind = 'dm_pastor'
    and (ct.dm_user_a = OLD.user_id or ct.dm_user_b = OLD.user_id)
    and ts.user_id = OLD.user_id;

  -- Cascade small-group memberships (its own delete trigger handles SG chat)
  delete from public.small_group_members
    where user_id = OLD.user_id
      and small_group_id in (
        select id from public.small_groups where youth_group_id = OLD.group_id
      );

  -- NEW: parent-of-leaving-child cleanup. For each parent linked to
  -- the leaving child via family_members, check if the parent still
  -- has another child in this youth group. If not, unsubscribe the
  -- parent from this YG's parent threads.
  for v_parent in
    select distinct fm_parent.user_id
    from public.family_members fm_child
    join public.family_members fm_parent
      on fm_parent.family_id = fm_child.family_id and fm_parent.role = 'parent'
    where fm_child.user_id = OLD.user_id and fm_child.role = 'child'
  loop
    if not exists (
      select 1
      from public.family_members fm_p2
      join public.family_members fm_c2
        on fm_c2.family_id = fm_p2.family_id and fm_c2.role = 'child'
      join public.youth_group_members ygm2
        on ygm2.user_id = fm_c2.user_id and ygm2.group_id = OLD.group_id
      where fm_p2.user_id = v_parent
        and fm_p2.role    = 'parent'
        and fm_c2.user_id <> OLD.user_id
    ) then
      -- No other children of this parent in this YG → drop parent's
      -- subscriptions for this group's parent threads.

      -- 1) parent_chat (group-wide)
      delete from public.thread_subscribers ts
      using public.chat_threads t
      where ts.thread_id = t.id
        and t.kind       = 'parent_chat'
        and t.group_id   = OLD.group_id
        and ts.user_id   = v_parent;

      -- 2) dm_parent_pastor (parent ↔ each pastor of this YG)
      delete from public.thread_subscribers ts
      using public.chat_threads t
      where ts.thread_id = t.id
        and t.kind       = 'dm_parent_pastor'
        and t.group_id   = OLD.group_id
        and ts.user_id   = v_parent;

      -- 3) dm_parent_leader (parent ↔ leaders of small groups under this YG)
      delete from public.thread_subscribers ts
      using public.chat_threads t
      join public.small_groups sg on sg.id = t.small_group_id
      where ts.thread_id = t.id
        and t.kind       = 'dm_parent_leader'
        and sg.youth_group_id = OLD.group_id
        and ts.user_id   = v_parent;
    end if;
  end loop;

  return OLD;
end $function$;

-- ============================================================================
-- 2) Block self-delete by pastors
-- ============================================================================
create or replace function public.tg_block_pastor_self_leave()
returns trigger
language plpgsql
set search_path = public
as $function$
begin
  if OLD.role = 'pastor' and OLD.user_id = auth.uid() then
    raise exception 'pastor_cannot_leave_own_group'
      using errcode = '42501',
            message = 'Pastors cannot leave their own youth group. '
                      'Transfer ownership or contact support first.';
  end if;
  return OLD;
end;
$function$;

drop trigger if exists trg_block_pastor_self_leave on public.youth_group_members;
create trigger trg_block_pastor_self_leave
  before delete on public.youth_group_members
  for each row execute function public.tg_block_pastor_self_leave();
