
-- Update the auto-scrape trigger to read the service key from the
-- _internal_secrets table via the helper, matching the cron's pattern.

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
