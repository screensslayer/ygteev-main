-- Lifetime XP + infinite level system.
-- `xp` is a spendable balance (water-style "currency"); `lifetime_xp` is
-- monotonic and drives the level. Level 1 starts at 0 XP. Curve:
--   xp_for_level(n) = 500 * n * (n - 1)
--   level_for_xp(x) = floor((1 + sqrt(1 + x/125)) / 2)  clamped to >= 1

alter table public.profiles
  add column if not exists lifetime_xp bigint not null default 0;

-- One-time backfill: current xp is effectively lifetime since nothing
-- has ever decremented it. Only touch rows where lifetime_xp is still
-- the zero default so re-running this migration is idempotent.
update public.profiles
   set lifetime_xp = xp
 where lifetime_xp = 0 and xp > 0;

create or replace function public.xp_for_level(_level int)
returns bigint
language sql immutable parallel safe
as $$
  select case when _level < 1 then 0::bigint
              else (500 * _level * (_level - 1))::bigint end;
$$;

create or replace function public.level_for_xp(_xp bigint)
returns int
language sql immutable parallel safe
as $$
  select greatest(
    1,
    floor((1 + sqrt(1 + greatest(_xp, 0)::numeric / 125)) / 2)::int
  );
$$;

grant execute on function public.xp_for_level(int)    to anon, authenticated, service_role;
grant execute on function public.level_for_xp(bigint) to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Patch complete_pastor_plan_day: keep `lifetime_xp` in lockstep with `xp`.
-- Same body as before, with one extra line in the profile UPDATE.
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
         lifetime_xp           = lifetime_xp + _total_xp,
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

-- ---------------------------------------------------------------------------
-- Patch complete_plan_step: same — keep lifetime_xp in sync at both
-- profile-update sites.
-- ---------------------------------------------------------------------------
create or replace function public.complete_plan_step(
  _plan_id uuid, _day_id uuid, _step bible_plan_step, _answers jsonb default '{}'::jsonb
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

  _xp_multiplier int := 1;
  _xp_base int;
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
           lifetime_xp           = lifetime_xp + _total_xp,
           water                 = water + _total_water,
           streak                = _new_streak,
           last_streak_date      = _today,
           current_streak_run_id = _new_run_id,
           updated_at            = now()
     where id = _uid;
  else
    _xp_base := _total_xp;
    if public.is_paying_subscriber(_uid) then
      _xp_multiplier := 2;
      _total_xp := _total_xp * _xp_multiplier;
    end if;

    update public.profiles
       set xp = xp + _total_xp,
           lifetime_xp = lifetime_xp + _total_xp,
           water = water + _total_water,
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
    'xp_multiplier',        _xp_multiplier,
    'xp_base_awarded',      _xp_base,
    'total_xp_awarded',     _total_xp,
    'total_water_awarded',  _total_water
  );
end $function$;
