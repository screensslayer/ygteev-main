-- Allow pastor-onboarding logo uploads to the staging path
-- `youth-group-logos/drafts/<draft_id>/...` when the draft row belongs
-- to the caller. The existing `<group_id>/...` policies stay in place;
-- multiple permissive policies are OR'd, so legacy uploads keep working.

drop policy if exists "logos: draft owner write"  on storage.objects;
drop policy if exists "logos: draft owner update" on storage.objects;
drop policy if exists "logos: draft owner delete" on storage.objects;

create policy "logos: draft owner write"
on storage.objects
for insert
to public
with check (
  bucket_id = 'youth-group-logos'
  and split_part(name, '/', 1) = 'drafts'
  and (
    is_site_admin(auth.uid())
    or exists (
      select 1 from public.pastor_signup_drafts d
      where d.id = try_parse_uuid(split_part(name, '/', 2))
        and d.user_id = auth.uid()
    )
  )
);

create policy "logos: draft owner update"
on storage.objects
for update
to public
using (
  bucket_id = 'youth-group-logos'
  and split_part(name, '/', 1) = 'drafts'
  and (
    is_site_admin(auth.uid())
    or exists (
      select 1 from public.pastor_signup_drafts d
      where d.id = try_parse_uuid(split_part(name, '/', 2))
        and d.user_id = auth.uid()
    )
  )
);

create policy "logos: draft owner delete"
on storage.objects
for delete
to public
using (
  bucket_id = 'youth-group-logos'
  and split_part(name, '/', 1) = 'drafts'
  and (
    is_site_admin(auth.uid())
    or exists (
      select 1 from public.pastor_signup_drafts d
      where d.id = try_parse_uuid(split_part(name, '/', 2))
        and d.user_id = auth.uid()
    )
  )
);
