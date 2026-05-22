
-- Allow a user to delete their own membership row (i.e. leave a
-- youth group). The tg_block_pastor_self_leave BEFORE DELETE trigger
-- still applies: pastors get a clean error message instead of silently
-- failing if they try to leave their own group.
--
-- Combined behavior:
--   • Regular member / leader → can leave freely.
--   • Pastor → trigger raises pastor_cannot_leave_own_group.
--   • Pastor of OTHER members → already covered by "ygm: pastor manages".
--   • Site admin → already covered by both existing policies.

create policy "ygm: self leave"
  on public.youth_group_members
  for delete
  using (auth.uid() = user_id);
