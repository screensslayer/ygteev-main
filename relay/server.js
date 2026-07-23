// YGTeeV Backyard position relay
//
// A flat-cost WebSocket relay for the community garden's live-player
// position stream. Supabase Realtime bills per message DELIVERED, and
// position broadcasts grow N² with garden size; this relay makes that
// traffic linear (snapshot ticking) and its cost flat (one small VM).
// Everything durable — plots, league, chat, saves — stays on Supabase.
//
// Auth holds zero secrets: a joining client presents its Supabase JWT,
// which the relay verifies against /auth/v1/user, then confirms garden
// membership via the by_member_status RPC *using the client's own JWT*
// (RLS does the work). Only publishable values live in env.
//
//   env: SUPABASE_URL, SUPABASE_ANON_KEY, PORT (Railway sets PORT)
//
// Wire protocol (JSON text frames):
//   client → relay:  { t:"join", gid, token, me:{ id, name, outfit } }
//                    { t:"pos", i, x, z, a, m }     (i must equal own id)
//                    { t:"act", i }
//   relay → client:  { t:"ack" }
//                    { t:"roster", players:[{ id, meta }] }   (join/leave)
//                    { t:"snap", p:[{ i, x, z, a, m }, ...] } (10 Hz, movers only)
//                    { t:"act", i }
//                    { t:"err", code }  then close

const http = require("http");
const { WebSocketServer } = require("ws");

const PORT = process.env.PORT || 8080;
const SUPABASE_URL = (process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY || "";

const TICK_MS = 100; // 10 Hz snapshot cadence per room
const SNAP_NEAREST = 30; // above this many movers, each client gets only its nearest
const POS_PER_SEC = 15; // per-client inbound position budget (client sends ~8/s)
const JOIN_TIMEOUT_MS = 10000;
const MAX_MSG_BYTES = 4096;
const MAX_ROOM = 200; // hard sanity cap per garden

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  console.error("Missing SUPABASE_URL / SUPABASE_ANON_KEY env vars");
  process.exit(1);
}

// gid -> { clients: Map<uid, client>, timer }
const rooms = new Map();
const started = Date.now();

async function verifyJoin(token, gid, claimedId) {
  const headers = { apikey: SUPABASE_ANON_KEY, authorization: "Bearer " + token };
  const u = await fetch(SUPABASE_URL + "/auth/v1/user", { headers });
  if (!u.ok) return false;
  const user = await u.json();
  if (!user || !user.id || user.id !== claimedId) return false; // no identity spoofing
  const m = await fetch(SUPABASE_URL + "/rest/v1/rpc/by_member_status", {
    method: "POST",
    headers: { ...headers, "content-type": "application/json" },
    body: "{}",
  });
  if (!m.ok) return false;
  const status = await m.json();
  return ((status && status.memberships) || []).some((x) => x && x.group_id === gid);
}

function roomOf(gid) {
  let room = rooms.get(gid);
  if (!room) {
    room = { clients: new Map(), timer: setInterval(() => tick(room), TICK_MS) };
    rooms.set(gid, room);
  }
  return room;
}

function send(c, obj) {
  if (c.ws.readyState === 1) c.ws.send(JSON.stringify(obj));
}

function broadcastRoster(room) {
  const players = [];
  for (const [id, c] of room.clients) players.push({ id, meta: c.meta });
  const msg = JSON.stringify({ t: "roster", players });
  for (const [, c] of room.clients) if (c.ws.readyState === 1) c.ws.send(msg);
}

function tick(room) {
  const movers = [];
  for (const [, c] of room.clients) {
    if (c.dirty && c.pos) {
      movers.push(c.pos);
      c.dirty = false;
    }
  }
  if (!movers.length) return;
  if (movers.length <= SNAP_NEAREST) {
    const msg = JSON.stringify({ t: "snap", p: movers });
    for (const [, c] of room.clients) if (c.ws.readyState === 1) c.ws.send(msg);
  } else {
    // big-garden mode: every client gets only the movers nearest to it
    for (const [, c] of room.clients) {
      if (c.ws.readyState !== 1) continue;
      const cx = c.pos ? c.pos.x : 0, cz = c.pos ? c.pos.z : 0;
      const nearest = movers
        .map((p) => ({ p, d: (p.x - cx) ** 2 + (p.z - cz) ** 2 }))
        .sort((a, b) => a.d - b.d)
        .slice(0, SNAP_NEAREST)
        .map((e) => e.p);
      c.ws.send(JSON.stringify({ t: "snap", p: nearest }));
    }
  }
}

