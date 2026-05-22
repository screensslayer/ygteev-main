
-- =============================================================================
-- Member-side flow for pastor-authored plans.
--   1. get_my_youth_group_plans(_filter) — Available / Completed / All
--   2. get_my_plan_day_progress(_plan_id) — per-day status for the in-row expand
--   3. complete_pastor_plan_day(_plan_id, _day_number, _answers)
--        Awards: 500 XP + (correct_count * 50 XP)
--                + 4 water per day
--                + 100 XP / 5 water daily bonus
--                + plan-completion bonus on last day
--                + streak milestones (same table as old plans)
--        Server-authoritative scoring: client sends selected_index for each
--        question block, server compares to stored correct_index.
-- =============================================================================

-- 1. List pastor plans visible to the caller, with completion stats ----------
create or replace function public.get_my_youth_group_plans(
  _filter text default 'available'  -- 'available' | 'completed' | 'all'
)
returns table (
  plan_id          uuid,
  title            text,
  group_id         uuid,
  group_name       text,
  days_total       int,
  days_completed   int,
  is_completed     boolean,
  completed_at     timestamptz,
  gradient_index   int,
  header_kind      text,
  header_image_url text,
  xp_reward        int,
  water_reward     int,
  visibility       bible_plan_visibility,
  published_at     timestamptz
)
language sql
stable
security definer
set search_path = public
as $func$
  with my_groups as (
    select group_id from public.youth_group_members
    where user_id = auth.uid()
  ),
  my_plans as (
    select bp.*
    from public.bible_plans bp
    where bp.scope = 'group'
      and bp.status = 'published'
      and (
        bp.visibility = 'public'
        or bp.group_id in (select group_id from my_groups)
      )
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
    mp.id              as plan_id,
    mp.title,
    mp.group_id,
    yg.name            as group_name,
    mp.days_total,
    coalesce(pud.days_done, 0) as days_completed,
    (puc.completed_at is not null) as is_completed,
    puc.completed_at,
    mp.gradient_index,
    mp.header_kind,
    mp.header_image_url,
    mp.xp_reward,
    mp.water_reward,
    mp.visibility,
    mp.published_at
  from my_plans mp
  join public.youth_groups yg on yg.id = mp.group_id
  left join per_user_days       pud on pud.plan_id = mp.id
  left join per_user_completion puc on puc.plan_id = mp.id
  where _filter = 'all'
     or (_filter = 'completed' and puc.completed_at is not null)
     or (_filter = 'available' and puc.completed_at is null)
  order by
    (puc.completed_at is null) desc,        -- in-progress first within bucket
    coalesce(mp.published_at, mp.created_at) desc;
$func$;
grant execute on function public.get_my_youth_group_plans(text) to authenticated;


-- 2. Day-by-day status for a single plan (powers the row-expand) -------------
create or replace function public.get_my_plan_day_progress(_plan_id uuid)
returns table (
  day_id              uuid,
  day_number          int,
  title               text,
  scripture_reference text,
  block_count         int,
  is_completed        boolean,
  completed_at        timestamptz,
  step_xp_earned      int,
  step_water_earned   int
)
language sql
stable
security definer
set search_path = public
as $func$
  select
    d.id           as day_id,
    d.day_number,
    d.title,
    d.scripture_reference,
    jsonb_array_length(coalesce(d.sections->'blocks', '[]'::jsonb))::int as block_count,
    (dp.id is not null) as is_completed,
    dp.completed_at,
    coalesce(dp.step_xp_earned, 0)    as step_xp_earned,
    coalesce(dp.step_water_earned, 0) as step_water_earned
  from public.bible_plan_days d
  left join public.bible_plan_day_progress dp
    on dp.day_id = d.id and dp.user_id = auth.uid()
  where d.plan_id = _plan_id
  order by d.day_number;
$func$;
grant execute on function public.get_my_plan_day_progress(uuid) to authenticated;


-- 3. Complete a pastor plan day ---------------------------------------------
-- Scoring rule (locked):
--   day_xp     = 500 + (correct_count * 50)
--   day_water  = 4
-- Plus daily bonus / streak / completion bonus same as old plans.
create or replace function public.complete_pastor_plan_day(
  _plan_id     uuid,
  _day_number  int,
  _answers     jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $func$
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
begin
  if _uid is null then raise exception 'not_authenticated'; end if;

  select * into _plan from public.bible_plans where id = _plan_id;
  if _plan.id is null then raise exception 'plan_not_found'; end if;
  if _plan.status <> 'published' then raise exception 'plan_not_published'; end if;

  -- Membership / visibility gate
  if _plan.scope = 'group'
     and _plan.visibility = 'private'
     and not exists (
       select 1 from public.youth_group_members
       where group_id = _plan.group_id and user_id = _uid
     )
  then
    raise exception 'not_in_group';
  end if;

  select * into _day from public.bible_plan_days
    where plan_id = _plan_id and day_number = _day_number;
  if _day.id is null then raise exception 'day_not_found'; end if;

  -- Idempotent: if day already completed, return what was earned originally.
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

  -- Count correct question answers
  for _block in select * from jsonb_array_elements(coalesce(_day.sections->'blocks','[]'::jsonb))
  loop
    if _block->>'type' = 'question' then
      _correct_idx := nullif(_block->>'correct_index', '')::int;
      -- find caller's answer for this block by matching block_id
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

  -- Lock profile & update streak
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

  -- Persist day progress
  insert into public.bible_plan_day_progress
    (user_id, plan_id, day_id, step_xp_earned, step_water_earned)
  values (_uid, _plan_id, _day.id, _day_xp, _day_water);

  _total_xp    := _day_xp    + _daily_bonus_xp    + _milestone_xp;
  _total_water := _day_water + _daily_bonus_water + _milestone_water;

  -- Plan completion?
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

  -- Apply to profile
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
    'total_xp_awarded',      _total_xp,
    'total_water_awarded',   _total_water
  );
end;
$func$;
grant execute on function public.complete_pastor_plan_day(uuid, int, jsonb) to authenticated;


-- 4. Tiny helper iOS can use to know whether to show "Join A Group" CTA -----
create or replace function public.am_i_in_any_youth_group()
returns boolean
language sql stable security definer set search_path = public as $func$
  select exists (
    select 1 from public.youth_group_members ygm
    join public.youth_groups yg on yg.id = ygm.group_id
    where ygm.user_id = auth.uid()
      and yg.is_default_ygteev = false   -- real church membership only
  );
$func$;
grant execute on function public.am_i_in_any_youth_group() to authenticated;

notify pgrst, 'reload schema';
