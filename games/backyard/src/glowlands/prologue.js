// =============================================================================
// glowlands/prologue.js
// The Meadow Town story script engine — Phase 1 gateway slice (Seal 1 arc).
//
// Design authority: /docs/glowlands-design.md
//   Ch. 7    — Meadow Town: prologue (Zohar compassion test -> Lantern grant),
//              library study, trivia-battle template, Seal 1 + the Lie-Lens,
//              restoration meter + shops-as-service-organs, Gloom-stain creep,
//              save transformation, the Eli farewell at the East Gate.
//   Ch. 2    — Truth & Light (encounters delegated to ./combat.js).
//   Ch. 3.10 — Town Books (reading delegated to ./townbook.js; this module
//              only *points* at the desk and reads its progress blob).
//   Ch. 5.7  — the Lightfound fanfare (every real earn event, never otherwise).
//   Ch. 17   — Phase 1 slice scope (row 7: Meadow Town full zone).
//
// WHAT THIS MODULE IS
//   * A resumable six-beat quest state machine, persisted in glow-state:
//       beat 1  Gloom incursion intro (dawn walk, fog stain, first
//               Whisperling tutorial encounter)
//       beat 2  the Stranger at the Fountain compassion test -> Zohar reveal
//               -> Lantern grant (Lightfound fanfare)
//       beat 3  library unlock + first Town Book session pointer (+ the
//               free-Bram vignette and the four-Whisperling field clear)
//       beat 4  champion trivia battle (combat's visual language in trivia
//               mode) -> Lantern Seal I + the Lie-Lens
//       beat 5  restoration meter + three service quests (feed / repair /
//               the Right Hammer vignettes) + donations + replanting
//       beat 6  save-transformation trigger + the Eli farewell (first East
//               Gate exit only)
//     Beats 1-3 are linear; beats 4 (seal track) and 5 (restoration track)
//     run in PARALLEL after beat 3 (Ch. 7 canon: "seal and restoration are
//     parallel tracks, both required to save"); beat 6 fires automatically
//     the moment both conditions hold.
//   * All dialog / vignette / trivia UI is self-contained DOM in the game's
//     overlay language (theme values copied from dragon-garden-quest.jsx via
//     combat.js — never imported; that file stays untouched). Zero three.js,
//     zero draw calls added.
//   * 3D staging is DIRECTIVES ONLY: fog planes, NPC placement, the lantern
//     wave, gate meshes are the Wire phase's job, driven through optional
//     ctx.world hooks. Every hook is optional-safe; missing hooks no-op so
//     the whole arc is judgeable standalone in a bare page.
//
// WHAT THIS MODULE IS NOT
//   * It never touches dragon-garden-quest.jsx / backend.js / main.jsx.
//   * It never writes lantern brightness (LOCKED, Ch. 5.5) — the Lantern
//     *grant* is a story flag; the tier still derives from real reading days.
//   * It never runs combat itself — encounters delegate to ./combat.js
//     (ctx.startEncounter when the Wire phase supplies it, else directly).
//   * Ember NEVER appears outside the Home Garden (Phase 1 rule) — he exists
//     here only as Eli's farewell joke, per the bible's own script.
//
// ctx CONTRACT (Wire phase supplies this; EVERY member optional-safe):
//   ctx.fetchPassage(ref) -> Promise<{reference,translation,text}|{error}>
//       Runtime ESV. This module displays NO verse text (references + original
//       gists only), so it never calls this itself — it only forwards it to
//       ./combat.js for encounter overlays.
//   ctx.storage        async KV: get(key)->{value}|string, set(key, str).
//                      Falls back to window.storage, then localStorage.
//   ctx.getGlowState() / ctx.setGlowState(glow)   optional overrides for the
//                      persisted 'glow-state' blob; when absent this module
//                      read-modify-writes the 'glow-state' storage key,
//                      PRESERVING every field it does not own (it owns only
//                      glow.quests.meadow_town).
//   ctx.startEncounter(id) -> Promise<EncounterResult>   combat delegate;
//                      default: combat.js startEncounter(ctx, id).
//   ctx.openTownBook()      opens the library reading desk (townbook.open()).
//   ctx.openTodaysPlan()    deep link to today's plan day in the parent app.
//   ctx.satchel.mintSerum({id, ref, family, lieFamily, source, sourceId})
//   ctx.awardXp(n, meta) / ctx.awardGold(n, meta) / ctx.awardFruit(n, meta)
//   ctx.getFruitCount() -> n | Promise<n>     fruit basket (donations/sharing)
//   ctx.spendFruit(n) -> bool | Promise<bool>
//   ctx.grantItem({id, name})                 Wayfarer's Kit grants (Lie-Lens)
//   ctx.onSealEarned(n)                       seal socket + fruit multiplier
//   ctx.sfx / ctx.fanfare(weight)             host audio; fanfare falls back
//                                             to audio-motifs' Lightfound.
//   ctx.world.{ setGloomFog01(t), setGloomStain01(t), setEastGateOpen(b),
//               playSaveTransformation(opts), applySavedState(), openPublicPlots(),
//               setNpcState(id, state), onLanternGranted(), onSatchelGranted(),
//               focus(nodeId) }               3D staging directives (all optional)
//   ctx.settings = { calmMode, reducedFlash } accessibility (forwarded to combat)
//   ctx.mount               overlay parent (default document.body)
//   ctx.now() -> epoch ms   injectable clock;  ctx.random() -> [0,1) seedable RNG
//
// SCRIPTURE RULE (LOCKED): zero verse text is bundled here. Every quiz item,
// recital paraphrase, retelling and dialog line below is ORIGINAL prose
// faithful to the actual chapters — never quotes. Verse *references* and the
// original one-line gists from data/combat-data.js are the only scripture-
// adjacent strings shown.
// =============================================================================

import JOHN_BOOK from './data/john-book.js';
import {
  VERSES,
  STARTER_SERUMS,
  FIRST_STUDY_SESSION_MINTS,
  FIRST_SHADOW,
} from './data/combat-data.js';
import { startEncounter as combatStartEncounter } from './combat.js';
import { playLightfoundFanfare } from './audio-motifs.js';
import { townBookProgressKey } from './townbook.js';

// ---------------------------------------------------------------------------
// Environment
// ---------------------------------------------------------------------------
const IS_DEV = (() => {
  try { return !!(import.meta.env && import.meta.env.DEV); } catch (e) { return false; }
})();

// ---------------------------------------------------------------------------
// Tunables — every number the bible marks tunable lives here.
// ---------------------------------------------------------------------------
export const PROLOGUE_TUNING = Object.freeze({
  // Gloom stain creep (Ch. 7.2): 2 m/day along the ~40 m field run, halting
  // at the fountain's bottom step (t=1). Pressure without punishment.
  stainMetersPerDay: 2,
  stainRunMeters: 40,

  // Compassion test (Ch. 7.5): ~90 s, tunable, NO reward shown.
  cartBundles: 6,          // spilled bundles to regather
  cartWalkHoldMs: 2600,    // hold-to-walk duration for the cart step

  // Field clear at the prologue's end (Ch. 7.5: "clear 4 Gloomlings").
  fieldWhisperlings: 4,

  // Trivia battle template (Ch. 7 — template for all six seals).
  triviaRounds: 5,
  triviaWinsNeeded: 3,
  triviaRecitalRound: 4,   // round 4 is Bram's Recital
  triviaCrowd: 20,         // 20-NPC crowd
  // No real-time timer at seal 1 (later towns add one).

  // Rewards (Ch. 3.1 & the seal-arc tables; all tunable).
  triviaWinXp: 500,
  triviaWinGold: 25,
  studySessionXp: 150,     // per library study session (chapter completed)
  questXp: { raise_roof: 100, loaves: 80, right_hammer: 80 },
  questGold: { raise_roof: 10, loaves: 0, right_hammer: 8 },

  // Restoration meter (Ch. 7.9): saved at Seal I AND 100 pts.
  restorationTarget: 100,
  restQuestPts: { raise_roof: 30, loaves: 25, right_hammer: 20 }, // = 75
  donationPtsPerFruit: 2,
  donationDailyCapPts: 10,
  plotCount: 5,
  ptsPerPlot: 5,           // = 25 total

  // Standing (Ch. 7, post-save; town override of Ch. 3.5 defaults).
  standingFriendAt: 150,
  standingGuardianAt: 400,
  standingPerDonationDay: 10,
  standingPerPlot: 10,
  standingFullReplantBonus: 25,
  standingPerSecret: 15,

  // Save transformation (Ch. 7.2/7.9): 40 lanterns over 6 s; stain burn 10 s.
  saveWaveLanterns: 40,
  saveWaveSec: 6,
  stainBurnSec: 10,
});

/** The glow-state storage key this module read-modify-writes. */
export const GLOW_STATE_KEY = 'glow-state';
/** The namespace this module owns inside glow-state.quests. */
export const QUEST_NS = 'meadow_town';

// ---------------------------------------------------------------------------
// Theme — mirrors dragon-garden-quest.jsx's overlay/dialog visual language
// (values copied via combat.js, never imported: that file stays untouched).
// ---------------------------------------------------------------------------
const GOLD = '#2f7fc1';
const GOLD_BRIGHT = '#ffb845';
const PARCH = '#17497e';
const WOOD_TEX =
  'radial-gradient(130% 90% at 50% -25%, rgba(255,255,255,0.95), rgba(255,255,255,0) 55%), ' +
  'linear-gradient(180deg, #ffffff 0%, #e9f5fd 50%, #cfe9fa 100%)';
const GOLD_BTN_BG = 'linear-gradient(180deg, #ffc85e, #f0931c)';
const GREEN_BTN_BG = 'linear-gradient(180deg, #8fd460, #4f9e2f)';
const FONT = "'Trebuchet MS', 'Segoe UI', sans-serif";
const PANEL_SHADOW =
  'inset 0 0 0 2px rgba(255,255,255,0.85), inset 0 -3px 8px rgba(47,127,193,0.16), 0 8px 18px rgba(23,73,126,0.28)';

// ---------------------------------------------------------------------------
// Cast (Ch. 7.4). Portrait glyphs; NPCs are staged in 3D by the Wire phase —
// these drive the dialog panel only.
// ---------------------------------------------------------------------------
export const MEADOW_NPCS = Object.freeze({
  eli:      Object.freeze({ id: 'eli',      name: 'Eli',                       glyph: '🧓', color: '#7aa85c' }),
  rosie:    Object.freeze({ id: 'rosie',    name: 'Rosie',                     glyph: '🌼', color: '#e88bb0' }),
  maribel:  Object.freeze({ id: 'maribel',  name: 'Maribel Quill',             glyph: '📚', color: '#8f7ac9' }),
  bram:     Object.freeze({ id: 'bram',     name: 'Bram Oakes',                glyph: '🌾', color: '#d8a04a' }),
  grint:    Object.freeze({ id: 'grint',    name: 'Grint',                     glyph: '🔨', color: '#9a8d7f' }),
  tam:      Object.freeze({ id: 'tam',      name: 'Old Tam',                   glyph: '🌧', color: '#7f93a8' }),
  finches:  Object.freeze({ id: 'finches',  name: 'The Finch Twins',           glyph: '🐦', color: '#e0b64a' }),
  stranger: Object.freeze({ id: 'stranger', name: 'A Ragged Stranger',         glyph: '🧣', color: '#8a8a96' }),
  zohar:    Object.freeze({ id: 'zohar',    name: 'Zohar, Emissary of Everlight', glyph: '✨', color: '#ffd27a' }),
  narrator: Object.freeze({ id: 'narrator', name: '',                          glyph: '🕯', color: GOLD_BRIGHT }),
});

// ---------------------------------------------------------------------------
// Service quests (beat 5) — Ch. 7.5 side quests, exactly the bible's three.
// Vignette theming: FEED (Loaves for the Finches), REPAIR (Raise the Roof —
// which also leaves Old Tam warm and dry, the arc's "clothe the shivering"
// beat), and the Right Hammer running joke.
// ---------------------------------------------------------------------------
export const SERVICE_QUESTS = Object.freeze({
  raise_roof: Object.freeze({
    id: 'raise_roof', name: 'Raise the Roof', npc: 'tam', icon: '🏚',
    blurb: 'Fetch Grint’s cedar shingles and rebuild Old Tam’s caved-in roof.',
  }),
  loaves: Object.freeze({
    id: 'loaves', name: 'Loaves for the Finches', npc: 'finches', icon: '🍞',
    blurb: 'Donate 5 home-grown fruit through the Berry Market so the twins eat well.',
    fruitNeeded: 5,
  }),
  right_hammer: Object.freeze({
    id: 'right_hammer', name: 'The Right Hammer', npc: 'grint', icon: '🔔',
    blurb: 'Help Grint fix the chapel bell. He is sure it needs a hammer. It does not.',
  }),
});

