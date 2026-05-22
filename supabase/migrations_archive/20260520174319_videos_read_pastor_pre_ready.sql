-- Pastors couldn't read their own freshly-uploaded videos while Mux was
-- still encoding (status='uploading'|'processing') because the SELECT
-- RLS gated youthGroup-scoped rows behind status='ready'. That broke
-- the iOS upload flow's poll-until-ready loop with
-- "Cannot coerce the result to a single JSON object" (single() saw 0
-- rows). Extend the policy so the group's pastor (or site admin) sees
-- their own group's videos regardless of status, matching the pattern
-- we already use for plan-scope videos.

drop policy if exists "videos: visibility read" on public.videos;

create policy "videos: visibility read"
on public.videos
for select
to public
using (
  is_site_admin(auth.uid())
  or (
    status = 'ready'::video_status
    and (
      scope = 'global'::video_scope
      or (
        scope = 'youthGroup'::video_scope
        and group_id is not null
        and is_group_member(auth.uid(), group_id)
      )
    )
  )
  or (
    -- NEW: pastor of the group sees uploads at any status while
    -- Mux is processing.
    scope = 'youthGroup'::video_scope
    and group_id is not null
    and is_group_pastor(auth.uid(), group_id)
  )
  or (
    scope = 'plan'::video_scope
    and exists (
      select 1
      from public.bible_plan_days d
      join public.bible_plans p on p.id = d.plan_id
      where d.id = videos.plan_day_id
        and (
          public._pastor_can_edit_plan(p.id)
          or (videos.status = 'ready'::video_status
              and public.can_user_start_plan(auth.uid(), p.id))
        )
    )
  )
);
