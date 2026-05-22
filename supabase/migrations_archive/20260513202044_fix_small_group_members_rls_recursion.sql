
-- The previous "sgm: members read" policy contained an inline EXISTS subquery
-- that read small_group_members from inside small_group_members' own policy,
-- causing infinite recursion. Replace with a call to the SECURITY DEFINER
-- helper public.is_small_group_leader (which bypasses RLS).

drop policy if exists "sgm: members read" on public.small_group_members;
create policy "sgm: members read" on public.small_group_members for select using (
  public.is_site_admin(auth.uid())
  or user_id = auth.uid()
  or exists (
    select 1 from public.small_groups sg
    where sg.id = small_group_id
      and public.is_group_pastor(auth.uid(), sg.youth_group_id)
  )
  or public.is_small_group_leader(auth.uid(), small_group_id)
);
