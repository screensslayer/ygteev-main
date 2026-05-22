
do $$ begin
  create type public.group_submission_status as enum ('pending','contacted','approved','rejected');
exception when duplicate_object then null; end $$;

create table if not exists public.youth_group_submissions (
  id              uuid primary key default gen_random_uuid(),
  submitter_id    uuid references auth.users(id) on delete set null,
  submitter_email text,
  church_name     text not null,
  pastor_name     text not null,
  pastor_email    text not null,
  status          public.group_submission_status not null default 'pending',
  notes           text,
  created_at      timestamptz not null default now(),
  decided_at      timestamptz,
  decided_by      uuid references auth.users(id) on delete set null
);
create index if not exists ygs_status_idx    on public.youth_group_submissions(status);
create index if not exists ygs_submitter_idx on public.youth_group_submissions(submitter_id);
create index if not exists ygs_created_idx   on public.youth_group_submissions(created_at desc);

alter table public.youth_group_submissions enable row level security;

drop policy if exists "ygs: read"             on public.youth_group_submissions;
drop policy if exists "ygs: admin update"     on public.youth_group_submissions;
drop policy if exists "ygs: no client insert" on public.youth_group_submissions;

create policy "ygs: read" on public.youth_group_submissions for select using (
  public.is_site_admin(auth.uid())
  or submitter_id = auth.uid()
);
create policy "ygs: admin update" on public.youth_group_submissions for update
  using (public.is_site_admin(auth.uid()))
  with check (public.is_site_admin(auth.uid()));
create policy "ygs: no client insert" on public.youth_group_submissions
  for insert with check (false);

-- RPC: authenticated users submit; server attaches user id + dedupes pending
create or replace function public.submit_youth_group_request(
  _church_name  text,
  _pastor_name  text,
  _pastor_email text
) returns public.youth_group_submissions
language plpgsql security definer set search_path = public as $$
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
end $$;
