
-- ---------- Step enum ----------
do $$ begin
  create type public.bible_plan_step as enum ('read','study','apply','give','memorize','pray');
exception when duplicate_object then null; end $$;

-- ---------- Step progress table ----------
create table if not exists public.bible_plan_step_progress (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  plan_id       uuid not null references public.bible_plans(id) on delete cascade,
  day_id        uuid not null references public.bible_plan_days(id) on delete cascade,
  step          public.bible_plan_step not null,
  payload       jsonb not null default '{}'::jsonb,
  xp_earned     int  not null default 0,
  water_earned  int  not null default 0,
  completed_at  timestamptz not null default now(),
  unique (user_id, day_id, step)
);
create index if not exists bpsp_user_idx on public.bible_plan_step_progress(user_id);
create index if not exists bpsp_day_idx  on public.bible_plan_step_progress(day_id);
create index if not exists bpsp_user_recent_idx
  on public.bible_plan_step_progress(user_id, completed_at desc);

alter table public.bible_plan_step_progress enable row level security;

drop policy if exists "bpsp: read"             on public.bible_plan_step_progress;
drop policy if exists "bpsp: no client insert" on public.bible_plan_step_progress;
create policy "bpsp: read" on public.bible_plan_step_progress for select using (
  user_id = auth.uid()
  or public.is_site_admin(auth.uid())
  or exists (
    select 1 from public.bible_plans p
    where p.id = plan_id and public.is_group_pastor(auth.uid(), p.group_id)
  )
);
create policy "bpsp: no client insert" on public.bible_plan_step_progress
  for insert with check (false);

-- ---------- Replace the old day-only RPC ----------
drop function if exists public.record_plan_day_completion(uuid, uuid, int, int);

-- ---------- The workhorse: complete_plan_step ----------
create or replace function public.complete_plan_step(
  _plan_id uuid,
  _day_id  uuid,
  _step    public.bible_plan_step,
  _answers jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql security definer set search_path = public as $$
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

  -- Idempotent: if step already completed, return cached result, no double-pay.
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

  -- ============================================================
  -- Server-authoritative scoring per step kind
  -- ============================================================
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
    -- Client trusts the verse-ordering result; pass `passed: true` when user got it right.
    if coalesce((_answers->>'passed')::boolean, false) then
      _step_xp := 20;
    end if;
    _step_payload := _answers;

  else
    -- apply / give / pray — no XP
    _step_xp := 0;
    _step_payload := _answers;
  end if;

  -- ============================================================
  -- Persist this step
  -- ============================================================
  insert into public.bible_plan_step_progress
    (user_id, plan_id, day_id, step, payload, xp_earned, water_earned)
  values
    (_uid, _plan_id, _day_id, _step, _step_payload, _step_xp, _step_water);

  -- ============================================================
  -- Day completion cascade
  -- ============================================================
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
    -- Lock & load the profile
    select * into _profile from public.profiles where id = _uid for update;

    -- Streak update
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

    -- Streak milestone
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

    -- Day progress row (idempotent, but we already checked above)
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

    -- Plan completion
    select count(*) into _all_days_done
      from public.bible_plan_day_progress
     where user_id = _uid and plan_id = _plan_id;

    if _all_days_done = _plan.days_total then
      begin
        insert into public.bible_plan_completions
          (user_id, plan_id, awarded_tree_species)
        values (_uid, _plan_id, _plan.tree_species);
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
    -- Day not yet complete (or already finalized previously). Just apply step XP/water.
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
    'tree_planted',         case when _plan_completed then _plan.tree_species else null end,
    'total_xp_awarded',     _total_xp,
    'total_water_awarded',  _total_water
  );
end $$;

-- ---------- Query RPCs ----------
create or replace function public.get_user_plan_progress(_plan_id uuid)
returns table (
  day_id              uuid,
  day_number          int,
  title               text,
  scripture_reference text,
  reflection          text,
  day_complete        boolean,
  steps_completed     text[],
  day_xp_earned       int,
  day_completed_at    timestamptz
)
language sql stable security definer set search_path = public as $$
  select
    d.id,
    d.day_number,
    d.title,
    d.scripture_reference,
    d.reflection,
    (dp.id is not null) as day_complete,
    coalesce(array_agg(sp.step::text order by sp.completed_at)
             filter (where sp.id is not null), '{}'::text[]) as steps_completed,
    coalesce(sum(sp.xp_earned), 0)::int as day_xp_earned,
    dp.completed_at
  from public.bible_plan_days d
  left join public.bible_plan_day_progress dp
    on dp.user_id = auth.uid() and dp.day_id = d.id
  left join public.bible_plan_step_progress sp
    on sp.user_id = auth.uid() and sp.day_id = d.id
  where d.plan_id = _plan_id
  group by d.id, d.day_number, d.title, d.scripture_reference, d.reflection, dp.id, dp.completed_at
  order by d.day_number;
$$;

create or replace function public.get_continue_card()
returns table (
  plan_id             uuid,
  plan_title          text,
  plan_slug           text,
  plan_gradient_from  text,
  plan_gradient_to    text,
  days_total          int,
  day_id              uuid,
  day_number          int,
  day_title           text,
  scripture_reference text,
  steps_completed     text[],
  is_resume           boolean   -- true = resume mid-day, false = next un-started day
)
language sql stable security definer set search_path = public as $$
  with my_uid as (select auth.uid() as uid),
  in_progress as (
    -- Days the user has touched but not finished. Most recent first.
    select sp.day_id, sp.plan_id, max(sp.completed_at) as last_at
    from public.bible_plan_step_progress sp, my_uid m
    where sp.user_id = m.uid
      and not exists (
        select 1 from public.bible_plan_day_progress dp
        where dp.user_id = m.uid and dp.day_id = sp.day_id
      )
    group by sp.day_id, sp.plan_id
    order by last_at desc
    limit 1
  ),
  last_completed_plan as (
    select dp.plan_id, max(dp.completed_at) as last_at
    from public.bible_plan_day_progress dp, my_uid m
    where dp.user_id = m.uid
    group by dp.plan_id
    order by last_at desc
    limit 1
  ),
  next_day_in_plan as (
    select d.id as day_id, d.plan_id
    from public.bible_plan_days d, my_uid m
    where d.plan_id = (select plan_id from last_completed_plan)
      and not exists (
        select 1 from public.bible_plan_day_progress dp
        where dp.user_id = m.uid and dp.day_id = d.id
      )
      and not exists (select 1 from in_progress)
    order by d.day_number
    limit 1
  ),
  chosen as (
    select day_id, plan_id, true as is_resume from in_progress
    union all
    select day_id, plan_id, false as is_resume from next_day_in_plan
    limit 1
  )
  select
    p.id, p.title, p.slug, p.gradient_from, p.gradient_to, p.days_total,
    d.id, d.day_number, d.title, d.scripture_reference,
    coalesce(
      (select array_agg(sp.step::text order by sp.completed_at)
         from public.bible_plan_step_progress sp, my_uid m
         where sp.user_id = m.uid and sp.day_id = d.id),
      '{}'::text[]
    ),
    c.is_resume
  from chosen c
  join public.bible_plans p     on p.id = c.plan_id
  join public.bible_plan_days d on d.id = c.day_id;
$$;
