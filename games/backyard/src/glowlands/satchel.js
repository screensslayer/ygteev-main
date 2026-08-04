// =============================================================================
// glowlands/satchel.js
// The Verse Satchel — Truth Serum inventory model + out-of-combat panel UI.
//
// Design authority: /docs/glowlands-design.md
//   Ch. 2.3  — Truth Serums & the Verse Satchel (earning, 5 charges, loadout
//              6 families x 3 cards / max 18 equipped, wick pips, long-press
//              full text, mastery Bronze/Silver/Gold, recharge free at any
//              library — "the librarian re-reads the verse with you")
//   Ch. 2.2  — six verse families / type chart (families never color-only)
//   Ch. 5.7  — the Lightfound fanfare: EVERY earn event plays it (full form
//              for a serum mint, small form for pickups); never for something
//              the player did not actually gain
//   Ch. 3.10 — the reading desk doubles as the serum recharge point
//   Ch. 17   — row 4 (Truth Serum pipeline + Satchel: charge model, radial UI,
//              charge pips, long-press full text, mastery counters)
//
// ROLE SPLIT vs combat.js: combat.js owns the IN-ENCOUNTER satchel wheel and
// battle overlay. This module owns everything outside the fight — the persistent
// serum collection ("glow-state"), the HUD-opened satchel panel, the
// recharge-at-library flow, and the serum-earn toast. The two meet through the
// ctx bridge below.
//
// -----------------------------------------------------------------------------
// WIRING (Wire phase only — this module NEVER touches dragon-garden-quest.jsx):
//
//   import createSatchel from './glowlands/satchel.js';
//   const satchel = createSatchel({
//     storage: window.storage,        // async KV ({get(key)->{value}, set(key,str)});
//                                     // falls back to localStorage in a bare dev page
//     fetchPassage,                   // (ref) -> Promise<{reference, translation,
//                                     //   text, copyright?} | {error}> — RUNTIME ESV
//                                     //   via get-bible-passage; may 503
//                                     //   {error:'translation_unavailable'} until the
//                                     //   ESV key exists. Reader degrades to ref+gist.
//     fanfare: (weight) => {...},     // the Lightfound jingle ('full'|'small');
//                                     //   e.g. audio-motifs' playLightfoundFanfare
//     sfx: SFX,                       // optional host SFX object ({click, correct, ...})
//     mountEl: document.body,         // optional overlay parent
//     atLibrary: () => bool,          // optional: enables the panel's Recharge button
//     onChange: (snapshot) => {...},  // optional: HUD badge refresh hook
//     settings: { reducedFlash },     // optional accessibility flags
//   });
//   await satchel.ready;              // hydrated from glow-state
//
//   // Combat bridge (combat.js ctx contract):
//   startEncounter({ ...gameCtx,
//     getEquippedSerums: satchel.getEquippedSerums,
//     spendSerumCharge:  satchel.spendSerumCharge,
//   }, 'east_road_milepost_oak');
//
//   // Town Book bridge (townbook.js ctx contract — the reading desk):
//   createTownBook({ ..., satchel: {
//     mintSerum: satchel.mintSerum,   // memory-verse pass mints a serum
//     recharge:  satchel.recharge,    // desk = the serum recharge point
//   }});
//
//   // HUD: either mount the provided button or call openPanel() from your own.
//   satchel.mountHudButton(hudEl);    // or satchel.openPanel()
//
// -----------------------------------------------------------------------------
// PERSISTENCE — the glow-state blob.
// One storage key, GLOW_STATE_KEY ('glow-state'), holds a JSON object shared by
// glowlands modules. This module owns ONLY the `satchel` slice and preserves
// every foreign top-level key on write (read-modify-write, serialized through a
// single promise chain so concurrent saves can't clobber each other):
//
//   { satchel: { v: 1,
//       serums:   { [serumId]: { id, ref, family, charges, mastery,
//                                earnedAt, source, sourceId } },
//       equipped: [serumId, ...],          // <= 3/family, <= 18 total
//       lastRechargeAt: ISOString|null } }
//
// SCRIPTURE RULE (LOCKED): this file bundles ZERO verse text. Serums store an
// accurate `ref` only; card faces show the ORIGINAL `gist` prose from
// combat-data.js VERSES (or none for CMS-minted refs outside that pool). Full
// text is fetched at RUNTIME via ctx.fetchPassage and every text surface
// degrades gracefully to ref + gist. No dev mock lives here (townbook.js owns
// the one DEV-gated mock provider; pass it in as ctx.fetchPassage to judge
// this UI standalone).
//
// No three.js, no React, no new dependencies — a 2D DOM overlay adds zero
// draw calls to the 3D budget.
// =============================================================================

import {
  COMBAT_TUNING,
  LIE_FAMILIES,
  VERSE_FAMILIES,
  TYPE_CHART,
  VERSES,
} from './data/combat-data.js';

// ---------------------------------------------------------------------------
// Environment
// ---------------------------------------------------------------------------
const IS_DEV = (() => {
  try { return !!(import.meta.env && import.meta.env.DEV); } catch (e) { return false; }
})();

// ---------------------------------------------------------------------------
// Tunables (Ch. 2.3 — every number the bible marks tunable)
// ---------------------------------------------------------------------------
export const SATCHEL_TUNING = Object.freeze({
  maxCharges: COMBAT_TUNING.serumCharges,            // 5 (Deepwell Vials -> 6, Phase 2)
  familySlots: COMBAT_TUNING.loadout.familySlots,    // 6
  cardsPerFamily: COMBAT_TUNING.loadout.cardsPerFamily, // 3
  maxEquipped: COMBAT_TUNING.loadout.maxEquipped,    // 18
  mastery: COMBAT_TUNING.masteryThresholds,          // { bronze: 5, silver: 15, gold: 40 }
  earnToastSec: 3.2,                                 // serum-earn toast hold time
  saveDebounceMs: 250,                               // persistence write coalescing
});

/** The shared glowlands save blob key (window.storage / by_saves). */
export const GLOW_STATE_KEY = 'glow-state';

// ---------------------------------------------------------------------------
// Pure helpers (exported for tests and sibling modules)
// ---------------------------------------------------------------------------

/**
 * Canonical serum id for a verse reference: the combat-data VERSES key when
 * the ref matches that pool (so combat.js recognizes the card), else a stable
 * slug of the reference (future CMS-minted verses outside the launch pool).
 */
export function serumIdForRef(ref) {
  const norm = String(ref || '').trim().toLowerCase();
  for (const [id, v] of Object.entries(VERSES)) {
    if (v.ref.toLowerCase() === norm) return id;
  }
  return norm.replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '') || 'unknown_ref';
}

/** Mastery tier for a correct-use count: 'gold' | 'silver' | 'bronze' | null. */
export function masteryTierFor(count, thresholds = SATCHEL_TUNING.mastery) {
  if (count >= thresholds.gold) return 'gold';
  if (count >= thresholds.silver) return 'silver';
  if (count >= thresholds.bronze) return 'bronze';
  return null;
}

