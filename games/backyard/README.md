# YGTeeV Backyard — web app

Cozy 3D garden RPG (three.js r128, pinned) wrapped in a Vite + React shell
wired to the YGTeeV Supabase backend (`by_*` tables/RPCs).

## Develop

```bash
npm install
npm run dev        # http://localhost:5199 (or the port Vite picks)
```

Sign in with any YGTeeV account (email/password) via the dev form, or open
with a token hash like the iOS app does:

```
http://localhost:5199/#at=<access_token>&rt=<refresh_token>
```

## Build

```bash
npm run build      # outputs static site to dist/
```

## Deploy (Vercel — one-time setup ~10 min)

1. `npm i -g vercel` then `vercel login`
2. From this directory: `vercel --prod`
   - Framework preset: **Vite** (auto-detected)
   - Build command: `npm run build` · Output: `dist`
3. In the Vercel dashboard → project → Settings → Domains →
   add `backyard.ygteev.com`
4. In your DNS (wherever ygteev.com lives): add a CNAME
   `backyard` → `cname.vercel-dns.com`
5. Done. Every future deploy is just `vercel --prod` from this folder.

Netlify / Cloudflare Pages work identically (static `dist/` + custom domain).

## Environment

`.env` holds the **prod** Supabase URL + publishable anon key (safe in
client bundles). For a staging build, swap both values to the
ygteev-staging project and rebuild.

## Architecture notes

- `src/main.jsx` — boot: session (hash handoff → persisted → dev form),
  installs `window.storage`, `window.YGTEEV_MEMBER`, `window.YGTEEV`
  (profile + memberships), `window.YGTEEV_API`, then dynamically imports
  the game.
- `src/storage.js` — game save-state adapter over the `by_saves` table.
- `src/backend.js` — RPC bridge (`by_spend_xp`, `by_start_quiz`,
  `by_answer_quiz`, `by_plant_rare`, `by_get_plots`, `by_get_league`) +
  realtime plot subscription.
- `src/dragon-garden-quest.jsx` — the game. **three@0.128.0 is pinned;
  do not upgrade** (colors/wind/clouds visibly break on newer three).
- Multi-group users get a garden picker at the bridge; single-group users
  are auto-assigned. Berries are computed server-side from plant
  timestamps (cheat-proof by construction).

<!-- Deployed via GitHub Pages: pushes touching games/backyard/** auto-deploy -->
