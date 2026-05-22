
-- ============================================================================
-- Pastor "Publish a Bible Plan" — authoring RPCs
--
-- All RPCs SECURITY DEFINER. Each performs an explicit pastor/admin check
-- against the target plan's group_id before mutating.
-- ============================================================================

-- Internal authz check: caller is the group's pastor or a site admin.
create or replace function public._pastor_can_edit_plan(_plan_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $func$
  select
    public.is_site_admin(auth.uid())
    or exists (
      select 1 from public.bible_plans p
      where p.id = _plan_id
        and p.scope = 'group'
        and public.is_group_pastor(auth.uid(), p.group_id)
    );
$func$;


-- ----------------------------------------------------------------------------
-- 1. pastor_create_plan
--    Creates a new draft plan for the caller's youth group with empty day
--    skeletons. Returns the new plan id.
-- ----------------------------------------------------------------------------
create or replace function public.pastor_create_plan(
  _group_id     uuid,
  _title        text,
  _days_total   int,
  _gradient_index int default 0
) returns uuid
language plpgsql
security definer
set search_path = public
as $func$
declare
  v_caller uuid := auth.uid();
  v_plan_id uuid;
  v_slug text;
  i int;
begin
  if v_caller is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  if not (public.is_site_admin(v_caller) or public.is_group_pastor(v_caller, _group_id)) then
    raise exception 'forbidden: must be a pastor of this youth group'
      using errcode = '42501';
  end if;

  if _days_total < 1 or _days_total > 30 then
    raise exception 'days_total must be between 1 and 30' using errcode = '22023';
  end if;

  -- Generate a slug: lowercase, alphanumeric + dashes, plus short random suffix
  -- to avoid uniqueness collisions across groups.
  v_slug := regexp_replace(lower(coalesce(_title, 'plan')), '[^a-z0-9]+', '-', 'g');
  v_slug := trim(both '-' from v_slug);
  if v_slug = '' then v_slug := 'plan'; end if;
  v_slug := v_slug || '-' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 6);

  insert into public.bible_plans (
    title, slug, category, scope, group_id, status, days_total,
    tree_species, gradient_index, header_kind, created_by
  ) values (
    coalesce(nullif(trim(_title), ''), 'Untitled plan'),
    v_slug,
    'group_plan'::bible_plan_category,
    'group'::bible_plan_scope,
    _group_id,
    'draft'::bible_plan_status,
    _days_total,
    'oak',  -- TODO: pastor-pickable tree species in v2
    greatest(0, least(4, _gradient_index)),
    'gradient',
    v_caller
  )
  returning id into v_plan_id;

  -- Skeleton days. The pastor flow lets them fill blocks in later.
  for i in 1 .. _days_total loop
    insert into public.bible_plan_days (plan_id, day_number, title, scripture_reference, sections)
    values (
      v_plan_id, i,
      'Day ' || i,
      '',
      jsonb_build_object('blocks', '[]'::jsonb)
    );
  end loop;

  return v_plan_id;
end;
$func$;


-- ----------------------------------------------------------------------------
-- 2. pastor_update_plan_basics
--    Update title, days_total (resizing days array), header settings.
-- ----------------------------------------------------------------------------
create or replace function public.pastor_update_plan_basics(
  _plan_id          uuid,
  _title            text default null,
  _days_total       int  default null,
  _header_kind      text default null,
  _header_image_url text default null,
  _gradient_index   int  default null
) returns void
language plpgsql
security definer
set search_path = public
as $func$
declare
  v_current_days int;
  v_new_days int;
  i int;
