
-- 1. Expand can_manage_user_profile to also cover pure small-group leaders.
create or replace function public.can_manage_user_profile(_caller_id uuid, _target_user_id uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select
    _caller_id = _target_user_id
    or public.is_site_admin(_caller_id)
    -- Same youth group, caller is pastor or leader there
    or exists (
      select 1
      from public.youth_group_members ygm_target
      join public.youth_group_members ygm_caller
        on ygm_caller.group_id = ygm_target.group_id
      where ygm_target.user_id = _target_user_id
        and ygm_caller.user_id  = _caller_id
        and ygm_caller.role in ('pastor', 'leader')
    )
    -- Same small group, caller is a leader there
    or exists (
      select 1
      from public.small_group_members sgm_target
      join public.small_group_members sgm_caller
        on sgm_caller.small_group_id = sgm_target.small_group_id
      where sgm_target.user_id = _target_user_id
        and sgm_caller.user_id  = _caller_id
        and sgm_caller.role = 'leader'
    );
$$;

-- 2. Add a SELECT policy on profiles for leaders / pastors / admins.
-- The original "profiles: self read" stays in place (self + admin
-- branch); PERMISSIVE policies OR together, so the broader read works.
drop policy if exists "profiles: manager read" on public.profiles;
create policy "profiles: manager read" on public.profiles for select using (
  public.can_manage_user_profile(auth.uid(), id)
);

notify pgrst, 'reload schema';
