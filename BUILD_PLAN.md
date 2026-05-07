# YGTeeV Backend — Build Plan

Phased plan to feed Claude Code one chunk at a time. Each phase ends in something testable. **Don't move on until the previous phase passes its acceptance checks.** Copy each phase's prompt into Claude Code as a fresh task.

> Always start a Claude Code session with: *"Read CLAUDE.md before doing anything else. Then: [paste phase prompt]."*

---

## Phase 0 — Project setup

**Goal:** Empty Supabase project, local dev working, conventions in place.

**Prompt:**

> Read CLAUDE.md. Then:
> 1. Initialize the Supabase project structure: `supabase/migrations/`, `supabase/functions/`, `supabase/seed/`, `docs/`.
> 2. Create empty placeholder files: `docs/schema.md`, `docs/rls-policies.md`, `docs/edge-functions.md`.
> 3. Add a `Makefile` with targets: `dev` (start local Supabase), `migrate`, `reset` (db reset + reseed), `gen-types` (TS types to `supabase/types.ts`), `test` (run all SQL + Deno tests).
> 4. First migration `00000000000000_extensions.sql`: enable `pgcrypto`, `postgis`, `pg_cron`, `vault`, `uuid-ossp`.
> 5. Second migration `00000000000001_helpers.sql`: the generic `set_updated_at()` trigger function. Stub `is_admin()`, `has_role(text)`, `is_pro(uuid)` returning false (will be filled in later phases).
> 6. `.env.example` listing every secret from CLAUDE.md.
> 7. Commit a `README.md` explaining how to run locally.
>
> Do NOT add business tables yet.

**Acceptance:** `make dev` runs, `make migrate` applies cleanly, `select is_pro(gen_random_uuid())` returns false.

---

## Phase 1 — Identity, roles, parent linkage

**Goal:** Signup creates a profile + starter row + default role; under-13 enforcement; parent can add a child.

**Prompt:**

> Read CLAUDE.md. Build the identity layer.
>
> Migration: `profiles` table with `id` referencing `auth.users` (cascade delete), `display_name`, `avatar_url`, `birthdate`, `parent_account_id` (self-FK), `last_opened_at`, `home_group_id` (nullable, set later), standard `created_at`/`updated_at`/`deleted_at`. Add a CHECK constraint: under-13 birthdates require non-null `parent_account_id`. RLS: select own; select if parent of (use `is_parent_of()`); select if `is_admin()`; update own (whitelist: `display_name`, `avatar_url`); admin can update anything.
>
> Migration: `user_roles` (`user_id`, `role` text-checked in `('site_admin','member','parent','group_leader','pastor')`, `assigned_at`, PK on both columns). RLS: select own; select if admin; insert/delete only via security-definer functions (no direct client writes).
>
> Migration: implement helper functions properly now: `is_admin()`, `has_role(_role text)`, `is_parent_of(_child uuid)`. Make them `security definer`, set `search_path = public`.
>
> Migration: trigger on `auth.users` insert that creates the matching `profiles` row + a `user_roles` row with `role = 'member'`. Leave a comment placeholder for the `user_currencies` insert (Phase 2 will add it).
>
> Edge Function `add-child-account`:
> - Authenticated parent calls it with a StoreKit transaction JWS for the $0.99 kid IAP.
> - **Require non-empty `transaction_jws` input; reject with 400 if missing or empty.**
> - Stub the Apple verification (return `true` if the JWS is present, with a TODO) — Phase 8 implements real validation.
> - Creates `auth.users` for the child (use admin API), inserts profile with `parent_account_id = caller`, adds `parent` role to caller if missing.
> - Returns the new child's id.
>
> Tests (`supabase/migrations/tests/01_identity.test.sql`):
> - Adult signup → profile + member role exist.
> - Under-13 signup with no parent → reject.
> - Under-13 signup linked to adult → succeed.
> - Adult can SELECT child profile; unrelated user cannot.

**Acceptance:** All tests pass. Manual signup creates a clean profile.

---

