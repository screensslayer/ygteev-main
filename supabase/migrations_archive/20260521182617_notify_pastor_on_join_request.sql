
-- Fire the send-join-request-email Edge Function whenever a new
-- pending join request is created. Uses pg_net.http_post for an
-- async, non-blocking call — the INSERT returns immediately and the
-- email is delivered out of band.
--
-- We only fire on status='pending' (the default) to avoid emailing
-- for bulk-loaded approved memberships or cancellations created via
-- admin tooling.

create or replace function public.tg_notify_pastor_on_join_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
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

drop trigger if exists tg_notify_pastor_on_join_request on public.youth_group_join_requests;

create trigger tg_notify_pastor_on_join_request
after insert on public.youth_group_join_requests
for each row execute function public.tg_notify_pastor_on_join_request();
