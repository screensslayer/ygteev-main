
-- =============================================================================
-- Helper RPCs for the pastor "All Bible plans" screen:
--   1. pastor_list_my_plans()  — returns all plans across the pastor's groups,
--      drafts + published, with summary stats so the list can render counts.
--   2. pastor_delete_plan(uuid) — hard-delete a plan (and its days) the pastor
--      authored / is pastor for. Cleans up abandoned drafts.
-- =============================================================================

create or replace function public.pastor_list_my_plans()
returns table (
  plan_id          uuid,
  title            text,
  status           bible_plan_status,
  days_total       int,
  ready_day_count  int,
  total_blocks     int,
  xp_reward        int,
  water_reward     int,
  gradient_index   int,
  header_kind      text,
  header_image_url text,
  group_id         uuid,
  group_name       text,
  created_at       timestamptz,
  updated_at       timestamptz,
  published_at     timestamptz
)
language sql
stable
security definer
set search_path = public
as $func$
  with my_groups as (
    select ygm.group_id
    from public.youth_group_members ygm
    where ygm.user_id = auth.uid()
      and ygm.role = 'pastor'
  ),
  per_day as (
    select
      d.plan_id,
      count(*)::int as days_with_blocks,
      sum(jsonb_array_length(coalesce(d.sections->'blocks','[]'::jsonb)))::int as blocks
    from public.bible_plan_days d
    where d.plan_id in (
      select bp.id from public.bible_plans bp
        where bp.scope = 'group' and bp.group_id in (select group_id from my_groups)
    )
      and jsonb_array_length(coalesce(d.sections->'blocks','[]'::jsonb)) > 0
    group by d.plan_id
  )
  select
    bp.id              as plan_id,
    bp.title,
    bp.status,
    bp.days_total,
    coalesce(pd.days_with_blocks, 0) as ready_day_count,
    coalesce(pd.blocks, 0)            as total_blocks,
    bp.xp_reward,
    bp.water_reward,
    bp.gradient_index,
    bp.header_kind,
    bp.header_image_url,
    bp.group_id,
    yg.name            as group_name,
    bp.created_at,
    bp.updated_at,
    bp.published_at
  from public.bible_plans bp
  join public.youth_groups yg on yg.id = bp.group_id
  left join per_day pd on pd.plan_id = bp.id
  where bp.scope = 'group'
    and bp.group_id in (select group_id from my_groups)
  order by
    case bp.status when 'draft' then 0 when 'published' then 1 when 'archived' then 2 end,
    bp.updated_at desc;
$func$;


create or replace function public.pastor_delete_plan(_plan_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $func$
begin
  if not public._pastor_can_edit_plan(_plan_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  -- Days cascade only if FK has on delete cascade; play it safe and clear them.
  delete from public.bible_plan_days where plan_id = _plan_id;
  delete from public.bible_plans where id = _plan_id;
end;
$func$;


grant execute on function public.pastor_list_my_plans()       to authenticated;
grant execute on function public.pastor_delete_plan(uuid)     to authenticated;

notify pgrst, 'reload schema';
