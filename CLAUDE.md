# YGTeeV Backend — Project Context for Claude Code

This file is your persistent context. **Read it before any task.** Update it as architecture evolves. When in doubt, prefer what's written here over your training-data defaults.

---

## What we're building

YGTeeV is a social gaming Bible-reading app for teens. Users complete daily Bible plans, earn water/XP/streaks, grow plants in a garden, and join their local church's youth group for community + chat. The iOS app is **already built in native Swift** (separate Xcode project). The admin CMS is **built in Lovable** (separate web app). This repo is the **Supabase backend** that powers both: schema, RLS, Edge Functions, triggers, cron jobs, and external integrations.

You will not be writing Swift or the CMS UI. You write SQL migrations, Edge Functions (Deno/TypeScript), and integration glue.

---

## Stack

| Layer | Tool |
|---|---|
| Database / Auth / Storage / Realtime | Supabase (Postgres 17+) |
| Server compute | Supabase Edge Functions (Deno) |
| Cron | `pg_cron` (Supabase) |
| iOS frontend | Native Swift / Xcode (separate repo) |
| Admin CMS | Lovable (separate repo, reads/writes our DB) |
| Video hosting | Mux |
| Maps | Apple MapKit (client-side); PostGIS for server-side geo queries |
| iOS in-app payments | Apple StoreKit 2 → server-side receipt validation |
| Web payments (pastors) | Stripe |
| Bible text | Bible API (api.bible / scripture.api.bible) |
| Chat moderation | OpenAI Moderation API (free tier) |
| Email | Resend |
| Push | APNS direct |
| Error tracking | Sentry |
| Product analytics | PostHog |

---

## Conventions

- Tables: `snake_case`, plural (`youth_groups`, `plan_days`).
- Columns: `snake_case`. Always include `created_at` and `updated_at` (with trigger).
- All IDs: `uuid` with `gen_random_uuid()` default.
- Soft delete via `deleted_at` (nullable `timestamptz`); hard delete only via admin.
- **RLS on every user-data table — no exceptions.**
- RLS policy names: `{select|insert|update|delete}_{role}_{descriptor}`, e.g. `select_pastor_own_group_members`.
- Helper SQL functions for repeated permission checks: `is_admin()`, `has_role(text)`, `is_parent_of(uuid)`, `is_pastor_of_group(uuid)`, `is_leader_of_member(uuid)`, `is_pro(uuid)`.
- Edge Functions: kebab-case, one per concern, in `supabase/functions/{name}/index.ts`.
- Migrations: timestamp-prefixed, descriptive (`20250115120000_create_profiles.sql`). Idempotent where possible.
- All money in cents (`bigint`), with a `currency` column on every monetary table.
- All timestamps `timestamptz`. Never `timestamp without timezone`.
- Generated TypeScript types committed at `supabase/types.ts` after every schema change.

---

## Account types & roles

**Site Admin** — manages everything via the CMS.

**Regular User** — one user can hold multiple roles simultaneously. Stored in a `user_roles` join table:
- `member` (always)
- `parent` (if they have child accounts under them)
- `group_leader` (if a Pastor assigned them to lead a small group)
- `pastor` (if they own a youth group)

A pastor is also a member; a parent might also be a leader. Don't model roles as a single column — use `user_roles`.

---

## Entitlement tiers (CRITICAL — read carefully)

There are four user-facing tiers. These are **derived**, not stored as a column. Compute them via the canonical `is_pro()` and `get_my_entitlements()` functions.

### 1. Free Member
- Access to **Plan 1 only (Book of John)**.
- Auto-joined to the default YGTeeV youth group at signup.
- Starts with `water = 12`, `xp = 2000`.
- Cannot create plans or events.

### 2. Pro Member
- Free + access to **all plans**.
- Achieved by **either**:
  - Active iOS IAP subscription via Apple StoreKit (slider $0.99–$4.99/mo, registered in App Store Connect as 5 discrete subscription products in one group), **OR**
  - Membership in any youth group **other than the default YGTeeV group**.
- The youth-group-grants-Pro rule is core: the moment a user joins a real church's youth group, they unlock everything for free. The moment they leave, they revert to Free unless they have their own Apple subscription.
- "Member of" here means a row in `youth_group_members` exists. The 90-day "active" definition is for **billing the pastor**, not for entitlements.

