-- bible_cache — server-side passage cache for get-bible-passage (CLAUDE.md
-- Plans domain). Key = translation + normalized reference; 30-day TTL so
-- Crossway sees each passage ~once/month regardless of player count.
-- Server-only table: RLS on, no policies (edge function uses service role).
-- Applied to staging + prod 2026-08-04.

create table if not exists public.bible_cache (
  id uuid primary key default gen_random_uuid(),
  cache_key text not null unique,
  translation text not null,
  reference text not null,
  passage_text text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '30 days'
);
alter table public.bible_cache enable row level security;
