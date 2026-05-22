-- When a child joins a youth group or small group AFTER they're already
-- in a family, re-run ensure_parent_chat_subscriptions for each parent
-- so the parent picks up the new parent_chat / dm_parent_pastor /
-- dm_parent_leader threads. ensure_* is idempotent so it's safe to
-- call many times.

create or replace function public.tg_chat_on_youth_group_member_insert()
returns trigger
language plpgsql security definer
set search_path = public
as $function$
declare
  _main_thread_id uuid;
  _peer record;
  _fam record;
begin
  if exists (select 1 from public.youth_groups where id = NEW.group_id and is_default_ygteev = true) then
    return NEW;
  end if;

  _main_thread_id := public.ensure_group_main_thread(NEW.group_id);
  insert into public.thread_subscribers(thread_id, user_id)
    values (_main_thread_id, NEW.user_id) on conflict do nothing;

  if NEW.role = 'member' then
    for _peer in select user_id from public.youth_group_members
                 where group_id = NEW.group_id and role = 'pastor' loop
      perform public.ensure_dm_thread(NEW.group_id, 'dm_pastor', NEW.user_id, _peer.user_id);
    end loop;
  end if;

  if NEW.role = 'pastor' then
    for _peer in select user_id from public.youth_group_members
                 where group_id = NEW.group_id and role = 'member' loop
      perform public.ensure_dm_thread(NEW.group_id, 'dm_pastor', NEW.user_id, _peer.user_id);
    end loop;
  end if;

  -- NEW: if the joining user is a child in any family, rewire each of
  -- that family's parents for parent_chat / dm_parent_pastor.
  for _fam in
    select fm_p.user_id as parent_id, fm_c.family_id
    from public.family_members fm_c
    join public.family_members fm_p
      on fm_p.family_id = fm_c.family_id and fm_p.role = 'parent'
    where fm_c.user_id = NEW.user_id and fm_c.role = 'child'
  loop
    perform public.ensure_parent_chat_subscriptions(_fam.parent_id, _fam.family_id);
  end loop;

  return NEW;
end $function$;

create or replace function public.tg_chat_on_small_group_member_insert()
returns trigger
language plpgsql security definer
set search_path = public
as $function$
declare
  _thread_id uuid;
  _group_id uuid;
  _peer record;
  _fam record;
begin
  select youth_group_id into _group_id from public.small_groups where id = NEW.small_group_id;
  _thread_id := public.ensure_small_group_thread(NEW.small_group_id);
  insert into public.thread_subscribers(thread_id, user_id)
    values (_thread_id, NEW.user_id) on conflict do nothing;

  if NEW.role = 'member' then
    for _peer in select user_id from public.small_group_members
                 where small_group_id = NEW.small_group_id and role = 'leader' loop
      perform public.ensure_dm_thread(_group_id, 'dm_leader', NEW.user_id, _peer.user_id);
    end loop;
  end if;

  if NEW.role = 'leader' then
    for _peer in select user_id from public.small_group_members
                 where small_group_id = NEW.small_group_id and role = 'member' loop
      perform public.ensure_dm_thread(_group_id, 'dm_leader', NEW.user_id, _peer.user_id);
    end loop;
  end if;

  -- NEW: rewire the joining user's parents for dm_parent_leader threads
  -- against this small group's leader.
  for _fam in
    select fm_p.user_id as parent_id, fm_c.family_id
    from public.family_members fm_c
    join public.family_members fm_p
      on fm_p.family_id = fm_c.family_id and fm_p.role = 'parent'
    where fm_c.user_id = NEW.user_id and fm_c.role = 'child'
  loop
    perform public.ensure_parent_chat_subscriptions(_fam.parent_id, _fam.family_id);
  end loop;

  return NEW;
end $function$;

-- Backfill: catch parent1@ygteev.com up immediately on the existing
-- child memberships.
select public.ensure_parent_chat_subscriptions(
  'b838bf3f-71ff-4a91-9d90-bf7023bae7a7'::uuid,    -- parent1
  '857bba38-286d-468f-bc5a-686855183fe8'::uuid     -- parent1's family
);
