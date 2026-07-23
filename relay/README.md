# YGTeeV Backyard position relay

Flat-cost WebSocket relay for the community garden's live-player
position stream. Supabase Realtime bills per message *delivered* and
position broadcasts grow N² with garden size (50 walking players ≈
20,000 deliveries/sec ≈ ~$180/hr); this relay makes that traffic linear
via 10 Hz snapshot ticking and its cost flat (~$2/mo on Fly, near-zero
while gardens are empty thanks to auto-stop). Everything durable —
plots sync, league, chat, saves, auth — stays on Supabase. If the relay
is down, the game auto-falls back to the Supabase Realtime path, so
live avatars degrade gracefully and nothing else is affected.

**Live at `wss://ygteev-relay.fly.dev`** (app `ygteev-relay`, region
`iad`, single shared-cpu-1x 256MB machine, deployed 2026-07-23 under
jim@storybutton.com's personal Fly org). The game's transport selection
lives in `games/backyard/src/backend.js` (`RELAY_URL` — empty string
disables the relay entirely).

## How auth works (no secrets on this box)

On join the client presents its Supabase JWT. The relay:
1. verifies it against `/auth/v1/user` (also pins the claimed player id
   to the token's user id — no impersonation), then
2. calls the `by_member_status` RPC **with the client's own JWT** and
   requires the requested garden to be in the user's memberships.

Env holds only publishable values: `SUPABASE_URL`, `SUPABASE_ANON_KEY`.

## Deploying (Fly.io)

Config is `fly.toml` (auto-stop machine, env baked in — both values are
publishable) + `Dockerfile`. From this directory:

```sh
fly deploy --ha=false     # --ha=false keeps it to ONE machine
```

Deploys are manual (`fly deploy`), not push-triggered. Other useful
commands: `fly logs`, `fly status`, `fly apps restart ygteev-relay`.
Health check: `GET https://ygteev-relay.fly.dev/` returns
`{ ok, rooms, players, uptime_s }`.

The server itself is host-agnostic — any Node host works (Railway:
root dir `relay`, env `SUPABASE_URL` + `SUPABASE_ANON_KEY`, generate a
domain, then point `RELAY_URL` at it).

## Protocol

JSON text frames.

| Direction | Message |
|---|---|
| client → relay | `{ t:"join", gid, token, me:{ id, name, outfit } }` |
| client → relay | `{ t:"pos", i, x, z, a, m }` (≤15/sec accepted; client sends ~8) |
| client → relay | `{ t:"act", i }` |
| relay → client | `{ t:"ack" }` on successful join |
| relay → client | `{ t:"roster", players:[{ id, meta }] }` on any join/leave |
| relay → client | `{ t:"snap", p:[{ i, x, z, a, m }…] }` 10 Hz, movers only; rooms >30 movers get per-client nearest-30 |
| relay → client | `{ t:"act", i }` passthrough |
| relay → client | `{ t:"err", code }` then close (`bad_join`, `unauthorized`, `room_full`) |

Idle rooms tick nothing and empty rooms are deleted, so an idle relay
does ~zero work. Dead sockets are reaped by 30s pings.
