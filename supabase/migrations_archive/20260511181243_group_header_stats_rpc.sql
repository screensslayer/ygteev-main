
create or replace function public.get_group_header_stats(_group_id uuid)
returns table (member_count int, active_count int)
language plpgsql stable security definer set search_path = public as $$
begin
  if not (public.is_site_admin(auth.uid()) or public.is_group_member(auth.uid(), _group_id)) then
    raise exception 'not_authorized';
  end if;
  return query
  select
    (select count(*)::int from public.youth_group_members where group_id = _group_id),
    (select count(*)::int
       from public.youth_group_members ygm
       join public.profiles p on p.id = ygm.user_id
       where ygm.group_id = _group_id
         and p.last_opened_at >= now() - interval '90 days');
end $$;
