# Migrations Archive

These 116 SQL files are the **historical record** of every migration applied to prod via the Supabase MCP `apply_migration` tool between 2026-05-11 and 2026-05-22, extracted from `supabase_migrations.schema_migrations` on 2026-05-22.

They are **NOT applied** by `supabase db push`. They are not a buildable history from scratch — they assume a pre-MCP base schema that was set up via the Supabase dashboard and never captured in a migration file.

## Purpose

- `git grep` and `git log` over these files lets you find when a given table, column, RPC, or policy was added.
- Use them as reference when investigating "why does X exist."

## Current source of truth

`../migrations/00000000000000_initial_baseline.sql` represents the live prod schema as of 2026-05-22. New migrations after that point go in `../migrations/` as normal.

## Why archive instead of delete

Cheap to keep, valuable for blame/search. Delete only if the folder ever becomes confusing.
