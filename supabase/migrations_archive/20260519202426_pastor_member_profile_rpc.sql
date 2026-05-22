-- Pastor's view of an individual member: profile + small group + 90-day
-- small-group attendance + recent event RSVPs. Single round-trip.
-- Pastor only — gated by is_group_pastor on _group_id. The target
-- user must be either a direct member of the group OR a parent of a
-- child in the group.

create or replace function public.pastor_member_profile(
  _group_id uuid,
  _user_id uuid
)
returns jsonb
language plpgsql stable security definer
set search_path = public
as $function$
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
$function$;

grant execute on function public.pastor_member_profile(uuid, uuid) to authenticated, service_role;
