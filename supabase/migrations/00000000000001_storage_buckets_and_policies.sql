-- Storage buckets and RLS policies that prod relied on at baseline time.
-- Kept as a separate forward migration (not in the public-schema baseline)
-- because pg_dump emits storage internals that the standard CLI role
-- can't recreate in a shadow DB, but bucket inserts and CREATE POLICY
-- are well within role permissions.

-- ---------- buckets ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('avatars',            'avatars',            true,  5242880,  array['image/png','image/jpeg','image/webp','image/svg+xml']),
  ('bible-plan-headers', 'bible-plan-headers', true,  5242880,  array['image/png','image/jpeg','image/webp']),
  ('event-covers',       'event-covers',       true,  5242880,  array['image/png','image/jpeg','image/webp','image/svg+xml']),
  ('event-media',        'event-media',        false, 52428800, array['image/png','image/jpeg','image/webp','image/heic','image/heif','video/mp4','video/quicktime']),
  ('feed-photos',        'feed-photos',        true,  10485760, array['image/png','image/jpeg','image/webp','image/heic','image/heif']),
  ('youth-group-logos',  'youth-group-logos',  true,  5242880,  array['image/png','image/jpeg','image/webp','image/svg+xml'])
on conflict (id) do nothing;

-- ---------- policies on storage.objects ----------

-- avatars
create policy "avatars: public read" on storage.objects for select
  using (bucket_id = 'avatars');

create policy "avatars: self/manager insert" on storage.objects for insert
  with check (bucket_id = 'avatars' and can_manage_user_profile(auth.uid(), try_parse_uuid(split_part(name,'/',1))));

create policy "avatars: self/manager update" on storage.objects for update
  using (bucket_id = 'avatars' and can_manage_user_profile(auth.uid(), try_parse_uuid(split_part(name,'/',1))));

create policy "avatars: self/manager delete" on storage.objects for delete
  using (bucket_id = 'avatars' and can_manage_user_profile(auth.uid(), try_parse_uuid(split_part(name,'/',1))));

-- bible-plan-headers
create policy "bible-plan-headers: public read" on storage.objects for select
  using (bucket_id = 'bible-plan-headers');

create policy "bible-plan-headers: pastor write" on storage.objects for insert
  with check (
    bucket_id = 'bible-plan-headers' and (
      is_site_admin(auth.uid()) or exists (
        select 1 from bible_plans p
         where p.id = try_parse_uuid(split_part(name,'/',1))
           and p.scope = 'group'::bible_plan_scope
           and is_group_pastor(auth.uid(), p.group_id)
      )
    )
  );

create policy "bible-plan-headers: pastor update" on storage.objects for update
  using (
    bucket_id = 'bible-plan-headers' and (
      is_site_admin(auth.uid()) or exists (
        select 1 from bible_plans p
         where p.id = try_parse_uuid(split_part(objects.name,'/',1))
           and p.scope = 'group'::bible_plan_scope
           and is_group_pastor(auth.uid(), p.group_id)
      )
    )
  );

create policy "bible-plan-headers: pastor delete" on storage.objects for delete
  using (
    bucket_id = 'bible-plan-headers' and (
      is_site_admin(auth.uid()) or exists (
        select 1 from bible_plans p
         where p.id = try_parse_uuid(split_part(objects.name,'/',1))
           and p.scope = 'group'::bible_plan_scope
           and is_group_pastor(auth.uid(), p.group_id)
      )
    )
  );

-- event-covers
create policy "event-covers: public read" on storage.objects for select
  using (bucket_id = 'event-covers');

create policy "event-covers: pastor/admin write" on storage.objects for insert
  with check (bucket_id = 'event-covers' and (is_site_admin(auth.uid()) or is_group_pastor(auth.uid(), try_parse_uuid(split_part(name,'/',1)))));

create policy "event-covers: pastor/admin update" on storage.objects for update
  using (bucket_id = 'event-covers' and (is_site_admin(auth.uid()) or is_group_pastor(auth.uid(), try_parse_uuid(split_part(name,'/',1)))));

create policy "event-covers: pastor/admin delete" on storage.objects for delete
  using (bucket_id = 'event-covers' and (is_site_admin(auth.uid()) or is_group_pastor(auth.uid(), try_parse_uuid(split_part(name,'/',1)))));