/**
 * Verse families in satchel-wheel order — each verse family sits in the fixed
 * wheel wedge of the lie family it counters (families are never color-only:
 * icon + wheel position double-code them, Ch. 2.2).
 */
export const FAMILY_WHEEL_ORDER = Object.freeze(
  Object.values(LIE_FAMILIES)
    .slice()
    .sort((a, b) => a.wheelIndex - b.wheelIndex)
    .map((lf) => lf.counterFamily)
);

// Family glyphs — same double-coding set as combat.js (values copied, not
// imported from it: sibling UI modules stay independent).
const VERSE_FAMILY_GLYPHS = {
  presence: '🤝', grace: '🕊', courage: '🦁', identity: '🌟', hope: '🌅', trust: '🧭',
};
const LIE_FAMILY_GLYPHS = {
  isolation: '◌', condemnation: '⛓', fear: '👁', worthlessness: '🪞', despair: '🍂', doubt: '🏮',
};

/** Lie family a verse family counters (reverse type chart). */
const COUNTERED_LIE = {};
for (const [lie, verse] of Object.entries(TYPE_CHART)) COUNTERED_LIE[verse] = lie;

// ---------------------------------------------------------------------------
// Storage adapter — window.storage shape with a localStorage fallback so the
// module is judgeable in a bare dev page (mirrors townbook.js).
// ---------------------------------------------------------------------------
function makeStorage(ctxStorage) {
  const s = ctxStorage || (typeof window !== 'undefined' ? window.storage : null);
  if (s && typeof s.get === 'function' && typeof s.set === 'function') {
    return {
      async get(key) { try { const r = await s.get(key); return r && r.value != null ? r.value : null; } catch (e) { return null; } },
      async set(key, val) { try { await s.set(key, val); } catch (e) { /* non-fatal */ } },
    };
  }
  return {
    async get(key) { try { return window.localStorage.getItem(key); } catch (e) { return null; } },
    async set(key, val) { try { window.localStorage.setItem(key, val); } catch (e) { /* non-fatal */ } },
  };
}

// ---------------------------------------------------------------------------
// Fallback SFX + Lightfound fanfare — used only when ctx.sfx / ctx.fanfare are
// absent (judging standalone). The real game passes its SFX through ctx; the
// melody here mirrors the Ch. 5.7 shape (ascending bells resolving to the
// lantern leitmotif's first interval) in the same WebAudio blip style as the
// host game and townbook.js.
// ---------------------------------------------------------------------------
function makeSfx(ctxSfx, ctxFanfare) {
  let AC = null;
  const ac = () => {
    if (!AC) { try { AC = new (window.AudioContext || window.webkitAudioContext)(); } catch (e) { /* no audio */ } }
    if (AC && AC.state === 'suspended') AC.resume().catch(() => {});
    return AC;
  };
  const tone = (freq, at, dur, gain, type = 'sine') => {
    const a = ac(); if (!a) return;
    const o = a.createOscillator(); const g = a.createGain();
    o.type = type; o.frequency.value = freq;
    g.gain.setValueAtTime(0.0001, at);
    g.gain.linearRampToValueAtTime(gain, at + 0.015);
    g.gain.exponentialRampToValueAtTime(0.0001, at + dur);
    o.connect(g); g.connect(a.destination);
    o.start(at); o.stop(at + dur + 0.05);
  };
  const now = () => (ac() ? AC.currentTime + 0.01 : 0);
  const fb = {
    click:  () => tone(1150, now(), 0.05, 0.06, 'square'),
    equip:  () => { const t = now(); tone(660, t, 0.08, 0.08, 'triangle'); tone(880, t + 0.06, 0.1, 0.08, 'triangle'); },
    wick:   () => { const t = now(); tone(523.25, t, 0.1, 0.07, 'triangle'); tone(1046.5, t + 0.07, 0.2, 0.06); }, // a wick relighting
    wrong:  () => tone(200, now(), 0.22, 0.1, 'square'),
  };
  const sfx = {};
  for (const k of Object.keys(fb)) {
    sfx[k] = (ctxSfx && typeof ctxSfx[k] === 'function') ? () => ctxSfx[k]() : fb[k];
  }
  // The Lightfound fanfare (Ch. 5.7): full = milestones (a serum mint), small = pickups.
  sfx.fanfare = (weight = 'small') => {
    if (typeof ctxFanfare === 'function') { try { ctxFanfare(weight); } catch (e) { /* audio hook */ } return; }
    if (ctxSfx && typeof ctxSfx.itemGet === 'function') { ctxSfx.itemGet(); return; }
    const t = now();
    const seq = weight === 'full'
      ? [523.25, 659.25, 784, 1046.5, 1318.5]
      : [659.25, 784, 1046.5];
    seq.forEach((f, i) => tone(f, t + i * 0.09, 0.22, 0.12, 'triangle'));
    if (weight === 'full') tone(1568, t + seq.length * 0.09, 0.5, 0.08);
  };
  return sfx;
}

// ---------------------------------------------------------------------------
// Visual language — the travel-worn leather-and-brass satchel. Same panel
// grammar as the game's ornate dialogs (S.panel / Ribbon / Corners in
// dragon-garden-quest.jsx) and townbook.js's parchment; values copied, never
// imported — the host file stays untouched.
// ---------------------------------------------------------------------------
const UI = Object.freeze({
  font: "'Trebuchet MS', 'Segoe UI', sans-serif",
  scrim: 'rgba(20, 14, 8, 0.6)',
  leather: 'radial-gradient(120% 80% at 50% -20%, rgba(255,243,220,0.9), rgba(255,243,220,0) 55%), linear-gradient(180deg, #f7e9c8 0%, #ecd8a8 55%, #ddc48d 100%)',
  cardBg: 'linear-gradient(180deg, #fffaf0 0%, #f7ecd2 100%)',
  cardSpentBg: 'linear-gradient(180deg, #efe9dd 0%, #e2d9c6 100%)',
  wood: '#7a5230',
  ink: '#4a3218',
  inkSoft: 'rgba(74, 50, 24, 0.7)',
  gold: '#b07a28',
  goldBright: '#ffb845',
  amber: '#a3641a',
  goldBtn: 'linear-gradient(180deg, #ffc85e, #f0931c)',
  greenBtn: 'linear-gradient(180deg, #6cd47a, #2f7a3c)',
  panelShadow: 'inset 0 0 0 2px rgba(255,244,214,0.85), inset 0 -3px 8px rgba(122,82,48,0.18), 0 10px 26px rgba(30,18,6,0.5)',
  masteryColors: { bronze: '#a4703a', silver: '#9aa3ad', gold: '#e0a121' },
});

