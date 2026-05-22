-- Surface youth_groups.address through pastor_my_groups so the iOS
-- pastor dashboard / Create Event sheet has it without a second fetch.
drop function if exists public.pastor_my_groups();
create or replace function public.pastor_my_groups()
returns table(group_id uuid, name text, address text, member_count integer)
language sql stable security definer
set search_path = public
as $$
  select
    yg.id   as group_id,
    yg.name,
    yg.address,
    (select count(*)::int from public.youth_group_members ygm
       where ygm.group_id = yg.id) as member_count
  from public.youth_groups yg
  join public.youth_group_members me on me.group_id = yg.id
  where me.user_id = auth.uid()
    and me.role = 'pastor'
  order by yg.name;
$$;
