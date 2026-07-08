# YGTeeV Backyard — web app

Cozy 3D garden RPG (three.js r128, pinned) wrapped in a Vite + React shell
wired to the YGTeeV Supabase backend (`by_*` tables/RPCs). Live at
**https://backyard.ygteev.com**, embedded in the iOS app via WKWebView.

## Develop

```bash
npm install
npm run dev        # port 5199 (see .claude/launch.json "backyard")
```

Sign in with any YGTeeV account (email/password) via the dev form, or open
with a token hash like the iOS app does:

```
http://localhost:5199/?ios=1#at=<access_token>&rt=<refresh_token>
```

### Dev-only hooks (stripped from production builds)

- `window.__BY_G` — the live engine object (`G`). Useful: `G.inv`,
  `G.activeGarden`, `G.week`, `G.doAction()`, `G.reqGardenPick(opts, ex)`.
- `window.__BY_G.__dev()` — `{ px, pz, prompt }` (player position + active
  prompt type). Used for scripted navigation in preview testing.

## Deploy — GitHub Pages (automatic)

Every push to `main` that touches `games/backyard/**` builds and deploys
via [.github/workflows/deploy-backyard.yml](../../.github/workflows/deploy-backyard.yml).
No CLI, no dashboard — edit, commit, push, live in ~1 minute.

One-time setup already done: Pages enabled (Source: GitHub Actions),
DNS CNAME `backyard` → `screensslayer.github.io`, custom domain bound via
`public/CNAME`. After DNS/cert changes, check Settings → Pages →
Enforce HTTPS is ticked.

## iOS embed contract

The iOS app (`BackyardGameView`, a WKWebView) loads:

```
https://backyard.ygteev.com/?ios=1#at=<access_token>&rt=<refresh_token>
```

- `#at/#rt` — Supabase session handoff. The shell calls
  `auth.setSession()` and immediately scrubs the tokens from the URL.
- `?ios=1` — tells the game it's embedded: the top-left HUD pills shift
  right 56px to clear the app's floating close button.
- **Sound on the silent switch** is controlled by the HOST app, not the
  web page: `BackyardGameView` must set
  `AVAudioSession.setCategory(.playback)` or WKWebView audio mutes with
  the ringer.

## Environment

`.env` holds the **prod** Supabase URL + publishable anon key (safe in
client bundles — intentionally committed so CI builds need no secrets).
For a staging build, swap both values to the ygteev-staging project.

## Architecture

- `src/main.jsx` — boot: session (hash handoff → persisted → dev form),
  installs `window.storage`, `window.YGTEEV_MEMBER`, `window.YGTEEV`
  (profile + memberships), `window.YGTEEV_API`, then dynamically imports
  the game. `createRoot` is HMR-guarded.
- `src/storage.js` — game save-state adapter over the `by_saves` table
  (outfit, build state, intro flag, week cache).
- `src/backend.js` — RPC bridge: `by_spend_xp`, `by_start_quiz`,
  `by_answer_quiz`, `by_plant_rare`, `by_get_plots`, `by_get_league` +
  realtime plot subscription per group.
- `src/dragon-garden-quest.jsx` — the game (~4,700 lines, embedded
  audio/logo). **three@0.128.0 is pinned; do not upgrade** — colors,
  wind, and clouds visibly break on newer three.

### Game ↔ backend integration points (all guarded — game runs standalone without `window.YGTEEV_API`)

| System | How it works |
|---|---|
| XP wallet | Initialized from `profiles.xp`; every purchase optimistically deducts locally then syncs via `by_spend_xp` (auto-refund + toast on server refusal) |
| Eli's quiz | 3 questions from Bible-plan content the player has completed ("second exposure"), fallback to the basic pool. Served without answers; graded server-side one answer at a time. Early pass/fail auto-submits filler answers so the server attempt always completes |
| Rare planting | Requires a passed, unconsumed, <15-min-old quiz attempt (`by_plant_rare`). Seed refunds if the plot was taken |
| Community plots | Shared per youth group — loaded via `by_get_plots`, realtime-synced; groupmates' plants appear live |
| Live groupmates | Community garden only: presence + ~8 Hz position broadcasts on the private channel `by:garden:{group_id}` (membership-gated RLS on `realtime.messages`); groupmates appear with their real outfit + name tag and animate as they walk |
| Garden League | Real weekly standings via `by_get_league` (60s poll). Berries are computed **server-side from plant timestamps** — clients never report berry counts (cheat-proof by construction) |
| Multi-group | Users in 2+ youth groups pick their garden at the bridge (parchment picker); single-group users auto-assigned. Map label, bridge label, and chapel sign all show the real group name |

### Mobile/UX behaviors

- **Safe areas**: HUD elements offset by `env(safe-area-inset-*)`; the 3D
  canvas stays full-bleed (`viewport-fit=cover` in index.html).
- **Tap-to-act**: a short tap (<350ms, <12px movement) on the canvas that
  lands within ~2.6 world-units of the highlighted target triggers the
  action — same as the big button. Taps on UI elements are excluded.
- **Portrait zoom**: the follow camera pulls back 22% when the viewport
  is taller than wide.

## Backend

All game tables/RPCs live in the `by_*` namespace on both Supabase
projects (staging + prod). Berry accrual runs on a 5-minute pg_cron
(`by-accrue-berries`). See the Phase 1 migration
(`backyard_phase1_schema_and_rpcs`) for the full schema.