## Phase 2 — Gamification core

**Goal:** Server-validated currency, store, garden growth.

**Prompt:**

> Read CLAUDE.md. Build the gamification layer.
>
> Tables:
> - `user_currencies` (`user_id` PK FK, `water int default 0`, `xp int default 0`, `streak_count int default 0`, `streak_last_active_date date`). RLS select own / admin. **No direct client writes** — only via SECURITY DEFINER RPCs.
> - `point_rules` (`id`, `action_type text unique`, `water_reward int`, `xp_reward int`, `is_active bool`, `notes text`). Public read; admin write.
> - `store_items` (`id`, `name`, `type text`, `price_xp int`, `asset_url`, `growth_curve jsonb`, `is_active bool`, `sort_order int`). Public read; admin write. `growth_curve` is an array like `[{stage:0, water_required:0}, {stage:1, water_required:5}, ...]`.
> - `user_inventory` (`id`, `user_id`, `store_item_id`, `acquired_at`).
> - `user_garden` (`id`, `user_id`, `store_item_id`, `planted_at`, `water_applied int default 0`, `current_growth_stage int default 0`, `last_watered_at`, `position int`).
>
> RPCs (SECURITY DEFINER, callable by `authenticated`):
> - `award_points(_action_type text, _idempotency_key text)` — looks up active rule, increments `user_currencies` for `auth.uid()`, returns new balances. Use the idempotency key + action type as a unique row in an `awarded_points_log` table to prevent double-awarding (e.g., same plan-step completed twice).
> - `purchase_store_item(_item_id uuid)` — checks XP balance, deducts, inserts inventory.
> - `plant_item(_inventory_id uuid, _position int)` — moves from inventory to garden.
> - `water_plant(_garden_id uuid, _amount int)` — checks water, deducts, increments `water_applied`, recomputes `current_growth_stage` from item's `growth_curve`.
> - `update_streak()` — call when user completes first plan-step of the day. If `streak_last_active_date = today - 1`, increment. If `= today`, no-op. Else reset to 1.
>
> Update the auth-user trigger from Phase 1: insert into `user_currencies` with `water=12, xp=2000`.
>
> Seed `point_rules` with placeholder rows (zero values) for every `action_type` we'll wire up later: `complete_plan_step`, `complete_plan_day`, `complete_plan_book`, `daily_streak_continued`, `streak_milestone_7`, `streak_milestone_30`, `streak_milestone_100`. Admin will tune values via CMS.
>
> Tests: idempotency on `award_points`, store purchase fails when XP insufficient, plant grows correctly through stages.

**Acceptance:** SQL test suite green. Manual flow: new user → has 12 water + 2000 XP → buys plant → plants it → waters it → growth stage advances.

---

## Phase 3 — Bible plans + progress

**Goal:** Admin can create plans in the CMS; users complete them; the John gate works.

**Prompt:**

