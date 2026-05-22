# YGTeeV — Staging + CI/CD Decision Doc

Locked-in decisions for moving from "MCP straight to prod" to a staged, repo-as-source-of-truth workflow. Each section flags one of:
- **[DECIDED]** — my recommendation, proceed unless you override
- **[OPEN]** — needs your input before we build

Last updated: 2026-05-22

---

## 1. Repo layout

**[DECIDED]** Backend code lives alongside iOS in this repo (monorepo).

```
YGTeeV/
├── supabase/
│   ├── config.toml
│   ├── migrations/              # timestamped, source of truth
│   ├── functions/               # one folder per Edge Function
│   ├── seed.sql                 # staging-only seed
│   └── types.ts                 # generated, committed
├── YGTeeV/                      # iOS Swift app (unchanged)
├── YGTeeV.xcodeproj/
└── .github/workflows/
```

**Rationale:** iOS and backend ship together; PRs that touch both are easier in one repo. Lovable CMS stays in its own repo.

---

## 2. Supabase project naming

**[DECIDED]**
- Prod: existing project, ref `tkesywmshaicjmywbovn`, rename to `ygteev-prod` in dashboard for clarity.
- Staging: new project named `ygteev-staging`, **same region as prod** (avoids cross-region latency surprises in tests).
- Both on the **Pro tier** ($25/mo each = $50/mo total). Free tier won't work for staging because pg_cron, pg_net, and edge function logs are needed.

---

## 3. iOS scheme + bundle ID

**[DECIDED]**
- Bundle IDs:
  - Prod: `storybutton.YGTeeV` (existing)
  - Staging: `storybutton.YGTeeV.staging`
