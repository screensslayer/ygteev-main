// =============================================================================
// glowlands/combat.js
// Truth & Light encounter engine + battle UI overlay (DOM).
//
// Design authority: /docs/glowlands-design.md — Ch. 2 (Truth & Light), Ch. 7
// (Meadow Town / First Shadow), Roads interlude (East Road patrols), Ch. 5.7
// (Lightfound fanfare), Ch. 17 (Phase 1 slice). Data: ./data/combat-data.js.
//
// Combat is an argument you win, not a body you break. No HP, no damage, no
// death. The fear vignette is the only pressure meter; failure resolves via
// the Fade path (wake at the nearest lit lantern — repositioning is the
// CALLER's job, this module only reports outcome:'fade').
//
// -----------------------------------------------------------------------------
// PUBLIC API
//   startEncounter(ctx, id) -> Promise<EncounterResult>
//     id resolves in order against:
//       1. EAST_ROAD_ENCOUNTERS[].id  (road patrol — rolls units per spawner contract)
//       2. FIRST_SHADOW.id            ('first_shadow' — 3-phase boss)
//       3. GLOOMLINGS keys            ('whisperling' — single ad-hoc/tutorial fight)
//
// EncounterResult = {
//   encounterId, kind: 'patrol'|'gloomling'|'boss',
//   outcome: 'victory'|'fade'|'retreat'|'clear-empty',   // clear-empty = every
//            unit skip-spawned (no-soft-lock rule): counts as clear, no rewards
//   zone, clearedLies: string[],                          // lie ids answered
//   missLog: [{ lie_id, counter_verse_ref, zone, timestamp }],  // Ch. 13.6 contract
//   chargeSpends: { [serumId]: n },                       // for callers without spendSerumCharge
//   sparks, xp, gold,                                     // gold is 0 by design (Ch. 2.1:
//                                                         // combat never drops gold)
//   waymarkerId?, relightsWaymarker?                      // road patrols only; true on clear
// }
//
// -----------------------------------------------------------------------------
// ctx CONTRACT (Wire phase supplies this; every method is optional-safe — the
// module degrades gracefully so it can be exercised standalone in dev):
//   ctx.fetchPassage(ref) -> Promise<{reference, translation, text}|{error}>
//       RUNTIME ESV via the get-bible-passage edge function. May 503
//       ({error:'translation_unavailable'}) until the ESV key is configured —
//       every text surface here degrades to `ref` + `gist` (original prose).
//       NO VERSE TEXT IS EVER BUNDLED IN THIS FILE.
//   ctx.getEquippedSerums() -> [{ id, charges }]  ids are VERSES keys.
//       Dev fallback: prologue starters + first study mints, full charges.
//   ctx.spendSerumCharge(serumId)      persist one charge spent (also reported
//                                      in result.chargeSpends either way)
//   ctx.awardXp(n) / ctx.awardGold(n) / ctx.awardSparks(n)   rewards on win
//   ctx.logMiss({lie_id, counter_verse_ref, zone, timestamp}) global miss-log
//   ctx.setTimeDilation(mult)          0.25 while the encounter runs, 1 after
//   ctx.duckAmbient(on)                −6 dB ambient duck hook
//   ctx.isDusk() -> bool               road patrols: dusk density multiplier
//   ctx.settings = { calmMode, reducedFlash }              accessibility
//   ctx.mount                          overlay parent (default document.body)
//   ctx.random() -> [0,1)              seedable RNG (default Math.random)
// =============================================================================

import {
  COMBAT_TUNING,
  LIE_FAMILIES,
  EFFECTIVENESS,
  resolveCast,
  VERSES,
  STARTER_SERUMS,
  FIRST_STUDY_SESSION_MINTS,
  LIES,
  GLOOMLINGS,
  FIRST_SHADOW,
  EAST_ROAD_ENCOUNTERS,
  filterDealableLies,
} from './data/combat-data.js';

// -----------------------------------------------------------------------------
// Theme — mirrors dragon-garden-quest.jsx's overlay/dialog visual language
// (S.panel / WOOD_TEX / Corners / gold buttons) so the battle overlay reads as
// the same game. Values copied, not imported: that file must stay untouched.
// -----------------------------------------------------------------------------
const GOLD = '#2f7fc1';
const GOLD_BRIGHT = '#ffb845';
const PARCH = '#17497e';
const WOOD = 'linear-gradient(180deg, #ffffff 0%, #edf7fd 55%, #d8edfb 100%)';
const WOOD_TEX =
  'radial-gradient(130% 90% at 50% -25%, rgba(255,255,255,0.95), rgba(255,255,255,0) 55%), ' +
  'linear-gradient(180deg, #ffffff 0%, #e9f5fd 50%, #cfe9fa 100%)';
const GOLD_BTN_BG = 'linear-gradient(180deg, #ffc85e, #f0931c)';
const FONT = "'Trebuchet MS', 'Segoe UI', sans-serif";
const PANEL_SHADOW =
  'inset 0 0 0 2px rgba(255,255,255,0.85), inset 0 -3px 8px rgba(47,127,193,0.16), 0 8px 18px rgba(23,73,126,0.28)';

/** Family icon glyphs (families are never color-only — icon + fixed wheel slot). */
const FAMILY_GLYPHS = {
  isolation: '◌', condemnation: '⛓', fear: '👁', worthlessness: '🪞', despair: '🍂', doubt: '🏮',
};
const VERSE_FAMILY_GLYPHS = {
  presence: '🤝', grace: '🕊', courage: '🦁', identity: '🌟', hope: '🌅', trust: '🧭',
};

/** XP per repelled unit (tunable; road XP daily cap enforced by the road layer). */
const XP_REWARDS = { trash: 5, elite: 12, boss: 40 };

// =============================================================================
// Tiny sound kit — WebAudio, self-contained, mirroring the main game's synth
// grammar (tone / noiseBurst on a modest sfx bus). Lazy: nothing is created
// until the first encounter, and iOS resume is attempted on each play.
// =============================================================================
const snd = (() => {
  let AC = null, bus = null;
  function ensure() {
    if (AC) { if (AC.state === 'suspended') AC.resume().catch(() => {}); return true; }
    try { AC = new (window.AudioContext || window.webkitAudioContext)(); } catch (e) { return false; }
    bus = AC.createGain(); bus.gain.value = 0.5; bus.connect(AC.destination);
    return true;
  }
  function tone(freq, at, dur, vol, type = 'triangle', slideTo = null, lp = null) {
    if (!ensure()) return;
    const t = AC.currentTime + at;
    const o = AC.createOscillator(); o.type = type; o.frequency.setValueAtTime(freq, t);
    if (slideTo) o.frequency.exponentialRampToValueAtTime(Math.max(20, slideTo), t + dur);
    const g = AC.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(vol, t + 0.015);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    let last = o;
    if (lp) { const f = AC.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = lp; o.connect(f); last = f; }
    last.connect(g); g.connect(bus);
    o.start(t); o.stop(t + dur + 0.05);
  }
  function noise(at, dur, vol, freq = 800, q = 1, ftype = 'bandpass', freqEnd = null) {
    if (!ensure()) return;
    const t = AC.currentTime + at;
    const b = AC.createBuffer(1, Math.max(1, Math.floor(AC.sampleRate * dur)), AC.sampleRate);
    const d = b.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
    const src = AC.createBufferSource(); src.buffer = b;
    const f = AC.createBiquadFilter(); f.type = ftype; f.frequency.setValueAtTime(freq, t); f.Q.value = q;
    if (freqEnd) f.frequency.exponentialRampToValueAtTime(freqEnd, t + dur);
    const g = AC.createGain(); g.gain.setValueAtTime(vol, t); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    src.connect(f); f.connect(g); g.connect(bus);
    src.start(t); src.stop(t + dur);
  }
  /** Looped whisper bed while a lie is live. Returns a stop(). */
  function whisper() {
    if (!ensure()) return () => {};
    const b = AC.createBuffer(1, Math.floor(AC.sampleRate * 2), AC.sampleRate);
    const d = b.getChannelData(0);
    let last = 0;
    for (let i = 0; i < d.length; i++) { const w = Math.random() * 2 - 1; last = last * 0.97 + w * 0.03; d[i] = last * 3; }
    const src = AC.createBufferSource(); src.buffer = b; src.loop = true;
    const f = AC.createBiquadFilter(); f.type = 'bandpass'; f.frequency.value = 900; f.Q.value = 0.8;
    // slow LFO on the filter = breathy "voices" without any real speech
    const lfo = AC.createOscillator(); lfo.frequency.value = 0.31;
    const lfoGain = AC.createGain(); lfoGain.gain.value = 350;
    lfo.connect(lfoGain); lfoGain.connect(f.frequency);
    const g = AC.createGain(); g.gain.setValueAtTime(0.0001, AC.currentTime);
    g.gain.linearRampToValueAtTime(0.055, AC.currentTime + 1.2);
    src.connect(f); f.connect(g); g.connect(bus);
    src.start(); lfo.start();
    return () => {
      try {
        g.gain.setTargetAtTime(0.0001, AC.currentTime, 0.15);
        src.stop(AC.currentTime + 0.6); lfo.stop(AC.currentTime + 0.6);
      } catch (e) {}
    };
  }
  return {
    click() { tone(880, 0, 0.06, 0.12, 'square', null, 2200); },
    open() { tone(392, 0, 0.1, 0.1); tone(523.25, 0.06, 0.12, 0.1); },
    /** The Lightburst: whisper hiss reversed into a warm chime (Ch. 7.8). */
    lightburst() {
      noise(0, 0.35, 0.16, 300, 1.4, 'bandpass', 3200);   // rising hiss
      tone(523.25, 0.3, 0.5, 0.2); tone(659.25, 0.38, 0.5, 0.18);
      tone(783.99, 0.46, 0.7, 0.16); tone(1046.5, 0.54, 0.9, 0.12, 'sine');
    },
    fizzle() { tone(180, 0, 0.25, 0.16, 'sawtooth', 90, 500); noise(0, 0.2, 0.08, 500, 1, 'lowpass'); },
    lieForms() { noise(0, 0.7, 0.06, 240, 0.8, 'lowpass'); tone(110, 0, 0.6, 0.05, 'sine', 80); },
    /**
     * The Lightfound fanfare (Ch. 5.7): bright ascending bells + plucked
     * strings resolving to the lantern leitmotif's first interval. One jingle,
     * everywhere, always the same melody. full=false is the 0.8 s pickup form.
     */
    fanfare(full = true) {
      const seq = full
        ? [[523.25, 0], [659.25, 0.12], [783.99, 0.24], [1046.5, 0.38], [783.99, 0.62], [1174.66, 0.78]]
        : [[659.25, 0], [783.99, 0.1], [1046.5, 0.22]];
      seq.forEach(([f, at]) => { tone(f, at, 0.5, 0.2); tone(f * 2, at, 0.28, 0.07, 'sine'); });
      if (full) tone(587.33, 1.0, 0.9, 0.12, 'sine'); // leitmotif resolve
    },
    heartbeat() { [0, 0.32, 0.9, 1.22].forEach((at, i) => tone(55, at, 0.16, i % 2 ? 0.14 : 0.2, 'sine', 40)); },
    lanternChime(i) { const penta = [523.25, 587.33, 659.25, 783.99, 880, 1046.5, 1174.66, 1318.5]; tone(penta[i % penta.length], 0, 0.4, 0.13); },
    timerTick() { tone(1200, 0, 0.03, 0.05, 'square'); },
    whisper,
  };
})();

