// =============================================================================
// glowlands/lantern.js
// Lantern state + HUD for the Phase 1 gateway slice.
//
// Design authority: /docs/glowlands-design.md
//   Ch. 3.4  — the Lantern: brightness tiers (Spark/Flame/Beacon/Radiant),
//              THE stepwise algorithm (single source of truth), the onboarding
//              rule (Meadow Town core is never dark to a newcomer), the
//              pressure valve (7-of-rolling-10 counts as Radiant for gates),
//              and the gentle gate-line pattern ("Your lantern isn't bright
//              enough yet — Eli can help you relight it") deep-linking to
//              today's plan.
//   Ch. 5.4  — HUD language: the lantern meter is drawn as the actual lantern,
//              top-left; warm second-person voice, verbs first.
//   Ch. 5.5  — Lantern brightness is SERVER-DERIVED from real reading data,
//              read on session start and app foreground, and NEVER writable by
//              the game client (LOCKED).
//   Ch. 6    — Hearthlight: the Home Garden is always fully bright; the
//              Lantern Post reads the tier honestly, but gating is felt only
//              at frontier gates.
//   Ch. 17   — Phase 1 slice: the FULL four-tier data model ships, but only
//              Spark/Flame gates are actually *used* in the slice.
//
// WHAT THIS MODULE IS
//   * The tier data model (all four tiers — radius, order, voice lines).
//   * A read-only lantern state store with a strict source ladder:
//       debug override  >  server tier  >  staged derivation  >  Spark.
//     The "staged derivation" exists because the real server lantern service
//     is Phase 1 row 3 backend work that may land after the client: until it
//     does, we derive the tier locally from the player's glow-state (a record
//     of completed plan-day dates) using the exact Ch. 3.4 stepwise algorithm.
//     The derivation is pure and unit-testable; the moment ctx.getLanternTier
//     starts answering, it silently wins and the derivation becomes dead code.
//   * The lantern HUD pill (DOM, zero draw calls) with a live brightness
//     visual, and a tap popover with the warm tier line + plan deep-link.
//   * canEnter(requiredTier|zoneKey) — the ONE gate check, with the gentle
//     refusal line pattern. No punishment mechanics exist here: a closed gate
//     never costs, damages, or shames — it only points at today's reading.
//
// WHAT THIS MODULE IS NOT
//   * It never WRITES brightness anywhere (no storage writes, no RPCs) — the
//     client is read-only on lantern state, LOCKED (Ch. 5.5). The debug
//     setLantern() override is in-memory only and clears on reload.
//   * It never decides in-world combat radii — named Gloom territory uses
//     zone-constant radii (Ch. 2 decoupling rule); tier decides ENTRY only.
//   * It never touches dragon-garden-quest.jsx. The Wire phase calls
//     initLantern(ctx) and mounts the HUD; every entry point is safe to call
//     before init (no-ops / Spark defaults) so glowlands code may call these
//     unconditionally.
//
// ctx CONTRACT (Wire phase supplies this; every member optional-safe):
//   ctx.getLanternTier() -> 'spark'|'flame'|'beacon'|'radiant' | {tier} |
//       Promise of either — the real server-derived tier once the lantern
//       service exists. Wins over derivation whenever it answers.
//   ctx.getGlowState() -> glow-state | Promise<glow-state> — reading record
//       for the staged derivation. Accepted shapes (any one):
//         { completedDays: ['YYYY-MM-DD' | ISO | epochMs, ...] }
//         { readingDays:   [...same...] }
//         [...same...]                       (bare array)
//         { tier: 'flame' }                  (pre-derived snapshot passthrough)
//   ctx.storage — async KV with get(key)->{value} (window.storage-shaped).
//       Fallback read of the 'glow-state' key when getGlowState is absent.
//       READ ONLY — this module never calls set/delete on it.
//   ctx.openTodaysPlan() — deep link to today's plan day in the parent app.
//       Powers the gate line's "relight it" button and the HUD popover.
//   ctx.mount — parent element for HUD/toasts (default document.body).
//   ctx.now() -> epoch ms (default Date.now; injectable for tests).
//
// SCRIPTURE RULE: no verse text lives here (gate lines and tier lines are
// original prose in the game's warm voice — never quotes).
// =============================================================================