- Schemes: `YGTeeV` (prod) and `YGTeeV-Staging`.
- Each scheme uses its own `.xcconfig` (`Prod.xcconfig`, `Staging.xcconfig`) with `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
- **Two separate App Store Connect app records.** Yes, this means duplicating IAP products. The alternative — shared bundle with feature-flagged URL — breaks StoreKit sandbox vs production cleanly and is not worth the complexity.
- App name in staging: `YGTeeV (Staging)` so testers can tell at a glance.
- Staging app icon: same icon with a "STAGING" diagonal banner overlay (iOS Claude generates).

**[DEFERRED]** A third "Local Dev" config pointing at `supabase start` is not in scope for v1. Add later if offline iteration becomes painful.

---

## 4. Lovable pastor CMS staging

**[DECIDED]** Skip Lovable staging — pastor CMS always talks to prod.

**Risk this creates:** schema changes that break PostgREST-visible columns or RPC signatures (rename a column, drop an RPC param, change a return type) won't be caught until prod. The CMS will throw runtime errors against the new schema.

**Mitigations we'll bake into the workflow:**
- Any migration that touches a table or RPC used by the Lovable CMS gets flagged in the PR description with a "Lovable surface change" note.
- Before merging such PRs: manually run the CMS locally (or in Lovable's preview mode) pointed at the **staging** Supabase to verify nothing broke.
- Maintain a list of "Lovable-facing surface" tables and RPCs in `supabase/LOVABLE_SURFACE.md` so we know what's load-bearing.
- Prefer additive schema changes over breaking ones; for breaking ones, ship in two PRs (add new, migrate CMS, drop old).

---

## 5. Branching + deploy strategy

**[DECIDED]** Trunk-based with manual prod promotion:

- `main` is the default branch. PRs merge into `main` after CI passes.
- Merge to `main` → GitHub Actions auto-deploys to **staging** (migrations + edge functions).
- Tag `v*` (e.g. `v1.0.3`) → GitHub Actions deploys to **prod**, but only after `workflow_dispatch` confirmation.
- No long-lived `release` branch. Hotfixes: branch off `main`, PR back, tag.

**Rationale:** solo + small team. A release branch adds ceremony that pays off only with multiple parallel release lines. Tag-based promotion gives the same safety with less overhead.

---

## 6. Migration discipline (the most important rule)

**[DECIDED]**
- All schema changes → `supabase/migrations/<timestamp>_<name>.sql`. Committed. Reviewed. Merged.
- I (this Claude) **stop using `mcp__supabase__apply_migration` against prod** as of Step 0 completion.
- `mcp__supabase__execute_sql` against prod is allowed for: read-only investigation, one-off data fixes that are not schema-shaped (e.g., updating a single bad row), and read-only analytics.
- `mcp__supabase__execute_sql` against staging is allowed for anything — experimentation is the point.
- Cron jobs are schema (they're `pg_cron.schedule()` rows). Put them in migrations.
- Edge Function deploys: same rule — file in repo, merge, CI deploys.

**Enforcement:** honor system + the fact that PRs reviewing migration SQL will catch drift.

---

## 7. Staging data strategy

**[DECIDED]** Long-lived seeded staging, never refreshed from prod.

`supabase/seed.sql` creates:
- 1 site admin (`admin@ygteev-staging.test`)
- 2 pastors (`pastor1@ygteev-staging.test`, `pastor2@ygteev-staging.test`) — one Basic, one Plus
- 1 default YGTeeV group
- 2 real youth groups (one with paid sub, one without — to test the activation gate)
- 5 members spread across groups, varied roles
- 1 small group
- 2 Bible plans (Book of John + one Plus-pastor custom plan)
- A handful of messages, including some flagged ones for the moderation queue
- 1 parent with 2 child accounts

**Why not snapshot prod?** Real user data carries PII risk and the under-13 protection rules make it especially fraught. Seed data avoids all of that and keeps test scenarios deterministic.

**[DECIDED]** Weekly Sunday-night auto-reset. `pg_cron` job in staging runs `reset_staging_data()` Sunday 23:00 UTC. Function wipes user-generated rows (messages, RSVPs, plan progress, garden state, auth.users except seeded test accounts) and re-runs `seed.sql`. Predictable Monday-morning test state.

---

## 8. Secrets management

**[DECIDED]**
- Prod Supabase Vault → prod secrets (unchanged).
- Staging Supabase Vault → sandbox/test versions of every secret (see table in earlier message).
- GitHub Actions secrets:
  - `SUPABASE_ACCESS_TOKEN` — personal access token from supabase.com/dashboard/account/tokens
  - `SUPABASE_PROD_REF` = `tkesywmshaicjmywbovn`
  - `SUPABASE_STAGING_REF` = (new, after Step 1)
- **Never** put service role keys in GitHub Actions secrets. CI uses the access token + project ref, which is enough to push migrations and deploy functions.

---

## 9. CI/CD workflow specifics

**[DECIDED]** Three workflows:

### `.github/workflows/lint.yml` (every PR)
- Checkout
- Install Supabase CLI
- `supabase db lint --schema public` against the migrations folder
- `supabase gen types typescript --linked` against staging, diff against committed `supabase/types.ts` — **fail if drift**
- `deno check supabase/functions/**/*.ts`
- (Future) RLS test runner against an ephemeral Supabase branch

### `.github/workflows/deploy-staging.yml` (merge to `main`)
- `supabase link --project-ref ${{ secrets.SUPABASE_STAGING_REF }}`
- `supabase db push`
- Deploy every changed Edge Function (use `git diff` to detect)
- Post to Slack/Discord webhook on success/failure

### `.github/workflows/deploy-prod.yml` (tag `v*` + manual confirm)
- `workflow_dispatch` with `confirm: "yes"` input required
- Same steps as staging but against prod ref
- Requires the tag to be reachable from `main`

---

## 10. iOS TestFlight pipeline

**[DECIDED]** Manual for v1.0. Xcode → Archive → Distribute App → App Store Connect → Upload. Revisit Fastlane + GitHub Actions automation once shipping cadence exceeds ~1 build/week.

---

## 11. Cost summary

| Item | Monthly | Notes |
|---|---|---|
| Supabase prod | $25 | existing |
| Supabase staging | $25 | new |
| Lovable staging | $0 | skipped per §4 |
| Mux test env | $0 | Mux test uploads are free up to limits |
| OpenAI staging usage | <$5 | moderation + classifier calls during testing |
| GitHub Actions | $0 | free tier covers this load |
| **Total new spend** | **~$25/mo** | |

---

## 12. All decisions locked

All sections above are **[DECIDED]** or **[DEFERRED]**. Build can proceed.

---

## 13. Build order

1. **Step 0** — `supabase db pull` + `supabase functions download --all` against prod. Commit. ~2-4 hrs.
2. **Step 1** — create `ygteev-staging` project, copy schema + functions, duplicate secrets, write `seed.sql`, set up Sunday-night reset cron. ~3-5 hrs.
3. **Step 2** — iOS Claude adds Staging scheme + xcconfig + duplicate IAP products in App Store Connect. ~2-4 hrs (iOS Claude lane).
4. **Step 3** — three GitHub Actions workflows (lint, deploy-staging, deploy-prod). ~2-3 hrs.
5. **Step 4** — write `supabase/LOVABLE_SURFACE.md` listing tables/RPCs the CMS depends on, for breaking-change review. ~30 min.
6. **Done.** Total elapsed: ~1.5–2 working days.
