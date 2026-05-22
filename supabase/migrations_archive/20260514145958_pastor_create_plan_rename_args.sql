
-- Rename pastor_create_plan args to match what the iOS client sends:
--   _days_total    → _days
--   _gradient_index → _gradient_idx
-- Postgres can't rename function arguments in place; we drop + recreate.

drop function if exists public.pastor_create_plan(uuid, text, int, int);

create or replace function public.pastor_create_plan(
  _group_id     uuid,
  _title        text,
  _days         int,
  _gradient_idx int default 0
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

  if _days < 1 or _days > 30 then
    raise exception 'days must be between 1 and 30' using errcode = '22023';
  end if;

  v_slug := regexp_replace(lower(coalesce(_title, 'plan')), '[^a-z0-9]+', '-', 'g');
  v_slug := trim(both '-' from v_slug);
  if v_slug = '' then v_slug := 'plan'; end if;
  v_slug := v_slug || '-' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 6);

  insert into public.bible_plans (
    title, slug, category, scope, group_id, status, days_total,
    gradient_index, header_kind, created_by
  ) values (
    coalesce(nullif(trim(_title), ''), 'Untitled plan'),
    v_slug,
    'group_plan'::bible_plan_category,
    'group'::bible_plan_scope,
    _group_id,
    'draft'::bible_plan_status,
    _days,
    greatest(0, least(4, _gradient_idx)),
    'gradient',
    v_caller
  )
  returning id into v_plan_id;

  for i in 1 .. _days loop
    insert into public.bible_plan_days (plan_id, day_number, title, scripture_reference, sections)
    values (v_plan_id, i, 'Day ' || i, '', jsonb_build_object('blocks', '[]'::jsonb));
  end loop;

  return v_plan_id;
end;
$func$;

grant execute on function public.pastor_create_plan(uuid, text, int, int) to authenticated;

notify pgrst, 'reload schema';
