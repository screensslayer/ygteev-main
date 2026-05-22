
-- ---------- Helper #1: is the user subscribed to this thread? ----------
-- SECURITY DEFINER bypasses RLS, breaking the recursive call chain.
create or replace function public.is_thread_subscriber(_thread_id uuid, _user_id uuid default null)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.thread_subscribers
    where thread_id = _thread_id
      and user_id = coalesce(_user_id, auth.uid())
  );
$$;

-- ---------- Helper #2: what group does this thread belong to? ----------
create or replace function public.thread_group_id(_thread_id uuid)
returns uuid
language sql stable security definer set search_path = public
as $$
  select group_id from public.chat_threads where id = _thread_id;
$$;

-- ---------- Rewrite policies using the helpers (no more cross-table EXISTS) ----------

-- chat_threads
drop policy if exists "threads: subscriber read" on public.chat_threads;
create policy "threads: subscriber read" on public.chat_threads for select using (
  public.is_site_admin(auth.uid())
  or public.is_group_pastor(auth.uid(), group_id)
  or public.is_thread_subscriber(id, auth.uid())
);

-- thread_subscribers
drop policy if exists "subs: read" on public.thread_subscribers;
create policy "subs: read" on public.thread_subscribers for select using (
  user_id = auth.uid()
  or public.is_site_admin(auth.uid())
  or public.is_group_pastor(auth.uid(), public.thread_group_id(thread_id))
);

-- messages
drop policy if exists "messages: subscriber read" on public.messages;
create policy "messages: subscriber read" on public.messages for select using (
  public.is_site_admin(auth.uid())
  or public.is_thread_subscriber(thread_id, auth.uid())
  or public.is_group_pastor(auth.uid(), public.thread_group_id(thread_id))
);