// =============================================================================
// DOM helpers + injected stylesheet (keyframes the overlay animations need)
// =============================================================================
function el(tag, style, props) {
  const n = document.createElement(tag);
  if (style) Object.assign(n.style, style);
  if (props) {
    for (const k of Object.keys(props)) {
      if (k === 'text') n.textContent = props[k];
      else if (k === 'html') n.innerHTML = props[k];
      else n[k] = props[k];
    }
  }
  return n;
}

const CSS_ID = 'glowlands-combat-css';
function injectStyles() {
  if (document.getElementById(CSS_ID)) return;
  const s = document.createElement('style');
  s.id = CSS_ID;
  s.textContent = `
@keyframes gcDrift { 0%{transform:translate(0,0) rotate(0deg)} 33%{transform:translate(4px,-5px) rotate(0.6deg)} 66%{transform:translate(-4px,-2px) rotate(-0.6deg)} 100%{transform:translate(0,0) rotate(0deg)} }
@keyframes gcPulse { 0%,100%{opacity:0.75; transform:scale(1)} 50%{opacity:1; transform:scale(1.12)} }
@keyframes gcSway { 0%,100%{transform:translateX(-4px) skewX(-2deg)} 50%{transform:translateX(4px) skewX(2deg)} }
@keyframes gcShake { 0%,100%{transform:translateX(0)} 20%{transform:translateX(-7px)} 40%{transform:translateX(6px)} 60%{transform:translateX(-4px)} 80%{transform:translateX(3px)} }
@keyframes gcSlideUp { from{opacity:0; transform:translateY(16px)} to{opacity:1; transform:translateY(0)} }
@keyframes gcFadeIn { from{opacity:0} to{opacity:1} }
@keyframes gcFlare { 0%{opacity:0; transform:scale(0.35)} 18%{opacity:1; transform:scale(1)} 80%{opacity:1; transform:scale(1.04)} 100%{opacity:0; transform:scale(1.1)} }
@keyframes gcFirefly { 0%{opacity:1; transform:translate(0,0) scale(1)} 100%{opacity:0; transform:translate(var(--fx),var(--fy)) scale(0.3)} }
@keyframes gcBloom { 0%{box-shadow:0 0 0 rgba(255,214,120,0)} 50%{box-shadow:0 0 70px rgba(255,214,120,0.85)} 100%{box-shadow:0 0 26px rgba(255,214,120,0.4)} }
@keyframes gcCascade { 0%{opacity:0; transform:scale(0.2)} 45%{opacity:1} 100%{opacity:0; transform:scale(2.6)} }
@keyframes gcWickFlicker { 0%,100%{opacity:1} 50%{opacity:0.55} }
.gc-card:not([disabled]):active { transform: scale(0.96); }
.gc-wedge:not([disabled]):active { transform: scale(0.94); }
`;
  document.head.appendChild(s);
}

// =============================================================================
// Satchel state — local working copy of the equipped loadout for one encounter.
// Loadout is locked during encounters (Ch. 2.3), so a snapshot is correct.
// =============================================================================
function buildSatchel(ctx) {
  let equipped = null;
  try { equipped = ctx.getEquippedSerums ? ctx.getEquippedSerums() : null; } catch (e) { equipped = null; }
  if (!Array.isArray(equipped) || equipped.length === 0) {
    // Dev/demo fallback: the prologue-guaranteed grants at full charge.
    equipped = [...STARTER_SERUMS, ...FIRST_STUDY_SESSION_MINTS]
      .map((id) => ({ id, charges: COMBAT_TUNING.serumCharges }));
  }
  const perFamily = {};
  const cards = [];
  for (const e of equipped) {
    const v = VERSES[e.id];
    if (!v) continue;
    perFamily[v.family] = (perFamily[v.family] || 0) + 1;
    if (perFamily[v.family] > COMBAT_TUNING.loadout.cardsPerFamily) continue; // 3-per-family loadout rule
    if (cards.length >= COMBAT_TUNING.loadout.maxEquipped) break;
    cards.push({
      id: e.id, ref: v.ref, family: v.family, gist: v.gist,
      charges: Math.max(0, Math.min(COMBAT_TUNING.serumCharges, e.charges ?? COMBAT_TUNING.serumCharges)),
      greyedOut: false, // per-encounter grey-out (fizzle rule)
    });
  }
  return cards;
}

// =============================================================================
// The encounter session — one overlay, reused across every lie/unit/phase of a
// single startEncounter() call.
// =============================================================================
class Session {
  constructor(ctx, meta) {
    this.ctx = ctx;
    this.meta = meta;                          // { encounterId, kind, zone }
    this.rand = typeof ctx.random === 'function' ? ctx.random : Math.random;
    this.settings = ctx.settings || {};
    this.satchel = buildSatchel(ctx);
    this.passageCache = new Map();             // ref -> {text?, reference} | null
    this.fear = 0.12;                          // vignette 0..1 (mood floor, not zero)
    this.fearRAF = null;
    this.fearRunning = false;
    this.fearPaused = false;
    this.clearedLies = [];
    this.missLog = [];
    this.chargeSpends = {};
    this.sparks = 0;
    this.xp = 0;
    this.retreatRequested = false;
    this.onRetreat = null;                     // set while a lie is awaiting input
    this.stopWhisper = null;
    this.destroyed = false;
    this._buildDom();
  }

  // --------------------------------------------------------------- overlay DOM
  _buildDom() {
    injectStyles();
    const mount = this.ctx.mount || document.body;
    this.root = el('div', {
      position: 'fixed', inset: '0', zIndex: 60, fontFamily: FONT,
      userSelect: 'none', WebkitUserSelect: 'none', overflow: 'hidden',
      color: PARCH, animation: 'gcFadeIn 0.35s ease',
    });
    // dusk scrim — the battle stage
    this.scrim = el('div', {
      position: 'absolute', inset: '0',
      background: 'linear-gradient(180deg, #1c2340 0%, #2c3a5c 55%, #22304a 100%)',
      opacity: '0.94',
    });
    // fear vignette — the only pressure meter in the game
    this.vignette = el('div', { position: 'absolute', inset: '0', pointerEvents: 'none', transition: 'background 0.25s linear' });
    // extra darkness layer (First Shadow P2 lanterns-out)
    this.darkStage = el('div', {
      position: 'absolute', inset: '0', pointerEvents: 'none', background: 'rgba(4,5,12,0.55)',
      opacity: '0', transition: 'opacity 1.2s ease',
    });
    this.stage = el('div', {
      position: 'absolute', inset: '0', display: 'flex', flexDirection: 'column',
      alignItems: 'center', justifyContent: 'flex-start', padding: 'max(10px, env(safe-area-inset-top)) 10px 10px',
    });
    this.root.appendChild(this.scrim);
    this.root.appendChild(this.darkStage);
    this.root.appendChild(this.vignette);
    this.root.appendChild(this.stage);
    mount.appendChild(this.root);
    this._applyVignette();
  }

