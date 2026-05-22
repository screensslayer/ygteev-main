


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';


-- Extensions required by this baseline. Installed into "public" to match prod.
CREATE EXTENSION IF NOT EXISTS "postgis" WITH SCHEMA "public";
CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "public";


CREATE TYPE "public"."app_role" AS ENUM (
    'site_admin',
    'pastor',
    'leader',
    'member',
    'parent'
);


ALTER TYPE "public"."app_role" OWNER TO "postgres";


CREATE TYPE "public"."bible_plan_category" AS ENUM (
    'book_study',
    'thematic',
    'devotional',
    'group_plan'
);


ALTER TYPE "public"."bible_plan_category" OWNER TO "postgres";


CREATE TYPE "public"."bible_plan_scope" AS ENUM (
    'global',
    'group'
);


ALTER TYPE "public"."bible_plan_scope" OWNER TO "postgres";


CREATE TYPE "public"."bible_plan_status" AS ENUM (
    'draft',
    'published',
    'archived'
);


ALTER TYPE "public"."bible_plan_status" OWNER TO "postgres";


CREATE TYPE "public"."bible_plan_step" AS ENUM (
    'read',
    'study',
    'apply',
    'give',
    'memorize',
    'pray',
    'commentary',
    'video',
    'question'
);


ALTER TYPE "public"."bible_plan_step" OWNER TO "postgres";


CREATE TYPE "public"."bible_plan_visibility" AS ENUM (
    'private',
    'public'
);


ALTER TYPE "public"."bible_plan_visibility" OWNER TO "postgres";


CREATE TYPE "public"."event_media_kind" AS ENUM (
    'photo',
    'video'
);


ALTER TYPE "public"."event_media_kind" OWNER TO "postgres";


CREATE TYPE "public"."event_rsvp_audience" AS ENUM (
    'members_only',
    'public'
);


ALTER TYPE "public"."event_rsvp_audience" OWNER TO "postgres";


CREATE TYPE "public"."event_visibility" AS ENUM (
    'public',
    'groupPrivate'
);


ALTER TYPE "public"."event_visibility" OWNER TO "postgres";


CREATE TYPE "public"."flag_severity" AS ENUM (
    'low',
    'medium',
    'high'
);


ALTER TYPE "public"."flag_severity" OWNER TO "postgres";


CREATE TYPE "public"."flag_status" AS ENUM (
    'open',
    'dismissed',
    'removed'
);


ALTER TYPE "public"."flag_status" OWNER TO "postgres";


CREATE TYPE "public"."group_role" AS ENUM (
    'pastor',
    'leader',
    'member'
);


ALTER TYPE "public"."group_role" OWNER TO "postgres";


CREATE TYPE "public"."group_submission_status" AS ENUM (
    'pending',
    'contacted',
    'approved',
    'rejected'
);


ALTER TYPE "public"."group_submission_status" OWNER TO "postgres";


CREATE TYPE "public"."item_rarity" AS ENUM (
    'common',
    'rare',
    'epic',
    'legendary'
);


ALTER TYPE "public"."item_rarity" OWNER TO "postgres";


CREATE TYPE "public"."item_type" AS ENUM (
    'plant',
    'decor'
);


ALTER TYPE "public"."item_type" OWNER TO "postgres";


CREATE TYPE "public"."join_request_status" AS ENUM (
    'pending',
    'approved',
    'denied',
    'cancelled'
);


ALTER TYPE "public"."join_request_status" OWNER TO "postgres";


CREATE TYPE "public"."moderation_status" AS ENUM (
    'clean',
    'flagged_allowed',
    'flagged_blocked'
);


ALTER TYPE "public"."moderation_status" OWNER TO "postgres";


CREATE TYPE "public"."pastor_signup_stage" AS ENUM (
    'account',
    'group',
    'brand',
    'tours',
    'pricing',
    'checkout',
    'converted',
    'abandoned'
);


ALTER TYPE "public"."pastor_signup_stage" OWNER TO "postgres";


CREATE TYPE "public"."rsvp_status" AS ENUM (
    'going',
    'maybe',
    'declined'
);


ALTER TYPE "public"."rsvp_status" OWNER TO "postgres";


CREATE TYPE "public"."small_group_role" AS ENUM (
    'member',
    'leader'
);


ALTER TYPE "public"."small_group_role" OWNER TO "postgres";


CREATE TYPE "public"."stripe_subscription_status" AS ENUM (
    'trialing',
    'active',
    'past_due',
    'canceled',
    'incomplete',
    'incomplete_expired',
    'unpaid',
    'paused'
);


ALTER TYPE "public"."stripe_subscription_status" OWNER TO "postgres";


CREATE TYPE "public"."thread_kind" AS ENUM (
    'group_main',
    'small_group',
    'parent_chat',
    'dm_pastor',
    'dm_leader',
    'dm_parent_pastor',
    'dm_parent_leader'
);


ALTER TYPE "public"."thread_kind" OWNER TO "postgres";


CREATE TYPE "public"."thread_moderation_policy" AS ENUM (
    'block',
    'allow_alert'
);


ALTER TYPE "public"."thread_moderation_policy" OWNER TO "postgres";


CREATE TYPE "public"."video_policy" AS ENUM (
    'public',
    'signed'
);


ALTER TYPE "public"."video_policy" OWNER TO "postgres";


CREATE TYPE "public"."video_scope" AS ENUM (
    'global',
    'youthGroup',
    'plan'
);


ALTER TYPE "public"."video_scope" OWNER TO "postgres";


CREATE TYPE "public"."video_status" AS ENUM (
    'uploading',
    'processing',
    'ready',
    'errored'
);