### 3. Pastor — Basic Plan
- Owns and runs a youth group, creates small groups, assigns leaders.
- **Tiered per-active-user billing** (active = `last_opened_at >= now() - interval '90 days'`):
  - 1–19, 20–49, 50–99, 100–149, 150–199, 200+ users
  - Prices TBD — store in `subscription_tiers` table for easy edits, never hardcode.
- **Cannot** create custom plans or events.
- Charged via **Stripe**, purchased on the CMS.

### 4. Pastor — Plus Plan
- Everything in Basic.
- **$25/mo flat + the same per-active-user tier on top.**
- **Can** create custom Bible plans (scoped to their youth group only).
- **Can** create events (public or group-private).

### Parent (orthogonal to tiers)
- Account itself is free.
- To add a child (under 13), parent pays **$0.99 one-time IAP per child** via Apple StoreKit.
- Child's account linked via `parent_account_id` on `profiles`.
- Parent has read access to their children's game stats.
- Parent auto-subscribed to the "parent chat" thread for each youth group their child is in.

---

## Canonical entitlement function

Implement once, use everywhere. iOS client never computes this — it calls the RPC.

```sql
create or replace function is_pro(uid uuid)
returns boolean
language sql stable security definer as $$
  select
    exists (
      select 1 from apple_subscriptions
      where user_id = uid
        and status in ('active', 'in_grace')
        and expires_at > now()
    )
    or
    exists (
      select 1 from youth_group_members ygm
      join youth_groups yg on yg.id = ygm.youth_group_id
      where ygm.user_id = uid
        and yg.is_default_ygteev = false
    );
$$;
```

`get_my_entitlements()` returns a record like `{ is_pro, can_create_plans, can_create_events, can_run_youth_group, ... }`. The iOS client calls this on every cold start and after any subscription/membership change.

---

## Critical business rules

1. **Under-13 protection (COPPA-adjacent)**
   - `profiles` has a CHECK constraint: under-13 birthdates require a non-null `parent_account_id`.
   - Under-13 accounts MUST NOT appear on the public map.
   - Under-13 accounts MUST NOT appear in public youth group listings.
   - Site admin can bypass these for moderation only.

2. **Default YGTeeV group**
   - Seed row with `is_default_ygteev = true`. Enforce uniqueness with a partial unique index.
   - Every new signup is auto-inserted via trigger.
   - This group does NOT grant Pro (per the Pro rules above).

3. **StoreKit receipt validation — server-side, always**
   - Client sends signed transaction JWS to `validate-storekit-receipt` Edge Function.
   - Function verifies with Apple's App Store Server API, then writes/updates `apple_subscriptions` or `apple_purchases`.
   - Client trusts ONLY what comes back from the Edge Function.
   - Apple Server Notifications V2 hit `apple-server-notifications` Edge Function for renewals/cancellations.

4. **Chat moderation — runs on everyone**
   - Every `messages` insert routes through `moderate-message` Edge Function first.
   - Flagged messages stored with `moderation_status = 'flagged'` and surfaced to the responsible moderator: small group → leader; youth group → pastor; default group → site admin.
   - Pastors and admins are NOT exempt.

5. **Active user tracking (for pastor billing)**
   - `last_opened_at` on `profiles`.
   - Updated via RPC `heartbeat()` from iOS, debounced client-side to once per app foreground.
   - Monthly cron `sync-pastor-billing` counts users with `last_opened_at >= now() - interval '90 days'` per group, reports metered usage to Stripe.

6. **Chat threads — fixed model, no DMs between members**
   When a user joins a youth group + small group, they're auto-subscribed to:
   1. Main youth group thread
   2. 1:1 with the pastor
   3. 1:1 with the small group leader
   4. Small group thread

   Parents additionally get: "parent chat" thread (parents + pastor + leaders).

   **No other thread types. Do not build member-to-member DMs.**

