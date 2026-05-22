
-- =============================================================================
-- Pastor plans: visibility (public vs private) + adoption stats
--
--   - visibility = 'private' (default): published plan visible only to members
--     of the plan's youth group + the group's pastors + site admin.
--   - visibility = 'public': published plan visible to every authenticated user.
--
--   Note: scope='global' plans (admin-curated YGTeeV plans) are always visible
--   to everyone when published, regardless of `visibility`. The new column
--   only changes behavior for scope='group' (pastor-authored) plans.
-- =============================================================================

-- 1. New enum + column
do $$
begin
  if not exists (select 1 from pg_type where typname='bible_plan_visibility') then
    create type public.bible_plan_visibility as enum ('private', 'public');
  end if;
end $$;

alter table public.bible_plans
  add column if not exists visibility public.bible_plan_visibility not null default 'private';


-- 2. Rewrite SELECT RLS on bible_plans to honor visibility
drop policy if exists "bp: read" on public.bible_plans;

create policy "bp: read" on public.bible_plans
for select using (
  public.is_site_admin(auth.uid())
  -- pastors see every plan for their groups, drafts included
  or (scope = 'group'::bible_plan_scope and public.is_group_pastor(auth.uid(), group_id))
  -- published plans visible per rules:
  or (
    status = 'published'::bible_plan_status
    and (
      scope = 'global'::bible_plan_scope                       -- admin/global plans
      or visibility = 'public'::public.bible_plan_visibility   -- pastor opt-in public
      or (
        -- private group plans → only members of that group
        scope = 'group'::bible_plan_scope
        and exists (
          select 1 from public.youth_group_members ygm
          where ygm.group_id = bible_plans.group_id
            and ygm.user_id = auth.uid()
        )
      )
    )
  )
);


-- 3. Rewrite SELECT RLS on bible_plan_days the same way
drop policy if exists "bpd: read" on public.bible_plan_days;

create policy "bpd: read" on public.bible_plan_days
for select using (
  public.is_site_admin(auth.uid())
  or exists (
    select 1 from public.bible_plans p
    where p.id = bible_plan_days.plan_id
      and (
        (p.scope = 'group'::bible_plan_scope and public.is_group_pastor(auth.uid(), p.group_id))
        or (
          p.status = 'published'::bible_plan_status
          and (
            p.scope = 'global'::bible_plan_scope
            or p.visibility = 'public'::public.bible_plan_visibility
            or (
              p.scope = 'group'::bible_plan_scope
              and exists (
                select 1 from public.youth_group_members ygm
                where ygm.group_id = p.group_id
                  and ygm.user_id = auth.uid()
              )
            )
          )
        )
      )
  )
);