  _applyVignette() {
    const f = Math.max(0, Math.min(1, this.fear));
    if (this.settings.reducedFlash) {
      // accessibility: vignette desaturates instead of darkening
      this.vignette.style.background = 'transparent';
      this.vignette.style.backdropFilter = `saturate(${Math.round(100 - f * 80)}%)`;
      this.vignette.style.webkitBackdropFilter = this.vignette.style.backdropFilter;
      return;
    }
    const open = 85 - f * 73;                  // fear 0 → radius 85%, fear 1 → 12%
    const alpha = 0.5 + f * 0.5;
    this.vignette.style.background =
      `radial-gradient(circle at 50% 46%, rgba(8,7,18,0) ${open.toFixed(1)}%, rgba(8,7,18,${alpha.toFixed(2)}) 100%)`;
  }

  /** Fear pressure loop: +2%/s while a lie is live (COMBAT_TUNING). */
  _startFearTick() {
    if (this.fearRunning) return;
    this.fearRunning = true;
    let last = performance.now();
    const step = (now) => {
      if (!this.fearRunning || this.destroyed) return;
      const dt = Math.min(0.1, (now - last) / 1000); last = now;
      if (!this.fearPaused) {
        this.fear = Math.min(1, this.fear + COMBAT_TUNING.vignetteTightenPerSec * dt);
        this._applyVignette();
      }
      this.fearRAF = requestAnimationFrame(step);
    };
    this.fearRAF = requestAnimationFrame(step);
  }
  _stopFearTick() { this.fearRunning = false; if (this.fearRAF) cancelAnimationFrame(this.fearRAF); }
  _releaseFear() {
    // On encounter clear the vignette releases over 0.8 s
    this._stopFearTick();
    const from = this.fear, t0 = performance.now();
    const anim = (now) => {
      if (this.destroyed) return;
      const k = Math.min(1, (now - t0) / (COMBAT_TUNING.vignetteReleaseSec * 1000));
      this.fear = from + (0.12 - from) * k;
      this._applyVignette();
      if (k < 1) requestAnimationFrame(anim);
    };
    requestAnimationFrame(anim);
  }

  // --------------------------------------------------------- passage fetching
  /** Runtime ESV fetch with cache; resolves null on any error (degrade to gist). */
  fetchPassage(ref) {
    if (this.passageCache.has(ref)) return Promise.resolve(this.passageCache.get(ref));
    const fp = this.ctx.fetchPassage;
    if (typeof fp !== 'function') { this.passageCache.set(ref, null); return Promise.resolve(null); }
    let p;
    try { p = Promise.resolve(fp(ref)); } catch (e) { p = Promise.resolve(null); }
    return p
      .then((r) => (r && r.text && !r.error ? r : null))
      .catch(() => null)
      .then((r) => { this.passageCache.set(ref, r); return r; });
  }

  // ----------------------------------------------------------------- utilities
  sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
  pickRand(arr) { return arr[Math.floor(this.rand() * arr.length)]; }
  clearStage() { while (this.stage.firstChild) this.stage.removeChild(this.stage.firstChild); }

  /** Top banner in the game's Ribbon style. */
  async banner(text, sub = null, holdMs = 1300) {
    const wrap = el('div', { marginTop: '8vh', textAlign: 'center', animation: 'gcSlideUp 0.35s ease', pointerEvents: 'none' });
    const rib = el('div', {
      display: 'inline-flex', alignItems: 'center', gap: '10px', padding: '7px 20px',
      background: 'linear-gradient(180deg,#ffffff,#dff0fb)', border: `1px solid ${GOLD}`,
      boxShadow: 'inset 0 0 0 1px rgba(255,184,69,0.3), 0 3px 8px rgba(0,0,0,0.5)',
      borderRadius: '6px', color: GOLD_BRIGHT, fontSize: '15px', letterSpacing: '2px', fontWeight: '700',
    });
    rib.appendChild(el('span', { opacity: '0.65', fontSize: '11px' }, { text: '◆' }));
    rib.appendChild(el('span', {}, { text: text }));
    rib.appendChild(el('span', { opacity: '0.65', fontSize: '11px' }, { text: '◆' }));
    wrap.appendChild(rib);
    if (sub) {
      wrap.appendChild(el('div', {
        marginTop: '8px', color: '#dceafd', fontSize: '13px', lineHeight: '1.5',
        textShadow: '0 1px 3px rgba(0,0,0,0.6)', maxWidth: '440px', marginLeft: 'auto', marginRight: 'auto',
      }, { text: sub }));
    }
    this.stage.appendChild(wrap);
    await this.sleep(holdMs);
    wrap.remove();
  }

  // =========================================================================
  // Creature display — matte-black silhouette blob with one glowing feature,
  // gently swaying (the DOM stand-in for the world-space Gloomling).
  // =========================================================================
  showCreature(gloomling) {
    this.creatureWrap = el('div', {
      position: 'relative', marginTop: '4vh', width: '150px', height: '130px',
      animation: 'gcSway 3.2s ease-in-out infinite', pointerEvents: 'none',
      transition: 'opacity 0.4s ease, transform 0.4s ease',
    });
    const body = el('div', {
      position: 'absolute', left: '15px', top: '18px', width: '120px', height: '104px',
      background: 'radial-gradient(ellipse at 50% 38%, #14121f 62%, rgba(20,18,31,0) 76%)',
      filter: 'blur(1px)',
    });
    // wispy top
    const wisp = el('div', {
      position: 'absolute', left: '48px', top: '-6px', width: '54px', height: '46px',
      background: 'radial-gradient(ellipse at 50% 80%, #14121f 45%, rgba(20,18,31,0) 72%)',
      filter: 'blur(2px)', animation: 'gcDrift 4.5s ease-in-out infinite',
    });
    this.creatureWrap.appendChild(body);
    this.creatureWrap.appendChild(wisp);
    // the one glowing feature (Whisperling: eyes)
    if ((gloomling.glowFeature || 'eyes') === 'eyes') {
      [-14, 14].forEach((dx) => {
        this.creatureWrap.appendChild(el('div', {
          position: 'absolute', left: `${75 + dx - 5}px`, top: '52px', width: '10px', height: '7px',
          borderRadius: '50%', background: '#cfe3ff',
          boxShadow: '0 0 10px 3px rgba(160,200,255,0.8)', animation: 'gcPulse 2.4s ease-in-out infinite',
        }));
      });
    } else {
      this.creatureWrap.appendChild(el('div', {
        position: 'absolute', left: '55px', top: '40px', width: '40px', height: '8px', borderRadius: '4px',
        background: '#bfe0ff', boxShadow: '0 0 12px 4px rgba(160,200,255,0.7)', animation: 'gcPulse 2s ease-in-out infinite',
      }));
    }
    const name = el('div', {
      position: 'absolute', left: '0', right: '0', bottom: '-20px', textAlign: 'center',
      color: 'rgba(220,234,253,0.75)', fontSize: '11px', letterSpacing: '2px', fontWeight: '700',
    }, { text: gloomling.name.toUpperCase() });
    this.creatureWrap.appendChild(name);
    this.stage.appendChild(this.creatureWrap);
  }
  hideCreature() { if (this.creatureWrap) { this.creatureWrap.remove(); this.creatureWrap = null; } }

  /** Death: dissolve upward into additive firefly sprites — no ragdolls. */
  async dissolveCreature() {
    if (!this.creatureWrap) return;
    const wrap = this.creatureWrap;
    wrap.style.opacity = '0';
    wrap.style.transform = 'translateY(-14px) scale(0.92)';
    const [lo, hi] = COMBAT_TUNING.dissolveFireflies;
    const count = lo + Math.floor(this.rand() * (hi - lo + 1));
    const rect = wrap.getBoundingClientRect();
    for (let i = 0; i < count; i++) {
      const fx = (this.rand() * 2 - 1) * 90;
      const fy = -40 - this.rand() * 140;
      const fly = el('div', {
        position: 'fixed',
        left: `${rect.left + rect.width * (0.25 + this.rand() * 0.5)}px`,
        top: `${rect.top + rect.height * (0.2 + this.rand() * 0.6)}px`,
        width: '5px', height: '5px', borderRadius: '50%',
        background: '#ffe9a8', boxShadow: '0 0 8px 3px rgba(255,224,140,0.85)',
        pointerEvents: 'none', zIndex: 62,
        animation: `gcFirefly ${(0.7 + this.rand() * 0.7).toFixed(2)}s ease-out forwards`,
      });
      fly.style.setProperty('--fx', `${fx}px`);
      fly.style.setProperty('--fy', `${fy}px`);
      this.root.appendChild(fly);
      setTimeout(() => fly.remove(), 1600);
    }
    await this.sleep(650);
    this.hideCreature();
  }