// -----------------------------------------------------------------------------
// Tier data model (Ch. 3.4 table — radii in metres, tunable).
// Full four-tier model ships in Phase 1; only spark/flame gates are USED.
// -----------------------------------------------------------------------------
export const LANTERN_TIERS = Object.freeze({
  spark: Object.freeze({
    key: 'spark', order: 1, label: 'Spark', radiusM: 4,
    access: 'Saved towns, Home Garden, and the roads between them',
    // Warm HUD line — never shaming; a lapsed lantern is "resting", not failed.
    line: 'Your lantern is resting at a spark. Today’s reading will relight it.',
    flame: { color: '#b8895a', glow: 'rgba(255,178,90,0.35)', size: 5 },
  }),
  flame: Object.freeze({
    key: 'flame', order: 2, label: 'Flame', radiusM: 7,
    access: '+ trial zones and dark-flagged Mission Trips',
    line: 'Your lantern burns at a steady flame. Keep reading — it grows.',
    flame: { color: '#ffb845', glow: 'rgba(255,184,69,0.55)', size: 7 },
  }),
  beacon: Object.freeze({
    key: 'beacon', order: 3, label: 'Beacon', radiusM: 11,
    access: '+ unsaved-town Gloom districts',
    line: 'Your lantern shines like a beacon. Dark roads open before you.',
    flame: { color: '#ffd27a', glow: 'rgba(255,205,110,0.75)', size: 9 },
  }),
  radiant: Object.freeze({
    key: 'radiant', order: 4, label: 'Radiant', radiusM: 15,
    access: '+ frontier missions, night events, seasonal surges',
    line: 'Radiant — your light warms everyone walking near you.',
    flame: { color: '#fff1c0', glow: 'rgba(255,230,150,0.95)', size: 11 },
  }),
});

/** Tier keys in ascending brightness order. */
export const TIER_ORDER = Object.freeze(['spark', 'flame', 'beacon', 'radiant']);

export function tierByKey(key) {
  return LANTERN_TIERS[key] || null;
}

function tierByOrder(order) {
  return LANTERN_TIERS[TIER_ORDER[Math.min(4, Math.max(1, order)) - 1]];
}

// -----------------------------------------------------------------------------
// Slice zone gates (Ch. 17: only spark/flame are USED in Phase 1; the rest are
// the full data model, flagged so nothing wires them yet). `null` = never
// gated. Meadow Town core is LOCKED-open (onboarding rule, Ch. 3.4); the two
// gardens are Hearthlight (Ch. 6) — gating is felt only at frontier gates.
// -----------------------------------------------------------------------------
export const ZONE_GATES = Object.freeze({
  home_garden:       Object.freeze({ requires: null,      inPhase1Slice: true }),  // Hearthlight
  community_garden:  Object.freeze({ requires: null,      inPhase1Slice: true }),  // Hearthlight
  garden_path:       Object.freeze({ requires: null,      inPhase1Slice: true }),  // 20 s safe walk
  meadow_town_core:  Object.freeze({ requires: null,      inPhase1Slice: true }),  // onboarding rule, LOCKED
  east_road:         Object.freeze({ requires: 'spark',   inPhase1Slice: true }),  // road between saved towns
  // Defined for the full data model; NOT used in the slice (Phase 2+):
  murkmire:          Object.freeze({ requires: 'flame',   inPhase1Slice: false }),
  whisper_gorge:     Object.freeze({ requires: 'flame',   inPhase1Slice: false }),
  hollowkeep:        Object.freeze({ requires: 'flame',   inPhase1Slice: false }),
  dark_mission_trip: Object.freeze({ requires: 'flame',   inPhase1Slice: false }),
  gloom_district:    Object.freeze({ requires: 'beacon',  inPhase1Slice: false }),
  frontier_mission:  Object.freeze({ requires: 'radiant', inPhase1Slice: false }),
});

// -----------------------------------------------------------------------------
// Gentle refusal lines (Ch. 3.4 pattern). Warm, second person, verbs first;
// the gate always points forward at today's reading, never back at the miss.
// The 'flame' line is the bible's canonical gate line verbatim.
// -----------------------------------------------------------------------------
const REFUSAL_LINES = Object.freeze({
  flame: 'Your lantern isn’t bright enough yet — Eli can help you relight it.',
  beacon: 'This part of town is still deep in Gloom. A few more days of reading and your beacon will carry you in.',
  radiant: 'This road asks for a radiant lantern. Keep reading — you’re closer than you think.',
});
const REFUSAL_HINT = 'Open today’s reading'; // deep-link button label

// Stepwise-algorithm constants (Ch. 3.4, tunable).
const DECAY_GAP_MS = 48 * 3600 * 1000;   // one tier lost per full 48 h without a plan day
const ROLLING_WINDOW_MS = 10 * 24 * 3600 * 1000; // the 7-of-rolling-10 pressure valve
const ROLLING_DAYS_NEEDED = 7;

