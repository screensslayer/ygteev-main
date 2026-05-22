
-- ============================================================================
-- Pastor "Publish a Bible Plan" — schema extensions
--
-- Extends the existing bible_plans / bible_plan_days surface for pastor-
-- authored, group-scoped plans built block-by-block in the iOS pastor flow.
--
-- Design notes:
--   - bible_plan_days.sections (jsonb) is now formally the block list.
--     Contract: { "blocks": [ Block, Block, ... ] }
--     where each Block matches the iOS spec from pastor-plan-create.jsx:
--
--     reading:    { id, type:"read",      order, translation, book,
--                   chapter, verse_start, verse_end }
--     commentary: { id, type:"commentary",order, title, body, ai_drafted }
--     video:      { id, type:"video",     order, title, video_url,
--                   duration_seconds, thumbnail_url }
--     question:   { id, type:"question",  order, prompt,
--                   options:[{label,body}], correct_index }
--     prayer:     { id, type:"prayer",    order, title, body, duration_seconds }
--
--   - Scoring per the spec:
--       day_xp     = 500 + (question_count * 50)
--       day_water  = 4
--       plan totals roll up automatically via trigger.
-- ============================================================================

-- 1. Extend bible_plans -------------------------------------------------------

alter table public.bible_plans
  add column if not exists header_kind text not null default 'gradient'
    check (header_kind in ('gradient', 'photo', 'upload')),
  add column if not exists header_image_url text,
  add column if not exists gradient_index int not null default 0
    check (gradient_index between 0 and 4),
  add column if not exists published_at timestamptz;

-- Auto-stamp published_at when status flips to 'published'.
create or replace function public.tg_bible_plans_set_published_at()
returns trigger language plpgsql as $$
begin
  if new.status = 'published' and (old.status is distinct from 'published') then
    new.published_at := coalesce(new.published_at, now());
  end if;
  return new;
end;
$$;

drop trigger if exists trg_bible_plans_set_published_at on public.bible_plans;
create trigger trg_bible_plans_set_published_at
before update on public.bible_plans
for each row execute function public.tg_bible_plans_set_published_at();


-- 2. Extend bible_plan_step enum with new block types ------------------------

do $$
begin
  if not exists (select 1 from pg_enum e join pg_type t on t.oid = e.enumtypid
                 where t.typname='bible_plan_step' and e.enumlabel='commentary') then
    alter type public.bible_plan_step add value if not exists 'commentary';
  end if;
  if not exists (select 1 from pg_enum e join pg_type t on t.oid = e.enumtypid
                 where t.typname='bible_plan_step' and e.enumlabel='video') then
    alter type public.bible_plan_step add value if not exists 'video';
  end if;
  if not exists (select 1 from pg_enum e join pg_type t on t.oid = e.enumtypid
                 where t.typname='bible_plan_step' and e.enumlabel='question') then
    alter type public.bible_plan_step add value if not exists 'question';
  end if;
end $$;


-- 3. Touch-updated_at trigger on bible_plan_days (for autosave) --------------
-- The existing schema already has updated_at; just make sure a trigger keeps
-- it fresh on every save (in case it doesn't already).

create or replace function public.tg_touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end;
$$;

drop trigger if exists trg_bible_plan_days_touch on public.bible_plan_days;
create trigger trg_bible_plan_days_touch
before update on public.bible_plan_days
for each row execute function public.tg_touch_updated_at();

notify pgrst, 'reload schema';
