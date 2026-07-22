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
- **Sound on the silent switch**: the game keeps a looping silent
  `<audio>` element alive (started on the PLAY tap) which flips the
  page's audio session to media playback — Web Audio then ignores the
  ringer switch. The host app also sets
  `AVAudioSession.setCategory(.playback)`; keep both.

## Environment

`.env` holds the **prod** Supabase URL + publishable anon key (safe in
client bundles — intentionally committed so CI builds need no secrets).
For a staging build, swap both values to the ygteev-staging project.

## Architecture

- `src/main.jsx` — boot: session (hash handoff → persisted → dev form),
  installs `window.storage`, `window.YGTEEV_MEMBER`, `window.YGTEEV`
  (profile + memberships), `window.YGTEEV_API`, then dynamically imports
  the game. `createRoot` is HMR-guarded.
- `src/storage.js` — save-state adapter over the `by_saves` table. Keys:
  `garden-state` (inventory, gold, home plots + harvest counts with
  wall-clock timers, dragon fullness), `garden-outfit`, `garden-build`,
  `garden-intro`, `garden-youthgroup`, `grace-garden-week`.
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
| Persistence | Full game state saved to `by_saves` (`garden-state`): change-driven autosave (~4s check) + flush on background/close. Plot timers are wall-clock anchored, so plants keep growing/regrowing while the game is closed |
| Eli's quiz | 3 questions from Bible-plan content the player has completed ("second exposure"), fallback to the basic pool. Freshness is a soft preference (fresh plan → fresh basic → repeats) so heavy players never hit "not enough questions". Served without answers; graded server-side one answer at a time. Early pass/fail auto-submits filler answers so the server attempt always completes |
| Rare planting | Requires a passed, unconsumed, <15-min-old quiz attempt (`by_plant_rare`). Seed refunds if the plot was taken |
| Community plots | Shared per youth group — loaded via `by_get_plots`, realtime-synced; groupmates' plants appear live |
| Live groupmates | Community garden only: presence + ~8 Hz position broadcasts on the private channel `by:garden:{group_id}` (membership-gated RLS on `realtime.messages`); groupmates appear with their real outfit + name tag and animate as they walk |
| Garden League | Real weekly standings via `by_get_league` (60s poll). Berries are computed **server-side from plant timestamps** — clients never report berry counts (cheat-proof by construction). One global board with a **size-fairness multiplier** (`min(max_active/active, 3.0)`, active = members w/ 90-day `last_opened_at`) stored on `by_league_weeks` and refreshed by the 5-min berry cron — never computed per read. HUD shows a live "N today" pulse pill (`by_garden_pulse`); tapping it opens the dedicated dark League Board view (hero stats card, fairness chips, rank-movement arrows) |
| Multi-group | Users in 2+ youth groups pick their garden at the bridge (parchment picker); single-group users auto-assigned. Map label, bridge label, and chapel sign all show the real group name |
| Red bags | 3 hidden Bible-question pouches per player per UTC day on the HOME map (`by_get_red_bags` on boot + 5-min re-poll — a midnight rollover respawns fresh bags mid-session). The server picks 3 of the client's 12 hiding spots (grass/woods, clear of road/garden/cave/river) and pre-rolls each reward (gold 1/3/5/10 or XP 5/10/15/25/50, uniform over 9 outcomes). Tap → `by_open_red_bag` returns the question (level-matched server-side: grades 6–8 get middle-school questions, everyone else high school; 200-question bank per level in `by_bag_questions`). One attempt, no retry — `by_answer_red_bag` grades once, reveals the correct answer on a miss, and the bag is consumed either way. Correct + gold → applied client-side into the garden save; correct + XP → granted server-side (`profiles.xp` + `user_xp_grants` source `red_bag`), HUD set from returned `total_xp` |

### Home garden economy (current tuning)

| Seed | Cost | Grow | Regrow | Yield | Sell |
|---|---|---|---|---|---|
| Strawberry | 50 XP | 20s | 3:00 | 2 fruit × 3 harvests | 6g |
| Blueberry | 120 XP | 30s | 5:00 | 2 × 3 | 15g |
| Sunfruit | 300 XP | 45s | 8:00 | 2 × 3 | 45g |
| Glowberry | 120 gold | — | — | church plots only, quiz-gated | league berries |

After the third harvest the plant is spent and the plot frees up. A
floating pill over each regrowing plant shows the countdown. Glowberry
ripenings credit **group berries only** — no personal gold (gold enters
the game exclusively by selling home-grown fruit). Entering the
community garden auto-selects the glowberry seed.

### Ember the dragon

The in-game dragon is the "lab v3" design: black lathed hide, red
segmented belly plates + wing membranes, purple horns/brows/spikes/
claws, mismatched googly white eyes, articulated jaw/tongue/eyelids.
Hunger drives him (drains only while the game is open; restored on load
**exactly** — quit with a starving Ember and he's still starving, and
acts on it immediately): full ≥72 → sleeps
(snore audio fades in when near), <62 → wakes with a yawn stretch,
<30 → hangry (brows slam, eyes burn, fast flaps). At 0, **eating is the
only thing that refills him**:

- Garden has plants → rampage: charges a random planted plot, eats it
  (chomp audio), runs home refilled.
- Garden empty → **prowl**: he leaves the cave and patrols a fixed loop
  around the meadow and house, angry, with a crazy spin-and-hop burst
  every ~6–11s — **forever, until fed**. The feed prompt follows his
  live position ("Ember is hangry — offer him a berry!"), and planting
  anything while he prowls makes him charge and eat it immediately.
  Feeding him one fruit ends the prowl and he runs back to his cave.

Feeding him fruit restores fullness + a happy wiggle.

**Design playground:** `/dragon-lab.html` (same URL base) — standalone
page with the full rig and 8 test states (Standing/Sleeping/Waking/
Running/Angry/Crazy/Rampage/Eating). Iterate there, then port winning
changes into `makeDragon()`/`updateDragon()` in the game file.

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
(`backyard_phase1_schema_and_rpcs`) for the full schema. The community
garden field is 18×18 = 324 plots (`by_plots.plot_idx < 324`).

## Live ops notes

- **Grant XP**: update `profiles.xp` (+ `lifetime_xp`) and log to
  `user_xp_grants` with source `admin_grant` so leaderboards stay
  consistent.
- **Grant gold**: gold lives in the player's `by_saves` `garden-state`
  JSON — `jsonb_set` the `gold` key. ⚠️ An OPEN game session overwrites
  the save on close/autosave: the player must force-quit BEFORE the
  grant, then reopen.
- **Question pool**: Eli draws from the player's completed plan days +
  `by_basic_questions` (24 rows). Freshness is best-effort; grow the
  basic pool if brand-new players see repeats too often.
- **Versions**: every game version is a git commit touching
  `games/backyard/` — check out any hash and push to redeploy. An
  on-demand snapshot function (`backup-backyard`) can copy the live
  build + source into the private `backups` bucket.