7. **Bible content**
   - Bible verse text is sourced from the Bible API at request time. Cached API responses (TTL'd in `bible_cache`) are fine. Don't model verses as first-class content in our schema — references only on `plan_days` / `plan_day_steps`.
   - `get-bible-passage` Edge Function calls Bible API and caches responses in `bible_cache` (key = translation + reference, TTL = 30 days).
   - Default translation TBD — hold a `translation_id` column on plans.

8. **Free tier book gate**
   - Plan 1 (Book of John) is the free entry point.
   - All other plans require `is_pro()` to start.
   - Enforced server-side in `start_plan()` RPC, not client-side.

9. **Youth group activation gate**
   - `youth_groups.plan_type` is nullable; NULL means no active subscription.
   - Groups with `plan_type IS NULL` are not visible on the public map and cannot host events.
   - Stripe webhook flips this on successful checkout.

---

## Data domains (full schemas in `docs/schema.md`)

1. **Identity** — `profiles`, `user_roles`.
2. **Plans** — `bible_plans`, `plan_days`, `plan_day_steps`, `user_plan_progress`, `bible_cache`.
3. **Gamification** — `user_currencies`, `point_rules`, `store_items`, `user_inventory`, `user_garden`.
4. **Groups** — `youth_groups`, `small_groups`, `youth_group_members`, `small_group_members`, `group_invites`.
5. **Chat** — `chat_threads`, `thread_subscribers`, `messages`, `message_reports`.
6. **Content** — `videos`, `video_engagement`, `events`, `event_rsvps`, `user_feed_cache`.
7. **Billing** — `subscription_tiers`, `apple_subscriptions`, `apple_purchases`, `stripe_subscriptions`, `usage_records`, `audit_log`.

---

## Edge Functions (one per concern)

- `validate-storekit-receipt` — verifies + persists Apple IAP/sub.
- `apple-server-notifications` — handles Apple's webhook (renewals, cancels, refunds).
- `stripe-webhook` — pastor subscription state changes.
- `sync-pastor-billing` — monthly cron: count active users + report usage to Stripe.
- `moderate-message` — OpenAI moderation pre-insert hook.
- `get-bible-passage` — proxy + cache for Bible API.
- `mux-webhook` — handles Mux `video.asset.ready` and related events.
- `claim-group-invite` — validates QR/signed invite token, inserts membership.
- `compute-feed` — generates `user_feed_cache` rows (scheduled + on-demand).
- `add-child-account` — validates kid-IAP receipt, creates child profile.

---

## RPCs (SECURITY DEFINER)

These run inside Postgres (no Edge Function hop) and are the iOS client's primary surface for sensitive reads/writes.

- `get_my_entitlements()` — single source of truth for what the current user can do. iOS calls this on cold start and after any subscription/membership change.
- `heartbeat()` — updates `last_opened_at = now()` for `auth.uid()`. Debounced client-side to once per app foreground.

---

## Secrets (set in Supabase dashboard, never committed)

- `APPLE_SHARED_SECRET`, `APPLE_BUNDLE_ID`, `APPLE_KEY_ID`, `APPLE_ISSUER_ID`, `APPLE_PRIVATE_KEY` (for App Store Server API)
- `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`
- `OPENAI_API_KEY`
- `BIBLE_API_KEY`
- `MUX_TOKEN_ID`, `MUX_TOKEN_SECRET`, `MUX_WEBHOOK_SECRET`
- `RESEND_API_KEY`
- `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_KEY_P8` (base64), `APNS_BUNDLE_ID`

---

## Non-goals / what NOT to do

- ❌ Do not use Stripe for iOS-side digital purchases. Apple requires StoreKit. Stripe is ONLY for pastor subscriptions on the Lovable CMS web flow.
- ❌ Do not build member-to-member DMs.
- ❌ Do not store Bible verse text.
- ❌ Do not compute entitlements client-side.
- ❌ Do not skip moderation for any role.
- ❌ Do not use the `service_role` key in Edge Functions unless absolutely necessary; prefer RLS + `auth.uid()`.
- ❌ Do not add columns to `auth.users` — extend via `profiles`.
- ❌ Do not let the iOS client write directly to `user_currencies`, `apple_subscriptions`, `apple_purchases`, `stripe_subscriptions`, `usage_records`, or any billing table — those are server-only via RPCs and Edge Functions.
- ❌ Do not hardcode prices anywhere — read from `subscription_tiers` and `store_items`.

---

## Testing

- After each migration, write a `*.test.sql` exercising RLS as different roles via `set local role` + `set local request.jwt.claims`.
- Edge Functions: Deno tests with mocked external APIs (Apple, Stripe, OpenAI, Bible API, Mux).
- Always run an end-to-end entitlement test after touching billing.
- Before merging: `make test` must pass; `make gen-types` must produce no diff.

---

## When you're unsure

Ask the user. Specifically about:
- Pricing numbers (tier prices, slider tier count)
- Which Bible translation to default to
- Mux upload-policy specifics
- Apple StoreKit product IDs (we'll get these from App Store Connect)
- Whether a behavior should be CMS-configurable vs hardcoded

Don't guess on business rules. Guess fine on naming, formatting, file layout.
