
-- One-call dashboard for the pastor's Overview page. Returns:
--   • setup checklist (so the page can show a setup flow until the
--     group is fully configured, then disappear)
--   • headline metrics: active count, total members, weekly XP,
--     flagged-message backlog
--   • 12-week new-member growth series for a chart
--   • secondary counters: small groups, upcoming events
--
-- Permission: caller must be a pastor of the group (or site admin).

create or replace function public.pastor_overview_metrics(_group_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
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

grant execute on function public.pastor_overview_metrics(uuid) to authenticated;
