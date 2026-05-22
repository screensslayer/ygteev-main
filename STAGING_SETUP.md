# Staging Environment — Setup Checklist

The `ygteev-staging` Supabase project is provisioned and schema-matched to prod. This doc lists the manual setup steps that still need to happen — secrets, third-party sandbox configs, and the staging iOS scheme — before staging is functional for end-to-end testing.

## Quick reference

| Thing | Value |
|---|---|
| Project name | `ygteev-staging` |
| Project ref | `nmdfmlcmhauqbbairkjw` |
| Region | `us-east-2` (Ohio) |
| URL | `https://nmdfmlcmhauqbbairkjw.supabase.co` |
| Plan | Free (auto-pauses after 7d inactivity; the Sunday cron prevents this) |
| Dashboard | `https://supabase.com/dashboard/project/nmdfmlcmhauqbbairkjw` |

## Anon / publishable keys (safe to embed in iOS staging build)

```
anon (legacy JWT):     eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5tZGZtbGNtaGF1cWJiYWlya2p3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk0NzA4NjksImV4cCI6MjA5NTA0Njg2OX0.gSFr006xJUpZEGIYkyw1qmo6C_rADDkgVelhqozuPYo

publishable (new):     sb_publishable_JssYrpMXrFKuZSdZ_KZKQg_6kb52u7D
```

Use the publishable key in new iOS code; the legacy anon JWT is here only for parity with existing code that may still use the old format.

## Step 1 — Service role key (REQUIRED for cron jobs and any server-side script)

1. Open the staging project dashboard → Settings → API.
2. Copy the **service_role** secret (starts with `sb_secret_...`, ~41 chars).
3. Run this in the SQL editor of the staging project:

```sql
insert into public._internal_secrets (key, value)
values ('service_role_key', '<paste here>')
on conflict (key) do update set value = excluded.value;
```

This is what `_get_service_role_key()` reads. Required for any cron job that calls an Edge Function.

## Step 2 — Supabase Vault secrets (for Edge Functions)

The 23 Edge Functions are already deployed but most will fail until their secrets are set. Open dashboard → Edge Functions → Manage Secrets, and add:

### Stripe (test mode)
- `STRIPE_SECRET_KEY` — `sk_test_...` from dashboard.stripe.com (test mode)
- `STRIPE_WEBHOOK_SECRET` — `whsec_...` from a NEW webhook endpoint pointed at `https://nmdfmlcmhauqbbairkjw.supabase.co/functions/v1/stripe-webhook` in Stripe test mode

### Apple StoreKit (sandbox)
- `APPLE_SHARED_SECRET` — same as prod, OR a separate sandbox shared secret
- `APPLE_BUNDLE_ID` — `storybutton.YGTeeV.staging` (the staging bundle ID — see iOS section below)
- `APPLE_KEY_ID`, `APPLE_ISSUER_ID`, `APPLE_PRIVATE_KEY` — App Store Server API credentials. For staging, generate a separate key pair or reuse prod's (both work against Apple's sandbox)

### Mux (test env)
- `MUX_TOKEN_ID`, `MUX_TOKEN_SECRET` — create a new env in dashboard.mux.com for staging
- `MUX_WEBHOOK_SECRET` — from the new env's webhook endpoint pointed at the staging mux-webhook URL

### OpenAI
- `OPENAI_API_KEY` — can reuse prod's; or create a separate restricted key with monthly spend cap

### Bible API
- `BIBLE_API_KEY` — can reuse prod's

### Resend
- `RESEND_API_KEY` — same as prod (or a separate "staging" key with the sending domain restricted)

### APNS (development)
- `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_KEY_P8` (base64), `APNS_BUNDLE_ID` — the **development** APNS environment, paired with `storybutton.YGTeeV.staging`

### Apify
- `APIFY_TOKEN`, `APIFY_ACTOR_ID` — can reuse prod's

## Step 3 — iOS Staging scheme (iOS Claude's lane)

This is the part iOS Claude needs to do in Xcode. Self-contained prompt:

> Add a `YGTeeV-Staging` scheme to the YGTeeV Xcode project. It should:
> - Use bundle ID `storybutton.YGTeeV.staging`
> - Use a separate `Staging.xcconfig` with:
>   ```
>   SUPABASE_URL = https://nmdfmlcmhauqbbairkjw.supabase.co
>   SUPABASE_ANON_KEY = sb_publishable_JssYrpMXrFKuZSdZ_KZKQg_6kb52u7D
>   ```
> - Use a separate launch image / app icon with a visible "STAGING" overlay so testers can tell at a glance
> - The Prod scheme keeps its current bundle ID and reads from a parallel `Prod.xcconfig`
> Make sure `SupabaseManager.swift` reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` from Info.plist (which references the xcconfig values), not hardcoded constants.

## Step 4 — App Store Connect staging app (one-time)

Once iOS Claude finishes Step 3:
- App Store Connect → My Apps → New App
- Bundle ID: `storybutton.YGTeeV.staging`
- Name: `YGTeeV (Staging)`
- Recreate the 5 subscription products + 1 child-account IAP for this bundle ID (IAP products are per-bundle)

## Step 5 — DNS / Lovable (skipped per plan)

Per `STAGING_CICD_PLAN.md` §4, the Lovable pastor CMS stays pointed at prod. Schema changes that touch Lovable-facing tables/RPCs follow the discipline in `supabase/LOVABLE_SURFACE.md` (TODO: write this file in Step 4).

## Step 6 — Verification checklist

After secrets are filled in:

- [ ] Run `select public.reset_staging_data();` in staging SQL editor — should return without error (placeholder no-op).
- [ ] Run `select * from cron.job where jobname = 'staging-weekly-reset';` — should show active=true, schedule `0 23 * * 0`.
- [ ] Edge Function smoke test: `curl -X POST https://nmdfmlcmhauqbbairkjw.supabase.co/functions/v1/send-message -H "Authorization: Bearer <publishable_key>"` — should return 401 (auth required, not 500).
- [ ] Sign up a test user via the staging iOS build → confirm `auth.users` row appears and the trigger added them to the default YGTeeV group.

## Current state

| Item | Status |
|---|---|
| Schema (52 tables, 883 functions, 89 RLS policies) | ✅ in sync with prod |
| Storage (6 buckets, 27 RLS policies) | ✅ in sync with prod |
| Edge Functions (23 deployed) | ✅ deployed (need secrets to work) |
| pg_cron + pg_net extensions | ✅ enabled |
| Default YGTeeV group | ✅ seeded |
| `reset_staging_data()` + Sunday cron | ✅ scheduled |
| `_internal_secrets.project_url` | ✅ set to staging URL |
| `_internal_secrets.service_role_key` | ⚠️ Step 1 above |
| Vault secrets for Edge Functions | ⚠️ Step 2 above |
| iOS Staging scheme | ⚠️ Step 3 above (iOS Claude) |
| App Store Connect staging app | ⚠️ Step 4 above |
| `reset_staging_data()` Phase B (actual wipe logic) | TODO when QA actually needs it |
| Seed test users + plans | TODO when QA actually needs it |
