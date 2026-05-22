
-- =========================================================================
-- 1. Update signup grant: 3000 XP / 27 water (was 0 / 0)
-- =========================================================================
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare default_group_id uuid;
begin
  insert into public.profiles (id, email, display_name, xp, water)
  values (
    new.id, new.email,
    coalesce(new.raw_user_meta_data->>'display_name', new.email),
    3000, 27
  );
  insert into public.user_roles (user_id, role) values (new.id, 'member');

  select id into default_group_id from public.youth_groups where is_default_ygteev = true limit 1;
  if default_group_id is not null then
    insert into public.youth_group_members (group_id, user_id, role)
    values (default_group_id, new.id, 'member') on conflict do nothing;
  end if;
  return new;
end $$;

-- Backfill: any user at 0/0 gets the starter grant.
update public.profiles
   set xp = 3000, water = 27, updated_at = now()
 where xp = 0 and water = 0;

-- =========================================================================
-- 2. Enums + bible_plans / bible_plan_days
-- =========================================================================
do $$ begin
  create type public.bible_plan_category as enum ('book_study','thematic','devotional','group_plan');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.bible_plan_scope as enum ('global','group');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.bible_plan_status as enum ('draft','published','archived');
exception when duplicate_object then null; end $$;

create table if not exists public.bible_plans (
  id                uuid primary key default gen_random_uuid(),
  title             text not null,
  slug              text not null unique,
  description       text,
  category          public.bible_plan_category not null,
  scope             public.bible_plan_scope not null default 'global',
  group_id          uuid references public.youth_groups(id) on delete cascade,
  status            public.bible_plan_status not null default 'draft',
  days_total        int  not null check (days_total >= 1),
  tree_species      text not null,
  gradient_from     text not null default '#6B2BFF',
  gradient_to       text not null default '#FF3DA5',
  recommended_order int,
  is_free_entry     boolean not null default false,
  xp_reward         int not null default 0,
  water_reward      int not null default 0,
  created_by        uuid references auth.users(id) on delete set null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  check ((scope = 'group' and group_id is not null) or (scope = 'global' and group_id is null))
);
create unique index if not exists bible_plans_one_free_entry
  on public.bible_plans(is_free_entry) where is_free_entry = true;
create index if not exists bible_plans_status_idx on public.bible_plans(status);
create index if not exists bible_plans_group_idx on public.bible_plans(group_id);
create index if not exists bible_plans_recommended_idx
  on public.bible_plans(recommended_order) where status = 'published';

alter table public.bible_plans enable row level security;
drop trigger if exists touch_bible_plans on public.bible_plans;
create trigger touch_bible_plans before update on public.bible_plans
  for each row execute function public.touch_updated_at();

create table if not exists public.bible_plan_days (
  id                  uuid primary key default gen_random_uuid(),
  plan_id             uuid not null references public.bible_plans(id) on delete cascade,
  day_number          int not null check (day_number >= 1),
  title               text not null,
  scripture_reference text not null,
  reflection          text,
  sections            jsonb not null default '{}'::jsonb,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  unique (plan_id, day_number)
);
create index if not exists bpd_plan_idx on public.bible_plan_days(plan_id);
alter table public.bible_plan_days enable row level security;
drop trigger if exists touch_bible_plan_days on public.bible_plan_days;
create trigger touch_bible_plan_days before update on public.bible_plan_days
  for each row execute function public.touch_updated_at();

-- =========================================================================
-- 3. Progress & completion logs
-- =========================================================================
create table if not exists public.bible_plan_day_progress (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references auth.users(id) on delete cascade,
  plan_id            uuid not null references public.bible_plans(id) on delete cascade,
  day_id             uuid not null references public.bible_plan_days(id) on delete cascade,
  step_xp_earned     int not null default 0,
  step_water_earned  int not null default 0,
  completed_at       timestamptz not null default now(),
  unique (user_id, day_id)
);
create index if not exists bpdp_user_idx on public.bible_plan_day_progress(user_id);
create index if not exists bpdp_plan_idx on public.bible_plan_day_progress(plan_id);
create index if not exists bpdp_user_completed_idx
  on public.bible_plan_day_progress(user_id, completed_at);