// =============================================================================
// Staged derivation — the Ch. 3.4 stepwise algorithm, pure.
// Brightness is a stored stepwise VALUE, not a streak lookup: each completed
// plan day raises it one tier (max Radiant); each full 48 h gap without one
// lowers it one tier (min Spark).
// =============================================================================

/** Parse one glow-state entry ('YYYY-MM-DD' | ISO string | epoch ms) to ms. */
function entryToMs(e) {
  if (typeof e === 'number' && isFinite(e)) return e;
  if (typeof e !== 'string') return null;
  // Date-only strings anchor at local noon so DST edges can't move the day.
  if (/^\d{4}-\d{2}-\d{2}$/.test(e)) {
    const t = new Date(e + 'T12:00:00').getTime();
    return isFinite(t) ? t : null;
  }
  const t = new Date(e).getTime();
  return isFinite(t) ? t : null;
}

/** Local calendar-day key for dedup (a plan day counts once). */
function dayKey(ms) {
  const d = new Date(ms);
  return d.getFullYear() + '-' + (d.getMonth() + 1) + '-' + d.getDate();
}

/**
 * Normalize any accepted glow-state shape to a sorted array of completion
 * timestamps, ONE per local calendar day (the day's latest completion — decay
 * counts from when you last finished reading).
 */
export function normalizeGlowState(glowState) {
  let list = null;
  if (Array.isArray(glowState)) list = glowState;
  else if (glowState && Array.isArray(glowState.completedDays)) list = glowState.completedDays;
  else if (glowState && Array.isArray(glowState.readingDays)) list = glowState.readingDays;
  if (!list) return [];
  const byDay = new Map();
  for (const e of list) {
    const ms = entryToMs(e);
    if (ms == null) continue;
    const k = dayKey(ms);
    if (!byDay.has(k) || ms > byDay.get(k)) byDay.set(k, ms);
  }
  return Array.from(byDay.values()).sort((a, b) => a - b);
}

/**
 * The stepwise algorithm (Ch. 3.4, single source of truth), pure.
 * Returns a tier ORDER 1..4. A player with no completed days is Spark; the
 * prologue's first plan day lights the brand-new lantern to Flame — which is
 * exactly what one +1 step from Spark produces here.
 */
export function deriveTierOrder(glowState, nowMs) {
  const now = typeof nowMs === 'number' ? nowMs : Date.now();
  // Snapshot passthrough: a pre-derived { tier } is trusted as-is.
  if (glowState && !Array.isArray(glowState) && typeof glowState.tier === 'string') {
    const t = tierByKey(glowState.tier);
    if (t) return t.order;
  }
  const times = normalizeGlowState(glowState);
  let order = 1; // min Spark
  let prev = null;
  for (const t of times) {
    if (t > now) break; // ignore clock-skewed future entries
    if (prev != null) {
      const drops = Math.floor((t - prev) / DECAY_GAP_MS);
      if (drops > 0) order = Math.max(1, order - drops);
    }
    order = Math.min(4, order + 1);
    prev = t;
  }
  if (prev == null) return 1;
  const drops = Math.floor(Math.max(0, now - prev) / DECAY_GAP_MS);
  return Math.max(1, order - drops);
}

/**
 * Pressure valve (Ch. 3.4): any 7 completed plan days within a rolling 10
 * count as Radiant FOR GATE PURPOSES — a five-day-a-week reader is never
 * locked out, only late to extras. Display tier is unaffected.
 */
export function qualifiesRollingRadiant(glowState, nowMs) {
  const now = typeof nowMs === 'number' ? nowMs : Date.now();
  const times = normalizeGlowState(glowState);
  let n = 0;
  for (let i = times.length - 1; i >= 0; i--) {
    if (times[i] > now) continue;
    if (now - times[i] > ROLLING_WINDOW_MS) break;
    if (++n >= ROLLING_DAYS_NEEDED) return true;
  }
  return false;
}

// =============================================================================
// Lantern state store (read-only from the game's point of view)
// =============================================================================
let CTX = null;            // wire-phase context
let debugOverride = null;  // tier key | null — in-memory only, never persisted
let visListener = null;    // foreground-refresh handler (removed on dispose)
const listeners = new Set();