const STYLE_ID = 'glowlands-satchel-style';
function ensureStyles() {
  if (document.getElementById(STYLE_ID)) return;
  const s = document.createElement('style');
  s.id = STYLE_ID;
  s.textContent = `
    @keyframes gsPop { 0% { transform: scale(0.72); opacity: 0; } 100% { transform: scale(1); opacity: 1; } }
    @keyframes gsFadeUp { 0% { transform: translateY(10px); opacity: 0; } 100% { transform: translateY(0); opacity: 1; } }
    @keyframes gsToast { 0% { transform: translateY(-8px); opacity: 0; } 10% { transform: translateY(0); opacity: 1; } 88% { opacity: 1; } 100% { opacity: 0; } }
    @keyframes gsSpin { to { transform: rotate(360deg); } }
    @keyframes gsBloom { 0% { transform: scale(0.4); opacity: 0; } 30% { opacity: 0.9; } 100% { transform: scale(1.9); opacity: 0; } }
    @keyframes gsEarnPop { 0% { transform: scale(0.6); opacity: 0; } 60% { transform: scale(1.06); opacity: 1; } 100% { transform: scale(1); opacity: 1; } }
    @keyframes gsWickLight { 0% { transform: scale(0.6); filter: grayscale(1); } 60% { transform: scale(1.5); } 100% { transform: scale(1); filter: grayscale(0); } }
  `;
  document.head.appendChild(s);
}

/** Tiny hyperscript: el('div', {style, onClick, ...attrs}, ...children) */
function el(tag, props, ...kids) {
  const n = document.createElement(tag);
  if (props) {
    for (const [k, v] of Object.entries(props)) {
      if (v == null) continue;
      if (k === 'style') Object.assign(n.style, v);
      else if (k.startsWith('on') && typeof v === 'function') n.addEventListener(k.slice(2).toLowerCase(), v);
      else if (k === 'className') n.className = v;
      else n.setAttribute(k, v);
    }
  }
  for (const kid of kids.flat(Infinity)) {
    if (kid == null || kid === false) continue;
    n.append(kid.nodeType ? kid : String(kid));
  }
  return n;
}

const ribbon = (text) => el('div', { style: { textAlign: 'center', margin: '0 0 10px' } },
  el('div', {
    style: {
      display: 'inline-flex', alignItems: 'center', gap: '10px', padding: '6px 18px',
      background: 'linear-gradient(180deg, #fff7e2, #f0dfb6)', border: `1px solid ${UI.gold}`,
      boxShadow: 'inset 0 0 0 1px rgba(255,184,69,0.35), 0 3px 8px rgba(30,18,6,0.45)',
      borderRadius: '6px', color: UI.amber, fontSize: '14px', letterSpacing: '2px', fontWeight: '700',
    },
  }, el('span', { style: { opacity: '0.6', fontSize: '11px' } }, '◆'), text,
     el('span', { style: { opacity: '0.6', fontSize: '11px' } }, '◆')));

const corners = () => {
  const c = (t, l, r, b) => el('span', {
    style: {
      position: 'absolute', fontSize: '13px', color: UI.goldBright, opacity: '0.8',
      top: t, left: l, right: r, bottom: b, pointerEvents: 'none',
    },
  }, '✦');
  return [c('4px', '8px', null, null), c('4px', null, '8px', null), c(null, '8px', null, '4px'), c(null, null, '8px', '4px')];
};

function button(label, { kind = 'gold', disabled = false, small = false } = {}, onClick) {
  const bg = disabled ? '#d9cba8' : kind === 'green' ? UI.greenBtn : kind === 'plain' ? 'transparent' : UI.goldBtn;
  const fg = disabled ? '#9a8a68' : kind === 'plain' ? UI.ink : kind === 'green' ? '#f4ffe9' : '#5a3305';
  return el('button', {
    style: {
      border: `1px solid ${disabled ? '#b5a37c' : UI.wood}`, borderRadius: '10px',
      padding: small ? '6px 12px' : '10px 20px', fontWeight: '800',
      fontFamily: 'inherit', fontSize: small ? '12.5px' : '15px',
      cursor: disabled ? 'default' : 'pointer', background: bg, color: fg,
      boxShadow: disabled ? 'none' : 'inset 0 1px 2px rgba(255,255,255,0.7), 0 3px 6px rgba(30,18,6,0.4)',
      opacity: disabled ? '0.7' : '1',
    },
    onClick: disabled ? null : onClick,
  }, label);
}

/** Passage renderer — "[12] words…" verse markers to styled sups (ESV API shape). */
function renderPassageText(text) {
  const wrap = el('div', {
    style: { fontSize: '15px', lineHeight: '1.7', color: UI.ink, fontFamily: 'Georgia, serif', textAlign: 'left' },
  });
  const parts = String(text).split(/(\[\d+\])/g);
  for (const p of parts) {
    if (!p) continue;
    const m = p.match(/^\[(\d+)\]$/);
    if (m) {
      wrap.append(el('sup', {
        style: { color: UI.amber, fontWeight: '700', fontSize: '10px', margin: '0 3px 0 6px', fontFamily: UI.font },
      }, m[1]));
    } else wrap.append(p);
  }
  return wrap;
}

/** Charge pips — 5 wick dots, lit vs unlit (never color-only: filled vs hollow). */
function wickPips(charges, max, { size = 11 } = {}) {
  const row = el('span', { style: { display: 'inline-flex', gap: '3px', verticalAlign: 'middle' } });
  for (let i = 0; i < max; i++) {
    const lit = i < charges;
    row.append(el('span', {
      style: {
        width: `${size}px`, height: `${size}px`, borderRadius: '50%',
        border: `1.5px solid ${lit ? UI.amber : '#b1a284'}`,
        background: lit ? 'radial-gradient(circle at 35% 30%, #ffe9a8, #f0a72c)' : 'transparent',
        boxShadow: lit ? '0 0 5px rgba(255,184,69,0.6)' : 'none',
        display: 'inline-block',
      },
      title: lit ? 'charge' : 'spent',
    }));
  }
  return row;
}

function masteryChip(mastery) {
  const tier = masteryTierFor(mastery);
  if (!tier) return null;
  const col = UI.masteryColors[tier];
  return el('span', {
    style: {
      fontSize: '10px', fontWeight: '800', letterSpacing: '1px', color: '#fff',
      background: col, borderRadius: '8px', padding: '2px 7px', textTransform: 'uppercase',
      boxShadow: 'inset 0 1px 1px rgba(255,255,255,0.4)',
    },
    title: `${mastery} correct uses`,
  }, tier);
}