> Read CLAUDE.md. Build the Bible plan system.
>
> Tables:
> - `bible_plans` (`id`, `book text`, `chapter_start int`, `chapter_end int`, `title`, `description`, `cover_image_url`, `translation_id text`, `created_by uuid`, `scope text check in ('global','youth_group')`, `youth_group_id uuid` nullable (required if scope=youth_group), `is_published bool`, `is_free_tier bool` — true only for the John plan, `sort_order int`). Public read of published; insert allowed only if `is_admin()` (no pastor branch yet — Phase 9 extends this).
> - `plan_days` (`id`, `plan_id`, `day_number int`, `chapter_reference text`, `title`).
> - `plan_day_steps` (`id`, `plan_day_id`, `step_order int 1-6`, `step_type text check in ('read','reflect','quiz','video','prayer','journal')`, `content jsonb`, `xp_reward int`, `water_reward int`). The `content` shape varies by `step_type` — document the schema for each in `docs/schema.md`.
> - `user_plan_progress` (`id`, `user_id`, `plan_id`, `plan_day_id`, `step_id`, `completed_at`). Unique index on `(user_id, step_id)`.
> - `bible_cache` (`id`, `cache_key text unique` — format `{translation}:{reference}`, `payload jsonb`, `fetched_at`, `expires_at`). Public read; only Edge Function writes.
>
> RPCs:
> - `start_plan(_plan_id uuid)` — checks: plan is published, AND (plan is `is_free_tier` OR `is_pro(auth.uid())`). Returns plan + first day. Reject otherwise with a clear error code (`PRO_REQUIRED`).
> - `complete_step(_step_id uuid)` — inserts into `user_plan_progress` (idempotent), then calls `award_points` with the step's rewards, then if all steps for that day are done also award `complete_plan_day`, then if all days done award `complete_plan_book`, then `update_streak()`.
>
> Edge Function `get-bible-passage`:
> - Input: `{translation, reference}`.
> - Check `bible_cache` for fresh entry (`expires_at > now()`).
> - If miss, fetch from Bible API, store with 30-day TTL.
> - Return passage text.
>
> Seed: insert the John plan as `is_free_tier = true, scope = 'global'`. Create one sample plan_day with 6 placeholder steps so the iOS team can integrate.
>
> Tests: Free user can `start_plan` for John. Free user gets `PRO_REQUIRED` for any other plan. Pro user (mock subscription) can start any plan. Completing all 6 steps of a day awards day completion bonus exactly once.

**Acceptance:** Free/Pro gating works. Full plan completion awards correct points.

---

## Phase 4 — Youth groups, small groups, map

**Goal:** Pastors can run groups; users can join via QR; map search works.

**Prompt:**

> Read CLAUDE.md. Build the group system.
>
> Tables:
> - `youth_groups` (`id`, `name`, `description`, `church_name`, `location geography(point,4326)`, `address text`, `cover_image_url`, `is_public bool`, `is_default_ygteev bool`, `owner_id uuid` — the pastor, `stripe_subscription_id text`, `plan_type text` nullable (default NULL, CHECK in `('basic','plus')` when not null), `is_active bool` generated as `(plan_type IS NOT NULL) STORED`, `created_at`, `updated_at`, `deleted_at`). Partial unique index `where is_default_ygteev = true` to enforce one default group. (Note: the default YGTeeV group is the one exception — seed it with a non-null `plan_type` so it stays visible.)
> - `small_groups` (`id`, `youth_group_id`, `name`, `leader_id uuid`).
> - `youth_group_members` (`youth_group_id`, `user_id`, `joined_at`, PK on both).
> - `small_group_members` (`small_group_id`, `user_id`, `joined_at`, PK on both).
> - `group_invites` (`id`, `youth_group_id`, `code text unique`, `signed_token text`, `created_by`, `expires_at`, `max_uses int`, `used_count int`).
>
> Helper functions: `is_pastor_of_group(uuid)`, `is_leader_of_group(uuid)`, `is_member_of_group(uuid)`, `is_leader_of_member(uuid)` (true if `auth.uid()` leads a small group containing the given user).
>
> RLS:
> - `youth_groups`: public select where `is_public = true AND plan_type IS NOT NULL` (public-map gate); pastor select own; admin all. Update only by owner pastor or admin.
> - `youth_group_members`: select if member of same group, or pastor of group, or admin. Insert via RPC only.
> - `small_groups`/`small_group_members`: scoped reads; only pastor or assigned leader can manage members.
>
> RPCs:
> - `create_youth_group(...)` — for a user with `pastor` role; creates group, sets `owner_id`. (Subscription created separately in Phase 8.)
> - `add_member_to_youth_group(_group_id, _user_id)` — pastor or admin only.
> - `remove_member(_group_id, _user_id)` — pastor or admin only; on remove, also clean up `small_group_members` and `thread_subscribers` rows.
> - `assign_small_group_leader(_small_group_id, _user_id)` — adds `group_leader` role to user if missing.
>
> Edge Functions:
> - `claim-group-invite` — input: signed token. Verifies signature + expiry + usage cap, inserts membership, returns group info.
> - `generate-group-invite` — pastor-only; returns `{code, signed_token, qr_payload}`.
>
> Update Phase 1's auth.users trigger to also insert the new user into the default YGTeeV group's `youth_group_members`. Make this defensive: `SELECT id FROM youth_groups WHERE is_default_ygteev = true LIMIT 1` — if not found, skip the membership insert and log a warning. Don't fail signup.
>
> Seed: insert the default YGTeeV group with `is_default_ygteev = true` and a system-account owner (create a system user via the admin API in the seed script if needed).
>
> Extend `is_pro()` to include the youth-group branch only. The Apple-subscription branch is added in Phase 8 when `apple_subscriptions` exists.
>
> Map search RPC: `search_groups_near(_lat float, _lng float, _radius_meters int)` — returns public groups within radius using `ST_DWithin`. Excludes under-13 user counts; only returns groups themselves.
>
> Tests: User signs up → joins default group → `is_pro()` still false. User joins a non-default group → `is_pro()` true. Pastor can manage their group; non-owner pastor cannot.