let state = {
  tier: 'spark',
  order: 1,
  label: 'Spark',
  radiusM: LANTERN_TIERS.spark.radiusM,
  gateTier: 'spark',       // display tier + rolling-Radiant valve, for gates
  gateOrder: 1,
  source: 'default',       // 'debug' | 'server' | 'derived' | 'default'
  updatedAt: 0,
};

function now() {
  if (CTX && typeof CTX.now === 'function') { try { return CTX.now(); } catch (e) {} }
  return Date.now();
}

function setState(tierKey, gateOrder, source) {
  const t = tierByKey(tierKey) || LANTERN_TIERS.spark;
  const g = Math.min(4, Math.max(t.order, gateOrder || t.order));
  const changed = t.key !== state.tier || g !== state.gateOrder || source !== state.source;
  state = {
    tier: t.key, order: t.order, label: t.label, radiusM: t.radiusM,
    gateTier: tierByOrder(g).key, gateOrder: g,
    source, updatedAt: now(),
  };
  if (changed) {
    for (const cb of listeners) { try { cb(getLantern()); } catch (e) {} }
    updateHud();
  }
}

/** Current snapshot (frozen copy). Safe pre-init: Spark defaults. */
export function getLantern() {
  return Object.freeze({ ...state });
}

/** Brightness as 0..1 (Lantern Post glow, garden cello stem, etc.). */
export function getBrightness01() {
  return (state.order - 1) / 3;
}

/**
 * The literal light radius (m) for the player's carried lantern point light +
 * ground decal ring. NOTE (Ch. 2 decoupling rule): named Gloom territory uses
 * zone-constant in-world radii for spatial gameplay — zones own that number;
 * this one is the tier's travel radius.
 */
export function getLightRadiusM() {
  return state.radiusM;
}

/** Subscribe to lantern changes. Returns an unsubscribe function. */
export function onLanternChange(cb) {
  if (typeof cb !== 'function') return () => {};
  listeners.add(cb);
  return () => listeners.delete(cb);
}

// -----------------------------------------------------------------------------
// Refresh — the source ladder. Read on session start (init) and app
// foreground (visibilitychange), per Ch. 5.5. Never writes anything.
// -----------------------------------------------------------------------------
async function readServerTier() {
  if (!CTX || typeof CTX.getLanternTier !== 'function') return null;
  try {
    const r = await CTX.getLanternTier();
    const key = typeof r === 'string' ? r : (r && typeof r.tier === 'string' ? r.tier : null);
    return key && tierByKey(key) ? key : null;
  } catch (e) { return null; }
}

async function readGlowState() {
  if (CTX && typeof CTX.getGlowState === 'function') {
    try {
      const gs = await CTX.getGlowState();
      if (gs != null) return gs;
    } catch (e) {}
  }
  // Fallback: the persisted 'glow-state' key on the host's async KV (READ only).
  const kv = (CTX && CTX.storage) || (typeof window !== 'undefined' ? window.storage : null);
  if (kv && typeof kv.get === 'function') {
    try {
      const row = await kv.get('glow-state'); // throws when missing — that's fine
      const raw = row && row.value != null ? row.value : row;
      if (typeof raw === 'string') { try { return JSON.parse(raw); } catch (e) { return null; } }
      return raw || null;
    } catch (e) { return null; }
  }
  return null;
}

/**
 * Re-read lantern state through the source ladder:
 *   debug override > server tier > staged derivation from glow-state > Spark.
 * Safe to call any time, from anywhere, even pre-init.
 */
export async function refreshLantern() {
  if (debugOverride) { setState(debugOverride, 4, 'debug'); return getLantern(); }

  const serverTier = await readServerTier();
  const gs = await readGlowState(); // still read for the rolling-Radiant valve
  const rollingRadiant = gs ? qualifiesRollingRadiant(gs, now()) : false;

  if (serverTier) {
    setState(serverTier, rollingRadiant ? 4 : 0, 'server');
  } else if (gs != null) {
    const order = deriveTierOrder(gs, now());
    setState(tierByOrder(order).key, rollingRadiant ? 4 : 0, 'derived');
  } else {
    setState('spark', 0, 'default');
  }
  return getLantern();
}

/**
 * Debug override (dev/staging QA): force a tier, or pass null to return to
 * real data. In-memory only — reload clears it; nothing is ever written.
 * Debug state gates as Radiant so QA can walk every door.
 */
export function setLantern(tierKey) {
  debugOverride = tierKey && tierByKey(tierKey) ? tierKey : null;
  if (debugOverride) setState(debugOverride, 4, 'debug');
  else refreshLantern();
  return getLantern();
}

