
create or replace function public.increment_pastor_signup_promo_uses(_code text)
returns void
language sql
security definer
set search_path = public
as $$
  update public.pastor_signup_promos
  set uses_count = uses_count + 1,
      updated_at = now()
  where lower(code) = lower(_code);
$$;

-- Only the service role calls this (from the Edge Function). Don't
-- grant to anon/authenticated.
revoke all on function public.increment_pastor_signup_promo_uses(text) from public;
revoke all on function public.increment_pastor_signup_promo_uses(text) from anon, authenticated;