**Acceptance:** Default group seed exists. Map search returns expected results. Pro entitlement flips correctly on group join/leave.

---

## Phase 5 — Chat (with moderation)

**Goal:** Four thread types auto-subscribe; messages get moderated; realtime works.

**Prompt:**

> Read CLAUDE.md. Build chat.
>
> Tables:
> - `chat_threads` (`id`, `type text check in ('main_yg','pastor_dm','leader_dm','small_group','parent_chat')`, `youth_group_id`, `small_group_id` nullable, `pastor_id` nullable, `leader_id` nullable, `member_id` nullable, `created_at`). The nullable cols vary by type — add a CHECK that enforces required cols per type.
> - `thread_subscribers` (`thread_id`, `user_id`, `subscribed_at`, `last_read_at`, PK on first two).
> - `messages` (`id`, `thread_id`, `sender_id`, `body text`, `created_at`, `moderation_status text check in ('pending','approved','flagged')`, `moderation_categories jsonb`, `is_deleted bool`).
> - `message_reports` (`id`, `message_id`, `reporter_id`, `reason text`, `status text`, `resolved_by`, `resolved_at`).
>
> RLS: select messages only if subscribed to the thread. Insert messages only via the `send-message` Edge Function (RLS denies direct INSERT — clients must use the function).
>
> Edge Function `send-message`:
> - Auth check: caller must be subscribed to the target thread.
> - Call OpenAI Moderation API (free) with the message body.
> - If flagged: insert with `moderation_status = 'flagged'` and create a moderation queue entry visible to the appropriate moderator. Don't surface to other users.
> - If clean: insert with `moderation_status = 'approved'`.
> - Send realtime notification + APNS push to other subscribers.
>
> Auto-subscription logic (trigger or RPC) when membership changes:
> - On `youth_group_members` insert: subscribe user to `main_yg` thread + `pastor_dm` (creating if needed).
> - On `small_group_members` insert: subscribe user to `small_group` thread + `leader_dm` (creating if needed).
> - On parent linked to a child whose youth group is X: subscribe parent to the `parent_chat` thread for group X.
> - On any membership removal: unsubscribe from corresponding threads.
>
> RPC `mark_thread_read(_thread_id)` — updates `last_read_at`.
>
> Tests: User in small group is subscribed to all 4 expected threads. Sending a flagged message (use a known-bad test phrase) results in `moderation_status = 'flagged'` and is not visible to other subscribers. Realtime channel filtered by `thread_id` works.

**Acceptance:** Four thread types auto-wire on join. Moderation runs on every message. Realtime delivers to subscribers only.

---

## Phase 6 — Video feed (Mux) + algorithm

**Goal:** Home feed served from cache, updated on engagement.

**Prompt:**