/**
 * Wire-phase init. Reads once, then refreshes on every app foreground.
 * Idempotent; last ctx wins.
 */
export function initLantern(ctx) {
  CTX = ctx || {};
  if (!visListener && typeof document !== 'undefined') {
    visListener = () => { if (document.visibilityState === 'visible') refreshLantern(); };
    document.addEventListener('visibilitychange', visListener);
  }
  return refreshLantern();
}

/** Full teardown (HUD, popover, listeners). */
export function disposeLantern() {
  if (visListener && typeof document !== 'undefined') {
    document.removeEventListener('visibilitychange', visListener);
    visListener = null;
  }
  unmountLanternHud();
  dismissGateToast();
  listeners.clear();
  CTX = null;
}

// =============================================================================
// Gate check — canEnter(requiredTier | zoneKey)
// =============================================================================

/**
 * The one gate check. Accepts a tier key ('flame'), a ZONE_GATES key
 * ('east_road'), or null/undefined (never gated).
 *
 * Returns { ok, tier, order, required, requiredOrder, line, hint }:
 *   ok            — true when the gate opens (compares against gateOrder, so
 *                   the 7-of-rolling-10 Radiant valve applies automatically)
 *   line          — the gentle refusal line (only when !ok); warm voice,
 *                   points at today's reading, never at the lapse
 *   hint          — deep-link button label for the gate UI
 *
 * No punishment mechanics: a refused gate costs nothing and records nothing.
 */
export function canEnter(required) {
  let reqKey = required;
  if (reqKey != null && ZONE_GATES[reqKey]) reqKey = ZONE_GATES[reqKey].requires;
  if (reqKey == null) {
    return { ok: true, tier: state.tier, order: state.order, required: null, requiredOrder: 0, line: null, hint: null };
  }
  const reqTier = tierByKey(reqKey);
  if (!reqTier) {
    // Unknown requirement: fail OPEN — a data typo must never lock a kid out.
    return { ok: true, tier: state.tier, order: state.order, required: null, requiredOrder: 0, line: null, hint: null };
  }
  const ok = state.gateOrder >= reqTier.order;
  return {
    ok,
    tier: state.tier,
    order: state.order,
    required: reqTier.key,
    requiredOrder: reqTier.order,
    line: ok ? null : (REFUSAL_LINES[reqTier.key] || REFUSAL_LINES.flame),
    hint: ok ? null : REFUSAL_HINT,
  };
}

// =============================================================================
// DOM — theme (values copied from dragon-garden-quest.jsx's UI language, not
// imported: that file stays untouched) + the HUD pill + the gate toast.
// =============================================================================
const GOLD = '#2f7fc1';
const GOLD_BRIGHT = '#ffb845';
const PARCH = '#17497e';
const WOOD = 'linear-gradient(180deg, #ffffff 0%, #edf7fd 55%, #d8edfb 100%)';
const GOLD_BTN_BG = 'linear-gradient(180deg, #ffc85e, #f0931c)';
const FONT = "'Trebuchet MS', 'Segoe UI', sans-serif";
const PANEL_SHADOW =
  'inset 0 0 0 2px rgba(255,255,255,0.85), inset 0 -3px 8px rgba(47,127,193,0.16), 0 8px 18px rgba(23,73,126,0.28)';

let styleTag = null;
function ensureStyles() {
  if (styleTag || typeof document === 'undefined') return;
  styleTag = document.createElement('style');
  styleTag.setAttribute('data-glowlands', 'lantern');
  styleTag.textContent = `
@keyframes glFlameFlicker { 0%,100% { transform: scale(1) } 42% { transform: scale(1.12, 0.94) } 74% { transform: scale(0.93, 1.08) } }
@keyframes glRadiantBreathe { 0%,100% { opacity: 0.85 } 50% { opacity: 1 } }
@keyframes glGateIn { from { transform: translate(-50%, -14px); opacity: 0 } to { transform: translate(-50%, 0); opacity: 1 } }
@keyframes glGateOut { from { opacity: 1 } to { opacity: 0 } }
@keyframes glPopIn { from { transform: translateY(-6px); opacity: 0 } to { transform: none; opacity: 1 } }
`;
  document.head.appendChild(styleTag);
}

function el(tag, styles, text) {
  const n = document.createElement(tag);
  if (styles) Object.assign(n.style, styles);
  if (text != null) n.textContent = text;
  return n;
}

