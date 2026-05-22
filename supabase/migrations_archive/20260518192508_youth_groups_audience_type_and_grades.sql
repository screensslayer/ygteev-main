alter table public.youth_groups
  add column if not exists group_type text,
  add column if not exists grades     integer[];

alter table public.youth_groups
  drop constraint if exists youth_groups_group_type_check;
alter table public.youth_groups
  add  constraint youth_groups_group_type_check
  check (group_type is null or group_type in ('hs','ms','hs_ms'));

alter table public.youth_groups
  drop constraint if exists youth_groups_grades_range_check;
alter table public.youth_groups
  add  constraint youth_groups_grades_range_check
  check (
    grades is null
    or (
      array_length(grades, 1) between 1 and 7
      and grades <@ array[6,7,8,9,10,11,12]
    )
  );

comment on column public.youth_groups.group_type is
  '''hs'' | ''ms'' | ''hs_ms'' — broad audience tier set by the pastor.';
comment on column public.youth_groups.grades is
  'Specific grade-levels (6..12) the group serves.';