// ---------------------------------------------------------------------------
// Trivia content (beat 4). The pool is DEFINED by Maribel's three study
// sessions (Ch. 7: "study is preparation, never trivia-out-of-nowhere"):
//   a) the comprehension questions authored in data/john-book.js (John 1-3),
//   b) verse-to-reference matching over the serums the arc itself granted
//      (original gists from data/combat-data.js — never verse text),
//   c) "who said it" items — ORIGINAL prose over the same three chapters.
// Round 4 is always Bram's Recital (the mangled-name joke made mechanical).
// ---------------------------------------------------------------------------
export const WHO_SAID_ITEMS = Object.freeze([
  Object.freeze({
    prompt: 'Who told the priests from Jerusalem that he was only a voice in the wilderness — not the Christ?',
    choices: ['Nicodemus', 'John the Baptizer', 'Andrew', 'Philip'],
    correctIndex: 1, sourceRef: 'John 1:19-23',
  }),
  Object.freeze({
    prompt: 'At the wedding in Cana, who told the servants to do whatever Jesus said?',
    choices: ['Peter', 'The master of the feast', 'Jesus’ mother', 'Nathanael'],
    correctIndex: 2, sourceRef: 'John 2:5',
  }),
  Object.freeze({
    prompt: 'Who came to Jesus at night and asked how a grown man could possibly be born a second time?',
    choices: ['Nicodemus', 'John the Baptizer', 'Simon Peter', 'A priest from the Jordan'],
    correctIndex: 0, sourceRef: 'John 3:4',
  }),
  Object.freeze({
    prompt: 'Who scoffed that nothing good could come from Nazareth — and then followed Jesus anyway?',
    choices: ['Andrew', 'Philip', 'Nathanael', 'Nicodemus'],
    correctIndex: 2, sourceRef: 'John 1:46',
  }),
  Object.freeze({
    prompt: 'Who hunted down his brother Simon with the news that they had found the Messiah?',
    choices: ['Andrew', 'Philip', 'Nathanael', 'John the Baptizer'],
    correctIndex: 0, sourceRef: 'John 1:41',
  }),
  Object.freeze({
    prompt: 'Who said that Jesus must keep growing greater, while he himself grew smaller?',
    choices: ['Nicodemus', 'Nathanael', 'Simon Peter', 'John the Baptizer'],
    correctIndex: 3, sourceRef: 'John 3:30',
  }),
]);

/**
 * Bram's Recital items (round 4). Bram RETELLS a moment in his own words —
 * never a quote — and mangles one proper name. The player wins the round by
 * tapping the mangled word, then picking the correction. Original prose.
 */
export const RECITAL_ITEMS = Object.freeze([
  Object.freeze({
    before: 'Okay, okay — so this teacher sneaks over at night, right, ',
    mangled: 'Nick-o-DEEM-us',
    after: ' — and Jesus tells him everybody’s gotta be born all over again. Wild.',
    correct: 'Nicodemus',
    decoys: ['Nathanael', 'Nicodemius', 'Demetrius'],
    sourceRef: 'John 3:1-3',
  }),
  Object.freeze({
    before: 'And the fig-tree fella — ',
    mangled: 'Nuh-THAN-ee-ell',
    after: ' — Jesus spots him before they even meet, and the guy just about falls over.',
    correct: 'Nathanael',
    decoys: ['Nathaniah', 'Nicodemus', 'Thaddeus'],
    sourceRef: 'John 1:47-49',
  }),
  Object.freeze({
    before: 'Then there’s the wedding — water into the good stuff — that was at ',
    mangled: 'KAY-nah… Canaan?',
    after: ' Anyway, the servants knew the whole time.',
    correct: 'Cana',
    decoys: ['Canaan', 'Cana-ville', 'Capernaum'],
    sourceRef: 'John 2:1-11',
  }),
  Object.freeze({
    before: 'After the wedding they all head down to ',
    mangled: 'Ca-PER-nom',
    after: ' for a few days — him, his mother, his brothers, the disciples, everybody.',
    correct: 'Capernaum',
    decoys: ['Capernum', 'Cana', 'Capernia'],
    sourceRef: 'John 2:12',
  }),
]);

/** Serum ids whose (ref + original gist) feed the verse-to-reference rounds. */
const TRIVIA_SERUM_IDS = Object.freeze([...STARTER_SERUMS, ...FIRST_STUDY_SESSION_MINTS]);

