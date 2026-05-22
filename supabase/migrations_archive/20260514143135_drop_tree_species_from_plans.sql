
-- =============================================================================
-- Drop the tree-species concept from Bible plans entirely.
--
-- Order:
--   1. Rewrite complete_plan_step to stop reading/writing tree_species.
--   2. Rewrite pastor_create_plan to stop setting tree_species.
--   3. Drop bible_plan_completions.awarded_tree_species.
--   4. Drop bible_plans.tree_species.
--
-- iOS impact: the JSON returned by complete_plan_step no longer contains
-- the `tree_planted` key. The Swift CompletePlanResult model needs that
-- field removed (or made optional then ignored).
-- =============================================================================

-- 1. complete_plan_step (rewrite without tree_species) -----------------------
create or replace function public.complete_plan_step(
  _plan_id uuid,
  _day_id uuid,
  _step bible_plan_step,
  _answers jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  _uid uuid := auth.uid();
  _plan public.bible_plans;
  _day  public.bible_plan_days;
  _profile public.profiles;

  _step_xp int := 0;
  _step_water int := 0;
  _step_payload jsonb := _answers;
  _existing public.bible_plan_step_progress;

  _steps_done int;
  _is_day_now_complete boolean := false;
  _today date := current_date;
  _new_streak int;
  _new_run_id uuid;
  _milestone_xp int := 0;
  _milestone_water int := 0;
  _milestone_hit int := null;

  _all_days_done int;
  _plan_completed boolean := false;
  _daily_bonus_xp int := 100;
  _daily_bonus_water int := 5;
  _total_xp int := 0;
  _total_water int := 0;

  _correct_count int := 0;
  _parts jsonb;
  _i int;
  _ans int;
  _study_correct int;
begin
  if _uid is null then raise exception 'not_authenticated'; end if;

  select * into _plan from public.bible_plans where id = _plan_id;
  if _plan.id is null then raise exception 'plan_not_found'; end if;

  select * into _day from public.bible_plan_days where id = _day_id;
  if _day.id is null or _day.plan_id <> _plan_id then
    raise exception 'day_not_in_plan';
  end if;

  if not public.can_user_start_plan(_uid, _plan_id) then
    raise exception 'plan_locked';
  end if;

  select * into _existing from public.bible_plan_step_progress
   where user_id = _uid and day_id = _day_id and step = _step;
  if _existing.id is not null then
    return jsonb_build_object(
      'already_completed', true,
      'step', _step,
      'xp_earned', _existing.xp_earned,
      'water_earned', _existing.water_earned,
      'payload', _existing.payload
    );
  end if;

  if _step = 'read' then
    _parts := _day.sections->'read'->'parts';
    if _parts is not null and jsonb_array_length(_parts) = 3 then
      for _i in 0..2 loop
        _ans := nullif((_answers->'part_answers'->>_i), '')::int;
        if _ans is not null
           and (_parts->_i->>'correct_index') is not null
           and _ans = (_parts->_i->>'correct_index')::int then
          _correct_count := _correct_count + 1;
        end if;
      end loop;
    end if;
    _step_xp := _correct_count * 10;
    _step_payload := jsonb_build_object(
      'part_answers',  coalesce(_answers->'part_answers', '[]'::jsonb),
      'correct_count', _correct_count
    );

  elsif _step = 'study' then
    _ans := nullif((_answers->>'answer'), '')::int;
    _study_correct := nullif((_day.sections->'study'->>'correct_index'), '')::int;
    if _ans is not null and _study_correct is not null and _ans = _study_correct then
      _step_xp := 10;
      _step_payload := jsonb_build_object('answer', _ans, 'correct', true);
    else
      _step_payload := jsonb_build_object('answer', _ans, 'correct', false);
    end if;

  elsif _step = 'memorize' then
    if coalesce((_answers->>'passed')::boolean, false) then
      _step_xp := 20;
    end if;
    _step_payload := _answers;

  else
    _step_xp := 0;
    _step_payload := _answers;
  end if;

  insert into public.bible_plan_step_progress
    (user_id, plan_id, day_id, step, payload, xp_earned, water_earned)
  values
    (_uid, _plan_id, _day_id, _step, _step_payload, _step_xp, _step_water);

  select count(distinct step) into _steps_done
    from public.bible_plan_step_progress
   where user_id = _uid and day_id = _day_id;

  _is_day_now_complete := (_steps_done = 6);

  _total_xp := _step_xp;
  _total_water := _step_water;

  if _is_day_now_complete and not exists (
    select 1 from public.bible_plan_day_progress
    where user_id = _uid and day_id = _day_id
  ) then
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
    values (
      _uid, _plan_id, _day_id,
      (select coalesce(sum(xp_earned),0)
         from public.bible_plan_step_progress
         where user_id = _uid and day_id = _day_id),
      (select coalesce(sum(water_earned),0)
         from public.bible_plan_step_progress
         where user_id = _uid and day_id = _day_id)
    );

    _total_xp    := _total_xp    + _daily_bonus_xp    + _milestone_xp;
    _total_water := _total_water + _daily_bonus_water + _milestone_water;

    select count(*) into _all_days_done
      from public.bible_plan_day_progress
     where user_id = _uid and plan_id = _plan_id;

    if _all_days_done = _plan.days_total then
      begin
        -- NB: no more tree_species — completion is just the row + reward.
        insert into public.bible_plan_completions (user_id, plan_id)
        values (_uid, _plan_id);
        _plan_completed := true;
        _total_xp    := _total_xp    + _plan.xp_reward;
        _total_water := _total_water + _plan.water_reward;
      exception when unique_violation then null;
      end;
    end if;

    update public.profiles
       set xp                    = xp + _total_xp,
           water                 = water + _total_water,
           streak                = _new_streak,
           last_streak_date      = _today,
           current_streak_run_id = _new_run_id,
           updated_at            = now()
     where id = _uid;
  else
    update public.profiles
       set xp = xp + _step_xp,
           water = water + _step_water,
           updated_at = now()
     where id = _uid;
  end if;

  return jsonb_build_object(
    'already_completed',    false,
    'step',                 _step,
    'step_xp',              _step_xp,
    'step_water',           _step_water,
    'steps_done',           _steps_done,
    'day_now_complete',     _is_day_now_complete,
    'daily_bonus_xp',       case when _is_day_now_complete then _daily_bonus_xp else 0 end,
    'daily_bonus_water',    case when _is_day_now_complete then _daily_bonus_water else 0 end,
    'milestone_hit',        _milestone_hit,
    'milestone_xp',         _milestone_xp,
    'milestone_water',      _milestone_water,
    'plan_completed',       _plan_completed,
    'plan_completion_xp',   case when _plan_completed then _plan.xp_reward else 0 end,
    'plan_completion_water',case when _plan_completed then _plan.water_reward else 0 end,
    'new_streak',           case when _is_day_now_complete then _new_streak else null end,
    'total_xp_awarded',     _total_xp,
    'total_water_awarded',  _total_water
  );
end $function$;


-- 2. pastor_create_plan (rewrite without tree_species) -----------------------
create or replace function public.pastor_create_plan(
  _group_id uuid,
  _title text,
  _days_total int,
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
    _days_total,
    greatest(0, least(4, _gradient_index)),
    'gradient',
    v_caller
  )
  returning id into v_plan_id;

  for i in 1 .. _days_total loop
    insert into public.bible_plan_days (plan_id, day_number, title, scripture_reference, sections)
    values (v_plan_id, i, 'Day ' || i, '', jsonb_build_object('blocks', '[]'::jsonb));
  end loop;

  return v_plan_id;
end;
$func$;


-- 3. Drop the columns --------------------------------------------------------
alter table public.bible_plan_completions
  drop column if exists awarded_tree_species;

alter table public.bible_plans
  drop column if exists tree_species;

notify pgrst, 'reload schema';
