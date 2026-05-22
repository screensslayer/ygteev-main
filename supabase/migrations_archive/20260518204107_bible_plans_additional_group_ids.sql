-- Multi-group Bible plan assignment.
-- A plan keeps a single `group_id` (the "primary" group) and gains an
-- `additional_group_ids` array for any extra groups the pastor wants
-- the same plan visible/startable/completable in. Edits propagate
-- (single row) and stats / completion are unified.
-- Each RPC that gated on group_id now also accepts any group in the
-- array.

alter table public.bible_plans
  add column if not exists additional_group_ids uuid[] not null default '{}'::uuid[];

alter table public.bible_plans
  drop constraint if exists bible_plans_additional_excludes_primary;
alter table public.bible_plans
  add  constraint bible_plans_additional_excludes_primary
  check (group_id is null or not (group_id = any(additional_group_ids)));

-- ---------------------------------------------------------------------------
-- _pastor_can_edit_plan: pastor of primary OR any additional
-- ---------------------------------------------------------------------------
create or replace function public._pastor_can_edit_plan(_plan_id uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select
    public.is_site_admin(auth.uid())
    or exists (
      select 1 from public.bible_plans p
      where p.id = _plan_id and p.scope = 'group'
        and (
          public.is_group_pastor(auth.uid(), p.group_id)
          or exists (
            select 1 from unnest(coalesce(p.additional_group_ids, '{}'::uuid[])) g
            where public.is_group_pastor(auth.uid(), g)
          )
        )
    );
$$;

-- ---------------------------------------------------------------------------
-- can_user_start_plan: caller is member of primary OR any additional
-- ---------------------------------------------------------------------------
create or replace function public.can_user_start_plan(_user_id uuid, _plan_id uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select
    public.is_site_admin(_user_id)
    or exists (
      select 1 from public.bible_plans p
      where p.id = _plan_id
        and p.status = 'published'
        and (
          (p.scope = 'group' and (
              public.is_group_member(_user_id, p.group_id)
              or exists (
                select 1 from unnest(coalesce(p.additional_group_ids, '{}'::uuid[])) g
                where public.is_group_member(_user_id, g)
              )
          ))
          or (p.scope = 'global' and (p.is_free_entry or public.is_pro(_user_id)))
        )
    );
$$;

-- ---------------------------------------------------------------------------
-- get_my_youth_group_plans: surface a plan for every group of mine it's
-- assigned to. Same plan_id can appear under multiple group_name labels
-- so the UI can show it under each group's "Plans" section.
-- ---------------------------------------------------------------------------
drop function if exists public.get_my_youth_group_plans(text);
create or replace function public.get_my_youth_group_plans(_filter text default 'available')
returns table(
  plan_id uuid, title text, group_id uuid, group_name text,
  days_total integer, days_completed integer,
  is_completed boolean, completed_at timestamptz,
  gradient_index integer, header_kind text, header_image_url text,
  xp_reward integer, water_reward integer,
  visibility bible_plan_visibility, published_at timestamptz
)
language sql stable security definer
set search_path = public
as $$
  with my_groups as (
    select group_id from public.youth_group_members where user_id = auth.uid()
  ),
  plan_groups as (
    -- Flatten primary + additional into one row-per-(plan,group)
    select bp.id as plan_id, bp.group_id
    from public.bible_plans bp
    where bp.scope = 'group' and bp.status = 'published'
    union all
    select bp.id, unnest(bp.additional_group_ids)
    from public.bible_plans bp
    where bp.scope = 'group' and bp.status = 'published'
      and array_length(bp.additional_group_ids, 1) is not null
  ),
  visible_pairs as (
    select pg.plan_id, pg.group_id
    from plan_groups pg
    join public.bible_plans bp on bp.id = pg.plan_id
    where bp.visibility = 'public'
       or pg.group_id in (select group_id from my_groups)
  ),
  per_user_days as (
    select plan_id, count(*)::int as days_done
    from public.bible_plan_day_progress
    where user_id = auth.uid()
    group by plan_id
  ),
  per_user_completion as (
    select plan_id, max(completed_at) as completed_at
    from public.bible_plan_completions
    where user_id = auth.uid()
    group by plan_id
  )
  select
    bp.id              as plan_id,
    bp.title,
    vp.group_id,
    yg.name            as group_name,
    bp.days_total,
    coalesce(pud.days_done, 0) as days_completed,
    (puc.completed_at is not null) as is_completed,
    puc.completed_at,
    bp.gradient_index,
    bp.header_kind,
    bp.header_image_url,
    bp.xp_reward,
    bp.water_reward,
    bp.visibility,
    bp.published_at
  from visible_pairs vp
  join public.bible_plans bp on bp.id = vp.plan_id
  join public.youth_groups yg on yg.id = vp.group_id
  left join per_user_days       pud on pud.plan_id = bp.id
  left join per_user_completion puc on puc.plan_id = bp.id
  where _filter = 'all'
     or (_filter = 'completed' and puc.completed_at is not null)
     or (_filter = 'available' and puc.completed_at is null)
  order by
    (puc.completed_at is null) desc,
    coalesce(bp.published_at, bp.created_at) desc;
$$;

-- ---------------------------------------------------------------------------
-- pastor_list_my_plans: surface plans where pastor owns primary OR any
-- additional group. Each plan appears once; group_name reflects the
-- primary group.
-- ---------------------------------------------------------------------------
drop function if exists public.pastor_list_my_plans();
create or replace function public.pastor_list_my_plans()
returns table(
  plan_id uuid, title text,
  status bible_plan_status, visibility bible_plan_visibility,
  days_total integer, ready_day_count integer, total_blocks integer,
  xp_reward integer, water_reward integer,
  gradient_index integer, header_kind text, header_image_url text,
  group_id uuid, group_name text,
  additional_group_ids uuid[],
  started_count integer, completed_count integer,
  created_at timestamptz, updated_at timestamptz, published_at timestamptz
)
language sql stable security definer
set search_path = public
as $$
  with my_pastor_groups as (
    select group_id
    from public.youth_group_members
    where user_id = auth.uid() and role = 'pastor'
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
    bp.status, bp.visibility,
    bp.days_total,
    coalesce(pd.days_with_blocks, 0) as ready_day_count,
    coalesce(pd.blocks, 0)            as total_blocks,
    bp.xp_reward, bp.water_reward,
    bp.gradient_index, bp.header_kind, bp.header_image_url,
    bp.group_id,
    yg.name            as group_name,
    bp.additional_group_ids,
    coalesce(ps.started_count, 0)    as started_count,
    coalesce(pc.completed_count, 0)  as completed_count,
    bp.created_at, bp.updated_at, bp.published_at
  from public.bible_plans bp
  join public.youth_groups yg on yg.id = bp.group_id
  left join per_day         pd on pd.plan_id = bp.id
  left join per_starts      ps on ps.plan_id = bp.id
  left join per_completions pc on pc.plan_id = bp.id
  where bp.scope = 'group'
    and (
      bp.group_id in (select group_id from my_pastor_groups)
      or exists (
        select 1 from unnest(bp.additional_group_ids) g
        where g in (select group_id from my_pastor_groups)
      )
    )
  order by
    case bp.status when 'draft' then 0 when 'published' then 1 when 'archived' then 2 end,
    bp.updated_at desc;
$$;

-- ---------------------------------------------------------------------------
-- pastor_create_plan: add optional _additional_group_ids param. Caller
-- must pastor every selected group.
-- ---------------------------------------------------------------------------
create or replace function public.pastor_create_plan(
  _group_id uuid,
  _title text,
  _days integer,
  _gradient_idx integer default 0,
  _visibility text default 'private',
  _additional_group_ids uuid[] default null
)
returns uuid
language plpgsql security definer
set search_path = public
as $function$
declare
  v_caller uuid := auth.uid();
  v_plan_id uuid;
  v_slug text;
  v_vis public.bible_plan_visibility;
  v_extras uuid[] := '{}'::uuid[];
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

  -- Sanitize the extras array: dedupe, drop the primary, and require
  -- pastor permission on each.
  if _additional_group_ids is not null then
    v_extras := array(
      select distinct g from unnest(_additional_group_ids) g
      where g is not null and g <> _group_id
    );
    if exists (
      select 1 from unnest(v_extras) g
      where not (public.is_site_admin(v_caller) or public.is_group_pastor(v_caller, g))
    ) then
      raise exception 'forbidden: must be a pastor of every selected group'
        using errcode = '42501';
    end if;
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
    title, slug, category, scope, group_id, additional_group_ids,
    status, days_total,
    gradient_index, header_kind, visibility, created_by
  ) values (
    coalesce(nullif(trim(_title), ''), 'Untitled plan'),
    v_slug,
    'group_plan'::bible_plan_category,
    'group'::bible_plan_scope,
    _group_id,
    v_extras,
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
$function$;

-- ---------------------------------------------------------------------------
-- pastor_update_plan_basics: add optional _additional_group_ids param.
-- NULL = leave unchanged. Pass '{}' to clear. Each value must be a
-- group the caller pastors.
-- ---------------------------------------------------------------------------
create or replace function public.pastor_update_plan_basics(
  _plan_id uuid,
  _title text default null,
  _days integer default null,
  _header_kind text default null,
  _header_image_url text default null,
  _gradient_idx integer default null,
  _visibility text default null,
  _group_id uuid default null,
  _additional_group_ids uuid[] default null
)
returns void
language plpgsql security definer
set search_path = public
as $function$
declare
  v_current_days int;
  v_new_days int;
  v_vis public.bible_plan_visibility;
  v_extras uuid[];
  v_primary uuid;
  i int;
begin
  if not public._pastor_can_edit_plan(_plan_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  -- If pastor is moving the plan to a different primary group, validate
  -- they're a pastor of the target group too.
  if _group_id is not null and not (
       public.is_site_admin(auth.uid())
       or public.is_group_pastor(auth.uid(), _group_id)
     ) then
    raise exception 'forbidden: cannot move plan into a group you do not pastor'
      using errcode = '42501';
  end if;

  -- Determine the effective primary (for sanitizing extras against it).
  select coalesce(_group_id, group_id) into v_primary
  from public.bible_plans where id = _plan_id;

  if _additional_group_ids is not null then
    v_extras := array(
      select distinct g from unnest(_additional_group_ids) g
      where g is not null and g <> v_primary
    );
    if exists (
      select 1 from unnest(v_extras) g
      where not (public.is_site_admin(auth.uid()) or public.is_group_pastor(auth.uid(), g))
    ) then
      raise exception 'forbidden: must be a pastor of every selected group'
        using errcode = '42501';
    end if;
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
    additional_group_ids = coalesce(v_extras, additional_group_ids),
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
$function$;

-- ---------------------------------------------------------------------------
-- complete_pastor_plan_day: update the private-group membership check
-- to also allow members of any additional group. Preserves the recent
-- 2x XP multiplier for paying subscribers.
-- ---------------------------------------------------------------------------
create or replace function public.complete_pastor_plan_day(
  _plan_id uuid, _day_number integer, _answers jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql security definer
set search_path = public
as $function$
declare
  _uid uuid := auth.uid();
  _plan public.bible_plans;
  _day  public.bible_plan_days;
  _profile public.profiles;

  _block jsonb;
  _ans   jsonb;
  _selected int;
  _correct_idx int;
  _correct_count int := 0;

  _day_xp int;
  _day_water int := 4;
  _daily_bonus_xp int := 100;
  _daily_bonus_water int := 5;
  _existing public.bible_plan_day_progress;

  _today date := current_date;
  _new_streak int;
  _new_run_id uuid;
  _milestone_xp int := 0;
  _milestone_water int := 0;
  _milestone_hit int := null;

  _all_days_done int;
  _plan_completed boolean := false;
  _total_xp int := 0;
  _total_water int := 0;

  _xp_multiplier int := 1;
  _xp_base int;
begin
  if _uid is null then raise exception 'not_authenticated'; end if;

  select * into _plan from public.bible_plans where id = _plan_id;
  if _plan.id is null then raise exception 'plan_not_found'; end if;
  if _plan.status <> 'published' then raise exception 'plan_not_published'; end if;

  -- Multi-group membership gate: allow members of the primary group OR
  -- any group listed in additional_group_ids.
  if _plan.scope = 'group'
     and _plan.visibility = 'private'
     and not exists (
       select 1 from public.youth_group_members
       where user_id = _uid
         and (group_id = _plan.group_id
              or group_id = any(coalesce(_plan.additional_group_ids, '{}'::uuid[])))
     )
  then
    raise exception 'not_in_group';
  end if;

  select * into _day from public.bible_plan_days
    where plan_id = _plan_id and day_number = _day_number;
  if _day.id is null then raise exception 'day_not_found'; end if;

  select * into _existing from public.bible_plan_day_progress
    where user_id = _uid and day_id = _day.id;
  if _existing.id is not null then
    return jsonb_build_object(
      'already_completed', true,
      'day_id',         _day.id,
      'day_xp',         _existing.step_xp_earned,
      'day_water',      _existing.step_water_earned
    );
  end if;

  for _block in select * from jsonb_array_elements(coalesce(_day.sections->'blocks','[]'::jsonb))
  loop
    if _block->>'type' = 'question' then
      _correct_idx := nullif(_block->>'correct_index', '')::int;
      select value into _ans
        from jsonb_array_elements(coalesce(_answers, '[]'::jsonb)) as t(value)
       where t.value->>'block_id' = _block->>'id'
       limit 1;
      if _ans is not null and _correct_idx is not null then
        _selected := nullif(_ans->>'selected_index', '')::int;
        if _selected is not null and _selected = _correct_idx then
          _correct_count := _correct_count + 1;
        end if;
      end if;
    end if;
  end loop;

  _day_xp := 500 + (_correct_count * 50);

  select * into _profile from public.profiles where id = _uid for update;

  if _profile.last_streak_date is null or _profile.last_streak_date < _today - interval '1 day' then
    _new_streak := 1;
    _new_run_id := gen_random_uuid();
  elsif _profile.last_streak_date = _today then
    _new_streak := _profile.streak;
    _new_run_id := _profile.current_streak_run_id;
  else
    _new_streak := _profile.streak + 1;
    _new_run_id := coalesce(_profile.current_streak_run_id, gen_random_uuid());
  end if;

  if _new_streak in (3,7,10,15,20,25,30) then
    _milestone_hit := _new_streak;
    case _new_streak
      when 3  then _milestone_xp := 50;   _milestone_water := 10;
      when 7  then _milestone_xp := 200;  _milestone_water := 30;
      when 10 then _milestone_xp := 300;  _milestone_water := 50;
      when 15 then _milestone_xp := 500;  _milestone_water := 75;
      when 20 then _milestone_xp := 750;  _milestone_water := 100;
      when 25 then _milestone_xp := 1000; _milestone_water := 125;
      when 30 then _milestone_xp := 1500; _milestone_water := 200;
    end case;
    begin
      insert into public.user_streak_milestone_grants
        (user_id, run_id, milestone, xp_awarded, water_awarded)
      values (_uid, _new_run_id, _new_streak, _milestone_xp, _milestone_water);
    exception when unique_violation then
      _milestone_xp := 0; _milestone_water := 0; _milestone_hit := null;
    end;
  end if;

  insert into public.bible_plan_day_progress
    (user_id, plan_id, day_id, step_xp_earned, step_water_earned)
  values (_uid, _plan_id, _day.id, _day_xp, _day_water);

  _total_xp    := _day_xp    + _daily_bonus_xp    + _milestone_xp;
  _total_water := _day_water + _daily_bonus_water + _milestone_water;

  select count(*) into _all_days_done
    from public.bible_plan_day_progress
   where user_id = _uid and plan_id = _plan_id;

  if _all_days_done = _plan.days_total then
    begin
      insert into public.bible_plan_completions (user_id, plan_id)
      values (_uid, _plan_id);
      _plan_completed := true;
      _total_xp    := _total_xp    + _plan.xp_reward;
      _total_water := _total_water + _plan.water_reward;
    exception when unique_violation then null;
    end;
  end if;

  _xp_base := _total_xp;
  if public.is_paying_subscriber(_uid) then
    _xp_multiplier := 2;
    _total_xp := _total_xp * _xp_multiplier;
  end if;

  update public.profiles
     set xp                    = xp + _total_xp,
         water                 = water + _total_water,
         streak                = _new_streak,
         last_streak_date      = _today,
         current_streak_run_id = _new_run_id,
         updated_at            = now()
   where id = _uid;

  return jsonb_build_object(
    'already_completed',     false,
    'day_id',                _day.id,
    'day_xp',                _day_xp,
    'day_water',             _day_water,
    'correct_count',         _correct_count,
    'daily_bonus_xp',        _daily_bonus_xp,
    'daily_bonus_water',     _daily_bonus_water,
    'milestone_hit',         _milestone_hit,
    'milestone_xp',          _milestone_xp,
    'milestone_water',       _milestone_water,
    'plan_completed',        _plan_completed,
    'plan_completion_xp',    case when _plan_completed then _plan.xp_reward else 0 end,
    'plan_completion_water', case when _plan_completed then _plan.water_reward else 0 end,
    'new_streak',            _new_streak,
    'xp_multiplier',         _xp_multiplier,
    'xp_base_awarded',       _xp_base,
    'total_xp_awarded',      _total_xp,
    'total_water_awarded',   _total_water
  );
end;
$function$;