-- 4. pastor_create_plan: accept _visibility (default private)
create or replace function public.pastor_create_plan(
  _group_id     uuid,
  _title        text,
  _days         int,
  _gradient_idx int default 0,
  _visibility   text default 'private'
) returns uuid
language plpgsql
security definer
set search_path = public
as $func$
declare
  v_caller uuid := auth.uid();
  v_plan_id uuid;
  v_slug text;
  v_vis public.bible_plan_visibility;
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

  v_vis := case lower(coalesce(_visibility, 'private'))
             when 'public' then 'public'::public.bible_plan_visibility
             else 'private'::public.bible_plan_visibility
           end;

  v_slug := regexp_replace(lower(coalesce(_title, 'plan')), '[^a-z0-9]+', '-', 'g');
  v_slug := trim(both '-' from v_slug);
  if v_slug = '' then v_slug := 'plan'; end if;
  v_slug := v_slug || '-' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 6);

  insert into public.bible_plans (
    title, slug, category, scope, group_id, status, days_total,
    gradient_index, header_kind, visibility, created_by
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
    v_vis,
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

grant execute on function public.pastor_create_plan(uuid, text, int, int, text) to authenticated;


-- 5. pastor_update_plan_basics: accept _visibility + _group_id (transfer ownership)
drop function if exists public.pastor_update_plan_basics(uuid, text, int, text, text, int);

create or replace function public.pastor_update_plan_basics(
  _plan_id          uuid,
  _title            text default null,
  _days             int  default null,
  _header_kind      text default null,
  _header_image_url text default null,
  _gradient_idx     int  default null,
  _visibility       text default null,
  _group_id         uuid default null
) returns void
language plpgsql
security definer
set search_path = public
as $func$
declare
  v_current_days int;
  v_new_days int;
  v_vis public.bible_plan_visibility;
  i int;
begin
  if not public._pastor_can_edit_plan(_plan_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  -- If pastor is moving the plan to a different group, validate they're
  -- a pastor of the target group too.
  if _group_id is not null and not (
       public.is_site_admin(auth.uid())
       or public.is_group_pastor(auth.uid(), _group_id)
     ) then
    raise exception 'forbidden: cannot move plan into a group you do not pastor'
      using errcode = '42501';
  end if;

  if _visibility is not null then
    v_vis := case lower(_visibility)
               when 'public' then 'public'::public.bible_plan_visibility
               else 'private'::public.bible_plan_visibility
             end;
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
                         when _gradient_idx is null then gradient_index
                         else greatest(0, least(4, _gradient_idx))
                       end,
    days_total       = case
                         when _days is null then days_total
                         else greatest(1, least(30, _days))
                       end,
    visibility       = coalesce(v_vis, visibility),
    group_id         = coalesce(_group_id, group_id),
    updated_at       = now()
  where id = _plan_id;

  if _days is not null then
    v_new_days := greatest(1, least(30, _days));
    if v_new_days > v_current_days then
      for i in (v_current_days + 1) .. v_new_days loop
        insert into public.bible_plan_days (plan_id, day_number, title, scripture_reference, sections)
        values (_plan_id, i, 'Day ' || i, '', jsonb_build_object('blocks', '[]'::jsonb))
        on conflict do nothing;
      end loop;
    elsif v_new_days < v_current_days then
      delete from public.bible_plan_days
        where plan_id = _plan_id and day_number > v_new_days;
    end if;
  end if;
end;
$func$;

grant execute on function public.pastor_update_plan_basics(uuid, text, int, text, text, int, text, uuid) to authenticated;


-- 6. pastor_list_my_plans: add visibility + started/completed stats
drop function if exists public.pastor_list_my_plans();

create or replace function public.pastor_list_my_plans()
returns table (
  plan_id          uuid,
  title            text,
  status           bible_plan_status,
  visibility       bible_plan_visibility,
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
  started_count    int,
  completed_count  int,
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
      count(*) filter (
        where jsonb_array_length(coalesce(d.sections->'blocks','[]'::jsonb)) > 0
      )::int as days_with_blocks,
      sum(jsonb_array_length(coalesce(d.sections->'blocks','[]'::jsonb)))::int as blocks
    from public.bible_plan_days d
    group by d.plan_id
  ),
  per_starts as (
    select plan_id, count(distinct user_id)::int as started_count
    from public.bible_plan_step_progress
    group by plan_id
  ),
  per_completions as (
    select plan_id, count(*)::int as completed_count
    from public.bible_plan_completions
    group by plan_id
  )
  select
    bp.id              as plan_id,
    bp.title,
    bp.status,
    bp.visibility,
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
    coalesce(ps.started_count, 0)    as started_count,
    coalesce(pc.completed_count, 0)  as completed_count,
    bp.created_at,
    bp.updated_at,
    bp.published_at
  from public.bible_plans bp
  join public.youth_groups yg on yg.id = bp.group_id
  left join per_day         pd on pd.plan_id = bp.id
  left join per_starts      ps on ps.plan_id = bp.id
  left join per_completions pc on pc.plan_id = bp.id
  where bp.scope = 'group'
    and bp.group_id in (select group_id from my_groups)
  order by
    case bp.status when 'draft' then 0 when 'published' then 1 when 'archived' then 2 end,
    bp.updated_at desc;
$func$;

grant execute on function public.pastor_list_my_plans() to authenticated;


-- 7. Helper: pastor_my_groups() — returns the youth groups the caller pastors,
--    for the iOS group-picker UI.
create or replace function public.pastor_my_groups()
returns table (group_id uuid, name text, member_count int)
language sql
stable
security definer
set search_path = public
as $func$
  select
    yg.id   as group_id,
    yg.name,
    (select count(*)::int from public.youth_group_members ygm
       where ygm.group_id = yg.id) as member_count
  from public.youth_groups yg
  join public.youth_group_members me on me.group_id = yg.id
  where me.user_id = auth.uid()
    and me.role = 'pastor'
  order by yg.name;
$func$;

grant execute on function public.pastor_my_groups() to authenticated;

notify pgrst, 'reload schema';