alter table public.bible_plan_day_progress enable row level security;

create table if not exists public.bible_plan_completions (
  id                   uuid primary key default gen_random_uuid(),
  user_id              uuid not null references auth.users(id) on delete cascade,
  plan_id              uuid not null references public.bible_plans(id) on delete cascade,
  completed_at         timestamptz not null default now(),
  awarded_tree_species text,
  unique (user_id, plan_id)
);
create index if not exists bpc_user_idx on public.bible_plan_completions(user_id);
alter table public.bible_plan_completions enable row level security;

-- =========================================================================
-- 4. Streak state (denormalized on profiles + grant log)
-- =========================================================================
alter table public.profiles
  add column if not exists last_streak_date date,
  add column if not exists current_streak_run_id uuid;

create table if not exists public.user_streak_milestone_grants (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  run_id        uuid not null,
  milestone     int  not null check (milestone in (3,7,10,15,20,25,30)),
  xp_awarded    int  not null,
  water_awarded int  not null,
  awarded_at    timestamptz not null default now(),
  unique (user_id, run_id, milestone)
);
create index if not exists usmg_user_idx on public.user_streak_milestone_grants(user_id);
alter table public.user_streak_milestone_grants enable row level security;

-- =========================================================================
-- 5. Helper: free-tier gate
-- =========================================================================
create or replace function public.can_user_start_plan(_user_id uuid, _plan_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select
    public.is_site_admin(_user_id)
    or exists (
      select 1 from public.bible_plans p
      where p.id = _plan_id
        and p.status = 'published'
        and (
          (p.scope = 'group' and public.is_group_member(_user_id, p.group_id))
          or (p.scope = 'global' and (p.is_free_entry or public.is_pro(_user_id)))
        )
    );
$$;

-- =========================================================================
-- 6. The workhorse RPC
-- =========================================================================
create or replace function public.record_plan_day_completion(
  _plan_id uuid,
  _day_id  uuid,
  _step_xp_earned   int default 0,
  _step_water_earned int default 0
)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  _uid uuid := auth.uid();
  _profile public.profiles;
  _plan public.bible_plans;
  _day  public.bible_plan_days;
  _today date := current_date;
  _new_streak int;
  _new_run_id uuid;
  _milestone_xp int := 0;
  _milestone_water int := 0;
  _milestone_hit int := null;
  _all_days_done int;
  _plan_completed boolean := false;
  _daily_bonus_xp    int := 100;
  _daily_bonus_water int := 5;
  _total_xp int;
  _total_water int;
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

  -- Insert progress (idempotent via unique(user_id, day_id))
  begin
    insert into public.bible_plan_day_progress
      (user_id, plan_id, day_id, step_xp_earned, step_water_earned)
    values (_uid, _plan_id, _day_id, _step_xp_earned, _step_water_earned);
  exception when unique_violation then
    return jsonb_build_object('already_completed', true);
  end;

  -- Streak update (lock the profile row)
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

  -- Streak milestone (idempotent per run)
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
      insert into public.user_streak_milestone_grants(user_id, run_id, milestone, xp_awarded, water_awarded)
      values (_uid, _new_run_id, _new_streak, _milestone_xp, _milestone_water);
    exception when unique_violation then
      _milestone_xp := 0; _milestone_water := 0; _milestone_hit := null;
    end;
  end if;

  -- Plan completion check
  select count(*) into _all_days_done
    from public.bible_plan_day_progress
   where user_id = _uid and plan_id = _plan_id;

  if _all_days_done = _plan.days_total then
    begin
      insert into public.bible_plan_completions (user_id, plan_id, awarded_tree_species)
      values (_uid, _plan_id, _plan.tree_species);
      _plan_completed := true;
    exception when unique_violation then null;
    end;
  end if;

  _total_xp := _step_xp_earned + _daily_bonus_xp + _milestone_xp
               + (case when _plan_completed then _plan.xp_reward else 0 end);
  _total_water := _step_water_earned + _daily_bonus_water + _milestone_water
                  + (case when _plan_completed then _plan.water_reward else 0 end);

  update public.profiles
     set xp                    = xp + _total_xp,
         water                 = water + _total_water,
         streak                = _new_streak,
         last_streak_date      = _today,
         current_streak_run_id = _new_run_id,
         updated_at            = now()
   where id = _uid;

  return jsonb_build_object(
    'already_completed',    false,
    'step_xp',              _step_xp_earned,
    'step_water',           _step_water_earned,
    'daily_bonus_xp',       _daily_bonus_xp,
    'daily_bonus_water',    _daily_bonus_water,
    'milestone_hit',        _milestone_hit,
    'milestone_xp',         _milestone_xp,
    'milestone_water',      _milestone_water,
    'plan_completed',       _plan_completed,
    'plan_completion_xp',   case when _plan_completed then _plan.xp_reward else 0 end,
    'plan_completion_water',case when _plan_completed then _plan.water_reward else 0 end,
    'new_streak',           _new_streak,
    'tree_planted',         case when _plan_completed then _plan.tree_species else null end,
    'total_xp_awarded',     _total_xp,
    'total_water_awarded',  _total_water
  );
end $$;

-- =========================================================================
-- 7. RLS
-- =========================================================================
drop policy if exists "bp: read"          on public.bible_plans;
drop policy if exists "bp: admin/pastor"  on public.bible_plans;
create policy "bp: read" on public.bible_plans for select using (
  public.is_site_admin(auth.uid())
  or status = 'published'
  or (scope = 'group' and public.is_group_pastor(auth.uid(), group_id))
);
create policy "bp: admin/pastor" on public.bible_plans for all using (
  public.is_site_admin(auth.uid())
  or (scope = 'group' and public.is_group_pastor(auth.uid(), group_id))
) with check (
  public.is_site_admin(auth.uid())
  or (scope = 'group' and public.is_group_pastor(auth.uid(), group_id))
);

drop policy if exists "bpd: read"         on public.bible_plan_days;
drop policy if exists "bpd: admin/pastor" on public.bible_plan_days;
create policy "bpd: read" on public.bible_plan_days for select using (
  public.is_site_admin(auth.uid())
  or exists (
    select 1 from public.bible_plans p
    where p.id = plan_id
      and (p.status = 'published'
           or public.is_group_pastor(auth.uid(), p.group_id))
  )
);
create policy "bpd: admin/pastor" on public.bible_plan_days for all using (
  public.is_site_admin(auth.uid())
  or exists (
    select 1 from public.bible_plans p
    where p.id = plan_id
      and p.scope = 'group'
      and public.is_group_pastor(auth.uid(), p.group_id)
  )
) with check (
  public.is_site_admin(auth.uid())
  or exists (
    select 1 from public.bible_plans p
    where p.id = plan_id
      and p.scope = 'group'
      and public.is_group_pastor(auth.uid(), p.group_id)
  )
);

drop policy if exists "bpdp: self read"      on public.bible_plan_day_progress;
drop policy if exists "bpdp: no client insert" on public.bible_plan_day_progress;
create policy "bpdp: self read" on public.bible_plan_day_progress for select using (
  user_id = auth.uid()
  or public.is_site_admin(auth.uid())
  or exists (
    select 1 from public.bible_plans p
    where p.id = plan_id and public.is_group_pastor(auth.uid(), p.group_id)
  )
);
create policy "bpdp: no client insert" on public.bible_plan_day_progress
  for insert with check (false);

drop policy if exists "bpc: self read" on public.bible_plan_completions;
create policy "bpc: self read" on public.bible_plan_completions for select using (
  user_id = auth.uid()
  or public.is_site_admin(auth.uid())
  or exists (
    select 1 from public.bible_plans p
    where p.id = plan_id and public.is_group_pastor(auth.uid(), p.group_id)
  )
);

drop policy if exists "usmg: self read" on public.user_streak_milestone_grants;
create policy "usmg: self read" on public.user_streak_milestone_grants for select using (
  user_id = auth.uid() or public.is_site_admin(auth.uid())
);