// -----------------------------------------------------------------------------
// HUD pill — the lantern, drawn as the actual lantern (Ch. 5.4): a small brass
// lantern whose flame + glow scale with tier, four tier pips, tier name.
// Pure DOM: zero draw calls against the perf budget.
// -----------------------------------------------------------------------------
let hud = null; // { root, flame, glowHalo, pips, label, popover }

/**
 * Mount the lantern HUD pill.
 *   parent — element to append into (default ctx.mount or document.body)
 *   opts.floating — when true (default), the pill positions itself top-left
 *     under the host's stats row; pass false to lay it into a host-owned row.
 * Tapping the pill opens a small popover: the warm tier line + tier pips +
 * an "Open today's reading" button when ctx.openTodaysPlan exists.
 */
export function mountLanternHud(parent, opts = {}) {
  if (typeof document === 'undefined') return null;
  if (hud) return hud.root;
  ensureStyles();
  const floating = opts.floating !== false;
  const mount = parent || (CTX && CTX.mount) || document.body;

  const root = el('div', {
    display: 'flex', alignItems: 'center', gap: '8px',
    background: WOOD, border: `2px solid ${GOLD}`, boxShadow: PANEL_SHADOW,
    borderRadius: '16px', padding: '5px 12px 5px 8px', color: PARCH,
    fontFamily: FONT, fontSize: '13px', fontWeight: '700',
    cursor: 'pointer', userSelect: 'none', WebkitUserSelect: 'none',
    pointerEvents: 'auto',
  });
  root.setAttribute('data-glow-hud', 'lantern'); // lets overlays (title splash) hide the HUD
  if (floating) {
    Object.assign(root.style, {
      position: 'absolute', zIndex: 40,
      top: 'calc(48px + env(safe-area-inset-top, 0px))', // one row under gold/XP
      left: opts.left != null ? opts.left : '10px',
    });
  }

  // --- the lantern itself (CSS brass-and-glass) ---
  const lamp = el('div', { position: 'relative', width: '22px', height: '30px', flex: '0 0 22px' });
  // hanging ring + cap
  lamp.appendChild(el('div', {
    position: 'absolute', top: '0', left: '50%', transform: 'translateX(-50%)',
    width: '8px', height: '4px', border: '1.5px solid #a5772e', borderBottom: 'none',
    borderRadius: '4px 4px 0 0',
  }));
  lamp.appendChild(el('div', {
    position: 'absolute', top: '3px', left: '50%', transform: 'translateX(-50%)',
    width: '16px', height: '5px', background: 'linear-gradient(180deg, #e8b85e, #a5772e)',
    borderRadius: '3px 3px 1px 1px',
  }));
  // glass body
  const glass = el('div', {
    position: 'absolute', top: '8px', left: '50%', transform: 'translateX(-50%)',
    width: '18px', height: '17px',
    background: 'linear-gradient(180deg, rgba(255,255,255,0.9), rgba(214,236,250,0.75))',
    border: '1.5px solid #a5772e', borderRadius: '4px',
    overflow: 'visible',
  });
  // glow halo (behind the flame, scales with tier)
  const glowHalo = el('div', {
    position: 'absolute', left: '50%', top: '52%', transform: 'translate(-50%, -50%)',
    width: '26px', height: '26px', borderRadius: '50%', pointerEvents: 'none',
  });
  glass.appendChild(glowHalo);
  // the flame
  const flame = el('div', {
    position: 'absolute', left: '50%', top: '52%', transform: 'translate(-50%, -55%)',
    width: '7px', height: '9px',
    borderRadius: '50% 50% 50% 50% / 62% 62% 38% 38%',
    animation: 'glFlameFlicker 1.6s ease-in-out infinite',
    transformOrigin: '50% 85%',
  });
  glass.appendChild(flame);
  lamp.appendChild(glass);
  // base
  lamp.appendChild(el('div', {
    position: 'absolute', bottom: '0', left: '50%', transform: 'translateX(-50%)',
    width: '14px', height: '4px', background: 'linear-gradient(180deg, #e8b85e, #a5772e)',
    borderRadius: '1px 1px 3px 3px',
  }));
  root.appendChild(lamp);

  // --- label + pips column ---
  const col = el('div', { display: 'flex', flexDirection: 'column', gap: '3px', alignItems: 'flex-start' });
  const label = el('div', { lineHeight: '1', letterSpacing: '0.4px' }, 'Spark');
  const pips = el('div', { display: 'flex', gap: '3px' });
  const pipEls = [];
  for (let i = 0; i < 4; i++) {
    const p = el('div', {
      width: '7px', height: '7px', borderRadius: '50%',
      border: '1px solid #a8cfe8', background: '#e9f5fc',
      transition: 'background 0.3s, box-shadow 0.3s, border-color 0.3s',
    });
    pipEls.push(p);
    pips.appendChild(p);
  }
  col.appendChild(label);
  col.appendChild(pips);
  root.appendChild(col);

  hud = { root, flame, glowHalo, pips: pipEls, label, popover: null, mount };

  root.addEventListener('click', (ev) => { ev.stopPropagation(); togglePopover(); });
  mount.appendChild(root);
  updateHud();
  return root;
}