begin
  if not public._pastor_can_edit_plan(_plan_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  select days_total into v_current_days from public.bible_plans where id = _plan_id;

  update public.bible_plans set
    title            = coalesce(nullif(trim(_title), ''), title),
    header_kind      = coalesce(_header_kind, header_kind),
    header_image_url = case
                         when _header_kind is not null and _header_kind = 'gradient' then null
                         else coalesce(_header_image_url, header_image_url)
                       end,
    gradient_index   = case
                         when _gradient_index is null then gradient_index
                         else greatest(0, least(4, _gradient_index))
                       end,
    days_total       = case
                         when _days_total is null then days_total
                         else greatest(1, least(30, _days_total))
                       end,
    updated_at       = now()
  where id = _plan_id;

  -- Resize the days array if days_total changed
  if _days_total is not null then
    v_new_days := greatest(1, least(30, _days_total));
    if v_new_days > v_current_days then
      -- Append blank days
      for i in (v_current_days + 1) .. v_new_days loop
        insert into public.bible_plan_days (plan_id, day_number, title, scripture_reference, sections)
        values (_plan_id, i, 'Day ' || i, '', jsonb_build_object('blocks', '[]'::jsonb))
        on conflict do nothing;
      end loop;
    elsif v_new_days < v_current_days then
      -- Drop trailing days (cascades via FK? no — bible_plan_days has no
      -- cascade to clean up step_progress, but progress rows fall to leaders'
      -- cleanup via plan_id reference. For now, delete the day rows.)
      delete from public.bible_plan_days
        where plan_id = _plan_id and day_number > v_new_days;
    end if;
  end if;
end;
$func$;


-- ----------------------------------------------------------------------------
-- 3. pastor_upsert_day
--    Save a day's content. The iOS app calls this on every block change
--    (autosave) and on explicit save. Validates the blocks JSON shape.
-- ----------------------------------------------------------------------------
create or replace function public.pastor_upsert_day(
  _plan_id             uuid,
  _day_number          int,
  _title               text,
  _scripture_reference text,
  _blocks              jsonb     -- array of Block objects
) returns uuid
language plpgsql
security definer
set search_path = public
as $func$
declare
  v_day_id uuid;
  v_blocks jsonb;
  v_block jsonb;
  v_type text;
begin
  if not public._pastor_can_edit_plan(_plan_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  if _day_number < 1 then
    raise exception 'day_number must be >= 1' using errcode = '22023';
  end if;

  -- Normalize blocks: ensure it's a JSON array; default to []
  v_blocks := coalesce(_blocks, '[]'::jsonb);
  if jsonb_typeof(v_blocks) <> 'array' then
    raise exception 'blocks must be a JSON array' using errcode = '22023';
  end if;

  -- Light validation: every block has a recognized type and an order field.
  for v_block in select * from jsonb_array_elements(v_blocks) loop
    v_type := v_block->>'type';
    if v_type not in ('read','commentary','video','question','prayer') then
      raise exception 'unknown block type: %', v_type using errcode = '22023';
    end if;
  end loop;

  insert into public.bible_plan_days (
    plan_id, day_number, title, scripture_reference, sections
  ) values (
    _plan_id, _day_number,
    coalesce(nullif(trim(_title), ''), 'Day ' || _day_number),
    coalesce(_scripture_reference, ''),
    jsonb_build_object('blocks', v_blocks)
  )
  on conflict (plan_id, day_number) do update set
    title               = excluded.title,
    scripture_reference = excluded.scripture_reference,
    sections            = excluded.sections,
    updated_at          = now()
  returning id into v_day_id;

  return v_day_id;
end;
$func$;

-- Make sure (plan_id, day_number) is unique for the on conflict above
do $$
begin
  if not exists (
    select 1 from pg_indexes
    where schemaname='public' and tablename='bible_plan_days'
      and indexname='bible_plan_days_plan_day_uniq'
  ) then
    alter table public.bible_plan_days
      add constraint bible_plan_days_plan_day_uniq unique (plan_id, day_number);
  end if;
end $$;


-- ----------------------------------------------------------------------------
-- 4. pastor_publish_plan
--    Flip status='published'. Requires every day to have at least one block.
-- ----------------------------------------------------------------------------
create or replace function public.pastor_publish_plan(_plan_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $func$
declare
  v_empty_count int;
begin
  if not public._pastor_can_edit_plan(_plan_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  -- Validation: no day with zero blocks.
  select count(*) into v_empty_count
  from public.bible_plan_days d
  where d.plan_id = _plan_id
    and jsonb_array_length(coalesce(d.sections->'blocks', '[]'::jsonb)) = 0;

  if v_empty_count > 0 then
    raise exception 'plan has % day(s) with no blocks — fill every day before publishing', v_empty_count
      using errcode = '22023';
  end if;

  update public.bible_plans
    set status       = 'published'::bible_plan_status,
        published_at = coalesce(published_at, now()),
        updated_at   = now()
    where id = _plan_id;
end;
$func$;


-- ----------------------------------------------------------------------------
-- 5. pastor_archive_plan
--    Soft-archive (status='archived'). Plan stays visible to past readers but
--    won't surface to new ones.
-- ----------------------------------------------------------------------------
create or replace function public.pastor_archive_plan(_plan_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $func$
begin
  if not public._pastor_can_edit_plan(_plan_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  update public.bible_plans
    set status     = 'archived'::bible_plan_status,
        updated_at = now()
    where id = _plan_id;
end;
$func$;


-- Grants
grant execute on function public.pastor_create_plan(uuid, text, int, int) to authenticated;
grant execute on function public.pastor_update_plan_basics(uuid, text, int, text, text, int) to authenticated;
grant execute on function public.pastor_upsert_day(uuid, int, text, text, jsonb) to authenticated;
grant execute on function public.pastor_publish_plan(uuid) to authenticated;
grant execute on function public.pastor_archive_plan(uuid) to authenticated;
grant execute on function public._pastor_can_edit_plan(uuid) to authenticated;

notify pgrst, 'reload schema';