> Read CLAUDE.md. Build video.
>
> Tables:
> - `videos` (`id`, `mux_asset_id`, `mux_playback_id`, `title`, `description`, `duration_seconds`, `thumbnail_url`, `tags text[]`, `scope text check in ('global','youth_group')`, `youth_group_id` nullable, `uploaded_by`, `is_published bool`, `created_at`).
> - `video_engagement` (`video_id`, `user_id`, `watched_seconds int`, `completed bool`, `liked bool`, `last_watched_at`, PK on first two).
> - `user_feed_cache` (`id`, `user_id`, `video_id`, `score float`, `position int`, `generated_at`).
>
> Edge Function `mux-webhook`:
> - Verify Mux signature.
> - On `video.asset.ready`: update `videos` with `mux_playback_id`, `duration_seconds`, `thumbnail_url`. Set `is_published` only after admin/pastor approval (don't auto-publish).
> - On `video.asset.errored`: log + flag.
>
> Edge Function `compute-feed`:
> - Inputs: `user_id` (or batch).
> - For each candidate video (published, scope global OR scope youth_group AND user is member):
>   - `recency = 1 / (1 + days_since_created)`
>   - `engagement = (likes + completions) / log(views + 2)`  (use coalesce so new videos don't crash)
>   - `youth_group_match = 1 if video's youth_group_id matches a group the user is in, else 0`
>   - `score = 0.4*recency + 0.4*engagement + 0.2*youth_group_match`
> - Apply diversity rule: same `uploaded_by` cannot appear twice in any 5-video window.
> - Insert top N (start with 50) into `user_feed_cache` with `position` 1..N. Replace prior cache for that user.
>
> RPC `get_my_feed(_limit int, _offset int)` — reads from `user_feed_cache`, joins to `videos`, returns playback info.
>
> Cron: schedule `compute-feed` every 6 hours for all users active in last 30 days. Also call on-demand after a user likes/completes 3+ videos in a session (debounced).
>
> RPC `record_engagement(_video_id, _watched_seconds, _completed, _liked)` — upserts `video_engagement`.
>
> Tests: Feed excludes private youth-group videos for non-members. Diversity rule holds. Free users get global content only (no Pro gating on videos themselves — videos are free for everyone, the gate is only on plans).

**Acceptance:** Cron populates feeds. Manual call generates fresh feed. Algorithm respects scope rules.

---

## Phase 7 — Events + RSVPs

**Goal:** Plus-plan pastors create events; users RSVP; RSVPs visible to pastor.

**Prompt:**

> Read CLAUDE.md. Build events.
>
> Tables:
> - `events` (`id`, `youth_group_id`, `created_by`, `title`, `description`, `starts_at`, `ends_at`, `location_text`, `location_geo geography(point,4326)` nullable, `is_public bool`, `cover_image_url`, `created_at`, `updated_at`, `deleted_at`).
> - `event_rsvps` (`event_id`, `user_id`, `status text check in ('going','maybe','declined')`, `responded_at`, PK on first two).
>
> RLS:
> - `events` select: if `is_public = true`, OR member of `youth_group_id`, OR admin.
> - `events` insert: only if caller is `is_pastor_of_group(youth_group_id)` AND that group's `plan_type = 'plus'` (use a helper `is_pastor_plus_of(uuid)`).
> - `events` update/delete: same constraint.
> - `event_rsvps` select: own RSVP, OR pastor of the event's group, OR admin.
> - `event_rsvps` insert/update: own only.
>
> RPC `rsvp_event(_event_id uuid, _status text)` — upserts.
>
> RPC `get_event_rsvps(_event_id uuid)` — pastor-only view: returns counts + list.
>
> Map search: extend Phase 4's geo search to also return upcoming public events nearby.
>
> Tests: Basic-plan pastor cannot insert events. Plus-plan pastor can. Non-member of a private event's group cannot see it.

**Acceptance:** Plan-tier gating works. Pastor sees the right RSVP roster.

---

## Phase 8 — Billing (StoreKit + Stripe)

**Goal:** Real receipt validation, real subscription state, monthly metered billing job.

**Prompt:**

> Read CLAUDE.md. Build the billing layer. **This is the highest-stakes phase — write thorough tests.**
>
> Tables:
> - `subscription_tiers` (`id`, `plan_type text check in ('pastor_basic','pastor_plus')`, `min_users int`, `max_users int`, `monthly_price_cents bigint`, `currency text default 'USD'`, `stripe_price_id text`). Seed with the 6 tiers for Basic and 6 for Plus (12 rows). Admin-editable.
> - `apple_subscriptions` (`id`, `user_id`, `original_transaction_id text unique`, `product_id text`, `price_cents bigint`, `status text check in ('active','expired','in_grace','revoked')`, `current_period_start`, `expires_at`, `auto_renew bool`, `last_verified_at`, `raw_transaction jsonb`).
> - `apple_purchases` (`id`, `user_id`, `transaction_id text unique`, `product_id text`, `price_cents bigint`, `purchased_at`, `raw_transaction jsonb`). For one-time IAPs (kid add).
> - `stripe_subscriptions` (`id`, `youth_group_id`, `stripe_customer_id`, `stripe_subscription_id text unique`, `plan_type text`, `status text`, `current_period_end`, `cancel_at_period_end bool`, `created_at`, `updated_at`).
> - `usage_records` (`id`, `youth_group_id`, `period_start date`, `period_end date`, `active_user_count int`, `tier_id uuid`, `reported_to_stripe_at`, `stripe_usage_record_id`).
> - `audit_log` (`id`, `actor_id`, `action text`, `target_type text`, `target_id uuid`, `payload jsonb`, `created_at`).
>
> Edge Function `validate-storekit-receipt`:
> - Input: signed transaction JWS from client.
> - Verify with Apple App Store Server API (use the JWT auth flow with `APPLE_KEY_ID`/`APPLE_ISSUER_ID`/`APPLE_PRIVATE_KEY`).
> - Determine product type:
>   - Pro subscription products (5 SKUs for the slider) → upsert `apple_subscriptions`.
>   - Kid-add IAP product → insert `apple_purchases` AND mark the parent's pending child-add as paid (this links to Phase 1's `add-child-account`).
> - Return refreshed entitlements via `get_my_entitlements()`.
>
> Edge Function `apple-server-notifications`:
> - Verify Apple's signed payload.
> - Handle `DID_RENEW`, `EXPIRED`, `REVOKE`, `REFUND`, `DID_CHANGE_RENEWAL_STATUS`.
> - Update `apple_subscriptions` accordingly.
>
> Edge Function `stripe-webhook`:
> - Verify signature.
> - Handle `customer.subscription.created/updated/deleted`, `invoice.payment_failed`.
> - Sync `stripe_subscriptions` and toggle `youth_groups.plan_type` accordingly.
>
> Edge Function `sync-pastor-billing` (cron, monthly on the 1st):
> - For each `stripe_subscriptions` row with status='active':
>   - Count `youth_group_members` where the linked profile has `last_opened_at >= now() - interval '90 days'`.
>   - Look up the matching tier in `subscription_tiers` for the group's `plan_type` and user count.
>   - Insert `usage_records` row.
>   - Report to Stripe via the Usage Records API (`stripe.subscriptionItems.createUsageRecord`).
>
> RPC `heartbeat()` — updates `last_opened_at = now()` for `auth.uid()`. Lightweight, no return.
>
> Update `is_pro()` and `get_my_entitlements()` to read from real `apple_subscriptions` (drop any stub logic).
>
> Tests:
> - Mock Apple verification: valid JWS → `apple_subscriptions` row created, `is_pro()` true.
> - Subscription expired: `is_pro()` flips false (unless user is in a non-default group).
> - Kid IAP receipt → `add-child-account` flow completes.
> - Mock Stripe webhook for new subscription → `stripe_subscriptions` row created and `youth_groups.plan_type` updated.
> - `sync-pastor-billing` reports correct tier for various user counts (1, 19, 20, 100, 250).

**Acceptance:** End-to-end: a test user buys a Pro sub (mocked) → entitlements update → cancels → entitlements revert. Pastor billing job produces correct usage records for synthetic groups.

---

## Phase 9 — Pastor-created plans (Plus only)

**Goal:** Plus pastors author plans for their group; gated; visible to their members.

**Prompt:**

> Read CLAUDE.md. Wire pastor plan authorship.
>
> Add helper `is_pastor_plus_of(_group_id uuid)` — true if caller is the group's owner AND group's `plan_type = 'plus'`.
>
> Extend the `bible_plans` insert policy from Phase 3 to also allow `is_pastor_plus_of(youth_group_id)` when `scope = 'youth_group'`. (Admin remains allowed.)
>
> Update `bible_plans` select RLS: published global plans visible to all; published youth-group plans visible only to members of that group.
>
> RPC `create_youth_group_plan(...)` — wraps insert with proper validation. Forwards to `plan_days`/`plan_day_steps` inserts via the same call (transactional).
>
> Update `start_plan()` to allow starting a youth-group plan if user is in that youth group (regardless of `is_pro` — being in the group already grants Pro).
>
> Tests: Plus pastor can create plan; Basic pastor cannot. Non-member of the group can't see or start the plan.

**Acceptance:** Plus-tier feature gating verified end-to-end.

---

## Phase 10 — Hardening, observability, polish

**Goal:** Production-ready: rate limits, audit log, error tracking, type generation in CI.

**Prompt:**

> Read CLAUDE.md. Hardening pass.
>
> 1. Add rate limiting on hot Edge Functions (`send-message`, `validate-storekit-receipt`, `heartbeat`, `claim-group-invite`) using a `rate_limits` table keyed by `(user_id, function_name, window_start)`. Return 429 on excess.
> 2. Audit log: trigger-based inserts on every write to `youth_groups`, `bible_plans`, `store_items`, `point_rules`, `user_roles`, `apple_subscriptions`, `stripe_subscriptions`. Capture `actor_id = auth.uid()`, action, before/after diff in `payload`.
> 3. Add Sentry init to every Edge Function (use `SENTRY_DSN` secret). Capture and rethrow.
> 4. Add a `posthog-event` Edge Function the iOS client can call to forward events; backend also fires server-side events (signup, plan_completed, sub_purchased, sub_canceled).
> 5. Generate TypeScript types and commit at `supabase/types.ts`. Add a CI check that fails if `make gen-types` produces a diff.
> 6. Add a `docs/runbook.md` covering: how to rotate secrets, how to pause a user, how to refund a subscription, how to investigate a flagged-message report.
> 7. Add nightly cron `prune-stale-data`: deletes expired `bible_cache`, expired `group_invites`, soft-deleted records older than 90 days.
>
> Tests: Rate limiting trips at the configured threshold. Audit log captures a representative write. Type generation is stable.

**Acceptance:** Production-ready. CI green. Runbook covers the top 5 incident scenarios.

---

## Suggested cadence

- Phases 0–2: foundation, ~1 week
- Phases 3–5: core experience, ~2 weeks
- Phases 6–7: feed + events, ~1 week
- Phase 8: billing, ~1 week (test-heavy)
- Phases 9–10: polish, ~1 week

After Phase 5 you have enough to start integrating with the iOS app for end-to-end testing — don't wait for Phase 10.

---

## Open questions to resolve before starting

1. **Pastor tier prices** — what's the dollar amount per tier for Basic and Plus? (Needed for `subscription_tiers` seed.)
2. **Default Bible translation** — ESV (paid license), CSB (cheap license), KJV/WEB (free public domain), NIV (paid)?
3. **Pro slider granularity** — exactly which discrete prices? Recommend $0.99, $1.99, $2.99, $3.99, $4.99 (5 SKUs).
4. **App Store Connect product IDs** — once registered, drop them in `CLAUDE.md` so Claude Code knows what to validate against.
5. **Apple developer account ready** — keys for App Store Server API generated?
6. **Stripe products** — pre-create the metered subscription products in Stripe dashboard, then add their `price_id` values to the `subscription_tiers` seed.