ALTER TYPE "public"."video_status" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."_can_manage_feed_post"("_post_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    public.is_site_admin(auth.uid())
    or exists (
      select 1 from public.feed_posts fp
      where fp.id = _post_id
        and fp.scope = 'group'
        and public.is_group_pastor(auth.uid(), fp.group_id)
    );
$$;


ALTER FUNCTION "public"."_can_manage_feed_post"("_post_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."_dev_grant_age_verification"() RETURNS timestamp with time zone
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_caller uuid := auth.uid();
  v_when timestamptz := now();
begin
  if v_caller is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  update public.profiles
    set age_verified_at = v_when,
        updated_at      = now()
    where id = v_caller;

  return v_when;
end;
$$;


ALTER FUNCTION "public"."_dev_grant_age_verification"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."_get_service_role_key"() RETURNS "text"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select value from public._internal_secrets where key = 'service_role_key';
$$;


ALTER FUNCTION "public"."_get_service_role_key"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."_pastor_can_edit_plan"("_plan_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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


ALTER FUNCTION "public"."_pastor_can_edit_plan"("_plan_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."_pastor_can_view_group"("_group_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select public.is_site_admin(auth.uid())
      or public.is_group_pastor(auth.uid(), _group_id);
$$;


ALTER FUNCTION "public"."_pastor_can_view_group"("_group_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."accept_family_invite"("_code" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare v_caller uuid := auth.uid(); v_invite public.family_invites;
begin
  if v_caller is null then raise exception 'not_authenticated'; end if;

  -- Sweep stale pending before lookup
  update public.family_invites
     set status = 'expired'
   where status = 'pending' and expires_at <= now();

  select * into v_invite
    from public.family_invites
   where pairing_code = _code
     and status = 'pending'
   order by created_at desc
   limit 1
   for update;

  if v_invite.id is null then
    raise exception 'invalid_or_expired_code' using errcode = '22023';
  end if;
  if v_invite.invited_user_id is not null and v_invite.invited_user_id <> v_caller then
    raise exception 'code_belongs_to_another_user' using errcode = '42501';
  end if;

  insert into public.family_members (family_id, user_id, role)
    values (v_invite.family_id, v_caller, 'child')
    on conflict (family_id, user_id) do nothing;

  update public.family_invites
     set status='accepted', accepted_by=v_caller, accepted_at=now()
   where id = v_invite.id;

  return v_invite.family_id;
end;
$$;


ALTER FUNCTION "public"."accept_family_invite"("_code" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_approve_to_official"("_source_post_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_src public.feed_posts;
  v_new_id uuid;
begin
  if not public.is_site_admin(auth.uid()) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  select * into v_src from public.feed_posts where id = _source_post_id;
  if v_src.id is null then raise exception 'post_not_found'; end if;

  insert into public.feed_posts (
    post_type, scope, group_id, source_kind, source_url, source_handle, source_post_id,
    title, caption, video_id, slideshow_seconds_per_photo,
    status, published_at, created_by
  ) values (
    v_src.post_type, 'ygteev_official', null,
    'cross_group_approved', v_src.source_url, v_src.source_handle, v_src.source_post_id,
    v_src.title, v_src.caption, v_src.video_id, v_src.slideshow_seconds_per_photo,
    'published', now(), auth.uid()
  )
  returning id into v_new_id;

  -- For slideshows: copy the photo rows over (same storage_paths)
  if v_src.post_type = 'slideshow' then
    insert into public.feed_post_photos (post_id, storage_path, display_order, alt_text)
    select v_new_id, storage_path, display_order, alt_text
    from public.feed_post_photos where post_id = _source_post_id;
  end if;

  return v_new_id;
end;
$$;


ALTER FUNCTION "public"."admin_approve_to_official"("_source_post_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_hard_delete_user"("_user_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
declare
  v_caller uuid := auth.uid();
begin
  if v_caller is null or not public.is_site_admin(v_caller) then
    raise exception 'forbidden: site admin required'
      using errcode = '42501';
  end if;

  if _user_id is null then
    raise exception 'user_id is required'
      using errcode = '22023';
  end if;

  -- Cascade does the rest.
  delete from auth.users where id = _user_id;
end;
$$;


ALTER FUNCTION "public"."admin_hard_delete_user"("_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_list_all_group_posts"("_limit" integer DEFAULT 100) RETURNS TABLE("post_id" "uuid", "post_type" "text", "group_id" "uuid", "group_name" "text", "title" "text", "caption" "text", "source_kind" "text", "source_handle" "text", "video_id" "uuid", "mux_playback_id" "text", "duration_sec" numeric, "photos" "jsonb", "views_count" integer, "likes_count" integer, "published_at" timestamp with time zone, "already_in_official" boolean)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    fp.id, fp.post_type, fp.group_id, yg.name, fp.title, fp.caption,
    fp.source_kind, fp.source_handle,
    fp.video_id, v.mux_playback_id, v.duration_sec,
    coalesce(
      (select jsonb_agg(jsonb_build_object(
                'storage_path', ph.storage_path,
                'display_order', ph.display_order,
                'public_url',
                  'https://tkesywmshaicjmywbovn.supabase.co/storage/v1/object/public/feed-photos/' || ph.storage_path
              ) order by ph.display_order)
         from public.feed_post_photos ph where ph.post_id = fp.id),
      '[]'::jsonb
    ),
    fp.views_count, fp.likes_count, fp.published_at,
    exists (
      select 1 from public.feed_posts dup
      where dup.scope = 'ygteev_official'
        and dup.video_id is not distinct from fp.video_id
        and dup.title is not distinct from fp.title
    )
  from public.feed_posts fp
  left join public.youth_groups yg on yg.id = fp.group_id
  left join public.videos v on v.id = fp.video_id
  where fp.scope = 'group' and fp.status = 'published'
    and public.is_site_admin(auth.uid())
  order by fp.published_at desc nulls last
  limit greatest(1, least(_limit, 500));
$$;


ALTER FUNCTION "public"."admin_list_all_group_posts"("_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_weekly_ranking_report"("_week_start" "date" DEFAULT NULL::"date") RETURNS TABLE("week_start" "date", "class" "text", "class_label" "text", "total_groups_in_class" integer, "rank_in_class" integer, "group_id" "uuid", "group_name" "text", "church_name" "text", "logo_url" "text", "active_count" integer, "week_xp" bigint, "multiplier" numeric, "adjusted_xp" bigint)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_week date := coalesce(_week_start,
    (date_trunc('week', now() at time zone 'UTC')::date - 7));
begin
  if not public.is_site_admin(auth.uid()) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  return query
  select s.week_start,
         s.class,
         initcap(s.class)            as class_label,
         s.total_groups_in_class,
         s.rank_in_class,
         s.group_id,
         yg.name                     as group_name,
         yg.church_name,
         yg.logo_url,
         s.active_count, s.week_xp, s.multiplier, s.adjusted_xp
  from public.weekly_ranking_snapshots s
  join public.youth_groups yg on yg.id = s.group_id
  where s.week_start = v_week
  order by s.class, s.rank_in_class;
end;
$$;


ALTER FUNCTION "public"."admin_weekly_ranking_report"("_week_start" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."am_i_in_any_youth_group"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1 from public.youth_group_members ygm
    join public.youth_groups yg on yg.id = ygm.group_id
    where ygm.user_id = auth.uid()
      and yg.is_default_ygteev = false   -- real church membership only
  );
$$;


ALTER FUNCTION "public"."am_i_in_any_youth_group"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_manage_small_groups"("_user_id" "uuid", "_small_group_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    public.is_site_admin(_user_id)
    or exists (
      select 1 from public.small_groups sg
      where sg.id = _small_group_id
        and public.is_group_pastor(_user_id, sg.youth_group_id)
    )
$$;


ALTER FUNCTION "public"."can_manage_small_groups"("_user_id" "uuid", "_small_group_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_manage_user_profile"("_caller_id" "uuid", "_target_user_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    _caller_id = _target_user_id
    or public.is_site_admin(_caller_id)
    -- Same youth group, caller is pastor or leader there
    or exists (
      select 1
      from public.youth_group_members ygm_target
      join public.youth_group_members ygm_caller
        on ygm_caller.group_id = ygm_target.group_id
      where ygm_target.user_id = _target_user_id
        and ygm_caller.user_id  = _caller_id
        and ygm_caller.role in ('pastor', 'leader')
    )
    -- Same small group, caller is a leader there
    or exists (
      select 1
      from public.small_group_members sgm_target
      join public.small_group_members sgm_caller
        on sgm_caller.small_group_id = sgm_target.small_group_id
      where sgm_target.user_id = _target_user_id
        and sgm_caller.user_id  = _caller_id
        and sgm_caller.role = 'leader'
    );
$$;


ALTER FUNCTION "public"."can_manage_user_profile"("_caller_id" "uuid", "_target_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_take_attendance"("_user_id" "uuid", "_small_group_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select public.is_small_group_leader(_user_id, _small_group_id)
      or public.can_manage_small_groups(_user_id, _small_group_id);
$$;


ALTER FUNCTION "public"."can_take_attendance"("_user_id" "uuid", "_small_group_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_user_start_plan"("_user_id" "uuid", "_plan_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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


ALTER FUNCTION "public"."can_user_start_plan"("_user_id" "uuid", "_plan_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."complete_pastor_plan_day"("_plan_id" "uuid", "_day_number" integer, "_answers" "jsonb" DEFAULT '[]'::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  _uid uuid := auth.uid();
  _plan public.bible_plans;
  _day  public.bible_plan_days;
  _profile public.profiles;
  _block jsonb; _ans jsonb;
  _selected int; _correct_idx int; _correct_count int := 0;
  _day_xp int; _day_water int := 4;
  _daily_bonus_xp int := 100; _daily_bonus_water int := 5;
  _existing public.bible_plan_day_progress;
  _today date := current_date;
  _new_streak int; _new_run_id uuid;
  _milestone_xp int := 0; _milestone_water int := 0; _milestone_hit int := null;
  _all_days_done int; _plan_completed boolean := false;
  _total_xp int := 0; _total_water int := 0;
  _xp_multiplier int := 1; _xp_base int;
begin
  if _uid is null then raise exception 'not_authenticated'; end if;

  select * into _plan from public.bible_plans where id = _plan_id;
  if _plan.id is null then raise exception 'plan_not_found'; end if;
  if _plan.status <> 'published' then raise exception 'plan_not_published'; end if;

  if _plan.scope = 'group' and _plan.visibility = 'private'
     and not exists (
       select 1 from public.youth_group_members
       where user_id = _uid
         and (group_id = _plan.group_id
              or group_id = any(coalesce(_plan.additional_group_ids, '{}'::uuid[])))
     ) then raise exception 'not_in_group'; end if;

  select * into _day from public.bible_plan_days where plan_id = _plan_id and day_number = _day_number;
  if _day.id is null then raise exception 'day_not_found'; end if;

  select * into _existing from public.bible_plan_day_progress where user_id = _uid and day_id = _day.id;
  if _existing.id is not null then
    return jsonb_build_object('already_completed', true, 'day_id', _day.id,
      'day_xp', _existing.step_xp_earned, 'day_water', _existing.step_water_earned);
  end if;

  for _block in select * from jsonb_array_elements(coalesce(_day.sections->'blocks','[]'::jsonb)) loop
    if _block->>'type' = 'question' then
      _correct_idx := nullif(_block->>'correct_index', '')::int;
      select value into _ans
        from jsonb_array_elements(coalesce(_answers, '[]'::jsonb)) as t(value)
       where t.value->>'block_id' = _block->>'id' limit 1;
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
    _new_streak := 1; _new_run_id := gen_random_uuid();
  elsif _profile.last_streak_date = _today then
    _new_streak := _profile.streak; _new_run_id := _profile.current_streak_run_id;
  else
    _new_streak := _profile.streak + 1;
    _new_run_id := coalesce(_profile.current_streak_run_id, gen_random_uuid());
  end if;

  if _new_streak in (3,7,10,15,20,25,30) then
    _milestone_hit := _new_streak;
    case _new_streak
      when 3 then _milestone_xp := 50; _milestone_water := 10;
      when 7 then _milestone_xp := 200; _milestone_water := 30;
      when 10 then _milestone_xp := 300; _milestone_water := 50;
      when 15 then _milestone_xp := 500; _milestone_water := 75;
      when 20 then _milestone_xp := 750; _milestone_water := 100;
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

  insert into public.bible_plan_day_progress (user_id, plan_id, day_id, step_xp_earned, step_water_earned)
  values (_uid, _plan_id, _day.id, _day_xp, _day_water);

  _total_xp := _day_xp + _daily_bonus_xp + _milestone_xp;
  _total_water := _day_water + _daily_bonus_water + _milestone_water;

  select count(*) into _all_days_done from public.bible_plan_day_progress
   where user_id = _uid and plan_id = _plan_id;
  if _all_days_done = _plan.days_total then
    begin
      insert into public.bible_plan_completions (user_id, plan_id) values (_uid, _plan_id);
      _plan_completed := true;
      _total_xp := _total_xp + _plan.xp_reward;
      _total_water := _total_water + _plan.water_reward;
    exception when unique_violation then null; end;
  end if;

  _xp_base := _total_xp;
  if public.is_paying_subscriber(_uid) then
    _xp_multiplier := 2;
    _total_xp := _total_xp * _xp_multiplier;
  end if;

  update public.profiles
     set xp = xp + _total_xp,
         lifetime_xp = lifetime_xp + _total_xp,
         water = water + _total_water,
         streak = _new_streak,
         last_streak_date = _today,
         current_streak_run_id = _new_run_id,
         updated_at = now()
   where id = _uid;

  -- NEW: log the credit for the weekly leaderboard
  insert into public.user_xp_grants (user_id, amount, source)
  values (_uid, _total_xp, 'pastor_plan_day');

  return jsonb_build_object(
    'already_completed', false, 'day_id', _day.id, 'day_xp', _day_xp, 'day_water', _day_water,
    'correct_count', _correct_count, 'daily_bonus_xp', _daily_bonus_xp,
    'daily_bonus_water', _daily_bonus_water, 'milestone_hit', _milestone_hit,
    'milestone_xp', _milestone_xp, 'milestone_water', _milestone_water,
    'plan_completed', _plan_completed,
    'plan_completion_xp', case when _plan_completed then _plan.xp_reward else 0 end,
    'plan_completion_water', case when _plan_completed then _plan.water_reward else 0 end,
    'new_streak', _new_streak, 'xp_multiplier', _xp_multiplier,
    'xp_base_awarded', _xp_base, 'total_xp_awarded', _total_xp,
    'total_water_awarded', _total_water
  );
end;
$$;


ALTER FUNCTION "public"."complete_pastor_plan_day"("_plan_id" "uuid", "_day_number" integer, "_answers" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."complete_plan_step"("_plan_id" "uuid", "_day_id" "uuid", "_step" "public"."bible_plan_step", "_answers" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  _uid uuid := auth.uid();
  _plan public.bible_plans; _day public.bible_plan_days; _profile public.profiles;
  _step_xp int := 0; _step_water int := 0;
  _step_payload jsonb := _answers; _existing public.bible_plan_step_progress;
  _steps_done int; _is_day_now_complete boolean := false;
  _today date := current_date; _new_streak int; _new_run_id uuid;
  _milestone_xp int := 0; _milestone_water int := 0; _milestone_hit int := null;
  _all_days_done int; _plan_completed boolean := false;
  _daily_bonus_xp int := 100; _daily_bonus_water int := 5;
  _total_xp int := 0; _total_water int := 0;
  _correct_count int := 0; _parts jsonb; _i int; _ans int; _study_correct int;
  _xp_multiplier int := 1; _xp_base int;
begin
  if _uid is null then raise exception 'not_authenticated'; end if;

  select * into _plan from public.bible_plans where id = _plan_id;
  if _plan.id is null then raise exception 'plan_not_found'; end if;
  select * into _day from public.bible_plan_days where id = _day_id;
  if _day.id is null or _day.plan_id <> _plan_id then raise exception 'day_not_in_plan'; end if;
  if not public.can_user_start_plan(_uid, _plan_id) then raise exception 'plan_locked'; end if;

  -- 'give' step is being deprecated. If a client still submits it,
  -- treat as no-op so older builds don't hang the day flow.
  if _step::text = 'give' then
    return jsonb_build_object(
      'already_completed', true,
      'step',              _step,
      'xp_earned',         0,
      'water_earned',      0,
      'payload',           _answers,
      'note',              'give step removed — submission ignored'
    );
  end if;

  select * into _existing from public.bible_plan_step_progress
   where user_id = _uid and day_id = _day_id and step = _step;
  if _existing.id is not null then
    return jsonb_build_object('already_completed', true, 'step', _step,
      'xp_earned', _existing.xp_earned, 'water_earned', _existing.water_earned,
      'payload', _existing.payload);
  end if;

  if _step = 'read' then
    _parts := _day.sections->'read'->'parts';
    if _parts is not null and jsonb_array_length(_parts) = 3 then
      for _i in 0..2 loop
        _ans := nullif((_answers->'part_answers'->>_i), '')::int;
        if _ans is not null and (_parts->_i->>'correct_index') is not null
           and _ans = (_parts->_i->>'correct_index')::int then
          _correct_count := _correct_count + 1;
        end if;
      end loop;
    end if;
    _step_xp := _correct_count * 10;
    _step_payload := jsonb_build_object('part_answers', coalesce(_answers->'part_answers','[]'::jsonb), 'correct_count', _correct_count);
  elsif _step = 'study' then
    _ans := nullif((_answers->>'answer'), '')::int;
    _study_correct := nullif((_day.sections->'study'->>'correct_index'), '')::int;
    if _ans is not null and _study_correct is not null and _ans = _study_correct then
      _step_xp := 10; _step_payload := jsonb_build_object('answer', _ans, 'correct', true);
    else
      _step_payload := jsonb_build_object('answer', _ans, 'correct', false);
    end if;
  elsif _step = 'memorize' then
    if coalesce((_answers->>'passed')::boolean, false) then _step_xp := 20; end if;
    _step_payload := _answers;
  else
    _step_xp := 0; _step_payload := _answers;
  end if;

  insert into public.bible_plan_step_progress
    (user_id, plan_id, day_id, step, payload, xp_earned, water_earned)
  values (_uid, _plan_id, _day_id, _step, _step_payload, _step_xp, _step_water);

  -- Count distinct steps EXCLUDING any legacy 'give' rows so old
  -- progress doesn't artificially inflate the completion count.
  select count(distinct step) into _steps_done
    from public.bible_plan_step_progress
   where user_id = _uid and day_id = _day_id and step::text <> 'give';

  -- Day is complete at 5 steps (was 6 before 'give' was removed)
  _is_day_now_complete := (_steps_done = 5);

  _total_xp := _step_xp; _total_water := _step_water;

  if _is_day_now_complete and not exists (
    select 1 from public.bible_plan_day_progress where user_id = _uid and day_id = _day_id
  ) then
    select * into _profile from public.profiles where id = _uid for update;
    if _profile.last_streak_date is null or _profile.last_streak_date < _today - interval '1 day' then
      _new_streak := 1; _new_run_id := gen_random_uuid();
    elsif _profile.last_streak_date = _today then
      _new_streak := _profile.streak; _new_run_id := _profile.current_streak_run_id;
    else
      _new_streak := _profile.streak + 1;
      _new_run_id := coalesce(_profile.current_streak_run_id, gen_random_uuid());
    end if;
    if _new_streak in (3,7,10,15,20,25,30) then
      _milestone_hit := _new_streak;
      case _new_streak
        when 3 then _milestone_xp := 50; _milestone_water := 10;
        when 7 then _milestone_xp := 200; _milestone_water := 30;
        when 10 then _milestone_xp := 300; _milestone_water := 50;
        when 15 then _milestone_xp := 500; _milestone_water := 75;
        when 20 then _milestone_xp := 750; _milestone_water := 100;
        when 25 then _milestone_xp := 1000; _milestone_water := 125;
        when 30 then _milestone_xp := 1500; _milestone_water := 200;
      end case;
      begin
        insert into public.user_streak_milestone_grants (user_id, run_id, milestone, xp_awarded, water_awarded)
        values (_uid, _new_run_id, _new_streak, _milestone_xp, _milestone_water);
      exception when unique_violation then
        _milestone_xp := 0; _milestone_water := 0; _milestone_hit := null;
      end;
    end if;
    insert into public.bible_plan_day_progress (user_id, plan_id, day_id, step_xp_earned, step_water_earned)
    values (_uid, _plan_id, _day_id,
      (select coalesce(sum(xp_earned),0) from public.bible_plan_step_progress where user_id=_uid and day_id=_day_id and step::text <> 'give'),
      (select coalesce(sum(water_earned),0) from public.bible_plan_step_progress where user_id=_uid and day_id=_day_id and step::text <> 'give'));
    _total_xp := _total_xp + _daily_bonus_xp + _milestone_xp;
    _total_water := _total_water + _daily_bonus_water + _milestone_water;

    select count(*) into _all_days_done from public.bible_plan_day_progress
     where user_id = _uid and plan_id = _plan_id;
    if _all_days_done = _plan.days_total then
      begin
        insert into public.bible_plan_completions (user_id, plan_id) values (_uid, _plan_id);
        _plan_completed := true;
        _total_xp := _total_xp + _plan.xp_reward;
        _total_water := _total_water + _plan.water_reward;
      exception when unique_violation then null; end;
    end if;

    _xp_base := _total_xp;
    if public.is_paying_subscriber(_uid) then
      _xp_multiplier := 2;
      _total_xp := _total_xp * _xp_multiplier;
    end if;
    update public.profiles
       set xp = xp + _total_xp, lifetime_xp = lifetime_xp + _total_xp,
           water = water + _total_water, streak = _new_streak,
           last_streak_date = _today, current_streak_run_id = _new_run_id, updated_at = now()
     where id = _uid;
    insert into public.user_xp_grants (user_id, amount, source)
    values (_uid, _total_xp, 'plan_step_day_complete');
  else
    _xp_base := _total_xp;
    if public.is_paying_subscriber(_uid) then
      _xp_multiplier := 2;
      _total_xp := _total_xp * _xp_multiplier;
    end if;
    update public.profiles set xp = xp + _total_xp, lifetime_xp = lifetime_xp + _total_xp,
       water = water + _total_water, updated_at = now() where id = _uid;
    insert into public.user_xp_grants (user_id, amount, source)
    values (_uid, _total_xp, 'plan_step');
  end if;

  return jsonb_build_object(
    'already_completed', false, 'step', _step, 'step_xp', _step_xp, 'step_water', _step_water,
    'steps_done', _steps_done, 'day_now_complete', _is_day_now_complete,
    'daily_bonus_xp', case when _is_day_now_complete then _daily_bonus_xp else 0 end,
    'daily_bonus_water', case when _is_day_now_complete then _daily_bonus_water else 0 end,
    'milestone_hit', _milestone_hit, 'milestone_xp', _milestone_xp, 'milestone_water', _milestone_water,
    'plan_completed', _plan_completed,
    'plan_completion_xp', case when _plan_completed then _plan.xp_reward else 0 end,
    'plan_completion_water', case when _plan_completed then _plan.water_reward else 0 end,
    'new_streak', case when _is_day_now_complete then _new_streak else null end,
    'xp_multiplier', _xp_multiplier, 'xp_base_awarded', _xp_base,
    'total_xp_awarded', _total_xp, 'total_water_awarded', _total_water
  );
end $$;


ALTER FUNCTION "public"."complete_plan_step"("_plan_id" "uuid", "_day_id" "uuid", "_step" "public"."bible_plan_step", "_answers" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."compute_bible_plan_rewards"("_plan_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."compute_bible_plan_rewards"("_plan_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_family_invite"("_family_id" "uuid", "_invited_user_id" "uuid" DEFAULT NULL::"uuid", "_invited_email" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_caller uuid := auth.uid();
  v_code text;
  v_invite_id uuid;
  v_attempts int := 0;
begin
  if v_caller is null then raise exception 'not_authenticated'; end if;
  if not exists (
    select 1 from public.family_members
    where family_id = _family_id and user_id = v_caller and role = 'parent'
  ) then raise exception 'forbidden: must be a parent' using errcode = '42501'; end if;

  -- Sweep stale pending invites to free up codes
  update public.family_invites
     set status = 'expired'
   where status = 'pending' and expires_at <= now();

  loop
    v_attempts := v_attempts + 1;
    v_code := lpad((floor(random() * 10000))::text, 4, '0');
    begin
      insert into public.family_invites
        (family_id, pairing_code, invited_user_id, invited_email, created_by)
      values (_family_id, v_code, _invited_user_id, nullif(trim(_invited_email), ''), v_caller)
      returning id into v_invite_id;
      exit;
    exception when unique_violation then
      if v_attempts > 10 then raise exception 'could_not_generate_unique_code'; end if;
    end;
  end loop;

  return jsonb_build_object(
    'invite_id', v_invite_id,
    'pairing_code', v_code,
    'expires_at', now() + interval '10 minutes'
  );
end;
$$;


ALTER FUNCTION "public"."create_family_invite"("_family_id" "uuid", "_invited_user_id" "uuid", "_invited_email" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ensure_dm_thread"("_group_id" "uuid", "_kind" "public"."thread_kind", "_u1" "uuid", "_u2" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare _ua uuid := least(_u1, _u2); _ub uuid := greatest(_u1, _u2); _tid uuid;
begin
  if _u1 = _u2 then return null; end if;
  select id into _tid from public.chat_threads
    where group_id = _group_id and kind = _kind and dm_user_a = _ua and dm_user_b = _ub;
  if _tid is not null then return _tid; end if;
  insert into public.chat_threads(group_id, kind, moderation_policy, dm_user_a, dm_user_b)
  values (_group_id, _kind,
          case when _kind in ('dm_pastor','dm_leader') then 'allow_alert'::public.thread_moderation_policy
               else 'block'::public.thread_moderation_policy end,
          _ua, _ub)
  returning id into _tid;
  insert into public.thread_subscribers(thread_id, user_id) values (_tid, _ua), (_tid, _ub)
  on conflict do nothing;
  return _tid;
end $$;


ALTER FUNCTION "public"."ensure_dm_thread"("_group_id" "uuid", "_kind" "public"."thread_kind", "_u1" "uuid", "_u2" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ensure_group_main_thread"("_group_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare _tid uuid;
begin
  select id into _tid from public.chat_threads where group_id = _group_id and kind = 'group_main';
  if _tid is not null then return _tid; end if;
  insert into public.chat_threads(group_id, kind, moderation_policy)
  values (_group_id, 'group_main', 'block') returning id into _tid;
  return _tid;
end $$;


ALTER FUNCTION "public"."ensure_group_main_thread"("_group_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ensure_parent_chat_subscriptions"("_parent_id" "uuid", "_family_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_yg uuid; v_pastor uuid; v_sg uuid; v_leader uuid; v_thread uuid;
begin
  for v_yg in
    select distinct ygm.group_id
    from public.family_members fm
    join public.youth_group_members ygm on ygm.user_id = fm.user_id
    where fm.family_id = _family_id and fm.role = 'child'
  loop
    -- parent_chat per youth group
    select id into v_thread from public.chat_threads
      where kind = 'parent_chat'::thread_kind and group_id = v_yg limit 1;
    if v_thread is null then
      insert into public.chat_threads (kind, group_id)
        values ('parent_chat'::thread_kind, v_yg) returning id into v_thread;
      insert into public.thread_subscribers (thread_id, user_id)
        select v_thread, ygm.user_id
        from public.youth_group_members ygm
        where ygm.group_id = v_yg and ygm.role in ('pastor','leader')
        on conflict do nothing;
    end if;
    insert into public.thread_subscribers (thread_id, user_id)
      values (v_thread, _parent_id) on conflict do nothing;

    -- dm_parent_pastor for each pastor
    for v_pastor in
      select user_id from public.youth_group_members
      where group_id = v_yg and role = 'pastor'
    loop
      select t.id into v_thread
      from public.chat_threads t
      where t.kind = 'dm_parent_pastor'::thread_kind and t.group_id = v_yg
        and exists (select 1 from public.thread_subscribers
                     where thread_id = t.id and user_id = _parent_id)
        and exists (select 1 from public.thread_subscribers
                     where thread_id = t.id and user_id = v_pastor)
      limit 1;
      if v_thread is null then
        insert into public.chat_threads (kind, group_id)
          values ('dm_parent_pastor'::thread_kind, v_yg) returning id into v_thread;
        insert into public.thread_subscribers (thread_id, user_id)
          values (v_thread, _parent_id), (v_thread, v_pastor)
          on conflict do nothing;
      end if;
    end loop;

    -- dm_parent_leader for each small group the child(ren) belong to
    for v_sg, v_leader in
      select sg.id, sgm_leader.user_id
      from public.family_members fm
      join public.small_group_members sgm on sgm.user_id = fm.user_id and sgm.role = 'member'
      join public.small_groups sg on sg.id = sgm.small_group_id
      join public.small_group_members sgm_leader
        on sgm_leader.small_group_id = sg.id and sgm_leader.role = 'leader'
      where fm.family_id = _family_id and fm.role = 'child'
        and sg.youth_group_id = v_yg
    loop
      select t.id into v_thread
      from public.chat_threads t
      where t.kind = 'dm_parent_leader'::thread_kind and t.small_group_id = v_sg
        and exists (select 1 from public.thread_subscribers
                     where thread_id = t.id and user_id = _parent_id)
        and exists (select 1 from public.thread_subscribers
                     where thread_id = t.id and user_id = v_leader)
      limit 1;
      if v_thread is null then
        insert into public.chat_threads (kind, group_id, small_group_id)
          values ('dm_parent_leader'::thread_kind, v_yg, v_sg) returning id into v_thread;
        insert into public.thread_subscribers (thread_id, user_id)
          values (v_thread, _parent_id), (v_thread, v_leader)
          on conflict do nothing;
      end if;
    end loop;
  end loop;
end;
$$;


ALTER FUNCTION "public"."ensure_parent_chat_subscriptions"("_parent_id" "uuid", "_family_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ensure_small_group_thread"("_small_group_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare _tid uuid; _gid uuid;
begin
  select id into _tid from public.chat_threads where small_group_id = _small_group_id and kind = 'small_group';
  if _tid is not null then return _tid; end if;
  select youth_group_id into _gid from public.small_groups where id = _small_group_id;
  insert into public.chat_threads(group_id, small_group_id, kind, moderation_policy)
  values (_gid, _small_group_id, 'small_group', 'block') returning id into _tid;
  return _tid;
end $$;


ALTER FUNCTION "public"."ensure_small_group_thread"("_small_group_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."event_rsvp_summary"("_event_id" "uuid") RETURNS TABLE("going_count" integer, "maybe_count" integer, "declined_count" integer, "total_count" integer, "going" "jsonb", "maybe" "jsonb", "declined" "jsonb", "viewer_status" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_event public.events;
  v_uid uuid := auth.uid();
  v_can_see boolean;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select * into v_event from public.events where id = _event_id;
  if v_event.id is null then raise exception 'event_not_found'; end if;

  v_can_see :=
       public.is_site_admin(v_uid)
    or public.is_group_member(v_uid, v_event.group_id)
    or v_event.visibility = 'public';
  if not v_can_see then raise exception 'forbidden' using errcode = '42501'; end if;

  return query
  with rs as (
    select r.user_id, r.status, r.created_at,
           p.display_name, p.handle, p.avatar_url, p.grade_year,
           ygm.role::text as yg_role,
           exists (
             select 1
             from public.small_group_members sgm
             join public.small_groups sg on sg.id = sgm.small_group_id
             where sgm.user_id = r.user_id
               and sgm.role    = 'leader'
               and sg.youth_group_id = v_event.group_id
           ) as is_sg_leader
    from public.event_rsvps r
    join public.profiles p on p.id = r.user_id
    left join public.youth_group_members ygm
      on ygm.user_id = r.user_id and ygm.group_id = v_event.group_id
    where r.event_id = _event_id
  ),
  rs_with_role as (
    select
      user_id, status, created_at,
      display_name, handle, avatar_url, grade_year,
      case
        when yg_role = 'pastor' then 'pastor'
        when is_sg_leader        then 'leader'
        when yg_role is not null then 'member'
        else null
      end as role_label
    from rs
  )
  select
    (select count(*)::int from rs_with_role where status = 'going')              as going_count,
    (select count(*)::int from rs_with_role where status = 'maybe')              as maybe_count,
    (select count(*)::int from rs_with_role where status = 'declined')           as declined_count,
    (select count(*)::int from rs_with_role)                                     as total_count,
    coalesce(
      (select jsonb_agg(jsonb_build_object(
         'user_id', user_id, 'display_name', display_name,
         'handle', handle, 'avatar_url', avatar_url,
         'grade_year', grade_year, 'role', role_label,
         'rsvp_at', created_at) order by created_at)
       from rs_with_role where status = 'going'),
      '[]'::jsonb) as going,
    coalesce(
      (select jsonb_agg(jsonb_build_object(
         'user_id', user_id, 'display_name', display_name,
         'handle', handle, 'avatar_url', avatar_url,
         'grade_year', grade_year, 'role', role_label,
         'rsvp_at', created_at) order by created_at)
       from rs_with_role where status = 'maybe'),
      '[]'::jsonb) as maybe,
    coalesce(
      (select jsonb_agg(jsonb_build_object(
         'user_id', user_id, 'display_name', display_name,
         'handle', handle, 'avatar_url', avatar_url,
         'grade_year', grade_year, 'role', role_label,
         'rsvp_at', created_at) order by created_at)
       from rs_with_role where status = 'declined'),
      '[]'::jsonb) as declined,
    (select status::text from rs_with_role where user_id = v_uid limit 1) as viewer_status;
end;
$$;


ALTER FUNCTION "public"."event_rsvp_summary"("_event_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."family_add_via_scan"("_family_id" "uuid", "_scanned_user_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_caller uuid := auth.uid();
begin
  if v_caller is null then
    raise exception 'not_authenticated';
  end if;
  if v_caller = _scanned_user_id then
    raise exception 'cannot_add_self' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.family_members
    where family_id = _family_id and user_id = v_caller and role = 'parent'
  ) then
    raise exception 'forbidden: must be a parent' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.profiles where id = _scanned_user_id and deleted_at is null
  ) then
    raise exception 'scanned_user_not_found' using errcode = '22023';
  end if;

  insert into public.family_members (family_id, user_id, role)
    values (_family_id, _scanned_user_id, 'child')
    on conflict (family_id, user_id) do nothing;

  return _family_id;
end;
$$;


ALTER FUNCTION "public"."family_add_via_scan"("_family_id" "uuid", "_scanned_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."feed_post_record_view"("_post_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  insert into public.feed_post_engagement (post_id, user_id, first_viewed_at)
    values (_post_id, v_uid, now())
    on conflict (post_id, user_id) do update
      set first_viewed_at = coalesce(public.feed_post_engagement.first_viewed_at, now());
end;
$$;


ALTER FUNCTION "public"."feed_post_record_view"("_post_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."feed_post_record_watch_complete"("_post_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  insert into public.feed_post_engagement (post_id, user_id, first_viewed_at, watch_completed_at)
    values (_post_id, v_uid, now(), now())
    on conflict (post_id, user_id) do update
      set first_viewed_at    = coalesce(public.feed_post_engagement.first_viewed_at, now()),
          watch_completed_at = coalesce(public.feed_post_engagement.watch_completed_at, now());
end;
$$;


ALTER FUNCTION "public"."feed_post_record_watch_complete"("_post_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."feed_post_toggle_like"("_post_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_uid uuid := auth.uid();
  v_existing public.feed_post_engagement;
  v_now timestamptz := now();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select * into v_existing from public.feed_post_engagement
    where post_id = _post_id and user_id = v_uid;

  if v_existing.id is null then
    insert into public.feed_post_engagement (post_id, user_id, first_viewed_at, liked_at)
      values (_post_id, v_uid, v_now, v_now);
    return true;
  end if;

  if v_existing.liked_at is not null then
    update public.feed_post_engagement
      set liked_at = null
      where id = v_existing.id;
    return false;
  else
    update public.feed_post_engagement
      set liked_at = v_now,
          first_viewed_at = coalesce(first_viewed_at, v_now)
      where id = v_existing.id;
    return true;
  end if;
end;
$$;


ALTER FUNCTION "public"."feed_post_toggle_like"("_post_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."finalize_pastor_signup"("_draft_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  _draft public.pastor_signup_drafts;
  _gradient_pairs text[][] := array[
    array['#6B2BFF', '#FF3DA5'],  -- 0
    array['#00E0FF', '#6B2BFF'],  -- 1
    array['#B4FF3C', '#00E0FF'],  -- 2
    array['#FFD60A', '#FF6B35']   -- 3
  ];
  _gradient_from text;
  _gradient_to   text;
  _group_id uuid;
  _full_address text;
begin
  select * into _draft from public.pastor_signup_drafts where id = _draft_id for update;
  if _draft.id is null then raise exception 'draft_not_found'; end if;
  if _draft.finalized_youth_group_id is not null then
    return _draft.finalized_youth_group_id;
  end if;
  if _draft.user_id is null then raise exception 'draft_has_no_user'; end if;

  _gradient_from := _gradient_pairs[coalesce(_draft.gradient_idx, 0) + 1][1];
  _gradient_to   := _gradient_pairs[coalesce(_draft.gradient_idx, 0) + 1][2];
  _full_address  := concat_ws(', ', _draft.address_line, _draft.address_city);

  insert into public.youth_groups (
    name, church_name, description, address, meeting_time,
    latitude, longitude, logo_url,
    gradient_from, gradient_to, is_public,
    is_default_ygteev, created_by
  ) values (
    coalesce(nullif(trim(_draft.group_name), ''), _draft.church_name, 'Untitled Group'),
    coalesce(nullif(trim(_draft.church_name), ''), 'Untitled Church'),
    _draft.description,
    nullif(_full_address, ''),
    nullif(concat_ws(' ', _draft.meeting_day, _draft.meeting_time), ' '),
    _draft.latitude, _draft.longitude,
    _draft.logo_url,
    _gradient_from, _gradient_to,
    coalesce(_draft.public_on_map, true),
    false,
    _draft.user_id
  )
  returning id into _group_id;

  insert into public.youth_group_members (group_id, user_id, role)
  values (_group_id, _draft.user_id, 'pastor')
  on conflict (group_id, user_id) do update set role = 'pastor';

  insert into public.user_roles (user_id, role)
  values (_draft.user_id, 'pastor')
  on conflict (user_id, role) do nothing;

  update public.pastor_signup_drafts
     set stage = 'converted',
         finalized_youth_group_id = _group_id,
         updated_at = now()
   where id = _draft_id;

  return _group_id;
end $$;


ALTER FUNCTION "public"."finalize_pastor_signup"("_draft_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."for_you_feed"("_limit" integer DEFAULT 20, "_offset" integer DEFAULT 0, "_group_id" "uuid" DEFAULT NULL::"uuid") RETURNS TABLE("post_id" "uuid", "post_type" "text", "scope" "text", "group_id" "uuid", "group_name" "text", "source_kind" "text", "source_url" "text", "source_handle" "text", "title" "text", "caption" "text", "video_id" "uuid", "mux_playback_id" "text", "duration_sec" numeric, "aspect_ratio" "text", "slideshow_seconds_per_photo" numeric, "photos" "jsonb", "author_id" "uuid", "author_name" "text", "author_avatar" "text", "views_count" integer, "likes_count" integer, "has_viewed" boolean, "has_liked" boolean, "published_at" timestamp with time zone)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with mine as (
    select group_id from public.youth_group_members where user_id = auth.uid()
  ),
  selected_is_default as (
    select coalesce(
      (select is_default_ygteev from public.youth_groups where id = _group_id),
      false
    ) as v
  ),
  -- Same visibility rules as v1 (do not change without checking
  -- ygteev_official curation flow + group-private guarantees).
  visible as (
    select fp.*
    from public.feed_posts fp
    where fp.status = 'published'
      and (
        case
          when _group_id is null then
            fp.scope = 'ygteev_official'
            or (fp.scope = 'group' and fp.group_id in (select group_id from mine))
          when (select v from selected_is_default) then
            fp.scope = 'ygteev_official'
          else
            fp.scope = 'group'
            and fp.group_id = _group_id
            and fp.group_id in (select group_id from mine)
        end
      )
  ),
  -- Pre-compute per-post completion counts once.
  global_eng as (
    select e.post_id,
           count(*) filter (where e.watch_completed_at is not null)::int as completes
    from public.feed_post_engagement e
    group by e.post_id
  ),
  -- Caller's per-group completion share over last 30 days. Drives
  -- caller_affinity boost — users who actually finish a group's
  -- content get more of that group.
  user_affinity_raw as (
    select fp.group_id, count(*) filter (where e.watch_completed_at is not null)::int as my_completes
    from public.feed_post_engagement e
    join public.feed_posts fp on fp.id = e.post_id
    where e.user_id = auth.uid()
      and e.first_viewed_at >= now() - interval '30 days'
    group by fp.group_id
  ),
  user_affinity_total as (
    select coalesce(sum(my_completes), 0)::numeric as total
    from user_affinity_raw
  ),
  -- Score each visible post.
  scored as (
    select
      fp.*,
      eng.first_viewed_at as eng_first_viewed_at,
      eng.liked_at        as eng_liked_at,
      -- 1) seen_freshness
      case
        when eng.first_viewed_at is null                        then  1000::numeric
        when eng.first_viewed_at >  now() - interval '24 hours' then -2000::numeric
        when eng.first_viewed_at >  now() - interval '7 days'   then  -500::numeric
        when eng.first_viewed_at >  now() - interval '21 days'  then     0::numeric
        else                                                          200::numeric
      end as s_freshness,
      -- 2) publish_recency — half-life 7 days
      greatest(
        0,
        100 * exp(- (extract(epoch from now() - fp.published_at) / 86400.0) / 7)
      )::numeric as s_recency,
      -- 3) global_engagement — rate-based, normalized
      case when fp.views_count > 0 then
        (40 * (fp.likes_count::numeric / fp.views_count::numeric))
        + (60 * (coalesce(ge.completes, 0)::numeric / fp.views_count::numeric))
      else 0::numeric end as s_engagement,
      -- 4) caller_affinity — fraction of caller's completions that
      -- belonged to this post's group, capped via 80*(share).
      case when (select total from user_affinity_total) > 0 then
        80 * (coalesce(ua.my_completes, 0)::numeric / (select total from user_affinity_total))
      else 0::numeric end as s_affinity,
      -- 5) jitter — keeps sessions feeling fresh once a user has
      -- exhausted their library.
      (random() * 10)::numeric as s_jitter
    from visible fp
    left join public.feed_post_engagement eng
      on eng.post_id = fp.id and eng.user_id = auth.uid()
    left join global_eng ge        on ge.post_id  = fp.id
    left join user_affinity_raw ua on ua.group_id = fp.group_id
  ),
  -- 6) diversity penalty — N posts in a row from the same group lose
  -- 15 * (rank - 1) points within the group.
  with_pos as (
    select s.*,
           row_number() over (
             partition by s.group_id
             order by (s.s_freshness + s.s_recency + s.s_engagement
                       + s.s_affinity + s.s_jitter) desc,
                      s.published_at desc,
                      s.id desc
           ) as group_pos
    from scored s
  ),
  final as (
    select s.*,
      (s.s_freshness + s.s_recency + s.s_engagement + s.s_affinity + s.s_jitter
       - greatest(0, (s.group_pos - 1) * 15))::numeric as final_score
    from with_pos s
  )
  select
    fp.id as post_id,
    fp.post_type,
    fp.scope,
    fp.group_id,
    yg.name as group_name,
    fp.source_kind,
    fp.source_url,
    fp.source_handle,
    fp.title,
    fp.caption,
    fp.video_id,
    v.mux_playback_id,
    v.duration_sec,
    v.aspect_ratio,
    fp.slideshow_seconds_per_photo,
    coalesce(
      (select jsonb_agg(jsonb_build_object(
                'storage_path', ph.storage_path,
                'display_order', ph.display_order,
                'alt_text', ph.alt_text,
                'public_url',
                  'https://tkesywmshaicjmywbovn.supabase.co/storage/v1/object/public/feed-photos/' || ph.storage_path
              ) order by ph.display_order)
         from public.feed_post_photos ph where ph.post_id = fp.id),
      '[]'::jsonb
    ) as photos,
    fp.created_by as author_id,
    p.display_name as author_name,
    p.avatar_url   as author_avatar,
    fp.views_count,
    fp.likes_count,
    coalesce(fp.eng_first_viewed_at is not null, false) as has_viewed,
    coalesce(fp.eng_liked_at        is not null, false) as has_liked,
    fp.published_at
  from final fp
  left join public.youth_groups yg on yg.id = fp.group_id
  left join public.videos       v  on v.id  = fp.video_id
  left join public.profiles     p  on p.id  = fp.created_by
  order by fp.final_score desc, fp.published_at desc, fp.id desc
  offset greatest(0, _offset)
  limit  greatest(1, least(_limit, 50));
$$;


ALTER FUNCTION "public"."for_you_feed"("_limit" integer, "_offset" integer, "_group_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_random_handle"() RETURNS "text"
    LANGUAGE "plpgsql"
    AS $$
declare
  adjectives text[] := array[
    'Dangerous','Sneaky','Quick','Brave','Mighty','Stealth','Crystal','Phantom',
    'Cosmic','Frosty','Mystic','Wild','Lucky','Brilliant','Calm','Golden',
    'Silent','Swift','Eager','Fierce','Loyal','Bold','Sharp','Royal',
    'Epic','Smooth','Crafty','Daring','Nimble','Witty','Cheerful','Jolly',
    'Plucky','Zesty','Spry','Cunning','Bouncy','Speedy','Lively','Curious',
    'Sturdy','Vibrant','Radiant','Stoic','Hearty','Breezy','Sunny','Friendly',
    'Snappy','Clever'
  ];
  nouns text[] := array[
    'Table','Penguin','Wizard','Tiger','Eagle','Knight','Falcon','Lion',
    'Bear','Wolf','Fox','Cobra','Hawk','Panda','Otter','Dragon',
    'Phoenix','Hammer','Compass','Anchor','Beacon','Comet','Meteor','Lantern',
    'Glider','Rocket','Pirate','Ninja','Captain','Ranger','Scout','Hunter',
    'Warrior','Pilot','Sailor','Cowboy','Jester','Robot','Astronaut','Guardian',
    'Mariner','Voyager','Pioneer','Champion','Defender','Striker','Drifter','Maverick',
    'Sentry','Sage'
  ];
  candidate text;
  attempt int := 0;
begin
  loop
    attempt := attempt + 1;
    -- First 10 attempts: 2-digit suffix
    if attempt <= 10 then
      candidate :=
        adjectives[1 + floor(random() * array_length(adjectives, 1))::int]
        || nouns[1 + floor(random() * array_length(nouns, 1))::int]
        || (1 + floor(random() * 99))::text;
    else
      -- Fall back to 4-digit suffix
      candidate :=
        adjectives[1 + floor(random() * array_length(adjectives, 1))::int]
        || nouns[1 + floor(random() * array_length(nouns, 1))::int]
        || (100 + floor(random() * 9900))::text;
    end if;

    if not exists (
      select 1 from public.profiles where lower(handle) = lower(candidate)
    ) then
      return candidate;
    end if;

    if attempt > 50 then
      raise exception 'could_not_generate_unique_handle';
    end if;
  end loop;
end;
$$;


ALTER FUNCTION "public"."generate_random_handle"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_continue_card"() RETURNS TABLE("plan_id" "uuid", "plan_title" "text", "plan_slug" "text", "plan_gradient_from" "text", "plan_gradient_to" "text", "days_total" integer, "day_id" "uuid", "day_number" integer, "day_title" "text", "scripture_reference" "text", "steps_completed" "text"[], "is_resume" boolean)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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


ALTER FUNCTION "public"."get_continue_card"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_group_header_stats"("_group_id" "uuid") RETURNS TABLE("member_count" integer, "active_count" integer)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not (public.is_site_admin(auth.uid()) or public.is_group_member(auth.uid(), _group_id)) then
    raise exception 'not_authorized';
  end if;
  return query
  select
    (select count(*)::int from public.youth_group_members where group_id = _group_id),
    (select count(*)::int
       from public.youth_group_members ygm
       join public.profiles p on p.id = ygm.user_id
       where ygm.group_id = _group_id
         and p.last_opened_at >= now() - interval '90 days');
end $$;


ALTER FUNCTION "public"."get_group_header_stats"("_group_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_entitlements"() RETURNS TABLE("is_pro" boolean, "is_site_admin" boolean, "is_pastor" boolean, "is_parent" boolean, "can_create_events" boolean, "can_create_plans" boolean, "can_run_youth_group" boolean)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with me as (select auth.uid() as uid)
  select
    public.is_pro(me.uid),
    public.is_site_admin(me.uid),
    public.has_role(me.uid, 'pastor'),
    public.has_role(me.uid, 'parent'),
    -- TODO: tighten to Plus-plan-only when pastor plan_type lands
    (public.is_site_admin(me.uid)
      or exists (
        select 1 from public.youth_group_members
        where user_id = me.uid and role in ('pastor','leader')
      )),
    -- Plus-plan only; no pastor plan model yet -> admin only
    public.is_site_admin(me.uid),
    (public.is_site_admin(me.uid) or public.has_role(me.uid, 'pastor'))
  from me;
$$;


ALTER FUNCTION "public"."get_my_entitlements"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_plan_day_progress"("_plan_id" "uuid") RETURNS TABLE("day_id" "uuid", "day_number" integer, "title" "text", "scripture_reference" "text", "block_count" integer, "is_completed" boolean, "completed_at" timestamp with time zone, "step_xp_earned" integer, "step_water_earned" integer)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."get_my_plan_day_progress"("_plan_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_youth_group_plans"("_filter" "text" DEFAULT 'available'::"text") RETURNS TABLE("plan_id" "uuid", "title" "text", "group_id" "uuid", "group_name" "text", "days_total" integer, "days_completed" integer, "is_completed" boolean, "completed_at" timestamp with time zone, "gradient_index" integer, "header_kind" "text", "header_image_url" "text", "xp_reward" integer, "water_reward" integer, "visibility" "public"."bible_plan_visibility", "published_at" timestamp with time zone)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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


ALTER FUNCTION "public"."get_my_youth_group_plans"("_filter" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_pastor_signup_promo"("_code" "text") RETURNS TABLE("code" "text", "trial_days" integer, "label" "text", "valid" boolean)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    p.code,
    p.trial_days,
    p.label,
    (
      p.active = true
      and (p.expires_at is null or p.expires_at > now())
      and (p.max_uses   is null or p.uses_count < p.max_uses)
    ) as valid
  from public.pastor_signup_promos p
  where lower(p.code) = lower(coalesce(_code, ''))
  limit 1;
$$;


ALTER FUNCTION "public"."get_pastor_signup_promo"("_code" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_plan_progress"("_plan_id" "uuid") RETURNS TABLE("day_id" "uuid", "day_number" integer, "title" "text", "scripture_reference" "text", "reflection" "text", "day_complete" boolean, "steps_completed" "text"[], "day_xp_earned" integer, "day_completed_at" timestamp with time zone)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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


ALTER FUNCTION "public"."get_user_plan_progress"("_plan_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  default_group_id uuid;
  v_handle text;
  v_ext record;
begin
  v_handle := public.generate_random_handle();

  insert into public.profiles (id, email, display_name, handle, xp, water)
  values (
    new.id, new.email,
    coalesce(new.raw_user_meta_data->>'display_name', new.email),
    v_handle,
    3000, 27
  );
  insert into public.user_roles (user_id, role) values (new.id, 'member');

  select id into default_group_id from public.youth_groups where is_default_ygteev = true limit 1;
  if default_group_id is not null then
    insert into public.youth_group_members (group_id, user_id, role)
    values (default_group_id, new.id, 'member') on conflict do nothing;
  end if;

  -- NEW: claim any external RSVPs that match the signup email.
  if new.email is not null and length(new.email) > 0 then
    for v_ext in
      select * from public.event_external_rsvps
       where lower(email) = lower(new.email)
         and converted_to_user_id is null
    loop
      -- Mirror into the real event_rsvps table so the user sees the
      -- event in their account. on-conflict-do-nothing in case they
      -- already RSVPed via the app between us recording the external
      -- one and them signing up.
      begin
        insert into public.event_rsvps (event_id, user_id, status)
        values (v_ext.event_id, new.id, v_ext.status::rsvp_status)
        on conflict (event_id, user_id) do nothing;
      exception when others then
        -- Skip silently; we don't want signup to fail because of a
        -- bad enum cast or a missing event row.
        null;
      end;

      update public.event_external_rsvps
         set converted_to_user_id = new.id,
             converted_at = now()
       where id = v_ext.id;
    end loop;
  end if;

  return new;
end $$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."has_role"("_user_id" "uuid", "_role" "public"."app_role") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (select 1 from public.user_roles where user_id = _user_id and role = _role)
$$;


ALTER FUNCTION "public"."has_role"("_user_id" "uuid", "_role" "public"."app_role") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."heartbeat"() RETURNS "void"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  update public.profiles set last_opened_at = now() where id = auth.uid();
$$;


ALTER FUNCTION "public"."heartbeat"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."increment_pastor_signup_promo_uses"("_code" "text") RETURNS "void"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  update public.pastor_signup_promos
  set uses_count = uses_count + 1,
      updated_at = now()
  where lower(code) = lower(_code);
$$;


ALTER FUNCTION "public"."increment_pastor_signup_promo_uses"("_code" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_group_member"("_user_id" "uuid", "_group_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (select 1 from public.youth_group_members where user_id = _user_id and group_id = _group_id)
$$;


ALTER FUNCTION "public"."is_group_member"("_user_id" "uuid", "_group_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_group_pastor"("_user_id" "uuid", "_group_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1 from public.youth_group_members
    where user_id = _user_id and group_id = _group_id and role in ('pastor','leader')
  )
$$;


ALTER FUNCTION "public"."is_group_pastor"("_user_id" "uuid", "_group_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_in_family"("_family_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1 from public.family_members
    where family_id = _family_id and user_id = auth.uid()
  );
$$;


ALTER FUNCTION "public"."is_in_family"("_family_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_in_small_group"("_user_id" "uuid", "_small_group_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1 from public.small_group_members
    where user_id = _user_id and small_group_id = _small_group_id
  )
$$;


ALTER FUNCTION "public"."is_in_small_group"("_user_id" "uuid", "_small_group_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_pastor"() RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND role = 'pastor'
  );
END;
$$;


ALTER FUNCTION "public"."is_pastor"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_paying_subscriber"("_user_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1 from public.apple_subscriptions
    where user_id = _user_id
      and status in ('active', 'in_grace')
      and (expires_at is null or expires_at > now())
  );
$$;


ALTER FUNCTION "public"."is_paying_subscriber"("_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_pro"("_user_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    -- Direct: active Apple subscription
    exists (
      select 1 from public.apple_subscriptions
      where user_id = _user_id
        and status in ('active', 'in_grace')
        and (expires_at is null or expires_at > now())
    )
    -- Direct: user is themselves an active member of a non-default group
    or exists (
      select 1
      from public.youth_group_members ygm
      join public.youth_groups yg on yg.id = ygm.group_id
      join public.profiles p       on p.id  = ygm.user_id
      where ygm.user_id = _user_id
        and yg.is_default_ygteev = false
        and p.last_opened_at >= now() - interval '90 days'
    )
    -- NEW: caller is a parent whose child is in a non-default youth
    --      group, and the parent themselves is active.
    or exists (
      select 1
      from public.family_members fm_parent
      join public.family_members fm_child
        on fm_child.family_id = fm_parent.family_id
       and fm_child.role = 'child'
      join public.youth_group_members child_ygm
        on child_ygm.user_id = fm_child.user_id
      join public.youth_groups yg on yg.id = child_ygm.group_id
      join public.profiles parent_profile on parent_profile.id = fm_parent.user_id
      where fm_parent.user_id = _user_id
        and fm_parent.role    = 'parent'
        and yg.is_default_ygteev = false
        and parent_profile.last_opened_at >= now() - interval '90 days'
    );
$$;


ALTER FUNCTION "public"."is_pro"("_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_site_admin"("_user_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select public.has_role(_user_id, 'site_admin')
$$;


ALTER FUNCTION "public"."is_site_admin"("_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_small_group_leader"("_user_id" "uuid", "_small_group_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1 from public.small_group_members
    where user_id = _user_id and small_group_id = _small_group_id and role = 'leader'
  )
$$;


ALTER FUNCTION "public"."is_small_group_leader"("_user_id" "uuid", "_small_group_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_thread_subscriber"("_thread_id" "uuid", "_user_id" "uuid" DEFAULT NULL::"uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1 from public.thread_subscribers
    where thread_id = _thread_id
      and user_id = coalesce(_user_id, auth.uid())
  );
$$;


ALTER FUNCTION "public"."is_thread_subscriber"("_thread_id" "uuid", "_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."join_group_via_qr_scan"("_group_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_uid             uuid := auth.uid();
  v_yg              public.youth_groups;
  v_existing_member uuid;
  v_pending_request uuid;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  select * into v_yg from public.youth_groups where id = _group_id;
  if v_yg.id is null then
    raise exception 'group_not_found' using errcode = '22023';
  end if;
  if coalesce(v_yg.is_public, false) = false then
    raise exception 'group_not_public' using errcode = '42501';
  end if;

  -- Already a member? Idempotent return.
  select id into v_existing_member
  from public.youth_group_members
  where group_id = _group_id and user_id = v_uid;

  if v_existing_member is not null then
    return jsonb_build_object(
      'ok',             true,
      'group_id',       _group_id,
      'group_name',     v_yg.name,
      'already_member', true,
      'newly_joined',   false
    );
  end if;

  -- Auto-approve any pending request from this user for this group.
  -- Without this, the request_to_join_group flow would leave a stale
  -- pending row hanging around forever once they're joined.
  update public.youth_group_join_requests
  set status      = 'approved',
      decided_at  = now(),
      decided_by  = v_uid  -- self-approved via QR scan
  where group_id = _group_id
    and user_id  = v_uid
    and status   = 'pending'
  returning id into v_pending_request;

  -- Insert membership. The chat_on_ygm_insert trigger handles
  -- subscribing the user to the relevant chat threads (group_main,
  -- dm_pastor, etc.) automatically.
  insert into public.youth_group_members (group_id, user_id, role)
  values (_group_id, v_uid, 'member');

  return jsonb_build_object(
    'ok',                 true,
    'group_id',           _group_id,
    'group_name',         v_yg.name,
    'already_member',     false,
    'newly_joined',       true,
    'pending_request_auto_approved', v_pending_request is not null
  );
end;
$$;


ALTER FUNCTION "public"."join_group_via_qr_scan"("_group_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."level_for_xp"("_xp" bigint) RETURNS integer
    LANGUAGE "sql" IMMUTABLE PARALLEL SAFE
    AS $$
  select greatest(
    1,
    floor((1 + sqrt(1 + greatest(_xp, 0)::numeric / 125)) / 2)::int
  );
$$;


ALTER FUNCTION "public"."level_for_xp"("_xp" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_my_families"() RETURNS TABLE("family_id" "uuid", "family_name" "text", "my_role" "text", "members" "jsonb", "created_at" timestamp with time zone)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with mine as (
    select fm.family_id, fm.role as my_role
    from public.family_members fm where fm.user_id = auth.uid()
  )
  select f.id, f.name, m.my_role,
    coalesce(
      (select jsonb_agg(jsonb_build_object(
                'user_id', fm.user_id, 'role', fm.role, 'joined_at', fm.joined_at,
                'display_name', p.display_name, 'avatar_url', p.avatar_url, 'email', p.email
              ) order by fm.role desc, fm.joined_at)
         from public.family_members fm
         join public.profiles p on p.id = fm.user_id
         where fm.family_id = f.id),
      '[]'::jsonb),
    f.created_at
  from public.families f
  join mine m on m.family_id = f.id
  where f.deleted_at is null
  order by f.created_at desc;
$$;


ALTER FUNCTION "public"."list_my_families"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_my_pending_family_invites"() RETURNS TABLE("invite_id" "uuid", "family_id" "uuid", "family_name" "text", "pairing_code" "text", "inviter_id" "uuid", "inviter_name" "text", "inviter_avatar" "text", "created_at" timestamp with time zone, "expires_at" timestamp with time zone)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  -- Sweep stale rows first
  with sweep as (
    update public.family_invites
       set status = 'expired'
     where status = 'pending' and expires_at <= now()
     returning 1
  )
  select
    fi.id            as invite_id,
    fi.family_id,
    f.name           as family_name,
    fi.pairing_code,
    fi.created_by    as inviter_id,
    p.display_name   as inviter_name,
    p.avatar_url     as inviter_avatar,
    fi.created_at,
    fi.expires_at
  from public.family_invites fi
  join public.families f on f.id = fi.family_id
  join public.profiles p on p.id = fi.created_by
  where fi.invited_user_id = auth.uid()
    and fi.status = 'pending'
    and fi.expires_at > now()
  order by fi.created_at desc;
$$;


ALTER FUNCTION "public"."list_my_pending_family_invites"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_my_threads"() RETURNS TABLE("thread_id" "uuid", "kind" "public"."thread_kind", "group_id" "uuid", "group_name" "text", "group_gradient_from" "text", "group_gradient_to" "text", "small_group_id" "uuid", "small_group_name" "text", "dm_other_user_id" "uuid", "dm_other_display" "text", "dm_other_avatar_url" "text", "dm_other_role" "text", "last_message_body" "text", "last_message_sender" "text", "last_message_at" timestamp with time zone, "unread_count" integer)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with my_subs as (
    select s.thread_id, s.last_read_at
    from public.thread_subscribers s
    where s.user_id = auth.uid()
  ),
  last_msgs as (
    select distinct on (m.thread_id)
      m.thread_id, m.body, m.sender_id, m.created_at
    from public.messages m
    join my_subs ms on ms.thread_id = m.thread_id
    order by m.thread_id, m.created_at desc
  ),
  dm_other as (
    select ts.thread_id, ts.user_id,
           p.display_name, p.avatar_url, p.grade_year
    from public.thread_subscribers ts
    join public.chat_threads t on t.id = ts.thread_id
    join public.profiles p on p.id = ts.user_id
    where ts.user_id <> auth.uid()
      and t.kind in ('dm_pastor'::thread_kind,
                     'dm_leader'::thread_kind,
                     'dm_parent_pastor'::thread_kind,
                     'dm_parent_leader'::thread_kind)
      and ts.thread_id in (select thread_id from my_subs)
  )
  select
    t.id,
    t.kind,
    t.group_id,
    yg.name,
    yg.gradient_from,
    yg.gradient_to,
    t.small_group_id,
    sg.name,
    dmo.user_id        as dm_other_user_id,
    dmo.display_name   as dm_other_display,
    dmo.avatar_url     as dm_other_avatar_url,
    case
      when dmo.user_id is null then null
      when exists (
        select 1 from public.youth_group_members ygm
        where ygm.group_id = t.group_id
          and ygm.user_id = dmo.user_id
          and ygm.role = 'pastor'
      ) then 'pastor'
      when exists (
        select 1
        from public.small_group_members sgm
        join public.small_groups sg2 on sg2.id = sgm.small_group_id
        where sgm.user_id = dmo.user_id
          and sgm.role = 'leader'
          and sg2.youth_group_id = t.group_id
      ) then 'leader'
      when exists (
        select 1
        from public.family_members fm_parent
        join public.family_members fm_child
          on fm_child.family_id = fm_parent.family_id and fm_child.role = 'child'
        join public.youth_group_members child_ygm
          on child_ygm.user_id = fm_child.user_id and child_ygm.group_id = t.group_id
        where fm_parent.user_id = dmo.user_id and fm_parent.role = 'parent'
      ) then 'parent'
      when exists (
        select 1 from public.youth_group_members ygm
        where ygm.group_id = t.group_id
          and ygm.user_id = dmo.user_id
      ) then case when dmo.grade_year is not null then 'student' else 'member' end
      else null
    end as dm_other_role,
    lm.body,
    case when lm.sender_id = auth.uid() then 'You'
         else (select display_name from public.profiles where id = lm.sender_id) end,
    lm.created_at,
    coalesce((
      select count(*)::int from public.messages m2
      where m2.thread_id = t.id
        and m2.created_at > coalesce(ms.last_read_at, '-infinity'::timestamptz)
        and m2.sender_id <> auth.uid()
    ), 0)
  from public.chat_threads t
  join my_subs ms on ms.thread_id = t.id
  left join public.youth_groups yg on yg.id = t.group_id
  left join public.small_groups  sg on sg.id = t.small_group_id
  left join last_msgs            lm on lm.thread_id = t.id
  left join dm_other             dmo on dmo.thread_id = t.id
  order by
    -- Tier 1: group-style threads pinned to the top
    case t.kind
      when 'group_main'::thread_kind  then 0
      when 'small_group'::thread_kind then 0
      when 'parent_chat'::thread_kind then 0
      else 1
    end,
    -- Within tier, most recent activity first
    coalesce(lm.created_at, t.created_at) desc;
$$;


ALTER FUNCTION "public"."list_my_threads"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mark_thread_read"("_thread_id" "uuid") RETURNS "void"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  update public.thread_subscribers
     set last_read_at = now()
   where thread_id = _thread_id and user_id = auth.uid();
$$;


ALTER FUNCTION "public"."mark_thread_read"("_thread_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."my_event_carousels"() RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_uid      uuid := auth.uid();
  v_self     jsonb;
  v_children jsonb;
begin
  if v_uid is null then
    raise exception 'not-authenticated';
  end if;

  with self_profile as (
    select id, display_name, avatar_url
    from public.profiles where id = v_uid
  ),
  self_events as (
    select
      r.status::text                                    as my_status,
      e.id                                              as event_id,
      e.title,
      e.description,
      e.starts_at,
      e.location,
      e.cover_url,
      yg.id                                             as group_id,
      yg.name                                           as group_name,
      yg.church_name                                    as group_church_name,
      yg.logo_url                                       as group_logo_url,
      yg.gradient_from                                  as group_gradient_from,
      yg.gradient_to                                    as group_gradient_to,
      (
        (select count(*)::int from public.event_rsvps r2
          where r2.event_id = e.id and r2.status::text = 'going')
        +
        (select count(*)::int from public.event_external_rsvps x
          where x.event_id = e.id and x.status = 'going'
            and x.converted_to_user_id is null)
      )                                                 as going_count,
      (e.starts_at > now())                             as is_upcoming
    from public.event_rsvps r
    join public.events e        on e.id  = r.event_id
    join public.youth_groups yg on yg.id = e.group_id
    where r.user_id = v_uid
      and r.status::text in ('going','maybe')
      and e.starts_at > now() - interval '90 days'
  )
  select jsonb_build_object(
    'user_id',      sp.id,
    'display_name', coalesce(sp.display_name, 'You'),
    'avatar_url',   sp.avatar_url,
    'upcoming',     coalesce(
      (select jsonb_agg(to_jsonb(se) order by se.starts_at asc)
       from self_events se where se.is_upcoming),
      '[]'::jsonb
    ),
    'past',         coalesce(
      (select jsonb_agg(to_jsonb(se) order by se.starts_at desc)
       from self_events se where not se.is_upcoming),
      '[]'::jsonb
    )
  )
  into v_self
  from self_profile sp;

  with my_families as (
    select family_id from public.family_members
    where user_id = v_uid and role = 'parent'
  ),
  kid_ids as (
    select distinct user_id
    from public.family_members
    where family_id in (select family_id from my_families)
      and role = 'child'
  ),
  kid_events as (
    select
      p.id                                              as kid_user_id,
      coalesce(p.display_name, p.handle, 'Family member') as kid_display_name,
      p.avatar_url                                      as kid_avatar_url,
      r.status::text                                    as my_status,
      e.id                                              as event_id,
      e.title,
      e.description,
      e.starts_at,
      e.location,
      e.cover_url,
      yg.id                                             as group_id,
      yg.name                                           as group_name,
      yg.church_name                                    as group_church_name,
      yg.logo_url                                       as group_logo_url,
      yg.gradient_from                                  as group_gradient_from,
      yg.gradient_to                                    as group_gradient_to,
      (
        (select count(*)::int from public.event_rsvps r2
          where r2.event_id = e.id and r2.status::text = 'going')
        +
        (select count(*)::int from public.event_external_rsvps x
          where x.event_id = e.id and x.status = 'going'
            and x.converted_to_user_id is null)
      )                                                 as going_count,
      (e.starts_at > now())                             as is_upcoming
    from public.profiles p
    join public.event_rsvps r on r.user_id = p.id
    join public.events e         on e.id  = r.event_id
    join public.youth_groups yg  on yg.id = e.group_id
    where p.id in (select user_id from kid_ids)
      and r.status::text in ('going','maybe')
      and e.starts_at > now() - interval '90 days'
  ),
  kid_blocks as (
    select
      ke.kid_user_id      as user_id,
      ke.kid_display_name as display_name,
      ke.kid_avatar_url   as avatar_url,
      coalesce((
        select jsonb_agg(
                 to_jsonb(t) - 'kid_user_id' - 'kid_display_name' - 'kid_avatar_url'
                 order by t.starts_at asc
               )
        from kid_events t
        where t.kid_user_id = ke.kid_user_id and t.is_upcoming
      ), '[]'::jsonb) as upcoming,
      coalesce((
        select jsonb_agg(
                 to_jsonb(t) - 'kid_user_id' - 'kid_display_name' - 'kid_avatar_url'
                 order by t.starts_at desc
               )
        from kid_events t
        where t.kid_user_id = ke.kid_user_id and not t.is_upcoming
      ), '[]'::jsonb) as past
    from kid_events ke
    group by ke.kid_user_id, ke.kid_display_name, ke.kid_avatar_url
  ),
  kid_blocks_all as (
    -- Include kids with zero events so we can still show their empty-state.
    select
      p.id                                                as user_id,
      coalesce(p.display_name, p.handle, 'Family member') as display_name,
      p.avatar_url                                        as avatar_url,
      coalesce(kb.upcoming, '[]'::jsonb)                  as upcoming,
      coalesce(kb.past,     '[]'::jsonb)                  as past
    from public.profiles p
    left join kid_blocks kb on kb.user_id = p.id
    where p.id in (select user_id from kid_ids)
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'user_id',      kb.user_id,
        'display_name', kb.display_name,
        'avatar_url',   kb.avatar_url,
        'upcoming',     kb.upcoming,
        'past',         kb.past
      )
      order by kb.display_name asc
    ),
    '[]'::jsonb
  )
  into v_children
  from kid_blocks_all kb;

  return jsonb_build_object(
    'self',     v_self,
    'children', v_children
  );
end;
$$;


ALTER FUNCTION "public"."my_event_carousels"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pastor_active_user_count"("_pastor_user_id" "uuid") RETURNS integer
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with pastor_groups as (
    select group_id
    from public.youth_group_members
    where user_id = _pastor_user_id and role = 'pastor'
  ),
  direct_active as (
    -- Members / leaders / pastor themselves, recently active
    select distinct p.id as user_id
    from public.youth_group_members ygm
    join public.profiles p on p.id = ygm.user_id
    where ygm.group_id in (select group_id from pastor_groups)
      and p.last_opened_at >= now() - interval '90 days'
  ),
  parent_active as (
    -- Parents of children in any of this pastor's groups, gated on
    -- the parent's own activity.
    select distinct parent_p.id as user_id
    from public.youth_group_members child_ygm
    join public.family_members fm_child
      on fm_child.user_id = child_ygm.user_id and fm_child.role = 'child'
    join public.family_members fm_parent
      on fm_parent.family_id = fm_child.family_id and fm_parent.role = 'parent'
    join public.profiles parent_p on parent_p.id = fm_parent.user_id
    where child_ygm.group_id in (select group_id from pastor_groups)
      and parent_p.last_opened_at >= now() - interval '90 days'
  )
  select count(*)::int from (
    select user_id from direct_active
    union
    select user_id from parent_active
  ) all_active;
$$;


ALTER FUNCTION "public"."pastor_active_user_count"("_pastor_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pastor_approve_alert"("_alert_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_caller   uuid := auth.uid();
  v_alert    public.moderation_alerts;
  v_new_id   uuid;
begin
  if v_caller is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  select * into v_alert from public.moderation_alerts where id = _alert_id;
  if v_alert.id is null then
    raise exception 'alert_not_found' using errcode = '22023';
  end if;
  if not (is_group_pastor(v_caller, v_alert.group_id) or is_site_admin(v_caller)) then
    raise exception 'forbidden: not a pastor of this group' using errcode = '42501';
  end if;

  if v_alert.message_id is not null then
    -- Allowed flag: message already exists in messages table; just
    -- mark it clean so it stops looking flagged in chat.
    update public.messages
    set moderation_status = 'clean'::moderation_status
    where id = v_alert.message_id;
    v_new_id := v_alert.message_id;
  else
    -- Blocked flag: never made it to messages. Insert the original
    -- text now under the pastor's override.
    insert into public.messages (
      thread_id, sender_id, body,
      moderation_status, moderation_categories
    )
    values (
      v_alert.thread_id, v_alert.sender_id,
      coalesce(v_alert.preview, ''),
      'clean'::moderation_status,
      coalesce(v_alert.categories, '{}'::jsonb)
                          || jsonb_build_object('pastor_override', true)
    )
    returning id into v_new_id;

    -- Bump the thread's last_message_at so the chat surfaces it.
    update public.chat_threads
    set last_message_at = now()
    where id = v_alert.thread_id;
  end if;

  update public.moderation_alerts
  set acknowledged_at = now(),
      acknowledged_by = v_caller
  where id = _alert_id;

  return jsonb_build_object(
    'ok',           true,
    'alert_id',     _alert_id,
    'message_id',   v_new_id,
    'inserted_new', v_alert.message_id is null
  );
end;
$$;


ALTER FUNCTION "public"."pastor_approve_alert"("_alert_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pastor_approve_join_request"("_request_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_caller uuid := auth.uid();
  v_req public.youth_group_join_requests;
begin
  if v_caller is null then raise exception 'not_authenticated'; end if;

  select * into v_req from public.youth_group_join_requests where id = _request_id;
  if v_req.id is null then raise exception 'request_not_found'; end if;

  if not public._pastor_can_view_group(v_req.group_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  if v_req.status <> 'pending' then
    raise exception 'request_already_decided';
  end if;

  -- Add as a member (idempotent on conflict)
  insert into public.youth_group_members (group_id, user_id, role)
  values (v_req.group_id, v_req.user_id, 'member')
  on conflict (group_id, user_id) do nothing;

  update public.youth_group_join_requests
     set status      = 'approved',
         decided_at  = now(),
         decided_by  = v_caller
   where id = _request_id;

  return v_req.user_id;
end;
$$;


ALTER FUNCTION "public"."pastor_approve_join_request"("_request_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pastor_archive_feed_post"("_post_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not public._can_manage_feed_post(_post_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  update public.feed_posts set status = 'archived', updated_at = now() where id = _post_id;
end;
$$;


ALTER FUNCTION "public"."pastor_archive_feed_post"("_post_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pastor_archive_plan"("_plan_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not public._pastor_can_edit_plan(_plan_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  update public.bible_plans
    set status     = 'archived'::bible_plan_status,
        updated_at = now()
    where id = _plan_id;
end;
$$;


ALTER FUNCTION "public"."pastor_archive_plan"("_plan_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pastor_attach_slideshow_photos"("_post_id" "uuid", "_photos" "jsonb") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_inserted int := 0;
  v_row jsonb;
  v_existing_count int;
begin
  if not public._can_manage_feed_post(_post_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  -- Validate the parent post is a slideshow
  if not exists (
    select 1 from public.feed_posts
    where id = _post_id and post_type = 'slideshow'
  ) then
    raise exception 'post_not_slideshow';
  end if;

  -- Replace any existing photos (simpler model: reset every save)
  delete from public.feed_post_photos where post_id = _post_id;

  for v_row in select * from jsonb_array_elements(_photos)
  loop
    insert into public.feed_post_photos
      (post_id, storage_path, display_order, alt_text)
    values (
      _post_id,
      v_row->>'storage_path',
      coalesce((v_row->>'display_order')::int, v_inserted),
      v_row->>'alt_text'
    );
    v_inserted := v_inserted + 1;
  end loop;

  return v_inserted;
end;
$$;


ALTER FUNCTION "public"."pastor_attach_slideshow_photos"("_post_id" "uuid", "_photos" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pastor_attach_video_to_post"("_post_id" "uuid", "_video_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not public._can_manage_feed_post(_post_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.videos
    where id = _video_id and (created_by = auth.uid() or public.is_site_admin(auth.uid()))
  ) then
    raise exception 'video_not_owned';
  end if;

  update public.feed_posts
    set video_id = _video_id,
        updated_at = now()
    where id = _post_id and post_type = 'video';
end;
$$;


ALTER FUNCTION "public"."pastor_attach_video_to_post"("_post_id" "uuid", "_video_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pastor_clear_instagram_source"("_source_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare v_group uuid;
begin
  select group_id into v_group from public.instagram_sources where id = _source_id;
  if v_group is null then raise exception 'source_not_found'; end if;

  if not (public.is_site_admin(auth.uid()) or public.is_group_pastor(auth.uid(), v_group)) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  update public.instagram_sources set is_active = false where id = _source_id;
end;
$$;


ALTER FUNCTION "public"."pastor_clear_instagram_source"("_source_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pastor_create_feed_slideshow_post"("_group_id" "uuid", "_title" "text" DEFAULT NULL::"text", "_caption" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_caller uuid := auth.uid();
  v_post_id uuid;
begin
  if v_caller is null then raise exception 'not_authenticated'; end if;
  if not (public.is_site_admin(v_caller) or public.is_group_pastor(v_caller, _group_id)) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  insert into public.feed_posts (
    post_type, scope, group_id, source_kind,
    title, caption, status, created_by
  ) values (
    'slideshow', 'group', _group_id, 'pastor_upload',
    nullif(trim(_title), ''), nullif(trim(_caption), ''),
    'draft', v_caller
  )
  returning id into v_post_id;

  return v_post_id;
end;
$$;


ALTER FUNCTION "public"."pastor_create_feed_slideshow_post"("_group_id" "uuid", "_title" "text", "_caption" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pastor_create_plan"("_group_id" "uuid", "_title" "text", "_days" integer, "_gradient_idx" integer DEFAULT 0, "_visibility" "text" DEFAULT 'private'::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."pastor_create_plan"("_group_id" "uuid", "_title" "text", "_days" integer, "_gradient_idx" integer, "_visibility" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pastor_create_plan"("_group_id" "uuid", "_title" "text", "_days" integer, "_gradient_idx" integer DEFAULT 0, "_visibility" "text" DEFAULT 'private'::"text", "_additional_group_ids" "uuid"[] DEFAULT NULL::"uuid"[]) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."pastor_create_plan"("_group_id" "uuid", "_title" "text", "_days" integer, "_gradient_idx" integer, "_visibility" "text", "_additional_group_ids" "uuid"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pastor_dashboard"("_group_id" "uuid") RETURNS TABLE("group_id" "uuid", "group_name" "text", "logo_url" "text", "member_count" integer, "small_group_count" integer, "pending_request_count" integer, "active_this_week" integer, "active_last_week" integer, "active_this_week_pct" integer, "active_last_week_pct" integer, "total_group_xp" bigint, "total_group_water" bigint)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with allowed as (select public._pastor_can_view_group(_group_id) as ok),
  -- Every user counted toward "members" of this group: direct + parents
  related_users as (
    select p.id as user_id, p.last_opened_at
    from public.youth_group_members ygm
    join public.profiles p on p.id = ygm.user_id
    where ygm.group_id = _group_id
    union
    select parent_p.id, parent_p.last_opened_at
    from public.youth_group_members child_ygm
    join public.family_members fm_child
      on fm_child.user_id = child_ygm.user_id and fm_child.role = 'child'
    join public.family_members fm_parent
      on fm_parent.family_id = fm_child.family_id and fm_parent.role = 'parent'
    join public.profiles parent_p on parent_p.id = fm_parent.user_id
    where child_ygm.group_id = _group_id
  )
  select
    yg.id           as group_id,
    yg.name         as group_name,
    yg.logo_url     as logo_url,
    (select count(*)::int from related_users)                                 as member_count,
    (select count(*)::int from public.small_groups
       where youth_group_id = yg.id)                                          as small_group_count,
    (select count(*)::int from public.youth_group_join_requests
       where group_id = yg.id and status = 'pending')                         as pending_request_count,
    (select count(*)::int from related_users
       where last_opened_at >= now() - interval '7 days')                     as active_this_week,
    (select count(*)::int from related_users
       where last_opened_at >= now() - interval '14 days'
         and last_opened_at  < now() - interval '7 days')                     as active_last_week,
    (select case when count(*) = 0 then 0
            else round((count(*) filter (where last_opened_at >= now() - interval '7 days'))::numeric
                       / count(*)::numeric * 100)::int end
       from related_users)                                                    as active_this_week_pct,
    (select case when count(*) = 0 then 0
            else round((count(*) filter (
                          where last_opened_at >= now() - interval '14 days'
                            and last_opened_at  < now() - interval '7 days'))::numeric
                       / count(*)::numeric * 100)::int end
       from related_users)                                                    as active_last_week_pct,
    -- Group XP/water totals remain MEMBERS-ONLY by design — parents
    -- don't earn XP from this group's plans.
    (select coalesce(sum(p.xp), 0)::bigint
       from public.youth_group_members ygm
       join public.profiles p on p.id = ygm.user_id
      where ygm.group_id = yg.id)                                             as total_group_xp,
    (select coalesce(sum(p.water), 0)::bigint
       from public.youth_group_members ygm
       join public.profiles p on p.id = ygm.user_id
      where ygm.group_id = yg.id)                                             as total_group_water
  from public.youth_groups yg, allowed
  where yg.id = _group_id and allowed.ok;
$$;


ALTER FUNCTION "public"."pastor_dashboard"("_group_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pastor_delete_feed_post"("_post_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not public._can_manage_feed_post(_post_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  delete from public.feed_posts where id = _post_id;
end;
$$;


ALTER FUNCTION "public"."pastor_delete_feed_post"("_post_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pastor_delete_plan"("_plan_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not public._pastor_can_edit_plan(_plan_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  -- Days cascade only if FK has on delete cascade; play it safe and clear them.
  delete from public.bible_plan_days where plan_id = _plan_id;
  delete from public.bible_plans where id = _plan_id;
end;
$$;


ALTER FUNCTION "public"."pastor_delete_plan"("_plan_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pastor_deny_join_request"("_request_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_caller uuid := auth.uid();
  v_req public.youth_group_join_requests;
begin
  if v_caller is null then raise exception 'not_authenticated'; end if;

  select * into v_req from public.youth_group_join_requests where id = _request_id;
  if v_req.id is null then raise exception 'request_not_found'; end if;

  if not public._pastor_can_view_group(v_req.group_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  if v_req.status <> 'pending' then return; end if;

  update public.youth_group_join_requests
     set status      = 'denied',
         decided_at  = now(),
         decided_by  = v_caller
   where id = _request_id;
end;
$$;


ALTER FUNCTION "public"."pastor_deny_join_request"("_request_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pastor_list_group_members"("_group_id" "uuid", "_role_filter" "text" DEFAULT 'all'::"text", "_active_only" boolean DEFAULT false) RETURNS TABLE("user_id" "uuid", "display_name" "text", "email" "text", "avatar_url" "text", "role" "text", "grade_year" integer, "is_parent" boolean, "linked_child_names" "text"[], "joined_at" timestamp with time zone, "last_opened_at" timestamp with time zone, "xp" integer, "water" integer, "streak" integer, "is_active_week" boolean)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with pastor_ok as (
    select (public.is_site_admin(auth.uid())
            or public.is_group_pastor(auth.uid(), _group_id)) as ok
  ),
  direct_rows as (
    -- Anyone in `youth_group_members` for this group
    select
      p.id            as user_id,
      p.display_name,
      p.email,
      p.avatar_url,
      ygm.role::text  as role,
      p.grade_year,
      exists (
        select 1 from public.profiles c
        where c.parent_account_id = p.id
      )               as is_parent,
      null::text[]    as linked_child_names,
      ygm.joined_at,
      p.last_opened_at,
      p.xp, p.water, p.streak,
      (p.last_opened_at >= now() - interval '7 days') as is_active_week
    from public.youth_group_members ygm
    join public.profiles p on p.id = ygm.user_id
    where ygm.group_id = _group_id
  ),
  parent_rows as (
    -- Parents of children in this group, NOT already a direct member
    select
      parent_p.id     as user_id,
      parent_p.display_name,
      parent_p.email,
      parent_p.avatar_url,
      'parent'::text  as role,
      parent_p.grade_year,
      true            as is_parent,
      array_agg(distinct coalesce(child_p.display_name, child_p.email)
                order by coalesce(child_p.display_name, child_p.email))
                      as linked_child_names,
      min(fm_child.joined_at) as joined_at,
      parent_p.last_opened_at,
      parent_p.xp, parent_p.water, parent_p.streak,
      (parent_p.last_opened_at >= now() - interval '7 days') as is_active_week
    from public.youth_group_members child_ygm
    join public.family_members fm_child
      on fm_child.user_id = child_ygm.user_id and fm_child.role = 'child'
    join public.family_members fm_parent
      on fm_parent.family_id = fm_child.family_id and fm_parent.role = 'parent'
    join public.profiles parent_p on parent_p.id = fm_parent.user_id
    join public.profiles child_p  on child_p.id  = child_ygm.user_id
    where child_ygm.group_id = _group_id
      and not exists (
        select 1 from public.youth_group_members ygm
        where ygm.group_id = _group_id and ygm.user_id = parent_p.id
      )
    group by parent_p.id, parent_p.display_name, parent_p.email,
             parent_p.avatar_url, parent_p.grade_year,
             parent_p.last_opened_at, parent_p.xp, parent_p.water, parent_p.streak
  ),
  combined as (
    select * from direct_rows
    union all
    select * from parent_rows
  )
  select *
  from combined
  where (select ok from pastor_ok)
    and (_role_filter = 'all' or role = _role_filter)
    and (not _active_only or last_opened_at >= now() - interval '90 days')
  order by
    case role
      when 'pastor' then 0
      when 'leader' then 1
      when 'member' then 2
      when 'parent' then 3
    end,
    display_name nulls last;
$$;


ALTER FUNCTION "public"."pastor_list_group_members"("_group_id" "uuid", "_role_filter" "text", "_active_only" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pastor_list_join_requests"("_group_id" "uuid") RETURNS TABLE("request_id" "uuid", "user_id" "uuid", "display_name" "text", "avatar_url" "text", "email" "text", "grade_year" integer, "is_parent" boolean, "message" "text", "requested_at" timestamp with time zone)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with allowed as (select public._pastor_can_view_group(_group_id) as ok)
  select
    r.id          as request_id,
    r.user_id,
    p.display_name,
    p.avatar_url,
    p.email,
    p.grade_year,
    exists (
      select 1 from public.profiles c
      where c.parent_account_id = p.id
    )             as is_parent,
    r.message,
    r.requested_at
  from public.youth_group_join_requests r
  join public.profiles p on p.id = r.user_id
  cross join allowed
  where r.group_id = _group_id
    and r.status   = 'pending'
    and allowed.ok
  order by r.requested_at desc;
$$;


ALTER FUNCTION "public"."pastor_list_join_requests"("_group_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pastor_list_my_plans"() RETURNS TABLE("plan_id" "uuid", "title" "text", "status" "public"."bible_plan_status", "visibility" "public"."bible_plan_visibility", "days_total" integer, "ready_day_count" integer, "total_blocks" integer, "xp_reward" integer, "water_reward" integer, "gradient_index" integer, "header_kind" "text", "header_image_url" "text", "group_id" "uuid", "group_name" "text", "additional_group_ids" "uuid"[], "started_count" integer, "completed_count" integer, "created_at" timestamp with time zone, "updated_at" timestamp with time zone, "published_at" timestamp with time zone)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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


ALTER FUNCTION "public"."pastor_list_my_plans"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pastor_list_small_groups"("_group_id" "uuid") RETURNS TABLE("small_group_id" "uuid", "name" "text", "description" "text", "meeting_day" "text", "meeting_time" "text", "member_count" integer, "leader_count" integer, "leader_names" "text"[], "created_at" timestamp with time zone)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with allowed as (select public._pastor_can_view_group(_group_id) as ok)
  select
    sg.id            as small_group_id,
    sg.name,
    sg.description,
    sg.meeting_day,
    sg.meeting_time,
    (select count(*)::int from public.small_group_members where small_group_id = sg.id) as member_count,
    (select count(*)::int from public.small_group_members
        where small_group_id = sg.id and role = 'leader') as leader_count,
    (select coalesce(array_agg(coalesce(p.display_name, p.email)
              order by p.display_name nulls last, p.email),
              array[]::text[])
       from public.small_group_members sgm
       join public.profiles p on p.id = sgm.user_id
      where sgm.small_group_id = sg.id and sgm.role = 'leader') as leader_names,
    sg.created_at
  from public.small_groups sg
  cross join allowed
  where sg.youth_group_id = _group_id
    and allowed.ok
  order by sg.name;
$$;


ALTER FUNCTION "public"."pastor_list_small_groups"("_group_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pastor_member_profile"("_group_id" "uuid", "_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_caller uuid := auth.uid();
  v_profile public.profiles;
  v_role text;
  v_is_parent boolean;
  v_linked_children text[];
  v_joined_at timestamptz;
  v_sg jsonb;
  v_att jsonb;
  v_events jsonb;
begin
  if v_caller is null then raise exception 'not_authenticated'; end if;
  if not (public.is_site_admin(v_caller) or public.is_group_pastor(v_caller, _group_id)) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  select * into v_profile from public.profiles where id = _user_id;
  if v_profile.id is null then raise exception 'user_not_found'; end if;

  -- Role + join info: direct membership first, else parent connection
  select role::text, joined_at into v_role, v_joined_at
  from public.youth_group_members
  where group_id = _group_id and user_id = _user_id;

  if v_role is null then
    -- Check parent-of-child path
    select min(fm_child.joined_at) into v_joined_at
    from public.family_members fm_parent
    join public.family_members fm_child
      on fm_child.family_id = fm_parent.family_id and fm_child.role = 'child'
    join public.youth_group_members child_ygm
      on child_ygm.user_id = fm_child.user_id
    where fm_parent.user_id = _user_id and fm_parent.role = 'parent'
      and child_ygm.group_id = _group_id;
    if v_joined_at is not null then
      v_role := 'parent';
    end if;
  end if;

  if v_role is null then
    raise exception 'user_not_in_group';
  end if;

  -- Has children (anywhere)?
  v_is_parent := exists (
    select 1 from public.profiles c where c.parent_account_id = _user_id
  );

  -- Children of this user that are direct members of THIS group
  select coalesce(array_agg(distinct
           coalesce(child_p.display_name, child_p.email)
           order by coalesce(child_p.display_name, child_p.email)), '{}'::text[])
    into v_linked_children
  from public.family_members fm_parent
  join public.family_members fm_child
    on fm_child.family_id = fm_parent.family_id and fm_child.role = 'child'
  join public.youth_group_members child_ygm
    on child_ygm.user_id = fm_child.user_id and child_ygm.group_id = _group_id
  join public.profiles child_p on child_p.id = fm_child.user_id
  where fm_parent.user_id = _user_id and fm_parent.role = 'parent';

  -- Small group membership inside this youth group
  select jsonb_build_object(
    'id',          sg.id,
    'name',        sg.name,
    'role',        sgm.role::text,
    'joined_at',   sgm.joined_at,
    'leader_name', (
      select coalesce(p.display_name, p.email)
      from public.small_group_members lsgm
      join public.profiles p on p.id = lsgm.user_id
      where lsgm.small_group_id = sg.id and lsgm.role = 'leader'
      order by lsgm.joined_at
      limit 1
    )
  ) into v_sg
  from public.small_group_members sgm
  join public.small_groups sg on sg.id = sgm.small_group_id
  where sgm.user_id = _user_id and sg.youth_group_id = _group_id
  limit 1;

  -- Small-group attendance over last 90 days. Only counts attendance
  -- records for events in any small group of THIS youth group, taken
  -- by a leader (any creator counts here — attendance_events tracks
  -- created_by).
  select jsonb_build_object(
    'attended',  coalesce(sum(case when ar.present then 1 else 0 end), 0)::int,
    'total',     coalesce(count(*), 0)::int,
    'rate_pct',  case when count(*) = 0 then 0
                      else round(
                        (sum(case when ar.present then 1 else 0 end)::numeric
                         / count(*)::numeric) * 100)::int end,
    'events',    coalesce(jsonb_agg(jsonb_build_object(
                   'event_id',    ae.id,
                   'title',       ae.title,
                   'occurred_at', ae.occurred_at,
                   'present',     ar.present,
                   'small_group_name', sg2.name
                 ) order by ae.occurred_at desc), '[]'::jsonb)
  ) into v_att
  from public.attendance_events ae
  join public.small_groups sg2 on sg2.id = ae.small_group_id
  left join public.attendance_records ar
    on ar.event_id = ae.id and ar.user_id = _user_id
  where sg2.youth_group_id = _group_id
    and ae.occurred_at >= now() - interval '90 days'
    -- Only count meetings of small groups this user actually belongs to
    and exists (
      select 1 from public.small_group_members lsgm
      where lsgm.small_group_id = ae.small_group_id
        and lsgm.user_id = _user_id
    );

  if v_att is null then
    v_att := jsonb_build_object('attended', 0, 'total', 0, 'rate_pct', 0,
                                 'events', '[]'::jsonb);
  end if;

  -- Youth-group events the user RSVPed to (last 90 days + upcoming)
  select coalesce(jsonb_agg(jsonb_build_object(
           'event_id',  e.id,
           'title',     e.title,
           'starts_at', e.starts_at,
           'location',  e.location,
           'status',    er.status::text,
           'rsvped_at', er.created_at
         ) order by e.starts_at desc), '[]'::jsonb)
    into v_events
  from public.event_rsvps er
  join public.events e on e.id = er.event_id
  where er.user_id = _user_id
    and e.group_id = _group_id
    and (e.starts_at >= now() - interval '90 days'
         or e.starts_at >= now());

  return jsonb_build_object(
    'user_id',            v_profile.id,
    'display_name',       v_profile.display_name,
    'handle',             v_profile.handle,
    'email',              v_profile.email,
    'avatar_url',         v_profile.avatar_url,
    'role',               v_role,
    'grade_year',         v_profile.grade_year,
    'is_parent',          v_is_parent,
    'linked_child_names', to_jsonb(v_linked_children),
    'joined_at',          v_joined_at,
    'last_opened_at',     v_profile.last_opened_at,
    'xp',                 v_profile.xp,
    'water',              v_profile.water,
    'streak',             v_profile.streak,
    'lifetime_xp',        v_profile.lifetime_xp,
    'level',              public.level_for_xp(v_profile.lifetime_xp),
    'small_group',        v_sg,
    'attendance_90d',     v_att,
    'events',             v_events
  );
end;
$$;


ALTER FUNCTION "public"."pastor_member_profile"("_group_id" "uuid", "_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pastor_moderation_queue"("_group_id" "uuid") RETURNS TABLE("alert_id" "uuid", "message_id" "uuid", "preview" "text", "moderation_status" "text", "moderation_categories" "jsonb", "concern_category" "text", "concern_confidence" numeric, "concern_reason" "text", "created_at" timestamp with time zone, "thread_id" "uuid", "thread_kind" "text", "small_group_id" "uuid", "small_group_name" "text", "sender_id" "uuid", "sender_display_name" "text", "sender_email" "text", "sender_avatar_url" "text", "recipient_id" "uuid", "recipient_display_name" "text", "recipient_email" "text", "recipient_avatar_url" "text", "recipient_role" "text")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with base as (
    select
      a.id                          as alert_id,
      a.message_id                  as message_id,
      a.preview                     as preview,
      a.status::text                as moderation_status,
      a.categories                  as moderation_categories,
      a.concern_category            as concern_category,
      a.concern_confidence          as concern_confidence,
      a.concern_reason              as concern_reason,
      a.created_at                  as created_at,
      ct.id                         as thread_id,
      ct.kind::text                 as thread_kind,
      sg.id                         as small_group_id,
      sg.name                       as small_group_name,
      sp.id                         as sender_id,
      sp.display_name               as sender_display_name,
      sp.email                      as sender_email,
      sp.avatar_url                 as sender_avatar_url,
      case
        when ct.kind::text in ('dm_pastor','dm_leader') then (
          select ts.user_id
          from public.thread_subscribers ts
          where ts.thread_id = ct.id
            and ts.user_id <> a.sender_id
          order by ts.joined_at asc
          limit 1
        )
        else null
      end as r_recipient_id,
      a.group_id                    as a_group_id
    from public.moderation_alerts a
    join public.chat_threads ct       on ct.id = a.thread_id
    left join public.small_groups sg  on sg.id = ct.small_group_id
    left join public.profiles sp      on sp.id = a.sender_id
    where a.group_id = _group_id
      and a.acknowledged_at is null
  )
  select
    b.alert_id, b.message_id, b.preview, b.moderation_status,
    b.moderation_categories,
    b.concern_category, b.concern_confidence, b.concern_reason,
    b.created_at,
    b.thread_id, b.thread_kind, b.small_group_id, b.small_group_name,
    b.sender_id, b.sender_display_name, b.sender_email, b.sender_avatar_url,
    b.r_recipient_id                       as recipient_id,
    rp.display_name                         as recipient_display_name,
    rp.email                                as recipient_email,
    rp.avatar_url                           as recipient_avatar_url,
    rygm.role::text                         as recipient_role
  from base b
  left join public.profiles rp           on rp.id  = b.r_recipient_id
  left join public.youth_group_members rygm
       on rygm.user_id = b.r_recipient_id and rygm.group_id = b.a_group_id
  where
    is_group_pastor(auth.uid(), _group_id)
    or is_site_admin(auth.uid())
  order by b.created_at desc;
$$;


ALTER FUNCTION "public"."pastor_moderation_queue"("_group_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pastor_my_groups"() RETURNS TABLE("group_id" "uuid", "name" "text", "address" "text", "member_count" integer)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with related as (
    select yg.id as group_id, yg.name, yg.address, p.id as user_id
    from public.youth_groups yg
    join public.youth_group_members ygm on ygm.group_id = yg.id
    join public.profiles p on p.id = ygm.user_id
    union
    select yg.id, yg.name, yg.address, parent_p.id
    from public.youth_groups yg
    join public.youth_group_members child_ygm on child_ygm.group_id = yg.id
    join public.family_members fm_child
      on fm_child.user_id = child_ygm.user_id and fm_child.role = 'child'
    join public.family_members fm_parent
      on fm_parent.family_id = fm_child.family_id and fm_parent.role = 'parent'
    join public.profiles parent_p on parent_p.id = fm_parent.user_id
  )
  select
    yg.id   as group_id,
    yg.name,
    yg.address,
    (select count(*)::int from related r where r.group_id = yg.id) as member_count
  from public.youth_groups yg
  join public.youth_group_members me on me.group_id = yg.id
  where me.user_id = auth.uid()
    and me.role = 'pastor'
  order by yg.name;
$$;


ALTER FUNCTION "public"."pastor_my_groups"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pastor_overview_metrics"("_group_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_caller uuid := auth.uid();
  v_yg     public.youth_groups;
  v_active int;
  v_total  int;
  v_weekly_xp bigint;
  v_flagged int;
  v_small_groups int;
  v_upcoming int;
  v_growth jsonb;
  v_setup jsonb;
  v_setup_done boolean;
begin
  if v_caller is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  if not (is_group_pastor(v_caller, _group_id) or is_site_admin(v_caller)) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  select * into v_yg from public.youth_groups where id = _group_id;
  if v_yg.id is null then
    raise exception 'group_not_found' using errcode = '22023';
  end if;

  -- Active = profile.last_opened_at within the last 90 days (matches
  -- the billing definition in CLAUDE.md).
  select count(*)::int into v_active
  from public.youth_group_members ygm
  join public.profiles p on p.id = ygm.user_id
  where ygm.group_id = _group_id
    and p.last_opened_at >= now() - interval '90 days';

  select count(*)::int into v_total
  from public.youth_group_members
  where group_id = _group_id;

  -- Weekly XP: sum of grants to group members in the last 7 days.
  select coalesce(sum(g.amount), 0)::bigint into v_weekly_xp
  from public.user_xp_grants g
  join public.youth_group_members ygm on ygm.user_id = g.user_id
  where ygm.group_id = _group_id
    and g.awarded_at >= now() - interval '7 days';

  -- Flagged messages in threads scoped to this youth group OR to
  -- small groups within this youth group. We treat ALL flagged messages
  -- as "needs attention" — there's no resolved-at column on messages
  -- yet, so this is an outstanding-backlog count.
  select count(*)::int into v_flagged
  from public.messages m
  join public.chat_threads ct on ct.id = m.thread_id
  where m.moderation_status::text = 'flagged'
    and (
      ct.group_id = _group_id
      or ct.small_group_id in (
        select id from public.small_groups where youth_group_id = _group_id
      )
    );

  select count(*)::int into v_small_groups
  from public.small_groups where youth_group_id = _group_id;

  select count(*)::int into v_upcoming
  from public.events
  where group_id = _group_id and starts_at > now();

  -- 12-week growth series: new members per week, oldest first. Empty
  -- weeks return 0 so the chart's x-axis is continuous.
  with weeks as (
    select generate_series(
      date_trunc('week', now())::date - interval '11 weeks',
      date_trunc('week', now())::date,
      interval '1 week'
    )::date as week_start
  ),
  joins as (
    select date_trunc('week', joined_at)::date as week_start,
           count(*)::int as new_members
    from public.youth_group_members
    where group_id = _group_id
      and joined_at >= date_trunc('week', now())::date - interval '11 weeks'
    group by 1
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'week_start',  w.week_start,
        'new_members', coalesce(j.new_members, 0)
      )
      order by w.week_start asc
    ),
    '[]'::jsonb
  )
  into v_growth
  from weeks w
  left join joins j on j.week_start = w.week_start;

  -- Setup checklist: each item is a key + done bool + label. The CMS
  -- can render the items not-yet-done as a setup card and hide the
  -- whole block when is_complete is true.
  v_setup := jsonb_build_array(
    jsonb_build_object(
      'key',   'logo',
      'done',  (v_yg.logo_url is not null and length(trim(v_yg.logo_url)) > 0),
      'label', 'Upload your group logo'
    ),
    jsonb_build_object(
      'key',   'address',
      'done',  (
        v_yg.address is not null
        and length(trim(v_yg.address)) > 0
        and v_yg.latitude is not null
        and v_yg.longitude is not null
      ),
      'label', 'Set your group address'
    ),
    jsonb_build_object(
      'key',   'audience',
      'done',  (
        v_yg.group_type is not null
        and length(trim(v_yg.group_type)) > 0
        and v_yg.grades is not null
        and array_length(v_yg.grades, 1) > 0
      ),
      'label', 'Tell us who you serve (grades + group type)'
    ),
    jsonb_build_object(
      'key',   'small_groups',
      'done',  (v_small_groups > 0),
      'label', 'Create at least one small group'
    )
  );

  -- is_complete: every checklist item done.
  select coalesce(bool_and((item->>'done')::boolean), false)
  into v_setup_done
  from jsonb_array_elements(v_setup) as item;

  return jsonb_build_object(
    'group_id',            v_yg.id,
    'group_name',          v_yg.name,
    'church_name',         v_yg.church_name,
    'setup', jsonb_build_object(
      'is_complete', v_setup_done,
      'items',       v_setup
    ),
    'metrics', jsonb_build_object(
      'active_count',         v_active,
      'total_members',        v_total,
      'weekly_xp',            v_weekly_xp,
      'moderation_alerts',    v_flagged,
      'small_groups_count',   v_small_groups,
      'upcoming_events_count',v_upcoming
    ),
    'growth_12w', v_growth
  );
end;
$$;


ALTER FUNCTION "public"."pastor_overview_metrics"("_group_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pastor_publish_feed_post"("_post_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_post public.feed_posts;
  v_video public.videos;
  v_photo_count int;
begin
  if not public._can_manage_feed_post(_post_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  select * into v_post from public.feed_posts where id = _post_id;

  if v_post.post_type = 'video' then
    if v_post.video_id is null then raise exception 'video_not_attached'; end if;
    select * into v_video from public.videos where id = v_post.video_id;
    if v_video.status::text <> 'ready' then
      raise exception 'video_not_ready (current status: %)', v_video.status;
    end if;
  elsif v_post.post_type = 'slideshow' then
    select count(*) into v_photo_count
      from public.feed_post_photos where post_id = _post_id;
    if v_photo_count = 0 then raise exception 'slideshow_has_no_photos'; end if;
  end if;

  update public.feed_posts
    set status = 'published',
        published_at = coalesce(published_at, now()),
        updated_at = now()
  where id = _post_id;
end;
$$;


ALTER FUNCTION "public"."pastor_publish_feed_post"("_post_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pastor_publish_plan"("_plan_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_empty_count int;
begin
  if not public._pastor_can_edit_plan(_plan_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  -- Validation: no day with zero blocks.
  select count(*) into v_empty_count
  from public.bible_plan_days d
  where d.plan_id = _plan_id
    and jsonb_array_length(coalesce(d.sections->'blocks', '[]'::jsonb)) = 0;

  if v_empty_count > 0 then
    raise exception 'plan has % day(s) with no blocks — fill every day before publishing', v_empty_count
      using errcode = '22023';
  end if;

  update public.bible_plans
    set status       = 'published'::bible_plan_status,
        published_at = coalesce(published_at, now()),
        updated_at   = now()
    where id = _plan_id;
end;
$$;


ALTER FUNCTION "public"."pastor_publish_plan"("_plan_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pastor_recent_activity"("_group_id" "uuid", "_limit" integer DEFAULT 20) RETURNS TABLE("event_id" "text", "kind" "text", "user_id" "uuid", "display_name" "text", "avatar_url" "text", "headline" "text", "occurred_at" timestamp with time zone, "xp_delta" integer)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with allowed as (select public._pastor_can_view_group(_group_id) as ok),
  members as (
    select ygm.user_id from public.youth_group_members ygm where ygm.group_id = _group_id
  ),
  plan_completions as (
    select
      'pc:' || c.id::text as event_id,
      'plan_completed'    as kind,
      c.user_id,
      p.display_name,
      p.avatar_url,
      'finished '         || coalesce(bp.title, 'a plan') as headline,
      c.completed_at      as occurred_at,
      coalesce(bp.xp_reward, 0)::int as xp_delta
    from public.bible_plan_completions c
    join public.profiles p on p.id = c.user_id
    join public.bible_plans bp on bp.id = c.plan_id
    where c.user_id in (select user_id from members)
  ),
  day_completions as (
    select
      'dc:' || d.id::text as event_id,
      'day_completed'     as kind,
      d.user_id,
      p.display_name,
      p.avatar_url,
      'finished a day of ' || coalesce(bp.title, 'a plan') as headline,
      d.completed_at      as occurred_at,
      (d.step_xp_earned + 100)::int as xp_delta  -- + daily bonus
    from public.bible_plan_day_progress d
    join public.profiles p on p.id = d.user_id
    left join public.bible_plans bp on bp.id = d.plan_id
    where d.user_id in (select user_id from members)
  ),
  recent_joins as (
    select
      'jn:' || ygm.user_id::text || ':' || extract(epoch from ygm.joined_at)::text as event_id,
      'joined'            as kind,
      ygm.user_id,
      p.display_name,
      p.avatar_url,
      'joined the group'  as headline,
      ygm.joined_at       as occurred_at,
      0                   as xp_delta
    from public.youth_group_members ygm
    join public.profiles p on p.id = ygm.user_id
    where ygm.group_id = _group_id
  ),
  rsvps as (
    select
      'rs:' || r.id::text as event_id,
      'event_rsvp'        as kind,
      r.user_id,
      p.display_name,
      p.avatar_url,
      'RSVPed to '        || coalesce(e.title, 'an event') as headline,
      r.created_at        as occurred_at,
      0                   as xp_delta
    from public.event_rsvps r
    join public.profiles p on p.id = r.user_id
    left join public.events e on e.id = r.event_id
    where r.user_id in (select user_id from members)
  ),
  attendance as (
    select
      'at:' || ae.id::text as event_id,
      'attendance_taken'   as kind,
      ae.created_by        as user_id,
      coalesce(p.display_name, 'Leader') as display_name,
      p.avatar_url,
      'took attendance: '  || coalesce(ae.title, 'session') as headline,
      ae.occurred_at       as occurred_at,
      0                    as xp_delta
    from public.attendance_events ae
    left join public.profiles p on p.id = ae.created_by
    join public.small_groups sg on sg.id = ae.small_group_id
    where sg.youth_group_id = _group_id
  ),
  unioned as (
    select * from plan_completions
    union all select * from day_completions
    union all select * from recent_joins
    union all select * from rsvps
    union all select * from attendance
  )
  select u.* from unioned u, allowed
  where allowed.ok
  order by u.occurred_at desc
  limit greatest(1, least(_limit, 100));
$$;


ALTER FUNCTION "public"."pastor_recent_activity"("_group_id" "uuid", "_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pastor_reject_alert"("_alert_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_caller uuid := auth.uid();
  v_alert  public.moderation_alerts;
begin
  if v_caller is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  select * into v_alert from public.moderation_alerts where id = _alert_id;
  if v_alert.id is null then
    raise exception 'alert_not_found' using errcode = '22023';
  end if;
  if not (is_group_pastor(v_caller, v_alert.group_id) or is_site_admin(v_caller)) then
    raise exception 'forbidden: not a pastor of this group' using errcode = '42501';
  end if;

  -- If a message row exists (allowed flag), delete it.
  if v_alert.message_id is not null then
    delete from public.messages where id = v_alert.message_id;
  end if;

  update public.moderation_alerts
  set acknowledged_at = now(),
      acknowledged_by = v_caller
  where id = _alert_id;

  return jsonb_build_object(
    'ok',       true,
    'alert_id', _alert_id,
    'deleted',  v_alert.message_id is not null
  );
end;
$$;


ALTER FUNCTION "public"."pastor_reject_alert"("_alert_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pastor_set_instagram_source"("_group_id" "uuid", "_handle" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare
  v_caller uuid := auth.uid();
  v_clean text;
  v_id uuid;
begin
  if v_caller is null then raise exception 'not_authenticated'; end if;
  if not (public.is_site_admin(v_caller) or public.is_group_pastor(v_caller, _group_id)) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  -- Sanitize: strip leading @ and whitespace
  v_clean := regexp_replace(coalesce(_handle, ''), '^[\s@]+|\s+$', '', 'g');
  v_clean := lower(v_clean);
  if v_clean = '' then raise exception 'handle_required'; end if;

  insert into public.instagram_sources (group_id, handle, added_by, is_active)
    values (_group_id, v_clean, v_caller, true)
    on conflict (group_id, handle) do update
      set is_active = true,
          added_by  = excluded.added_by
    returning id into v_id;

  return v_id;
end;
$_$;


ALTER FUNCTION "public"."pastor_set_instagram_source"("_group_id" "uuid", "_handle" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pastor_update_plan_basics"("_plan_id" "uuid", "_title" "text" DEFAULT NULL::"text", "_days" integer DEFAULT NULL::integer, "_header_kind" "text" DEFAULT NULL::"text", "_header_image_url" "text" DEFAULT NULL::"text", "_gradient_idx" integer DEFAULT NULL::integer, "_visibility" "text" DEFAULT NULL::"text", "_group_id" "uuid" DEFAULT NULL::"uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."pastor_update_plan_basics"("_plan_id" "uuid", "_title" "text", "_days" integer, "_header_kind" "text", "_header_image_url" "text", "_gradient_idx" integer, "_visibility" "text", "_group_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pastor_update_plan_basics"("_plan_id" "uuid", "_title" "text" DEFAULT NULL::"text", "_days" integer DEFAULT NULL::integer, "_header_kind" "text" DEFAULT NULL::"text", "_header_image_url" "text" DEFAULT NULL::"text", "_gradient_idx" integer DEFAULT NULL::integer, "_visibility" "text" DEFAULT NULL::"text", "_group_id" "uuid" DEFAULT NULL::"uuid", "_additional_group_ids" "uuid"[] DEFAULT NULL::"uuid"[]) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."pastor_update_plan_basics"("_plan_id" "uuid", "_title" "text", "_days" integer, "_header_kind" "text", "_header_image_url" "text", "_gradient_idx" integer, "_visibility" "text", "_group_id" "uuid", "_additional_group_ids" "uuid"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pastor_upsert_day"("_plan_id" "uuid", "_day_number" integer, "_title" "text", "_scripture_reference" "text", "_blocks" "jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_day_id uuid;
  v_blocks jsonb;
  v_block jsonb;
  v_type text;
begin
  if not public._pastor_can_edit_plan(_plan_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  if _day_number < 1 then
    raise exception 'day_number must be >= 1' using errcode = '22023';
  end if;

  v_blocks := coalesce(_blocks, '[]'::jsonb);
  if jsonb_typeof(v_blocks) <> 'array' then
    raise exception 'blocks must be a JSON array' using errcode = '22023';
  end if;

  -- Accept canonical names + the `reading` alias (same as `read`).
  for v_block in select * from jsonb_array_elements(v_blocks) loop
    v_type := v_block->>'type';
    if v_type not in ('read','reading','commentary','video','question','prayer') then
      raise exception 'unknown block type: %', v_type using errcode = '22023';
    end if;
  end loop;

  insert into public.bible_plan_days (
    plan_id, day_number, title, scripture_reference, sections
  ) values (
    _plan_id, _day_number,
    coalesce(nullif(trim(_title), ''), 'Day ' || _day_number),
    coalesce(_scripture_reference, ''),
    jsonb_build_object('blocks', v_blocks)
  )
  on conflict (plan_id, day_number) do update set
    title               = excluded.title,
    scripture_reference = excluded.scripture_reference,
    sections            = excluded.sections,
    updated_at          = now()
  returning id into v_day_id;

  return v_day_id;
end;
$$;


ALTER FUNCTION "public"."pastor_upsert_day"("_plan_id" "uuid", "_day_number" integer, "_title" "text", "_scripture_reference" "text", "_blocks" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pastor_weekly_ranking_history"("_group_id" "uuid", "_weeks" integer DEFAULT 12) RETURNS TABLE("week_start" "date", "class" "text", "class_label" "text", "rank_in_class" integer, "total_groups_in_class" integer, "active_count" integer, "week_xp" bigint, "multiplier" numeric, "adjusted_xp" bigint)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if not (public.is_site_admin(v_uid)
          or public.is_group_pastor(v_uid, _group_id)) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  return query
  select s.week_start, s.class, initcap(s.class) as class_label,
         s.rank_in_class, s.total_groups_in_class,
         s.active_count, s.week_xp, s.multiplier, s.adjusted_xp
  from public.weekly_ranking_snapshots s
  where s.group_id = _group_id
  order by s.week_start desc
  limit greatest(_weeks, 1);
end;
$$;


ALTER FUNCTION "public"."pastor_weekly_ranking_history"("_group_id" "uuid", "_weeks" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pastor_weekly_ranking_report"("_group_id" "uuid", "_week_start" "date" DEFAULT NULL::"date") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_uid uuid := auth.uid();
  v_week date := coalesce(_week_start,
    (date_trunc('week', now() at time zone 'UTC')::date - 7));
  v_group public.weekly_ranking_snapshots;
  v_members jsonb;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if not (public.is_site_admin(v_uid)
          or public.is_group_pastor(v_uid, _group_id)) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  select * into v_group
  from public.weekly_ranking_snapshots
  where week_start = v_week and group_id = _group_id;

  if v_group.id is null then
    return jsonb_build_object(
      'week_start', v_week,
      'group_id', _group_id,
      'has_data', false
    );
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'rank',          u.rank_in_group,
    'user_id',       u.user_id,
    'display_name',  p.display_name,
    'handle',        p.handle,
    'avatar_url',    p.avatar_url,
    'role',          case
      when exists (select 1 from public.youth_group_members ygm
                   where ygm.group_id = _group_id and ygm.user_id = u.user_id and ygm.role = 'pastor')
        then 'pastor'
      when exists (select 1 from public.small_group_members sgm
                   join public.small_groups sg on sg.id = sgm.small_group_id
                   where sgm.user_id = u.user_id and sgm.role = 'leader'
                     and sg.youth_group_id = _group_id)
        then 'leader'
      when exists (select 1 from public.family_members fm_parent
                   join public.family_members fm_child
                     on fm_child.family_id = fm_parent.family_id and fm_child.role = 'child'
                   join public.youth_group_members child_ygm
                     on child_ygm.user_id = fm_child.user_id and child_ygm.group_id = _group_id
                   where fm_parent.user_id = u.user_id and fm_parent.role = 'parent')
        then 'parent'
      when p.grade_year is not null then 'student'
      else 'member'
    end,
    'grade_year',    p.grade_year,
    'week_xp',       u.week_xp
  ) order by u.rank_in_group), '[]'::jsonb)
  into v_members
  from public.weekly_user_ranking_snapshots u
  join public.profiles p on p.id = u.user_id
  where u.week_start = v_week and u.group_id = _group_id;

  return jsonb_build_object(
    'week_start',             v_group.week_start,
    'group_id',               v_group.group_id,
    'has_data',               true,
    'class',                  v_group.class,
    'class_label',            initcap(v_group.class),
    'rank_in_class',          v_group.rank_in_class,
    'total_groups_in_class',  v_group.total_groups_in_class,
    'active_count',           v_group.active_count,
    'week_xp',                v_group.week_xp,
    'multiplier',             v_group.multiplier,
    'adjusted_xp',            v_group.adjusted_xp,
    'top_members',            v_members
  );
end;
$$;


ALTER FUNCTION "public"."pastor_weekly_ranking_report"("_group_id" "uuid", "_week_start" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."profile_is_adult"("_dob" "date") RETURNS boolean
    LANGUAGE "sql" IMMUTABLE
    AS $$
  select _dob is null or _dob <= current_date - interval '18 years';
$$;


ALTER FUNCTION "public"."profile_is_adult"("_dob" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."profile_is_under_13"("_dob" "date") RETURNS boolean
    LANGUAGE "sql" IMMUTABLE
    AS $$
  select _dob is not null and _dob > current_date - interval '13 years';
$$;


ALTER FUNCTION "public"."profile_is_under_13"("_dob" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."public_event_summary"("_event_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_event public.events;
  v_group public.youth_groups;
  v_inside int;
  v_outside int;
  v_maybe int;
  v_decline int;
begin
  select * into v_event from public.events where id = _event_id;
  if v_event.id is null then
    return jsonb_build_object('found', false);
  end if;

  -- Only public-visible events have a shareable page. Members-only or
  -- groupPrivate events return a stub so the browser page can show
  -- "this event is private" rather than leaking details.
  if v_event.visibility::text <> 'public' or v_event.rsvp_audience::text <> 'public' then
    return jsonb_build_object(
      'found', true,
      'public', false,
      'event_id', v_event.id,
      'title', v_event.title
    );
  end if;

  select * into v_group from public.youth_groups where id = v_event.group_id;

  select count(*)::int into v_inside  from public.event_rsvps
    where event_id = _event_id and status::text = 'going';
  select count(*)::int into v_maybe   from public.event_rsvps
    where event_id = _event_id and status::text = 'maybe';
  select count(*)::int into v_decline from public.event_rsvps
    where event_id = _event_id and status::text = 'declined';
  select count(*)::int into v_outside from public.event_external_rsvps
    where event_id = _event_id and status = 'going'
      and converted_to_user_id is null;

  return jsonb_build_object(
    'found',         true,
    'public',        true,
    'event_id',      v_event.id,
    'title',         v_event.title,
    'description',   v_event.description,
    'starts_at',     v_event.starts_at,
    'location',      v_event.location,
    'cover_url',     v_event.cover_url,
    'group', jsonb_build_object(
      'id',            v_group.id,
      'name',          v_group.name,
      'church_name',   v_group.church_name,
      'logo_url',      v_group.logo_url,
      'gradient_from', v_group.gradient_from,
      'gradient_to',   v_group.gradient_to
    ),
    'going_count',   v_inside + v_outside,
    'maybe_count',   v_maybe,
    'declined_count',v_decline
  );
end;
$$;


ALTER FUNCTION "public"."public_event_summary"("_event_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."public_events_nearby"("_lat" double precision, "_lng" double precision, "_radius_m" integer DEFAULT 50000, "_limit" integer DEFAULT 20, "_window_days" integer DEFAULT 14) RETURNS TABLE("event_id" "uuid", "title" "text", "description" "text", "starts_at" timestamp with time zone, "location" "text", "cover_url" "text", "group_id" "uuid", "group_name" "text", "group_church_name" "text", "group_logo_url" "text", "group_gradient_from" "text", "group_gradient_to" "text", "going_count" integer, "distance_m" double precision, "is_my_group_event" boolean)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with base as (
    select
      e.id                                              as r_event_id,
      e.title                                           as r_title,
      e.description                                     as r_description,
      e.starts_at                                       as r_starts_at,
      e.location                                        as r_location,
      e.cover_url                                       as r_cover_url,
      yg.id                                             as r_group_id,
      yg.name                                           as r_group_name,
      yg.church_name                                    as r_group_church_name,
      yg.logo_url                                       as r_group_logo_url,
      yg.gradient_from                                  as r_group_gradient_from,
      yg.gradient_to                                    as r_group_gradient_to,
      coalesce(e.latitude,  yg.latitude)                as r_use_lat,
      coalesce(e.longitude, yg.longitude)               as r_use_lng,
      exists (
        select 1 from public.youth_group_members ygm
        where ygm.group_id = yg.id
          and ygm.user_id  = auth.uid()
      ) as r_is_my_group_event
    from public.events e
    join public.youth_groups yg on yg.id = e.group_id
    where e.visibility::text    = 'public'
      and e.rsvp_audience::text = 'public'
      and e.starts_at > now()
      and e.starts_at <= now() + make_interval(days => greatest(_window_days, 1))
      and coalesce(yg.is_public, false) = true
      and coalesce(yg.is_default_ygteev, false) = false
      and coalesce(e.latitude,  yg.latitude)  is not null
      and coalesce(e.longitude, yg.longitude) is not null
  ),
  with_geo as (
    select
      b.*,
      (
        6371000.0 * 2 * asin(
          sqrt(
            power(sin(radians((b.r_use_lat - _lat) / 2)), 2)
            + cos(radians(_lat)) * cos(radians(b.r_use_lat))
              * power(sin(radians((b.r_use_lng - _lng) / 2)), 2)
          )
        )
      ) as r_distance_m
    from base b
  ),
  with_counts as (
    select
      g.*,
      coalesce((
        select count(*)::int
        from public.event_rsvps r
        where r.event_id   = g.r_event_id
          and r.status::text = 'going'
      ), 0)
      + coalesce((
        select count(*)::int
        from public.event_external_rsvps x
        where x.event_id   = g.r_event_id
          and x.status     = 'going'
          and x.converted_to_user_id is null
      ), 0) as r_going_count
    from with_geo g
  )
  select
    r_event_id, r_title, r_description, r_starts_at, r_location, r_cover_url,
    r_group_id, r_group_name, r_group_church_name, r_group_logo_url,
    r_group_gradient_from, r_group_gradient_to,
    r_going_count, r_distance_m, r_is_my_group_event
  from with_counts
  where r_distance_m <= _radius_m
  order by r_starts_at asc, r_distance_m asc
  limit greatest(_limit, 1);
$$;


ALTER FUNCTION "public"."public_events_nearby"("_lat" double precision, "_lng" double precision, "_radius_m" integer, "_limit" integer, "_window_days" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."purge_soft_deleted_profiles"() RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
declare
  v_count integer := 0;
  v_id uuid;
begin
  for v_id in
    select p.id
    from public.profiles p
    where p.deleted_at is not null
      and p.deleted_at < now() - interval '30 days'
  loop
    delete from auth.users where id = v_id;
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;


ALTER FUNCTION "public"."purge_soft_deleted_profiles"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ranking_top_groups_in_my_class"("_group_id" "uuid", "_limit" integer DEFAULT 10) RETURNS TABLE("rank" integer, "group_id" "uuid", "name" "text", "church_name" "text", "logo_url" "text", "gradient_from" "text", "gradient_to" "text", "class" "text", "class_label" "text", "active_count" integer, "max_active_in_class" integer, "multiplier" numeric, "week_xp" bigint, "adjusted_xp" bigint, "is_my_group" boolean)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_uid uuid := auth.uid();
  v_yg public.youth_groups;
  v_week_start timestamptz :=
    (date_trunc('week', now() at time zone 'UTC')) at time zone 'UTC';
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_yg from public.youth_groups where id = _group_id;
  if v_yg.id is null then raise exception 'group_not_found'; end if;
  if v_yg.is_default_ygteev then raise exception 'cannot_rank_default_group'; end if;
  if not (public.is_site_admin(v_uid) or public.is_group_member(v_uid, _group_id)) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  return query
  with related_pairs as (
    select yg.id as r_group_id, p.id as r_user_id, p.last_opened_at as r_last_opened_at
    from public.youth_groups yg
    join public.youth_group_members ygm on ygm.group_id = yg.id
    join public.profiles p on p.id = ygm.user_id
    where yg.is_default_ygteev = false
    union
    select yg.id, parent_p.id, parent_p.last_opened_at
    from public.youth_groups yg
    join public.youth_group_members child_ygm on child_ygm.group_id = yg.id
    join public.family_members fm_child
      on fm_child.user_id = child_ygm.user_id and fm_child.role = 'child'
    join public.family_members fm_parent
      on fm_parent.family_id = fm_child.family_id and fm_parent.role = 'parent'
    join public.profiles parent_p on parent_p.id = fm_parent.user_id
    where yg.is_default_ygteev = false
  ),
  per_group as (
    select rp.r_group_id,
           count(distinct rp.r_user_id) filter (
             where rp.r_last_opened_at >= now() - interval '90 days'
           )::int                                     as r_active_count,
           coalesce(sum(g.amount), 0)::bigint         as r_week_xp
    from related_pairs rp
    left join public.user_xp_grants g
      on g.user_id = rp.r_user_id and g.awarded_at >= v_week_start
    group by rp.r_group_id
  ),
  classed as (
    select pg.r_group_id, pg.r_active_count, pg.r_week_xp,
           public.xp_class_for(pg.r_active_count) as r_class
    from per_group pg
  ),
  my_class as (
    select c.r_class as c from classed c where c.r_group_id = _group_id
  ),
  class_max as (
    select c.r_class, max(c.r_active_count) as r_max_active
    from classed c
    where c.r_class is not null
    group by c.r_class
  ),
  in_class as (
    select c.r_group_id, c.r_active_count, c.r_week_xp, c.r_class,
           cm.r_max_active,
           least(
             case when c.r_active_count = 0 then 1.0
                  else (cm.r_max_active::numeric / c.r_active_count::numeric)
             end,
             3.00::numeric
           ) as r_multiplier
    from classed c
    join class_max cm on cm.r_class = c.r_class
    where c.r_class = (select c from my_class)
  )
  select
    (row_number() over (
       order by (ic.r_week_xp * ic.r_multiplier) desc,
                ic.r_multiplier asc,
                yg.name nulls last
     ))::int                                              as rank,
    yg.id                                                 as group_id,
    yg.name                                               as name,
    yg.church_name                                        as church_name,
    yg.logo_url                                           as logo_url,
    yg.gradient_from                                      as gradient_from,
    yg.gradient_to                                        as gradient_to,
    ic.r_class                                            as class,
    initcap(ic.r_class)                                   as class_label,
    ic.r_active_count                                     as active_count,
    ic.r_max_active                                       as max_active_in_class,
    round(ic.r_multiplier, 2)                             as multiplier,
    ic.r_week_xp                                          as week_xp,
    floor(ic.r_week_xp * ic.r_multiplier)::bigint         as adjusted_xp,
    (yg.id = _group_id)                                   as is_my_group
  from in_class ic
  join public.youth_groups yg on yg.id = ic.r_group_id
  order by (ic.r_week_xp * ic.r_multiplier) desc,
           ic.r_multiplier asc,
           yg.name nulls last
  limit greatest(_limit, 1);
end;
$$;


ALTER FUNCTION "public"."ranking_top_groups_in_my_class"("_group_id" "uuid", "_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ranking_top_groups_overall"("_limit" integer DEFAULT 10) RETURNS TABLE("rank" integer, "group_id" "uuid", "name" "text", "church_name" "text", "logo_url" "text", "gradient_from" "text", "gradient_to" "text", "active_count" integer, "week_xp" bigint, "is_my_group" boolean)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_uid uuid := auth.uid();
  v_week_start timestamptz :=
    (date_trunc('week', now() at time zone 'UTC')) at time zone 'UTC';
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  return query
  with related_pairs as (
    select yg.id as r_group_id, p.id as r_user_id, p.last_opened_at as r_last_opened_at
    from public.youth_groups yg
    join public.youth_group_members ygm on ygm.group_id = yg.id
    join public.profiles p on p.id = ygm.user_id
    where yg.is_default_ygteev = false
    union
    select yg.id, parent_p.id, parent_p.last_opened_at
    from public.youth_groups yg
    join public.youth_group_members child_ygm on child_ygm.group_id = yg.id
    join public.family_members fm_child
      on fm_child.user_id = child_ygm.user_id and fm_child.role = 'child'
    join public.family_members fm_parent
      on fm_parent.family_id = fm_child.family_id and fm_parent.role = 'parent'
    join public.profiles parent_p on parent_p.id = fm_parent.user_id
    where yg.is_default_ygteev = false
  ),
  per_group as (
    select rp.r_group_id,
           count(distinct rp.r_user_id) filter (
             where rp.r_last_opened_at >= now() - interval '90 days'
           )::int as r_active_count,
           coalesce(sum(g.amount), 0)::bigint as r_week_xp
    from related_pairs rp
    left join public.user_xp_grants g
      on g.user_id = rp.r_user_id and g.awarded_at >= v_week_start
    group by rp.r_group_id
  ),
  mine as (
    select ygm.group_id as r_mine_group_id
    from public.youth_group_members ygm
    where ygm.user_id = v_uid
  )
  select
    (row_number() over (order by pg.r_week_xp desc, yg.name nulls last))::int as rank,
    yg.id              as group_id,
    yg.name            as name,
    yg.church_name     as church_name,
    yg.logo_url        as logo_url,
    yg.gradient_from   as gradient_from,
    yg.gradient_to     as gradient_to,
    pg.r_active_count  as active_count,
    pg.r_week_xp       as week_xp,
    (yg.id in (select m.r_mine_group_id from mine m)) as is_my_group
  from per_group pg
  join public.youth_groups yg on yg.id = pg.r_group_id
  order by pg.r_week_xp desc, yg.name nulls last
  limit greatest(_limit, 1);
end;
$$;


ALTER FUNCTION "public"."ranking_top_groups_overall"("_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ranking_top_users_in_group"("_group_id" "uuid", "_limit" integer DEFAULT 10) RETURNS TABLE("rank" integer, "user_id" "uuid", "display_name" "text", "handle" "text", "avatar_url" "text", "role" "text", "week_xp" bigint, "is_me" boolean)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_uid uuid := auth.uid();
  v_yg public.youth_groups;
  v_week_start timestamptz :=
    (date_trunc('week', now() at time zone 'UTC')) at time zone 'UTC';
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_yg from public.youth_groups where id = _group_id;
  if v_yg.id is null then raise exception 'group_not_found'; end if;
  if v_yg.is_default_ygteev then raise exception 'cannot_rank_default_group'; end if;
  if not (public.is_site_admin(v_uid) or public.is_group_member(v_uid, _group_id)) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  return query
  with related as (
    select p.id as r_user_id, p.display_name as r_display_name,
           p.handle as r_handle, p.avatar_url as r_avatar_url,
           p.grade_year as r_grade_year, 'direct'::text as r_src
    from public.youth_group_members ygm
    join public.profiles p on p.id = ygm.user_id
    where ygm.group_id = _group_id
    union
    select parent_p.id, parent_p.display_name, parent_p.handle,
           parent_p.avatar_url, parent_p.grade_year, 'parent'::text
    from public.youth_group_members child_ygm
    join public.family_members fm_child
      on fm_child.user_id = child_ygm.user_id and fm_child.role = 'child'
    join public.family_members fm_parent
      on fm_parent.family_id = fm_child.family_id and fm_parent.role = 'parent'
    join public.profiles parent_p on parent_p.id = fm_parent.user_id
    where child_ygm.group_id = _group_id
  ),
  scored as (
    select r.r_user_id, r.r_display_name, r.r_handle, r.r_avatar_url,
           r.r_grade_year, r.r_src,
           coalesce(sum(g.amount), 0)::bigint as r_week_xp
    from related r
    left join public.user_xp_grants g
      on g.user_id = r.r_user_id and g.awarded_at >= v_week_start
    group by r.r_user_id, r.r_display_name, r.r_handle, r.r_avatar_url,
             r.r_grade_year, r.r_src
  ),
  roled as (
    select s.r_user_id, s.r_display_name, s.r_handle, s.r_avatar_url,
           s.r_grade_year, s.r_src, s.r_week_xp,
      case
        when exists (select 1 from public.youth_group_members ygm2
                     where ygm2.group_id = _group_id and ygm2.user_id = s.r_user_id and ygm2.role = 'pastor')
          then 'pastor'
        when exists (select 1 from public.small_group_members sgm
                     join public.small_groups sg on sg.id = sgm.small_group_id
                     where sgm.user_id = s.r_user_id and sgm.role = 'leader'
                       and sg.youth_group_id = _group_id)
          then 'leader'
        when s.r_src = 'parent' then 'parent'
        when s.r_grade_year is not null then 'student'
        else 'member'
      end as r_role_label
    from scored s
  )
  select
    (row_number() over (order by roled.r_week_xp desc,
                                  roled.r_display_name nulls last))::int  as rank,
    roled.r_user_id                                                       as user_id,
    roled.r_display_name                                                  as display_name,
    roled.r_handle                                                        as handle,
    roled.r_avatar_url                                                    as avatar_url,
    roled.r_role_label                                                    as role,
    roled.r_week_xp                                                       as week_xp,
    (roled.r_user_id = v_uid)                                             as is_me
  from roled
  order by roled.r_week_xp desc, roled.r_display_name nulls last
  limit greatest(_limit, 1);
end;
$$;


ALTER FUNCTION "public"."ranking_top_users_in_group"("_group_id" "uuid", "_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ranking_top_users_overall"("_limit" integer DEFAULT 10) RETURNS TABLE("rank" integer, "user_id" "uuid", "display_name" "text", "handle" "text", "avatar_url" "text", "group_id" "uuid", "group_name" "text", "week_xp" bigint, "is_me" boolean)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_uid uuid := auth.uid();
  v_week_start timestamptz :=
    (date_trunc('week', now() at time zone 'UTC')) at time zone 'UTC';
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  return query
  with per_user as (
    select g.user_id as r_user_id,
           sum(g.amount)::bigint as r_week_xp
    from public.user_xp_grants g
    where g.awarded_at >= v_week_start
    group by g.user_id
    having sum(g.amount) > 0
  ),
  user_group as (
    select distinct on (ygm.user_id)
           ygm.user_id as r_user_id,
           ygm.group_id as r_group_id,
           yg.name as r_group_name
    from public.youth_group_members ygm
    join public.youth_groups yg on yg.id = ygm.group_id
    where yg.is_default_ygteev = false
    order by ygm.user_id, ygm.joined_at
  )
  select
    (row_number() over (order by pu.r_week_xp desc,
                                  p.display_name nulls last))::int  as rank,
    p.id              as user_id,
    p.display_name    as display_name,
    p.handle          as handle,
    p.avatar_url      as avatar_url,
    ug.r_group_id     as group_id,
    ug.r_group_name   as group_name,
    pu.r_week_xp      as week_xp,
    (p.id = v_uid)    as is_me
  from per_user pu
  join public.profiles p on p.id = pu.r_user_id
  left join user_group ug on ug.r_user_id = pu.r_user_id
  order by pu.r_week_xp desc, p.display_name nulls last
  limit greatest(_limit, 1);
end;
$$;


ALTER FUNCTION "public"."ranking_top_users_overall"("_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."remove_family"("_family_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare v_caller uuid := auth.uid(); v_still_parent boolean;
begin
  if v_caller is null then raise exception 'not_authenticated'; end if;
  if not exists (
    select 1 from public.family_members
    where family_id = _family_id and user_id = v_caller and role = 'parent'
  ) then raise exception 'forbidden' using errcode = '42501'; end if;

  delete from public.families where id = _family_id;

  select exists (select 1 from public.family_members
                 where user_id = v_caller and role = 'parent') into v_still_parent;
  if not v_still_parent then
    delete from public.user_roles
    where user_id = v_caller and role = 'parent'::app_role;
  end if;
end;
$$;


ALTER FUNCTION "public"."remove_family"("_family_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."request_account_deletion"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  update public.profiles
    set deleted_at = coalesce(deleted_at, now()),
        updated_at = now()
    where id = v_uid;
end;
$$;


ALTER FUNCTION "public"."request_account_deletion"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."youth_group_join_requests" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "group_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "status" "public"."join_request_status" DEFAULT 'pending'::"public"."join_request_status" NOT NULL,
    "message" "text",
    "requested_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "decided_at" timestamp with time zone,
    "decided_by" "uuid"
);


ALTER TABLE "public"."youth_group_join_requests" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."request_to_join_group"("_group_id" "uuid", "_message" "text" DEFAULT NULL::"text") RETURNS "public"."youth_group_join_requests"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  _uid    uuid := auth.uid();
  _yg     public.youth_groups;
  _grade  integer;
  _result public.youth_group_join_requests;
begin
  if _uid is null then raise exception 'not_authenticated'; end if;

  select * into _yg from public.youth_groups where id = _group_id;
  if _yg.id is null              then raise exception 'group_not_found';            end if;
  if _yg.is_default_ygteev       then raise exception 'cannot_request_default_group'; end if;
  if not _yg.is_public           then raise exception 'group_not_public';            end if;

  if exists (
    select 1 from public.youth_group_members where group_id = _group_id and user_id = _uid
  ) then
    raise exception 'already_member';
  end if;

  -- Audience gate: only enforce when the group has declared its grades
  -- AND the requester has a recorded grade. Adults / "not a student"
  -- users pass through; pastor approval is the final filter for them.
  if _yg.grades is not null then
    select grade_year into _grade from public.profiles where id = _uid;
    if _grade is not null and not (_grade = any(_yg.grades)) then
      raise exception 'grade_not_eligible' using errcode = '42501';
    end if;
  end if;

  select * into _result
  from public.youth_group_join_requests
  where group_id = _group_id and user_id = _uid and status = 'pending';
  if _result.id is not null then return _result; end if;

  insert into public.youth_group_join_requests (group_id, user_id, message)
  values (_group_id, _uid, _message)
  returning * into _result;

  return _result;
end $$;


ALTER FUNCTION "public"."request_to_join_group"("_group_id" "uuid", "_message" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."respond_to_join_request"("_request_id" "uuid", "_approve" boolean) RETURNS "public"."youth_group_join_requests"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  _uid uuid := auth.uid();
  _req public.youth_group_join_requests;
begin
  if _uid is null then raise exception 'not_authenticated'; end if;

  select * into _req
  from public.youth_group_join_requests
  where id = _request_id
  for update;

  if _req.id is null                                                              then raise exception 'request_not_found';        end if;
  if _req.status <> 'pending'                                                     then raise exception 'request_already_decided';  end if;
  if not (public.is_site_admin(_uid) or public.is_group_pastor(_uid, _req.group_id)) then raise exception 'not_authorized';         end if;

  if _approve then
    insert into public.youth_group_members (group_id, user_id, role)
    values (_req.group_id, _req.user_id, 'member')
    on conflict (group_id, user_id) do nothing;

    update public.youth_group_join_requests
       set status = 'approved', decided_at = now(), decided_by = _uid
     where id = _request_id
     returning * into _req;
  else
    update public.youth_group_join_requests
       set status = 'denied', decided_at = now(), decided_by = _uid
     where id = _request_id
     returning * into _req;
  end if;

  return _req;
end $$;


ALTER FUNCTION "public"."respond_to_join_request"("_request_id" "uuid", "_approve" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rsvp_public_event"("_event_id" "uuid", "_status" "text" DEFAULT 'going'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_uid     uuid := auth.uid();
  v_event   public.events;
  v_going   integer;
  v_outside integer;
begin
  if v_uid is null then
    raise exception 'not-authenticated';
  end if;
  if _status not in ('going','maybe','declined') then
    raise exception 'invalid-status: %', _status;
  end if;

  select * into v_event from public.events where id = _event_id;
  if v_event.id is null then
    raise exception 'event-not-found';
  end if;
  if v_event.visibility::text <> 'public' or v_event.rsvp_audience::text <> 'public' then
    raise exception 'event-not-public';
  end if;

  insert into public.event_rsvps (event_id, user_id, status)
  values (_event_id, v_uid, _status::event_rsvp_status)
  on conflict (event_id, user_id) do update
    set status = excluded.status;

  select count(*)::int into v_going
  from public.event_rsvps
  where event_id = _event_id and status::text = 'going';

  select count(*)::int into v_outside
  from public.event_external_rsvps
  where event_id = _event_id and status = 'going'
    and converted_to_user_id is null;

  return jsonb_build_object(
    'ok',           true,
    'event_id',     _event_id,
    'my_status',    _status,
    'going_count',  v_going + v_outside
  );
end;
$$;


ALTER FUNCTION "public"."rsvp_public_event"("_event_id" "uuid", "_status" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_attendance"("_event_id" "uuid", "_records" "jsonb") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  _event public.attendance_events;
  _r jsonb;
  _written int := 0;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;

  select * into _event from public.attendance_events where id = _event_id;
  if _event.id is null then raise exception 'event_not_found'; end if;
  if not public.can_take_attendance(auth.uid(), _event.small_group_id) then
    raise exception 'not_authorized';
  end if;

  for _r in select * from jsonb_array_elements(_records) loop
    insert into public.attendance_records (event_id, user_id, present, notes)
    values (
      _event_id,
      (_r->>'user_id')::uuid,
      (_r->>'present')::boolean,
      nullif(_r->>'notes', '')
    )
    on conflict (event_id, user_id) do update
      set present = excluded.present,
          notes   = excluded.notes,
          updated_at = now();
    _written := _written + 1;
  end loop;

  -- Bump the event's updated_at so list views resort correctly
  update public.attendance_events set updated_at = now() where id = _event_id;
  return _written;
end $$;


ALTER FUNCTION "public"."save_attendance"("_event_id" "uuid", "_records" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_map_visibility"("_visible" boolean) RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_uid uuid := auth.uid();
  v_new boolean;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  update public.profiles
    set is_visible_on_map = _visible,
        updated_at = now()
    where id = v_uid
    returning is_visible_on_map into v_new;

  return v_new;
end;
$$;


ALTER FUNCTION "public"."set_map_visibility"("_visible" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_member_role"("_group_id" "uuid", "_user_id" "uuid", "_new_role" "text") RETURNS TABLE("id" "uuid", "group_id" "uuid", "user_id" "uuid", "role" "text", "joined_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_caller        uuid := auth.uid();
  v_is_site_admin boolean := is_site_admin(v_caller);
  v_is_pastor     boolean;
  v_target_role   text;
  v_pastor_count  int;
begin
  if v_caller is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  if _new_role not in ('pastor','leader','member') then
    raise exception 'invalid_role: %', _new_role using errcode = '22023';
  end if;

  v_is_pastor := is_group_pastor(v_caller, _group_id);
  if not (v_is_pastor or v_is_site_admin) then
    raise exception 'forbidden: not a pastor of this group' using errcode = '42501';
  end if;

  if v_caller = _user_id and not v_is_site_admin then
    raise exception 'cannot_change_own_role' using errcode = '42501';
  end if;

  select ygm.role::text into v_target_role
  from public.youth_group_members ygm
  where ygm.group_id = _group_id and ygm.user_id = _user_id;

  if v_target_role is null then
    raise exception 'member_not_found' using errcode = '22023';
  end if;

  if v_target_role = _new_role then
    return query
      select ygm.id, ygm.group_id, ygm.user_id, ygm.role::text, ygm.joined_at
      from public.youth_group_members ygm
      where ygm.group_id = _group_id and ygm.user_id = _user_id;
    return;
  end if;

  if v_target_role = 'pastor' and _new_role <> 'pastor' then
    select count(*) into v_pastor_count
    from public.youth_group_members ygm
    where ygm.group_id = _group_id and ygm.role = 'pastor';
    if v_pastor_count <= 1 then
      raise exception 'cannot_demote_last_pastor' using errcode = '42501';
    end if;
  end if;

  update public.youth_group_members ygm
  set role = _new_role::group_role
  where ygm.group_id = _group_id and ygm.user_id = _user_id;

  return query
    select ygm.id, ygm.group_id, ygm.user_id, ygm.role::text, ygm.joined_at
    from public.youth_group_members ygm
    where ygm.group_id = _group_id and ygm.user_id = _user_id;
end;
$$;


ALTER FUNCTION "public"."set_member_role"("_group_id" "uuid", "_user_id" "uuid", "_new_role" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin new.updated_at = now(); return new; end;
$$;


ALTER FUNCTION "public"."set_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."share_chat_thread"("_other_user_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.thread_subscribers ts_me
    join public.thread_subscribers ts_them
      on ts_me.thread_id = ts_them.thread_id
    where ts_me.user_id   = auth.uid()
      and ts_them.user_id = _other_user_id
  );
$$;


ALTER FUNCTION "public"."share_chat_thread"("_other_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."snapshot_last_week_rankings"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_this_monday date  := (date_trunc('week', now() at time zone 'UTC'))::date;
  v_last_monday date  := v_this_monday - 7;
  v_window_start timestamptz := (v_last_monday::timestamp)::timestamptz at time zone 'UTC';
  v_window_end   timestamptz := (v_this_monday::timestamp)::timestamptz at time zone 'UTC';
begin
  if exists (select 1 from public.weekly_ranking_snapshots where week_start = v_last_monday) then
    return;  -- idempotent
  end if;

  -- Group rankings
  with related_pairs as (
    select yg.id as group_id, p.id as user_id, p.last_opened_at
    from public.youth_groups yg
    join public.youth_group_members ygm on ygm.group_id = yg.id
    join public.profiles p on p.id = ygm.user_id
    where yg.is_default_ygteev = false
    union
    select yg.id, parent_p.id, parent_p.last_opened_at
    from public.youth_groups yg
    join public.youth_group_members child_ygm on child_ygm.group_id = yg.id
    join public.family_members fm_child
      on fm_child.user_id = child_ygm.user_id and fm_child.role = 'child'
    join public.family_members fm_parent
      on fm_parent.family_id = fm_child.family_id and fm_parent.role = 'parent'
    join public.profiles parent_p on parent_p.id = fm_parent.user_id
    where yg.is_default_ygteev = false
  ),
  per_group as (
    select rp.group_id,
           count(distinct rp.user_id) filter (
             where rp.last_opened_at >= v_window_end - interval '90 days'
           )::int as active_count,
           coalesce(sum(g.amount), 0)::bigint as week_xp
    from related_pairs rp
    left join public.user_xp_grants g
      on g.user_id = rp.user_id
     and g.awarded_at >= v_window_start
     and g.awarded_at <  v_window_end
    group by rp.group_id
  ),
  classed as (
    select pg.group_id, pg.active_count, pg.week_xp,
           public.xp_class_for(pg.active_count) as class
    from per_group pg
    where pg.active_count > 0
  ),
  class_meta as (
    select class, max(active_count) as max_active, count(*) as total_in_class
    from classed
    group by class
  ),
  with_multiplier as (
    select c.group_id, c.active_count, c.week_xp, c.class,
           cm.max_active, cm.total_in_class,
           least(
             case when c.active_count = 0 then 1.0
                  else (cm.max_active::numeric / c.active_count::numeric)
             end,
             3.00::numeric
           ) as multiplier
    from classed c
    join class_meta cm on cm.class = c.class
  ),
  ranked as (
    select wm.*,
           floor(wm.week_xp * wm.multiplier)::bigint as adjusted_xp,
           row_number() over (
             partition by wm.class
             order by floor(wm.week_xp * wm.multiplier) desc, wm.multiplier asc
           )::int as rank_in_class
    from with_multiplier wm
  )
  insert into public.weekly_ranking_snapshots
    (week_start, group_id, class, active_count, week_xp,
     multiplier, adjusted_xp, rank_in_class, total_groups_in_class)
  select v_last_monday, group_id, class, active_count, week_xp,
         round(multiplier, 2), adjusted_xp, rank_in_class, total_in_class
  from ranked;

  -- Top 25 users per group (only users with > 0 XP that week)
  with related_pairs as (
    select yg.id as group_id, p.id as user_id
    from public.youth_groups yg
    join public.youth_group_members ygm on ygm.group_id = yg.id
    join public.profiles p on p.id = ygm.user_id
    where yg.is_default_ygteev = false
    union
    select yg.id, parent_p.id
    from public.youth_groups yg
    join public.youth_group_members child_ygm on child_ygm.group_id = yg.id
    join public.family_members fm_child
      on fm_child.user_id = child_ygm.user_id and fm_child.role = 'child'
    join public.family_members fm_parent
      on fm_parent.family_id = fm_child.family_id and fm_parent.role = 'parent'
    join public.profiles parent_p on parent_p.id = fm_parent.user_id
    where yg.is_default_ygteev = false
  ),
  per_user as (
    select rp.group_id, rp.user_id,
           coalesce(sum(g.amount), 0)::bigint as week_xp
    from related_pairs rp
    left join public.user_xp_grants g
      on g.user_id = rp.user_id
     and g.awarded_at >= v_window_start
     and g.awarded_at <  v_window_end
    group by rp.group_id, rp.user_id
  ),
  ranked_users as (
    select pu.group_id, pu.user_id, pu.week_xp,
           row_number() over (
             partition by pu.group_id
             order by pu.week_xp desc, pu.user_id
           )::int as rank
    from per_user pu
    where pu.week_xp > 0
  )
  insert into public.weekly_user_ranking_snapshots
    (week_start, group_id, user_id, week_xp, rank_in_group)
  select v_last_monday, group_id, user_id, week_xp, rank
  from ranked_users
  where rank <= 25;
end;
$$;


ALTER FUNCTION "public"."snapshot_last_week_rankings"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."start_family"("_name" "text" DEFAULT 'My Family'::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare v_caller uuid := auth.uid(); v_verified timestamptz; v_family_id uuid;
begin
  if v_caller is null then raise exception 'not_authenticated'; end if;
  select age_verified_at into v_verified from public.profiles where id = v_caller;
  if v_verified is null then
    raise exception 'age_verification_required'
      using errcode = '22023',
            hint = 'Pay the $0.99 StoreKit IAP and stamp profiles.age_verified_at first.';
  end if;

  insert into public.families (name, created_by)
    values (coalesce(nullif(trim(_name), ''), 'My Family'), v_caller)
  returning id into v_family_id;

  insert into public.family_members (family_id, user_id, role)
    values (v_family_id, v_caller, 'parent');

  insert into public.user_roles (user_id, role)
    values (v_caller, 'parent'::app_role)
    on conflict do nothing;

  return v_family_id;
end;
$_$;


ALTER FUNCTION "public"."start_family"("_name" "text") OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."youth_group_submissions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "submitter_id" "uuid",
    "submitter_email" "text",
    "church_name" "text" NOT NULL,
    "pastor_name" "text" NOT NULL,
    "pastor_email" "text" NOT NULL,
    "status" "public"."group_submission_status" DEFAULT 'pending'::"public"."group_submission_status" NOT NULL,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "decided_at" timestamp with time zone,
    "decided_by" "uuid",
    "lead_stage" "text" DEFAULT 'new_lead'::"text" NOT NULL,
    "emailed_at" timestamp with time zone,
    "email_provider_id" "text",
    "last_followup_at" timestamp with time zone,
    "followup_count" integer DEFAULT 0 NOT NULL,
    "converted_at" timestamp with time zone,
    "lost_at" timestamp with time zone,
    "lost_reason" "text",
    "pastor_phone" "text",
    "referral_channel" "text",
    CONSTRAINT "youth_group_submissions_lead_stage_check" CHECK (("lead_stage" = ANY (ARRAY['new_lead'::"text", 'emailed'::"text", 'following_up'::"text", 'converted'::"text", 'dead'::"text"]))),
    CONSTRAINT "youth_group_submissions_referral_channel_check" CHECK ((("referral_channel" IS NULL) OR ("referral_channel" = ANY (ARRAY['sms'::"text", 'email'::"text"]))))
);


ALTER TABLE "public"."youth_group_submissions" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."submit_youth_group_request"("_church_name" "text", "_pastor_name" "text", "_pastor_email" "text") RETURNS "public"."youth_group_submissions"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare
  _uid uuid := auth.uid();
  _email text;
  _result public.youth_group_submissions;
begin
  if _uid is null then raise exception 'not_authenticated'; end if;
  if length(coalesce(trim(_church_name),  '')) = 0 then raise exception 'missing_church_name';  end if;
  if length(coalesce(trim(_pastor_name),  '')) = 0 then raise exception 'missing_pastor_name';  end if;
  if length(coalesce(trim(_pastor_email), '')) = 0 then raise exception 'missing_pastor_email'; end if;
  if _pastor_email !~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'invalid_email';
  end if;

  select email into _email from auth.users where id = _uid;

  -- Idempotent: same submitter + same church already pending → return that row
  select * into _result
  from public.youth_group_submissions
  where submitter_id = _uid
    and lower(church_name) = lower(trim(_church_name))
    and status = 'pending'
  limit 1;
  if _result.id is not null then return _result; end if;

  insert into public.youth_group_submissions
    (submitter_id, submitter_email, church_name, pastor_name, pastor_email)
  values
    (_uid, _email, trim(_church_name), trim(_pastor_name), trim(_pastor_email))
  returning * into _result;
  return _result;
end $_$;


ALTER FUNCTION "public"."submit_youth_group_request"("_church_name" "text", "_pastor_name" "text", "_pastor_email" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."target_tier_for_count"("_count" integer) RETURNS "text"
    LANGUAGE "sql" STABLE
    AS $$
  with sorted as (
    select id, max_active, is_contact_only, display_order
    from public.subscription_tiers
    where active = true
    order by display_order
  )
  select id
  from sorted
  where (is_contact_only = false and max_active >= _count) or is_contact_only = true
  order by case when is_contact_only then 1 else 0 end, display_order
  limit 1;
$$;


ALTER FUNCTION "public"."target_tier_for_count"("_count" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."tg_attendance_events_default_creator"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if new.created_by is null then
    new.created_by := auth.uid();
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."tg_attendance_events_default_creator"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."tg_bible_plan_days_recompute_rewards"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare v_plan_id uuid;
begin
  v_plan_id := coalesce(new.plan_id, old.plan_id);
  perform public.compute_bible_plan_rewards(v_plan_id);
  return coalesce(new, old);
end;
$$;


ALTER FUNCTION "public"."tg_bible_plan_days_recompute_rewards"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."tg_bible_plans_recompute_rewards_on_days_total"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if new.days_total is distinct from old.days_total then
    perform public.compute_bible_plan_rewards(new.id);
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."tg_bible_plans_recompute_rewards_on_days_total"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."tg_bible_plans_set_published_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  if new.status = 'published' and (old.status is distinct from 'published') then
    new.published_at := coalesce(new.published_at, now());
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."tg_bible_plans_set_published_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."tg_block_pastor_self_leave"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
begin
  if OLD.role = 'pastor' and OLD.user_id = auth.uid() then
    raise exception 'pastor_cannot_leave_own_group'
      using errcode = '42501',
            message = 'Pastors cannot leave their own youth group. '
                      'Transfer ownership or contact support first.';
  end if;
  return OLD;
end;
$$;


ALTER FUNCTION "public"."tg_block_pastor_self_leave"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."tg_chat_on_small_group_member_delete"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  _thread_id uuid;
  _group_id  uuid;
begin
  select youth_group_id into _group_id from public.small_groups where id = OLD.small_group_id;

  -- Unsubscribe from this small_group thread
  select id into _thread_id from public.chat_threads
    where small_group_id = OLD.small_group_id and kind = 'small_group';
  if _thread_id is not null then
    delete from public.thread_subscribers
      where thread_id = _thread_id and user_id = OLD.user_id;
  end if;

  -- Unsubscribe from dm_leader threads in this youth group involving the
  -- leaving user, but ONLY where the leader-member pairing no longer exists
  -- in any remaining small group (i.e., they're not still in another small
  -- group together).
  delete from public.thread_subscribers ts
  using public.chat_threads ct
  where ts.thread_id = ct.id
    and ct.kind = 'dm_leader'
    and ct.group_id = _group_id
    and (ct.dm_user_a = OLD.user_id or ct.dm_user_b = OLD.user_id)
    and ts.user_id = OLD.user_id
    and not exists (
      select 1
      from public.small_group_members m1
      join public.small_group_members m2 on m1.small_group_id = m2.small_group_id
      where m1.user_id = ct.dm_user_a
        and m2.user_id = ct.dm_user_b
        and (m1.role = 'leader' or m2.role = 'leader')
    );

  return OLD;
end $$;


ALTER FUNCTION "public"."tg_chat_on_small_group_member_delete"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."tg_chat_on_small_group_member_insert"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  _thread_id uuid;
  _group_id uuid;
  _peer record;
  _fam record;
begin
  select youth_group_id into _group_id from public.small_groups where id = NEW.small_group_id;
  _thread_id := public.ensure_small_group_thread(NEW.small_group_id);
  insert into public.thread_subscribers(thread_id, user_id)
    values (_thread_id, NEW.user_id) on conflict do nothing;

  if NEW.role = 'member' then
    for _peer in select user_id from public.small_group_members
                 where small_group_id = NEW.small_group_id and role = 'leader' loop
      perform public.ensure_dm_thread(_group_id, 'dm_leader', NEW.user_id, _peer.user_id);
    end loop;
  end if;

  if NEW.role = 'leader' then
    for _peer in select user_id from public.small_group_members
                 where small_group_id = NEW.small_group_id and role = 'member' loop
      perform public.ensure_dm_thread(_group_id, 'dm_leader', NEW.user_id, _peer.user_id);
    end loop;
  end if;

  -- NEW: rewire the joining user's parents for dm_parent_leader threads
  -- against this small group's leader.
  for _fam in
    select fm_p.user_id as parent_id, fm_c.family_id
    from public.family_members fm_c
    join public.family_members fm_p
      on fm_p.family_id = fm_c.family_id and fm_p.role = 'parent'
    where fm_c.user_id = NEW.user_id and fm_c.role = 'child'
  loop
    perform public.ensure_parent_chat_subscriptions(_fam.parent_id, _fam.family_id);
  end loop;

  return NEW;
end $$;


ALTER FUNCTION "public"."tg_chat_on_small_group_member_insert"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."tg_chat_on_youth_group_member_delete"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  _thread_id uuid;
  v_parent uuid;
begin
  -- Default YGTeeV group: nothing to clean up (members never get
  -- group-specific chat subscriptions for it).
  if exists (select 1 from public.youth_groups
             where id = OLD.group_id and is_default_ygteev = true) then
    return OLD;
  end if;

  -- Existing cleanup: leaving user's own subscriptions
  select id into _thread_id from public.chat_threads
    where group_id = OLD.group_id and kind = 'group_main';
  if _thread_id is not null then
    delete from public.thread_subscribers
      where thread_id = _thread_id and user_id = OLD.user_id;
  end if;

  delete from public.thread_subscribers ts
  using public.chat_threads ct
  where ts.thread_id = ct.id
    and ct.group_id = OLD.group_id
    and ct.kind = 'dm_pastor'
    and (ct.dm_user_a = OLD.user_id or ct.dm_user_b = OLD.user_id)
    and ts.user_id = OLD.user_id;

  -- Cascade small-group memberships (its own delete trigger handles SG chat)
  delete from public.small_group_members
    where user_id = OLD.user_id
      and small_group_id in (
        select id from public.small_groups where youth_group_id = OLD.group_id
      );

  -- NEW: parent-of-leaving-child cleanup. For each parent linked to
  -- the leaving child via family_members, check if the parent still
  -- has another child in this youth group. If not, unsubscribe the
  -- parent from this YG's parent threads.
  for v_parent in
    select distinct fm_parent.user_id
    from public.family_members fm_child
    join public.family_members fm_parent
      on fm_parent.family_id = fm_child.family_id and fm_parent.role = 'parent'
    where fm_child.user_id = OLD.user_id and fm_child.role = 'child'
  loop
    if not exists (
      select 1
      from public.family_members fm_p2
      join public.family_members fm_c2
        on fm_c2.family_id = fm_p2.family_id and fm_c2.role = 'child'
      join public.youth_group_members ygm2
        on ygm2.user_id = fm_c2.user_id and ygm2.group_id = OLD.group_id
      where fm_p2.user_id = v_parent
        and fm_p2.role    = 'parent'
        and fm_c2.user_id <> OLD.user_id
    ) then
      -- No other children of this parent in this YG → drop parent's
      -- subscriptions for this group's parent threads.

      -- 1) parent_chat (group-wide)
      delete from public.thread_subscribers ts
      using public.chat_threads t
      where ts.thread_id = t.id
        and t.kind       = 'parent_chat'
        and t.group_id   = OLD.group_id
        and ts.user_id   = v_parent;

      -- 2) dm_parent_pastor (parent ↔ each pastor of this YG)
      delete from public.thread_subscribers ts
      using public.chat_threads t
      where ts.thread_id = t.id
        and t.kind       = 'dm_parent_pastor'
        and t.group_id   = OLD.group_id
        and ts.user_id   = v_parent;

      -- 3) dm_parent_leader (parent ↔ leaders of small groups under this YG)
      delete from public.thread_subscribers ts
      using public.chat_threads t
      join public.small_groups sg on sg.id = t.small_group_id
      where ts.thread_id = t.id
        and t.kind       = 'dm_parent_leader'
        and sg.youth_group_id = OLD.group_id
        and ts.user_id   = v_parent;
    end if;
  end loop;

  return OLD;
end $$;


ALTER FUNCTION "public"."tg_chat_on_youth_group_member_delete"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."tg_chat_on_youth_group_member_insert"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  _main_thread_id uuid;
  _peer record;
  _fam record;
begin
  if exists (select 1 from public.youth_groups where id = NEW.group_id and is_default_ygteev = true) then
    return NEW;
  end if;

  _main_thread_id := public.ensure_group_main_thread(NEW.group_id);
  insert into public.thread_subscribers(thread_id, user_id)
    values (_main_thread_id, NEW.user_id) on conflict do nothing;

  if NEW.role = 'member' then
    for _peer in select user_id from public.youth_group_members
                 where group_id = NEW.group_id and role = 'pastor' loop
      perform public.ensure_dm_thread(NEW.group_id, 'dm_pastor', NEW.user_id, _peer.user_id);
    end loop;
  end if;

  if NEW.role = 'pastor' then
    for _peer in select user_id from public.youth_group_members
                 where group_id = NEW.group_id and role = 'member' loop
      perform public.ensure_dm_thread(NEW.group_id, 'dm_pastor', NEW.user_id, _peer.user_id);
    end loop;
  end if;

  -- NEW: if the joining user is a child in any family, rewire each of
  -- that family's parents for parent_chat / dm_parent_pastor.
  for _fam in
    select fm_p.user_id as parent_id, fm_c.family_id
    from public.family_members fm_c
    join public.family_members fm_p
      on fm_p.family_id = fm_c.family_id and fm_p.role = 'parent'
    where fm_c.user_id = NEW.user_id and fm_c.role = 'child'
  loop
    perform public.ensure_parent_chat_subscriptions(_fam.parent_id, _fam.family_id);
  end loop;

  return NEW;
end $$;


ALTER FUNCTION "public"."tg_chat_on_youth_group_member_insert"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."tg_family_members_subscribe_parents"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare v_parent uuid;
begin
  for v_parent in
    select user_id from public.family_members
    where family_id = new.family_id and role = 'parent'
  loop
    perform public.ensure_parent_chat_subscriptions(v_parent, new.family_id);
  end loop;
  return new;
end;
$$;


ALTER FUNCTION "public"."tg_family_members_subscribe_parents"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."tg_feed_post_engagement_recount"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare v_post uuid;
begin
  v_post := coalesce(new.post_id, old.post_id);
  update public.feed_posts
    set views_count = (select count(*) from public.feed_post_engagement
                        where post_id = v_post and first_viewed_at is not null),
        likes_count = (select count(*) from public.feed_post_engagement
                        where post_id = v_post and liked_at is not null),
        updated_at  = now()
    where id = v_post;
  return coalesce(new, old);
end;
$$;


ALTER FUNCTION "public"."tg_feed_post_engagement_recount"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."tg_kick_instagram_scrape"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_should_kick boolean := false;
  v_svc text;
begin
  if TG_OP = 'INSERT' then
    v_should_kick := coalesce(NEW.is_active, false);
  elsif TG_OP = 'UPDATE' then
    v_should_kick := coalesce(NEW.is_active, false) and (
      coalesce(OLD.is_active, false) = false
      or coalesce(OLD.handle, '') <> coalesce(NEW.handle, '')
    );
  end if;

  if not v_should_kick then
    return NEW;
  end if;

  v_svc := coalesce(public._get_service_role_key(), '');
  if length(v_svc) < 20 then
    raise warning '[tg_kick_instagram_scrape] no service key in _internal_secrets — skipping http_post';
    return NEW;
  end if;

  perform net.http_post(
    url     := 'https://tkesywmshaicjmywbovn.supabase.co/functions/v1/trigger-instagram-scrapes',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_svc
    ),
    body    := jsonb_build_object('source_ids', jsonb_build_array(NEW.id))
  );
  return NEW;
exception when others then
  raise warning '[tg_kick_instagram_scrape] http_post failed: %', sqlerrm;
  return NEW;
end;
$$;


ALTER FUNCTION "public"."tg_kick_instagram_scrape"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."tg_notify_pastor_on_join_request"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_url text := 'https://tkesywmshaicjmywbovn.supabase.co/functions/v1/send-join-request-email';
begin
  if NEW.status::text <> 'pending' then
    return NEW;
  end if;

  perform net.http_post(
    url     := v_url,
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body    := jsonb_build_object('request_id', NEW.id)
  );
  return NEW;
exception when others then
  -- Don't block the insert if the HTTP call setup fails. Log to
  -- Postgres so we can see it in dashboard logs.
  raise warning '[tg_notify_pastor_on_join_request] http_post failed: %', sqlerrm;
  return NEW;
end;
$$;


ALTER FUNCTION "public"."tg_notify_pastor_on_join_request"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."tg_profiles_lock_handle"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if tg_op = 'UPDATE'
     and old.handle is not null
     and new.handle is distinct from old.handle
     and not coalesce(public.is_site_admin(auth.uid()), false)
  then
    raise exception 'handle_locked' using errcode = '42501';
  end if;
  return new;
end $$;


ALTER FUNCTION "public"."tg_profiles_lock_handle"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."tg_send_lead_welcome_email"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'net'
    AS $$
declare
  _url text := 'https://tkesywmshaicjmywbovn.supabase.co/functions/v1/send-lead-welcome-email';
begin
  -- New: skip the cold-outreach email when the student handled
  -- the outreach (SMS or email) directly from the iOS sheet.
  if NEW.referral_channel is not null then
    return NEW;
  end if;

  perform net.http_post(
    url     := _url,
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body    := jsonb_build_object('submission_id', NEW.id::text)
  );
  return NEW;
end $$;


ALTER FUNCTION "public"."tg_send_lead_welcome_email"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."tg_touch_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin new.updated_at := now(); return new; end;
$$;


ALTER FUNCTION "public"."tg_touch_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."thread_group_id"("_thread_id" "uuid") RETURNS "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select group_id from public.chat_threads where id = _thread_id;
$$;


ALTER FUNCTION "public"."thread_group_id"("_thread_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."touch_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin new.updated_at = now(); return new; end $$;


ALTER FUNCTION "public"."touch_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."try_parse_uuid"("_s" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
begin
  return _s::uuid;
exception when others then
  return null;
end $$;


ALTER FUNCTION "public"."try_parse_uuid"("_s" "text") OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "display_name" "text",
    "email" "text",
    "avatar_url" "text",
    "age_band" "text",
    "xp" integer DEFAULT 0 NOT NULL,
    "water" integer DEFAULT 0 NOT NULL,
    "streak" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "last_opened_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "last_streak_date" "date",
    "current_streak_run_id" "uuid",
    "bio" "text",
    "is_visible_on_map" boolean DEFAULT true NOT NULL,
    "deleted_at" timestamp with time zone,
    "age_verified_at" timestamp with time zone,
    "date_of_birth" "date",
    "grade_year" integer,
    "parent_account_id" "uuid",
    "is_managed_child" boolean DEFAULT false NOT NULL,
    "lifetime_xp" bigint DEFAULT 0 NOT NULL,
    "handle" "text" NOT NULL,
    CONSTRAINT "profiles_bio_length" CHECK ((("bio" IS NULL) OR ("char_length"("bio") <= 280))),
    CONSTRAINT "profiles_grade_year_check" CHECK ((("grade_year" IS NULL) OR (("grade_year" >= 1) AND ("grade_year" <= 20))))
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_managed_profile"("_target_user_id" "uuid", "_display_name" "text" DEFAULT NULL::"text", "_avatar_url" "text" DEFAULT NULL::"text", "_bio" "text" DEFAULT NULL::"text") RETURNS "public"."profiles"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare _result public.profiles;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not public.can_manage_user_profile(auth.uid(), _target_user_id) then
    raise exception 'not_authorized';
  end if;
  if _bio is not null and char_length(_bio) > 280 then
    raise exception 'bio_too_long';
  end if;

  update public.profiles
     set display_name = coalesce(_display_name, display_name),
         avatar_url   = coalesce(_avatar_url,   avatar_url),
         bio          = coalesce(_bio,          bio),
         updated_at   = now()
   where id = _target_user_id
   returning * into _result;
  if _result.id is null then raise exception 'profile_not_found'; end if;
  return _result;
end $$;


ALTER FUNCTION "public"."update_managed_profile"("_target_user_id" "uuid", "_display_name" "text", "_avatar_url" "text", "_bio" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."xp_class_for"("_active_count" integer) RETURNS "text"
    LANGUAGE "sql" IMMUTABLE PARALLEL SAFE
    AS $$
  select case
    when _active_count <= 0   then null
    when _active_count <= 19  then 'bolts'
    when _active_count <= 49  then 'volts'
    when _active_count <= 99  then 'surge'
    when _active_count <= 199 then 'storm'
    when _active_count <= 499 then 'thunder'
    else 'legends'
  end;
$$;


ALTER FUNCTION "public"."xp_class_for"("_active_count" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."xp_for_level"("_level" integer) RETURNS bigint
    LANGUAGE "sql" IMMUTABLE PARALLEL SAFE
    AS $$
  select case when _level < 1 then 0::bigint
              else (500 * _level * (_level - 1))::bigint end;
$$;


ALTER FUNCTION "public"."xp_for_level"("_level" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."youth_group_public_profile"("_group_id" "uuid") RETURNS TABLE("id" "uuid", "name" "text", "church_name" "text", "description" "text", "address" "text", "meeting_time" "text", "logo_url" "text", "gradient_from" "text", "gradient_to" "text", "latitude" double precision, "longitude" double precision, "member_count" integer, "small_group_count" integer, "leaders" "jsonb", "upcoming_events" "jsonb", "viewer_is_member" boolean, "viewer_pending_request" boolean, "group_type" "text", "grades" integer[])
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    yg.id, yg.name, yg.church_name, yg.description, yg.address,
    yg.meeting_time, yg.logo_url, yg.gradient_from, yg.gradient_to,
    yg.latitude, yg.longitude,
    (select count(*)::int from public.youth_group_members where group_id = yg.id),
    (select count(*)::int from public.small_groups       where youth_group_id = yg.id),
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id, 'display_name', p.display_name,
        'avatar_url', p.avatar_url, 'role', ygm.role
      ) order by case ygm.role when 'pastor' then 0 when 'leader' then 1 else 2 end, p.display_name)
      from public.youth_group_members ygm
      join public.profiles p on p.id = ygm.user_id
      where ygm.group_id = yg.id and ygm.role in ('pastor','leader')
    ), '[]'::jsonb),
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', e.id, 'title', e.title, 'description', e.description,
        'starts_at', e.starts_at, 'location', e.location,
        'cover_url', e.cover_url, 'capacity', e.capacity,
        'rsvp_audience', e.rsvp_audience
      ) order by e.starts_at)
      from public.events e
      where e.group_id = yg.id
        and e.starts_at >= now()
        and e.visibility = 'public'
    ), '[]'::jsonb),
    exists (
      select 1 from public.youth_group_members
      where group_id = yg.id and user_id = auth.uid()
    ),
    exists (
      select 1 from public.youth_group_join_requests
      where group_id = yg.id and user_id = auth.uid() and status = 'pending'
    ),
    yg.group_type,
    yg.grades
  from public.youth_groups yg
  where yg.id = _group_id
    and yg.is_public = true
    and yg.is_default_ygteev = false;
$$;


ALTER FUNCTION "public"."youth_group_public_profile"("_group_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."youth_groups_near"("_lat" double precision, "_lng" double precision, "_meters" numeric DEFAULT 40234) RETURNS TABLE("id" "uuid", "name" "text", "church_name" "text", "description" "text", "address" "text", "meeting_time" "text", "logo_url" "text", "gradient_from" "text", "gradient_to" "text", "latitude" double precision, "longitude" double precision, "distance_m" double precision, "member_count" integer, "small_group_count" integer, "group_type" "text", "grades" integer[])
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with origin as (
    select st_setsrid(st_makepoint(_lng, _lat), 4326)::geography as g
  )
  select
    yg.id, yg.name, yg.church_name, yg.description, yg.address,
    yg.meeting_time, yg.logo_url, yg.gradient_from, yg.gradient_to,
    yg.latitude, yg.longitude,
    st_distance(yg.location, origin.g) as distance_m,
    (select count(*)::int from public.youth_group_members where group_id = yg.id) as member_count,
    (select count(*)::int from public.small_groups where youth_group_id = yg.id) as small_group_count,
    yg.group_type,
    yg.grades
  from public.youth_groups yg, origin
  where yg.location is not null
    and yg.is_public = true
    and yg.is_default_ygteev = false
    and st_dwithin(yg.location, origin.g, _meters)
  order by yg.location <-> origin.g;
$$;


ALTER FUNCTION "public"."youth_groups_near"("_lat" double precision, "_lng" double precision, "_meters" numeric) OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."_internal_secrets" (
    "key" "text" NOT NULL,
    "value" "text" NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."_internal_secrets" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."apple_subscriptions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "original_transaction_id" "text" NOT NULL,
    "product_id" "text" NOT NULL,
    "status" "text" NOT NULL,
    "expires_at" timestamp with time zone,
    "raw_payload" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "apple_subscriptions_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'in_grace'::"text", 'expired'::"text", 'revoked'::"text", 'paused'::"text"])))
);


ALTER TABLE "public"."apple_subscriptions" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."attendance_event_summary" AS
SELECT
    NULL::"uuid" AS "event_id",
    NULL::"uuid" AS "small_group_id",
    NULL::"text" AS "small_group_name",
    NULL::"uuid" AS "youth_group_id",
    NULL::"text" AS "title",
    NULL::timestamp with time zone AS "occurred_at",
    NULL::"uuid" AS "created_by",
    NULL::bigint AS "roster_total",
    NULL::bigint AS "present_count",
    NULL::bigint AS "absent_count",
    NULL::timestamp with time zone AS "created_at",
    NULL::timestamp with time zone AS "updated_at";


ALTER VIEW "public"."attendance_event_summary" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."attendance_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "small_group_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "occurred_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "notes" "text",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."attendance_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."attendance_records" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "event_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "present" boolean NOT NULL,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."attendance_records" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."bible_plan_completions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "plan_id" "uuid" NOT NULL,
    "completed_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."bible_plan_completions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."bible_plan_day_progress" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "plan_id" "uuid" NOT NULL,
    "day_id" "uuid" NOT NULL,
    "step_xp_earned" integer DEFAULT 0 NOT NULL,
    "step_water_earned" integer DEFAULT 0 NOT NULL,
    "completed_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."bible_plan_day_progress" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."bible_plan_days" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "plan_id" "uuid" NOT NULL,
    "day_number" integer NOT NULL,
    "title" "text" NOT NULL,
    "scripture_reference" "text" NOT NULL,
    "reflection" "text",
    "sections" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "bible_plan_days_day_number_check" CHECK (("day_number" >= 1))
);


ALTER TABLE "public"."bible_plan_days" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."bible_plan_step_progress" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "plan_id" "uuid" NOT NULL,
    "day_id" "uuid" NOT NULL,
    "step" "public"."bible_plan_step" NOT NULL,
    "payload" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "xp_earned" integer DEFAULT 0 NOT NULL,
    "water_earned" integer DEFAULT 0 NOT NULL,
    "completed_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."bible_plan_step_progress" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."bible_plans" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "slug" "text" NOT NULL,
    "description" "text",
    "category" "public"."bible_plan_category" NOT NULL,
    "scope" "public"."bible_plan_scope" DEFAULT 'global'::"public"."bible_plan_scope" NOT NULL,
    "group_id" "uuid",
    "status" "public"."bible_plan_status" DEFAULT 'draft'::"public"."bible_plan_status" NOT NULL,
    "days_total" integer NOT NULL,
    "gradient_from" "text" DEFAULT '#6B2BFF'::"text" NOT NULL,
    "gradient_to" "text" DEFAULT '#FF3DA5'::"text" NOT NULL,
    "recommended_order" integer,
    "is_free_entry" boolean DEFAULT false NOT NULL,
    "xp_reward" integer DEFAULT 0 NOT NULL,
    "water_reward" integer DEFAULT 0 NOT NULL,
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "header_kind" "text" DEFAULT 'gradient'::"text" NOT NULL,
    "header_image_url" "text",
    "gradient_index" integer DEFAULT 0 NOT NULL,
    "published_at" timestamp with time zone,
    "visibility" "public"."bible_plan_visibility" DEFAULT 'private'::"public"."bible_plan_visibility" NOT NULL,
    "additional_group_ids" "uuid"[] DEFAULT '{}'::"uuid"[] NOT NULL,
    CONSTRAINT "bible_plans_additional_excludes_primary" CHECK ((("group_id" IS NULL) OR (NOT ("group_id" = ANY ("additional_group_ids"))))),
    CONSTRAINT "bible_plans_check" CHECK (((("scope" = 'group'::"public"."bible_plan_scope") AND ("group_id" IS NOT NULL)) OR (("scope" = 'global'::"public"."bible_plan_scope") AND ("group_id" IS NULL)))),
    CONSTRAINT "bible_plans_days_total_check" CHECK (("days_total" >= 1)),
    CONSTRAINT "bible_plans_gradient_index_check" CHECK ((("gradient_index" >= 0) AND ("gradient_index" <= 4))),
    CONSTRAINT "bible_plans_header_kind_check" CHECK (("header_kind" = ANY (ARRAY['gradient'::"text", 'photo'::"text", 'upload'::"text"])))
);


ALTER TABLE "public"."bible_plans" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."chat_threads" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "group_id" "uuid" NOT NULL,
    "small_group_id" "uuid",
    "kind" "public"."thread_kind" NOT NULL,
    "moderation_policy" "public"."thread_moderation_policy" DEFAULT 'block'::"public"."thread_moderation_policy" NOT NULL,
    "dm_user_a" "uuid",
    "dm_user_b" "uuid",
    "last_message_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "chat_threads_dm_canonical_order" CHECK ((("dm_user_a" IS NULL) OR ("dm_user_b" IS NULL) OR ("dm_user_a" < "dm_user_b")))
);


ALTER TABLE "public"."chat_threads" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."child_pairing_tokens" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "child_user_id" "uuid" NOT NULL,
    "token" "text" NOT NULL,
    "numeric_code" "text" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "expires_at" timestamp with time zone DEFAULT ("now"() + '00:05:00'::interval) NOT NULL,
    "redeemed_at" timestamp with time zone,
    "redeemed_from_user_agent" "text"
);


ALTER TABLE "public"."child_pairing_tokens" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."event_external_rsvps" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "event_id" "uuid" NOT NULL,
    "email" "text" NOT NULL,
    "display_name" "text",
    "grade_year" integer,
    "status" "text" DEFAULT 'going'::"text" NOT NULL,
    "inviter_user_id" "uuid",
    "source" "text" DEFAULT 'invite_link'::"text" NOT NULL,
    "converted_to_user_id" "uuid",
    "converted_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "event_external_rsvps_grade_year_check" CHECK ((("grade_year" IS NULL) OR (("grade_year" >= 6) AND ("grade_year" <= 12)))),
    CONSTRAINT "event_external_rsvps_status_check" CHECK (("status" = ANY (ARRAY['going'::"text", 'maybe'::"text", 'declined'::"text"])))
);


ALTER TABLE "public"."event_external_rsvps" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."event_media" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "event_id" "uuid" NOT NULL,
    "kind" "public"."event_media_kind" NOT NULL,
    "storage_path" "text",
    "video_id" "uuid",
    "caption" "text",
    "uploaded_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "event_media_payload_check" CHECK (((("kind" = 'photo'::"public"."event_media_kind") AND ("storage_path" IS NOT NULL)) OR (("kind" = 'video'::"public"."event_media_kind") AND (("storage_path" IS NOT NULL) OR ("video_id" IS NOT NULL)))))
);


ALTER TABLE "public"."event_media" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."event_rsvps" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "event_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "status" "public"."rsvp_status" DEFAULT 'going'::"public"."rsvp_status" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."event_rsvps" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "group_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "starts_at" timestamp with time zone NOT NULL,
    "location" "text" NOT NULL,
    "visibility" "public"."event_visibility" DEFAULT 'groupPrivate'::"public"."event_visibility" NOT NULL,
    "capacity" integer,
    "cover_url" "text",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "rsvp_audience" "public"."event_rsvp_audience" DEFAULT 'members_only'::"public"."event_rsvp_audience" NOT NULL,
    "latitude" double precision,
    "longitude" double precision,
    CONSTRAINT "events_rsvp_audience_consistent" CHECK ((("visibility" = 'public'::"public"."event_visibility") OR ("rsvp_audience" = 'members_only'::"public"."event_rsvp_audience")))
);


ALTER TABLE "public"."events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."families" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" DEFAULT 'My Family'::"text" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone
);


ALTER TABLE "public"."families" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."family_invites" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "family_id" "uuid" NOT NULL,
    "pairing_code" "text" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "invited_user_id" "uuid",
    "invited_email" "text",
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "expires_at" timestamp with time zone DEFAULT ("now"() + '00:10:00'::interval) NOT NULL,
    "accepted_by" "uuid",
    "accepted_at" timestamp with time zone,
    CONSTRAINT "family_invites_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'accepted'::"text", 'expired'::"text", 'cancelled'::"text"])))
);


ALTER TABLE "public"."family_invites" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."family_members" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "family_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "role" "text" NOT NULL,
    "joined_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "family_members_role_check" CHECK (("role" = ANY (ARRAY['parent'::"text", 'child'::"text"])))
);


ALTER TABLE "public"."family_members" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."feed_post_engagement" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "post_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "first_viewed_at" timestamp with time zone,
    "watch_completed_at" timestamp with time zone,
    "liked_at" timestamp with time zone
);


ALTER TABLE "public"."feed_post_engagement" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."feed_post_photos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "post_id" "uuid" NOT NULL,
    "storage_path" "text" NOT NULL,
    "display_order" integer DEFAULT 0 NOT NULL,
    "alt_text" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."feed_post_photos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."feed_posts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "post_type" "text" NOT NULL,
    "scope" "text" NOT NULL,
    "group_id" "uuid",
    "source_kind" "text" NOT NULL,
    "source_url" "text",
    "source_handle" "text",
    "source_post_id" "text",
    "title" "text",
    "caption" "text",
    "video_id" "uuid",
    "slideshow_seconds_per_photo" numeric DEFAULT 3.0,
    "status" "text" DEFAULT 'draft'::"text" NOT NULL,
    "published_at" timestamp with time zone,
    "views_count" integer DEFAULT 0 NOT NULL,
    "likes_count" integer DEFAULT 0 NOT NULL,
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "feed_posts_post_type_check" CHECK (("post_type" = ANY (ARRAY['video'::"text", 'slideshow'::"text"]))),
    CONSTRAINT "feed_posts_scope_check" CHECK (("scope" = ANY (ARRAY['ygteev_official'::"text", 'group'::"text"]))),
    CONSTRAINT "feed_posts_scope_group_check" CHECK (((("scope" = 'group'::"text") AND ("group_id" IS NOT NULL)) OR (("scope" = 'ygteev_official'::"text") AND ("group_id" IS NULL)))),
    CONSTRAINT "feed_posts_slideshow_seconds_per_photo_check" CHECK ((("slideshow_seconds_per_photo" IS NULL) OR (("slideshow_seconds_per_photo" >= (1)::numeric) AND ("slideshow_seconds_per_photo" <= (10)::numeric)))),
    CONSTRAINT "feed_posts_source_kind_check" CHECK (("source_kind" = ANY (ARRAY['pastor_upload'::"text", 'ygteev_curated'::"text", 'instagram_scrape'::"text", 'cross_group_approved'::"text"]))),
    CONSTRAINT "feed_posts_status_check" CHECK (("status" = ANY (ARRAY['draft'::"text", 'pending_approval'::"text", 'published'::"text", 'archived'::"text"])))
);


ALTER TABLE "public"."feed_posts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."instagram_scrape_jobs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "source_id" "uuid",
    "apify_run_id" "text",
    "apify_dataset_id" "text",
    "status" "text" DEFAULT 'started'::"text" NOT NULL,
    "started_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "finished_at" timestamp with time zone,
    "new_posts_count" integer DEFAULT 0,
    "error_message" "text",
    CONSTRAINT "instagram_scrape_jobs_status_check" CHECK (("status" = ANY (ARRAY['started'::"text", 'succeeded'::"text", 'failed'::"text", 'timeout'::"text"])))
);


ALTER TABLE "public"."instagram_scrape_jobs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."instagram_sources" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "group_id" "uuid" NOT NULL,
    "handle" "text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "added_by" "uuid",
    "added_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "last_scraped_at" timestamp with time zone,
    "results_limit" integer DEFAULT 25 NOT NULL,
    CONSTRAINT "instagram_sources_results_limit_check" CHECK ((("results_limit" >= 1) AND ("results_limit" <= 200)))
);


ALTER TABLE "public"."instagram_sources" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "thread_id" "uuid" NOT NULL,
    "sender_id" "uuid" NOT NULL,
    "body" "text" NOT NULL,
    "moderation_status" "public"."moderation_status" DEFAULT 'clean'::"public"."moderation_status" NOT NULL,
    "moderation_categories" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "messages_body_check" CHECK ((("length"("body") >= 1) AND ("length"("body") <= 4000)))
);


ALTER TABLE "public"."messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."moderation_alerts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "thread_id" "uuid" NOT NULL,
    "message_id" "uuid",
    "group_id" "uuid" NOT NULL,
    "sender_id" "uuid",
    "status" "public"."moderation_status" NOT NULL,
    "categories" "jsonb",
    "preview" "text",
    "acknowledged_at" timestamp with time zone,
    "acknowledged_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "concern_category" "text",
    "concern_confidence" numeric,
    "concern_reason" "text"
);


ALTER TABLE "public"."moderation_alerts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."moderation_flags" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "group_id" "uuid",
    "user_id" "uuid",
    "thread" "text",
    "excerpt" "text",
    "category" "text",
    "score" numeric,
    "severity" "public"."flag_severity" DEFAULT 'medium'::"public"."flag_severity" NOT NULL,
    "status" "public"."flag_status" DEFAULT 'open'::"public"."flag_status" NOT NULL,
    "pastor_notified" boolean DEFAULT false NOT NULL,
    "flagged_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."moderation_flags" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."stripe_subscriptions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "group_id" "uuid",
    "pastor_user_id" "uuid",
    "draft_id" "uuid",
    "stripe_customer_id" "text" NOT NULL,
    "stripe_subscription_id" "text" NOT NULL,
    "stripe_price_id" "text" NOT NULL,
    "tier_id" "text",
    "status" "public"."stripe_subscription_status" NOT NULL,
    "trial_end" timestamp with time zone,
    "current_period_start" timestamp with time zone,
    "current_period_end" timestamp with time zone,
    "cancel_at_period_end" boolean DEFAULT false NOT NULL,
    "canceled_at" timestamp with time zone,
    "raw_payload" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "pending_tier_id" "text",
    "pending_effective_at" timestamp with time zone,
    "last_synced_at" timestamp with time zone
);


ALTER TABLE "public"."stripe_subscriptions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."subscription_tiers" (
    "id" "text" NOT NULL,
    "display_order" integer NOT NULL,
    "name" "text" NOT NULL,
    "range_label" "text" NOT NULL,
    "max_active" integer NOT NULL,
    "price_cents" integer NOT NULL,
    "currency" "text" DEFAULT 'usd'::"text" NOT NULL,
    "stripe_price_id" "text",
    "active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "is_contact_only" boolean DEFAULT false NOT NULL
);


ALTER TABLE "public"."subscription_tiers" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."pastor_billing_summary" AS
 SELECT "ss"."id" AS "subscription_id",
    "ss"."pastor_user_id",
    "ss"."status",
    "ss"."tier_id" AS "current_tier_id",
    "t"."name" AS "current_tier_name",
    "t"."range_label" AS "current_range",
    "t"."max_active" AS "current_max_active",
    "public"."pastor_active_user_count"("ss"."pastor_user_id") AS "active_count",
    "public"."target_tier_for_count"("public"."pastor_active_user_count"("ss"."pastor_user_id")) AS "target_tier_id",
    "ss"."pending_tier_id",
    "ss"."pending_effective_at",
    "ss"."current_period_end",
    "ss"."trial_end",
    "ss"."cancel_at_period_end"
   FROM ("public"."stripe_subscriptions" "ss"
     LEFT JOIN "public"."subscription_tiers" "t" ON (("t"."id" = "ss"."tier_id")));


ALTER VIEW "public"."pastor_billing_summary" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pastor_signup_drafts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "email" "text",
    "first_name" "text",
    "last_name" "text",
    "church_name" "text",
    "address_line" "text",
    "address_city" "text",
    "latitude" double precision,
    "longitude" double precision,
    "meeting_day" "text",
    "meeting_time" "text",
    "group_name" "text",
    "description" "text",
    "gradient_idx" integer DEFAULT 0,
    "logo_url" "text",
    "public_on_map" boolean DEFAULT true,
    "tier_id" "text",
    "stage" "public"."pastor_signup_stage" DEFAULT 'account'::"public"."pastor_signup_stage" NOT NULL,
    "resumed_at" timestamp with time zone,
    "reminder_sent_at" timestamp with time zone,
    "finalized_youth_group_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "promo_code" "text"
);


ALTER TABLE "public"."pastor_signup_drafts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pastor_signup_promos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "code" "text" NOT NULL,
    "trial_days" integer NOT NULL,
    "label" "text",
    "description" "text",
    "active" boolean DEFAULT true NOT NULL,
    "expires_at" timestamp with time zone,
    "max_uses" integer,
    "uses_count" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "pastor_signup_promos_trial_days_check" CHECK ((("trial_days" >= 1) AND ("trial_days" <= 365)))
);


ALTER TABLE "public"."pastor_signup_promos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."small_group_members" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "small_group_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "role" "public"."small_group_role" DEFAULT 'member'::"public"."small_group_role" NOT NULL,
    "joined_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."small_group_members" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."small_groups" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "youth_group_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "meeting_day" "text",
    "meeting_time" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."small_groups" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."store_item_levels" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "item_id" "uuid" NOT NULL,
    "level" integer NOT NULL,
    "label" "text" NOT NULL,
    "water_to_next" integer DEFAULT 0 NOT NULL,
    "size_px" integer DEFAULT 24 NOT NULL,
    "sprite_url" "text"
);


ALTER TABLE "public"."store_item_levels" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."store_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "type" "public"."item_type" NOT NULL,
    "cost_xp" integer DEFAULT 0 NOT NULL,
    "default_water_per_level" integer DEFAULT 3 NOT NULL,
    "rarity" "public"."item_rarity" DEFAULT 'common'::"public"."item_rarity" NOT NULL,
    "active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."store_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."stripe_events" (
    "id" "text" NOT NULL,
    "type" "text" NOT NULL,
    "received_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "payload" "jsonb" NOT NULL,
    "processed_at" timestamp with time zone,
    "error_message" "text"
);


ALTER TABLE "public"."stripe_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."thread_subscribers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "thread_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "joined_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "last_read_at" timestamp with time zone
);


ALTER TABLE "public"."thread_subscribers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_roles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "role" "public"."app_role" NOT NULL
);


ALTER TABLE "public"."user_roles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_streak_milestone_grants" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "run_id" "uuid" NOT NULL,
    "milestone" integer NOT NULL,
    "xp_awarded" integer NOT NULL,
    "water_awarded" integer NOT NULL,
    "awarded_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "user_streak_milestone_grants_milestone_check" CHECK (("milestone" = ANY (ARRAY[3, 7, 10, 15, 20, 25, 30])))
);


ALTER TABLE "public"."user_streak_milestone_grants" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_xp_grants" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "amount" integer NOT NULL,
    "source" "text" NOT NULL,
    "awarded_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "user_xp_grants_amount_check" CHECK (("amount" >= 0))
);


ALTER TABLE "public"."user_xp_grants" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."videos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "scope" "public"."video_scope" DEFAULT 'global'::"public"."video_scope" NOT NULL,
    "group_id" "uuid",
    "policy" "public"."video_policy" DEFAULT 'public'::"public"."video_policy" NOT NULL,
    "mux_upload_id" "text",
    "mux_asset_id" "text",
    "mux_playback_id" "text",
    "duration_sec" numeric,
    "aspect_ratio" "text",
    "status" "public"."video_status" DEFAULT 'uploading'::"public"."video_status" NOT NULL,
    "views" integer DEFAULT 0 NOT NULL,
    "published_at" timestamp with time zone,
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "plan_day_id" "uuid",
    "plan_block_id" "text"
);


ALTER TABLE "public"."videos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."weekly_ranking_snapshots" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "week_start" "date" NOT NULL,
    "group_id" "uuid" NOT NULL,
    "class" "text" NOT NULL,
    "active_count" integer NOT NULL,
    "week_xp" bigint NOT NULL,
    "multiplier" numeric(5,2) NOT NULL,
    "adjusted_xp" bigint NOT NULL,
    "rank_in_class" integer NOT NULL,
    "total_groups_in_class" integer NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."weekly_ranking_snapshots" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."weekly_user_ranking_snapshots" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "week_start" "date" NOT NULL,
    "group_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "week_xp" bigint NOT NULL,
    "rank_in_group" integer NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."weekly_user_ranking_snapshots" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."youth_group_members" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "group_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "role" "public"."group_role" DEFAULT 'member'::"public"."group_role" NOT NULL,
    "joined_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."youth_group_members" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."youth_groups" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "church_name" "text" NOT NULL,
    "description" "text",
    "meeting_time" "text",
    "address" "text",
    "logo_url" "text",
    "gradient_from" "text",
    "gradient_to" "text",
    "is_public" boolean DEFAULT true NOT NULL,
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "is_default_ygteev" boolean DEFAULT false NOT NULL,
    "latitude" double precision,
    "longitude" double precision,
    "location" "public"."geography"(Point,4326) GENERATED ALWAYS AS (
CASE
    WHEN (("latitude" IS NOT NULL) AND ("longitude" IS NOT NULL)) THEN ("public"."st_setsrid"("public"."st_makepoint"("longitude", "latitude"), 4326))::"public"."geography"
    ELSE NULL::"public"."geography"
END) STORED,
    "stripe_customer_id" "text",
    "group_type" "text",
    "grades" integer[],
    CONSTRAINT "youth_groups_grades_range_check" CHECK ((("grades" IS NULL) OR ((("array_length"("grades", 1) >= 1) AND ("array_length"("grades", 1) <= 7)) AND ("grades" <@ ARRAY[6, 7, 8, 9, 10, 11, 12])))),
    CONSTRAINT "youth_groups_group_type_check" CHECK ((("group_type" IS NULL) OR ("group_type" = ANY (ARRAY['hs'::"text", 'ms'::"text", 'hs_ms'::"text"])))),
    CONSTRAINT "youth_groups_lat_range" CHECK ((("latitude" IS NULL) OR (("latitude" >= ('-90'::integer)::double precision) AND ("latitude" <= (90)::double precision)))),
    CONSTRAINT "youth_groups_lng_range" CHECK ((("longitude" IS NULL) OR (("longitude" >= ('-180'::integer)::double precision) AND ("longitude" <= (180)::double precision))))
);


ALTER TABLE "public"."youth_groups" OWNER TO "postgres";


COMMENT ON COLUMN "public"."youth_groups"."group_type" IS '''hs'' | ''ms'' | ''hs_ms'' — broad audience tier set by the pastor.';



COMMENT ON COLUMN "public"."youth_groups"."grades" IS 'Specific grade-levels (6..12) the group serves.';



ALTER TABLE ONLY "public"."_internal_secrets"
    ADD CONSTRAINT "_internal_secrets_pkey" PRIMARY KEY ("key");



ALTER TABLE ONLY "public"."apple_subscriptions"
    ADD CONSTRAINT "apple_subscriptions_original_transaction_id_key" UNIQUE ("original_transaction_id");



ALTER TABLE ONLY "public"."apple_subscriptions"
    ADD CONSTRAINT "apple_subscriptions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."attendance_events"
    ADD CONSTRAINT "attendance_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."attendance_records"
    ADD CONSTRAINT "attendance_records_event_id_user_id_key" UNIQUE ("event_id", "user_id");



ALTER TABLE ONLY "public"."attendance_records"
    ADD CONSTRAINT "attendance_records_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."bible_plan_completions"
    ADD CONSTRAINT "bible_plan_completions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."bible_plan_completions"
    ADD CONSTRAINT "bible_plan_completions_user_id_plan_id_key" UNIQUE ("user_id", "plan_id");



ALTER TABLE ONLY "public"."bible_plan_day_progress"
    ADD CONSTRAINT "bible_plan_day_progress_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."bible_plan_day_progress"
    ADD CONSTRAINT "bible_plan_day_progress_user_id_day_id_key" UNIQUE ("user_id", "day_id");



ALTER TABLE ONLY "public"."bible_plan_days"
    ADD CONSTRAINT "bible_plan_days_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."bible_plan_days"
    ADD CONSTRAINT "bible_plan_days_plan_day_uniq" UNIQUE ("plan_id", "day_number");



ALTER TABLE ONLY "public"."bible_plan_days"
    ADD CONSTRAINT "bible_plan_days_plan_id_day_number_key" UNIQUE ("plan_id", "day_number");



ALTER TABLE ONLY "public"."bible_plan_step_progress"
    ADD CONSTRAINT "bible_plan_step_progress_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."bible_plan_step_progress"
    ADD CONSTRAINT "bible_plan_step_progress_user_id_day_id_step_key" UNIQUE ("user_id", "day_id", "step");



ALTER TABLE ONLY "public"."bible_plans"
    ADD CONSTRAINT "bible_plans_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."bible_plans"
    ADD CONSTRAINT "bible_plans_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "public"."chat_threads"
    ADD CONSTRAINT "chat_threads_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."child_pairing_tokens"
    ADD CONSTRAINT "child_pairing_tokens_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."child_pairing_tokens"
    ADD CONSTRAINT "child_pairing_tokens_token_key" UNIQUE ("token");



ALTER TABLE ONLY "public"."event_external_rsvps"
    ADD CONSTRAINT "event_external_rsvps_event_email_unique" UNIQUE ("event_id", "email");



ALTER TABLE ONLY "public"."event_external_rsvps"
    ADD CONSTRAINT "event_external_rsvps_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."event_media"
    ADD CONSTRAINT "event_media_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."event_rsvps"
    ADD CONSTRAINT "event_rsvps_event_id_user_id_key" UNIQUE ("event_id", "user_id");



ALTER TABLE ONLY "public"."event_rsvps"
    ADD CONSTRAINT "event_rsvps_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."families"
    ADD CONSTRAINT "families_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."family_invites"
    ADD CONSTRAINT "family_invites_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."family_members"
    ADD CONSTRAINT "family_members_family_id_user_id_key" UNIQUE ("family_id", "user_id");



ALTER TABLE ONLY "public"."family_members"
    ADD CONSTRAINT "family_members_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."feed_post_engagement"
    ADD CONSTRAINT "feed_post_engagement_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."feed_post_engagement"
    ADD CONSTRAINT "feed_post_engagement_post_id_user_id_key" UNIQUE ("post_id", "user_id");



ALTER TABLE ONLY "public"."feed_post_photos"
    ADD CONSTRAINT "feed_post_photos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."feed_post_photos"
    ADD CONSTRAINT "feed_post_photos_post_id_display_order_key" UNIQUE ("post_id", "display_order");



ALTER TABLE ONLY "public"."feed_posts"
    ADD CONSTRAINT "feed_posts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."instagram_scrape_jobs"
    ADD CONSTRAINT "instagram_scrape_jobs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."instagram_sources"
    ADD CONSTRAINT "instagram_sources_group_id_handle_key" UNIQUE ("group_id", "handle");



ALTER TABLE ONLY "public"."instagram_sources"
    ADD CONSTRAINT "instagram_sources_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."moderation_alerts"
    ADD CONSTRAINT "moderation_alerts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."moderation_flags"
    ADD CONSTRAINT "moderation_flags_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pastor_signup_drafts"
    ADD CONSTRAINT "pastor_signup_drafts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pastor_signup_drafts"
    ADD CONSTRAINT "pastor_signup_drafts_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."pastor_signup_promos"
    ADD CONSTRAINT "pastor_signup_promos_code_key" UNIQUE ("code");



ALTER TABLE ONLY "public"."pastor_signup_promos"
    ADD CONSTRAINT "pastor_signup_promos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE "public"."profiles"
    ADD CONSTRAINT "profiles_under_13_needs_parent" CHECK ((("date_of_birth" IS NULL) OR ("date_of_birth" <= (CURRENT_DATE - '13 years'::interval)) OR (("parent_account_id" IS NOT NULL) AND ("is_managed_child" = true)))) NOT VALID;



ALTER TABLE ONLY "public"."small_group_members"
    ADD CONSTRAINT "small_group_members_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."small_group_members"
    ADD CONSTRAINT "small_group_members_small_group_id_user_id_key" UNIQUE ("small_group_id", "user_id");



ALTER TABLE ONLY "public"."small_groups"
    ADD CONSTRAINT "small_groups_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."store_item_levels"
    ADD CONSTRAINT "store_item_levels_item_id_level_key" UNIQUE ("item_id", "level");



ALTER TABLE ONLY "public"."store_item_levels"
    ADD CONSTRAINT "store_item_levels_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."store_items"
    ADD CONSTRAINT "store_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."stripe_events"
    ADD CONSTRAINT "stripe_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."stripe_subscriptions"
    ADD CONSTRAINT "stripe_subscriptions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."stripe_subscriptions"
    ADD CONSTRAINT "stripe_subscriptions_stripe_subscription_id_key" UNIQUE ("stripe_subscription_id");



ALTER TABLE ONLY "public"."subscription_tiers"
    ADD CONSTRAINT "subscription_tiers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."thread_subscribers"
    ADD CONSTRAINT "thread_subscribers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."thread_subscribers"
    ADD CONSTRAINT "thread_subscribers_thread_id_user_id_key" UNIQUE ("thread_id", "user_id");



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_user_id_role_key" UNIQUE ("user_id", "role");



ALTER TABLE ONLY "public"."user_streak_milestone_grants"
    ADD CONSTRAINT "user_streak_milestone_grants_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_streak_milestone_grants"
    ADD CONSTRAINT "user_streak_milestone_grants_user_id_run_id_milestone_key" UNIQUE ("user_id", "run_id", "milestone");



ALTER TABLE ONLY "public"."user_xp_grants"
    ADD CONSTRAINT "user_xp_grants_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."videos"
    ADD CONSTRAINT "videos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."weekly_ranking_snapshots"
    ADD CONSTRAINT "weekly_ranking_snapshots_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."weekly_ranking_snapshots"
    ADD CONSTRAINT "weekly_ranking_snapshots_week_start_group_id_key" UNIQUE ("week_start", "group_id");



ALTER TABLE ONLY "public"."weekly_user_ranking_snapshots"
    ADD CONSTRAINT "weekly_user_ranking_snapshots_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."weekly_user_ranking_snapshots"
    ADD CONSTRAINT "weekly_user_ranking_snapshots_week_start_group_id_user_id_key" UNIQUE ("week_start", "group_id", "user_id");



ALTER TABLE ONLY "public"."youth_group_join_requests"
    ADD CONSTRAINT "youth_group_join_requests_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."youth_group_members"
    ADD CONSTRAINT "youth_group_members_group_id_user_id_key" UNIQUE ("group_id", "user_id");



ALTER TABLE ONLY "public"."youth_group_members"
    ADD CONSTRAINT "youth_group_members_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."youth_group_submissions"
    ADD CONSTRAINT "youth_group_submissions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."youth_groups"
    ADD CONSTRAINT "youth_groups_pkey" PRIMARY KEY ("id");



CREATE INDEX "ae_small_group_idx" ON "public"."attendance_events" USING "btree" ("small_group_id", "occurred_at" DESC);



CREATE INDEX "apple_subs_status_idx" ON "public"."apple_subscriptions" USING "btree" ("status");



CREATE INDEX "apple_subs_user_idx" ON "public"."apple_subscriptions" USING "btree" ("user_id");



CREATE INDEX "ar_event_idx" ON "public"."attendance_records" USING "btree" ("event_id");



CREATE INDEX "ar_user_idx" ON "public"."attendance_records" USING "btree" ("user_id");



CREATE INDEX "bible_plans_group_idx" ON "public"."bible_plans" USING "btree" ("group_id");



CREATE UNIQUE INDEX "bible_plans_one_free_entry" ON "public"."bible_plans" USING "btree" ("is_free_entry") WHERE ("is_free_entry" = true);



CREATE INDEX "bible_plans_recommended_idx" ON "public"."bible_plans" USING "btree" ("recommended_order") WHERE ("status" = 'published'::"public"."bible_plan_status");



CREATE INDEX "bible_plans_status_idx" ON "public"."bible_plans" USING "btree" ("status");



CREATE INDEX "bpc_user_idx" ON "public"."bible_plan_completions" USING "btree" ("user_id");



CREATE INDEX "bpd_plan_idx" ON "public"."bible_plan_days" USING "btree" ("plan_id");



CREATE INDEX "bpdp_plan_idx" ON "public"."bible_plan_day_progress" USING "btree" ("plan_id");



CREATE INDEX "bpdp_user_completed_idx" ON "public"."bible_plan_day_progress" USING "btree" ("user_id", "completed_at");



CREATE INDEX "bpdp_user_idx" ON "public"."bible_plan_day_progress" USING "btree" ("user_id");



CREATE INDEX "bpsp_day_idx" ON "public"."bible_plan_step_progress" USING "btree" ("day_id");



CREATE INDEX "bpsp_user_idx" ON "public"."bible_plan_step_progress" USING "btree" ("user_id");



CREATE INDEX "bpsp_user_recent_idx" ON "public"."bible_plan_step_progress" USING "btree" ("user_id", "completed_at" DESC);



CREATE UNIQUE INDEX "chat_threads_dm_unique" ON "public"."chat_threads" USING "btree" ("group_id", "kind", "dm_user_a", "dm_user_b") WHERE ("dm_user_a" IS NOT NULL);



CREATE INDEX "chat_threads_group_idx" ON "public"."chat_threads" USING "btree" ("group_id");



CREATE UNIQUE INDEX "chat_threads_one_main_per_group" ON "public"."chat_threads" USING "btree" ("group_id") WHERE ("kind" = 'group_main'::"public"."thread_kind");



CREATE UNIQUE INDEX "chat_threads_one_per_small_group" ON "public"."chat_threads" USING "btree" ("small_group_id") WHERE ("kind" = 'small_group'::"public"."thread_kind");



CREATE INDEX "child_pairing_tokens_numeric_active_idx" ON "public"."child_pairing_tokens" USING "btree" ("numeric_code") WHERE ("redeemed_at" IS NULL);



CREATE INDEX "child_pairing_tokens_token_active_idx" ON "public"."child_pairing_tokens" USING "btree" ("token") WHERE ("redeemed_at" IS NULL);



CREATE INDEX "event_external_rsvps_email_idx" ON "public"."event_external_rsvps" USING "btree" ("lower"("email")) WHERE ("converted_to_user_id" IS NULL);



CREATE INDEX "event_media_event_idx" ON "public"."event_media" USING "btree" ("event_id");



CREATE INDEX "event_media_kind_idx" ON "public"."event_media" USING "btree" ("kind");



CREATE INDEX "event_rsvps_event_id_idx" ON "public"."event_rsvps" USING "btree" ("event_id");



CREATE INDEX "events_group_id_idx" ON "public"."events" USING "btree" ("group_id");



CREATE INDEX "events_lat_lng_idx" ON "public"."events" USING "btree" ("latitude", "longitude") WHERE (("latitude" IS NOT NULL) AND ("longitude" IS NOT NULL));



CREATE INDEX "events_starts_at_idx" ON "public"."events" USING "btree" ("starts_at");



CREATE INDEX "family_invites_family_idx" ON "public"."family_invites" USING "btree" ("family_id", "status");



CREATE UNIQUE INDEX "family_invites_pending_code_uniq" ON "public"."family_invites" USING "btree" ("pairing_code") WHERE ("status" = 'pending'::"text");



CREATE INDEX "family_members_user_idx" ON "public"."family_members" USING "btree" ("user_id");



CREATE INDEX "feed_post_engagement_post_idx" ON "public"."feed_post_engagement" USING "btree" ("post_id");



CREATE INDEX "feed_post_engagement_user_idx" ON "public"."feed_post_engagement" USING "btree" ("user_id");



CREATE INDEX "feed_post_photos_post_idx" ON "public"."feed_post_photos" USING "btree" ("post_id");



CREATE INDEX "feed_posts_group_published_idx" ON "public"."feed_posts" USING "btree" ("group_id", "published_at" DESC NULLS LAST) WHERE ("status" = 'published'::"text");



CREATE INDEX "feed_posts_published_idx" ON "public"."feed_posts" USING "btree" ("published_at" DESC NULLS LAST) WHERE ("status" = 'published'::"text");



CREATE UNIQUE INDEX "feed_posts_source_post_unique_idx" ON "public"."feed_posts" USING "btree" ("source_handle", "source_post_id") WHERE (("source_post_id" IS NOT NULL) AND ("scope" = 'group'::"text"));



CREATE INDEX "instagram_scrape_jobs_run_idx" ON "public"."instagram_scrape_jobs" USING "btree" ("apify_run_id");



CREATE INDEX "instagram_scrape_jobs_started_idx" ON "public"."instagram_scrape_jobs" USING "btree" ("started_at" DESC);



CREATE INDEX "instagram_sources_active_idx" ON "public"."instagram_sources" USING "btree" ("group_id") WHERE ("is_active" = true);



CREATE INDEX "messages_thread_idx" ON "public"."messages" USING "btree" ("thread_id", "created_at" DESC);



CREATE INDEX "moderation_alerts_concern_category_idx" ON "public"."moderation_alerts" USING "btree" ("concern_category") WHERE ("concern_category" IS NOT NULL);



CREATE INDEX "moderation_alerts_group_idx" ON "public"."moderation_alerts" USING "btree" ("group_id", "created_at" DESC);



CREATE INDEX "moderation_flags_group_id_idx" ON "public"."moderation_flags" USING "btree" ("group_id");



CREATE INDEX "moderation_flags_status_idx" ON "public"."moderation_flags" USING "btree" ("status");



CREATE INDEX "pastor_signup_promos_code_lower_idx" ON "public"."pastor_signup_promos" USING "btree" ("lower"("code"));



CREATE UNIQUE INDEX "profiles_handle_lower_idx" ON "public"."profiles" USING "btree" ("lower"("handle"));



CREATE INDEX "profiles_last_opened_at_idx" ON "public"."profiles" USING "btree" ("last_opened_at");



CREATE INDEX "profiles_parent_account_idx" ON "public"."profiles" USING "btree" ("parent_account_id") WHERE ("parent_account_id" IS NOT NULL);



CREATE INDEX "psd_email_idx" ON "public"."pastor_signup_drafts" USING "btree" ("lower"("email"));



CREATE INDEX "psd_stage_idx" ON "public"."pastor_signup_drafts" USING "btree" ("stage");



CREATE INDEX "psd_user_idx" ON "public"."pastor_signup_drafts" USING "btree" ("user_id");



CREATE INDEX "sgm_sg_idx" ON "public"."small_group_members" USING "btree" ("small_group_id");



CREATE INDEX "sgm_user_idx" ON "public"."small_group_members" USING "btree" ("user_id");



CREATE INDEX "small_groups_yg_idx" ON "public"."small_groups" USING "btree" ("youth_group_id");



CREATE INDEX "ss_customer_idx" ON "public"."stripe_subscriptions" USING "btree" ("stripe_customer_id");



CREATE INDEX "ss_group_idx" ON "public"."stripe_subscriptions" USING "btree" ("group_id");



CREATE UNIQUE INDEX "ss_one_active_per_pastor" ON "public"."stripe_subscriptions" USING "btree" ("pastor_user_id") WHERE ("status" = ANY (ARRAY['trialing'::"public"."stripe_subscription_status", 'active'::"public"."stripe_subscription_status", 'past_due'::"public"."stripe_subscription_status"]));



CREATE INDEX "ss_status_idx" ON "public"."stripe_subscriptions" USING "btree" ("status");



CREATE INDEX "store_item_levels_item_id_idx" ON "public"."store_item_levels" USING "btree" ("item_id");



CREATE INDEX "thread_subscribers_user_idx" ON "public"."thread_subscribers" USING "btree" ("user_id");



CREATE INDEX "user_xp_grants_awarded_at_idx" ON "public"."user_xp_grants" USING "btree" ("awarded_at");



CREATE INDEX "user_xp_grants_user_awarded_idx" ON "public"."user_xp_grants" USING "btree" ("user_id", "awarded_at" DESC);



CREATE INDEX "usmg_user_idx" ON "public"."user_streak_milestone_grants" USING "btree" ("user_id");



CREATE INDEX "videos_group_id_idx" ON "public"."videos" USING "btree" ("group_id");



CREATE INDEX "videos_plan_day_id_idx" ON "public"."videos" USING "btree" ("plan_day_id") WHERE ("plan_day_id" IS NOT NULL);



CREATE INDEX "videos_status_idx" ON "public"."videos" USING "btree" ("status");



CREATE INDEX "weekly_ranking_snapshots_class_idx" ON "public"."weekly_ranking_snapshots" USING "btree" ("week_start", "class", "rank_in_class");



CREATE INDEX "weekly_ranking_snapshots_group_idx" ON "public"."weekly_ranking_snapshots" USING "btree" ("group_id", "week_start" DESC);



CREATE INDEX "weekly_user_ranking_snapshots_group_week_idx" ON "public"."weekly_user_ranking_snapshots" USING "btree" ("group_id", "week_start" DESC, "rank_in_group");



CREATE INDEX "ygjr_group_status_idx" ON "public"."youth_group_join_requests" USING "btree" ("group_id", "status");



CREATE UNIQUE INDEX "ygjr_one_pending_per_user_group" ON "public"."youth_group_join_requests" USING "btree" ("group_id", "user_id") WHERE ("status" = 'pending'::"public"."join_request_status");



CREATE INDEX "ygjr_user_idx" ON "public"."youth_group_join_requests" USING "btree" ("user_id");



CREATE INDEX "ygs_created_idx" ON "public"."youth_group_submissions" USING "btree" ("created_at" DESC);



CREATE INDEX "ygs_lead_stage_idx" ON "public"."youth_group_submissions" USING "btree" ("lead_stage");



CREATE INDEX "ygs_status_idx" ON "public"."youth_group_submissions" USING "btree" ("status");



CREATE INDEX "ygs_submitter_idx" ON "public"."youth_group_submissions" USING "btree" ("submitter_id");



CREATE INDEX "youth_group_members_group_id_idx" ON "public"."youth_group_members" USING "btree" ("group_id");



CREATE INDEX "youth_group_members_user_id_idx" ON "public"."youth_group_members" USING "btree" ("user_id");



CREATE INDEX "youth_groups_location_idx" ON "public"."youth_groups" USING "gist" ("location");



CREATE UNIQUE INDEX "youth_groups_one_default" ON "public"."youth_groups" USING "btree" ("is_default_ygteev") WHERE ("is_default_ygteev" = true);



CREATE OR REPLACE VIEW "public"."attendance_event_summary" AS
 SELECT "e"."id" AS "event_id",
    "e"."small_group_id",
    "sg"."name" AS "small_group_name",
    "sg"."youth_group_id",
    "e"."title",
    "e"."occurred_at",
    "e"."created_by",
    "count"("r".*) AS "roster_total",
    "count"("r".*) FILTER (WHERE ("r"."present" = true)) AS "present_count",
    "count"("r".*) FILTER (WHERE ("r"."present" = false)) AS "absent_count",
    "e"."created_at",
    "e"."updated_at"
   FROM (("public"."attendance_events" "e"
     LEFT JOIN "public"."attendance_records" "r" ON (("r"."event_id" = "e"."id")))
     LEFT JOIN "public"."small_groups" "sg" ON (("sg"."id" = "e"."small_group_id")))
  GROUP BY "e"."id", "sg"."name", "sg"."youth_group_id";



CREATE OR REPLACE TRIGGER "chat_on_sgm_delete" AFTER DELETE ON "public"."small_group_members" FOR EACH ROW EXECUTE FUNCTION "public"."tg_chat_on_small_group_member_delete"();



CREATE OR REPLACE TRIGGER "chat_on_sgm_insert" AFTER INSERT ON "public"."small_group_members" FOR EACH ROW EXECUTE FUNCTION "public"."tg_chat_on_small_group_member_insert"();



CREATE OR REPLACE TRIGGER "chat_on_ygm_delete" AFTER DELETE ON "public"."youth_group_members" FOR EACH ROW EXECUTE FUNCTION "public"."tg_chat_on_youth_group_member_delete"();



CREATE OR REPLACE TRIGGER "chat_on_ygm_insert" AFTER INSERT ON "public"."youth_group_members" FOR EACH ROW EXECUTE FUNCTION "public"."tg_chat_on_youth_group_member_insert"();



CREATE OR REPLACE TRIGGER "send_lead_email_on_insert" AFTER INSERT ON "public"."youth_group_submissions" FOR EACH ROW EXECUTE FUNCTION "public"."tg_send_lead_welcome_email"();



CREATE OR REPLACE TRIGGER "tg_kick_instagram_scrape_ins" AFTER INSERT ON "public"."instagram_sources" FOR EACH ROW EXECUTE FUNCTION "public"."tg_kick_instagram_scrape"();



CREATE OR REPLACE TRIGGER "tg_kick_instagram_scrape_upd" AFTER UPDATE ON "public"."instagram_sources" FOR EACH ROW EXECUTE FUNCTION "public"."tg_kick_instagram_scrape"();



CREATE OR REPLACE TRIGGER "tg_notify_pastor_on_join_request" AFTER INSERT ON "public"."youth_group_join_requests" FOR EACH ROW EXECUTE FUNCTION "public"."tg_notify_pastor_on_join_request"();



CREATE OR REPLACE TRIGGER "touch_apple_subscriptions" BEFORE UPDATE ON "public"."apple_subscriptions" FOR EACH ROW EXECUTE FUNCTION "public"."touch_updated_at"();



CREATE OR REPLACE TRIGGER "touch_attendance_events" BEFORE UPDATE ON "public"."attendance_events" FOR EACH ROW EXECUTE FUNCTION "public"."touch_updated_at"();



CREATE OR REPLACE TRIGGER "touch_attendance_records" BEFORE UPDATE ON "public"."attendance_records" FOR EACH ROW EXECUTE FUNCTION "public"."touch_updated_at"();



CREATE OR REPLACE TRIGGER "touch_bible_plan_days" BEFORE UPDATE ON "public"."bible_plan_days" FOR EACH ROW EXECUTE FUNCTION "public"."touch_updated_at"();



CREATE OR REPLACE TRIGGER "touch_bible_plans" BEFORE UPDATE ON "public"."bible_plans" FOR EACH ROW EXECUTE FUNCTION "public"."touch_updated_at"();



CREATE OR REPLACE TRIGGER "touch_event_external_rsvps" BEFORE UPDATE ON "public"."event_external_rsvps" FOR EACH ROW EXECUTE FUNCTION "public"."touch_updated_at"();



CREATE OR REPLACE TRIGGER "touch_profiles" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."touch_updated_at"();



CREATE OR REPLACE TRIGGER "touch_psd" BEFORE UPDATE ON "public"."pastor_signup_drafts" FOR EACH ROW EXECUTE FUNCTION "public"."touch_updated_at"();



CREATE OR REPLACE TRIGGER "touch_small_groups" BEFORE UPDATE ON "public"."small_groups" FOR EACH ROW EXECUTE FUNCTION "public"."touch_updated_at"();



CREATE OR REPLACE TRIGGER "touch_ss" BEFORE UPDATE ON "public"."stripe_subscriptions" FOR EACH ROW EXECUTE FUNCTION "public"."touch_updated_at"();



CREATE OR REPLACE TRIGGER "touch_subscription_tiers" BEFORE UPDATE ON "public"."subscription_tiers" FOR EACH ROW EXECUTE FUNCTION "public"."touch_updated_at"();



CREATE OR REPLACE TRIGGER "touch_youth_groups" BEFORE UPDATE ON "public"."youth_groups" FOR EACH ROW EXECUTE FUNCTION "public"."touch_updated_at"();



CREATE OR REPLACE TRIGGER "trg_attendance_events_default_creator" BEFORE INSERT ON "public"."attendance_events" FOR EACH ROW EXECUTE FUNCTION "public"."tg_attendance_events_default_creator"();



CREATE OR REPLACE TRIGGER "trg_bible_plan_days_recompute_rewards" AFTER INSERT OR DELETE OR UPDATE ON "public"."bible_plan_days" FOR EACH ROW EXECUTE FUNCTION "public"."tg_bible_plan_days_recompute_rewards"();



CREATE OR REPLACE TRIGGER "trg_bible_plan_days_touch" BEFORE UPDATE ON "public"."bible_plan_days" FOR EACH ROW EXECUTE FUNCTION "public"."tg_touch_updated_at"();



CREATE OR REPLACE TRIGGER "trg_bible_plans_recompute_rewards_on_days_total" AFTER UPDATE ON "public"."bible_plans" FOR EACH ROW EXECUTE FUNCTION "public"."tg_bible_plans_recompute_rewards_on_days_total"();



CREATE OR REPLACE TRIGGER "trg_bible_plans_set_published_at" BEFORE UPDATE ON "public"."bible_plans" FOR EACH ROW EXECUTE FUNCTION "public"."tg_bible_plans_set_published_at"();



CREATE OR REPLACE TRIGGER "trg_block_pastor_self_leave" BEFORE DELETE ON "public"."youth_group_members" FOR EACH ROW EXECUTE FUNCTION "public"."tg_block_pastor_self_leave"();



CREATE OR REPLACE TRIGGER "trg_family_members_subscribe_parents" AFTER INSERT ON "public"."family_members" FOR EACH ROW EXECUTE FUNCTION "public"."tg_family_members_subscribe_parents"();



CREATE OR REPLACE TRIGGER "trg_feed_post_engagement_recount" AFTER INSERT OR DELETE OR UPDATE ON "public"."feed_post_engagement" FOR EACH ROW EXECUTE FUNCTION "public"."tg_feed_post_engagement_recount"();



CREATE OR REPLACE TRIGGER "trg_feed_posts_touch" BEFORE UPDATE ON "public"."feed_posts" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_profiles_lock_handle" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."tg_profiles_lock_handle"();



ALTER TABLE ONLY "public"."apple_subscriptions"
    ADD CONSTRAINT "apple_subscriptions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."attendance_events"
    ADD CONSTRAINT "attendance_events_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."attendance_events"
    ADD CONSTRAINT "attendance_events_small_group_id_fkey" FOREIGN KEY ("small_group_id") REFERENCES "public"."small_groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."attendance_records"
    ADD CONSTRAINT "attendance_records_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."attendance_events"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."attendance_records"
    ADD CONSTRAINT "attendance_records_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bible_plan_completions"
    ADD CONSTRAINT "bible_plan_completions_plan_id_fkey" FOREIGN KEY ("plan_id") REFERENCES "public"."bible_plans"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bible_plan_completions"
    ADD CONSTRAINT "bible_plan_completions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bible_plan_day_progress"
    ADD CONSTRAINT "bible_plan_day_progress_day_id_fkey" FOREIGN KEY ("day_id") REFERENCES "public"."bible_plan_days"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bible_plan_day_progress"
    ADD CONSTRAINT "bible_plan_day_progress_plan_id_fkey" FOREIGN KEY ("plan_id") REFERENCES "public"."bible_plans"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bible_plan_day_progress"
    ADD CONSTRAINT "bible_plan_day_progress_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bible_plan_days"
    ADD CONSTRAINT "bible_plan_days_plan_id_fkey" FOREIGN KEY ("plan_id") REFERENCES "public"."bible_plans"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bible_plan_step_progress"
    ADD CONSTRAINT "bible_plan_step_progress_day_id_fkey" FOREIGN KEY ("day_id") REFERENCES "public"."bible_plan_days"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bible_plan_step_progress"
    ADD CONSTRAINT "bible_plan_step_progress_plan_id_fkey" FOREIGN KEY ("plan_id") REFERENCES "public"."bible_plans"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bible_plan_step_progress"
    ADD CONSTRAINT "bible_plan_step_progress_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bible_plans"
    ADD CONSTRAINT "bible_plans_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."bible_plans"
    ADD CONSTRAINT "bible_plans_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."youth_groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."chat_threads"
    ADD CONSTRAINT "chat_threads_dm_user_a_fkey" FOREIGN KEY ("dm_user_a") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."chat_threads"
    ADD CONSTRAINT "chat_threads_dm_user_b_fkey" FOREIGN KEY ("dm_user_b") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."chat_threads"
    ADD CONSTRAINT "chat_threads_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."youth_groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."chat_threads"
    ADD CONSTRAINT "chat_threads_small_group_id_fkey" FOREIGN KEY ("small_group_id") REFERENCES "public"."small_groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."child_pairing_tokens"
    ADD CONSTRAINT "child_pairing_tokens_child_user_id_fkey" FOREIGN KEY ("child_user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."child_pairing_tokens"
    ADD CONSTRAINT "child_pairing_tokens_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."event_external_rsvps"
    ADD CONSTRAINT "event_external_rsvps_converted_to_user_id_fkey" FOREIGN KEY ("converted_to_user_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."event_external_rsvps"
    ADD CONSTRAINT "event_external_rsvps_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."event_external_rsvps"
    ADD CONSTRAINT "event_external_rsvps_inviter_user_id_fkey" FOREIGN KEY ("inviter_user_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."event_media"
    ADD CONSTRAINT "event_media_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."event_media"
    ADD CONSTRAINT "event_media_uploaded_by_fkey" FOREIGN KEY ("uploaded_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."event_media"
    ADD CONSTRAINT "event_media_video_id_fkey" FOREIGN KEY ("video_id") REFERENCES "public"."videos"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."event_rsvps"
    ADD CONSTRAINT "event_rsvps_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."event_rsvps"
    ADD CONSTRAINT "event_rsvps_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."event_rsvps"
    ADD CONSTRAINT "event_rsvps_user_profiles_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "events_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "events_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."youth_groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."families"
    ADD CONSTRAINT "families_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."family_invites"
    ADD CONSTRAINT "family_invites_accepted_by_fkey" FOREIGN KEY ("accepted_by") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."family_invites"
    ADD CONSTRAINT "family_invites_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."family_invites"
    ADD CONSTRAINT "family_invites_family_id_fkey" FOREIGN KEY ("family_id") REFERENCES "public"."families"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."family_invites"
    ADD CONSTRAINT "family_invites_invited_user_id_fkey" FOREIGN KEY ("invited_user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."family_members"
    ADD CONSTRAINT "family_members_family_id_fkey" FOREIGN KEY ("family_id") REFERENCES "public"."families"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."family_members"
    ADD CONSTRAINT "family_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."feed_post_engagement"
    ADD CONSTRAINT "feed_post_engagement_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "public"."feed_posts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."feed_post_engagement"
    ADD CONSTRAINT "feed_post_engagement_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."feed_post_photos"
    ADD CONSTRAINT "feed_post_photos_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "public"."feed_posts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."feed_posts"
    ADD CONSTRAINT "feed_posts_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."feed_posts"
    ADD CONSTRAINT "feed_posts_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."youth_groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."feed_posts"
    ADD CONSTRAINT "feed_posts_video_id_fkey" FOREIGN KEY ("video_id") REFERENCES "public"."videos"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."instagram_scrape_jobs"
    ADD CONSTRAINT "instagram_scrape_jobs_source_id_fkey" FOREIGN KEY ("source_id") REFERENCES "public"."instagram_sources"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."instagram_sources"
    ADD CONSTRAINT "instagram_sources_added_by_fkey" FOREIGN KEY ("added_by") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."instagram_sources"
    ADD CONSTRAINT "instagram_sources_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."youth_groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_sender_id_profiles_fkey" FOREIGN KEY ("sender_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_thread_id_fkey" FOREIGN KEY ("thread_id") REFERENCES "public"."chat_threads"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."moderation_alerts"
    ADD CONSTRAINT "moderation_alerts_ack_profiles_fkey" FOREIGN KEY ("acknowledged_by") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."moderation_alerts"
    ADD CONSTRAINT "moderation_alerts_acknowledged_by_fkey" FOREIGN KEY ("acknowledged_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."moderation_alerts"
    ADD CONSTRAINT "moderation_alerts_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."youth_groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."moderation_alerts"
    ADD CONSTRAINT "moderation_alerts_message_id_fkey" FOREIGN KEY ("message_id") REFERENCES "public"."messages"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."moderation_alerts"
    ADD CONSTRAINT "moderation_alerts_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."moderation_alerts"
    ADD CONSTRAINT "moderation_alerts_sender_profiles_fkey" FOREIGN KEY ("sender_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."moderation_alerts"
    ADD CONSTRAINT "moderation_alerts_thread_id_fkey" FOREIGN KEY ("thread_id") REFERENCES "public"."chat_threads"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."moderation_flags"
    ADD CONSTRAINT "moderation_flags_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."youth_groups"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."moderation_flags"
    ADD CONSTRAINT "moderation_flags_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."pastor_signup_drafts"
    ADD CONSTRAINT "pastor_signup_drafts_finalized_youth_group_id_fkey" FOREIGN KEY ("finalized_youth_group_id") REFERENCES "public"."youth_groups"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."pastor_signup_drafts"
    ADD CONSTRAINT "pastor_signup_drafts_tier_id_fkey" FOREIGN KEY ("tier_id") REFERENCES "public"."subscription_tiers"("id");



ALTER TABLE ONLY "public"."pastor_signup_drafts"
    ADD CONSTRAINT "pastor_signup_drafts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_parent_account_id_fkey" FOREIGN KEY ("parent_account_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."small_group_members"
    ADD CONSTRAINT "small_group_members_small_group_id_fkey" FOREIGN KEY ("small_group_id") REFERENCES "public"."small_groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."small_group_members"
    ADD CONSTRAINT "small_group_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."small_group_members"
    ADD CONSTRAINT "small_group_members_user_profiles_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."small_groups"
    ADD CONSTRAINT "small_groups_youth_group_id_fkey" FOREIGN KEY ("youth_group_id") REFERENCES "public"."youth_groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."store_item_levels"
    ADD CONSTRAINT "store_item_levels_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "public"."store_items"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stripe_subscriptions"
    ADD CONSTRAINT "stripe_subscriptions_draft_id_fkey" FOREIGN KEY ("draft_id") REFERENCES "public"."pastor_signup_drafts"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."stripe_subscriptions"
    ADD CONSTRAINT "stripe_subscriptions_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."youth_groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stripe_subscriptions"
    ADD CONSTRAINT "stripe_subscriptions_pastor_user_id_fkey" FOREIGN KEY ("pastor_user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."stripe_subscriptions"
    ADD CONSTRAINT "stripe_subscriptions_pending_tier_id_fkey" FOREIGN KEY ("pending_tier_id") REFERENCES "public"."subscription_tiers"("id");



ALTER TABLE ONLY "public"."stripe_subscriptions"
    ADD CONSTRAINT "stripe_subscriptions_tier_id_fkey" FOREIGN KEY ("tier_id") REFERENCES "public"."subscription_tiers"("id");



ALTER TABLE ONLY "public"."thread_subscribers"
    ADD CONSTRAINT "thread_subscribers_thread_id_fkey" FOREIGN KEY ("thread_id") REFERENCES "public"."chat_threads"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."thread_subscribers"
    ADD CONSTRAINT "thread_subscribers_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_streak_milestone_grants"
    ADD CONSTRAINT "user_streak_milestone_grants_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_xp_grants"
    ADD CONSTRAINT "user_xp_grants_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."videos"
    ADD CONSTRAINT "videos_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."videos"
    ADD CONSTRAINT "videos_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."youth_groups"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."videos"
    ADD CONSTRAINT "videos_plan_day_id_fkey" FOREIGN KEY ("plan_day_id") REFERENCES "public"."bible_plan_days"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."weekly_ranking_snapshots"
    ADD CONSTRAINT "weekly_ranking_snapshots_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."youth_groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."weekly_user_ranking_snapshots"
    ADD CONSTRAINT "weekly_user_ranking_snapshots_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."youth_groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."weekly_user_ranking_snapshots"
    ADD CONSTRAINT "weekly_user_ranking_snapshots_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."youth_group_join_requests"
    ADD CONSTRAINT "youth_group_join_requests_decided_by_fkey" FOREIGN KEY ("decided_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."youth_group_join_requests"
    ADD CONSTRAINT "youth_group_join_requests_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."youth_groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."youth_group_join_requests"
    ADD CONSTRAINT "youth_group_join_requests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."youth_group_members"
    ADD CONSTRAINT "youth_group_members_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."youth_groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."youth_group_members"
    ADD CONSTRAINT "youth_group_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."youth_group_submissions"
    ADD CONSTRAINT "youth_group_submissions_decided_by_fkey" FOREIGN KEY ("decided_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."youth_group_submissions"
    ADD CONSTRAINT "youth_group_submissions_submitter_id_fkey" FOREIGN KEY ("submitter_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."youth_groups"
    ADD CONSTRAINT "youth_groups_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE "public"."_internal_secrets" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "ae: read" ON "public"."attendance_events" FOR SELECT USING (("public"."is_site_admin"("auth"."uid"()) OR "public"."can_take_attendance"("auth"."uid"(), "small_group_id") OR "public"."is_in_small_group"("auth"."uid"(), "small_group_id")));



CREATE POLICY "ae: write" ON "public"."attendance_events" USING ("public"."can_take_attendance"("auth"."uid"(), "small_group_id")) WITH CHECK ("public"."can_take_attendance"("auth"."uid"(), "small_group_id"));



CREATE POLICY "alerts: pastor/admin read" ON "public"."moderation_alerts" FOR SELECT USING (("public"."is_site_admin"("auth"."uid"()) OR "public"."is_group_pastor"("auth"."uid"(), "group_id")));



CREATE POLICY "alerts: pastor/admin update" ON "public"."moderation_alerts" FOR UPDATE USING (("public"."is_site_admin"("auth"."uid"()) OR "public"."is_group_pastor"("auth"."uid"(), "group_id"))) WITH CHECK (("public"."is_site_admin"("auth"."uid"()) OR "public"."is_group_pastor"("auth"."uid"(), "group_id")));



CREATE POLICY "apple_subs: admin read" ON "public"."apple_subscriptions" FOR SELECT USING ("public"."is_site_admin"("auth"."uid"()));



ALTER TABLE "public"."apple_subscriptions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "ar: read" ON "public"."attendance_records" FOR SELECT USING (("public"."is_site_admin"("auth"."uid"()) OR ("user_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."attendance_events" "e"
  WHERE (("e"."id" = "attendance_records"."event_id") AND "public"."can_take_attendance"("auth"."uid"(), "e"."small_group_id"))))));



CREATE POLICY "ar: write" ON "public"."attendance_records" USING ((EXISTS ( SELECT 1
   FROM "public"."attendance_events" "e"
  WHERE (("e"."id" = "attendance_records"."event_id") AND "public"."can_take_attendance"("auth"."uid"(), "e"."small_group_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."attendance_events" "e"
  WHERE (("e"."id" = "attendance_records"."event_id") AND "public"."can_take_attendance"("auth"."uid"(), "e"."small_group_id")))));



ALTER TABLE "public"."attendance_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."attendance_records" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."bible_plan_completions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."bible_plan_day_progress" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."bible_plan_days" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."bible_plan_step_progress" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."bible_plans" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "bp: admin/pastor" ON "public"."bible_plans" USING (("public"."is_site_admin"("auth"."uid"()) OR (("scope" = 'group'::"public"."bible_plan_scope") AND "public"."is_group_pastor"("auth"."uid"(), "group_id")))) WITH CHECK (("public"."is_site_admin"("auth"."uid"()) OR (("scope" = 'group'::"public"."bible_plan_scope") AND "public"."is_group_pastor"("auth"."uid"(), "group_id"))));



CREATE POLICY "bp: read" ON "public"."bible_plans" FOR SELECT USING (("public"."is_site_admin"("auth"."uid"()) OR (("scope" = 'group'::"public"."bible_plan_scope") AND "public"."is_group_pastor"("auth"."uid"(), "group_id")) OR (("status" = 'published'::"public"."bible_plan_status") AND (("scope" = 'global'::"public"."bible_plan_scope") OR ("visibility" = 'public'::"public"."bible_plan_visibility") OR (("scope" = 'group'::"public"."bible_plan_scope") AND (EXISTS ( SELECT 1
   FROM "public"."youth_group_members" "ygm"
  WHERE (("ygm"."group_id" = "bible_plans"."group_id") AND ("ygm"."user_id" = "auth"."uid"())))))))));



CREATE POLICY "bpc: self read" ON "public"."bible_plan_completions" FOR SELECT USING ((("user_id" = "auth"."uid"()) OR "public"."is_site_admin"("auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."bible_plans" "p"
  WHERE (("p"."id" = "bible_plan_completions"."plan_id") AND "public"."is_group_pastor"("auth"."uid"(), "p"."group_id"))))));



CREATE POLICY "bpd: admin/pastor" ON "public"."bible_plan_days" USING (("public"."is_site_admin"("auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."bible_plans" "p"
  WHERE (("p"."id" = "bible_plan_days"."plan_id") AND ("p"."scope" = 'group'::"public"."bible_plan_scope") AND "public"."is_group_pastor"("auth"."uid"(), "p"."group_id")))))) WITH CHECK (("public"."is_site_admin"("auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."bible_plans" "p"
  WHERE (("p"."id" = "bible_plan_days"."plan_id") AND ("p"."scope" = 'group'::"public"."bible_plan_scope") AND "public"."is_group_pastor"("auth"."uid"(), "p"."group_id"))))));



CREATE POLICY "bpd: read" ON "public"."bible_plan_days" FOR SELECT USING (("public"."is_site_admin"("auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."bible_plans" "p"
  WHERE (("p"."id" = "bible_plan_days"."plan_id") AND ((("p"."scope" = 'group'::"public"."bible_plan_scope") AND "public"."is_group_pastor"("auth"."uid"(), "p"."group_id")) OR (("p"."status" = 'published'::"public"."bible_plan_status") AND (("p"."scope" = 'global'::"public"."bible_plan_scope") OR ("p"."visibility" = 'public'::"public"."bible_plan_visibility") OR (("p"."scope" = 'group'::"public"."bible_plan_scope") AND (EXISTS ( SELECT 1
           FROM "public"."youth_group_members" "ygm"
          WHERE (("ygm"."group_id" = "p"."group_id") AND ("ygm"."user_id" = "auth"."uid"())))))))))))));



CREATE POLICY "bpdp: no client insert" ON "public"."bible_plan_day_progress" FOR INSERT WITH CHECK (false);



CREATE POLICY "bpdp: self read" ON "public"."bible_plan_day_progress" FOR SELECT USING ((("user_id" = "auth"."uid"()) OR "public"."is_site_admin"("auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."bible_plans" "p"
  WHERE (("p"."id" = "bible_plan_day_progress"."plan_id") AND "public"."is_group_pastor"("auth"."uid"(), "p"."group_id"))))));



CREATE POLICY "bpsp: no client insert" ON "public"."bible_plan_step_progress" FOR INSERT WITH CHECK (false);



CREATE POLICY "bpsp: read" ON "public"."bible_plan_step_progress" FOR SELECT USING ((("user_id" = "auth"."uid"()) OR "public"."is_site_admin"("auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."bible_plans" "p"
  WHERE (("p"."id" = "bible_plan_step_progress"."plan_id") AND "public"."is_group_pastor"("auth"."uid"(), "p"."group_id"))))));



ALTER TABLE "public"."chat_threads" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."child_pairing_tokens" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "child_pairing_tokens: creator read" ON "public"."child_pairing_tokens" FOR SELECT USING (("created_by" = "auth"."uid"()));



ALTER TABLE "public"."event_external_rsvps" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."event_media" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "event_media: members read" ON "public"."event_media" FOR SELECT USING (("public"."is_site_admin"("auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."events" "e"
  WHERE (("e"."id" = "event_media"."event_id") AND "public"."is_group_member"("auth"."uid"(), "e"."group_id"))))));



CREATE POLICY "event_media: pastor/admin manage" ON "public"."event_media" USING (("public"."is_site_admin"("auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."events" "e"
  WHERE (("e"."id" = "event_media"."event_id") AND "public"."is_group_pastor"("auth"."uid"(), "e"."group_id")))))) WITH CHECK (("public"."is_site_admin"("auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."events" "e"
  WHERE (("e"."id" = "event_media"."event_id") AND "public"."is_group_pastor"("auth"."uid"(), "e"."group_id"))))));



ALTER TABLE "public"."event_rsvps" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."events" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "events: pastor write" ON "public"."events" USING (("public"."is_group_pastor"("auth"."uid"(), "group_id") OR "public"."is_site_admin"("auth"."uid"()))) WITH CHECK (("public"."is_group_pastor"("auth"."uid"(), "group_id") OR "public"."is_site_admin"("auth"."uid"())));



CREATE POLICY "events: visibility read" ON "public"."events" FOR SELECT USING ((("visibility" = 'public'::"public"."event_visibility") OR "public"."is_group_member"("auth"."uid"(), "group_id") OR "public"."is_site_admin"("auth"."uid"())));



ALTER TABLE "public"."families" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "families: members read" ON "public"."families" FOR SELECT USING (("public"."is_site_admin"("auth"."uid"()) OR "public"."is_in_family"("id")));



CREATE POLICY "families: parent update" ON "public"."families" FOR UPDATE USING (("public"."is_site_admin"("auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."family_members"
  WHERE (("family_members"."family_id" = "families"."id") AND ("family_members"."user_id" = "auth"."uid"()) AND ("family_members"."role" = 'parent'::"text"))))));



ALTER TABLE "public"."family_invites" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "family_invites: family read" ON "public"."family_invites" FOR SELECT USING (("public"."is_site_admin"("auth"."uid"()) OR "public"."is_in_family"("family_id") OR ("invited_user_id" = "auth"."uid"())));



ALTER TABLE "public"."family_members" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "family_members: in-family read" ON "public"."family_members" FOR SELECT USING (("public"."is_site_admin"("auth"."uid"()) OR "public"."is_in_family"("family_id")));



ALTER TABLE "public"."feed_post_engagement" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "feed_post_engagement: self read" ON "public"."feed_post_engagement" FOR SELECT USING ((("user_id" = "auth"."uid"()) OR "public"."is_site_admin"("auth"."uid"())));



CREATE POLICY "feed_post_engagement: self update" ON "public"."feed_post_engagement" FOR UPDATE USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "feed_post_engagement: self write" ON "public"."feed_post_engagement" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."feed_post_photos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "feed_post_photos: pastor manage" ON "public"."feed_post_photos" USING ((EXISTS ( SELECT 1
   FROM "public"."feed_posts" "fp"
  WHERE (("fp"."id" = "feed_post_photos"."post_id") AND ("public"."is_site_admin"("auth"."uid"()) OR (("fp"."scope" = 'group'::"text") AND "public"."is_group_pastor"("auth"."uid"(), "fp"."group_id"))))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."feed_posts" "fp"
  WHERE (("fp"."id" = "feed_post_photos"."post_id") AND ("public"."is_site_admin"("auth"."uid"()) OR (("fp"."scope" = 'group'::"text") AND "public"."is_group_pastor"("auth"."uid"(), "fp"."group_id")))))));



CREATE POLICY "feed_post_photos: read" ON "public"."feed_post_photos" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."feed_posts" "fp"
  WHERE (("fp"."id" = "feed_post_photos"."post_id") AND ("public"."is_site_admin"("auth"."uid"()) OR (("fp"."status" = 'published'::"text") AND (("fp"."scope" = 'ygteev_official'::"text") OR (("fp"."scope" = 'group'::"text") AND (EXISTS ( SELECT 1
           FROM "public"."youth_group_members"
          WHERE (("youth_group_members"."group_id" = "fp"."group_id") AND ("youth_group_members"."user_id" = "auth"."uid"()))))))) OR (("fp"."scope" = 'group'::"text") AND "public"."is_group_pastor"("auth"."uid"(), "fp"."group_id")))))));



ALTER TABLE "public"."feed_posts" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "feed_posts: pastor manage" ON "public"."feed_posts" USING (("public"."is_site_admin"("auth"."uid"()) OR (("scope" = 'group'::"text") AND "public"."is_group_pastor"("auth"."uid"(), "group_id")))) WITH CHECK (("public"."is_site_admin"("auth"."uid"()) OR (("scope" = 'group'::"text") AND "public"."is_group_pastor"("auth"."uid"(), "group_id"))));



CREATE POLICY "feed_posts: read" ON "public"."feed_posts" FOR SELECT USING (("public"."is_site_admin"("auth"."uid"()) OR (("status" = 'published'::"text") AND (("scope" = 'ygteev_official'::"text") OR (("scope" = 'group'::"text") AND (EXISTS ( SELECT 1
   FROM "public"."youth_group_members" "ygm"
  WHERE (("ygm"."group_id" = "feed_posts"."group_id") AND ("ygm"."user_id" = "auth"."uid"()))))))) OR (("scope" = 'group'::"text") AND "public"."is_group_pastor"("auth"."uid"(), "group_id"))));



CREATE POLICY "flags: pastor read" ON "public"."moderation_flags" FOR SELECT USING (("public"."is_site_admin"("auth"."uid"()) OR (("group_id" IS NOT NULL) AND "public"."is_group_pastor"("auth"."uid"(), "group_id"))));



CREATE POLICY "flags: pastor write" ON "public"."moderation_flags" USING (("public"."is_site_admin"("auth"."uid"()) OR (("group_id" IS NOT NULL) AND "public"."is_group_pastor"("auth"."uid"(), "group_id")))) WITH CHECK (("public"."is_site_admin"("auth"."uid"()) OR (("group_id" IS NOT NULL) AND "public"."is_group_pastor"("auth"."uid"(), "group_id"))));



CREATE POLICY "ig_jobs: pastor/admin read" ON "public"."instagram_scrape_jobs" FOR SELECT USING (("public"."is_site_admin"("auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."instagram_sources" "s"
  WHERE (("s"."id" = "instagram_scrape_jobs"."source_id") AND "public"."is_group_pastor"("auth"."uid"(), "s"."group_id"))))));



CREATE POLICY "ig_sources: pastor manage" ON "public"."instagram_sources" USING (("public"."is_site_admin"("auth"."uid"()) OR "public"."is_group_pastor"("auth"."uid"(), "group_id"))) WITH CHECK (("public"."is_site_admin"("auth"."uid"()) OR "public"."is_group_pastor"("auth"."uid"(), "group_id")));



ALTER TABLE "public"."instagram_scrape_jobs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."instagram_sources" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "items: admin write" ON "public"."store_items" USING ("public"."is_site_admin"("auth"."uid"())) WITH CHECK ("public"."is_site_admin"("auth"."uid"()));



CREATE POLICY "items: public read" ON "public"."store_items" FOR SELECT USING (("active" OR "public"."is_site_admin"("auth"."uid"())));



CREATE POLICY "levels: admin write" ON "public"."store_item_levels" USING ("public"."is_site_admin"("auth"."uid"())) WITH CHECK ("public"."is_site_admin"("auth"."uid"()));



CREATE POLICY "levels: public read" ON "public"."store_item_levels" FOR SELECT USING (true);



ALTER TABLE "public"."messages" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "messages: client insert blocked" ON "public"."messages" FOR INSERT WITH CHECK (false);



CREATE POLICY "messages: subscriber read" ON "public"."messages" FOR SELECT USING (("public"."is_site_admin"("auth"."uid"()) OR "public"."is_thread_subscriber"("thread_id", "auth"."uid"()) OR "public"."is_group_pastor"("auth"."uid"(), "public"."thread_group_id"("thread_id"))));



ALTER TABLE "public"."moderation_alerts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."moderation_flags" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pastor_signup_drafts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pastor_signup_promos" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "profiles: chat co-subscriber read" ON "public"."profiles" FOR SELECT USING ("public"."share_chat_thread"("id"));



CREATE POLICY "profiles: manager read" ON "public"."profiles" FOR SELECT USING ("public"."can_manage_user_profile"("auth"."uid"(), "id"));



CREATE POLICY "profiles: parent of child read" ON "public"."profiles" FOR SELECT USING (("parent_account_id" = "auth"."uid"()));



CREATE POLICY "profiles: parent of child update" ON "public"."profiles" FOR UPDATE USING (("parent_account_id" = "auth"."uid"())) WITH CHECK (("parent_account_id" = "auth"."uid"()));



CREATE POLICY "profiles: self insert" ON "public"."profiles" FOR INSERT WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "profiles: self read" ON "public"."profiles" FOR SELECT USING ((("auth"."uid"() = "id") OR "public"."is_site_admin"("auth"."uid"())));



CREATE POLICY "profiles: self update" ON "public"."profiles" FOR UPDATE USING (("auth"."uid"() = "id"));



CREATE POLICY "promos: admin manage" ON "public"."pastor_signup_promos" USING ("public"."is_site_admin"("auth"."uid"())) WITH CHECK ("public"."is_site_admin"("auth"."uid"()));



CREATE POLICY "psd: self read" ON "public"."pastor_signup_drafts" FOR SELECT USING ((("user_id" = "auth"."uid"()) OR "public"."is_site_admin"("auth"."uid"())));



CREATE POLICY "psd: self upsert" ON "public"."pastor_signup_drafts" USING ((("user_id" = "auth"."uid"()) OR "public"."is_site_admin"("auth"."uid"()))) WITH CHECK ((("user_id" = "auth"."uid"()) OR "public"."is_site_admin"("auth"."uid"())));



CREATE POLICY "rsvps: read" ON "public"."event_rsvps" FOR SELECT USING ((("user_id" = "auth"."uid"()) OR "public"."is_site_admin"("auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."events" "e"
  WHERE (("e"."id" = "event_rsvps"."event_id") AND "public"."is_group_member"("auth"."uid"(), "e"."group_id"))))));



CREATE POLICY "rsvps: self delete" ON "public"."event_rsvps" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "rsvps: self insert" ON "public"."event_rsvps" FOR INSERT WITH CHECK ((("user_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1
   FROM "public"."events" "e"
  WHERE (("e"."id" = "event_rsvps"."event_id") AND ("public"."is_group_member"("auth"."uid"(), "e"."group_id") OR (("e"."rsvp_audience" = 'public'::"public"."event_rsvp_audience") AND ("e"."visibility" = 'public'::"public"."event_visibility"))))))));



CREATE POLICY "rsvps: self update" ON "public"."event_rsvps" FOR UPDATE USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "sgm: members read" ON "public"."small_group_members" FOR SELECT USING (("public"."is_site_admin"("auth"."uid"()) OR ("user_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."small_groups" "sg"
  WHERE (("sg"."id" = "small_group_members"."small_group_id") AND "public"."is_group_pastor"("auth"."uid"(), "sg"."youth_group_id")))) OR "public"."is_small_group_leader"("auth"."uid"(), "small_group_id")));



CREATE POLICY "sgm: pastor manage" ON "public"."small_group_members" USING ("public"."can_manage_small_groups"("auth"."uid"(), "small_group_id")) WITH CHECK ("public"."can_manage_small_groups"("auth"."uid"(), "small_group_id"));



ALTER TABLE "public"."small_group_members" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."small_groups" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "small_groups: leader update" ON "public"."small_groups" FOR UPDATE USING ("public"."is_small_group_leader"("auth"."uid"(), "id")) WITH CHECK ("public"."is_small_group_leader"("auth"."uid"(), "id"));



CREATE POLICY "small_groups: members read" ON "public"."small_groups" FOR SELECT USING (("public"."is_site_admin"("auth"."uid"()) OR "public"."is_group_member"("auth"."uid"(), "youth_group_id")));



CREATE POLICY "small_groups: pastor manage" ON "public"."small_groups" USING (("public"."is_site_admin"("auth"."uid"()) OR "public"."is_group_pastor"("auth"."uid"(), "youth_group_id"))) WITH CHECK (("public"."is_site_admin"("auth"."uid"()) OR "public"."is_group_pastor"("auth"."uid"(), "youth_group_id")));



CREATE POLICY "ss: no client write" ON "public"."stripe_subscriptions" FOR INSERT WITH CHECK (false);



CREATE POLICY "ss: pastor read" ON "public"."stripe_subscriptions" FOR SELECT USING ((("pastor_user_id" = "auth"."uid"()) OR "public"."is_site_admin"("auth"."uid"()) OR (("group_id" IS NOT NULL) AND "public"."is_group_pastor"("auth"."uid"(), "group_id"))));



ALTER TABLE "public"."store_item_levels" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."store_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."stripe_subscriptions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "subs: read" ON "public"."thread_subscribers" FOR SELECT USING ((("user_id" = "auth"."uid"()) OR "public"."is_site_admin"("auth"."uid"()) OR "public"."is_group_pastor"("auth"."uid"(), "public"."thread_group_id"("thread_id"))));



CREATE POLICY "subs: self mark read" ON "public"."thread_subscribers" FOR UPDATE USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."subscription_tiers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."thread_subscribers" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "threads: subscriber read" ON "public"."chat_threads" FOR SELECT USING (("public"."is_site_admin"("auth"."uid"()) OR "public"."is_group_pastor"("auth"."uid"(), "group_id") OR "public"."is_thread_subscriber"("id", "auth"."uid"())));



CREATE POLICY "tiers: admin write" ON "public"."subscription_tiers" USING ("public"."is_site_admin"("auth"."uid"())) WITH CHECK ("public"."is_site_admin"("auth"."uid"()));



CREATE POLICY "tiers: public read" ON "public"."subscription_tiers" FOR SELECT USING (("active" = true));



ALTER TABLE "public"."user_roles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "user_roles: admin write" ON "public"."user_roles" USING ("public"."is_site_admin"("auth"."uid"())) WITH CHECK ("public"."is_site_admin"("auth"."uid"()));



CREATE POLICY "user_roles: self read" ON "public"."user_roles" FOR SELECT USING ((("user_id" = "auth"."uid"()) OR "public"."is_site_admin"("auth"."uid"())));



ALTER TABLE "public"."user_streak_milestone_grants" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_xp_grants" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "usmg: self read" ON "public"."user_streak_milestone_grants" FOR SELECT USING ((("user_id" = "auth"."uid"()) OR "public"."is_site_admin"("auth"."uid"())));



ALTER TABLE "public"."videos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "videos: admin write" ON "public"."videos" USING ("public"."is_site_admin"("auth"."uid"())) WITH CHECK ("public"."is_site_admin"("auth"."uid"()));



CREATE POLICY "videos: visibility read" ON "public"."videos" FOR SELECT USING (("public"."is_site_admin"("auth"."uid"()) OR (("status" = 'ready'::"public"."video_status") AND (("scope" = 'global'::"public"."video_scope") OR (("scope" = 'youthGroup'::"public"."video_scope") AND ("group_id" IS NOT NULL) AND "public"."is_group_member"("auth"."uid"(), "group_id")))) OR (("scope" = 'youthGroup'::"public"."video_scope") AND ("group_id" IS NOT NULL) AND "public"."is_group_pastor"("auth"."uid"(), "group_id")) OR (("scope" = 'plan'::"public"."video_scope") AND (EXISTS ( SELECT 1
   FROM ("public"."bible_plan_days" "d"
     JOIN "public"."bible_plans" "p" ON (("p"."id" = "d"."plan_id")))
  WHERE (("d"."id" = "videos"."plan_day_id") AND ("public"."_pastor_can_edit_plan"("p"."id") OR (("videos"."status" = 'ready'::"public"."video_status") AND "public"."can_user_start_plan"("auth"."uid"(), "p"."id")))))))));



ALTER TABLE "public"."weekly_ranking_snapshots" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."weekly_user_ranking_snapshots" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "xp_grants: self read" ON "public"."user_xp_grants" FOR SELECT USING ((("user_id" = "auth"."uid"()) OR "public"."is_site_admin"("auth"."uid"())));



CREATE POLICY "ygjr: pastor/admin update" ON "public"."youth_group_join_requests" FOR UPDATE USING (("public"."is_site_admin"("auth"."uid"()) OR "public"."is_group_pastor"("auth"."uid"(), "group_id"))) WITH CHECK (("public"."is_site_admin"("auth"."uid"()) OR "public"."is_group_pastor"("auth"."uid"(), "group_id")));



CREATE POLICY "ygjr: read" ON "public"."youth_group_join_requests" FOR SELECT USING ((("user_id" = "auth"."uid"()) OR "public"."is_site_admin"("auth"."uid"()) OR "public"."is_group_pastor"("auth"."uid"(), "group_id")));



CREATE POLICY "ygjr: self cancel" ON "public"."youth_group_join_requests" FOR UPDATE USING ((("user_id" = "auth"."uid"()) AND ("status" = 'pending'::"public"."join_request_status"))) WITH CHECK ((("user_id" = "auth"."uid"()) AND ("status" = 'cancelled'::"public"."join_request_status")));



CREATE POLICY "ygjr: self insert" ON "public"."youth_group_join_requests" FOR INSERT WITH CHECK ((("user_id" = "auth"."uid"()) AND ("status" = 'pending'::"public"."join_request_status")));



CREATE POLICY "ygm: members read roster" ON "public"."youth_group_members" FOR SELECT USING (("public"."is_group_member"("auth"."uid"(), "group_id") OR "public"."is_site_admin"("auth"."uid"())));



CREATE POLICY "ygm: pastor manages" ON "public"."youth_group_members" USING (("public"."is_group_pastor"("auth"."uid"(), "group_id") OR "public"."is_site_admin"("auth"."uid"()))) WITH CHECK (("public"."is_group_pastor"("auth"."uid"(), "group_id") OR "public"."is_site_admin"("auth"."uid"())));



CREATE POLICY "ygm: self join" ON "public"."youth_group_members" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "ygm: self leave" ON "public"."youth_group_members" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "ygs: admin update" ON "public"."youth_group_submissions" FOR UPDATE USING ("public"."is_site_admin"("auth"."uid"())) WITH CHECK ("public"."is_site_admin"("auth"."uid"()));



CREATE POLICY "ygs: no client insert" ON "public"."youth_group_submissions" FOR INSERT WITH CHECK (false);



CREATE POLICY "ygs: read" ON "public"."youth_group_submissions" FOR SELECT USING (("public"."is_site_admin"("auth"."uid"()) OR ("submitter_id" = "auth"."uid"())));



ALTER TABLE "public"."youth_group_join_requests" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."youth_group_members" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."youth_group_submissions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."youth_groups" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "youth_groups: pastor delete" ON "public"."youth_groups" FOR DELETE USING (("public"."is_group_pastor"("auth"."uid"(), "id") OR "public"."is_site_admin"("auth"."uid"())));



CREATE POLICY "youth_groups: pastor insert" ON "public"."youth_groups" FOR INSERT WITH CHECK ((("auth"."uid"() IS NOT NULL) AND ("public"."has_role"("auth"."uid"(), 'pastor'::"public"."app_role") OR "public"."is_site_admin"("auth"."uid"()))));



CREATE POLICY "youth_groups: pastor update" ON "public"."youth_groups" FOR UPDATE USING (("public"."is_group_pastor"("auth"."uid"(), "id") OR "public"."is_site_admin"("auth"."uid"())));



CREATE POLICY "youth_groups: public read" ON "public"."youth_groups" FOR SELECT USING (true);



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON FUNCTION "public"."_can_manage_feed_post"("_post_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."_can_manage_feed_post"("_post_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_can_manage_feed_post"("_post_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."_dev_grant_age_verification"() TO "anon";
GRANT ALL ON FUNCTION "public"."_dev_grant_age_verification"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."_dev_grant_age_verification"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."_get_service_role_key"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."_get_service_role_key"() TO "service_role";



GRANT ALL ON FUNCTION "public"."_pastor_can_edit_plan"("_plan_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."_pastor_can_edit_plan"("_plan_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_pastor_can_edit_plan"("_plan_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."_pastor_can_view_group"("_group_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."_pastor_can_view_group"("_group_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_pastor_can_view_group"("_group_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."accept_family_invite"("_code" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."accept_family_invite"("_code" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."accept_family_invite"("_code" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."admin_approve_to_official"("_source_post_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."admin_approve_to_official"("_source_post_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_approve_to_official"("_source_post_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."admin_hard_delete_user"("_user_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_hard_delete_user"("_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."admin_hard_delete_user"("_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_hard_delete_user"("_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."admin_list_all_group_posts"("_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."admin_list_all_group_posts"("_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_list_all_group_posts"("_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."admin_weekly_ranking_report"("_week_start" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."admin_weekly_ranking_report"("_week_start" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_weekly_ranking_report"("_week_start" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."am_i_in_any_youth_group"() TO "anon";
GRANT ALL ON FUNCTION "public"."am_i_in_any_youth_group"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."am_i_in_any_youth_group"() TO "service_role";



GRANT ALL ON FUNCTION "public"."can_manage_small_groups"("_user_id" "uuid", "_small_group_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."can_manage_small_groups"("_user_id" "uuid", "_small_group_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_manage_small_groups"("_user_id" "uuid", "_small_group_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."can_manage_user_profile"("_caller_id" "uuid", "_target_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."can_manage_user_profile"("_caller_id" "uuid", "_target_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_manage_user_profile"("_caller_id" "uuid", "_target_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."can_take_attendance"("_user_id" "uuid", "_small_group_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."can_take_attendance"("_user_id" "uuid", "_small_group_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_take_attendance"("_user_id" "uuid", "_small_group_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."can_user_start_plan"("_user_id" "uuid", "_plan_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."can_user_start_plan"("_user_id" "uuid", "_plan_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_user_start_plan"("_user_id" "uuid", "_plan_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."complete_pastor_plan_day"("_plan_id" "uuid", "_day_number" integer, "_answers" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."complete_pastor_plan_day"("_plan_id" "uuid", "_day_number" integer, "_answers" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."complete_pastor_plan_day"("_plan_id" "uuid", "_day_number" integer, "_answers" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."complete_plan_step"("_plan_id" "uuid", "_day_id" "uuid", "_step" "public"."bible_plan_step", "_answers" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."complete_plan_step"("_plan_id" "uuid", "_day_id" "uuid", "_step" "public"."bible_plan_step", "_answers" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."complete_plan_step"("_plan_id" "uuid", "_day_id" "uuid", "_step" "public"."bible_plan_step", "_answers" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."compute_bible_plan_rewards"("_plan_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."compute_bible_plan_rewards"("_plan_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."compute_bible_plan_rewards"("_plan_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_family_invite"("_family_id" "uuid", "_invited_user_id" "uuid", "_invited_email" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."create_family_invite"("_family_id" "uuid", "_invited_user_id" "uuid", "_invited_email" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_family_invite"("_family_id" "uuid", "_invited_user_id" "uuid", "_invited_email" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."ensure_dm_thread"("_group_id" "uuid", "_kind" "public"."thread_kind", "_u1" "uuid", "_u2" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."ensure_dm_thread"("_group_id" "uuid", "_kind" "public"."thread_kind", "_u1" "uuid", "_u2" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ensure_dm_thread"("_group_id" "uuid", "_kind" "public"."thread_kind", "_u1" "uuid", "_u2" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."ensure_group_main_thread"("_group_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."ensure_group_main_thread"("_group_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ensure_group_main_thread"("_group_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."ensure_parent_chat_subscriptions"("_parent_id" "uuid", "_family_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."ensure_parent_chat_subscriptions"("_parent_id" "uuid", "_family_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ensure_parent_chat_subscriptions"("_parent_id" "uuid", "_family_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."ensure_small_group_thread"("_small_group_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."ensure_small_group_thread"("_small_group_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ensure_small_group_thread"("_small_group_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."event_rsvp_summary"("_event_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."event_rsvp_summary"("_event_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."event_rsvp_summary"("_event_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."family_add_via_scan"("_family_id" "uuid", "_scanned_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."family_add_via_scan"("_family_id" "uuid", "_scanned_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."family_add_via_scan"("_family_id" "uuid", "_scanned_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."feed_post_record_view"("_post_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."feed_post_record_view"("_post_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."feed_post_record_view"("_post_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."feed_post_record_watch_complete"("_post_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."feed_post_record_watch_complete"("_post_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."feed_post_record_watch_complete"("_post_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."feed_post_toggle_like"("_post_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."feed_post_toggle_like"("_post_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."feed_post_toggle_like"("_post_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."finalize_pastor_signup"("_draft_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."finalize_pastor_signup"("_draft_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."finalize_pastor_signup"("_draft_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."for_you_feed"("_limit" integer, "_offset" integer, "_group_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."for_you_feed"("_limit" integer, "_offset" integer, "_group_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."for_you_feed"("_limit" integer, "_offset" integer, "_group_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_random_handle"() TO "anon";
GRANT ALL ON FUNCTION "public"."generate_random_handle"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_random_handle"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_continue_card"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_continue_card"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_continue_card"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_group_header_stats"("_group_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_group_header_stats"("_group_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_group_header_stats"("_group_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_my_entitlements"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_my_entitlements"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_my_entitlements"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_my_plan_day_progress"("_plan_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_my_plan_day_progress"("_plan_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_my_plan_day_progress"("_plan_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_my_youth_group_plans"("_filter" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_my_youth_group_plans"("_filter" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_my_youth_group_plans"("_filter" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_pastor_signup_promo"("_code" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_pastor_signup_promo"("_code" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_pastor_signup_promo"("_code" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_plan_progress"("_plan_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_plan_progress"("_plan_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_plan_progress"("_plan_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."has_role"("_user_id" "uuid", "_role" "public"."app_role") TO "anon";
GRANT ALL ON FUNCTION "public"."has_role"("_user_id" "uuid", "_role" "public"."app_role") TO "authenticated";
GRANT ALL ON FUNCTION "public"."has_role"("_user_id" "uuid", "_role" "public"."app_role") TO "service_role";



GRANT ALL ON FUNCTION "public"."heartbeat"() TO "anon";
GRANT ALL ON FUNCTION "public"."heartbeat"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."heartbeat"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."increment_pastor_signup_promo_uses"("_code" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."increment_pastor_signup_promo_uses"("_code" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_group_member"("_user_id" "uuid", "_group_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_group_member"("_user_id" "uuid", "_group_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_group_member"("_user_id" "uuid", "_group_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_group_pastor"("_user_id" "uuid", "_group_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_group_pastor"("_user_id" "uuid", "_group_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_group_pastor"("_user_id" "uuid", "_group_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_in_family"("_family_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_in_family"("_family_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_in_family"("_family_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_in_small_group"("_user_id" "uuid", "_small_group_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_in_small_group"("_user_id" "uuid", "_small_group_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_in_small_group"("_user_id" "uuid", "_small_group_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_pastor"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_pastor"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_pastor"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_paying_subscriber"("_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_paying_subscriber"("_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_paying_subscriber"("_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_pro"("_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_pro"("_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_pro"("_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_site_admin"("_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_site_admin"("_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_site_admin"("_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_small_group_leader"("_user_id" "uuid", "_small_group_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_small_group_leader"("_user_id" "uuid", "_small_group_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_small_group_leader"("_user_id" "uuid", "_small_group_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_thread_subscriber"("_thread_id" "uuid", "_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_thread_subscriber"("_thread_id" "uuid", "_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_thread_subscriber"("_thread_id" "uuid", "_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."join_group_via_qr_scan"("_group_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."join_group_via_qr_scan"("_group_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."join_group_via_qr_scan"("_group_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."level_for_xp"("_xp" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."level_for_xp"("_xp" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."level_for_xp"("_xp" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."list_my_families"() TO "anon";
GRANT ALL ON FUNCTION "public"."list_my_families"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_my_families"() TO "service_role";



GRANT ALL ON FUNCTION "public"."list_my_pending_family_invites"() TO "anon";
GRANT ALL ON FUNCTION "public"."list_my_pending_family_invites"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_my_pending_family_invites"() TO "service_role";



GRANT ALL ON FUNCTION "public"."list_my_threads"() TO "anon";
GRANT ALL ON FUNCTION "public"."list_my_threads"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_my_threads"() TO "service_role";



GRANT ALL ON FUNCTION "public"."mark_thread_read"("_thread_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."mark_thread_read"("_thread_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."mark_thread_read"("_thread_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."my_event_carousels"() TO "anon";
GRANT ALL ON FUNCTION "public"."my_event_carousels"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."my_event_carousels"() TO "service_role";



GRANT ALL ON FUNCTION "public"."pastor_active_user_count"("_pastor_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."pastor_active_user_count"("_pastor_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pastor_active_user_count"("_pastor_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."pastor_approve_alert"("_alert_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."pastor_approve_alert"("_alert_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pastor_approve_alert"("_alert_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."pastor_approve_join_request"("_request_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."pastor_approve_join_request"("_request_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pastor_approve_join_request"("_request_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."pastor_archive_feed_post"("_post_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."pastor_archive_feed_post"("_post_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pastor_archive_feed_post"("_post_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."pastor_archive_plan"("_plan_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."pastor_archive_plan"("_plan_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pastor_archive_plan"("_plan_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."pastor_attach_slideshow_photos"("_post_id" "uuid", "_photos" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."pastor_attach_slideshow_photos"("_post_id" "uuid", "_photos" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pastor_attach_slideshow_photos"("_post_id" "uuid", "_photos" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."pastor_attach_video_to_post"("_post_id" "uuid", "_video_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."pastor_attach_video_to_post"("_post_id" "uuid", "_video_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pastor_attach_video_to_post"("_post_id" "uuid", "_video_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."pastor_clear_instagram_source"("_source_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."pastor_clear_instagram_source"("_source_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pastor_clear_instagram_source"("_source_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."pastor_create_feed_slideshow_post"("_group_id" "uuid", "_title" "text", "_caption" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."pastor_create_feed_slideshow_post"("_group_id" "uuid", "_title" "text", "_caption" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pastor_create_feed_slideshow_post"("_group_id" "uuid", "_title" "text", "_caption" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."pastor_create_plan"("_group_id" "uuid", "_title" "text", "_days" integer, "_gradient_idx" integer, "_visibility" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."pastor_create_plan"("_group_id" "uuid", "_title" "text", "_days" integer, "_gradient_idx" integer, "_visibility" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pastor_create_plan"("_group_id" "uuid", "_title" "text", "_days" integer, "_gradient_idx" integer, "_visibility" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."pastor_create_plan"("_group_id" "uuid", "_title" "text", "_days" integer, "_gradient_idx" integer, "_visibility" "text", "_additional_group_ids" "uuid"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."pastor_create_plan"("_group_id" "uuid", "_title" "text", "_days" integer, "_gradient_idx" integer, "_visibility" "text", "_additional_group_ids" "uuid"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."pastor_create_plan"("_group_id" "uuid", "_title" "text", "_days" integer, "_gradient_idx" integer, "_visibility" "text", "_additional_group_ids" "uuid"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."pastor_dashboard"("_group_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."pastor_dashboard"("_group_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pastor_dashboard"("_group_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."pastor_delete_feed_post"("_post_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."pastor_delete_feed_post"("_post_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pastor_delete_feed_post"("_post_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."pastor_delete_plan"("_plan_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."pastor_delete_plan"("_plan_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pastor_delete_plan"("_plan_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."pastor_deny_join_request"("_request_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."pastor_deny_join_request"("_request_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pastor_deny_join_request"("_request_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."pastor_list_group_members"("_group_id" "uuid", "_role_filter" "text", "_active_only" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."pastor_list_group_members"("_group_id" "uuid", "_role_filter" "text", "_active_only" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."pastor_list_group_members"("_group_id" "uuid", "_role_filter" "text", "_active_only" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."pastor_list_join_requests"("_group_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."pastor_list_join_requests"("_group_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pastor_list_join_requests"("_group_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."pastor_list_my_plans"() TO "anon";
GRANT ALL ON FUNCTION "public"."pastor_list_my_plans"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."pastor_list_my_plans"() TO "service_role";



GRANT ALL ON FUNCTION "public"."pastor_list_small_groups"("_group_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."pastor_list_small_groups"("_group_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pastor_list_small_groups"("_group_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."pastor_member_profile"("_group_id" "uuid", "_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."pastor_member_profile"("_group_id" "uuid", "_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pastor_member_profile"("_group_id" "uuid", "_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."pastor_moderation_queue"("_group_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."pastor_moderation_queue"("_group_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pastor_moderation_queue"("_group_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."pastor_my_groups"() TO "anon";
GRANT ALL ON FUNCTION "public"."pastor_my_groups"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."pastor_my_groups"() TO "service_role";



GRANT ALL ON FUNCTION "public"."pastor_overview_metrics"("_group_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."pastor_overview_metrics"("_group_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pastor_overview_metrics"("_group_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."pastor_publish_feed_post"("_post_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."pastor_publish_feed_post"("_post_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pastor_publish_feed_post"("_post_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."pastor_publish_plan"("_plan_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."pastor_publish_plan"("_plan_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pastor_publish_plan"("_plan_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."pastor_recent_activity"("_group_id" "uuid", "_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."pastor_recent_activity"("_group_id" "uuid", "_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."pastor_recent_activity"("_group_id" "uuid", "_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."pastor_reject_alert"("_alert_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."pastor_reject_alert"("_alert_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pastor_reject_alert"("_alert_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."pastor_set_instagram_source"("_group_id" "uuid", "_handle" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."pastor_set_instagram_source"("_group_id" "uuid", "_handle" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pastor_set_instagram_source"("_group_id" "uuid", "_handle" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."pastor_update_plan_basics"("_plan_id" "uuid", "_title" "text", "_days" integer, "_header_kind" "text", "_header_image_url" "text", "_gradient_idx" integer, "_visibility" "text", "_group_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."pastor_update_plan_basics"("_plan_id" "uuid", "_title" "text", "_days" integer, "_header_kind" "text", "_header_image_url" "text", "_gradient_idx" integer, "_visibility" "text", "_group_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pastor_update_plan_basics"("_plan_id" "uuid", "_title" "text", "_days" integer, "_header_kind" "text", "_header_image_url" "text", "_gradient_idx" integer, "_visibility" "text", "_group_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."pastor_update_plan_basics"("_plan_id" "uuid", "_title" "text", "_days" integer, "_header_kind" "text", "_header_image_url" "text", "_gradient_idx" integer, "_visibility" "text", "_group_id" "uuid", "_additional_group_ids" "uuid"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."pastor_update_plan_basics"("_plan_id" "uuid", "_title" "text", "_days" integer, "_header_kind" "text", "_header_image_url" "text", "_gradient_idx" integer, "_visibility" "text", "_group_id" "uuid", "_additional_group_ids" "uuid"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."pastor_update_plan_basics"("_plan_id" "uuid", "_title" "text", "_days" integer, "_header_kind" "text", "_header_image_url" "text", "_gradient_idx" integer, "_visibility" "text", "_group_id" "uuid", "_additional_group_ids" "uuid"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."pastor_upsert_day"("_plan_id" "uuid", "_day_number" integer, "_title" "text", "_scripture_reference" "text", "_blocks" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."pastor_upsert_day"("_plan_id" "uuid", "_day_number" integer, "_title" "text", "_scripture_reference" "text", "_blocks" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pastor_upsert_day"("_plan_id" "uuid", "_day_number" integer, "_title" "text", "_scripture_reference" "text", "_blocks" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."pastor_weekly_ranking_history"("_group_id" "uuid", "_weeks" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."pastor_weekly_ranking_history"("_group_id" "uuid", "_weeks" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."pastor_weekly_ranking_history"("_group_id" "uuid", "_weeks" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."pastor_weekly_ranking_report"("_group_id" "uuid", "_week_start" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."pastor_weekly_ranking_report"("_group_id" "uuid", "_week_start" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pastor_weekly_ranking_report"("_group_id" "uuid", "_week_start" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."profile_is_adult"("_dob" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."profile_is_adult"("_dob" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."profile_is_adult"("_dob" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."profile_is_under_13"("_dob" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."profile_is_under_13"("_dob" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."profile_is_under_13"("_dob" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."public_event_summary"("_event_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."public_event_summary"("_event_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."public_event_summary"("_event_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."public_events_nearby"("_lat" double precision, "_lng" double precision, "_radius_m" integer, "_limit" integer, "_window_days" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."public_events_nearby"("_lat" double precision, "_lng" double precision, "_radius_m" integer, "_limit" integer, "_window_days" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."public_events_nearby"("_lat" double precision, "_lng" double precision, "_radius_m" integer, "_limit" integer, "_window_days" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."purge_soft_deleted_profiles"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."purge_soft_deleted_profiles"() TO "anon";
GRANT ALL ON FUNCTION "public"."purge_soft_deleted_profiles"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."purge_soft_deleted_profiles"() TO "service_role";



GRANT ALL ON FUNCTION "public"."ranking_top_groups_in_my_class"("_group_id" "uuid", "_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."ranking_top_groups_in_my_class"("_group_id" "uuid", "_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."ranking_top_groups_in_my_class"("_group_id" "uuid", "_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."ranking_top_groups_overall"("_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."ranking_top_groups_overall"("_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."ranking_top_groups_overall"("_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."ranking_top_users_in_group"("_group_id" "uuid", "_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."ranking_top_users_in_group"("_group_id" "uuid", "_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."ranking_top_users_in_group"("_group_id" "uuid", "_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."ranking_top_users_overall"("_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."ranking_top_users_overall"("_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."ranking_top_users_overall"("_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."remove_family"("_family_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."remove_family"("_family_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."remove_family"("_family_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."request_account_deletion"() TO "anon";
GRANT ALL ON FUNCTION "public"."request_account_deletion"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."request_account_deletion"() TO "service_role";



GRANT ALL ON TABLE "public"."youth_group_join_requests" TO "anon";
GRANT ALL ON TABLE "public"."youth_group_join_requests" TO "authenticated";
GRANT ALL ON TABLE "public"."youth_group_join_requests" TO "service_role";



GRANT ALL ON FUNCTION "public"."request_to_join_group"("_group_id" "uuid", "_message" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."request_to_join_group"("_group_id" "uuid", "_message" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."request_to_join_group"("_group_id" "uuid", "_message" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."respond_to_join_request"("_request_id" "uuid", "_approve" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."respond_to_join_request"("_request_id" "uuid", "_approve" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."respond_to_join_request"("_request_id" "uuid", "_approve" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."rsvp_public_event"("_event_id" "uuid", "_status" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."rsvp_public_event"("_event_id" "uuid", "_status" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."rsvp_public_event"("_event_id" "uuid", "_status" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."save_attendance"("_event_id" "uuid", "_records" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."save_attendance"("_event_id" "uuid", "_records" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_attendance"("_event_id" "uuid", "_records" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."set_map_visibility"("_visible" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."set_map_visibility"("_visible" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_map_visibility"("_visible" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."set_member_role"("_group_id" "uuid", "_user_id" "uuid", "_new_role" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."set_member_role"("_group_id" "uuid", "_user_id" "uuid", "_new_role" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_member_role"("_group_id" "uuid", "_user_id" "uuid", "_new_role" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."share_chat_thread"("_other_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."share_chat_thread"("_other_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."share_chat_thread"("_other_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."snapshot_last_week_rankings"() TO "anon";
GRANT ALL ON FUNCTION "public"."snapshot_last_week_rankings"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."snapshot_last_week_rankings"() TO "service_role";



GRANT ALL ON FUNCTION "public"."start_family"("_name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."start_family"("_name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."start_family"("_name" "text") TO "service_role";



GRANT ALL ON TABLE "public"."youth_group_submissions" TO "anon";
GRANT ALL ON TABLE "public"."youth_group_submissions" TO "authenticated";
GRANT ALL ON TABLE "public"."youth_group_submissions" TO "service_role";



GRANT ALL ON FUNCTION "public"."submit_youth_group_request"("_church_name" "text", "_pastor_name" "text", "_pastor_email" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."submit_youth_group_request"("_church_name" "text", "_pastor_name" "text", "_pastor_email" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."submit_youth_group_request"("_church_name" "text", "_pastor_name" "text", "_pastor_email" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."target_tier_for_count"("_count" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."target_tier_for_count"("_count" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."target_tier_for_count"("_count" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."tg_attendance_events_default_creator"() TO "anon";
GRANT ALL ON FUNCTION "public"."tg_attendance_events_default_creator"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."tg_attendance_events_default_creator"() TO "service_role";



GRANT ALL ON FUNCTION "public"."tg_bible_plan_days_recompute_rewards"() TO "anon";
GRANT ALL ON FUNCTION "public"."tg_bible_plan_days_recompute_rewards"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."tg_bible_plan_days_recompute_rewards"() TO "service_role";



GRANT ALL ON FUNCTION "public"."tg_bible_plans_recompute_rewards_on_days_total"() TO "anon";
GRANT ALL ON FUNCTION "public"."tg_bible_plans_recompute_rewards_on_days_total"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."tg_bible_plans_recompute_rewards_on_days_total"() TO "service_role";



GRANT ALL ON FUNCTION "public"."tg_bible_plans_set_published_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."tg_bible_plans_set_published_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."tg_bible_plans_set_published_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."tg_block_pastor_self_leave"() TO "anon";
GRANT ALL ON FUNCTION "public"."tg_block_pastor_self_leave"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."tg_block_pastor_self_leave"() TO "service_role";



GRANT ALL ON FUNCTION "public"."tg_chat_on_small_group_member_delete"() TO "anon";
GRANT ALL ON FUNCTION "public"."tg_chat_on_small_group_member_delete"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."tg_chat_on_small_group_member_delete"() TO "service_role";



GRANT ALL ON FUNCTION "public"."tg_chat_on_small_group_member_insert"() TO "anon";
GRANT ALL ON FUNCTION "public"."tg_chat_on_small_group_member_insert"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."tg_chat_on_small_group_member_insert"() TO "service_role";



GRANT ALL ON FUNCTION "public"."tg_chat_on_youth_group_member_delete"() TO "anon";
GRANT ALL ON FUNCTION "public"."tg_chat_on_youth_group_member_delete"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."tg_chat_on_youth_group_member_delete"() TO "service_role";



GRANT ALL ON FUNCTION "public"."tg_chat_on_youth_group_member_insert"() TO "anon";
GRANT ALL ON FUNCTION "public"."tg_chat_on_youth_group_member_insert"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."tg_chat_on_youth_group_member_insert"() TO "service_role";



GRANT ALL ON FUNCTION "public"."tg_family_members_subscribe_parents"() TO "anon";
GRANT ALL ON FUNCTION "public"."tg_family_members_subscribe_parents"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."tg_family_members_subscribe_parents"() TO "service_role";



GRANT ALL ON FUNCTION "public"."tg_feed_post_engagement_recount"() TO "anon";
GRANT ALL ON FUNCTION "public"."tg_feed_post_engagement_recount"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."tg_feed_post_engagement_recount"() TO "service_role";



GRANT ALL ON FUNCTION "public"."tg_kick_instagram_scrape"() TO "anon";
GRANT ALL ON FUNCTION "public"."tg_kick_instagram_scrape"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."tg_kick_instagram_scrape"() TO "service_role";



GRANT ALL ON FUNCTION "public"."tg_notify_pastor_on_join_request"() TO "anon";
GRANT ALL ON FUNCTION "public"."tg_notify_pastor_on_join_request"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."tg_notify_pastor_on_join_request"() TO "service_role";



GRANT ALL ON FUNCTION "public"."tg_profiles_lock_handle"() TO "anon";
GRANT ALL ON FUNCTION "public"."tg_profiles_lock_handle"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."tg_profiles_lock_handle"() TO "service_role";



GRANT ALL ON FUNCTION "public"."tg_send_lead_welcome_email"() TO "anon";
GRANT ALL ON FUNCTION "public"."tg_send_lead_welcome_email"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."tg_send_lead_welcome_email"() TO "service_role";



GRANT ALL ON FUNCTION "public"."tg_touch_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."tg_touch_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."tg_touch_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."thread_group_id"("_thread_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."thread_group_id"("_thread_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."thread_group_id"("_thread_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."touch_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."touch_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."touch_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."try_parse_uuid"("_s" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."try_parse_uuid"("_s" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."try_parse_uuid"("_s" "text") TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON FUNCTION "public"."update_managed_profile"("_target_user_id" "uuid", "_display_name" "text", "_avatar_url" "text", "_bio" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."update_managed_profile"("_target_user_id" "uuid", "_display_name" "text", "_avatar_url" "text", "_bio" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_managed_profile"("_target_user_id" "uuid", "_display_name" "text", "_avatar_url" "text", "_bio" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."xp_class_for"("_active_count" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."xp_class_for"("_active_count" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."xp_class_for"("_active_count" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."xp_for_level"("_level" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."xp_for_level"("_level" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."xp_for_level"("_level" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."youth_group_public_profile"("_group_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."youth_group_public_profile"("_group_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."youth_group_public_profile"("_group_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."youth_groups_near"("_lat" double precision, "_lng" double precision, "_meters" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."youth_groups_near"("_lat" double precision, "_lng" double precision, "_meters" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."youth_groups_near"("_lat" double precision, "_lng" double precision, "_meters" numeric) TO "service_role";



GRANT ALL ON TABLE "public"."_internal_secrets" TO "service_role";



GRANT ALL ON TABLE "public"."apple_subscriptions" TO "anon";
GRANT ALL ON TABLE "public"."apple_subscriptions" TO "authenticated";
GRANT ALL ON TABLE "public"."apple_subscriptions" TO "service_role";



GRANT ALL ON TABLE "public"."attendance_event_summary" TO "anon";
GRANT ALL ON TABLE "public"."attendance_event_summary" TO "authenticated";
GRANT ALL ON TABLE "public"."attendance_event_summary" TO "service_role";



GRANT ALL ON TABLE "public"."attendance_events" TO "anon";
GRANT ALL ON TABLE "public"."attendance_events" TO "authenticated";
GRANT ALL ON TABLE "public"."attendance_events" TO "service_role";



GRANT ALL ON TABLE "public"."attendance_records" TO "anon";
GRANT ALL ON TABLE "public"."attendance_records" TO "authenticated";
GRANT ALL ON TABLE "public"."attendance_records" TO "service_role";



GRANT ALL ON TABLE "public"."bible_plan_completions" TO "anon";
GRANT ALL ON TABLE "public"."bible_plan_completions" TO "authenticated";
GRANT ALL ON TABLE "public"."bible_plan_completions" TO "service_role";



GRANT ALL ON TABLE "public"."bible_plan_day_progress" TO "anon";
GRANT ALL ON TABLE "public"."bible_plan_day_progress" TO "authenticated";
GRANT ALL ON TABLE "public"."bible_plan_day_progress" TO "service_role";



GRANT ALL ON TABLE "public"."bible_plan_days" TO "anon";
GRANT ALL ON TABLE "public"."bible_plan_days" TO "authenticated";
GRANT ALL ON TABLE "public"."bible_plan_days" TO "service_role";



GRANT ALL ON TABLE "public"."bible_plan_step_progress" TO "anon";
GRANT ALL ON TABLE "public"."bible_plan_step_progress" TO "authenticated";
GRANT ALL ON TABLE "public"."bible_plan_step_progress" TO "service_role";



GRANT ALL ON TABLE "public"."bible_plans" TO "anon";
GRANT ALL ON TABLE "public"."bible_plans" TO "authenticated";
GRANT ALL ON TABLE "public"."bible_plans" TO "service_role";



GRANT ALL ON TABLE "public"."chat_threads" TO "anon";
GRANT ALL ON TABLE "public"."chat_threads" TO "authenticated";
GRANT ALL ON TABLE "public"."chat_threads" TO "service_role";



GRANT ALL ON TABLE "public"."child_pairing_tokens" TO "anon";
GRANT ALL ON TABLE "public"."child_pairing_tokens" TO "authenticated";
GRANT ALL ON TABLE "public"."child_pairing_tokens" TO "service_role";



GRANT ALL ON TABLE "public"."event_external_rsvps" TO "anon";
GRANT ALL ON TABLE "public"."event_external_rsvps" TO "authenticated";
GRANT ALL ON TABLE "public"."event_external_rsvps" TO "service_role";



GRANT ALL ON TABLE "public"."event_media" TO "anon";
GRANT ALL ON TABLE "public"."event_media" TO "authenticated";
GRANT ALL ON TABLE "public"."event_media" TO "service_role";



GRANT ALL ON TABLE "public"."event_rsvps" TO "anon";
GRANT ALL ON TABLE "public"."event_rsvps" TO "authenticated";
GRANT ALL ON TABLE "public"."event_rsvps" TO "service_role";



GRANT ALL ON TABLE "public"."events" TO "anon";
GRANT ALL ON TABLE "public"."events" TO "authenticated";
GRANT ALL ON TABLE "public"."events" TO "service_role";



GRANT ALL ON TABLE "public"."families" TO "anon";
GRANT ALL ON TABLE "public"."families" TO "authenticated";
GRANT ALL ON TABLE "public"."families" TO "service_role";



GRANT ALL ON TABLE "public"."family_invites" TO "anon";
GRANT ALL ON TABLE "public"."family_invites" TO "authenticated";
GRANT ALL ON TABLE "public"."family_invites" TO "service_role";



GRANT ALL ON TABLE "public"."family_members" TO "anon";
GRANT ALL ON TABLE "public"."family_members" TO "authenticated";
GRANT ALL ON TABLE "public"."family_members" TO "service_role";



GRANT ALL ON TABLE "public"."feed_post_engagement" TO "anon";
GRANT ALL ON TABLE "public"."feed_post_engagement" TO "authenticated";
GRANT ALL ON TABLE "public"."feed_post_engagement" TO "service_role";



GRANT ALL ON TABLE "public"."feed_post_photos" TO "anon";
GRANT ALL ON TABLE "public"."feed_post_photos" TO "authenticated";
GRANT ALL ON TABLE "public"."feed_post_photos" TO "service_role";



GRANT ALL ON TABLE "public"."feed_posts" TO "anon";
GRANT ALL ON TABLE "public"."feed_posts" TO "authenticated";
GRANT ALL ON TABLE "public"."feed_posts" TO "service_role";



GRANT ALL ON TABLE "public"."instagram_scrape_jobs" TO "anon";
GRANT ALL ON TABLE "public"."instagram_scrape_jobs" TO "authenticated";
GRANT ALL ON TABLE "public"."instagram_scrape_jobs" TO "service_role";



GRANT ALL ON TABLE "public"."instagram_sources" TO "anon";
GRANT ALL ON TABLE "public"."instagram_sources" TO "authenticated";
GRANT ALL ON TABLE "public"."instagram_sources" TO "service_role";



GRANT ALL ON TABLE "public"."messages" TO "anon";
GRANT ALL ON TABLE "public"."messages" TO "authenticated";
GRANT ALL ON TABLE "public"."messages" TO "service_role";



GRANT ALL ON TABLE "public"."moderation_alerts" TO "anon";
GRANT ALL ON TABLE "public"."moderation_alerts" TO "authenticated";
GRANT ALL ON TABLE "public"."moderation_alerts" TO "service_role";



GRANT ALL ON TABLE "public"."moderation_flags" TO "anon";
GRANT ALL ON TABLE "public"."moderation_flags" TO "authenticated";
GRANT ALL ON TABLE "public"."moderation_flags" TO "service_role";



GRANT ALL ON TABLE "public"."stripe_subscriptions" TO "anon";
GRANT ALL ON TABLE "public"."stripe_subscriptions" TO "authenticated";
GRANT ALL ON TABLE "public"."stripe_subscriptions" TO "service_role";



GRANT ALL ON TABLE "public"."subscription_tiers" TO "anon";
GRANT ALL ON TABLE "public"."subscription_tiers" TO "authenticated";
GRANT ALL ON TABLE "public"."subscription_tiers" TO "service_role";



GRANT ALL ON TABLE "public"."pastor_billing_summary" TO "anon";
GRANT ALL ON TABLE "public"."pastor_billing_summary" TO "authenticated";
GRANT ALL ON TABLE "public"."pastor_billing_summary" TO "service_role";



GRANT ALL ON TABLE "public"."pastor_signup_drafts" TO "anon";
GRANT ALL ON TABLE "public"."pastor_signup_drafts" TO "authenticated";
GRANT ALL ON TABLE "public"."pastor_signup_drafts" TO "service_role";



GRANT ALL ON TABLE "public"."pastor_signup_promos" TO "anon";
GRANT ALL ON TABLE "public"."pastor_signup_promos" TO "authenticated";
GRANT ALL ON TABLE "public"."pastor_signup_promos" TO "service_role";



GRANT ALL ON TABLE "public"."small_group_members" TO "anon";
GRANT ALL ON TABLE "public"."small_group_members" TO "authenticated";
GRANT ALL ON TABLE "public"."small_group_members" TO "service_role";



GRANT ALL ON TABLE "public"."small_groups" TO "anon";
GRANT ALL ON TABLE "public"."small_groups" TO "authenticated";
GRANT ALL ON TABLE "public"."small_groups" TO "service_role";



GRANT ALL ON TABLE "public"."store_item_levels" TO "anon";
GRANT ALL ON TABLE "public"."store_item_levels" TO "authenticated";
GRANT ALL ON TABLE "public"."store_item_levels" TO "service_role";



GRANT ALL ON TABLE "public"."store_items" TO "anon";
GRANT ALL ON TABLE "public"."store_items" TO "authenticated";
GRANT ALL ON TABLE "public"."store_items" TO "service_role";



GRANT ALL ON TABLE "public"."stripe_events" TO "anon";
GRANT ALL ON TABLE "public"."stripe_events" TO "authenticated";
GRANT ALL ON TABLE "public"."stripe_events" TO "service_role";



GRANT ALL ON TABLE "public"."thread_subscribers" TO "anon";
GRANT ALL ON TABLE "public"."thread_subscribers" TO "authenticated";
GRANT ALL ON TABLE "public"."thread_subscribers" TO "service_role";



GRANT ALL ON TABLE "public"."user_roles" TO "anon";
GRANT ALL ON TABLE "public"."user_roles" TO "authenticated";
GRANT ALL ON TABLE "public"."user_roles" TO "service_role";



GRANT ALL ON TABLE "public"."user_streak_milestone_grants" TO "anon";
GRANT ALL ON TABLE "public"."user_streak_milestone_grants" TO "authenticated";
GRANT ALL ON TABLE "public"."user_streak_milestone_grants" TO "service_role";



GRANT ALL ON TABLE "public"."user_xp_grants" TO "anon";
GRANT ALL ON TABLE "public"."user_xp_grants" TO "authenticated";
GRANT ALL ON TABLE "public"."user_xp_grants" TO "service_role";



GRANT ALL ON TABLE "public"."videos" TO "anon";
GRANT ALL ON TABLE "public"."videos" TO "authenticated";
GRANT ALL ON TABLE "public"."videos" TO "service_role";



GRANT ALL ON TABLE "public"."weekly_ranking_snapshots" TO "anon";
GRANT ALL ON TABLE "public"."weekly_ranking_snapshots" TO "authenticated";
GRANT ALL ON TABLE "public"."weekly_ranking_snapshots" TO "service_role";



GRANT ALL ON TABLE "public"."weekly_user_ranking_snapshots" TO "anon";
GRANT ALL ON TABLE "public"."weekly_user_ranking_snapshots" TO "authenticated";
GRANT ALL ON TABLE "public"."weekly_user_ranking_snapshots" TO "service_role";



GRANT ALL ON TABLE "public"."youth_group_members" TO "anon";
GRANT ALL ON TABLE "public"."youth_group_members" TO "authenticated";
GRANT ALL ON TABLE "public"."youth_group_members" TO "service_role";



GRANT ALL ON TABLE "public"."youth_groups" TO "anon";
GRANT ALL ON TABLE "public"."youth_groups" TO "authenticated";
GRANT ALL ON TABLE "public"."youth_groups" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";