export function unmountLanternHud() {
  if (!hud) return;
  closePopover();
  if (hud.root.parentNode) hud.root.parentNode.removeChild(hud.root);
  hud = null;
}

function updateHud() {
  if (!hud) return;
  const t = tierByKey(state.tier) || LANTERN_TIERS.spark;
  const f = t.flame;
  hud.label.textContent = t.label;
  Object.assign(hud.flame.style, {
    width: f.size + 'px', height: Math.round(f.size * 1.3) + 'px',
    background: `radial-gradient(circle at 50% 70%, #ffffff 0%, ${f.color} 55%, rgba(255,140,40,0.65) 100%)`,
    boxShadow: `0 0 ${4 + state.order * 3}px ${1 + state.order}px ${f.glow}`,
    opacity: state.order === 1 ? '0.8' : '1',
  });
  Object.assign(hud.glowHalo.style, {
    background: `radial-gradient(circle, ${f.glow} 0%, rgba(255,184,69,0) 70%)`,
    width: 12 + state.order * 6 + 'px', height: 12 + state.order * 6 + 'px',
    animation: state.order === 4 ? 'glRadiantBreathe 2.4s ease-in-out infinite' : 'none',
    opacity: String(0.35 + 0.16 * state.order),
  });
  hud.pips.forEach((p, i) => {
    const lit = i < state.order;
    Object.assign(p.style, {
      background: lit ? 'linear-gradient(180deg, #ffc85e, #f0931c)' : '#e9f5fc',
      borderColor: lit ? GOLD_BRIGHT : '#a8cfe8',
      boxShadow: lit ? '0 0 5px rgba(255,184,69,0.6)' : 'none',
    });
  });
  if (hud.popover) renderPopoverContent();
}

// --- tap popover: warm tier line + plan deep-link -----------------------------
let outsideCloser = null;

function togglePopover() {
  if (!hud) return;
  if (hud.popover) { closePopover(); return; }
  const pop = el('div', {
    position: 'absolute', top: 'calc(100% + 8px)', left: '0', zIndex: 41,
    minWidth: '220px', maxWidth: '270px',
    background: WOOD, border: `2px solid ${GOLD}`, boxShadow: PANEL_SHADOW,
    borderRadius: '14px', padding: '11px 13px', color: PARCH,
    fontFamily: FONT, fontSize: '13px', fontWeight: '600', lineHeight: '1.45',
    animation: 'glPopIn 0.22s ease-out',
    cursor: 'default',
  });
  pop.addEventListener('click', (ev) => ev.stopPropagation());
  hud.popover = pop;
  hud.root.appendChild(pop);
  renderPopoverContent();
  outsideCloser = () => closePopover();
  setTimeout(() => document.addEventListener('click', outsideCloser), 0);
}

function closePopover() {
  if (!hud || !hud.popover) return;
  if (hud.popover.parentNode) hud.popover.parentNode.removeChild(hud.popover);
  hud.popover = null;
  if (outsideCloser) { document.removeEventListener('click', outsideCloser); outsideCloser = null; }
}

function renderPopoverContent() {
  const pop = hud && hud.popover;
  if (!pop) return;
  pop.textContent = '';
  const t = tierByKey(state.tier) || LANTERN_TIERS.spark;
  const title = el('div', { fontWeight: '800', fontSize: '12px', letterSpacing: '1.2px', color: '#f2971f', textShadow: '0 1px 0 rgba(255,255,255,0.75)', marginBottom: '5px' }, 'YOUR LANTERN — ' + t.label.toUpperCase());
  pop.appendChild(title);
  pop.appendChild(el('div', {}, t.line));
  // The valve, made visible: gates may already open wider than the flame shows.
  if (state.gateOrder > state.order) {
    pop.appendChild(el('div', { marginTop: '6px', fontSize: '12px', opacity: '0.85' },
      'Seven readings these last ten days — every gate opens for you.'));
  }
  const canDeepLink = CTX && typeof CTX.openTodaysPlan === 'function';
  if (canDeepLink && state.order < 4) {
    const btn = el('button', {
      marginTop: '9px', border: '1px solid #155a9c', borderRadius: '9px', padding: '7px 14px',
      fontWeight: '700', fontFamily: FONT, fontSize: '13px', cursor: 'pointer',
      background: GOLD_BTN_BG, color: '#5a3305',
      boxShadow: 'inset 0 1px 2px rgba(255,255,255,0.75), 0 3px 6px rgba(0,0,0,0.4)',
    }, REFUSAL_HINT);
    btn.addEventListener('click', (ev) => {
      ev.stopPropagation();
      closePopover();
      try { CTX.openTodaysPlan(); } catch (e) {}
    });
    pop.appendChild(btn);
  }
}

