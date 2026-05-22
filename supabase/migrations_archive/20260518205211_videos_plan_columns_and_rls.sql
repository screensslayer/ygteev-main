alter table public.videos
  add column if not exists plan_day_id uuid
    references public.bible_plan_days(id) on delete set null,
  add column if not exists plan_block_id text;

create index if not exists videos_plan_day_id_idx
  on public.videos(plan_day_id) where plan_day_id is not null;

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