// =============================================================================
// createSatchel(ctx, opts) — model + panel controller
// =============================================================================
export function createSatchel(ctx = {}, opts = {}) {
  const tuning = { ...SATCHEL_TUNING, ...(opts.tuning || {}) };
  const store = makeStorage(ctx.storage);
  const sfx = makeSfx(ctx.sfx, ctx.fanfare);
  const reducedFlash = () => !!(ctx.settings && ctx.settings.reducedFlash);

  // ---------------------------------------------------------------------------
  // Model — the satchel slice of glow-state
  // ---------------------------------------------------------------------------
  /** @type {{v:number, serums:Object, equipped:string[], lastRechargeAt:string|null}} */
  let slice = { v: 1, serums: {}, equipped: [], lastRechargeAt: null };
  let loaded = false;

  const clampCharges = (n) => Math.max(0, Math.min(tuning.maxCharges, Number.isFinite(n) ? Math.round(n) : 0));

  function sanitizeSerum(raw) {
    if (!raw || typeof raw !== 'object' || !raw.ref || !VERSE_FAMILIES[raw.family]) return null;
    const id = raw.id || serumIdForRef(raw.ref);
    return {
      id,
      ref: String(raw.ref),
      family: raw.family,
      charges: clampCharges(raw.charges != null ? raw.charges : tuning.maxCharges),
      mastery: Math.max(0, Number.isFinite(raw.mastery) ? Math.round(raw.mastery) : 0),
      earnedAt: raw.earnedAt || null,
      source: raw.source || null,
      sourceId: raw.sourceId || null,
    };
  }

  /** Equipped-list invariants: known ids, <= cardsPerFamily per family, <= maxEquipped. */
  function enforceLoadout(ids) {
    const seen = new Set();
    const perFamily = {};
    const out = [];
    for (const id of ids) {
      const s = slice.serums[id];
      if (!s || seen.has(id)) continue;
      const fam = s.family;
      if ((perFamily[fam] || 0) >= tuning.cardsPerFamily) continue;
      if (out.length >= tuning.maxEquipped) break;
      seen.add(id);
      perFamily[fam] = (perFamily[fam] || 0) + 1;
      out.push(id);
    }
    return out;
  }

  // --- persistence: read-modify-write on the shared glow-state blob, all writes
  // serialized through one promise chain so foreign slices are never clobbered.
  let saveChain = Promise.resolve();
  let saveTimer = null;
  async function writeThrough() {
    const raw = await store.get(GLOW_STATE_KEY);
    let blob = {};
    if (raw) { try { blob = JSON.parse(raw) || {}; } catch (e) { blob = {}; } } // corrupt blob: rebuild ours, lose nothing knowable
    blob.satchel = slice;
    await store.set(GLOW_STATE_KEY, JSON.stringify(blob));
  }
  function persist() {
    if (saveTimer) return; // coalesce bursts (mint + auto-equip + toast = one write)
    saveTimer = setTimeout(() => {
      saveTimer = null;
      saveChain = saveChain.then(writeThrough).catch(() => { /* offline: next write retries */ });
    }, tuning.saveDebounceMs);
  }
  /** Flush any pending write immediately (call before teardown / zone unload). */
  function flush() {
    if (saveTimer) { clearTimeout(saveTimer); saveTimer = null; }
    saveChain = saveChain.then(writeThrough).catch(() => {});
    return saveChain;
  }

  async function load() {
    const raw = await store.get(GLOW_STATE_KEY);
    if (raw) {
      try {
        const blob = JSON.parse(raw);
        const stored = blob && blob.satchel;
        if (stored && stored.v === 1 && stored.serums) {
          // Merge: anything minted before hydration finished wins over its
          // stored twin (it is newer); stored-only serums are restored.
          const merged = {};
          for (const [id, s] of Object.entries(stored.serums)) {
            const ok = sanitizeSerum({ ...s, id });
            if (ok) merged[id] = ok;
          }
          for (const [id, s] of Object.entries(slice.serums)) merged[id] = s;
          const equipped = enforceLoadoutWith(merged, [...(stored.equipped || []), ...slice.equipped]);
          slice = {
            v: 1,
            serums: merged,
            equipped,
            lastRechargeAt: stored.lastRechargeAt || slice.lastRechargeAt || null,
          };
        }
      } catch (e) { /* corrupt blob: keep the fresh slice */ }
    }
    loaded = true;
    notifyChange();
  }
  // enforceLoadout against an explicit serum map (used during hydration merge)
  function enforceLoadoutWith(serumMap, ids) {
    const keep = slice.serums;
    slice = { ...slice, serums: serumMap };
    const out = enforceLoadout(ids);
    slice = { ...slice, serums: keep };
    return out;
  }
  const ready = load();

  // ---------------------------------------------------------------------------
  // Change notification (HUD badge etc.)
  // ---------------------------------------------------------------------------
  function snapshot() {
    const all = Object.values(slice.serums);
    const equipped = slice.equipped.map((id) => slice.serums[id]).filter(Boolean);
    return {
      total: all.length,
      equippedCount: equipped.length,
      spentCount: all.filter((s) => s.charges < tuning.maxCharges).length,
      emptyEquipped: equipped.filter((s) => s.charges === 0).length,
      needsRecharge: all.some((s) => s.charges < tuning.maxCharges),
    };
  }
  function notifyChange() {
    if (typeof ctx.onChange === 'function') { try { ctx.onChange(snapshot()); } catch (e) { /* HUD hook */ } }
    if (root) renderPanel();      // live-refresh the open panel
    if (hudBadge) refreshHudBadge();
  }

  // ---------------------------------------------------------------------------
  // Model API
  // ---------------------------------------------------------------------------

  /** All owned serums, satchel-wheel family order then earn order. */
  function getSerums() {
    const order = new Map(FAMILY_WHEEL_ORDER.map((f, i) => [f, i]));
    return Object.values(slice.serums).slice().sort((a, b) => {
      const fo = (order.get(a.family) ?? 9) - (order.get(b.family) ?? 9);
      return fo !== 0 ? fo : String(a.earnedAt || '').localeCompare(String(b.earnedAt || ''));
    });
  }
  const getSerum = (id) => slice.serums[id] || null;
  const getEquipped = () => slice.equipped.map((id) => slice.serums[id]).filter(Boolean);

  /**
   * Combat bridge (combat.js ctx contract): equipped cards as
   * [{ id, charges, family, ref }]. combat.js reads id + charges and resolves
   * family/ref itself for ids in the VERSES pool; family/ref ride along for
   * forward-compat with CMS-minted refs outside that pool.
   */
  function getEquippedSerums() {
    return getEquipped().map((s) => ({ id: s.id, charges: s.charges, family: s.family, ref: s.ref }));
  }

  /** Spend one charge (combat casts call this per cast, hit or miss). */
  function spendSerumCharge(serumId) {
    const s = slice.serums[serumId];
    if (!s || s.charges <= 0) return false;
    s.charges -= 1;
    persist();
    notifyChange();
    return true;
  }

  /** Mastery counter: one correct use (a Lightburst) of this serum. */
  function recordSuperEffective(serumId) {
    const s = slice.serums[serumId];
    if (!s) return null;
    const before = masteryTierFor(s.mastery);
    s.mastery += 1;
    const after = masteryTierFor(s.mastery);
    persist();
    notifyChange();
    return after !== before ? after : null;   // 'bronze'|'silver'|'gold' on tier-up
  }

  /**
   * Mint a Truth Serum — THE earn path (memory-verse challenges only: Town Book
   * checks and app plan-day challenges; no serum is purchasable, Ch. 2.3).
   * Townbook bridge signature: { ref, family, lieFamily, source, sourceId }.
   *
   * Re-earning an owned verse refills its charges (the challenge re-read IS a
   * recharge) — small fanfare, never the full mint fanfare (Ch. 5.7: the jingle
   * never plays for something not actually gained).
   *
   * @returns {{ serum, isNew: boolean }|null} null = invalid payload (dev warns)
   */
  function mintSerum(payload = {}) {
    const ref = payload.ref && String(payload.ref).trim();
    let family = payload.family;
    // Family fallbacks: the VERSES pool's tag for this ref, else the counter of
    // the supplied lieFamily (type chart) — never guess beyond that.
    if (!VERSE_FAMILIES[family]) {
      const known = VERSES[serumIdForRef(ref)];
      family = known ? known.family : TYPE_CHART[payload.lieFamily];
    }
    if (!ref || !VERSE_FAMILIES[family]) {
      if (IS_DEV) console.warn('[satchel] mintSerum: bad payload', payload);
      return null;
    }
    const id = serumIdForRef(ref);
    const existing = slice.serums[id];
    if (existing) {
      existing.charges = tuning.maxCharges;
      persist();
      notifyChange();
      showEarnToast(existing, { isNew: false });
      return { serum: existing, isNew: false };
    }
    const serum = {
      id, ref, family,
      charges: tuning.maxCharges,
      mastery: 0,
      earnedAt: new Date().toISOString(),
      source: payload.source || null,
      sourceId: payload.sourceId || null,
    };
    slice.serums[id] = serum;
    autoEquip(id);
    persist();
    notifyChange();
    showEarnToast(serum, { isNew: true });
    return { serum, isNew: true };
  }

  /** Convenience for prologue/quest scripting: mint straight from a VERSES key. */
  function mintByVerseId(verseId, meta = {}) {
    const v = VERSES[verseId];
    if (!v) { if (IS_DEV) console.warn(`[satchel] mintByVerseId: unknown id "${verseId}"`); return null; }
    return mintSerum({ ref: v.ref, family: v.family, ...meta });
  }

  /** Auto-equip a fresh mint when its family wedge has room (quiet no-op otherwise). */
  function autoEquip(id) {
    const s = slice.serums[id];
    if (!s || slice.equipped.includes(id)) return false;
    if (slice.equipped.length >= tuning.maxEquipped) return false;
    const inFamily = slice.equipped.filter((eid) => slice.serums[eid] && slice.serums[eid].family === s.family);
    if (inFamily.length >= tuning.cardsPerFamily) return false;
    slice.equipped.push(id);
    return true;
  }

  /** Player-driven equip. Returns { ok, reason? }. Loadout edits are an
   *  out-of-combat surface only — combat.js locks the loadout during encounters
   *  by snapshotting getEquippedSerums() at encounter start (Ch. 2.3). */
  function equipSerum(id) {
    const s = slice.serums[id];
    if (!s) return { ok: false, reason: 'unknown' };
    if (slice.equipped.includes(id)) return { ok: true };
    if (slice.equipped.length >= tuning.maxEquipped) return { ok: false, reason: 'satchel-full' };
    const inFamily = slice.equipped.filter((eid) => slice.serums[eid] && slice.serums[eid].family === s.family);
    if (inFamily.length >= tuning.cardsPerFamily) return { ok: false, reason: 'family-full' };
    slice.equipped.push(id);
    persist();
    notifyChange();
    return { ok: true };
  }
  function unequipSerum(id) {
    const i = slice.equipped.indexOf(id);
    if (i === -1) return { ok: false, reason: 'not-equipped' };
    slice.equipped.splice(i, 1);
    persist();
    notifyChange();
    return { ok: true };
  }

  /**
   * Recharge-at-library flow (Ch. 2.3 / 3.10): free, instant, diegetic — the
   * librarian re-reads the verse with you and every wick relights. Called by
   * the townbook desk bridge and any library/lantern interaction the Wire
   * phase adds. Refills EVERY owned serum (collection, not just equipped —
   * "one trip to the library refills the satchel").
   *
   * NOT an earn event: relighting wicks gains the player nothing new, so the
   * Lightfound fanfare must NOT play here (Ch. 5.7 rule) — a soft wick-relight
   * chime is the whole ceremony.
   *
   * @returns {number} count of serums that needed (and got) a refill
   */
  function recharge(rechargeOpts = {}) {
    let refilled = 0;
    for (const s of Object.values(slice.serums)) {
      if (s.charges < tuning.maxCharges) { s.charges = tuning.maxCharges; refilled++; }
    }
    if (refilled > 0) {
      slice.lastRechargeAt = new Date().toISOString();
      persist();
      sfx.wick();
      if (root) panelToast(`🕯 ${refilled} wick${refilled === 1 ? '' : 's'} relit — every serum is full again.`);
      notifyChange();
    }
    if (typeof rechargeOpts.onDone === 'function') { try { rechargeOpts.onDone(refilled); } catch (e) { /* hook */ } }
    return refilled;
  }

  // ---------------------------------------------------------------------------
  // Serum-earn toast — center-screen presentation on a soft light bloom with
  // the Lightfound fanfare (Ch. 5.7: full form for a new serum; the small form
  // covers a re-earn refill). Queued so back-to-back mints (Maribel's first
  // study session mints three) present one at a time.
  // ---------------------------------------------------------------------------
  const earnQueue = [];
  let earnShowing = false;

  function showEarnToast(serum, { isNew = true } = {}) {
    earnQueue.push({ serum, isNew });
    if (!earnShowing) nextEarnToast();
  }
  function nextEarnToast() {
    const item = earnQueue.shift();
    if (!item) { earnShowing = false; return; }
    earnShowing = true;
    ensureStyles();
    const { serum, isNew } = item;
    const mount = ctx.mountEl || document.body;
    const fam = VERSE_FAMILIES[serum.family];
    const lieFam = LIE_FAMILIES[COUNTERED_LIE[serum.family]];
    const gist = VERSES[serum.id] ? VERSES[serum.id].gist : null;

    sfx.fanfare(isNew ? 'full' : 'small');

    const wrap = el('div', {
      style: {
        position: 'fixed', inset: '0', zIndex: '60', display: 'flex', alignItems: 'center',
        justifyContent: 'center', pointerEvents: 'none', fontFamily: UI.font,
      },
    });
    // Soft light bloom behind the card (reduced-flash: skip the bloom, keep the card)
    if (!reducedFlash()) {
      wrap.append(el('div', {
        style: {
          position: 'absolute', width: '340px', height: '340px', borderRadius: '50%',
          background: 'radial-gradient(circle, rgba(255,225,150,0.85) 0%, rgba(255,200,94,0.35) 45%, rgba(255,200,94,0) 70%)',
          animation: 'gsBloom 1.6s ease-out forwards',
        },
      }));
    }
    const card = el('div', {
      style: {
        position: 'relative', width: 'min(86vw, 320px)', textAlign: 'center',
        background: UI.cardBg, border: `2px solid ${UI.gold}`, borderRadius: '16px',
        boxShadow: UI.panelShadow, color: UI.ink, padding: '18px 18px 16px',
        animation: reducedFlash() ? 'gsFadeUp 0.3s ease-out' : 'gsEarnPop 0.45s ease-out',
        pointerEvents: 'auto', cursor: 'pointer',
      },
      onClick: dismiss,
    }, ...corners());
    card.append(
      el('div', { style: { fontSize: '11px', letterSpacing: '2px', fontWeight: '800', color: UI.amber, textTransform: 'uppercase' } },
        isNew ? '✨ New Truth Serum ✨' : '🕯 Serum Recharged'),
      el('div', { style: { fontSize: '34px', margin: '8px 0 2px', animation: reducedFlash() ? 'none' : 'gsWickLight 0.7s ease-out' } },
        VERSE_FAMILY_GLYPHS[serum.family] || '📜'),
      el('div', { style: { fontSize: '21px', fontWeight: '800', margin: '2px 0' } }, serum.ref),
      el('div', { style: { fontSize: '12px', color: UI.inkSoft, fontWeight: '700', marginBottom: gist ? '6px' : '10px' } },
        `${fam ? fam.label : serum.family} — answers ${lieFam ? lieFam.label : 'its lie'} ${LIE_FAMILY_GLYPHS[COUNTERED_LIE[serum.family]] || ''}`),
      gist ? el('div', { style: { fontSize: '13px', fontStyle: 'italic', color: UI.inkSoft, marginBottom: '10px' } }, `“${gist}”`) : null,
      el('div', { style: { display: 'flex', justifyContent: 'center' } }, wickPips(tuning.maxCharges, tuning.maxCharges, { size: 12 })),
    );
    wrap.append(card);
    mount.appendChild(wrap);

    let done = false;
    const timer = setTimeout(dismiss, tuning.earnToastSec * 1000);
    function dismiss() {
      if (done) return;
      done = true;
      clearTimeout(timer);
      wrap.style.transition = 'opacity 0.25s';
      wrap.style.opacity = '0';
      setTimeout(() => { wrap.remove(); nextEarnToast(); }, 260);
    }
  }

  // ---------------------------------------------------------------------------
  // Satchel panel (opened from the HUD) — collection browser, loadout editor,
  // reader, recharge surface. 2D overlay; zero 3D draw calls.
  // ---------------------------------------------------------------------------
  let root = null, body = null, toastBox = null;
  let panelState = null; // { screen: 'shelf' } | { screen: 'read', serumId, passage: null|obj, loading }
  let readSeq = 0;

  function panelToast(msg) {
    if (!toastBox) return;
    const t = el('div', {
      style: {
        background: 'linear-gradient(180deg, #fff7e2, #f2e2ba)', border: `1.5px solid ${UI.gold}`,
        color: UI.ink, borderRadius: '10px', padding: '7px 14px', fontSize: '12.5px', fontWeight: '700',
        boxShadow: '0 4px 10px rgba(30,18,6,0.4)', animation: 'gsToast 2.8s forwards', pointerEvents: 'none',
      },
    }, msg);
    toastBox.append(t);
    setTimeout(() => t.remove(), 2900);
  }

  function closePanel() {
    if (!root) return;
    root.remove();
    root = body = toastBox = null;
    panelState = null;
    if (typeof ctx.onClose === 'function') { try { ctx.onClose(); } catch (e) { /* game hook */ } }
  }

  async function openPanel() {
    if (root) return;
    ensureStyles();
    if (!loaded) { try { await ready; } catch (e) { /* offline: open with what we have */ } }
    const mount = ctx.mountEl || document.body;
    root = el('div', {
      style: {
        position: 'fixed', inset: '0', zIndex: '40', display: 'flex', alignItems: 'center',
        justifyContent: 'center', fontFamily: UI.font, userSelect: 'none', WebkitUserSelect: 'none',
      },
    });
    root.append(el('div', { style: { position: 'absolute', inset: '0', background: UI.scrim }, onClick: () => { sfx.click(); closePanel(); } }));
    const panel = el('div', {
      style: {
        position: 'relative', width: 'min(94vw, 520px)', maxHeight: 'min(88vh, 740px)',
        display: 'flex', flexDirection: 'column', background: UI.leather,
        border: `2px solid ${UI.wood}`, borderRadius: '18px', boxShadow: UI.panelShadow,
        color: UI.ink, padding: '16px 16px calc(14px + env(safe-area-inset-bottom, 0px))',
        animation: 'gsPop 0.22s ease-out',
      },
    }, ...corners());
    panel.append(el('button', {
      style: {
        position: 'absolute', top: '8px', right: '10px', zIndex: '2', width: '30px', height: '30px',
        borderRadius: '50%', border: `1.5px solid ${UI.wood}`, background: 'linear-gradient(180deg,#fff4da,#eeddb2)',
        color: UI.ink, fontWeight: '800', fontSize: '14px', cursor: 'pointer', fontFamily: 'inherit',
      },
      onClick: () => { sfx.click(); closePanel(); },
    }, '✕'));
    toastBox = el('div', {
      style: {
        position: 'absolute', top: '-6px', left: '50%', transform: 'translate(-50%, -100%)',
        display: 'flex', flexDirection: 'column', gap: '6px', alignItems: 'center', width: 'max-content',
        maxWidth: '92vw', pointerEvents: 'none',
      },
    });
    body = el('div', { style: { overflowY: 'auto', overscrollBehavior: 'contain', flex: '1', minHeight: '0', WebkitOverflowScrolling: 'touch' } });
    panel.append(toastBox, body);
    root.append(panel);
    mount.appendChild(root);
    panelState = { screen: 'shelf' };
    renderPanel();
  }

  function renderPanel() {
    if (!root || !panelState) return;
    body.replaceChildren();
    if (panelState.screen === 'read') renderReader();
    else renderShelf();
  }

  // --- shelf: six family wedges in wheel order, each with its cards ---
  function renderShelf() {
    body.append(ribbon('VERSE SATCHEL'));
    const equippedCount = slice.equipped.length;
    body.append(el('div', { style: { textAlign: 'center', fontSize: '12px', color: UI.inkSoft, fontWeight: '700', marginBottom: '10px' } },
      `Equipped ${equippedCount}/${tuning.maxEquipped} · ${tuning.cardsPerFamily} per family · charges refill free at any library`));

    // Recharge surface: active at a library/reading desk, otherwise a signpost.
    const snap = snapshot();
    const atLib = typeof ctx.atLibrary === 'function' ? !!safeCall(ctx.atLibrary) : false;
    if (snap.needsRecharge) {
      body.append(el('div', {
        style: {
          display: 'flex', alignItems: 'center', gap: '10px', justifyContent: 'space-between',
          background: 'linear-gradient(180deg, #fff3d6, #f4e2b4)', border: `1.5px dashed ${UI.gold}`,
          borderRadius: '12px', padding: '9px 12px', margin: '0 0 12px', fontSize: '12.5px', fontWeight: '700',
        },
      },
        el('span', null, atLib
          ? '🕯 The librarian is here — re-read together and relight every wick.'
          : '🕯 Spent wicks relight free at any library reading desk.'),
        atLib ? button('Recharge', { kind: 'green', small: true }, () => { sfx.click(); recharge({ source: 'panel' }); }) : null,
      ));
    }

    const serums = getSerums();
    if (!serums.length) {
      body.append(el('div', { style: { textAlign: 'center', padding: '30px 12px', color: UI.inkSoft, fontSize: '14px', lineHeight: '1.6' } },
        el('div', { style: { fontSize: '40px', marginBottom: '8px' } }, '🎒'),
        'The satchel is empty. Truth Serums are earned by memory-verse',
        el('br'), 'challenges — at the library reading desk, and from your daily reading.'));
      return;
    }

    for (const familyId of FAMILY_WHEEL_ORDER) {
      const fam = VERSE_FAMILIES[familyId];
      const lieFam = LIE_FAMILIES[COUNTERED_LIE[familyId]];
      const cards = serums.filter((s) => s.family === familyId);
      const sect = el('div', { style: { marginBottom: '12px' } });
      sect.append(el('div', {
        style: {
          display: 'flex', alignItems: 'center', gap: '8px', padding: '4px 2px', fontWeight: '800',
          fontSize: '13.5px', color: UI.ink, borderBottom: `2px solid ${lieFam ? lieFam.color : UI.gold}`,
          marginBottom: '6px',
        },
      },
        el('span', { style: { fontSize: '16px' } }, VERSE_FAMILY_GLYPHS[familyId] || '📜'),
        fam.label,
        el('span', { style: { fontSize: '11px', color: UI.inkSoft, fontWeight: '700' } },
          `answers ${lieFam ? lieFam.label : ''} ${LIE_FAMILY_GLYPHS[COUNTERED_LIE[familyId]] || ''}`),
        el('span', { style: { marginLeft: 'auto', fontSize: '11px', color: UI.inkSoft, fontWeight: '700' } },
          cards.length ? `${cards.filter((c) => slice.equipped.includes(c.id)).length}/${Math.min(cards.length, tuning.cardsPerFamily)} equipped` : '—'),
      ));
      if (!cards.length) {
        sect.append(el('div', { style: { fontSize: '12px', color: UI.inkSoft, fontStyle: 'italic', padding: '2px 4px 6px' } },
          'No serums yet — keep reading and studying.'));
      } else {
        for (const s of cards) sect.append(serumCard(s));
      }
      body.append(sect);
    }
  }

  function serumCard(s) {
    const equipped = slice.equipped.includes(s.id);
    const spent = s.charges === 0;
    const gist = VERSES[s.id] ? VERSES[s.id].gist : null;
    const row = el('div', {
      style: {
        display: 'flex', alignItems: 'center', gap: '10px',
        background: spent ? UI.cardSpentBg : UI.cardBg,
        border: `1.5px solid ${equipped ? UI.gold : '#c9b58a'}`,
        boxShadow: equipped ? `inset 0 0 0 1px ${UI.goldBright}, 0 2px 6px rgba(30,18,6,0.25)` : '0 1px 4px rgba(30,18,6,0.18)',
        borderRadius: '12px', padding: '8px 10px', marginBottom: '6px',
        opacity: spent ? '0.85' : '1',
      },
    });
    const info = el('div', {
      style: { flex: '1', minWidth: '0', cursor: 'pointer' },
      onClick: () => { sfx.click(); openReader(s.id); },
      title: 'Read the full verse',
    },
      el('div', { style: { display: 'flex', alignItems: 'center', gap: '7px', flexWrap: 'wrap' } },
        el('span', { style: { fontWeight: '800', fontSize: '14px' } }, s.ref),
        masteryChip(s.mastery),
        spent ? el('span', { style: { fontSize: '10px', fontWeight: '800', color: '#8a7a58', letterSpacing: '1px' } }, '🕯 SPENT') : null,
      ),
      gist ? el('div', {
        style: {
          fontSize: '12px', color: UI.inkSoft, fontStyle: 'italic', whiteSpace: 'nowrap',
          overflow: 'hidden', textOverflow: 'ellipsis',
        },
      }, gist) : null,
      el('div', { style: { marginTop: '3px' } }, wickPips(s.charges, tuning.maxCharges)),
    );
    const actions = el('div', { style: { display: 'flex', flexDirection: 'column', gap: '5px', alignItems: 'stretch' } },
      button(equipped ? 'Unequip' : 'Equip', { kind: equipped ? 'plain' : 'gold', small: true }, () => {
        if (equipped) { sfx.click(); unequipSerum(s.id); panelToast(`${s.ref} tucked away.`); }
        else {
          const r = equipSerum(s.id);
          if (r.ok) { sfx.equip(); panelToast(`${s.ref} equipped!`); }
          else {
            sfx.wrong();
            panelToast(r.reason === 'family-full'
              ? `That family wedge is full (${tuning.cardsPerFamily} cards).`
              : 'The satchel is full — unequip something first.');
          }
        }
      }),
      button('Read', { kind: 'plain', small: true }, () => { sfx.click(); openReader(s.id); }),
    );
    row.append(info, actions);
    return row;
  }

  // --- reader: full verse text, runtime-fetched, gracefully degrading ---
  function openReader(serumId) {
    panelState = { screen: 'read', serumId, passage: null, loading: true };
    renderPanel();
    const seq = ++readSeq;
    fetchPassageSafe(getSerum(serumId) ? getSerum(serumId).ref : '').then((res) => {
      if (seq !== readSeq || !panelState || panelState.screen !== 'read' || panelState.serumId !== serumId) return;
      panelState.passage = res;
      panelState.loading = false;
      renderPanel();
    });
  }

  const passageCache = new Map();
  async function fetchPassageSafe(ref) {
    if (!ref) return { error: 'translation_unavailable' };
    if (passageCache.has(ref)) return passageCache.get(ref);
    if (typeof ctx.fetchPassage !== 'function') {
      if (IS_DEV) console.warn('[satchel] ctx.fetchPassage not wired — reader degrades to ref + gist');
      return { error: 'translation_unavailable' };
    }
    let res;
    try { res = await ctx.fetchPassage(ref); } catch (e) { res = { error: 'network' }; }
    if (res && res.text && !res.error) passageCache.set(ref, res);
    return res || { error: 'translation_unavailable' };
  }

  function renderReader() {
    const s = getSerum(panelState.serumId);
    if (!s) { panelState = { screen: 'shelf' }; renderShelf(); return; }
    const fam = VERSE_FAMILIES[s.family];
    const lieFam = LIE_FAMILIES[COUNTERED_LIE[s.family]];
    const gist = VERSES[s.id] ? VERSES[s.id].gist : null;

    body.append(
      el('div', { style: { marginBottom: '8px' } },
        button('← Satchel', { kind: 'plain', small: true }, () => { sfx.click(); panelState = { screen: 'shelf' }; renderPanel(); })),
      el('div', { style: { textAlign: 'center', marginBottom: '10px' } },
        el('div', { style: { fontSize: '30px' } }, VERSE_FAMILY_GLYPHS[s.family] || '📜'),
        el('div', { style: { fontSize: '20px', fontWeight: '800' } }, s.ref),
        el('div', { style: { fontSize: '12px', color: UI.inkSoft, fontWeight: '700', marginTop: '2px' } },
          `${fam.label} — answers ${lieFam ? lieFam.label : ''} ${LIE_FAMILY_GLYPHS[COUNTERED_LIE[s.family]] || ''}`),
        el('div', { style: { marginTop: '6px', display: 'flex', justifyContent: 'center', alignItems: 'center', gap: '8px' } },
          wickPips(s.charges, tuning.maxCharges, { size: 12 }), masteryChip(s.mastery)),
      ),
    );

    const page = el('div', {
      style: {
        background: UI.cardBg, border: `1.5px solid #c9b58a`, borderRadius: '12px',
        padding: '14px 16px', minHeight: '90px',
      },
    });
    if (panelState.loading) {
      page.append(el('div', { style: { display: 'flex', alignItems: 'center', gap: '10px', color: UI.inkSoft, fontSize: '13px', fontWeight: '700' } },
        el('span', {
          style: {
            width: '16px', height: '16px', border: `2.5px solid ${UI.gold}`, borderTopColor: 'transparent',
            borderRadius: '50%', display: 'inline-block', animation: 'gsSpin 0.8s linear infinite',
          },
        }), 'Fetching the verse…'));
    } else if (panelState.passage && panelState.passage.text && !panelState.passage.error) {
      const p = panelState.passage;
      page.append(renderPassageText(p.text));
      page.append(el('div', { style: { fontSize: '10.5px', color: UI.inkSoft, marginTop: '10px', textAlign: 'right' } },
        p.copyright || `(${p.translation || 'ESV'})`));
    } else {
      // Graceful degradation (LOCKED): reference + original gist, never bundled text.
      page.append(
        gist ? el('div', { style: { fontSize: '14.5px', fontStyle: 'italic', lineHeight: '1.6', color: UI.ink } }, `“${gist}”`)
             : el('div', { style: { fontSize: '13px', color: UI.inkSoft } }, 'Open your Bible to this verse — the words are worth the trip.'),
        el('div', { style: { fontSize: '11px', color: UI.inkSoft, marginTop: '10px' } },
          '📜 The full text couldn’t be fetched right now. ',
          el('a', {
            style: { color: UI.amber, fontWeight: '700', cursor: 'pointer', textDecoration: 'underline' },
            onClick: () => { sfx.click(); openReader(s.id); },
          }, 'Try again')),
      );
    }
    body.append(page);
    if (s.charges < tuning.maxCharges) {
      body.append(el('div', { style: { fontSize: '11.5px', color: UI.inkSoft, fontWeight: '700', textAlign: 'center', marginTop: '10px' } },
        '🕯 Visit any library reading desk to relight this serum’s wicks — free, always.'));
    }
  }

  // ---------------------------------------------------------------------------
  // HUD button — a satchel toggle the Wire phase can drop into the game HUD.
  // Positioning is the caller's job (it lays out the HUD); the badge shows the
  // equipped count and warns (❕) when equipped cards are out of charges.
  // ---------------------------------------------------------------------------
  let hudBtn = null, hudBadge = null;
  function mountHudButton(parent) {
    if (hudBtn) return hudBtn;
    ensureStyles();
    hudBtn = el('button', {
      style: {
        position: 'relative', width: '48px', height: '48px', borderRadius: '50%',
        border: `2px solid ${UI.wood}`, background: UI.goldBtn, cursor: 'pointer',
        fontSize: '22px', lineHeight: '1', boxShadow: 'inset 0 1px 2px rgba(255,255,255,0.7), 0 3px 6px rgba(30,18,6,0.4)',
        fontFamily: UI.font,
      },
      title: 'Verse Satchel',
      onClick: () => { sfx.click(); openPanel(); },
    }, '🎒');
    hudBadge = el('span', {
      style: {
        position: 'absolute', top: '-4px', right: '-4px', minWidth: '18px', height: '18px',
        borderRadius: '9px', background: '#fff6df', border: `1.5px solid ${UI.wood}`,
        color: UI.ink, fontSize: '10.5px', fontWeight: '800', display: 'none',
        alignItems: 'center', justifyContent: 'center', padding: '0 4px', lineHeight: '1',
      },
    });
    hudBtn.append(hudBadge);
    refreshHudBadge();
    (parent || ctx.mountEl || document.body).appendChild(hudBtn);
    return hudBtn;
  }
  function refreshHudBadge() {
    if (!hudBadge) return;
    const snap = snapshot();
    if (!snap.total) { hudBadge.style.display = 'none'; return; }
    hudBadge.style.display = 'inline-flex';
    hudBadge.textContent = snap.emptyEquipped > 0 ? `${snap.equippedCount}❕` : String(snap.equippedCount);
    hudBadge.title = snap.emptyEquipped > 0 ? `${snap.emptyEquipped} equipped serum(s) out of charges` : `${snap.equippedCount} serums equipped`;
  }

  function safeCall(fn) { try { return fn(); } catch (e) { return undefined; } }

  function dispose() {
    closePanel();
    if (hudBtn) { hudBtn.remove(); hudBtn = null; hudBadge = null; }
    flush();
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------
  return {
    // lifecycle
    ready, load, flush, dispose,
    // model
    getSerums, getSerum, getEquipped, snapshot,
    equipSerum, unequipSerum,
    mintSerum, mintByVerseId,
    recharge,
    rechargeAll: recharge,          // alias — some call sites read better with it
    recordSuperEffective,
    // combat.js ctx bridge
    getEquippedSerums, spendSerumCharge,
    // UI
    openPanel, closePanel, isOpen: () => !!root,
    mountHudButton,
    showEarnToast,
  };
}

export default createSatchel;
