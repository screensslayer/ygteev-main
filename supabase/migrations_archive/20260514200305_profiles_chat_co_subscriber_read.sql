
-- Allow members to read profiles of users they share a chat thread with.
-- Used by the iOS chat view's "load sender display_name + avatar_url" lookup.
--
-- This is intentionally chat-scoped (via thread_subscribers) rather than the
-- broader "anyone in the same youth group" — chat thread membership is the
-- precise gate for "we are allowed to see each other's names in conversation."

create policy "profiles: chat co-subscriber read" on public.profiles
for select
using (
  exists (
    select 1
    from public.thread_subscribers ts_me
    join public.thread_subscribers ts_them
      on ts_me.thread_id = ts_them.thread_id
    where ts_me.user_id   = auth.uid()
      and ts_them.user_id = profiles.id
  )
);

notify pgrst, 'reload schema';
