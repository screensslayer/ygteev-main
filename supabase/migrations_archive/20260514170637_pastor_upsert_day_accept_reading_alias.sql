
-- Widen the block-type allowlist to accept both `read` and `reading`. iOS
-- ended up sending "reading"; that's also what the original design doc used.
-- Both are stored verbatim; nothing else in the server cares about the
-- distinction (reward roll-up only counts `type = 'question'`).

create or replace function public.pastor_upsert_day(
  _plan_id             uuid,
  _day_number          int,
  _title               text,
  _scripture_reference text,
  _blocks              jsonb
) returns uuid
language plpgsql
security definer
set search_path = public
as $func$
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
$func$;

grant execute on function public.pastor_upsert_day(uuid, int, text, text, jsonb) to authenticated;

notify pgrst, 'reload schema';