function leaveRoom(c) {
  const room = rooms.get(c.gid);
  if (!room) return;
  room.clients.delete(c.uid);
  if (room.clients.size === 0) {
    clearInterval(room.timer);
    rooms.delete(c.gid);
  } else {
    broadcastRoster(room);
  }
}

const server = http.createServer((req, res) => {
  let players = 0;
  for (const [, r] of rooms) players += r.clients.size;
  res.writeHead(200, { "content-type": "application/json" });
  res.end(JSON.stringify({ ok: true, rooms: rooms.size, players, uptime_s: Math.round((Date.now() - started) / 1000) }));
});

const wss = new WebSocketServer({ server, maxPayload: MAX_MSG_BYTES });

wss.on("connection", (ws) => {
  const c = { ws, uid: null, gid: null, meta: null, pos: null, dirty: false, posBudget: POS_PER_SEC, alive: true, joined: false };
  const joinTimer = setTimeout(() => { if (!c.joined) ws.close(4008, "join timeout"); }, JOIN_TIMEOUT_MS);
  ws.on("pong", () => { c.alive = true; });

  ws.on("message", async (raw) => {
    let msg;
    try { msg = JSON.parse(raw.toString()); } catch (e) { return; }
    if (!msg || typeof msg !== "object") return;

    if (msg.t === "join" && !c.joined) {
      if (typeof msg.gid !== "string" || typeof msg.token !== "string" || !msg.me || typeof msg.me.id !== "string") {
        send(c, { t: "err", code: "bad_join" }); ws.close(4000); return;
      }
      let ok = false;
      try { ok = await verifyJoin(msg.token, msg.gid, msg.me.id); } catch (e) { ok = false; }
      if (!ok) { send(c, { t: "err", code: "unauthorized" }); ws.close(4001); return; }
      const room = roomOf(msg.gid);
      if (room.clients.size >= MAX_ROOM) { send(c, { t: "err", code: "room_full" }); ws.close(4002); return; }
      const prev = room.clients.get(msg.me.id);
      if (prev) { try { prev.ws.close(4003, "superseded"); } catch (e) {} room.clients.delete(msg.me.id); }
      c.uid = msg.me.id;
      c.gid = msg.gid;
      c.meta = { id: msg.me.id, name: String(msg.me.name || "Gardener").slice(0, 40), outfit: msg.me.outfit || {} };
      c.joined = true;
      clearTimeout(joinTimer);
      room.clients.set(c.uid, c);
      send(c, { t: "ack" });
      broadcastRoster(room);
      return;
    }

    if (!c.joined) return;

    if (msg.t === "pos") {
      if (c.posBudget <= 0) return; // rate-limited at the door
      c.posBudget--;
      c.pos = { i: c.uid, x: +msg.x || 0, z: +msg.z || 0, a: +msg.a || 0, m: !!msg.m };
      c.dirty = true;
    } else if (msg.t === "act") {
      const room = rooms.get(c.gid);
      if (!room) return;
      const out = JSON.stringify({ t: "act", i: c.uid });
      for (const [id, other] of room.clients) {
        if (id !== c.uid && other.ws.readyState === 1) other.ws.send(out);
      }
    }
  });

  ws.on("close", () => { clearTimeout(joinTimer); if (c.joined) leaveRoom(c); });
  ws.on("error", () => { try { ws.close(); } catch (e) {} });
});

// refill inbound rate budgets + drop dead sockets
setInterval(() => {
  for (const [, room] of rooms) {
    for (const [, c] of room.clients) c.posBudget = POS_PER_SEC;
  }
}, 1000);
setInterval(() => {
  for (const ws of wss.clients) {
    const found = findClient(ws);
    if (found && !found.alive) { ws.terminate(); continue; }
    if (found) found.alive = false;
    try { ws.ping(); } catch (e) {}
  }
}, 30000);
function findClient(ws) {
  for (const [, room] of rooms) for (const [, c] of room.clients) if (c.ws === ws) return c;
  return null;
}

server.listen(PORT, () => console.log("YGTeeV Backyard relay listening on :" + PORT));
