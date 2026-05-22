
-- ============================================================================
-- Pastor plan: storage bucket for header images + plan reward roll-up trigger
-- ============================================================================

-- 1. Storage bucket: bible-plan-headers --------------------------------------
-- Public read (so iOS AsyncImage works on the dashboard listing). Writes
-- restricted to pastors of the plan's group + site admin via path-scoped RLS.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'bible-plan-headers', 'bible-plan-headers', true, 5242880,
  array['image/png','image/jpeg','image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Helper: extract plan_id from path "<plan_id>/<filename>"
-- Reuses public.try_parse_uuid + split_part already used by other buckets.

-- Storage policies for bible-plan-headers
drop policy if exists "bible-plan-headers: public read"   on storage.objects;
drop policy if exists "bible-plan-headers: pastor write"  on storage.objects;
drop policy if exists "bible-plan-headers: pastor update" on storage.objects;
drop policy if exists "bible-plan-headers: pastor delete" on storage.objects;

create policy "bible-plan-headers: public read" on storage.objects
  for select using (bucket_id = 'bible-plan-headers');

create policy "bible-plan-headers: pastor write" on storage.objects
  for insert with check (
    bucket_id = 'bible-plan-headers' and (
      public.is_site_admin(auth.uid())
      or exists (
        select 1 from public.bible_plans p
        where p.id = public.try_parse_uuid(split_part(name, '/', 1))
          and p.scope = 'group'
          and public.is_group_pastor(auth.uid(), p.group_id)
      )
    )
  );

create policy "bible-plan-headers: pastor update" on storage.objects
  for update using (
    bucket_id = 'bible-plan-headers' and (
      public.is_site_admin(auth.uid())
      or exists (
        select 1 from public.bible_plans p
        where p.id = public.try_parse_uuid(split_part(name, '/', 1))
          and p.scope = 'group'
          and public.is_group_pastor(auth.uid(), p.group_id)
      )
    )
  );

create policy "bible-plan-headers: pastor delete" on storage.objects
  for delete using (
    bucket_id = 'bible-plan-headers' and (
      public.is_site_admin(auth.uid())
      or exists (
        select 1 from public.bible_plans p
        where p.id = public.try_parse_uuid(split_part(name, '/', 1))
          and p.scope = 'group'
          and public.is_group_pastor(auth.uid(), p.group_id)
      )
    )
  );


-- 2. Plan reward roll-up ------------------------------------------------------
-- Per spec:
--   day_xp     = 500 + (question_count * 50)
--   day_water  = 4
--   plan.xp_reward    = SUM(day_xp)    across all days
--   plan.water_reward = SUM(day_water) = 4 * days_total

create or replace function public.compute_bible_plan_rewards(_plan_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $func$
declare
  v_question_count int;
  v_days_total int;
  v_xp int;
  v_water int;
begin
  -- Count all "question" blocks across all days of this plan.
  select coalesce(sum(
    (select count(*)
     from jsonb_array_elements(coalesce(d.sections->'blocks', '[]'::jsonb)) b
     where b->>'type' = 'question')
  ), 0)::int
  into v_question_count
  from public.bible_plan_days d
  where d.plan_id = _plan_id;

  -- Day count straight from the plan row (already maintained).
  select bp.days_total into v_days_total from public.bible_plans bp where bp.id = _plan_id;
  if v_days_total is null then return; end if;

  v_xp    := (500 * v_days_total) + (50 * v_question_count);
  v_water := 4 * v_days_total;

  update public.bible_plans
    set xp_reward    = v_xp,
        water_reward = v_water,
        updated_at   = now()
    where id = _plan_id;
end;
$func$;

-- Trigger: recompute on any day mutation
create or replace function public.tg_bible_plan_days_recompute_rewards()
returns trigger language plpgsql security definer set search_path = public as $func$
declare v_plan_id uuid;
begin
  v_plan_id := coalesce(new.plan_id, old.plan_id);
  perform public.compute_bible_plan_rewards(v_plan_id);
  return coalesce(new, old);
end;
$func$;

drop trigger if exists trg_bible_plan_days_recompute_rewards on public.bible_plan_days;
create trigger trg_bible_plan_days_recompute_rewards
after insert or update or delete on public.bible_plan_days
for each row execute function public.tg_bible_plan_days_recompute_rewards();

-- Trigger: also recompute when days_total changes on bible_plans (e.g. pastor
-- shrinks/grows the plan in the setup screen, before any days exist).
create or replace function public.tg_bible_plans_recompute_rewards_on_days_total()
returns trigger language plpgsql security definer set search_path = public as $func$
begin
  if new.days_total is distinct from old.days_total then
    perform public.compute_bible_plan_rewards(new.id);
  end if;
  return new;
end;
$func$;

drop trigger if exists trg_bible_plans_recompute_rewards_on_days_total on public.bible_plans;
create trigger trg_bible_plans_recompute_rewards_on_days_total
after update on public.bible_plans
for each row execute function public.tg_bible_plans_recompute_rewards_on_days_total();

notify pgrst, 'reload schema';
