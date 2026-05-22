
-- ---------- Trigger: youth_group_members DELETE ----------
create or replace function public.tg_chat_on_youth_group_member_delete()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  _thread_id uuid;
begin
  if exists (select 1 from public.youth_groups where id = OLD.group_id and is_default_ygteev = true) then
    return OLD;
  end if;

  -- Unsubscribe from the group_main thread
  select id into _thread_id from public.chat_threads
    where group_id = OLD.group_id and kind = 'group_main';
  if _thread_id is not null then
    delete from public.thread_subscribers
      where thread_id = _thread_id and user_id = OLD.user_id;
  end if;

  -- Unsubscribe from dm_pastor threads in this group involving the leaving user
  delete from public.thread_subscribers ts
  using public.chat_threads ct
  where ts.thread_id = ct.id
    and ct.group_id = OLD.group_id
    and ct.kind = 'dm_pastor'
    and (ct.dm_user_a = OLD.user_id or ct.dm_user_b = OLD.user_id)
    and ts.user_id = OLD.user_id;

  -- Cascade: remove this user from any small groups under this youth group.
  -- The small_group_members DELETE trigger handles the rest (small group
  -- thread unsubscription + dm_leader cleanup).
  delete from public.small_group_members
    where user_id = OLD.user_id
      and small_group_id in (
        select id from public.small_groups where youth_group_id = OLD.group_id
      );

  return OLD;
end $$;

drop trigger if exists chat_on_ygm_delete on public.youth_group_members;
create trigger chat_on_ygm_delete
  after delete on public.youth_group_members
  for each row execute function public.tg_chat_on_youth_group_member_delete();

-- ---------- Trigger: small_group_members DELETE ----------
create or replace function public.tg_chat_on_small_group_member_delete()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  _thread_id uuid;
  _group_id  uuid;
begin
  select youth_group_id into _group_id from public.small_groups where id = OLD.small_group_id;

  -- Unsubscribe from this small_group thread
  select id into _thread_id from public.chat_threads
    where small_group_id = OLD.small_group_id and kind = 'small_group';
  if _thread_id is not null then
    delete from public.thread_subscribers
      where thread_id = _thread_id and user_id = OLD.user_id;
  end if;

  -- Unsubscribe from dm_leader threads in this youth group involving the
  -- leaving user, but ONLY where the leader-member pairing no longer exists
  -- in any remaining small group (i.e., they're not still in another small
  -- group together).
  delete from public.thread_subscribers ts
  using public.chat_threads ct
  where ts.thread_id = ct.id
    and ct.kind = 'dm_leader'
    and ct.group_id = _group_id
    and (ct.dm_user_a = OLD.user_id or ct.dm_user_b = OLD.user_id)
    and ts.user_id = OLD.user_id
    and not exists (
      select 1
      from public.small_group_members m1
      join public.small_group_members m2 on m1.small_group_id = m2.small_group_id
      where m1.user_id = ct.dm_user_a
        and m2.user_id = ct.dm_user_b
        and (m1.role = 'leader' or m2.role = 'leader')
    );

  return OLD;
end $$;

drop trigger if exists chat_on_sgm_delete on public.small_group_members;
create trigger chat_on_sgm_delete
  after delete on public.small_group_members
  for each row execute function public.tg_chat_on_small_group_member_delete();
