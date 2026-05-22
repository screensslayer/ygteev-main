
-- The previous "profiles: chat co-subscriber read" policy can't see the other
-- user's thread_subscribers row because that table has its own RLS limiting
-- visibility to self. Rewrite using a SECURITY DEFINER helper that bypasses
-- RLS on thread_subscribers for this specific check.

create or replace function public.share_chat_thread(_other_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $func$
  select exists (
    select 1
    from public.thread_subscribers ts_me
    join public.thread_subscribers ts_them
      on ts_me.thread_id = ts_them.thread_id
    where ts_me.user_id   = auth.uid()
      and ts_them.user_id = _other_user_id
  );
$func$;

grant execute on function public.share_chat_thread(uuid) to authenticated;

drop policy if exists "profiles: chat co-subscriber read" on public.profiles;
create policy "profiles: chat co-subscriber read" on public.profiles
for select
using (
  public.share_chat_thread(profiles.id)
);

notify pgrst, 'reload schema';