// -----------------------------------------------------------------------------
// Gate refusal toast — the gentle gate line UI. Slides from the top (host
// toast language, Ch. 5.4), warm voice, deep-links to today's plan. Max one
// on screen. Costs nothing, records nothing.
// -----------------------------------------------------------------------------
let gateToast = null;
let gateToastTimer = 0;

export function dismissGateToast() {
  if (gateToastTimer) { clearTimeout(gateToastTimer); gateToastTimer = 0; }
  if (gateToast && gateToast.parentNode) gateToast.parentNode.removeChild(gateToast);
  gateToast = null;
}

/**
 * Show the gentle refusal for a gate the player can't pass yet.
 *   required — tier key or ZONE_GATES key (same as canEnter)
 *   opts.line — optional authored override (e.g. a road-warden's phrasing)
 *   opts.durationMs — default 5200 (long enough to read + tap the button)
 * Returns the canEnter() result (so callers can branch on .ok and skip the
 * toast entirely when the gate opens).
 */
export function showGateRefusal(required, opts = {}) {
  const check = canEnter(required);
  if (check.ok || typeof document === 'undefined') return check;
  ensureStyles();
  dismissGateToast();

  const mount = (CTX && CTX.mount) || document.body;
  const card = el('div', {
    position: 'absolute', top: 'calc(64px + env(safe-area-inset-top, 0px))', left: '50%',
    transform: 'translate(-50%, 0)', zIndex: 46,
    maxWidth: 'min(92%, 400px)',
    background: WOOD, border: `2px solid ${GOLD}`, boxShadow: PANEL_SHADOW,
    borderRadius: '14px', padding: '11px 15px', color: PARCH,
    fontFamily: FONT, fontSize: '13.5px', fontWeight: '600', lineHeight: '1.45',
    textAlign: 'center', animation: 'glGateIn 0.3s ease-out',
    pointerEvents: 'auto',
  });
  card.appendChild(el('div', {}, opts.line || check.line));
  if (CTX && typeof CTX.openTodaysPlan === 'function') {
    const btn = el('button', {
      marginTop: '9px', border: '1px solid #155a9c', borderRadius: '9px', padding: '7px 16px',
      fontWeight: '700', fontFamily: FONT, fontSize: '13px', cursor: 'pointer',
      background: GOLD_BTN_BG, color: '#5a3305',
      boxShadow: 'inset 0 1px 2px rgba(255,255,255,0.75), 0 3px 6px rgba(0,0,0,0.4)',
    }, check.hint);
    btn.addEventListener('click', (ev) => {
      ev.stopPropagation();
      dismissGateToast();
      try { CTX.openTodaysPlan(); } catch (e) {}
    });
    card.appendChild(btn);
  }
  card.addEventListener('click', () => dismissGateToast());
  mount.appendChild(card);
  gateToast = card;
  gateToastTimer = setTimeout(() => {
    if (gateToast) {
      gateToast.style.animation = 'glGateOut 0.4s ease-in forwards';
      setTimeout(dismissGateToast, 420);
    }
  }, opts.durationMs || 5200);
  return check;
}

// -----------------------------------------------------------------------------
// Dev hook (mirrors the host's window.__BY_G pattern; DEV builds only).
// window.__GL_LANTERN.set('beacon') / .set(null) / .get() / .refresh()
// -----------------------------------------------------------------------------
const IS_DEV = (() => { try { return !!(import.meta && import.meta.env && import.meta.env.DEV); } catch (e) { return false; } })();
if (IS_DEV && typeof window !== 'undefined') {
  window.__GL_LANTERN = { get: getLantern, set: setLantern, refresh: refreshLantern, canEnter };
}

export default getLantern;
