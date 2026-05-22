
-- ---------- 1. Helper: who can manage a given user's profile? ----------
-- True if: self, site_admin, or pastor/leader of any group containing target.
create or replace function public.can_manage_user_profile(_caller_id uuid, _target_user_id uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select
    _caller_id = _target_user_id
    or public.is_site_admin(_caller_id)
    or exists (
      select 1
      from public.youth_group_members ygm_target
      join public.youth_group_members ygm_caller
        on ygm_caller.group_id = ygm_target.group_id
      where ygm_target.user_id = _target_user_id
        and ygm_caller.user_id = _caller_id
        and ygm_caller.role in ('pastor', 'leader')
    );
$$;

-- ---------- 2. RPC: scoped profile update (display_name + avatar_url only) ----------
-- Intentionally narrow: gamification columns (xp/water/streak/last_opened_at)
-- stay server-controlled. coalesce() lets callers patch one field at a time.
create or replace function public.update_managed_profile(
  _target_user_id uuid,
  _display_name   text default null,
  _avatar_url     text default null
)
returns public.profiles
language plpgsql security definer set search_path = public as $$
declare
  _result public.profiles;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if not public.can_manage_user_profile(auth.uid(), _target_user_id) then
    raise exception 'not_authorized';
  end if;

  update public.profiles
     set display_name = coalesce(_display_name, display_name),
         avatar_url   = coalesce(_avatar_url,   avatar_url),
         updated_at   = now()
   where id = _target_user_id
   returning * into _result;

  if _result.id is null then
    raise exception 'profile_not_found';
  end if;

  return _result;
end $$;

-- ---------- 3. Avatars storage bucket ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  5242880,
  array['image/png','image/jpeg','image/webp','image/svg+xml']
)
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- ---------- 4. Storage policies for avatars ----------
-- Path convention enforced by RLS:  {user_id}/{filename}
drop policy if exists "avatars: public read"          on storage.objects;
drop policy if exists "avatars: self/manager insert"  on storage.objects;
drop policy if exists "avatars: self/manager update"  on storage.objects;
drop policy if exists "avatars: self/manager delete"  on storage.objects;

create policy "avatars: public read"
  on storage.objects for select
  using (bucket_id = 'avatars');

create policy "avatars: self/manager insert"
  on storage.objects for insert
  with check (
    bucket_id = 'avatars'
    and public.can_manage_user_profile(
      auth.uid(),
      public.try_parse_uuid(split_part(name, '/', 1))
    )
  );

create policy "avatars: self/manager update"
  on storage.objects for update
  using (
    bucket_id = 'avatars'
    and public.can_manage_user_profile(
      auth.uid(),
      public.try_parse_uuid(split_part(name, '/', 1))
    )
  );

create policy "avatars: self/manager delete"
  on storage.objects for delete
  using (
    bucket_id = 'avatars'
    and public.can_manage_user_profile(
      auth.uid(),
      public.try_parse_uuid(split_part(name, '/', 1))
    )
  );
