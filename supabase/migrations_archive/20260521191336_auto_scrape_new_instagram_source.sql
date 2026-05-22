
-- When a youth group's IG source is added (or reactivated), kick off
-- a scrape immediately instead of waiting up to 6 hours for the next
-- cron tick. Uses pg_net.http_post into trigger-instagram-scrapes,
-- with the same Authorization pattern the cron uses — so this trigger
-- works as soon as `app.settings.service_role_key` is set on the
-- database. (Until then, the http_post returns 401 silently, but the
-- INSERT itself still succeeds — no risk of blocking source creation.)

create or replace function public.tg_kick_instagram_scrape()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_should_kick boolean := false;
  v_svc text;
begin
  -- Fire on INSERT when active, or UPDATE that flips is_active false→true
  -- or changes the handle for an active row.
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

  v_svc := coalesce(current_setting('app.settings.service_role_key', true), '');

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
  -- Never block source creation if the HTTP plumbing throws.
  raise warning '[tg_kick_instagram_scrape] http_post failed: %', sqlerrm;
  return NEW;
end;
$$;

drop trigger if exists tg_kick_instagram_scrape_ins on public.instagram_sources;
drop trigger if exists tg_kick_instagram_scrape_upd on public.instagram_sources;

create trigger tg_kick_instagram_scrape_ins
after insert on public.instagram_sources
for each row execute function public.tg_kick_instagram_scrape();

create trigger tg_kick_instagram_scrape_upd
after update on public.instagram_sources
for each row execute function public.tg_kick_instagram_scrape();