-- event-media
create policy "event-media: members read" on storage.objects for select
  using (
    bucket_id = 'event-media' and (
      is_site_admin(auth.uid()) or exists (
        select 1 from youth_group_members
         where youth_group_members.user_id = auth.uid()
           and youth_group_members.group_id = try_parse_uuid(split_part(objects.name,'/',1))
      )
    )
  );

create policy "event-media: pastor write" on storage.objects for insert
  with check (bucket_id = 'event-media' and (is_site_admin(auth.uid()) or is_group_pastor(auth.uid(), try_parse_uuid(split_part(name,'/',1)))));

create policy "event-media: pastor update" on storage.objects for update
  using (bucket_id = 'event-media' and (is_site_admin(auth.uid()) or is_group_pastor(auth.uid(), try_parse_uuid(split_part(name,'/',1)))));

create policy "event-media: pastor delete" on storage.objects for delete
  using (bucket_id = 'event-media' and (is_site_admin(auth.uid()) or is_group_pastor(auth.uid(), try_parse_uuid(split_part(name,'/',1)))));

-- feed-photos
create policy "feed-photos: public read" on storage.objects for select
  using (bucket_id = 'feed-photos');

create policy "feed-photos: pastor write" on storage.objects for insert
  with check (
    bucket_id = 'feed-photos' and (
      is_site_admin(auth.uid()) or exists (
        select 1 from feed_posts fp
         where fp.id = try_parse_uuid(split_part(name,'/',1))
           and fp.scope = 'group'
           and is_group_pastor(auth.uid(), fp.group_id)
      )
    )
  );

create policy "feed-photos: pastor update" on storage.objects for update
  using (
    bucket_id = 'feed-photos' and (
      is_site_admin(auth.uid()) or exists (
        select 1 from feed_posts fp
         where fp.id = try_parse_uuid(split_part(objects.name,'/',1))
           and fp.scope = 'group'
           and is_group_pastor(auth.uid(), fp.group_id)
      )
    )
  );

create policy "feed-photos: pastor delete" on storage.objects for delete
  using (
    bucket_id = 'feed-photos' and (
      is_site_admin(auth.uid()) or exists (
        select 1 from feed_posts fp
         where fp.id = try_parse_uuid(split_part(objects.name,'/',1))
           and fp.scope = 'group'
           and is_group_pastor(auth.uid(), fp.group_id)
      )
    )
  );

-- youth-group-logos (policies named "logos: ...")
create policy "logos: public read" on storage.objects for select
  using (bucket_id = 'youth-group-logos');

create policy "logos: pastor/admin write" on storage.objects for insert
  with check (bucket_id = 'youth-group-logos' and (is_site_admin(auth.uid()) or is_group_pastor(auth.uid(), try_parse_uuid(split_part(name,'/',1)))));

create policy "logos: pastor/admin update" on storage.objects for update
  using (bucket_id = 'youth-group-logos' and (is_site_admin(auth.uid()) or is_group_pastor(auth.uid(), try_parse_uuid(split_part(name,'/',1)))));

create policy "logos: pastor/admin delete" on storage.objects for delete
  using (bucket_id = 'youth-group-logos' and (is_site_admin(auth.uid()) or is_group_pastor(auth.uid(), try_parse_uuid(split_part(name,'/',1)))));

create policy "logos: draft owner write" on storage.objects for insert
  with check (
    bucket_id = 'youth-group-logos'
    and split_part(name,'/',1) = 'drafts'
    and (
      is_site_admin(auth.uid()) or exists (
        select 1 from pastor_signup_drafts d
         where d.id = try_parse_uuid(split_part(name,'/',2))
           and d.user_id = auth.uid()
      )
    )
  );

create policy "logos: draft owner update" on storage.objects for update
  using (
    bucket_id = 'youth-group-logos'
    and split_part(objects.name,'/',1) = 'drafts'
    and (
      is_site_admin(auth.uid()) or exists (
        select 1 from pastor_signup_drafts d
         where d.id = try_parse_uuid(split_part(objects.name,'/',2))
           and d.user_id = auth.uid()
      )
    )
  );

create policy "logos: draft owner delete" on storage.objects for delete
  using (
    bucket_id = 'youth-group-logos'
    and split_part(objects.name,'/',1) = 'drafts'
    and (
      is_site_admin(auth.uid()) or exists (
        select 1 from pastor_signup_drafts d
         where d.id = try_parse_uuid(split_part(objects.name,'/',2))
           and d.user_id = auth.uid()
      )
    )
  );