  // =========================================================================
  // Lie plate — smoke-text panel with pulsing family icon (the static
  // accessibility plate IS the primary surface here).
  // =========================================================================
  showLie(lie, timerState = null) {
    const fam = LIE_FAMILIES[lie.family];
    this.liePlate = el('div', {
      marginTop: '14px', width: 'min(430px, 92vw)', position: 'relative',
      animation: 'gcSlideUp 0.4s ease',
    });
    const plate = el('div', {
      position: 'relative', borderRadius: '14px', padding: '13px 16px 12px',
      background: 'linear-gradient(180deg, rgba(30,26,48,0.92), rgba(18,16,32,0.92))',
      border: `1.5px solid ${fam.color}`, boxShadow: `0 0 22px rgba(0,0,0,0.55), inset 0 0 26px rgba(0,0,0,0.5)`,
      textAlign: 'center',
    });
    const iconRow = el('div', { display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px', marginBottom: '6px' });
    iconRow.appendChild(el('span', {
      fontSize: '17px', animation: 'gcPulse 1.6s ease-in-out infinite', filter: `drop-shadow(0 0 6px ${fam.color})`,
    }, { text: FAMILY_GLYPHS[lie.family] || '•' }));
    iconRow.appendChild(el('span', {
      fontSize: '10px', letterSpacing: '2.5px', fontWeight: '800', color: fam.color,
    }, { text: fam.label.toUpperCase() }));
    plate.appendChild(iconRow);
    this.lieText = el('div', {
      color: '#e8e4f4', fontSize: '19px', fontWeight: '700', lineHeight: '1.35',
      textShadow: `0 0 14px ${fam.color}55, 0 2px 4px rgba(0,0,0,0.8)`,
      animation: 'gcDrift 5s ease-in-out infinite', fontStyle: 'italic',
    }, { text: `“${lie.text}”` });
    plate.appendChild(this.lieText);
    if (timerState) {
      this.timerBar = el('div', { marginTop: '10px', height: '5px', borderRadius: '3px', background: 'rgba(255,255,255,0.12)', overflow: 'hidden' });
      this.timerFill = el('div', { height: '100%', width: '100%', borderRadius: '3px', background: `linear-gradient(90deg, ${GOLD_BRIGHT}, #ff8a5e)` });
      this.timerBar.appendChild(this.timerFill);
      plate.appendChild(this.timerBar);
    }
    this.liePlate.appendChild(plate);
    this.stage.appendChild(this.liePlate);
  }
  hideLie() { if (this.liePlate) { this.liePlate.remove(); this.liePlate = null; this.timerFill = null; } }
  /** Fizzle feedback: the lie re-forms louder. */
  lieReforms() {
    if (!this.lieText) return;
    this.lieText.style.animation = 'none';
    void this.lieText.offsetWidth; // restart
    this.lieText.style.animation = 'gcShake 0.45s ease, gcDrift 5s ease-in-out 0.45s infinite';
    this.lieText.style.fontSize = '21px';
    snd.lieForms();
  }

  // =========================================================================
  // The Verse Satchel dock — family wedges fan out cards (ref + gist + wick
  // pips). Bottom-anchored, thumb-reach, one-handed-portrait target.
  // =========================================================================
  openSatchel(onCast, { allowRetreat = true } = {}) {
    if (this.ctx.setTimeDilation) { try { this.ctx.setTimeDilation(COMBAT_TUNING.timeDilationSatchel); } catch (e) {} }
    snd.open();
    this.dock = el('div', {
      position: 'absolute', left: '50%', transform: 'translateX(-50%)',
      bottom: 'max(10px, env(safe-area-inset-bottom))', width: 'min(560px, 96vw)',
      animation: 'gcSlideUp 0.3s ease',
    });
    const panel = el('div', {
      position: 'relative', background: WOOD_TEX, border: `2px solid ${GOLD}`, boxShadow: PANEL_SHADOW,
      borderRadius: '16px', color: PARCH, padding: '10px 10px 9px',
    });
    // gold corner brackets (the game's Corners motif)
    [['top', 'left'], ['top', 'right'], ['bottom', 'left'], ['bottom', 'right']].forEach(([v, h]) => {
      panel.appendChild(el('span', {
        position: 'absolute', [v]: '6px', [h]: '6px', width: '15px', height: '15px', pointerEvents: 'none',
        borderTop: v === 'top' ? `3px solid ${GOLD_BRIGHT}` : 'none',
        borderBottom: v === 'bottom' ? `3px solid ${GOLD_BRIGHT}` : 'none',
        borderLeft: h === 'left' ? `3px solid ${GOLD_BRIGHT}` : 'none',
        borderRight: h === 'right' ? `3px solid ${GOLD_BRIGHT}` : 'none',
        borderRadius: '3px', opacity: '0.85', boxShadow: '0 0 6px rgba(255,184,69,0.3)',
      }));
    });
    const title = el('div', {
      textAlign: 'center', fontSize: '10px', letterSpacing: '2.5px', fontWeight: '800',
      color: '#f2971f', textShadow: '0 1px 0 rgba(255,255,255,0.75)', marginBottom: '7px',
    }, { text: '⚜ VERSE SATCHEL — ANSWER THE LIE' });
    panel.appendChild(title);

    // family wedge row (fixed wheel order — never color-only)
    const wedgeRow = el('div', { display: 'flex', gap: '5px', justifyContent: 'center', marginBottom: '7px' });
    this.cardFan = el('div', { display: 'flex', gap: '7px', justifyContent: 'center', minHeight: '86px', alignItems: 'stretch' });
    const families = Object.values(LIE_FAMILIES)
      .sort((a, b) => a.wheelIndex - b.wheelIndex)
      .map((lf) => lf.counterFamily);
    // remember the fanned-out family across dock rebuilds (fizzle refreshes)
    let activeFamily = this._activeFamily || null;
    const wedgeEls = {};
    const renderFan = () => {
      while (this.cardFan.firstChild) this.cardFan.removeChild(this.cardFan.firstChild);
      const cards = this.satchel.filter((c) => c.family === activeFamily);
      if (!activeFamily) {
        this.cardFan.appendChild(el('div', {
          alignSelf: 'center', fontSize: '12px', opacity: '0.6', fontStyle: 'italic',
        }, { text: 'Pick a verse family…' }));
        return;
      }
      if (cards.length === 0) {
        this.cardFan.appendChild(el('div', {
          alignSelf: 'center', fontSize: '12px', opacity: '0.6', fontStyle: 'italic',
        }, { text: 'No cards packed in this family yet.' }));
        return;
      }
      cards.forEach((card) => {
        const dead = card.charges <= 0 || card.greyedOut;
        const btn = el('button', {
          flex: '1 1 0', maxWidth: '170px', textAlign: 'left', cursor: dead ? 'default' : 'pointer',
          fontFamily: 'inherit', borderRadius: '10px', padding: '7px 9px 6px',
          border: `1.5px solid ${dead ? '#a8b6c4' : GOLD}`,
          background: dead ? 'linear-gradient(180deg,#e7e9ec,#d2d6da)' : 'linear-gradient(180deg, #ffffff, #d8edfb)',
          color: dead ? '#8a97a4' : PARCH, opacity: dead ? '0.55' : '1',
          boxShadow: dead ? 'none' : 'inset 0 1px 2px rgba(255,255,255,0.75), 0 2px 5px rgba(0,0,0,0.3)',
          transition: 'transform 0.08s ease',
        });
        btn.className = 'gc-card';
        if (dead) btn.disabled = true;
        btn.appendChild(el('div', { fontSize: '12.5px', fontWeight: '800', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }, { text: card.ref }));
        btn.appendChild(el('div', {
          fontSize: '10px', lineHeight: '1.3', margin: '3px 0 5px', height: '26px', overflow: 'hidden', opacity: '0.85',
        }, { text: card.gist }));
        // wick pips (charges); zero charges = unlit wick icon
        const pipRow = el('div', { display: 'flex', alignItems: 'center', gap: '3px', fontSize: '9px' });
        if (card.charges <= 0) {
          pipRow.appendChild(el('span', { fontSize: '11px', filter: 'grayscale(1)', animation: 'gcWickFlicker 2s infinite' }, { text: '🕯' }));
          pipRow.appendChild(el('span', { letterSpacing: '1px', fontSize: '8.5px' }, { text: 'RECHARGE AT A LIBRARY' }));
        } else {
          for (let i = 0; i < COMBAT_TUNING.serumCharges; i++) {
            pipRow.appendChild(el('span', {
              width: '8px', height: '8px', borderRadius: '50%',
              background: i < card.charges ? 'radial-gradient(circle at 35% 30%, #ffe9a8, #f0931c)' : 'rgba(23,73,126,0.18)',
              boxShadow: i < card.charges ? '0 0 4px rgba(255,184,69,0.7)' : 'none',
            }));
          }
          if (card.greyedOut) pipRow.appendChild(el('span', { fontSize: '8.5px', letterSpacing: '1px', marginLeft: '3px' }, { text: 'FIZZLED' }));
        }
        btn.appendChild(pipRow);
        // read-in-full: small book affordance, pauses fear tick while open
        const read = el('span', {
          position: 'relative', float: 'right', fontSize: '12px', marginTop: '-2px', padding: '2px 4px', cursor: 'pointer', opacity: '0.7',
        }, { text: '📖' });
        read.onclick = (ev) => { ev.stopPropagation(); this.openReader(card); };
        btn.insertBefore(read, btn.firstChild);
        if (!dead) btn.onclick = () => { snd.click(); onCast(card); };
        this.cardFan.appendChild(btn);
      });
    };
    families.forEach((vf) => {
      const lf = Object.values(LIE_FAMILIES).find((f) => f.counterFamily === vf);
      const packed = this.satchel.some((c) => c.family === vf);
      const live = this.satchel.some((c) => c.family === vf && c.charges > 0 && !c.greyedOut);
      const w = el('button', {
        flex: '1 1 0', maxWidth: '82px', padding: '5px 2px 4px', borderRadius: '9px', cursor: 'pointer',
        fontFamily: 'inherit', textAlign: 'center', transition: 'transform 0.08s ease',
        border: `1.5px solid ${live ? lf.color : '#b8c4d0'}`,
        background: 'linear-gradient(180deg,#ffffff,#e9f5fc)', opacity: packed ? (live ? '1' : '0.55') : '0.35',
      });
      w.className = 'gc-wedge';
      w.appendChild(el('div', { fontSize: '15px' }, { text: VERSE_FAMILY_GLYPHS[vf] }));
      w.appendChild(el('div', { fontSize: '8px', letterSpacing: '1px', fontWeight: '800', color: PARCH }, { text: vf.toUpperCase() }));
      const selectWedge = (withClick) => {
        if (withClick) snd.click();
        activeFamily = vf;
        this._activeFamily = vf;
        Object.values(wedgeEls).forEach((e2) => { e2.style.boxShadow = 'none'; e2.style.transform = 'none'; });
        w.style.boxShadow = `0 0 10px ${lf.color}88, inset 0 1px 2px rgba(255,255,255,0.85)`;
        w.style.transform = 'translateY(-2px)';
        renderFan();
      };
      w.onclick = () => selectWedge(true);
      wedgeEls[vf] = w;
      wedgeRow.appendChild(w);
      if (activeFamily === vf) queueMicrotask(() => selectWedge(false));
    });
    panel.appendChild(wedgeRow);
    panel.appendChild(this.cardFan);

    if (allowRetreat) {
      let armed = false;
      const retreat = el('button', {
        display: 'block', margin: '8px auto 0', padding: '5px 16px', borderRadius: '8px',
        border: `1px solid ${GOLD}`, background: WOOD, color: PARCH, fontFamily: 'inherit',
        fontWeight: '700', fontSize: '11.5px', cursor: 'pointer',
      }, { text: '🏃 Step back' });
      retreat.onclick = () => {
        if (!armed) { armed = true; retreat.textContent = 'Really step away?'; retreat.style.color = '#c94a34'; setTimeout(() => { armed = false; retreat.textContent = '🏃 Step back'; retreat.style.color = PARCH; }, 2200); return; }
        snd.click();
        this.retreatRequested = true;
        if (this.onRetreat) this.onRetreat();
      };
      panel.appendChild(retreat);
    }
    renderFan();
    this.dock.appendChild(panel);
    this.root.appendChild(this.dock);
  }
  closeSatchel() {
    if (this.ctx.setTimeDilation) { try { this.ctx.setTimeDilation(1); } catch (e) {} }
    if (this.dock) { this.dock.remove(); this.dock = null; }
  }

  /** Read-in-full popover: RUNTIME-fetched ESV, ref + gist fallback. Pauses fear. */
  openReader(card) {
    this.fearPaused = true;
    if (this.pauseTimer) this.pauseTimer();
    const shade = el('div', { position: 'absolute', inset: '0', zIndex: 65, background: 'rgba(10,12,24,0.55)', display: 'flex', alignItems: 'center', justifyContent: 'center', animation: 'gcFadeIn 0.2s ease' });
    const pane = el('div', {
      position: 'relative', background: WOOD_TEX, border: `2px solid ${GOLD}`, boxShadow: PANEL_SHADOW,
      borderRadius: '16px', color: PARCH, padding: '18px 18px 14px', width: 'min(400px, 90vw)', maxHeight: '70vh', overflowY: 'auto',
    });
    pane.appendChild(el('div', { fontSize: '15px', fontWeight: '800', color: '#f2971f', textShadow: '0 1px 0 rgba(255,255,255,0.75)' }, { text: card.ref }));
    const body = el('div', { fontSize: '14px', lineHeight: '1.55', margin: '9px 0 4px', fontStyle: 'italic', opacity: '0.75' }, { text: 'Opening the Book…' });
    pane.appendChild(body);
    const attribution = el('div', { fontSize: '9px', letterSpacing: '1px', opacity: '0.5', marginTop: '6px' });
    pane.appendChild(attribution);
    const close = el('button', {
      display: 'block', margin: '12px auto 0', padding: '7px 22px', borderRadius: '9px', border: '1px solid #155a9c',
      background: GOLD_BTN_BG, color: '#5a3305', fontFamily: 'inherit', fontWeight: '700', fontSize: '13px', cursor: 'pointer',
      boxShadow: 'inset 0 1px 2px rgba(255,255,255,0.75), 0 3px 6px rgba(0,0,0,0.4)',
    }, { text: 'Close' });
    close.onclick = () => { snd.click(); shade.remove(); this.fearPaused = false; if (this.resumeTimer) this.resumeTimer(); };
    pane.appendChild(close);
    shade.appendChild(pane);
    this.root.appendChild(shade);
    this.fetchPassage(card.ref).then((p) => {
      if (!shade.isConnected) return;
      if (p && p.text) {
        body.textContent = p.text;
        body.style.fontStyle = 'normal'; body.style.opacity = '1';
        attribution.textContent = (p.translation || 'ESV').toUpperCase();
      } else {
        body.textContent = card.gist;
        body.style.opacity = '0.9';
        attribution.textContent = 'Full verse text is on its way — this is the gist.';
      }
    });
  }

  // =========================================================================
  // Cast resolution FX
  // =========================================================================
  /** Lightburst: verse text flares 1.2 s with its reference, darkness flees. */
  async lightburst(card) {
    snd.lightburst();
    const reduced = !!this.settings.reducedFlash;
    // fire the runtime fetch NOW; the flare swaps gist → text if it lands in time
    const textP = this.fetchPassage(card.ref);
    const flare = el('div', {
      position: 'absolute', inset: '0', zIndex: 64, display: 'flex', alignItems: 'center',
      justifyContent: 'center', pointerEvents: 'none',
    });
    if (!reduced) {
      flare.appendChild(el('div', {
        position: 'absolute', inset: '0',
        background: 'radial-gradient(circle at 50% 42%, rgba(255,240,200,0.95) 0%, rgba(255,214,120,0.55) 34%, rgba(255,214,120,0) 70%)',
        animation: `gcFlare ${COMBAT_TUNING.lightburstFlareSec + 0.6}s ease forwards`,
      }));
    } else {
      // accessibility: 0.6 s radial glow ramp, no white frame
      flare.appendChild(el('div', {
        position: 'absolute', inset: '0',
        background: 'radial-gradient(circle at 50% 42%, rgba(255,224,150,0.5) 0%, rgba(255,224,150,0) 60%)',
        animation: `gcFadeIn ${COMBAT_TUNING.reducedFlashGlowRampSec}s ease forwards`,
      }));
    }
    const verseCard = el('div', {
      position: 'relative', maxWidth: 'min(420px, 88vw)', textAlign: 'center',
      animation: 'gcSlideUp 0.3s ease', padding: '0 12px',
    });
    const vtext = el('div', {
      color: '#fff7e0', fontSize: '19px', fontWeight: '800', lineHeight: '1.4',
      textShadow: '0 0 22px rgba(255,214,120,0.95), 0 2px 6px rgba(0,0,0,0.6)',
    }, { text: card.gist });
    const vref = el('div', {
      marginTop: '8px', color: GOLD_BRIGHT, fontSize: '13px', letterSpacing: '2px', fontWeight: '800',
      textShadow: '0 1px 4px rgba(0,0,0,0.7)',
    }, { text: `— ${card.ref} —` });
    verseCard.appendChild(vtext); verseCard.appendChild(vref);
    flare.appendChild(verseCard);
    this.root.appendChild(flare);
    textP.then((p) => { if (p && p.text && flare.isConnected) vtext.textContent = p.text; });
    // flare hold: 1.2 s flare + a readable beat
    await this.sleep(COMBAT_TUNING.lightburstFlareSec * 1000 + 700);
    flare.style.transition = 'opacity 0.3s ease'; flare.style.opacity = '0';
    await this.sleep(300);
    flare.remove();
  }

  /** Fizzle: weak grey shimmer; vignette snaps tighter; the lie re-forms louder. */
  async fizzleFx() {
    snd.fizzle();
    const shim = el('div', {
      position: 'absolute', inset: '0', zIndex: 64, pointerEvents: 'none',
      background: 'radial-gradient(circle at 50% 55%, rgba(160,160,175,0.35) 0%, rgba(160,160,175,0) 55%)',
      animation: 'gcFlare 0.55s ease forwards',
    });
    this.root.appendChild(shim);
    this.fear = Math.min(1, this.fear + COMBAT_TUNING.vignetteFizzleSnap);
    this._applyVignette();
    await this.sleep(520);
    shim.remove();
    this.lieReforms();
  }

  // =========================================================================
  // One live lie → resolution. Returns 'cleared' | 'fade' | 'retreat'.
  // =========================================================================
  async runLie(lieId, { timerSec = null, coachLine = null, allowRetreat = true, missZone = null } = {}) {
    const lie = LIES[lieId];
    if (!lie) return 'cleared';
    const calm = !!this.settings.calmMode;
    if (calm) timerSec = null;                 // Calm Mode removes all timers, game-wide
    this.stopWhisper = snd.whisper();
    if (this.ctx.duckAmbient) { try { this.ctx.duckAmbient(true); } catch (e) {} }
    this.showLie(lie, timerSec ? {} : null);
    if (coachLine) this.showCoach(coachLine);
    this._startFearTick();

    let result = null;
    while (result === null) {
      // No-soft-lock: if nothing equipped can answer this lie, the next beat
      // resolves via the Fade path (Ch. 2.1) rather than an unanswerable stall.
      const dealable = filterDealableLies([lieId], this.satchel);
      if (dealable.length === 0) { result = 'fade'; break; }

      const action = await this._awaitCast(timerSec, allowRetreat);
      if (action.kind === 'retreat') { result = 'retreat'; break; }
      if (action.kind === 'expire') {
        // Timer expiry = same result as a wrong answer, never worse (LOCKED):
        // fizzle vignette snap, replay the lie; no grey-out, no charge, no Fade.
        this.fear = Math.min(1, this.fear + EFFECTIVENESS.FIZZLE.vignetteDelta);
        this._applyVignette();
        this.lieReforms();
        if (this.fear >= 1) { result = 'fade'; }
        continue;
      }
      const card = action.card;
      // every cast spends one charge, hit or miss
      card.charges = Math.max(0, card.charges - 1);
      this.chargeSpends[card.id] = (this.chargeSpends[card.id] || 0) + 1;
      if (this.ctx.spendSerumCharge) { try { this.ctx.spendSerumCharge(card.id); } catch (e) {} }

      const eff = resolveCast(lie, { family: card.family, ref: card.ref }, { precision: 'family' });
      if (eff === 'super') {
        this.hideLieTimer();
        await this.lightburst(card);
        this.clearedLies.push(lieId);
        result = 'cleared';
      } else {
        // fizzle: grey the card for THIS encounter, log the miss (Ch. 13.6)
        card.greyedOut = true;
        const miss = {
          lie_id: lieId, counter_verse_ref: card.ref,
          zone: missZone || this.meta.zone, timestamp: new Date().toISOString(),
        };
        this.missLog.push(miss);
        if (this.ctx.logMiss) { try { this.ctx.logMiss(miss); } catch (e) {} }
        await this.fizzleFx();
        this.refreshSatchel();
        if (this.fear >= 1) result = 'fade';
      }
    }
    this._stopFearTick();
    if (this.stopWhisper) { this.stopWhisper(); this.stopWhisper = null; }
    this.hideCoach();
    this.hideLie();
    this.closeSatchel();
    return result;
  }

  /** Rebuild the card fan in place after a grey-out. */
  refreshSatchel() {
    if (!this.dock) return;
    const cb = this._lastOnCast; const opts = this._lastSatchelOpts;
    this.closeSatchel();
    if (cb) this.openSatchel(cb, opts);
  }

  /** Await a card cast / retreat / timer-expiry for the live lie. */
  _awaitCast(timerSec, allowRetreat) {
    return new Promise((resolve) => {
      let done = false;
      let timerId = null, tickId = null, remaining = timerSec ? timerSec * 1000 : null, lastT = null;
      const finish = (v) => {
        if (done) return; done = true;
        if (timerId) clearTimeout(timerId);
        if (tickId) clearInterval(tickId);
        this.pauseTimer = null; this.resumeTimer = null; this.onRetreat = null;
        resolve(v);
      };
      const startClock = () => {
        if (remaining == null) return;
        lastT = performance.now();
        timerId = setTimeout(() => finish({ kind: 'expire' }), remaining);
        tickId = setInterval(() => {
          if (!this.timerFill) return;
          const left = Math.max(0, remaining - (performance.now() - lastT));
          this.timerFill.style.width = `${(left / (timerSec * 1000)) * 100}%`;
          if (left < timerSec * 250) snd.timerTick();
        }, 200);
      };
      // reader-open pauses the clock (single-player rule)
      this.pauseTimer = () => {
        if (remaining == null || timerId == null) return;
        remaining = Math.max(0, remaining - (performance.now() - lastT));
        clearTimeout(timerId); clearInterval(tickId); timerId = null; tickId = null;
      };
      this.resumeTimer = () => { if (remaining != null && timerId == null && !done) startClock(); };
      this.onRetreat = () => finish({ kind: 'retreat' });
      const onCast = (card) => finish({ kind: 'cast', card });
      this._lastOnCast = onCast;
      this._lastSatchelOpts = { allowRetreat };
      if (!this.dock) this.openSatchel(onCast, { allowRetreat });
      else this.refreshSatchel();
      startClock();
    });
  }
  hideLieTimer() { if (this.timerBar) { this.timerBar.style.opacity = '0'; } }

  // ------------------------------------------------------------ coach banner
  showCoach(text) {
    this.hideCoach();
    this.coachEl = el('div', {
      marginTop: '10px', width: 'min(420px, 90vw)', display: 'flex', gap: '10px', alignItems: 'flex-start',
      background: WOOD_TEX, border: `2px solid ${GOLD}`, boxShadow: PANEL_SHADOW, borderRadius: '13px',
      padding: '9px 12px', animation: 'gcSlideUp 0.35s ease',
    });
    const face = el('div', {
      width: '38px', height: '38px', flex: '0 0 38px', borderRadius: '50%',
      background: 'radial-gradient(circle at 35% 30%, #6a7a4a, #3a4a2a)', border: `2px solid ${GOLD}`,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
    });
    face.appendChild(el('span', { fontSize: '17px', fontWeight: '800', color: '#ffffff', textShadow: '0 2px 4px rgba(0,0,0,0.45)', fontFamily: 'Georgia, serif' }, { text: 'E' }));
    this.coachEl.appendChild(face);
    const col = el('div', { flex: '1', minWidth: '0' });
    col.appendChild(el('div', { fontSize: '10px', letterSpacing: '1.5px', fontWeight: '800', color: '#f2971f', textShadow: '0 1px 0 rgba(255,255,255,0.75)' }, { text: 'OLD GARDENER ELI' }));
    col.appendChild(el('div', { fontSize: '12.5px', lineHeight: '1.45', color: PARCH, marginTop: '2px' }, { text: `“${text}”` }));
    this.coachEl.appendChild(col);
    this.stage.appendChild(this.coachEl);
  }
  hideCoach() { if (this.coachEl) { this.coachEl.remove(); this.coachEl = null; } }

  // =========================================================================
  // Fade path — fear, never death. Soft black, heartbeat, lantern re-flare.
  // Caller repositions the player at the nearest lit lantern.
  // =========================================================================
  async runFade() {
    this.closeSatchel();
    this.hideLie();
    this.hideCoach();
    if (this.stopWhisper) { this.stopWhisper(); this.stopWhisper = null; }
    this._stopFearTick();
    const black = el('div', { position: 'absolute', inset: '0', zIndex: 66, background: '#050409', opacity: '0', transition: 'opacity 1.1s ease' });
    this.root.appendChild(black);
    await this.sleep(30);
    black.style.opacity = '1';
    await this.sleep(1150);
    snd.heartbeat();
    await this.sleep(1700);
    // the lantern re-flares
    const flare = el('div', {
      position: 'absolute', inset: '0', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: '14px',
    });
    flare.appendChild(el('div', {
      width: '70px', height: '70px', borderRadius: '50%',
      background: 'radial-gradient(circle at 40% 35%, #fff3cf, #f0931c)',
      boxShadow: '0 0 60px 24px rgba(255,200,110,0.55)', animation: 'gcBloom 1.6s ease forwards',
    }, { text: '' }));
    flare.appendChild(el('div', { color: '#f4e8cf', fontSize: '14px', letterSpacing: '1px', textAlign: 'center', lineHeight: '1.6', padding: '0 24px' }, {
      text: 'The fear passes. You wake beside the nearest lit lantern —\neverything you carry is still yours.',
    }));
    flare.style.whiteSpace = 'pre-line';
    black.appendChild(flare);
    await this.sleep(2100);
  }

  // =========================================================================
  // Victory rewards — Lightfound fanfare + item card on a soft light bloom.
  // =========================================================================
  async runRewards({ sparks, xp, title = 'GLOOM REPELLED', line = null }) {
    this.sparks += sparks;
    this.xp += xp;
    snd.fanfare(true);
    const shade = el('div', { position: 'absolute', inset: '0', zIndex: 66, display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'rgba(12,14,28,0.45)', animation: 'gcFadeIn 0.3s ease' });
    const pane = el('div', {
      position: 'relative', background: WOOD_TEX, border: `2px solid ${GOLD}`, boxShadow: PANEL_SHADOW,
      borderRadius: '18px', color: PARCH, padding: '20px 24px 16px', width: 'min(340px, 88vw)', textAlign: 'center',
      animation: 'gcSlideUp 0.35s ease, gcBloom 1.4s ease forwards',
    });
    pane.appendChild(el('div', { fontSize: '12px', letterSpacing: '3px', fontWeight: '800', color: '#f2971f', textShadow: '0 1px 0 rgba(255,255,255,0.75)' }, { text: `⚜ ${title} ⚜` }));
    if (line) pane.appendChild(el('div', { fontSize: '13px', lineHeight: '1.5', margin: '9px 0 2px' }, { text: line }));
    const rows = el('div', { display: 'flex', justifyContent: 'center', gap: '10px', margin: '13px 0 4px' });
    const chipEl = (label, val) => {
      const c = el('div', {
        padding: '7px 13px', borderRadius: '10px', border: `1.5px solid ${GOLD_BRIGHT}`,
        background: 'linear-gradient(180deg, rgba(255,200,94,0.5), rgba(255,255,255,0.95))',
        boxShadow: '0 0 10px rgba(255,184,69,0.5), inset 0 1px 2px rgba(255,255,255,0.85)',
      });
      c.appendChild(el('div', { fontSize: '17px', fontWeight: '800' }, { text: val }));
      c.appendChild(el('div', { fontSize: '8.5px', letterSpacing: '1.5px', fontWeight: '800', opacity: '0.7' }, { text: label }));
      return c;
    };
    if (sparks > 0) rows.appendChild(chipEl('EMBER-SPARKS', `🔥 ${sparks}`));
    if (xp > 0) rows.appendChild(chipEl('XP', `✦ ${xp}`));
    pane.appendChild(rows);
    if (sparks > 0) pane.appendChild(el('div', { fontSize: '10px', opacity: '0.6', margin: '2px 0 4px' }, { text: 'Ember will happily eat these.' }));
    const btn = el('button', {
      marginTop: '9px', padding: '9px 30px', borderRadius: '10px', border: '1px solid #155a9c',
      background: GOLD_BTN_BG, color: '#5a3305', fontFamily: 'inherit', fontWeight: '800', fontSize: '14px',
      cursor: 'pointer', boxShadow: 'inset 0 1px 2px rgba(255,255,255,0.75), 0 3px 6px rgba(0,0,0,0.4)',
    }, { text: '⚜ Onward' });
    pane.appendChild(btn);
    shade.appendChild(pane);
    this.root.appendChild(shade);
    await new Promise((r) => { btn.onclick = () => { snd.click(); r(); }; });
    shade.remove();
  }

  // ---------------------------------------------------------------- teardown
  destroy() {
    if (this.destroyed) return;
    this.destroyed = true;
    this._stopFearTick();
    if (this.stopWhisper) { this.stopWhisper(); this.stopWhisper = null; }
    if (this.ctx.setTimeDilation) { try { this.ctx.setTimeDilation(1); } catch (e) {} }
    if (this.ctx.duckAmbient) { try { this.ctx.duckAmbient(false); } catch (e) {} }
    if (this.root) {
      this.root.style.transition = 'opacity 0.35s ease';
      this.root.style.opacity = '0';
      const r = this.root;
      setTimeout(() => r.remove(), 380);
      this.root = null;
    }
  }
}

// =============================================================================
// Encounter drivers
// =============================================================================

function rollInt(rand, [lo, hi]) { return lo + Math.floor(rand() * (hi - lo + 1)); }

/** Single Gloomling fight (tutorial / one patrol unit). */
async function fightGloomling(session, gloomling, lieId, { allowRetreat = true, introBanner = true } = {}) {
  if (introBanner) await session.banner(`A ${gloomling.name.toUpperCase()} STIRS`, 'It whispers from the dark…', 1100);
  session.showCreature(gloomling);
  await session.sleep(350);
  const outcome = await session.runLie(lieId, { allowRetreat });
  if (outcome === 'cleared') {
    await session.dissolveCreature();      // darkness always flees light
    session._releaseFear();
  } else {
    session.hideCreature();
  }
  return outcome;
}

/** East Road patrol: roll the unit roster per the spawner contract, fight each. */
async function runPatrol(session, enc) {
  const rand = session.rand;
  const dusk = !!(session.ctx.isDusk && (() => { try { return session.ctx.isDusk(); } catch (e) { return false; } })());
  const mult = dusk ? enc.duskDensityMult : 1;
  const spawned = [];
  for (const unit of enc.units) {
    const chance = Math.min(1, unit.spawnChance * mult);    // clamped; never duplicates units
    if (rand() >= chance) continue;
    const dealable = filterDealableLies([...unit.liePool], session.satchel);
    if (dealable.length === 0) continue;                     // onEmptyDealablePool: 'skip-spawn'
    spawned.push({ gloomling: GLOOMLINGS[unit.gloomling], lieId: session.pickRand(dealable) });
  }
  if (spawned.length === 0) {
    // Every unit skip-spawned: the encounter counts as clear (waymarker relights).
    return { outcome: 'clear-empty' };
  }
  let sparks = 0, xp = 0;
  for (let i = 0; i < spawned.length; i++) {
    const { gloomling, lieId } = spawned[i];
    const r = await fightGloomling(session, gloomling, lieId, {
      introBanner: true,
      allowRetreat: true,
    });
    if (r === 'fade') return { outcome: 'fade' };
    if (r === 'retreat') return { outcome: 'retreat' };
    sparks += rollInt(rand, gloomling.sparks);
    xp += XP_REWARDS[gloomling.tier] || XP_REWARDS.trash;
    if (i < spawned.length - 1) await session.sleep(400);
  }
  await session.runRewards({
    sparks, xp,
    title: 'PATROL REPELLED',
    line: enc.relightsWaymarkerOnClear ? 'The waymarker lantern along this stretch flickers back to life.' : null,
  });
  return { outcome: 'victory', sparks, xp };
}

/**
 * The First Shadow — Meadow Town prologue boss. Three phases: teach, test,
 * triumph. Gates the trivia battle; never grants the seal itself.
 */
async function runFirstShadow(session) {
  const boss = FIRST_SHADOW;
  const calm = !!session.settings.calmMode;
  await session.banner('THE FIRST SHADOW', 'The square goes quiet. Something old and grey unfolds above the fountain.', 1900);
  session.showCreature({ name: 'The First Shadow', glowFeature: 'maw' });

  // Eli coach lines — ORIGINAL prose, one per P1 lie (family-teaching beats).
  const P1_COACH = {
    lie_fs_p1_small: 'That one picks at your worth. Answer it with who God says you are!',
    lie_fs_p1_done: 'A chain-lie! Grace is the only key that fits those locks.',
    lie_fs_p1_dark: 'It wants you scared. Courage, child — you know Whose you are.',
  };

  for (const phase of boss.phases) {
    const phaseTimer = phase.id === 'p2_test' && calm ? boss.calmMode.p2TimerSec : phase.timerSec;
    const resolveMode = phase.id === 'p2_test' && calm ? boss.calmMode.p2ResolveMode : phase.resolveMode;

    if (phase.id === 'p1_teach') {
      await session.banner('◈ TEACH ◈', 'The Shadow speaks. Eli stands with you.', 1300);
      for (const lieId of phase.lies) {
        const r = await session.runLie(lieId, {
          coachLine: P1_COACH[lieId] || null, allowRetreat: true, missZone: boss.missLogZone,
        });
        if (r !== 'cleared') return { outcome: r };
        await session.sleep(320);
      }
    } else if (phase.id === 'p2_test') {
      await session.banner('◈ TEST ◈', calm
        ? 'The square’s lanterns go out. Relight all three — take your time.'
        : 'The square’s lanterns go out. Only your own light is left.', 1600);
      session.darkStage.style.opacity = '1';
      // lantern pips — one relights per correct answer
      const pipRow = el('div', { display: 'flex', gap: '10px', marginTop: '8px' });
      const pips = phase.lies.map(() => {
        const p = el('span', { fontSize: '20px', filter: 'grayscale(1)', opacity: '0.45', transition: 'all 0.5s ease' }, { text: '🏮' });
        pipRow.appendChild(p); return p;
      });
      session.stage.appendChild(pipRow);
      const order = resolveMode === 'simultaneous' ? [...phase.lies] : phase.lies;
      for (let i = 0; i < order.length; i++) {
        const r = await session.runLie(order[i], {
          timerSec: phaseTimer, allowRetreat: true, missZone: boss.missLogZone,
        });
        if (r !== 'cleared') { pipRow.remove(); session.darkStage.style.opacity = '0'; return { outcome: r }; }
        pips[i].style.filter = 'none'; pips[i].style.opacity = '1';
        snd.lanternChime(i);
        await session.sleep(420);
      }
      pipRow.remove();
      session.darkStage.style.opacity = '0';
    } else if (phase.id === 'p3_triumph') {
      await session.banner('◈ TRIUMPH ◈', `Every lie at once, swirling like smoke. Answer any ${phase.answersRequired} — the light will do the rest.`, 1800);
      // simultaneous: chips for all six lies; tap one to engage it
      let answered = 0;
      const remaining = new Set(phase.lies);
      while (answered < phase.answersRequired) {
        // no-soft-lock: only offer lies the current satchel can still answer
        const dealable = filterDealableLies([...remaining], session.satchel);
        if (dealable.length === 0) return { outcome: 'fade' };
        const chosen = await session.pickLieChip([...remaining], dealable);
        if (chosen == null) return { outcome: 'retreat' };
        const r = await session.runLie(chosen, { allowRetreat: true, missZone: boss.missLogZone });
        if (r !== 'cleared') return { outcome: r };
        remaining.delete(chosen);
        answered++;
      }
      // Finale: lantern cascade from the player; the covenant of the whole game.
      await session.dissolveCreature();
      await session.lanternCascade(phase.finale);
    }
  }
  session._releaseFear();
  await session.runRewards({
    sparks: boss.sparks, xp: XP_REWARDS.boss,
    title: 'THE SQUARE IS BRIGHT AGAIN',
    line: 'Light wins. Always.',
  });
  return { outcome: 'victory', sparks: boss.sparks, xp: XP_REWARDS.boss };
}

// P3 lie-chip picker + finale cascade live on the Session for DOM access.
Session.prototype.pickLieChip = function pickLieChip(all, dealable) {
  return new Promise((resolve) => {
    const wrap = el('div', {
      position: 'absolute', left: '50%', transform: 'translateX(-50%)', top: '16vh',
      width: 'min(460px, 94vw)', display: 'flex', flexWrap: 'wrap', gap: '8px', justifyContent: 'center',
      zIndex: 63, animation: 'gcFadeIn 0.3s ease',
    });
    const finish = (v) => { wrap.remove(); back.remove(); resolve(v); };
    all.forEach((lieId) => {
      const lie = LIES[lieId];
      const fam = LIE_FAMILIES[lie.family];
      const can = dealable.includes(lieId);
      const chip = el('button', {
        padding: '8px 12px', borderRadius: '11px', cursor: can ? 'pointer' : 'default',
        fontFamily: FONT, fontSize: '12px', fontWeight: '700', fontStyle: 'italic',
        background: 'linear-gradient(180deg, rgba(30,26,48,0.94), rgba(18,16,32,0.94))',
        border: `1.5px solid ${fam.color}`, color: '#e8e4f4', opacity: can ? '1' : '0.45',
        animation: 'gcDrift 4.5s ease-in-out infinite', textShadow: `0 0 10px ${fam.color}66`,
      }, { text: `${FAMILY_GLYPHS[lie.family]} “${lie.text}”` });
      if (can) chip.onclick = () => { snd.click(); finish(lieId); };
      else chip.disabled = true;
      wrap.appendChild(chip);
    });
    const back = el('button', {
      position: 'absolute', left: '50%', transform: 'translateX(-50%)',
      bottom: 'max(12px, env(safe-area-inset-bottom))', zIndex: 63,
      padding: '6px 18px', borderRadius: '8px', border: `1px solid ${GOLD}`, background: WOOD,
      color: PARCH, fontFamily: FONT, fontWeight: '700', fontSize: '11.5px', cursor: 'pointer',
    }, { text: '🏃 Step back' });
    back.onclick = () => { snd.click(); finish(null); };
    this.root.appendChild(wrap);
    this.root.appendChild(back);
  });
};

Session.prototype.lanternCascade = async function lanternCascade(finale) {
  const secs = finale && finale.cascadeSec ? finale.cascadeSec : 6;
  const count = Math.min(finale && finale.lanternCount ? finale.lanternCount : 40, 40);
  const cx = 50, cy = 58;
  for (let i = 0; i < count; i++) {
    const delay = (i / count) * secs * 0.62 * 1000;
    setTimeout(() => {
      if (this.destroyed || !this.root) return;
      const ang = this.rand() * Math.PI * 2;
      const dist = 6 + (i / count) * 46;
      const x = cx + Math.cos(ang) * dist;
      const y = cy + Math.sin(ang) * dist * 0.6;
      const g = el('div', {
        position: 'absolute', left: `${x}%`, top: `${y}%`, width: '16px', height: '16px',
        marginLeft: '-8px', marginTop: '-8px', borderRadius: '50%', pointerEvents: 'none', zIndex: 63,
        background: 'radial-gradient(circle at 40% 35%, #fff3cf, #f0931c)',
        boxShadow: '0 0 24px 10px rgba(255,200,110,0.5)',
        animation: `gcCascade ${1.4 + this.rand() * 0.8}s ease-out forwards`,
      });
      this.root.appendChild(g);
      if (i % 5 === 0) snd.lanternChime(i / 5);
      setTimeout(() => g.remove(), 2400);
    }, delay);
  }
  // warm the whole stage as the wave spreads
  this.scrim.style.transition = `background ${secs * 0.7}s ease`;
  this.scrim.style.background = 'linear-gradient(180deg, #3a3f66 0%, #6a5a4c 55%, #8a6a3e 100%)';
  await this.sleep(secs * 0.75 * 1000);
};

// =============================================================================
// Public entry point
// =============================================================================
let activeEncounter = false;

/**
 * Start a Truth & Light encounter. Resolves (never rejects) with an
 * EncounterResult once the overlay has fully closed.
 *
 * @param {object} ctx - see the ctx CONTRACT in the file header
 * @param {string} id  - EAST_ROAD_ENCOUNTERS id | 'first_shadow' | GLOOMLINGS key
 * @returns {Promise<object>} EncounterResult
 */
export async function startEncounter(ctx, id) {
  if (activeEncounter) {
    return { encounterId: id, kind: 'none', outcome: 'retreat', zone: null, clearedLies: [], missLog: [], chargeSpends: {}, sparks: 0, xp: 0, gold: 0, error: 'encounter_already_active' };
  }
  activeEncounter = true;
  ctx = ctx || {};

  const road = EAST_ROAD_ENCOUNTERS.find((e) => e.id === id) || null;
  const isBoss = id === FIRST_SHADOW.id;
  const gloom = !road && !isBoss ? GLOOMLINGS[id] : null;
  const meta = road
    ? { encounterId: id, kind: 'patrol', zone: road.zone }
    : isBoss
      ? { encounterId: id, kind: 'boss', zone: FIRST_SHADOW.zone }
      : gloom
        ? { encounterId: id, kind: 'gloomling', zone: gloom.zoneDebut }
        : null;
  if (!meta) {
    activeEncounter = false;
    return { encounterId: id, kind: 'none', outcome: 'retreat', zone: null, clearedLies: [], missLog: [], chargeSpends: {}, sparks: 0, xp: 0, gold: 0, error: 'unknown_encounter_id' };
  }
  if (gloom && !gloom.inPhase1Slice) {
    // Phase 1 slice discipline: Murmur Pack / Heavyback must not spawn yet.
    activeEncounter = false;
    return { encounterId: id, kind: 'gloomling', outcome: 'retreat', zone: gloom.zoneDebut, clearedLies: [], missLog: [], chargeSpends: {}, sparks: 0, xp: 0, gold: 0, error: 'out_of_phase1_slice' };
  }

  let session;
  try {
    session = new Session(ctx, meta);
  } catch (err) {
    activeEncounter = false;
    if (typeof console !== 'undefined') console.error('[glowlands/combat] overlay init failed', err);
    return { encounterId: id, kind: meta.kind, outcome: 'retreat', zone: meta.zone, clearedLies: [], missLog: [], chargeSpends: {}, sparks: 0, xp: 0, gold: 0, error: 'overlay_init_failed' };
  }
  let outcome = 'retreat';
  try {
    if (road) {
      const r = await runPatrol(session, road);
      outcome = r.outcome;
    } else if (isBoss) {
      const r = await runFirstShadow(session);
      outcome = r.outcome;
    } else {
      // single Gloomling: deal one lie from its script (dealable-filtered; the
      // script order is the authored priority, so take the first dealable)
      const dealable = filterDealableLies([...gloom.lieScript], session.satchel);
      const lieId = dealable[0] || gloom.lieScript[0];
      const r = await fightGloomling(session, gloom, lieId, { allowRetreat: true });
      outcome = r;
      if (outcome === 'cleared') {
        outcome = 'victory';
        const sparks = rollInt(session.rand, gloom.sparks);
        const xp = XP_REWARDS[gloom.tier] || XP_REWARDS.trash;
        await session.runRewards({ sparks, xp });
      }
    }
    if (outcome === 'fade') await session.runFade();
  } catch (err) {
    // Never let a UI error strand the player under a dead overlay.
    outcome = 'retreat';
    if (typeof console !== 'undefined') console.error('[glowlands/combat]', err);
  }

  // Rewards land via ctx on wins only (gold stays 0: combat never drops gold —
  // Ember-sparks are the deliberately separate combat currency, Ch. 2.1).
  const won = outcome === 'victory' || outcome === 'clear-empty';
  if (won) {
    if (session.sparks > 0 && ctx.awardSparks) { try { ctx.awardSparks(session.sparks); } catch (e) {} }
    if (session.xp > 0 && ctx.awardXp) { try { ctx.awardXp(session.xp); } catch (e) {} }
    // gold hook kept for contract completeness; always 0 in Phase 1 combat
  }

  session.destroy();
  activeEncounter = false;
  return {
    encounterId: id,
    kind: meta.kind,
    outcome,
    zone: meta.zone,
    clearedLies: session.clearedLies,
    missLog: session.missLog,
    chargeSpends: session.chargeSpends,
    sparks: won ? session.sparks : 0,
    xp: won ? session.xp : 0,
    gold: 0,
    ...(road ? { waymarkerId: road.waymarkerId, relightsWaymarker: won && road.relightsWaymarkerOnClear } : {}),
  };
}

// -----------------------------------------------------------------------------
// Dev hook (matches the game's window-hook convention; stripped from prod).
// Usage from console:  __glowlandsCombat.start('whisperling')
// -----------------------------------------------------------------------------
if (typeof import.meta !== 'undefined' && import.meta.env && import.meta.env.DEV && typeof window !== 'undefined') {
  window.__glowlandsCombat = {
    start: (id, ctx = {}) => startEncounter(ctx, id),
    encounters: [...EAST_ROAD_ENCOUNTERS.map((e) => e.id), FIRST_SHADOW.id, ...Object.keys(GLOOMLINGS)],
  };
}

export default startEncounter;