// ---------------------------------------------------------------------------
// Small utils
// ---------------------------------------------------------------------------
function hashStr(s) {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); }
  return h >>> 0;
}
function mulberry32(a) {
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
function shuffled(arr, rng) {
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}
function dayKey(d = new Date()) {
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}
const wait = (ms) => new Promise((r) => setTimeout(r, ms));

/**
 * Build a shuffled trivia pool for one battle attempt. Pure + seeded so a
 * rematch ("Best two of three more?") genuinely reshuffles. Exported for
 * tests and the Wire phase's dev hooks.
 */
export function buildTriviaPool(seedStr = 'meadow-1', book = JOHN_BOOK) {
  const rng = mulberry32(hashStr(String(seedStr)));
  const pool = [];
  for (const ch of book.chapters) {
    for (const s of ch.sections) {
      if (s.question) {
        pool.push({
          type: 'comprehension',
          prompt: s.question.prompt,
          choices: s.question.choices,
          correctIndex: s.question.correctIndex,
          sourceRef: s.question.answerRef || s.reference,
        });
      }
    }
  }
  // Verse-to-reference matching over the arc's own serum grants (gists are
  // original prose from combat-data — the ESV is never bundled or quoted).
  const refPool = TRIVIA_SERUM_IDS.map((id) => VERSES[id]).filter(Boolean);
  for (const v of refPool) {
    const decoys = shuffled(refPool.filter((o) => o.ref !== v.ref).map((o) => o.ref), rng).slice(0, 3);
    const choices = shuffled([v.ref, ...decoys], rng);
    pool.push({
      type: 'verse-ref',
      prompt: `Which verse in your satchel says it best? — “${v.gist}”`,
      choices,
      correctIndex: choices.indexOf(v.ref),
      sourceRef: v.ref,
    });
  }
  for (const w of WHO_SAID_ITEMS) pool.push({ type: 'who-said', ...w });
  return shuffled(pool, rng);
}

/**
 * Gloom-stain progress, 0 (east wall) .. 1 (fountain's bottom step), from
 * days since the prologue began. Halts at 1, burns to 0 on save. Pure.
 */
export function computeGloomStain01(state, nowMs, tuning = PROLOGUE_TUNING) {
  if (!state || typeof state.startedAt !== 'number') return 0;
  if (state.flags && state.flags.saved) return 0;
  const days = Math.max(0, (nowMs - state.startedAt) / 86400000);
  return Math.min(1, (days * tuning.stainMetersPerDay) / tuning.stainRunMeters);
}

// ---------------------------------------------------------------------------
// Persistent state — the quest blob inside glow-state.quests.meadow_town.
// Every beat is resumable: sub-step indices and counters persist after every
// completed step, never mid-animation.
// ---------------------------------------------------------------------------
export function defaultPrologueState(nowMs = Date.now()) {
  return {
    v: 1,
    startedAt: nowMs,
    beat: 1,                  // furthest LINEAR beat reached (1..3; 4 = prologue done)
    sub: 0,                   // step index inside the active linear beat
    flags: {
      john812Granted: false,
      phil413Granted: false,
      lanternGranted: false,
      planPointerShown: false,
      satchelGranted: false,
      firstStudyMinted: false,
      bramFreed: false,
      firstShadowCleared: false,
      seal1: false,
      lieLens: false,
      saved: false,
      farewellDone: false,
    },
    fieldsCleared: 0,          // 0..fieldWhisperlings (beat 3 tail)
    study: { sessions: 0 },    // completed library study sessions (chapters)
    trivia: { attempts: 0, won: false },
    restoration: {
      points: 0,
      quests: { raise_roof: false, loaves: false, right_hammer: false },
      donations: { day: null, ptsToday: 0, daysCount: 0 },
      plots: [false, false, false, false, false],
    },
    standing: { points: 0, tier: null },
  };
}

// ---------------------------------------------------------------------------
// Storage adapter — window.storage shape ({get -> {value}|string, set}) with
// a localStorage fallback so the module works in a bare dev page.
// ---------------------------------------------------------------------------
function makeStorage(ctxStorage) {
  const s = ctxStorage || (typeof window !== 'undefined' ? window.storage : null);
  if (s && typeof s.get === 'function' && typeof s.set === 'function') {
    return {
      async get(key) {
        try {
          const row = await s.get(key);
          if (row == null) return null;
          if (typeof row === 'string') return row;
          if (typeof row.value === 'string') return row.value;
          return null;
        } catch (e) { return null; } // missing-key throw = empty
      },
      async set(key, str) { try { await s.set(key, str); } catch (e) { /* offline: state stays in memory */ } },
    };
  }
  return {
    async get(key) { try { return localStorage.getItem(key); } catch (e) { return null; } },
    async set(key, str) { try { localStorage.setItem(key, str); } catch (e) {} },
  };
}

// ---------------------------------------------------------------------------
// DOM helpers + injected stylesheet
// ---------------------------------------------------------------------------
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

const CSS_ID = 'glowlands-prologue-css';
function injectStyles() {
  if (typeof document === 'undefined' || document.getElementById(CSS_ID)) return;
  const s = document.createElement('style');
  s.id = CSS_ID;
  s.textContent = `
@keyframes gpFadeIn { from{opacity:0} to{opacity:1} }
@keyframes gpSlideUp { from{opacity:0; transform:translateY(16px)} to{opacity:1; transform:translateY(0)} }
@keyframes gpPop { 0%{transform:scale(0.4); opacity:0} 60%{transform:scale(1.06)} 100%{transform:scale(1); opacity:1} }
@keyframes gpGlow { 0%,100%{filter:drop-shadow(0 0 6px rgba(255,210,120,0.5))} 50%{filter:drop-shadow(0 0 18px rgba(255,210,120,0.95))} }
@keyframes gpBob { 0%,100%{transform:translateY(0)} 50%{transform:translateY(-4px)} }
@keyframes gpShiver { 0%,100%{transform:translateX(0)} 25%{transform:translateX(-2px)} 75%{transform:translateX(2px)} }
@keyframes gpSway { 0%,100%{transform:rotate(-2deg)} 50%{transform:rotate(2deg)} }
@keyframes gpFlare { 0%{opacity:0; transform:scale(0.35)} 18%{opacity:1; transform:scale(1)} 80%{opacity:1; transform:scale(1.04)} 100%{opacity:0; transform:scale(1.12)} }
@keyframes gpHammer { 0%{left:0%} 50%{left:calc(100% - 14px)} 100%{left:0%} }
.gp-btn:not([disabled]):active { transform: scale(0.96); }
.gp-choice:not([disabled]):active { transform: scale(0.97); }
`;
  document.head.appendChild(s);
}

// ---------------------------------------------------------------------------
// Tiny sound kit — same synth grammar as the host game / combat.js. Lazy;
// nothing is created until first play; iOS resume attempted per play. The
// Lightfound fanfare itself always defers to ctx.fanfare or audio-motifs.
// ---------------------------------------------------------------------------
const snd = (() => {
  let AC = null, bus = null;
  function ensure() {
    if (typeof window === 'undefined') return false;
    if (AC) { if (AC.state === 'suspended') AC.resume().catch(() => {}); return true; }
    try { AC = new (window.AudioContext || window.webkitAudioContext)(); } catch (e) { return false; }
    bus = AC.createGain(); bus.gain.value = 0.45; bus.connect(AC.destination);
    return true;
  }
  function tone(freq, at, dur, vol, type = 'triangle', slideTo = null) {
    if (!ensure()) return;
    const t = AC.currentTime + at;
    const o = AC.createOscillator(); o.type = type; o.frequency.setValueAtTime(freq, t);
    if (slideTo) o.frequency.exponentialRampToValueAtTime(Math.max(20, slideTo), t + dur);
    const g = AC.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(vol, t + 0.015);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    o.connect(g); g.connect(bus);
    o.start(t); o.stop(t + dur + 0.05);
  }
  function noise(at, dur, vol, freq = 800, ftype = 'bandpass') {
    if (!ensure()) return;
    const t = AC.currentTime + at;
    const b = AC.createBuffer(1, Math.max(1, Math.floor(AC.sampleRate * dur)), AC.sampleRate);
    const d = b.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
    const src = AC.createBufferSource(); src.buffer = b;
    const f = AC.createBiquadFilter(); f.type = ftype; f.frequency.value = freq;
    const g = AC.createGain(); g.gain.setValueAtTime(vol, t); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    src.connect(f); f.connect(g); g.connect(bus);
    src.start(t); src.stop(t + dur);
  }
  return {
    click() { tone(880, 0, 0.06, 0.1, 'square'); },
    blip() { tone(523.25, 0, 0.08, 0.1); tone(659.25, 0.05, 0.1, 0.09); },
    right() { tone(659.25, 0, 0.14, 0.14); tone(987.77, 0.08, 0.24, 0.12); },
    wrong() { tone(196, 0, 0.22, 0.13, 'sawtooth', 130); },
    cheer() { noise(0, 0.5, 0.06, 1800, 'highpass'); [523.25, 659.25, 783.99].forEach((f, i) => tone(f, i * 0.05, 0.3, 0.08)); },
    murmur() { noise(0, 0.45, 0.05, 350, 'lowpass'); tone(180, 0, 0.3, 0.05, 'sine', 140); },
    hammerHit() { noise(0, 0.08, 0.16, 2500, 'highpass'); tone(220, 0, 0.1, 0.14, 'square', 160); },
    thud() { tone(90, 0, 0.18, 0.16, 'sine', 60); noise(0, 0.1, 0.06, 300, 'lowpass'); },
    bundle() { tone(392, 0, 0.09, 0.1); tone(523.25, 0.05, 0.12, 0.09); },
    lanternChime(i) { const penta = [523.25, 587.33, 659.25, 783.99, 880, 1046.5, 1174.66, 1318.5]; tone(penta[i % penta.length], 0, 0.42, 0.13); },
    bellSour() { tone(415.3, 0, 0.6, 0.12, 'triangle', 400); tone(427, 0.01, 0.55, 0.08, 'triangle', 410); },
    bellTrue() { tone(523.25, 0, 0.9, 0.13); tone(1046.5, 0.02, 0.7, 0.07, 'sine'); },
  };
})();

// =============================================================================
// createPrologue(ctx, opts) — the story engine instance.
// =============================================================================
export function createPrologue(ctx = {}, opts = {}) {
  const tuning = { ...PROLOGUE_TUNING, ...(opts.tuning || {}) };
  const storage = makeStorage(ctx.storage);
  const now = typeof ctx.now === 'function' ? ctx.now : Date.now;
  const rand = typeof ctx.random === 'function' ? ctx.random : Math.random;
  const settings = ctx.settings || {};
  const mountEl = () => ctx.mount || document.body;
  const world = () => ctx.world || {};

  // ---- state -----------------------------------------------------------------
  let state = defaultPrologueState(now());
  let loaded = false;
  let started = false;
  let disposed = false;
  let interactBusy = false;
  const listeners = new Set();

  function emit() {
    for (const cb of listeners) { try { cb(getPublicState()); } catch (e) {} }
    updateRestorationChip();
  }

  // --- glow-state read-modify-write (preserves every foreign field) ----------
  async function loadGlow() {
    if (typeof ctx.getGlowState === 'function') {
      try {
        const g = await ctx.getGlowState();
        if (g && typeof g === 'object') return Array.isArray(g) ? { completedDays: g } : g;
      } catch (e) {}
    }
    const raw = await storage.get(GLOW_STATE_KEY);
    if (raw) {
      try {
        const g = JSON.parse(raw);
        if (g && typeof g === 'object') return Array.isArray(g) ? { completedDays: g } : g;
      } catch (e) { /* corrupt blob: start fresh, never clobber other keys */ }
    }
    return {};
  }
  async function persist() {
    const glow = await loadGlow();
    glow.quests = glow.quests || {};
    glow.quests[QUEST_NS] = state;
    if (typeof ctx.setGlowState === 'function') {
      try { await ctx.setGlowState(glow); return; } catch (e) {}
    }
    await storage.set(GLOW_STATE_KEY, JSON.stringify(glow));
  }
  async function load() {
    const glow = await loadGlow();
    const saved = glow.quests && glow.quests[QUEST_NS];
    if (saved && saved.v === 1) {
      // Merge onto defaults so schema additions never crash an old save.
      const d = defaultPrologueState(saved.startedAt || now());
      state = {
        ...d, ...saved,
        flags: { ...d.flags, ...(saved.flags || {}) },
        study: { ...d.study, ...(saved.study || {}) },
        trivia: { ...d.trivia, ...(saved.trivia || {}) },
        restoration: {
          ...d.restoration, ...(saved.restoration || {}),
          quests: { ...d.restoration.quests, ...((saved.restoration || {}).quests || {}) },
          donations: { ...d.restoration.donations, ...((saved.restoration || {}).donations || {}) },
          plots: Array.isArray((saved.restoration || {}).plots) ? saved.restoration.plots.slice(0, tuning.plotCount) : d.restoration.plots,
        },
        standing: { ...d.standing, ...(saved.standing || {}) },
      };
    }
    loaded = true;
  }

  // ---- optional-safe ctx forwarding ------------------------------------------
  function safe(fn, ...args) { if (typeof fn === 'function') { try { return fn(...args); } catch (e) {} } return undefined; }
  const awardXp = (n, meta) => safe(ctx.awardXp || ctx.awardXP, n, meta);
  const awardGold = (n, meta) => safe(ctx.awardGold, n, meta);
  const mintSerum = (payload) => safe(ctx.satchel && ctx.satchel.mintSerum, payload);
  const fanfare = (weight = 'full') => {
    // ctx.fanfare speaks townbook's dialect ('full'|'small'); audio-motifs
    // speaks the bible's ('full'|'pickup'). Same jingle either way (Ch. 5.7).
    if (typeof ctx.fanfare === 'function') { try { ctx.fanfare(weight === 'full' ? 'full' : 'small'); return; } catch (e) {} }
    try { playLightfoundFanfare({ weight: weight === 'full' ? 'full' : 'pickup' }); } catch (e) {}
  };
  const fight = (id) => {
    if (typeof ctx.startEncounter === 'function') { try { return Promise.resolve(ctx.startEncounter(id)); } catch (e) {} }
    return combatStartEncounter(ctx, id);
  };
  async function getFruit() {
    try { const n = await safe(ctx.getFruitCount); return typeof n === 'number' ? n : null; } catch (e) { return null; }
  }
  async function spendFruit(n) {
    if (typeof ctx.spendFruit !== 'function') return true; // narrative fallback
    try { return (await ctx.spendFruit(n)) !== false; } catch (e) { return false; }
  }

  // ===========================================================================
  // Dialog engine — bottom speech panel in the game's overlay language.
  // Tap once to complete the typewriter, tap again to advance. z-index sits
  // BELOW combat's overlay (60+) so encounters always stack on top.
  // ===========================================================================
  let dlgRoot = null;
  function closeDialog() { if (dlgRoot) { try { dlgRoot.remove(); } catch (e) {} dlgRoot = null; } }

  function dialogShell() {
    closeDialog();
    injectStyles();
    dlgRoot = el('div', {
      position: 'fixed', left: '0', right: '0', bottom: '0', zIndex: 55,
      display: 'flex', justifyContent: 'center', pointerEvents: 'none',
      padding: '0 10px calc(14px + env(safe-area-inset-bottom, 0px))', fontFamily: FONT,
    });
    mountEl().appendChild(dlgRoot);
    return dlgRoot;
  }

  /** speak([{who, text}]) — sequential lines, tap-to-advance. */
  function speak(lines) {
    return new Promise((resolve) => {
      const root = dialogShell();
      let i = 0;
      const panel = el('div', {
        pointerEvents: 'auto', cursor: 'pointer', width: 'min(560px, 96vw)',
        background: WOOD_TEX, borderRadius: '14px', boxShadow: PANEL_SHADOW,
        border: `2px solid ${GOLD}`, padding: '12px 14px', display: 'flex', gap: '12px',
        alignItems: 'flex-start', animation: 'gpSlideUp 0.25s ease',
      });
      const portrait = el('div', {
        width: '46px', height: '46px', borderRadius: '50%', flex: '0 0 auto',
        background: 'rgba(255,255,255,0.8)', border: `2px solid ${GOLD}`,
        display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '26px',
      });
      const col = el('div', { flex: '1 1 auto', minWidth: '0' });
      const nameEl = el('div', { fontSize: '12px', fontWeight: '800', letterSpacing: '0.4px', marginBottom: '2px' });
      const textEl = el('div', { fontSize: '14.5px', lineHeight: '1.45', color: PARCH, minHeight: '42px' });
      const cont = el('div', { textAlign: 'right', fontSize: '13px', color: GOLD, animation: 'gpBob 1.2s infinite' }, { text: '▾' });
      col.append(nameEl, textEl, cont);
      panel.append(portrait, col);
      root.appendChild(panel);

      let timer = null, full = '', done = false;
      function show(idx) {
        const line = lines[idx];
        const npc = MEADOW_NPCS[line.who] || MEADOW_NPCS.narrator;
        portrait.textContent = npc.glyph;
        portrait.style.borderColor = npc.color;
        nameEl.textContent = npc.name;
        nameEl.style.color = npc.color === GOLD_BRIGHT ? GOLD : npc.color;
        full = line.text; done = false;
        textEl.textContent = '';
        cont.style.visibility = 'hidden';
        let c = 0;
        clearInterval(timer);
        timer = setInterval(() => {
          c += 2;
          textEl.textContent = full.slice(0, c);
          if (c >= full.length) { clearInterval(timer); done = true; cont.style.visibility = 'visible'; }
        }, 18);
      }
      panel.addEventListener('click', () => {
        snd.click();
        if (!done) { clearInterval(timer); textEl.textContent = full; done = true; cont.style.visibility = 'visible'; return; }
        i++;
        if (i >= lines.length) { closeDialog(); resolve(); } else show(i);
      });
      show(0);
    });
  }

  /** choose(who, prompt, options[]) -> Promise<index>. */
  function choose(who, prompt, options) {
    return new Promise((resolve) => {
      const root = dialogShell();
      const npc = MEADOW_NPCS[who] || MEADOW_NPCS.narrator;
      const panel = el('div', {
        pointerEvents: 'auto', width: 'min(560px, 96vw)', background: WOOD_TEX,
        borderRadius: '14px', boxShadow: PANEL_SHADOW, border: `2px solid ${GOLD}`,
        padding: '13px 15px', animation: 'gpSlideUp 0.25s ease',
      });
      panel.appendChild(el('div', { fontSize: '12px', fontWeight: '800', color: npc.color, marginBottom: '4px' }, { text: `${npc.glyph} ${npc.name}` }));
      panel.appendChild(el('div', { fontSize: '14.5px', lineHeight: '1.45', color: PARCH, marginBottom: '10px' }, { text: prompt }));
      options.forEach((opt, idx) => {
        const b = el('button', {
          display: 'block', width: '100%', textAlign: 'left', margin: '6px 0',
          background: 'rgba(255,255,255,0.85)', border: `2px solid ${GOLD}`, borderRadius: '10px',
          padding: '9px 12px', fontSize: '13.5px', fontWeight: '700', color: PARCH,
          fontFamily: FONT, cursor: 'pointer', transition: 'transform 0.08s',
        }, { text: opt, className: 'gp-choice' });
        b.addEventListener('click', () => { snd.click(); closeDialog(); resolve(idx); });
        panel.appendChild(b);
      });
      root.appendChild(panel);
    });
  }

  /** Full-screen milestone card (grants, reveals, the save moment). */
  function card({ icon, title, lines = [], cta = 'Continue', glow = false }) {
    return new Promise((resolve) => {
      injectStyles();
      const shade = el('div', {
        position: 'fixed', inset: '0', zIndex: 58, background: 'rgba(12,14,28,0.5)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        animation: 'gpFadeIn 0.25s ease', fontFamily: FONT, padding: '16px',
      });
      const panel = el('div', {
        background: WOOD_TEX, borderRadius: '16px', boxShadow: PANEL_SHADOW,
        border: `2.5px solid ${glow ? GOLD_BRIGHT : GOLD}`, padding: '22px 26px 18px',
        width: 'min(340px, 90vw)', textAlign: 'center', animation: 'gpPop 0.4s cubic-bezier(0.3,1.4,0.5,1)',
      });
      if (glow && !settings.reducedFlash) panel.style.boxShadow = `0 0 34px rgba(255,210,120,0.6), ${PANEL_SHADOW}`;
      panel.appendChild(el('div', { fontSize: '46px', marginBottom: '6px', animation: glow ? 'gpGlow 1.6s infinite' : 'none' }, { text: icon }));
      panel.appendChild(el('div', { fontSize: '17px', fontWeight: '900', color: PARCH, marginBottom: '8px' }, { text: title }));
      for (const l of lines) {
        panel.appendChild(el('div', { fontSize: '13.5px', lineHeight: '1.5', color: PARCH, opacity: '0.9', marginBottom: '6px' }, { text: l }));
      }
      const b = el('button', {
        marginTop: '10px', background: GOLD_BTN_BG, border: '2px solid #b06a10', borderRadius: '11px',
        padding: '10px 26px', fontSize: '14px', fontWeight: '900', color: '#5a3305',
        fontFamily: FONT, cursor: 'pointer', transition: 'transform 0.08s',
      }, { text: cta, className: 'gp-btn' });
      b.addEventListener('click', () => { snd.blip(); shade.remove(); resolve(); });
      panel.appendChild(b);
      shade.appendChild(panel);
      mountEl().appendChild(shade);
    });
  }

  // ===========================================================================
  // World directives — every 3D consequence flows through here, optional-safe.
  // ===========================================================================
  function pushWorldState() {
    const w = world();
    safe(w.setGloomStain01, computeGloomStain01(state, now(), tuning));
    safe(w.setGloomFog01, state.beat >= 4 ? 0 : state.beat >= 2 ? Math.max(0, 1 - state.fieldsCleared / tuning.fieldWhisperlings) : state.beat === 1 && state.sub >= 2 ? 1 : 0);
    safe(w.setEastGateOpen, !!state.flags.saved);
    if (state.flags.saved) safe(w.applySavedState);
  }

  // ===========================================================================
  // BEAT 1 — Gloom incursion intro.
  // Dawn walk with Eli -> the fog pours over the east wall -> the first
  // Whisperling tutorial encounter (combat.js; guaranteed winnable — the
  // starter serums counter every Whisperling family the tutorial rolls).
  // ===========================================================================
  const BEAT1_STEPS = [
    {
      id: 'dawn-walk',
      async run() {
        safe(world().focus, 'west_gate');
        await speak([
          { who: 'eli', text: 'Up with the sun, then. Come on — the town’s just past the arch, and mornings like this don’t keep.' },
          { who: 'eli', text: 'Meadow Town’s a good place. Sleepy, maybe. Lately though… folk say the east fields have gone grey.' },
          { who: 'eli', text: 'Before you go in — take this. An old card of mine. It carries a promise about walking in light instead of dark.' },
        ]);
        if (!state.flags.john812Granted) {
          const v = VERSES.john_8_12;
          mintSerum({ id: 'john_8_12', ref: v.ref, family: v.family, lieFamily: 'worthlessness', source: 'prologue', sourceId: 'eli-gate-card' });
          state.flags.john812Granted = true;
          await card({ icon: '🃏', title: 'Eli’s Card — John 8:12', lines: ['A promise of light kept close.', 'It sits in your Verse Satchel now.'], glow: true });
          fanfare('pickup');
        }
        await speak([
          { who: 'eli', text: 'Keep it where you can reach it. Words like that are for saying out loud, not for keeping in pockets.' },
          { who: 'eli', text: 'Go on through. Rosie at the seed shop will point you around. I’ll mind the garden.' },
        ]);
      },
    },
    {
      id: 'fog-incursion',
      async run() {
        safe(world().focus, 'east_fields');
        safe(world().setGloomFog01, 1);
        snd.thud();
        await card({
          icon: '🌫', title: 'The Gloom Pours In',
          lines: [
            'A violet-grey fog spills over the east wall and settles on the fields.',
            'Somewhere inside it, something is whispering.',
          ],
          cta: 'Go closer',
        });
        await speak([
          { who: 'rosie', text: 'Oh — careful, dear! That fog’s been creeping toward the square a little more every day.' },
          { who: 'rosie', text: 'It gets into your ears, that stuff. Says things. Unkind, untrue things. Don’t you listen to a word of it.' },
        ]);
      },
    },
    {
      id: 'tutorial-encounter',
      async run() {
        if (!state.flags.phil413Granted) {
          const v = VERSES.phil_4_13;
          mintSerum({ id: 'phil_4_13', ref: v.ref, family: v.family, lieFamily: 'fear', source: 'prologue', sourceId: 'tutorial-grant' });
          state.flags.phil413Granted = true;
          await speak([
            { who: 'eli', text: 'Psst — caught up with you. One more card before you face that thing: strength for everything you’ll meet. Say it like you mean it.' },
          ]);
          fanfare('pickup');
        }
        // The first Whisperling. combat.js owns the whole encounter overlay;
        // a fade/retreat just re-offers warmly — the tutorial cannot be lost.
        let cleared = false;
        while (!cleared && !disposed) {
          const res = await fight('whisperling');
          if (res && (res.outcome === 'victory' || res.outcome === 'clear-empty')) cleared = true;
          else {
            await speak([{ who: 'eli', text: 'It’s alright. A whisper only wins if you stop answering. Breathe, pick the true word, and try again.' }]);
          }
        }
        safe(world().setGloomFog01, 0.85);
        await speak([
          { who: 'eli', text: 'There! See how it scattered? Lies are loud, but they’re thin. The truth said out loud goes right through them.' },
          { who: 'rosie', text: 'Well done, dear. Now — someone’s been sitting by the fountain all morning. Poor soul looks like the road’s been hard on him.' },
        ]);
      },
    },
  ];

  // ===========================================================================
  // BEAT 2 — The Stranger at the Fountain (the Lantern origin, Ch. 7.5).
  // Quiet compassion test: regather bundles, share fruit, walk the cart.
  // NO reward is shown until the last bundle lands. Then the Zohar reveal
  // and the Lantern grant on the Lightfound fanfare.
  // ===========================================================================
  function cartVignette() {
    return new Promise((resolve) => {
      injectStyles();
      const shade = el('div', {
        position: 'fixed', inset: '0', zIndex: 56, background: 'rgba(12,14,28,0.35)',
        display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: FONT, padding: '14px',
        animation: 'gpFadeIn 0.25s ease',
      });
      const panel = el('div', {
        background: WOOD_TEX, borderRadius: '16px', boxShadow: PANEL_SHADOW, border: `2px solid ${GOLD}`,
        padding: '16px 18px', width: 'min(380px, 92vw)', textAlign: 'center',
      });
      const title = el('div', { fontSize: '15px', fontWeight: '900', color: PARCH, marginBottom: '4px' }, { text: 'The Spilled Handcart' });
      const hint = el('div', { fontSize: '12.5px', color: PARCH, opacity: '0.85', marginBottom: '10px' }, { text: 'His bundles are everywhere. He hasn’t asked for anything.' });
      const stage = el('div', { position: 'relative', height: '150px', marginBottom: '10px' });
      const cart = el('div', { position: 'absolute', left: '50%', bottom: '2px', transform: 'translateX(-50%)', fontSize: '40px', animation: 'gpSway 2.4s infinite' }, { text: '🛒' });
      stage.appendChild(cart);
      panel.append(title, hint, stage);
      shade.appendChild(panel);
      mountEl().appendChild(shade);

      // Step 1: regather the scattered bundles (tap each).
      let left = tuning.cartBundles;
      for (let i = 0; i < tuning.cartBundles; i++) {
        const b = el('div', {
          position: 'absolute', fontSize: '24px', cursor: 'pointer', userSelect: 'none',
          left: `${8 + rand() * 78}%`, top: `${5 + rand() * 55}%`, transition: 'left 0.4s ease, top 0.4s ease, opacity 0.4s',
        }, { text: '🎒' });
        b.addEventListener('click', () => {
          if (b.dataset.done) return;
          b.dataset.done = '1';
          snd.bundle();
          b.style.left = '48%'; b.style.top = '70%'; b.style.opacity = '0';
          left--;
          if (left === 0) setTimeout(stepShare, 450);
        }, { once: false });
        stage.appendChild(b);
      }

      // Step 2: share fruit from your satchel (spends 1 if the wallet exists;
      // otherwise the kindness is narrative — never blocked by an empty bag).
      async function stepShare() {
        hint.textContent = 'He looks like he has not eaten today.';
        const btn = el('button', {
          background: GREEN_BTN_BG, border: '2px solid #2f6b1a', borderRadius: '11px', padding: '10px 22px',
          fontSize: '13.5px', fontWeight: '900', color: '#123c06', fontFamily: FONT, cursor: 'pointer',
        }, { text: '🍎 Share a fruit from your satchel', className: 'gp-btn' });
        btn.addEventListener('click', async () => {
          btn.disabled = true;
          const n = await getFruit();
          if (n === null || n > 0) await spendFruit(1);
          snd.blip();
          btn.remove();
          stepWalk();
        });
        panel.appendChild(btn);
      }

      // Step 3: hold to walk the cart to shelter.
      function stepWalk() {
        hint.textContent = 'Hold to walk the cart to the market awning.';
        const barWrap = el('div', { height: '14px', borderRadius: '7px', background: 'rgba(23,73,126,0.15)', overflow: 'hidden', margin: '4px 8px' });
        const bar = el('div', { height: '100%', width: '0%', background: GOLD_BTN_BG, transition: 'width 0.1s linear' });
        barWrap.appendChild(bar);
        const btn = el('button', {
          marginTop: '8px', background: GOLD_BTN_BG, border: '2px solid #b06a10', borderRadius: '11px',
          padding: '10px 22px', fontSize: '13.5px', fontWeight: '900', color: '#5a3305', fontFamily: FONT,
          cursor: 'pointer', touchAction: 'none',
        }, { text: 'Hold to push', className: 'gp-btn' });
        panel.append(barWrap, btn);
        let p = 0, iv = null;
        const startHold = (e) => {
          e.preventDefault();
          clearInterval(iv);
          iv = setInterval(() => {
            p = Math.min(1, p + 100 / tuning.cartWalkHoldMs);
            bar.style.width = `${Math.round(p * 100)}%`;
            if (p >= 1) {
              clearInterval(iv);
              snd.thud();
              setTimeout(() => { shade.remove(); resolve(); }, 350);
            }
          }, 100);
        };
        const endHold = () => clearInterval(iv);
        btn.addEventListener('pointerdown', startHold);
        btn.addEventListener('pointerup', endHold);
        btn.addEventListener('pointercancel', endHold);
        btn.addEventListener('pointerleave', endHold);
      }
    });
  }

  const BEAT2_STEPS = [
    {
      id: 'stranger-meet',
      async run() {
        safe(world().focus, 'fountain');
        await speak([
          { who: 'narrator', text: 'By the fountain, a ragged traveler kneels over a tipped handcart. Bundles lie scattered on the cobbles.' },
          { who: 'stranger', text: '…No, no — don’t trouble yourself. I’ll manage. I always manage.' },
        ]);
      },
    },
    {
      id: 'compassion-test',
      async run() {
        // 90 s of quiet helping, no reward shown (Ch. 7.5, LOCKED intent).
        await cartVignette();
      },
    },
    {
      id: 'zohar-reveal',
      async run() {
        snd.bellTrue();
        await card({
          icon: '✨', title: 'The Rags Fall Away',
          lines: [
            'The stranger straightens. The road-dust resolves into travel-worn white and brass.',
            'He has tested travelers at this fountain since the roads were young.',
          ],
          cta: 'Listen', glow: true,
        });
        await speak([
          { who: 'zohar', text: 'Every traveler who passes this fountain is weighed — not by their strength, but by their stooping.' },
          { who: 'zohar', text: 'You knelt for a stranger’s bundles and asked for nothing. Light belongs to those who stoop.' },
          { who: 'zohar', text: 'So carry some. Not mine to keep — and now, not yours to keep either. Light is only ever held out.' },
        ]);
      },
    },
    {
      id: 'lantern-grant',
      async run() {
        state.flags.lanternGranted = true;
        safe(world().onLanternGranted);
        fanfare('full');
        await card({
          icon: '🏮', title: 'The Lantern',
          lines: [
            'Zohar sets a small brass lantern in your hands. The wick takes light from nowhere at all.',
            'Its brightness will rise and rest with your real reading — no one can wind it but you.',
          ],
          cta: 'Raise it', glow: true,
        });
        await speak([
          { who: 'zohar', text: 'It burns on the Word, not on oil. Read, and it will blaze. Rest, and it will only dim — never go out, and never shame you.' },
          { who: 'zohar', text: 'The fog on those fields hates a lit lantern. Go and see.' },
        ]);
        if (!state.flags.planPointerShown) {
          state.flags.planPointerShown = true;
          // The first plan day is the reading beat that lights the lantern to
          // Flame (Ch. 7.5). We only *point*; the parent app owns the reading
          // record — this module never writes brightness (LOCKED, Ch. 5.5).
          const wantsRead = await choose('zohar', 'Feed it its first light now?', [
            '📖 Open today’s reading', 'Later — the fields first',
          ]);
          if (wantsRead === 0) safe(ctx.openTodaysPlan);
        }
      },
    },
  ];

  // ===========================================================================
  // BEAT 3 — Library unlock + first Town Book session pointer, then the
  // free-Bram vignette and the four-Whisperling field clear.
  // ===========================================================================

  /** Poll the Town Book progress blob for completed chapters (study sessions). */
  async function readStudySessionsFromTownBook() {
    try {
      const raw = await storage.get(townBookProgressKey('john'));
      if (!raw) return state.study.sessions;
      const p = JSON.parse(raw);
      if (!p || !p.completed) return state.study.sessions;
      let done = 0;
      for (const ch of JOHN_BOOK.chapters) {
        if (ch.sections.every((s) => p.completed[s.id])) done++;
      }
      return Math.max(state.study.sessions, done);
    } catch (e) { return state.study.sessions; }
  }

  async function syncStudySessions() {
    const n = await readStudySessionsFromTownBook();
    if (n > state.study.sessions) {
      const gained = n - state.study.sessions;
      state.study.sessions = n;
      for (let i = 0; i < gained; i++) awardXp(tuning.studySessionXp, { source: 'library-study', town: QUEST_NS });
      await persist();
      emit();
    }
    return state.study.sessions;
  }

  /** The free-Bram satchel pick: a scripted, warm-retry family choice. */
  function freeBramVignette() {
    return new Promise((resolve) => {
      injectStyles();
      const shade = el('div', {
        position: 'fixed', inset: '0', zIndex: 56, background: 'rgba(12,14,28,0.5)',
        display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: FONT, padding: '14px',
        animation: 'gpFadeIn 0.25s ease',
      });
      const panel = el('div', {
        background: WOOD_TEX, borderRadius: '16px', boxShadow: PANEL_SHADOW, border: `2px solid ${GOLD}`,
        padding: '16px 18px', width: 'min(400px, 94vw)', textAlign: 'center',
      });
      panel.appendChild(el('div', { fontSize: '38px', animation: 'gpShiver 0.5s infinite' }, { text: '🌾' }));
      panel.appendChild(el('div', { fontSize: '14.5px', fontWeight: '900', color: PARCH, margin: '6px 0 2px' }, { text: 'Bram stands frozen mid-field.' }));
      const lieEl = el('div', {
        fontSize: '14px', fontStyle: 'italic', color: '#5a4a8a', margin: '4px 0 12px',
        animation: settings.reducedFlash ? 'none' : 'gpSway 3s infinite',
      }, { text: '“One mistake and you’re done.”' });
      panel.appendChild(lieEl);
      panel.appendChild(el('div', { fontSize: '12.5px', color: PARCH, opacity: '0.85', marginBottom: '8px' }, { text: 'Answer the whisper from your satchel. Which card breaks a lie like that?' }));

      // The player's real cards at this moment: starters + Maribel's mints.
      const cards = [...STARTER_SERUMS, ...FIRST_STUDY_SESSION_MINTS]
        .map((id) => ({ id, ...VERSES[id] })).filter((c) => c.ref);
      const grid = el('div', { display: 'flex', flexWrap: 'wrap', gap: '8px', justifyContent: 'center' });
      const note = el('div', { fontSize: '12px', minHeight: '18px', color: PARCH, marginTop: '8px', fontWeight: '700' });
      cards.forEach((c) => {
        const btn = el('button', {
          background: 'rgba(255,255,255,0.9)', border: `2px solid ${GOLD}`, borderRadius: '10px',
          padding: '8px 10px', fontSize: '12px', fontWeight: '800', color: PARCH, fontFamily: FONT,
          cursor: 'pointer', width: '110px', transition: 'transform 0.08s',
        }, { className: 'gp-choice' });
        btn.appendChild(el('div', { fontSize: '13px' }, { text: c.ref }));
        btn.appendChild(el('div', { fontSize: '10.5px', fontWeight: '600', opacity: '0.8', marginTop: '2px' }, { text: c.gist }));
        btn.addEventListener('click', () => {
          // Condemnation is countered by Grace (Ch. 2.2 type chart).
          if (c.family === 'grace') {
            snd.right();
            if (!settings.reducedFlash) {
              const flare = el('div', {
                position: 'absolute', inset: '0', borderRadius: '16px', pointerEvents: 'none',
                background: 'radial-gradient(circle, rgba(255,230,150,0.9), rgba(255,230,150,0) 70%)',
                animation: 'gpFlare 0.7s ease forwards',
              });
              panel.style.position = 'relative';
              panel.appendChild(flare);
            }
            lieEl.style.opacity = '0.25';
            note.textContent = 'The whisper thins to nothing. Bram blinks — and breathes.';
            setTimeout(() => { shade.remove(); resolve(); }, 900);
          } else {
            snd.wrong();
            note.textContent = 'It glances off. That card is true — but it isn’t the answer to THIS lie. Try another.';
          }
        });
        grid.appendChild(btn);
      });
      panel.append(grid, note);
      shade.appendChild(panel);
      mountEl().appendChild(shade);
    });
  }

  const BEAT3_STEPS = [
    {
      id: 'bram-frozen',
      async run() {
        safe(world().focus, 'east_fields');
        safe(world().setNpcState, 'bram', 'frozen');
        await speak([
          { who: 'narrator', text: 'Out in the grey field, a broad-shouldered farm kid stands stock-still, hoe half-raised, eyes glassy.' },
          { who: 'rosie', text: 'That’s Bram! Oh, the fog’s got him whispering-deep. You’ll need the right words to cut him loose…' },
          { who: 'rosie', text: 'Maribel at the library will know. She always knows. North edge of the square — the ivy-covered one.' },
        ]);
      },
    },
    {
      id: 'library-unlock',
      async run() {
        safe(world().focus, 'library');
        await speak([
          { who: 'maribel', text: 'Shoes wiped? Good. Welcome to the Meadow Town library — mind the dust, it minds me plenty. *achoo*' },
          { who: 'maribel', text: 'You’re the one Eli sent. And that fog has poor Bram, I hear. Then we haven’t a moment for anything but the Book.' },
        ]);
        if (!state.flags.satchelGranted) {
          state.flags.satchelGranted = true;
          safe(world().onSatchelGranted);
          await card({
            icon: '🎒', title: 'The Verse Satchel',
            lines: ['Maribel presses a worn leather satchel into your hands.', 'Six family pockets. Cards go in; courage comes out.'],
            glow: true,
          });
          fanfare('pickup');
        }
        await speak([
          { who: 'maribel', text: 'The town keeps its book at that reading desk — the Gospel of John. We will study it properly, you and I, three sessions.' },
          { who: 'maribel', text: 'Sit with chapter one first. When the whispers try to tell you what you are, John tells you Whose you are.' },
        ]);
      },
    },
    {
      id: 'first-study-pointer',
      async run() {
        // The first Town Book session pointer: open the desk (townbook.js owns
        // the whole reading flow); completion is detected from its progress
        // blob or via notifyStudySessionComplete() from the Wire phase.
        await syncStudySessions();
        while (state.study.sessions < 1 && !disposed) {
          const pick = await choose('maribel', 'Chapter one is open on the desk. Ready?', [
            '📖 Sit at the reading desk', 'Give me a moment',
          ]);
          if (pick === 0 && typeof ctx.openTownBook === 'function') {
            safe(ctx.openTownBook);
            // The desk overlay is modal; when the player returns, re-check.
            await waitForStudySession(1);
          } else if (pick === 0) {
            // No desk wired (bare dev page): mark the session narratively so
            // the script remains judgeable end to end.
            if (IS_DEV) { state.study.sessions = 1; awardXp(tuning.studySessionXp, { source: 'library-study', town: QUEST_NS }); }
            else await speak([{ who: 'maribel', text: 'Hm. The desk lamp is out. Come back when the library is ready.' }]);
          }
          if (state.study.sessions >= 1) break;
          if (pick !== 0) break; // player stepped away; beat resumes here later
        }
        if (state.study.sessions < 1) throw new Error('gp-paused'); // resumable pause
      },
    },
    {
      id: 'study-mints',
      async run() {
        if (!state.flags.firstStudyMinted) {
          state.flags.firstStudyMinted = true;
          for (const id of FIRST_STUDY_SESSION_MINTS) {
            const v = VERSES[id];
            if (v) mintSerum({ id, ref: v.ref, family: v.family, lieFamily: 'condemnation', source: 'prologue', sourceId: 'first-study-session' });
          }
          fanfare('full');
          await card({
            icon: '🕊', title: 'Three Grace Cards',
            lines: ['Maribel copies out three promises of forgiveness in her small, exact hand.', 'Grace answers condemnation. Every time.'],
            glow: true,
          });
        }
        await speak([
          { who: 'maribel', text: 'There. Grace, three ways — because the lie holding Bram is a condemning one, and condemnation cannot survive being forgiven.' },
          { who: 'maribel', text: 'Go. Say one to that fog like you believe it. *achoo* …And you DO believe it.' },
        ]);
      },
    },
    {
      id: 'free-bram',
      async run() {
        safe(world().focus, 'east_fields');
        await freeBramVignette();
        state.flags.bramFreed = true;
        safe(world().setNpcState, 'bram', 'freed');
        await speak([
          { who: 'bram', text: 'WHOA. Okay. Okay! It kept saying I’d ruined everything and — you just — POOF. Like it was never even true. Because it wasn’t!' },
          { who: 'bram', text: 'Bram Oakes. Town champion — trivia, mostly, and turnip-hurling. I owe you one. I owe you FIVE.' },
        ]);
      },
    },
    {
      id: 'clear-fields',
      async run() {
        await speak([
          { who: 'bram', text: 'There’s more of those whisper-things in the fields. Four, I counted, before one got me. Let’s send the fog home.' },
        ]);
        while (state.fieldsCleared < tuning.fieldWhisperlings && !disposed) {
          const res = await fight('whisperling');
          if (res && (res.outcome === 'victory' || res.outcome === 'clear-empty')) {
            state.fieldsCleared++;
            safe(world().setGloomFog01, Math.max(0, 1 - state.fieldsCleared / tuning.fieldWhisperlings));
            await persist(); // each clear survives a mid-beat quit
            emit();
            if (state.fieldsCleared < tuning.fieldWhisperlings) {
              await speak([{ who: 'bram', text: `${tuning.fieldWhisperlings - state.fieldsCleared} to go! The fog’s already thinner — look at it slink!` }]);
            }
          } else {
            await speak([{ who: 'bram', text: 'Shake it off — happens to champions too. Deep breath, right card, big voice.' }]);
          }
        }
        safe(world().setGloomFog01, 0);
        snd.cheer();
        await card({
          icon: '🌤', title: 'The Fog Recedes',
          lines: [
            'The last Whisperling scatters into fireflies, and the grey rolls back off the fields.',
            'The stain on the ground remains — but the town can breathe again.',
          ],
          cta: 'Well done',
        });
        await speak([
          { who: 'maribel', text: 'The seal, next. Finish our three study sessions, and Bram will meet you on the stage — tradition demands a champion’s challenge.' },
          { who: 'rosie', text: 'And the town itself needs hands, dear — Old Tam’s roof, the Finch twins’ supper, that poor bell. Kindness is how a town heals.' },
        ]);
        state.beat = 4; // prologue complete; seal + restoration tracks open
        state.sub = 0;
      },
    },
  ];

  /** Await study-session count reaching n (polls while the desk is open). */
  async function waitForStudySession(n) {
    for (let i = 0; i < 600 && !disposed; i++) { // ~5 min guard
      await wait(500);
      await syncStudySessions();
      if (state.study.sessions >= n) return;
      // If the desk overlay is gone and no progress, stop polling.
      if (i > 4 && !document.querySelector('[data-glowlands-townbook]')) {
        // townbook doesn't tag its root; fall back to a short grace poll.
        if (i > 10) return;
      }
    }
  }

  // ===========================================================================
  // BEAT 4 — The champion trivia battle (Seal 1 + the Lie-Lens).
  // Combat's visual language reused in trivia mode: stage, 20-NPC crowd,
  // 5 lanterns for rounds, warm defeat + instant rematch. Gated by the three
  // study sessions AND the First Shadow (Ch. 2.6: the boss gates the trivia
  // battle; it never grants the seal itself).
  // ===========================================================================
  function runTriviaBattle() {
    return new Promise((resolve) => {
      injectStyles();
      const T = tuning;
      state.trivia.attempts++;
      const pool = buildTriviaPool(`meadow-attempt-${state.trivia.attempts}-${Math.floor(rand() * 1e9)}`);
      const recital = RECITAL_ITEMS[Math.floor(rand() * RECITAL_ITEMS.length)];
      let round = 0, playerWins = 0, bramWins = 0, poolIdx = 0;

      const shade = el('div', {
        position: 'fixed', inset: '0', zIndex: 58, background: 'linear-gradient(180deg, rgba(20,26,52,0.92), rgba(30,26,20,0.94))',
        display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'flex-start',
        fontFamily: FONT, animation: 'gpFadeIn 0.3s ease', overflowY: 'auto',
        padding: 'calc(10px + env(safe-area-inset-top, 0px)) 10px calc(14px + env(safe-area-inset-bottom, 0px))',
      });
      mountEl().appendChild(shade);

      // --- the stage header: round lanterns + rivals ---
      const header = el('div', { width: 'min(560px, 96vw)', textAlign: 'center' });
      const lanternRow = el('div', { display: 'flex', justifyContent: 'center', gap: '10px', margin: '4px 0 6px' });
      const lanternEls = [];
      for (let i = 0; i < T.triviaRounds; i++) {
        const l = el('div', { fontSize: '24px', opacity: '0.35', transition: 'opacity 0.3s, filter 0.3s' }, { text: '🏮' });
        lanternRow.appendChild(l); lanternEls.push(l);
      }
      const rivals = el('div', { display: 'flex', justifyContent: 'space-between', width: '100%', color: '#ffe9c0', fontSize: '13px', fontWeight: '800', padding: '0 8px' });
      const youEl = el('div', {}, { text: 'You ✦ 0' });
      const bramEl = el('div', {}, { text: '0 ✦ Bram 🌾' });
      rivals.append(youEl, bramEl);
      // --- the 20-NPC crowd (emoji row, pure DOM — zero draw calls) ---
      const crowd = el('div', { fontSize: '13px', letterSpacing: '1px', margin: '2px 0 8px', opacity: '0.9' });
      const faces = ['🧑‍🌾', '👵', '🧒', '👨‍🦳', '👧', '🧑', '👩‍🌾', '👴', '🧓', '👦'];
      crowd.textContent = Array.from({ length: T.triviaCrowd }, (_, i) => faces[i % faces.length]).join('');
      header.append(lanternRow, rivals, crowd);
      shade.appendChild(header);

      const panel = el('div', {
        background: WOOD_TEX, borderRadius: '16px', boxShadow: PANEL_SHADOW, border: `2.5px solid ${GOLD}`,
        padding: '16px 18px', width: 'min(560px, 96vw)', textAlign: 'center',
      });
      shade.appendChild(panel);

      function crowdReact(good) {
        if (good) { snd.cheer(); crowd.style.animation = settings.reducedFlash ? 'none' : 'gpBob 0.5s 2'; }
        else { snd.murmur(); crowd.style.opacity = '0.6'; setTimeout(() => { crowd.style.opacity = '0.9'; }, 600); }
      }
      function setScore() {
        youEl.textContent = `You ✦ ${playerWins}`;
        bramEl.textContent = `${bramWins} ✦ Bram 🌾`;
      }
      function lightLantern(i, mine) {
        lanternEls[i].style.opacity = '1';
        if (mine) { lanternEls[i].style.filter = 'drop-shadow(0 0 8px rgba(255,210,120,0.9))'; snd.lanternChime(i); }
        else lanternEls[i].style.filter = 'grayscale(0.6)';
      }

      function finish(won) {
        panel.innerHTML = '';
        panel.appendChild(el('div', { fontSize: '44px' }, { text: won ? '🏅' : '🤝' }));
        panel.appendChild(el('div', { fontSize: '16px', fontWeight: '900', color: PARCH, margin: '6px 0' },
          { text: won ? 'The square erupts!' : 'A warm defeat' }));
        panel.appendChild(el('div', { fontSize: '13.5px', color: PARCH, opacity: '0.9', marginBottom: '10px' }, {
          text: won
            ? 'Bram grabs your hand and raises it himself. “THAT’S how it’s done, Meadow Town!”'
            : 'Bram grins, not unkindly. “Best two of three more? Reshuffle the questions — you nearly had me.”',
        }));
        const b = el('button', {
          background: GOLD_BTN_BG, border: '2px solid #b06a10', borderRadius: '11px', padding: '10px 26px',
          fontSize: '14px', fontWeight: '900', color: '#5a3305', fontFamily: FONT, cursor: 'pointer',
        }, { text: won ? 'Claim the seal' : 'Rematch!', className: 'gp-btn' });
        b.addEventListener('click', () => { snd.blip(); shade.remove(); resolve(won); });
        panel.appendChild(b);
      }

      function nextRound() {
        if (playerWins >= T.triviaWinsNeeded) return finish(true);
        if (bramWins >= T.triviaWinsNeeded) return finish(false);
        if (round >= T.triviaRounds) return finish(playerWins > bramWins);
        round++;
        if (round === T.triviaRecitalRound) recitalRound();
        else questionRound();
      }

      function roundHead(label) {
        panel.innerHTML = '';
        panel.appendChild(el('div', { fontSize: '11px', fontWeight: '900', color: GOLD, letterSpacing: '1px', marginBottom: '6px' },
          { text: `ROUND ${round} OF ${T.triviaRounds} — ${label}` }));
      }
      function resultLine(ok, extra) {
        const n = el('div', { fontSize: '12.5px', fontWeight: '800', marginTop: '10px', color: ok ? '#2f6b1a' : '#8a4a2a' }, {
          text: ok ? `The lantern above the stage flares! ${extra || ''}` : `Bram fields it without blinking and takes the round. ${extra || ''}`,
        });
        panel.appendChild(n);
        const b = el('button', {
          marginTop: '10px', background: GOLD_BTN_BG, border: '2px solid #b06a10', borderRadius: '11px',
          padding: '9px 22px', fontSize: '13px', fontWeight: '900', color: '#5a3305', fontFamily: FONT, cursor: 'pointer',
        }, { text: 'Next', className: 'gp-btn' });
        b.addEventListener('click', () => { snd.click(); nextRound(); });
        panel.appendChild(b);
      }

      function questionRound() {
        const q = pool[poolIdx % pool.length]; poolIdx++;
        roundHead('MARIBEL READS');
        panel.appendChild(el('div', { fontSize: '12px', color: '#8f7ac9', fontWeight: '800', marginBottom: '4px' }, { text: '📚 Maribel Quill, adjudicating' }));
        panel.appendChild(el('div', { fontSize: '14.5px', lineHeight: '1.45', color: PARCH, marginBottom: '10px', fontWeight: '700' }, { text: q.prompt }));
        let answered = false;
        q.choices.forEach((c, i) => {
          const b = el('button', {
            display: 'block', width: '100%', textAlign: 'left', margin: '6px 0',
            background: 'rgba(255,255,255,0.9)', border: `2px solid ${GOLD}`, borderRadius: '10px',
            padding: '9px 12px', fontSize: '13px', fontWeight: '700', color: PARCH, fontFamily: FONT, cursor: 'pointer',
          }, { text: c, className: 'gp-choice' });
          b.addEventListener('click', () => {
            if (answered) return;
            answered = true;
            const ok = i === q.correctIndex;
            b.style.borderColor = ok ? '#4f9e2f' : '#c0553a';
            if (ok) { snd.right(); playerWins++; lightLantern(round - 1, true); }
            else { snd.wrong(); bramWins++; lightLantern(round - 1, false); }
            crowdReact(ok);
            setScore();
            resultLine(ok, q.sourceRef ? `(${q.sourceRef})` : '');
          });
          panel.appendChild(b);
        });
      }

      // Round 4 — Bram's Recital: tap the mangled word, then correct it.
      function recitalRound() {
        roundHead('BRAM’S RECITAL');
        panel.appendChild(el('div', { fontSize: '12px', color: '#d8a04a', fontWeight: '800', marginBottom: '4px' }, { text: '🌾 Bram recites… approximately' }));
        const p = el('div', { fontSize: '14.5px', lineHeight: '1.5', color: PARCH, marginBottom: '10px' });
        p.appendChild(document.createTextNode(recital.before));
        const mang = el('span', {
          textDecoration: 'underline wavy #c0553a', fontWeight: '900', cursor: 'pointer', padding: '0 2px',
        }, { text: recital.mangled });
        p.appendChild(mang);
        p.appendChild(document.createTextNode(recital.after));
        panel.appendChild(p);
        const hint = el('div', { fontSize: '12px', color: GOLD, fontWeight: '800' }, { text: 'Something in there sounds… off. Tap the word that isn’t right.' });
        panel.appendChild(hint);
        let tapped = false;
        mang.addEventListener('click', () => {
          if (tapped) return;
          tapped = true;
          snd.blip();
          hint.textContent = 'That’s the one! What was the name supposed to be?';
          const choices = shuffled([recital.correct, ...recital.decoys], rand).slice(0, 4);
          if (!choices.includes(recital.correct)) choices[0] = recital.correct;
          let answered = false;
          choices.forEach((c) => {
            const b = el('button', {
              display: 'inline-block', margin: '6px 4px 0', background: 'rgba(255,255,255,0.9)',
              border: `2px solid ${GOLD}`, borderRadius: '10px', padding: '8px 14px',
              fontSize: '13px', fontWeight: '800', color: PARCH, fontFamily: FONT, cursor: 'pointer',
            }, { text: c, className: 'gp-choice' });
            b.addEventListener('click', () => {
              if (answered) return;
              answered = true;
              const ok = c === recital.correct;
              if (ok) { snd.right(); playerWins++; lightLantern(round - 1, true); }
              else { snd.wrong(); bramWins++; lightLantern(round - 1, false); }
              crowdReact(ok);
              setScore();
              resultLine(ok, ok ? `Bram: “${recital.correct}! Knew it. Was testing you.” (${recital.sourceRef})` : `(${recital.sourceRef})`);
            });
            panel.appendChild(b);
          });
        });
      }

      nextRound();
    });
  }

  /** The whole beat-4 arc: gates -> boss -> battle -> Seal I + Lie-Lens. */
  async function runSealArc() {
    await syncStudySessions();

    // Gate 1: three study sessions define the pool — no trivia-out-of-nowhere.
    if (state.study.sessions < 3) {
      const left = 3 - state.study.sessions;
      const pick = await choose('maribel',
        `The challenge stage is tradition, but preparation comes first. ${left === 1 ? 'One study session' : `${left} study sessions`} to go — the questions come straight from our reading.`,
        ['📖 To the reading desk', 'I’ll come back']);
      if (pick === 0) {
        safe(ctx.openTownBook);
        await waitForStudySession(3);
      }
      if (state.study.sessions < 3) return false;
      await speak([{ who: 'maribel', text: 'Three sessions. *achoo* — that’s the dust of a job well done. Bram is already warming up the crowd.' }]);
    }

    // Gate 2: the First Shadow gates the trivia battle (never grants the seal).
    if (!state.flags.firstShadowCleared) {
      await speak([
        { who: 'narrator', text: 'As the crowd gathers at the stage, the shadows between the houses pull together — and stand up.' },
        { who: 'bram', text: 'Uh. That’s new. That’s very new. Champion’s privilege: you first!' },
      ]);
      const res = await fight(FIRST_SHADOW.id);
      if (!res || (res.outcome !== 'victory' && res.outcome !== 'clear-empty')) {
        await speak([{ who: 'eli', text: 'You woke by a lit lantern — that’s the Gloom’s only real trick, and it’s spent. When you’re steady, face it again. Light wins. Always.' }]);
        await persist();
        return false;
      }
      state.flags.firstShadowCleared = true;
      await persist();
      emit();
      await speak([
        { who: 'bram', text: 'It just… came apart. Into FIREFLIES. Okay, new plan: you and me, stage, right now, before anything else stands up.' },
      ]);
    }

    // The battle proper (instant rematches live inside the loop — no lockout).
    let won = false;
    while (!won && !disposed) {
      await speak([
        { who: 'maribel', text: 'Five rounds, drawn from our three sessions. A lantern lights for every round won. Three lanterns takes the day.' },
        { who: 'bram', text: 'No hard feelings either way — but I HAVE been champion three years running. Well. Two and a harvest.' },
      ]);
      won = await runTriviaBattle();
      await persist();
      if (!won) {
        const again = await choose('bram', 'Straight back in, or catch your breath first?', ['🎪 Rematch now', 'Catch my breath']);
        if (again !== 0) return false;
      }
    }
    if (disposed) return false;

    // Seal I + the Lie-Lens, both on the Lightfound fanfare (earn events).
    state.flags.seal1 = true;
    state.trivia.won = true;
    awardXp(tuning.triviaWinXp, { source: 'trivia-seal-1', town: QUEST_NS });
    awardGold(tuning.triviaWinGold, { source: 'trivia-seal-1', town: QUEST_NS });
    safe(ctx.onSealEarned, 1);
    fanfare('full');
    await card({
      icon: '🔆', title: 'Lantern Seal I',
      lines: [
        'Maribel presses a brass seal, warm as a hearthstone, into your palm.',
        'The first of six. Your Wayfarer’s Table at home has a socket shaped exactly like it.',
      ],
      glow: true,
    });
    if (!state.flags.lieLens) {
      state.flags.lieLens = true;
      safe(ctx.grantItem, { id: 'lie_lens', name: 'The Lie-Lens' });
      fanfare('pickup');
      await card({
        icon: '🔍', title: 'The Lie-Lens',
        lines: [
          'A small reading glass on a cord — through it, a whisper’s FAMILY shows before it speaks.',
          'The first piece of the Wayfarer’s Kit.',
        ],
        glow: true,
      });
    }
    await speak([
      { who: 'bram', text: 'Seal and lens, same day! You know what that means. It means I need to study. MARIBEL! One library please!' },
      { who: 'maribel', text: 'The seal is yours; the town is not yet whole. The fields, the roof, the bell — hearts mend a town, not trophies. Both, together.' },
    ]);
    await persist();
    emit();
    await maybeSave();
    return true;
  }

  // ===========================================================================
  // BEAT 5 — Restoration: the meter, three service quests, donations, plots.
  // Shops as service organs (Ch. 7.6) — the APIs below are the interface the
  // Wire phase calls from Berry Market / Toolworks / Rosie's interactions.
  // ===========================================================================
  let restoChip = null;

  function addRestoration(pts, source) {
    if (state.flags.saved || pts <= 0) return state.restoration.points;
    state.restoration.points = Math.min(tuning.restorationTarget, state.restoration.points + pts);
    if (IS_DEV) console.log(`[prologue] +${pts} restoration (${source}) -> ${state.restoration.points}`);
    emit();
    return state.restoration.points;
  }
  function addStanding(pts, source) {
    state.standing.points += pts;
    state.standing.tier =
      state.standing.points >= tuning.standingGuardianAt ? 'guardian'
        : state.standing.points >= tuning.standingFriendAt ? 'friend'
          : state.standing.tier;
    if (IS_DEV) console.log(`[prologue] +${pts} standing (${source}) -> ${state.standing.points}`);
  }

  function mountRestorationChip() {
    if (restoChip || typeof document === 'undefined') return;
    injectStyles();
    restoChip = el('div', {
      position: 'fixed', top: 'calc(64px + env(safe-area-inset-top, 0px))', right: '10px', zIndex: 40,
      background: WOOD_TEX, border: `2px solid ${GOLD}`, borderRadius: '12px', boxShadow: PANEL_SHADOW,
      padding: '6px 10px', fontFamily: FONT, fontSize: '11.5px', fontWeight: '800', color: PARCH,
      display: 'flex', alignItems: 'center', gap: '6px', pointerEvents: 'none',
    });
    mountEl().appendChild(restoChip);
    updateRestorationChip();
  }
  function updateRestorationChip() {
    if (!restoChip) return;
    if (state.flags.saved) { restoChip.remove(); restoChip = null; return; }
    const p = state.restoration.points;
    restoChip.innerHTML = '';
    restoChip.appendChild(el('span', { fontSize: '14px' }, { text: '🏘' }));
    const barWrap = el('div', { width: '70px', height: '8px', borderRadius: '4px', background: 'rgba(23,73,126,0.15)', overflow: 'hidden' });
    barWrap.appendChild(el('div', { width: `${Math.round((p / tuning.restorationTarget) * 100)}%`, height: '100%', background: GOLD_BTN_BG }));
    restoChip.appendChild(barWrap);
    restoChip.appendChild(el('span', {}, { text: `${p}/${tuning.restorationTarget}` }));
  }

  // --- quest vignette: Raise the Roof (repair; leaves Old Tam warm and dry) ---
  function hammerMinigame() {
    return new Promise((resolve) => {
      injectStyles();
      const shade = el('div', {
        position: 'fixed', inset: '0', zIndex: 56, background: 'rgba(12,14,28,0.45)',
        display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: FONT, padding: '14px',
        animation: 'gpFadeIn 0.2s ease',
      });
      const panel = el('div', {
        background: WOOD_TEX, borderRadius: '16px', boxShadow: PANEL_SHADOW, border: `2px solid ${GOLD}`,
        padding: '16px 18px', width: 'min(340px, 92vw)', textAlign: 'center',
      });
      panel.appendChild(el('div', { fontSize: '34px' }, { text: '🔨🏚' }));
      const label = el('div', { fontSize: '13.5px', fontWeight: '800', color: PARCH, margin: '6px 0 10px' }, { text: 'Nail the shingles — tap when the marker crosses the gold. 3 clean strikes.' });
      panel.appendChild(label);
      const track = el('div', { position: 'relative', height: '18px', borderRadius: '9px', background: 'rgba(23,73,126,0.15)', margin: '0 6px 12px', overflow: 'hidden' });
      track.appendChild(el('div', { position: 'absolute', left: '38%', width: '24%', top: '0', bottom: '0', background: 'rgba(255,184,69,0.55)', borderRadius: '9px' }));
      const marker = el('div', { position: 'absolute', top: '2px', bottom: '2px', width: '14px', borderRadius: '7px', background: GOLD, animation: 'gpHammer 1.15s linear infinite' });
      track.appendChild(marker);
      panel.appendChild(track);
      const btn = el('button', {
        background: GOLD_BTN_BG, border: '2px solid #b06a10', borderRadius: '11px', padding: '10px 26px',
        fontSize: '14px', fontWeight: '900', color: '#5a3305', fontFamily: FONT, cursor: 'pointer',
      }, { text: 'SWING', className: 'gp-btn' });
      panel.appendChild(btn);
      shade.appendChild(panel);
      mountEl().appendChild(shade);
      let hits = 0;
      btn.addEventListener('click', () => {
        const trackRect = track.getBoundingClientRect();
        const markRect = marker.getBoundingClientRect();
        const t = (markRect.left + markRect.width / 2 - trackRect.left) / trackRect.width;
        if (t >= 0.38 && t <= 0.62) {
          hits++;
          snd.hammerHit();
          label.textContent = hits >= 3 ? 'Solid as a chapel pew!' : `Clean strike! ${3 - hits} to go.`;
          if (hits >= 3) setTimeout(() => { shade.remove(); resolve(); }, 500);
        } else {
          snd.thud();
          label.textContent = 'Glanced off — wait for the gold. Old Tam pretends not to wince.';
        }
      });
    });
  }

  async function questRaiseRoof() {
    const q = SERVICE_QUESTS.raise_roof;
    if (state.restoration.quests[q.id]) {
      await speak([{ who: 'tam', text: 'Roof’s held through two rains now. Sat under it just to listen. …Thank you.' }]);
      return;
    }
    await speak([
      { who: 'tam', text: 'Don’t mind the tarp. Roof gave in when the Gloom-rot took the beam. I’ll sort it. Always have.' },
      { who: 'narrator', text: 'He will not ask. The sag in the tarp asks for him.' },
    ]);
    const pick = await choose('narrator', 'Fetch cedar shingles from Grint’s Toolworks?', ['🔨 To the Toolworks', 'Not yet']);
    if (pick !== 0) return;
    await speak([
      { who: 'grint', text: 'Tam’s roof? About time somebody went at it. Cedar shingles — take the good bundle. And take a REAL hammer.' },
    ]);
    await hammerMinigame();
    state.restoration.quests[q.id] = true;
    addRestoration(tuning.restQuestPts[q.id], q.id);
    awardXp(tuning.questXp[q.id], { source: q.id, town: QUEST_NS });
    awardGold(tuning.questGold[q.id], { source: q.id, town: QUEST_NS });
    fanfare('full');
    await card({
      icon: '🏠', title: 'Raise the Roof — complete',
      lines: ['Old Tam stands in his doorway, dry for the first time in a month, wrapped in the spare blanket you found in the eaves.', `+${tuning.restQuestPts[q.id]} restoration`],
      glow: true,
    });
    await speak([{ who: 'tam', text: '…Huh. Warm. Forgot the sound rain makes when it’s not landing on you. You’ll take supper sometime. That’s not a question.' }]);
    await persist();
    await maybeSave();
  }

  // --- quest vignette: Loaves for the Finches (feed) ---
  async function questLoaves() {
    const q = SERVICE_QUESTS.loaves;
    if (state.restoration.quests[q.id]) {
      await speak([{ who: 'finches', text: '“THERE they are!” “The fruit hero!” “We told EVERYONE.” “The baker gave us crusts for the story!”' }]);
      return;
    }
    await speak([
      { who: 'finches', text: '“We’re not hungry.” “We’re ALWAYS hungry.” “Shh! We’re being polite!”' },
      { who: 'rosie', text: 'Their mother works the far orchards since the fields went grey. Five good fruit through the Berry Market would fill that table for a week.' },
    ]);
    const have = await getFruit();
    if (have !== null && have < q.fruitNeeded) {
      await speak([{ who: 'rosie', text: `You’ve ${have === 0 ? 'none' : `only ${have}`} in your basket, dear. Your garden at home grows what kindness needs — come back with ${q.fruitNeeded}.` }]);
      return;
    }
    const pick = await choose('rosie', `Donate ${q.fruitNeeded} home-grown fruit for the twins?`, [`🍎 Donate ${q.fruitNeeded} fruit`, 'Not yet']);
    if (pick !== 0) return;
    const ok = await spendFruit(q.fruitNeeded);
    if (!ok) {
      await speak([{ who: 'rosie', text: 'Oh — your basket’s lighter than it looked. No matter; the garden will fill it again.' }]);
      return;
    }
    state.restoration.quests[q.id] = true;
    addRestoration(tuning.restQuestPts[q.id], q.id);
    awardXp(tuning.questXp[q.id], { source: q.id, town: QUEST_NS });
    fanfare('full');
    await card({
      icon: '🍞', title: 'Loaves for the Finches — complete',
      lines: ['The twins narrate your generosity to the entire square, loudly, with additions.', `+${tuning.restQuestPts[q.id]} restoration`],
      glow: true,
    });
    await persist();
    await maybeSave();
  }

  // --- quest vignette: The Right Hammer (the running joke, made mechanical) ---
  async function questRightHammer() {
    const q = SERVICE_QUESTS.right_hammer;
    if (state.restoration.quests[q.id]) {
      await speak([{ who: 'grint', text: 'Bell rings true every hour now. Oil. OIL. Don’t tell a soul, or I’ll never sell another hammer.' }]);
      return;
    }
    await speak([
      { who: 'grint', text: 'Chapel bell’s gone sour. Clunks like a bucket. Every problem has a right hammer — I just haven’t found this one’s yet.' },
    ]);
    snd.bellSour();
    const tries = [
      { label: '🔨 The framing hammer', grint: 'CLONK. Worse. Interesting, but worse.' },
      { label: '⚒ The two-hander', grint: 'The pigeons have left the county. Bell’s still sour.' },
      { label: '🛠 The tiny jeweler’s hammer', grint: 'That was a tink. A SOUR tink. Hm.' },
    ];
    let solved = false;
    const used = new Set();
    while (!solved && !disposed) {
      const options = tries.map((t, i) => (used.has(i) ? `${t.label} (again?)` : t.label));
      options.push('🫙 …Maybe just oil the hinge?');
      const pick = await choose('grint', 'Which tool, then?', options);
      if (pick === tries.length) {
        solved = true;
      } else {
        used.add(pick);
        snd.bellSour();
        await speak([{ who: 'grint', text: tries[pick].grint }]);
        if (used.size >= tries.length) {
          await speak([{ who: 'grint', text: '…I’m beginning to suspect this problem was built without a hammer in mind. Which is heresy. Say nothing.' }]);
        }
      }
    }
    if (disposed) return;
    snd.bellTrue();
    state.restoration.quests[q.id] = true;
    addRestoration(tuning.restQuestPts[q.id], q.id);
    awardXp(tuning.questXp[q.id], { source: q.id, town: QUEST_NS });
    awardGold(tuning.questGold[q.id], { source: q.id, town: QUEST_NS });
    fanfare('full');
    await card({
      icon: '🔔', title: 'The Right Hammer — complete',
      lines: ['One drop of oil. The bell rolls out a note so clean the whole square looks up.', `+${tuning.restQuestPts[q.id]} restoration`],
      glow: true,
    });
    await speak([{ who: 'grint', text: 'The right hammer… was no hammer. I need to sit down. Take your points and let a man grieve his worldview.' }]);
    await persist();
    await maybeSave();
  }

  // --- shops-as-service-organs APIs (Wire phase calls these) ---
  async function donateFruit(n = 1) {
    if (state.flags.saved) return { accepted: 0, pointsGained: 0, cappedToday: false };
    const today = dayKey(new Date(now()));
    const d = state.restoration.donations;
    if (d.day !== today) { d.day = today; d.ptsToday = 0; }
    const room = Math.max(0, tuning.donationDailyCapPts - d.ptsToday);
    if (room === 0) return { accepted: 0, pointsGained: 0, cappedToday: true };
    const maxFruit = Math.floor(room / tuning.donationPtsPerFruit);
    const accept = Math.max(0, Math.min(n, maxFruit));
    if (accept === 0) return { accepted: 0, pointsGained: 0, cappedToday: true };
    const ok = await spendFruit(accept);
    if (!ok) return { accepted: 0, pointsGained: 0, cappedToday: false };
    const pts = accept * tuning.donationPtsPerFruit;
    const firstToday = d.ptsToday === 0;
    d.ptsToday += pts;
    if (firstToday) { d.daysCount++; addStanding(tuning.standingPerDonationDay, 'donation-day'); }
    addRestoration(pts, 'berry-market-donation');
    fanfare('pickup');
    await persist();
    await maybeSave();
    return { accepted: accept, pointsGained: pts, cappedToday: d.ptsToday >= tuning.donationDailyCapPts };
  }

  async function replantPlot(index) {
    if (index < 0 || index >= tuning.plotCount) return false;
    if (state.restoration.plots[index]) return false;
    state.restoration.plots[index] = true;
    addRestoration(tuning.ptsPerPlot, `replant-plot-${index}`);
    addStanding(tuning.standingPerPlot, 'plot-replanted');
    if (state.restoration.plots.every(Boolean)) addStanding(tuning.standingFullReplantBonus, 'full-replant');
    fanfare('pickup');
    await persist();
    emit();
    await maybeSave();
    return true;
  }

  /** Berry Market donation counter — small overlay for the shop interaction. */
  async function openDonationCounter() {
    const today = dayKey(new Date(now()));
    const d = state.restoration.donations;
    const usedToday = d.day === today ? d.ptsToday : 0;
    if (state.flags.saved) {
      await speak([{ who: 'rosie', text: 'The town’s whole again, dear — the market’s back to buying and selling. Your kindness did that.' }]);
      return;
    }
    if (usedToday >= tuning.donationDailyCapPts) {
      await speak([{ who: 'rosie', text: 'The donation basket’s full for today — generosity keeps, you know. Bring more tomorrow.' }]);
      return;
    }
    const pick = await choose('rosie',
      `Fruit for the town pantry? Every piece is ${tuning.donationPtsPerFruit} restoration — up to ${tuning.donationDailyCapPts} points a day. (${usedToday}/${tuning.donationDailyCapPts} today)`,
      ['🍎 Donate 1 fruit', '🧺 Donate 5 fruit', 'Just looking']);
    if (pick === 2) return;
    const res = await donateFruit(pick === 0 ? 1 : 5);
    if (res.accepted > 0) {
      await speak([{ who: 'rosie', text: `${res.accepted === 1 ? 'One beauty' : `${res.accepted} beauties`} for the pantry — that’s +${res.pointsGained} toward the town. ${res.cappedToday ? 'And that fills the basket for today!' : ''}` }]);
    } else if (res.cappedToday) {
      await speak([{ who: 'rosie', text: 'Basket’s brimming for today, dear. Tomorrow it’ll be empty and hopeful again.' }]);
    } else {
      await speak([{ who: 'rosie', text: 'Your own basket’s empty! The garden at home will see to that.' }]);
    }
  }

  // ===========================================================================
  // BEAT 6 — The save transformation + the Eli farewell (first exit only).
  // ===========================================================================
  async function maybeSave() {
    if (state.flags.saved) return;
    if (!(state.flags.seal1 && state.restoration.points >= tuning.restorationTarget)) return;
    state.flags.saved = true;
    state.standing.tier = state.standing.tier || 'neighbor';
    await persist();

    // The transformation: 3D staging is the Wire phase's; we drive timing,
    // audio (the lantern-string chime cascade) and the card.
    safe(world().playSaveTransformation, {
      lanterns: tuning.saveWaveLanterns,
      waveSec: tuning.saveWaveSec,
      stainBurnSec: tuning.stainBurnSec,
    });
    safe(world().setGloomStain01, 0);
    // Rising pentatonic glissando as the wave lights each strand (Ch. 7.8).
    const chimes = Math.min(12, tuning.saveWaveLanterns);
    for (let i = 0; i < chimes; i++) {
      setTimeout(() => snd.lanternChime(i), (i * tuning.saveWaveSec * 1000) / chimes);
    }
    await wait(Math.min(2500, tuning.saveWaveSec * 500));
    fanfare('full');
    await card({
      icon: '🏮', title: 'Meadow Town Is Saved',
      lines: [
        'Forty string lanterns ignite in a wave from the chapel to the gate.',
        'The Gloom stain burns off the field run. The music finds its second voice.',
        'The five plots you healed open as the town’s public garden beds — and the East Gate stands open.',
      ],
      cta: 'Breathe it in', glow: true,
    });
    safe(world().openPublicPlots);
    safe(world().setEastGateOpen, true);
    safe(world().applySavedState);
    await speak([
      { who: 'finches', text: '“LOOK AT THE LANTERNS!” “We KNEW them when they were nobody!” “We’re telling the whole road!”' },
      { who: 'rosie', text: 'A saved town stays saved, dear. Whatever the road does to your lantern, THIS light stays lit. Come home to it whenever you like.' },
    ]);
    emit();
  }

  /**
   * The farewell at the East Gate (Ch. 7 — scripted, FIRST exit only).
   * The Wire phase calls this when the player walks through the open gate.
   * Returns { proceed } — always true once the gate is open; the farewell
   * itself never blocks, it only happens once.
   */
  async function onEastGateExit() {
    if (!state.flags.saved) {
      // Sealed line: the gate opens by no other means (Ch. 7.9).
      await speak([
        { who: 'narrator', text: 'The East Gate is sealed fast. No lock, no keyhole — the town itself must shine before the road will have you.' },
      ]);
      return { proceed: false };
    }
    if (state.flags.farewellDone) return { proceed: true };
    state.flags.farewellDone = true;
    // Eli comes jogging up the Garden Path, out of breath, and catches you
    // at the arch. One handshake, no menu. (Ember stays home — Phase 1 rule;
    // he appears here only as Eli's joke, exactly per the bible's script.)
    safe(world().setNpcState, 'eli', 'east_gate_jog');
    await speak([
      { who: 'eli', text: '*huff* — wait, wait — made it. Ha! Old legs, new hills.' },
      { who: 'eli', text: 'You’re really going, then. Good. GOOD. The road past this arch needed you before it ever met you.' },
      { who: 'eli', text: 'I’ll mind the backyard while you’re gone. The plots. The post. The dragon-shaped lawn ornament — don’t tell him I said that.' },
      { who: 'eli', text: 'Come back anytime, for any reason, or no reason. Nothing at home will ever need saving. That’s the point of home.' },
      { who: 'narrator', text: 'One handshake. The door behind you stays open — and someone you trust is holding it.' },
    ]);
    await persist();
    emit();
    return { proceed: true };
  }

  // ===========================================================================
  // The beat runner — linear beats 1-3 resume at their persisted sub-step.
  // ===========================================================================
  const LINEAR_BEATS = { 1: BEAT1_STEPS, 2: BEAT2_STEPS, 3: BEAT3_STEPS };
  let linearRunning = false;

  async function runLinear() {
    if (linearRunning) return; // a step's dialog is already live — never re-enter
    linearRunning = true;
    try { await runLinearInner(); } finally { linearRunning = false; }
  }

  async function runLinearInner() {
    while (!disposed && state.beat <= 3) {
      const steps = LINEAR_BEATS[state.beat];
      if (state.sub >= steps.length) { state.beat++; state.sub = 0; await persist(); continue; }
      const step = steps[state.sub];
      try {
        await step.run();
      } catch (e) {
        if (e && e.message === 'gp-paused') { await persist(); emit(); return; } // resumable pause
        if (IS_DEV) console.error(`[prologue] step ${state.beat}.${step.id} failed`, e);
        await persist();
        return; // fail safe: never wedge the host — resume() retries the step
      }
      if (disposed) return;
      // Steps that advance beat themselves (clear-fields) skip the bump.
      if (LINEAR_BEATS[state.beat] === steps) state.sub++;
      await persist();
      emit();
    }
    if (!disposed && state.beat >= 4) {
      mountRestorationChip();
      pushWorldState();
    }
  }

  // ===========================================================================
  // Public interaction surface — the Wire phase routes 3D taps here.
  // ===========================================================================
  const interactions = {
    fountain: async () => {
      if (state.beat === 2) return runLinear();
      if (state.flags.lanternGranted) {
        await speak([{ who: 'narrator', text: 'The fountain murmurs to itself. You could swear the water runs a shade brighter where the stranger knelt.' }]);
      }
    },
    library_desk: async () => {
      await syncStudySessions();
      if (state.beat === 3) return runLinear();
      safe(ctx.openTownBook);
      await syncStudySessions();
    },
    stage: async () => {
      if (state.beat < 4) {
        await speak([{ who: 'bram', text: 'Stage is for the champion’s challenge! Which you are SO not ready for. Yet. No offense. Some offense.' }]);
        return;
      }
      if (state.flags.seal1) {
        await speak([{ who: 'bram', text: 'Rematch anytime, champ — friendly rules. But first I’ve got three chapters to memorize and a reputation to rebuild.' }]);
        return;
      }
      await runSealArc();
    },
    old_tam: () => (state.beat >= 4 ? questRaiseRoof() : speakGloomedTown()),
    finches: () => (state.beat >= 4 ? questLoaves() : speakGloomedTown()),
    grint: () => (state.beat >= 4 ? questRightHammer() : speakGloomedTown()),
    berry_market: () => (state.beat >= 4 ? openDonationCounter() : speakGloomedTown()),
    rosies: async () => {
      if (state.beat < 4) return speakGloomedTown();
      const replanted = state.restoration.plots.filter(Boolean).length;
      await speak([{
        who: 'rosie',
        text: replanted >= tuning.plotCount
          ? 'Every scarred plot green again! You garden like you mean it, dear.'
          : `The Meadow Replanting Pack is on the shelf — ${tuning.plotCount - replanted} scarred plot${tuning.plotCount - replanted === 1 ? '' : 's'} in the east fields still waiting for seeds and stubbornness. ${tuning.ptsPerPlot} restoration apiece.`,
      }]);
    },
    east_gate: () => onEastGateExit(),
  };
  async function speakGloomedTown() {
    await speak([{ who: 'narrator', text: 'The town is holding its breath. The fields come first.' }]);
  }

  function getPublicState() {
    return {
      beat: state.beat,
      sub: state.sub,
      prologueDone: state.beat >= 4,
      lanternGranted: state.flags.lanternGranted,
      studySessions: state.study.sessions,
      firstShadowCleared: state.flags.firstShadowCleared,
      seal1: state.flags.seal1,
      lieLens: state.flags.lieLens,
      restoration: {
        points: state.restoration.points,
        target: tuning.restorationTarget,
        quests: { ...state.restoration.quests },
        plots: state.restoration.plots.slice(),
        donationsToday: state.restoration.donations.day === dayKey(new Date(now())) ? state.restoration.donations.ptsToday : 0,
      },
      saved: state.flags.saved,
      farewellDone: state.flags.farewellDone,
      standing: { ...state.standing },
      gloomStain01: computeGloomStain01(state, now(), tuning),
    };
  }

  /** Quest markers for the Wire phase's 3D indicators. */
  function getQuestMarkers() {
    const m = {};
    if (state.beat === 1) m.west_gate = 'main';
    if (state.beat === 2) m.fountain = 'main';
    if (state.beat === 3) m.library_desk = 'main';
    if (state.beat >= 4 && !state.flags.seal1) {
      m.stage = state.study.sessions >= 3 ? 'main' : 'locked';
      if (state.study.sessions < 3) m.library_desk = 'main';
    }
    if (state.beat >= 4 && !state.flags.saved) {
      if (!state.restoration.quests.raise_roof) m.old_tam = 'side';
      if (!state.restoration.quests.loaves) m.finches = 'side';
      if (!state.restoration.quests.right_hammer) m.grint = 'side';
      m.berry_market = 'service';
      if (!state.restoration.plots.every(Boolean)) m.rosies = 'service';
    }
    if (state.flags.saved && !state.flags.farewellDone) m.east_gate = 'main';
    return m;
  }

  // ---- controller -----------------------------------------------------------
  const controller = {
    /** Load state and resume wherever the player left off. Idempotent. */
    async start() {
      if (started) return getPublicState();
      started = true;
      injectStyles();
      await load();
      await syncStudySessions();
      pushWorldState();
      if (state.beat >= 4) {
        mountRestorationChip();
        await maybeSave(); // covers restoration completed offline/elsewhere
      } else {
        await runLinear();
      }
      emit();
      return getPublicState();
    },
    /** Re-enter a paused linear beat (e.g. after the player wanders off). */
    async resume() {
      if (!loaded) await load();
      if (state.beat <= 3) await runLinear();
      else await maybeSave();
      return getPublicState();
    },
    /** Route a named 3D interaction ('fountain', 'stage', 'east_gate', ...).
     *  Re-entrant taps while a flow's dialog is live are ignored (a second
     *  dialogShell() would orphan the first flow's pending promise). */
    async interact(nodeId) {
      if (interactBusy) return undefined;
      interactBusy = true;
      try {
        if (!loaded) await load();
        const fn = interactions[nodeId];
        if (fn) return await fn();
        return undefined;
      } finally { interactBusy = false; }
    },
    /** Wire-phase event: a library study session (chapter) was completed. */
    async notifyStudySessionComplete(count) {
      if (!loaded) await load();
      const n = Math.max(state.study.sessions, Math.min(3, count | 0));
      if (n > state.study.sessions) {
        const gained = n - state.study.sessions;
        state.study.sessions = n;
        for (let i = 0; i < gained; i++) awardXp(tuning.studySessionXp, { source: 'library-study', town: QUEST_NS });
        await persist();
        emit();
      }
      return state.study.sessions;
    },
    /** Shops-as-service-organs interface (Ch. 7.6). */
    restoration: {
      donateFruit,
      replantPlot,
      addPoints: async (pts, source) => { addRestoration(pts, source || 'wire'); await persist(); await maybeSave(); },
      get: () => ({ points: state.restoration.points, target: tuning.restorationTarget }),
    },
    onEastGateExit,
    getState: getPublicState,
    getQuestMarkers,
    onChange(cb) { listeners.add(cb); return () => listeners.delete(cb); },
    dispose() {
      disposed = true;
      listeners.clear();
      closeDialog();
      if (restoChip) { try { restoChip.remove(); } catch (e) {} restoChip = null; }
    },
  };

  if (IS_DEV) {
    controller.dev = {
      state: () => JSON.parse(JSON.stringify(state)),
      async skipToBeat(n) {
        state.beat = Math.max(1, Math.min(4, n | 0));
        state.sub = 0;
        if (state.beat >= 2) { state.flags.john812Granted = true; state.flags.phil413Granted = true; }
        if (state.beat >= 3) state.flags.lanternGranted = true;
        if (state.beat >= 4) {
          Object.assign(state.flags, { satchelGranted: true, firstStudyMinted: true, bramFreed: true });
          state.fieldsCleared = tuning.fieldWhisperlings;
        }
        await persist(); emit(); pushWorldState();
      },
      async grantSeal() { state.flags.seal1 = true; state.flags.lieLens = true; await persist(); await maybeSave(); },
      async addRestoration(n) { addRestoration(n | 0, 'dev'); await persist(); await maybeSave(); },
      async setStudySessions(n) { state.study.sessions = Math.min(3, n | 0); await persist(); emit(); },
      async reset() { state = defaultPrologueState(now()); await persist(); emit(); pushWorldState(); },
      trivia: () => runTriviaBattle(),
    };
  }

  return controller;
}

export default createPrologue;
