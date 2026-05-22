
-- 1. Map visibility flag on profiles. Defaults to true; under-13 accounts are
--    forced false elsewhere (separate COPPA rule already lives in
--    profiles_under_13_rule trigger if/when added).
alter table public.profiles
  add column if not exists is_visible_on_map boolean not null default true;

-- 2. Soft-delete marker.
alter table public.profiles
  add column if not exists deleted_at timestamptz;

-- 3. RPC: user-initiated soft-deletion of their own account.
--    Marks profiles.deleted_at = now() for the calling user. Hard deletion of
--    auth.users is a separate admin-only operation handled out-of-band.
create or replace function public.request_account_deletion()
returns void
language plpgsql
security definer
set search_path = public
as $func$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  update public.profiles
    set deleted_at = coalesce(deleted_at, now()),
        updated_at = now()
    where id = v_uid;
end;
$func$;

grant execute on function public.request_account_deletion() to authenticated;

-- 4. RPC: toggle map visibility on the caller's own profile.
create or replace function public.set_map_visibility(_visible boolean)
returns boolean
language plpgsql
security definer
set search_path = public
as $func$
declare
  v_uid uuid := auth.uid();
  v_new boolean;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  update public.profiles
    set is_visible_on_map = _visible,
        updated_at = now()
    where id = v_uid
    returning is_visible_on_map into v_new;

  return v_new;
end;
$func$;

grant execute on function public.set_map_visibility(boolean) to authenticated;

notify pgrst, 'reload schema';
