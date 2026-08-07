// =============================================================================
// glowlands/townbook.js
// The Town Book reader — Meadow Town library reading desk (design bible Ch. 3.10)
//
// Phase 1 gateway slice: one book (The Gospel of John, chapters 1-3) read at
// the library desk. Bookshelf intro -> chapter/section navigation -> section
// reading view -> per-section check (comprehension question OR memory-verse
// challenge) -> XP + fruit payouts and Truth Serum minting.
//
// Design authority: /docs/glowlands-design.md
//   Ch. 3.10 — Town Books (single spec: ESV served never bundled, 3 sections
//              per chapter, one check per section, memory-verse mints serums,
//              recharge lives at the desk, 3 sections/day/town payout cap)
//   Ch. 3.1  — payout table (section 40 XP + 2 fruit; memory verse 60 XP + serum)
//   Ch. 5.7  — the Lightfound fanfare (every earn event), audio direction
//   Ch. 7    — Meadow Town library, Maribel Quill
//   Ch. 17   — row 6 (Town Book system scope)
//
// SCRIPTURE RULE (LOCKED): this module bundles ZERO ESV text. All displayed
// verse text is fetched at RUNTIME via
//   ctx.fetchPassage(reference) -> Promise<{reference, translation, text,
//                                           copyright?} | {error}>
// which calls the deployed get-bible-passage edge function (returns 503
// {error:"translation_unavailable"} until the ESV key is configured). Every
// reader/challenge view degrades gracefully to reference + retelling. The
// short copyright that arrives with the text (e.g. "(ESV)") is always
// rendered under the passage. The ONLY bundled verse text anywhere is the
// DEV-only mock passage provider below: import.meta.env.DEV-gated,
// public-domain World English Bible, John 1 only — stripped from production
// builds by Vite's dead-code elimination.
//
// NO three.js, no React, no new dependencies: this is a self-contained DOM
// overlay (2D reading UI adds zero draw calls to the 3D budget). The Wire
// phase mounts it from dragon-garden-quest.jsx at the library desk:
//
//   import createTownBook from './glowlands/townbook.js';
//   const townBook = createTownBook({
//     fetchPassage,               // REQUIRED in prod — see contract above
//     storage: window.storage,    // { get(key)->Promise<{value}>, set(key,str) }
//     awardXP:    (n, meta) => {...},   // credits the shared XP wallet
//     awardFruit: (n, meta) => {...},   // credits the fruit basket
//     satchel: {                        // Verse Satchel bridge (Ch. 2.3)
//       mintSerum: ({ ref, family, lieFamily, sourceId }) => {...},
//       recharge:  () => {...},         // desk = the serum recharge point
//     },
//     sfx: SFX,                   // optional: game SFX object (click/correct/…)
//     fanfare: (weight) => {...}, // optional: the Lightfound jingle ('full'|'small')
//     mountEl: document.body,     // optional overlay parent
//   });
//   // at the reading-desk interaction:
//   townBook.open();
//
// Every ctx member is optional except fetchPassage (in prod); missing members
// degrade to safe internal fallbacks so the module is judgeable standalone.
// =============================================================================

import JOHN_BOOK from './data/john-book.js';
import { LIE_FAMILIES, VERSE_FAMILIES } from './data/combat-data.js';

// ---------------------------------------------------------------------------
// Environment
// ---------------------------------------------------------------------------
const IS_DEV = (() => {
  try { return !!(import.meta.env && import.meta.env.DEV); } catch (e) { return false; }
})();

// ---------------------------------------------------------------------------
// Tunables (Ch. 3.1 / 3.10 — all values the bible marks tunable)
// ---------------------------------------------------------------------------
export const TOWNBOOK_TUNING = Object.freeze({
  xpPerSection: 40,          // Ch. 3.1: Town Book section completed
  fruitPerSection: 2,
  xpPerMemoryVerse: 60,      // Ch. 3.1: memory-verse challenge passed
  dailySectionCap: 3,        // Ch. 3.10 boundary rule: 3 rewarded sections/day/town
  blanksMin: 2,              // memory-verse challenge blank count bounds
  blanksMax: 5,
  blanksPerWords: 6,         // ~1 blank per 6 tokens
  decoyCount: 2,             // extra wrong words mixed into the tap bank
  mockLatencyMs: 350,        // DEV mock: artificial latency so loading state shows
});

/** Storage key for a town book's progress blob. */
export const townBookProgressKey = (bookId) => `glowlands-townbook-${bookId}`;

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
/** Local-time day key for the 3/day payout cap. */
function dayKey(d = new Date()) {
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

// ---------------------------------------------------------------------------
// Storage adapter — window.storage shape ({get -> {value}, set}) with a
// localStorage fallback so the module works in a bare dev page.
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
// Memory-verse tokenization (exported for tests).
// Operates ONLY on runtime-fetched text — nothing here to tokenize at build.
// ---------------------------------------------------------------------------
const STOPWORDS = new Set([
  'the', 'a', 'an', 'and', 'or', 'but', 'of', 'to', 'in', 'on', 'at', 'by',
  'for', 'with', 'as', 'is', 'was', 'were', 'are', 'be', 'been', 'that',
  'this', 'it', 'he', 'she', 'his', 'her', 'him', 'they', 'them', 'their',
  'who', 'whom', 'which', 'not', 'no', 'nor', 'so', 'did', 'do', 'does',
  'have', 'has', 'had', 'from', 'into', 'unto', 'shall', 'will', 'you',
  'your', 'we', 'our', 'us', 'i', 'me', 'my',
]);

/**
 * Tokenize a runtime-fetched passage into blank-able tokens.
 * Strips ESV-API-style "[12]" verse markers and normalizes quotes.
 * @returns {{idx:number, raw:string, display:string, clean:string,
 *            prefix:string, suffix:string}[]}
 */
export function tokenizePassageForBlanks(text) {
  const cleanedText = String(text || '')
    .replace(/\[\d+\]/g, ' ')            // verse-number markers
    .replace(/[“”]/g, '"')
    .replace(/[‘’]/g, '’')
    .replace(/\s+/g, ' ')
    .trim();
  const out = [];
  for (const raw of cleanedText.split(' ')) {
    const m = raw.match(/^([^A-Za-z0-9]*)([A-Za-z0-9’'-]+)([^A-Za-z0-9]*)$/);
    if (!m) continue;
    const display = m[2];
    const clean = display.toLowerCase().replace(/[^a-z0-9]/g, '');
    if (!clean) continue;
    out.push({ idx: out.length, raw, display, prefix: m[1], suffix: m[3], clean });
  }
  return out;
}

/**
 * Deterministically pick which token indices become blanks (seeded by the
 * reference so a verse always drills the same words — memorization aid).
 * Prefers significant words, spreads picks out, respects tuning bounds.
 */
export function pickBlankIndices(tokens, seedStr, tuning = TOWNBOOK_TUNING) {
  const rng = mulberry32(hashStr(seedStr || 'townbook'));
  let candidates = tokens.filter((t) => t.clean.length >= 3 && !STOPWORDS.has(t.clean));
  if (candidates.length < tuning.blanksMin) candidates = tokens.filter((t) => t.clean.length >= 2);
  if (!candidates.length) candidates = tokens.slice();
  const want = Math.max(
    tuning.blanksMin,
    Math.min(tuning.blanksMax, Math.round(tokens.length / tuning.blanksPerWords), candidates.length)
  );
  const pool = shuffled(candidates, rng);
  const picked = [];
  for (const t of pool) {                       // greedy spread: keep blanks apart
    if (picked.length >= want) break;
    if (picked.some((p) => Math.abs(p - t.idx) < 2)) continue;
    picked.push(t.idx);
  }
  for (const t of pool) {                       // relax spacing if we came up short
    if (picked.length >= want) break;
    if (!picked.includes(t.idx)) picked.push(t.idx);
  }
  return picked.sort((a, b) => a - b);
}

// Plausible-but-wrong bank decoys. ORIGINAL single words, not quotes.
const DECOY_POOL = [
  'lantern', 'morning', 'garden', 'river', 'mountain', 'shepherd', 'bread',
  'harvest', 'window', 'crown', 'candle', 'meadow', 'stone', 'wings',
];

// ---------------------------------------------------------------------------
// DEV-ONLY mock passage provider.
// Public-domain World English Bible, John 1 ONLY, so every reader state is
// judgeable before the ESV key exists (John 2-3 requests intentionally return
// translation_unavailable so the degraded path is judgeable too).
// The literal `import.meta.env.DEV` guard lets Vite strip this whole block —
// including the text — from production bundles.
// ---------------------------------------------------------------------------
let DEV_WEB_JOHN1 = null;
if (import.meta.env && import.meta.env.DEV) {
  DEV_WEB_JOHN1 = {
    1: 'In the beginning was the Word, and the Word was with God, and the Word was God.',
    2: 'The same was in the beginning with God.',
    3: 'All things were made through him. Without him, nothing was made that has been made.',
    4: 'In him was life, and the life was the light of men.',
    5: 'The light shines in the darkness, and the darkness hasn’t overcome it.',
    6: 'There came a man, sent from God, whose name was John.',
    7: 'The same came as a witness, that he might testify about the light, that all might believe through him.',
    8: 'He was not the light, but was sent that he might testify about the light.',
    9: 'The true light that enlightens everyone was coming into the world.',
    10: 'He was in the world, and the world was made through him, and the world didn’t recognize him.',
    11: 'He came to his own, and those who were his own didn’t receive him.',
    12: 'But as many as received him, to them he gave the right to become God’s children, to those who believe in his name:',
    13: 'who were born not of blood, nor of the will of the flesh, nor of the will of man, but of God.',
    14: 'The Word became flesh and lived among us. We saw his glory, such glory as of the one and only Son of the Father, full of grace and truth.',
    15: 'John testified about him. He cried out, saying, “This was he of whom I said, ‘He who comes after me has surpassed me, for he was before me.’”',
    16: 'From his fullness we all received grace upon grace.',
    17: 'For the law was given through Moses. Grace and truth were realized through Jesus Christ.',
    18: 'No one has seen God at any time. The one and only Son, who is in the bosom of the Father, has declared him.',
    19: 'This is John’s testimony, when the Jews sent priests and Levites from Jerusalem to ask him, “Who are you?”',
    20: 'He declared, and didn’t deny, but he declared, “I am not the Christ.”',
    21: 'They asked him, “What then? Are you Elijah?” He said, “I am not.” “Are you the prophet?” He answered, “No.”',
    22: 'They said therefore to him, “Who are you? Give us an answer to take back to those who sent us. What do you say about yourself?”',
    23: 'He said, “I am the voice of one crying in the wilderness, ‘Make straight the way of the Lord,’ as Isaiah the prophet said.”',
    24: 'The ones who had been sent were from the Pharisees.',
    25: 'They asked him, “Why then do you baptize, if you are not the Christ, nor Elijah, nor the prophet?”',
    26: 'John answered them, “I baptize in water, but among you stands one whom you don’t know.',
    27: 'He is the one who comes after me, who is preferred before me, whose sandal strap I’m not worthy to loosen.”',
    28: 'These things were done in Bethany beyond the Jordan, where John was baptizing.',
    29: 'The next day, he saw Jesus coming to him, and said, “Behold, the Lamb of God, who takes away the sin of the world!',
    30: 'This is he of whom I said, ‘After me comes a man who is preferred before me, for he was before me.’',
    31: 'I didn’t know him, but for this reason I came baptizing in water: that he would be revealed to Israel.”',
    32: 'John testified, saying, “I have seen the Spirit descending like a dove out of heaven, and it remained on him.',
    33: 'I didn’t recognize him, but he who sent me to baptize in water said to me, ‘On whomever you will see the Spirit descending and remaining on him is he who baptizes in the Holy Spirit.’',
    34: 'I have seen and have testified that this is the Son of God.”',
    35: 'Again, the next day, John was standing with two of his disciples,',
    36: 'and he looked at Jesus as he walked, and said, “Behold, the Lamb of God!”',
    37: 'The two disciples heard him speak, and they followed Jesus.',
    38: 'Jesus turned and saw them following, and said to them, “What are you looking for?” They said to him, “Rabbi” (which is to say, being interpreted, Teacher), “where are you staying?”',
    39: 'He said to them, “Come and see.” They came and saw where he was staying, and they stayed with him that day. It was about the tenth hour.',
    40: 'One of the two who heard John and followed him was Andrew, Simon Peter’s brother.',
    41: 'He first found his own brother, Simon, and said to him, “We have found the Messiah!” (which is, being interpreted, Christ).',
    42: 'He brought him to Jesus. Jesus looked at him and said, “You are Simon the son of Jonah. You shall be called Cephas” (which is by interpretation, Peter).',
    43: 'On the next day, he was determined to go out into Galilee, and he found Philip. Jesus said to him, “Follow me.”',
    44: 'Now Philip was from Bethsaida, the city of Andrew and Peter.',
    45: 'Philip found Nathanael, and said to him, “We have found him of whom Moses in the law and also the prophets wrote: Jesus of Nazareth, the son of Joseph.”',
    46: 'Nathanael said to him, “Can any good thing come out of Nazareth?” Philip said to him, “Come and see.”',
    47: 'Jesus saw Nathanael coming to him, and said about him, “Behold, an Israelite indeed, in whom is no deceit!”',
    48: 'Nathanael said to him, “How do you know me?” Jesus answered him, “Before Philip called you, when you were under the fig tree, I saw you.”',
    49: 'Nathanael answered him, “Rabbi, you are the Son of God! You are King of Israel!”',
    50: 'Jesus answered him, “Because I told you, ‘I saw you underneath the fig tree,’ do you believe? You will see greater things than these!”',
    51: 'He said to him, “Most certainly, I tell you all, hereafter you will see heaven opened, and the angels of God ascending and descending on the Son of Man.”',
  };
}

/**
 * DEV-only mock ctx.fetchPassage. Returns null outside dev builds (the data
 * above is stripped, so there is nothing to serve). Serves John 1 only, as
 * WEB with a clear mock copyright line; anything else degrades exactly like
 * the real edge function pre-ESV-key: {error:'translation_unavailable'}.
 */
export function createDevMockPassageProvider() {
  if (!DEV_WEB_JOHN1) return null;
  return async function mockFetchPassage(reference) {
    await new Promise((r) => setTimeout(r, TOWNBOOK_TUNING.mockLatencyMs));
    const m = String(reference || '').trim().match(/^John\s+1:(\d+)(?:-(\d+))?$/i);
    if (!m) return { error: 'translation_unavailable' };
    const a = parseInt(m[1], 10);
    const b = m[2] ? parseInt(m[2], 10) : a;
    const parts = [];
    for (let v = a; v <= b; v++) {
      if (!DEV_WEB_JOHN1[v]) return { error: 'translation_unavailable' };
      parts.push(`[${v}] ${DEV_WEB_JOHN1[v]}`);
    }
    return {
      reference,
      translation: 'WEB',
      text: parts.join(' '),
      copyright: '(WEB — public domain · DEV mock, not shipped)',
    };
  };
}

// ---------------------------------------------------------------------------
// Passage service — session cache (successes only, so errors stay retryable).
// ---------------------------------------------------------------------------
function createPassageService(getFetcher) {
  const cache = new Map();
  return {
    async get(reference) {
      if (cache.has(reference)) return cache.get(reference);
      const fetcher = getFetcher();
      if (typeof fetcher !== 'function') return { error: 'translation_unavailable' };
      let res;
      try { res = await fetcher(reference); } catch (e) { res = { error: 'network' }; }
      if (res && res.text && !res.error) cache.set(reference, res);
      return res || { error: 'translation_unavailable' };
    },
    clear() { cache.clear(); },
  };
}

// ---------------------------------------------------------------------------
// Fallback SFX + Lightfound fanfare (used only when ctx.sfx / ctx.fanfare are
// absent — e.g. judging the module standalone). Mirrors the game's WebAudio
// blip style; the real game passes its SFX object through ctx.
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
    click:   () => tone(1150, now(), 0.05, 0.06, 'square'),
    correct: () => { const t = now(); tone(880, t, 0.12, 0.12); tone(1108.7, t + 0.09, 0.16, 0.12); },
    wrong:   () => tone(200, now(), 0.22, 0.1, 'square'),
    pageTurn: () => tone(520, now(), 0.08, 0.05, 'triangle'),
  };
  const sfx = {};
  for (const k of Object.keys(fb)) sfx[k] = (ctxSfx && typeof ctxSfx[k] === 'function') ? () => ctxSfx[k]() : fb[k];
  // Lightfound fanfare (Ch. 5.7): full = milestones (serum mint), small = pickups.
  sfx.fanfare = (weight = 'small') => {
    if (typeof ctxFanfare === 'function') { ctxFanfare(weight); return; }
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
// Narration player — sequential per-verse MP3s on one reused <audio> element.
// NLT recorded narration is read-aloud audio, NEVER word-for-word highlight
// text against the displayed ESV (john-book.js caveat), so there is no text
// sync — just play/stop and a verse counter.
// ---------------------------------------------------------------------------
function createNarrationPlayer(onUpdate) {
  let audio = null, urls = [], i = 0, playing = false, startVerse = 1;
  const status = () => ({ playing, verse: startVerse + i, index: i, total: urls.length });
  const notify = () => { try { onUpdate(status()); } catch (e) { /* UI gone */ } };
  function next() {
    if (!playing) return;
    i++;
    if (i < urls.length) { audio.src = urls[i]; audio.play().catch(stop); notify(); }
    else stop();
  }
  function ensure() {
    if (audio) return;
    audio = document.createElement('audio');
    audio.setAttribute('playsinline', '');
    audio.preload = 'none';
    audio.addEventListener('ended', next);
    audio.addEventListener('error', next); // a missing verse file skips forward
  }
  function play(list, firstVerse = 1) {
    if (!list || !list.length) return;
    ensure();
    urls = list.slice(); i = 0; startVerse = firstVerse; playing = true;
    audio.src = urls[0];
    audio.play().catch(() => stop());
    notify();
  }
  function stop() {
    playing = false;
    if (audio) { try { audio.pause(); audio.removeAttribute('src'); } catch (e) { /* fine */ } }
    notify();
  }
  return { play, stop, status, get playing() { return playing; }, dispose() { stop(); audio = null; } };
}

// ---------------------------------------------------------------------------
// Warm-library visual language — the game's ornate wood-and-gold panel system
// (dragon-garden-quest.jsx S.panel / Ribbon / Corners) warmed to lamplit
// parchment for the library interior.
// ---------------------------------------------------------------------------
const UI = Object.freeze({
  font: "'Trebuchet MS', 'Segoe UI', sans-serif",
  scrim: 'rgba(24, 15, 6, 0.62)',
  parchment: 'radial-gradient(120% 80% at 50% -20%, rgba(255,250,235,0.95), rgba(255,250,235,0) 55%), linear-gradient(180deg, #fdf4de 0%, #f4e4bd 55%, #e9d5a4 100%)',
  parchmentDeep: 'linear-gradient(180deg, #f8ecd0 0%, #eddcb4 100%)',
  wood: '#7a5230',
  woodDark: '#5e3c1e',
  ink: '#4a3218',
  inkSoft: 'rgba(74, 50, 24, 0.7)',
  gold: '#b07a28',
  goldBright: '#ffb845',
  goldText: { color: '#b3760f', textShadow: '0 1px 0 rgba(255,255,255,0.6)' },
  green: '#2f7a3c',
  greenBtn: 'linear-gradient(180deg, #6cd47a, #2f7a3c)',
  goldBtn: 'linear-gradient(180deg, #ffc85e, #f0931c)',
  amber: '#a3641a',
  panelShadow: 'inset 0 0 0 2px rgba(255,244,214,0.85), inset 0 -3px 8px rgba(122,82,48,0.18), 0 10px 26px rgba(30,18,6,0.5)',
});

const STYLE_ID = 'glowlands-townbook-style';
function ensureStyles() {
  if (document.getElementById(STYLE_ID)) return;
  const s = document.createElement('style');
  s.id = STYLE_ID;
  s.textContent = `
    @keyframes tbSpin { to { transform: rotate(360deg); } }
    @keyframes tbShake { 0%,100% { transform: translateX(0); } 25% { transform: translateX(-5px); } 75% { transform: translateX(5px); } }
    @keyframes tbPop { 0% { transform: scale(0.72); opacity: 0; } 100% { transform: scale(1); opacity: 1; } }
    @keyframes tbFadeUp { 0% { transform: translateY(10px); opacity: 0; } 100% { transform: translateY(0); opacity: 1; } }
    @keyframes tbGlow { 0%,100% { box-shadow: 0 0 12px rgba(255,184,69,0.35); } 50% { box-shadow: 0 0 26px rgba(255,184,69,0.75); } }
    @keyframes tbToast { 0% { transform: translateY(-8px); opacity: 0; } 12% { transform: translateY(0); opacity: 1; } 85% { opacity: 1; } 100% { opacity: 0; } }
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

const ribbon = (text) => el('div', { style: { textAlign: 'center', margin: '0 0 12px' } },
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

/** Passage text renderer — turns "[12] words…" into styled spans. */
function renderPassageText(text) {
  const wrap = el('div', {
    style: { fontSize: '15.5px', lineHeight: '1.72', color: UI.ink, fontFamily: 'Georgia, serif', textAlign: 'left' },
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

// ---------------------------------------------------------------------------
// Future-shelf flavor (Ch. 3.10 table) — spine labels only, no scripture.
// ---------------------------------------------------------------------------
const FUTURE_SHELF = [
  { town: 'Riverbend', book: 'Philippians' },
  { town: 'Lantern Hollow', book: '1 John' },
  { town: 'Glimmerton', book: 'Ecclesiastes' },
  { town: 'Starcrest', book: '1 Peter' },
  { town: 'Brightharbor', book: 'Acts' },
];

// =============================================================================
// createTownBook(ctx, opts) — the controller
// =============================================================================
export function createTownBook(ctx = {}, opts = {}) {
  const tuning = { ...TOWNBOOK_TUNING, ...(opts.tuning || {}) };
  const book = opts.book || JOHN_BOOK;
  const storage = makeStorage(ctx.storage);
  const sfx = makeSfx(ctx.sfx, ctx.fanfare);
  const storageKey = townBookProgressKey(book.meta.bookId);

  // --- dev flags (no-ops in prod; the mock itself only exists in dev) ---
  const devFlags = { forceMock: false, forceUnavailable: false };
  let mockProvider; // lazy
  const getFetcher = () => {
    if (IS_DEV && devFlags.forceUnavailable) return async () => ({ error: 'translation_unavailable' });
    if (IS_DEV && devFlags.forceMock) return (mockProvider ||= createDevMockPassageProvider());
    if (typeof ctx.fetchPassage === 'function') return ctx.fetchPassage;
    if (IS_DEV) return (mockProvider ||= createDevMockPassageProvider());
    return null;
  };
  const passages = createPassageService(getFetcher);

  // --- flattened section order (bookmark math) ---
  const FLAT = [];
  for (const ch of book.chapters) {
    ch.sections.forEach((s, i) => FLAT.push({ chapter: ch.chapter, chapterTitle: ch.title, sectionIdx: i, section: s }));
  }
  const flatIndexOf = (sectionId) => FLAT.findIndex((f) => f.section.id === sectionId);

  // --- progress (persisted; bookmark never regresses — Ch. 3.10) ---
  let progress = { v: 1, bookId: book.meta.bookId, completed: {}, mvPassed: {}, daily: { day: dayKey(), count: 0 }, lastSectionId: null };
  let progressLoaded = false;
  async function loadProgress() {
    const raw = await storage.get(storageKey);
    if (raw) {
      try {
        const d = JSON.parse(raw);
        if (d && d.v === 1 && d.bookId === book.meta.bookId) {
          progress = { ...progress, ...d, completed: d.completed || {}, mvPassed: d.mvPassed || {}, daily: d.daily || progress.daily };
        }
      } catch (e) { /* corrupt blob: keep fresh progress */ }
    }
    progressLoaded = true;
  }
  function saveProgress() {
    storage.set(storageKey, JSON.stringify(progress));
  }
  const firstIncompleteFlat = () => {
    const i = FLAT.findIndex((f) => !progress.completed[f.section.id]);
    return i === -1 ? FLAT.length - 1 : i;
  };
  const isUnlocked = (sectionId) => flatIndexOf(sectionId) <= firstIncompleteFlat();
  const rewardedToday = () => (progress.daily.day === dayKey() ? progress.daily.count : 0);

  // --- payouts (Ch. 3.1) ---
  function warnMissing(name) {
    if (IS_DEV) console.warn(`[townbook] ctx.${name} not wired — payout skipped (Wire phase hooks this up)`);
  }
  function awardXP(n, meta) {
    if (typeof ctx.awardXP === 'function') { try { ctx.awardXP(n, meta); } catch (e) { /* wallet hiccup: UI already showed the earn */ } }
    else warnMissing('awardXP');
  }
  function awardFruit(n, meta) {
    if (typeof ctx.awardFruit === 'function') { try { ctx.awardFruit(n, meta); } catch (e) { /* ditto */ } }
    else warnMissing('awardFruit');
  }
  function mintSerum(mv) {
    const payload = {
      ref: mv.reference,
      family: mv.serum.counterFamily,
      lieFamily: mv.serum.lieFamily,
      source: 'townbook',
      sourceId: mv.id,
    };
    const mint = (ctx.satchel && ctx.satchel.mintSerum) || ctx.mintSerum;
    if (typeof mint === 'function') { try { mint(payload); } catch (e) { /* satchel will re-sync */ } }
    else warnMissing('satchel.mintSerum');
    return payload;
  }
  function deskRecharge() {
    const fn = (ctx.satchel && ctx.satchel.recharge) || ctx.rechargeSerums;
    if (typeof fn === 'function') { try { fn(); return true; } catch (e) { return false; } }
    return false;
  }

  /**
   * Apply completion + payouts for a section check that was just passed.
   * Section pay (40 XP + 2 fruit) is first-completion only and 3/day capped;
   * memory-verse pay (60 XP + serum) is per-check, once ever per verse.
   */
  function settleSection(flatEntry, { mvJustPassed = false } = {}) {
    const s = flatEntry.section;
    const res = { xp: 0, fruit: 0, serum: null, capped: false, alreadyDone: !!progress.completed[s.id] };
    if (!res.alreadyDone) {
      progress.completed[s.id] = true;
      const today = dayKey();
      if (progress.daily.day !== today) progress.daily = { day: today, count: 0 };
      if (progress.daily.count < tuning.dailySectionCap) {
        progress.daily.count++;
        res.xp += tuning.xpPerSection;
        res.fruit += tuning.fruitPerSection;
      } else res.capped = true;
    }
    if (mvJustPassed && s.memoryVerse && !progress.mvPassed[s.memoryVerse.id]) {
      progress.mvPassed[s.memoryVerse.id] = true;
      res.xp += tuning.xpPerMemoryVerse;
      res.serum = mintSerum(s.memoryVerse);
    }
    if (res.xp) awardXP(res.xp, { source: 'townbook', bookId: book.meta.bookId, sectionId: s.id, memoryVerse: mvJustPassed });
    if (res.fruit) awardFruit(res.fruit, { source: 'townbook', bookId: book.meta.bookId, sectionId: s.id });
    saveProgress();
    return res;
  }

  // ---------------------------------------------------------------------------
  // Overlay state machine
  // screens: shelf | chapters | section | question | memory | result
  // ---------------------------------------------------------------------------
  let root = null, body = null, toastBox = null;
  let state = null;
  let loadSeq = 0;
  const narrator = createNarrationPlayer(() => { if (state && (state.screen === 'section' || state.screen === 'memory')) render(); });

  function toast(msg) {
    if (!toastBox) return;
    const t = el('div', {
      style: {
        background: 'linear-gradient(180deg, #fff7e2, #f2e2ba)', border: `1.5px solid ${UI.gold}`,
        color: UI.ink, borderRadius: '10px', padding: '7px 14px', fontSize: '12.5px', fontWeight: '700',
        boxShadow: '0 4px 10px rgba(30,18,6,0.4)', animation: 'tbToast 2.8s forwards', pointerEvents: 'none',
      },
    }, msg);
    toastBox.append(t);
    setTimeout(() => t.remove(), 2900);
  }

  function close() {
    if (!root) return;
    narrator.stop();
    saveProgress();
    root.remove();
    root = body = toastBox = null;
    state = null;
    if (typeof ctx.onClose === 'function') { try { ctx.onClose(); } catch (e) { /* game hook */ } }
  }

  async function open(sectionId) {
    if (root) return; // already open
    ensureStyles();
    if (!progressLoaded) await loadProgress();

    const mount = ctx.mountEl || document.body;
    root = el('div', {
      style: {
        position: 'fixed', inset: '0', zIndex: '40', display: 'flex', alignItems: 'center',
        justifyContent: 'center', fontFamily: UI.font, userSelect: 'none', WebkitUserSelect: 'none',
      },
    });
    root.append(el('div', { style: { position: 'absolute', inset: '0', background: UI.scrim }, onClick: () => { sfx.click(); close(); } }));
    const panel = el('div', {
      style: {
        position: 'relative', width: 'min(94vw, 540px)', maxHeight: 'min(88vh, 760px)',
        display: 'flex', flexDirection: 'column', background: UI.parchment,
        border: `2px solid ${UI.wood}`, borderRadius: '18px', boxShadow: UI.panelShadow,
        color: UI.ink, padding: '16px 16px calc(14px + env(safe-area-inset-bottom, 0px))',
        animation: 'tbPop 0.22s ease-out',
      },
    }, ...corners());
    panel.append(el('button', {
      style: {
        position: 'absolute', top: '8px', right: '10px', zIndex: '2', width: '30px', height: '30px',
        borderRadius: '50%', border: `1.5px solid ${UI.wood}`, background: 'linear-gradient(180deg,#fff4da,#eeddb2)',
        color: UI.ink, fontWeight: '800', fontSize: '14px', cursor: 'pointer', fontFamily: 'inherit',
      },
      onClick: () => { sfx.click(); close(); },
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

    // The reading desk is the serum recharge point (Ch. 3.10 / 2.3).
    if (deskRecharge()) toast('🕯 Reading desk: your Verse Satchel is recharged.');

    if (sectionId && flatIndexOf(sectionId) !== -1 && isUnlocked(sectionId)) gotoSection(sectionId);
    else state = { screen: 'shelf' };
    render();
  }

  function gotoSection(sectionId) {
    const fi = flatIndexOf(sectionId);
    const entry = FLAT[fi];
    progress.lastSectionId = sectionId;
    saveProgress();
    state = { screen: 'section', flat: entry, passage: { status: 'loading' }, showRetelling: false };
    loadPassage(entry.section.reference);
  }

  function loadPassage(reference) {
    const seq = ++loadSeq;
    passages.get(reference).then((res) => {
      if (seq !== loadSeq || !state) return;
      if (state.screen === 'section') {
        state.passage = res && res.text && !res.error ? { status: 'ok', data: res } : { status: 'error', error: (res && res.error) || 'unavailable' };
        render();
      }
    });
  }

  // ------------------------------------------------------------------ screens
  function render() {
    if (!body || !state) return;
    body.replaceChildren();
    const r = {
      shelf: renderShelf, chapters: renderChapters, section: renderSection,
      question: renderQuestion, memory: renderMemory, result: renderResult,
    }[state.screen];
    if (r) r();
  }

  // --- 1. Bookshelf intro -------------------------------------------------
  function renderShelf() {
    const done = FLAT.filter((f) => progress.completed[f.section.id]).length;
    const bm = FLAT[firstIncompleteFlat()];
    body.append(ribbon('MEADOW TOWN LIBRARY'));
    body.append(el('div', { style: { display: 'flex', alignItems: 'center', gap: '10px', margin: '2px 2px 12px' } },
      el('div', {
        style: {
          width: '44px', height: '44px', flex: '0 0 44px', borderRadius: '50%',
          background: 'radial-gradient(circle at 35% 30%, #e8d5a8, #8a6a3a)', border: `2px solid ${UI.gold}`,
          display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '24px',
          boxShadow: '0 3px 8px rgba(30,18,6,0.5)',
        },
      }, '📖'),
      el('em', { style: { fontSize: '12.5px', color: UI.inkSoft, lineHeight: '1.45' } },
        '“Mind the dust, dear. The town’s book waits at the desk — and the desk always tops up your satchel.” — Maribel Quill')));

    // The town's book — warm, glowing, openable.
    const card = el('div', {
      style: {
        position: 'relative', borderRadius: '14px', padding: '14px 14px 12px', margin: '0 2px 12px',
        background: UI.parchmentDeep, border: `2px solid ${UI.gold}`,
        animation: 'tbGlow 3s infinite', cursor: 'pointer',
      },
      onClick: () => { sfx.pageTurn(); state = { screen: 'chapters' }; render(); },
    },
      el('div', { style: { fontFamily: 'Georgia, serif', fontSize: '19px', fontWeight: '700', color: UI.ink } }, book.meta.bookTitle),
      el('div', { style: { fontSize: '11px', color: UI.inkSoft, margin: '3px 0 8px' } },
        `${book.meta.translation.id} · read at the desk · chapters ${book.meta.chaptersIncluded[0]}–${book.meta.chaptersIncluded[book.meta.chaptersIncluded.length - 1]} of ${book.meta.chaptersTotal} on the desk`),
      el('div', { style: { height: '9px', borderRadius: '6px', background: 'rgba(74,50,24,0.18)', overflow: 'hidden', marginBottom: '6px' } },
        el('div', { style: { height: '100%', width: `${Math.round((done / FLAT.length) * 100)}%`, background: 'linear-gradient(90deg, #ffc85e, #f0931c)', borderRadius: '6px', transition: 'width 0.3s' } })),
      el('div', { style: { display: 'flex', justifyContent: 'space-between', alignItems: 'center' } },
        el('span', { style: { fontSize: '12px', fontWeight: '700', color: UI.amber } }, `${done}/${FLAT.length} sections studied`),
        button(done === 0 ? '▸ Open the book' : `▸ Continue · ${bm.chapterTitle}`, { small: true }, (e) => {
          e.stopPropagation(); sfx.pageTurn(); state = { screen: 'chapters' }; render();
        })));
    body.append(card);

    // Future spines — flavor only.
    body.append(el('div', { style: { fontSize: '10px', letterSpacing: '1.5px', color: UI.inkSoft, margin: '2px 4px 6px' } }, 'OTHER TOWNS KEEP THEIR OWN BOOKS'));
    body.append(el('div', {
      style: {
        display: 'flex', gap: '6px', alignItems: 'flex-end', padding: '10px 8px 8px', borderRadius: '12px',
        background: 'linear-gradient(180deg, #8a5f38 0%, #6a4522 100%)', boxShadow: 'inset 0 2px 6px rgba(0,0,0,0.35)', margin: '0 2px',
      },
    }, FUTURE_SHELF.map((b, i) => el('div', {
      style: {
        flex: '1', height: `${52 + (i % 3) * 8}px`, borderRadius: '4px 4px 2px 2px',
        background: 'linear-gradient(180deg, #b39a72, #94794f)', border: '1px solid rgba(60,38,14,0.5)',
        opacity: '0.55', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
        color: '#3d2a12', textAlign: 'center', padding: '2px',
      },
    },
      el('div', { style: { fontSize: '8.5px', fontWeight: '800', lineHeight: '1.2' } }, b.book),
      el('div', { style: { fontSize: '7px', opacity: '0.8' } }, b.town)))));
    body.append(el('div', { style: { fontSize: '10.5px', color: UI.inkSoft, textAlign: 'center', margin: '8px 0 2px', fontStyle: 'italic' } },
      'Sections pay XP and fruit (3 a day). Memory verses mint Truth Serums.'));

    if (IS_DEV) renderDevBar();
  }

  function renderDevBar() {
    body.append(el('div', {
      style: {
        marginTop: '10px', padding: '7px 9px', borderRadius: '9px', border: '1px dashed #a3641a',
        background: 'rgba(255,184,69,0.12)', display: 'flex', gap: '6px', alignItems: 'center', flexWrap: 'wrap',
      },
    },
      el('span', { style: { fontSize: '9.5px', fontWeight: '800', letterSpacing: '1px', color: UI.amber } }, 'DEV'),
      button(devFlags.forceMock ? 'mock: ON' : 'mock: off', { kind: 'plain', small: true }, () => { devFlags.forceMock = !devFlags.forceMock; passages.clear(); render(); }),
      button(devFlags.forceUnavailable ? '503: ON' : '503: off', { kind: 'plain', small: true }, () => { devFlags.forceUnavailable = !devFlags.forceUnavailable; render(); }),
      button('reset progress', { kind: 'plain', small: true }, () => {
        progress = { v: 1, bookId: book.meta.bookId, completed: {}, mvPassed: {}, daily: { day: dayKey(), count: 0 }, lastSectionId: null };
        saveProgress(); render();
      })));
  }

  // --- 2. Chapter / section navigation ------------------------------------
  function renderChapters() {
    body.append(ribbon(book.meta.bookTitle.toUpperCase()));
    body.append(el('div', { style: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', margin: '0 2px 10px' } },
      button('◂ Shelf', { kind: 'plain', small: true }, () => { sfx.click(); state = { screen: 'shelf' }; render(); }),
      el('span', {
        style: {
          fontSize: '11px', fontWeight: '700', color: rewardedToday() >= tuning.dailySectionCap ? UI.amber : UI.green,
          border: `1px solid ${UI.gold}`, borderRadius: '999px', padding: '3px 10px', background: 'rgba(255,247,226,0.8)',
        },
      }, `today’s study: ${rewardedToday()}/${tuning.dailySectionCap} rewarded`)));

    const bmIdx = firstIncompleteFlat();
    for (const ch of book.chapters) {
      body.append(el('div', { style: { margin: '10px 4px 5px', display: 'flex', alignItems: 'baseline', gap: '8px' } },
        el('span', { style: { fontFamily: 'Georgia, serif', fontSize: '16px', fontWeight: '700', color: UI.ink } }, `Chapter ${ch.chapter}`),
        el('span', { style: { fontSize: '12px', color: UI.inkSoft, fontStyle: 'italic' } }, ch.title)));
      for (const s of ch.sections) {
        const fi = flatIndexOf(s.id);
        const isDone = !!progress.completed[s.id];
        const locked = fi > bmIdx;
        const isBm = fi === bmIdx && !isDone;
        const mvPending = s.memoryVerse && isDone && !progress.mvPassed[s.memoryVerse.id];
        const row = el('div', {
          style: {
            display: 'flex', alignItems: 'center', gap: '10px', margin: '5px 2px', padding: '9px 11px',
            borderRadius: '11px', cursor: locked ? 'default' : 'pointer',
            background: isBm ? 'linear-gradient(180deg, rgba(255,200,94,0.5), rgba(255,247,226,0.9))' : 'rgba(255,250,235,0.75)',
            border: isBm ? `2px solid ${UI.goldBright}` : `1px solid ${locked ? 'rgba(122,82,48,0.3)' : UI.gold}`,
            opacity: locked ? '0.55' : '1',
            boxShadow: locked ? 'none' : 'inset 0 1px 2px rgba(255,255,255,0.7), 0 2px 5px rgba(30,18,6,0.18)',
          },
          onClick: locked ? null : () => { sfx.pageTurn(); gotoSection(s.id); render(); },
        },
          el('span', { style: { fontSize: '17px', flex: '0 0 auto' } }, locked ? '🔒' : isDone ? '✅' : '🔖'),
          el('div', { style: { flex: '1', minWidth: '0' } },
            el('div', { style: { fontWeight: '800', fontSize: '13.5px', color: UI.ink } }, s.title),
            el('div', { style: { fontSize: '10.5px', color: UI.inkSoft } }, s.reference)),
          s.memoryVerse && el('span', {
            style: {
              fontSize: '9.5px', fontWeight: '800', padding: '3px 8px', borderRadius: '999px', flex: '0 0 auto',
              border: `1px solid ${LIE_FAMILIES[s.memoryVerse.serum.lieFamily].color}`,
              color: mvPending ? UI.amber : progress.mvPassed[s.memoryVerse.id] ? UI.green : UI.inkSoft,
              background: 'rgba(255,250,235,0.9)',
            },
          }, progress.mvPassed[s.memoryVerse.id] ? '💎 serum minted'
            : mvPending ? '💎 challenge waiting'
              : `💎 ${VERSE_FAMILIES[s.memoryVerse.serum.counterFamily].label} serum`));
        body.append(row);
      }
    }
  }

  // --- 3. Section reading view --------------------------------------------
  function renderSection() {
    const { flat, passage } = state;
    const s = flat.section;
    body.append(el('div', { style: { display: 'flex', alignItems: 'center', gap: '8px', margin: '0 2px 8px' } },
      button('◂ Chapters', { kind: 'plain', small: true }, () => { sfx.click(); narrator.stop(); state = { screen: 'chapters' }; render(); }),
      el('div', { style: { flex: '1', minWidth: '0', textAlign: 'right' } },
        el('div', { style: { fontSize: '10px', color: UI.inkSoft, letterSpacing: '1px' } }, `CHAPTER ${flat.chapter} · ${flat.chapterTitle.toUpperCase()}`))));
    body.append(el('div', { style: { textAlign: 'center', margin: '0 0 4px' } },
      el('div', { style: { fontFamily: 'Georgia, serif', fontSize: '19px', fontWeight: '700', color: UI.ink } }, s.title),
      el('div', {
        style: {
          display: 'inline-block', marginTop: '4px', fontSize: '11.5px', fontWeight: '700', color: UI.amber,
          border: `1px solid ${UI.gold}`, borderRadius: '999px', padding: '2px 12px', background: 'rgba(255,247,226,0.85)',
        },
      }, s.reference)));

    // Audio narration row (Ch. 5.7 / john-book caveat: read-aloud only).
    if (s.audio && s.audio.urls && s.audio.urls.length) {
      const st = narrator.status();
      body.append(el('div', { style: { display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '9px', margin: '8px 0' } },
        button(narrator.playing ? '■ Stop' : '🔊 Listen', { kind: narrator.playing ? 'plain' : 'green', small: true }, () => {
          sfx.click();
          if (narrator.playing) narrator.stop();
          else narrator.play(s.audio.urls, s.verseRange ? s.verseRange[0] : 1);
        }),
        el('span', { style: { fontSize: '10.5px', color: UI.inkSoft } },
          narrator.playing ? `verse ${st.verse} · ${st.index + 1}/${st.total}` : `${s.audio.translation} narration · read-aloud`)));
    }

    // Passage area: loading -> ESV text (+ short copyright) -> degraded.
    const area = el('div', {
      style: {
        borderRadius: '12px', border: `1.5px solid ${UI.gold}`, background: 'rgba(255,250,238,0.9)',
        boxShadow: 'inset 0 1px 4px rgba(122,82,48,0.18)', padding: '13px 15px', margin: '4px 2px 8px',
      },
    });
    if (passage.status === 'loading') {
      area.append(el('div', { style: { display: 'flex', alignItems: 'center', gap: '10px', justifyContent: 'center', padding: '18px 0', color: UI.inkSoft } },
        el('span', {
          style: {
            width: '18px', height: '18px', border: `3px solid rgba(176,122,40,0.25)`, borderTopColor: UI.amber,
            borderRadius: '50%', display: 'inline-block', animation: 'tbSpin 0.9s linear infinite',
          },
        }),
        el('span', { style: { fontSize: '13px', fontStyle: 'italic' } }, 'Maribel is finding the page…')));
    } else if (passage.status === 'ok') {
      const d = passage.data;
      area.append(renderPassageText(d.text));
      // Short copyright arrives with the text (LOCKED rule: always shown).
      area.append(el('div', { style: { fontSize: '10px', color: UI.inkSoft, textAlign: 'right', marginTop: '9px' } },
        d.copyright || (d.translation ? `(${d.translation})` : '(ESV)')));
    } else {
      // Graceful degraded mode: reference + retelling, retry offered.
      area.append(el('div', {
        style: {
          borderRadius: '9px', border: `1px solid ${UI.amber}`, background: 'rgba(255,184,69,0.14)',
          padding: '8px 11px', marginBottom: '10px', fontSize: '11.5px', color: UI.amber, fontWeight: '700',
          display: 'flex', alignItems: 'center', gap: '8px', animation: 'tbFadeUp 0.25s',
        },
      },
        el('span', { style: { fontSize: '15px' } }, '🕯'),
        el('span', { style: { flex: '1', fontWeight: '600', color: UI.ink } },
          `The ${book.meta.translation.id} page isn’t on the desk right now — here is ${s.reference} in Maribel’s words. The full text returns soon.`),
        button('Retry', { small: true }, () => { sfx.click(); state.passage = { status: 'loading' }; render(); loadPassage(s.reference); })));
      area.append(el('div', { style: { fontSize: '14px', lineHeight: '1.7', color: UI.ink, fontStyle: 'italic' } }, s.retelling));
    }
    body.append(area);

    // Maribel's retelling is always available under the fetched text.
    if (passage.status === 'ok') {
      const open = state.showRetelling;
      body.append(el('div', { style: { margin: '0 2px 8px' } },
        el('div', {
          style: { fontSize: '11.5px', fontWeight: '800', color: UI.amber, cursor: 'pointer', padding: '4px 2px' },
          onClick: () => { sfx.click(); state.showRetelling = !open; render(); },
        }, `${open ? '▾' : '▸'} Maribel’s retelling`),
        open && el('div', {
          style: {
            fontSize: '12.5px', lineHeight: '1.65', color: UI.inkSoft, fontStyle: 'italic',
            borderLeft: `3px solid ${UI.gold}`, padding: '4px 10px', margin: '2px 4px', animation: 'tbFadeUp 0.2s',
          },
        }, s.retelling)));
    }

    // Footer: on to the section's one check (question XOR memory verse).
    const ready = passage.status !== 'loading';
    const isDone = !!progress.completed[s.id];
    const label = s.memoryVerse
      ? (progress.mvPassed[s.memoryVerse.id] ? '💎 Practice the memory verse' : '💎 Memory-verse challenge')
      : (isDone ? 'Re-read the question' : 'Continue → question');
    body.append(el('div', { style: { textAlign: 'center', marginTop: '4px' } },
      button(label, { kind: 'green', disabled: !ready }, () => {
        sfx.click(); narrator.stop();
        if (s.memoryVerse) startMemory(flat);
        else { state = { screen: 'question', flat, picked: null, wrong: new Set(), tries: 0 }; render(); }
      })));
  }

  // --- 4a. Comprehension question (warm retry — Ch. 3.10) ------------------
  function renderQuestion() {
    const { flat } = state;
    const s = flat.section;
    const q = s.question;
    body.append(ribbon('LOOK CLOSER'));
    body.append(el('div', { style: { fontSize: '10.5px', color: UI.inkSoft, textAlign: 'center', marginBottom: '8px' } },
      `${s.title} · ${s.reference}`));
    body.append(el('div', {
      style: { fontFamily: 'Georgia, serif', fontSize: '16px', lineHeight: '1.5', color: UI.ink, textAlign: 'center', margin: '0 8px 14px' },
    }, q.prompt));

    q.choices.forEach((choice, i) => {
      const wrong = state.wrong.has(i);
      body.append(el('div', {
        style: {
          margin: '7px 4px', padding: '11px 13px', borderRadius: '11px', fontSize: '13.5px', fontWeight: '700',
          color: wrong ? 'rgba(74,50,24,0.45)' : UI.ink, cursor: wrong ? 'default' : 'pointer',
          background: wrong ? 'rgba(74,50,24,0.07)' : 'linear-gradient(180deg, #fffaef, #f4e6c4)',
          border: `1.5px solid ${wrong ? 'rgba(122,82,48,0.25)' : UI.gold}`,
          boxShadow: wrong ? 'none' : 'inset 0 1px 2px rgba(255,255,255,0.7), 0 2px 5px rgba(30,18,6,0.2)',
          animation: state.lastWrong === i ? 'tbShake 0.35s' : 'none',
        },
        onClick: wrong ? null : () => {
          if (i === q.correctIndex) {
            sfx.correct();
            const res = settleSection(flat);
            state = { screen: 'result', flat, res };
            // Lightfound rule (Ch. 5.7): the jingle plays only for real gains.
            if (res.xp || res.fruit) sfx.fanfare('small');
            render();
          } else {
            sfx.wrong();
            state.wrong.add(i);
            state.tries++;
            state.lastWrong = i;
            render();
            setTimeout(() => { if (state && state.screen === 'question') { state.lastWrong = null; render(); } }, 380);
          }
        },
      }, choice));
    });

    if (state.tries > 0) {
      body.append(el('div', { style: { textAlign: 'center', fontSize: '12px', color: UI.amber, fontStyle: 'italic', margin: '10px 0 2px', animation: 'tbFadeUp 0.25s' } },
        state.tries >= 2 ? `Look again — the answer is hiding near ${q.answerRef}.` : 'Hmm, not quite — look again. No rush, the page isn’t going anywhere.'));
    }
    body.append(el('div', { style: { textAlign: 'center', marginTop: '10px' } },
      button('◂ Back to the page', { kind: 'plain', small: true }, () => { sfx.click(); gotoSection(s.id); render(); })));
  }

  // --- 4b. Memory-verse challenge ------------------------------------------
  // Fetches the ESV text at runtime and tokenizes it into tap-the-missing-
  // words blanks. Passing mints the verse as a Truth Serum (Ch. 2.3 / 3.10).
  function startMemory(flat) {
    const mv = flat.section.memoryVerse;
    state = { screen: 'memory', flat, phase: 'loading', practice: !!progress.mvPassed[mv.id] };
    render();
    const seq = ++loadSeq;
    passages.get(mv.reference).then((res) => {
      if (seq !== loadSeq || !state || state.screen !== 'memory') return;
      if (res && res.text && !res.error) {
        const tokens = tokenizePassageForBlanks(res.text);
        if (tokens.length < TOWNBOOK_TUNING.blanksMin + 1) { state.phase = 'degraded'; render(); return; }
        const blanks = pickBlankIndices(tokens, mv.reference, tuning);
        const rng = mulberry32(hashStr(mv.reference + '|bank'));
        const answers = blanks.map((bi) => tokens[bi]);
        const tokenCleans = new Set(tokens.map((t) => t.clean));
        const decoys = shuffled(DECOY_POOL.filter((w) => !tokenCleans.has(w)), rng).slice(0, tuning.decoyCount);
        const bank = shuffled(
          [...answers.map((t) => ({ word: t.display, clean: t.clean, used: false })),
           ...decoys.map((w) => ({ word: w, clean: w, used: false }))],
          rng
        );
        Object.assign(state, {
          phase: 'play', passageData: res, tokens, blanks,
          slots: blanks.map(() => null), // bank index or null
          bank, checked: false,
        });
      } else state.phase = 'degraded';
      render();
    });
  }

  function renderMemory() {
    const { flat } = state;
    const s = flat.section;
    const mv = s.memoryVerse;
    const fam = VERSE_FAMILIES[mv.serum.counterFamily];
    const lieFam = LIE_FAMILIES[mv.serum.lieFamily];

    body.append(ribbon(state.practice ? 'MEMORY VERSE · PRACTICE' : 'HIDE IT IN YOUR HEART'));
    body.append(el('div', { style: { textAlign: 'center', marginBottom: '10px' } },
      el('span', {
        style: {
          display: 'inline-block', fontSize: '12px', fontWeight: '800', color: UI.amber,
          border: `1px solid ${UI.gold}`, borderRadius: '999px', padding: '3px 14px', background: 'rgba(255,247,226,0.85)',
        },
      }, mv.reference),
      !state.practice && el('div', { style: { fontSize: '11px', color: UI.inkSoft, marginTop: '5px' } },
        `Pass it to mint a ${fam.label} Truth Serum — it counters ${lieFam.label} lies.`)));

    if (mv.audioUrl) {
      body.append(el('div', { style: { textAlign: 'center', marginBottom: '10px' } },
        button(narrator.playing ? '■ Stop' : '🔊 Hear the verse', { kind: 'plain', small: true }, () => {
          sfx.click();
          if (narrator.playing) narrator.stop();
          else narrator.play([mv.audioUrl], parseInt((mv.reference.split(':')[1] || '1'), 10) || 1);
        })));
    }

    if (state.phase === 'loading') {
      body.append(el('div', { style: { display: 'flex', alignItems: 'center', gap: '10px', justifyContent: 'center', padding: '26px 0', color: UI.inkSoft } },
        el('span', { style: { width: '18px', height: '18px', border: '3px solid rgba(176,122,40,0.25)', borderTopColor: UI.amber, borderRadius: '50%', animation: 'tbSpin 0.9s linear infinite' } }),
        el('span', { style: { fontSize: '13px', fontStyle: 'italic' } }, `Fetching ${mv.reference}…`)));
      return;
    }

    if (state.phase === 'degraded') {
      // Graceful degraded mode: no fetched text means no blanks to build.
      // The section can still be finished from the retelling; the challenge
      // stays waiting on the chapter list ("challenge waiting" badge).
      body.append(el('div', {
        style: {
          borderRadius: '11px', border: `1px solid ${UI.amber}`, background: 'rgba(255,184,69,0.14)',
          padding: '11px 13px', margin: '0 4px 10px', fontSize: '12.5px', color: UI.ink, lineHeight: '1.55', animation: 'tbFadeUp 0.25s',
        },
      },
        el('b', { style: { color: UI.amber } }, '🕯 The verse text isn’t available right now. '),
        `The memory-verse challenge needs the ${book.meta.translation.id} words themselves, so it will wait for you here. Read ${mv.reference} in Maribel’s retelling and come back soon.`));
      body.append(el('div', {
        style: { fontSize: '13px', lineHeight: '1.65', color: UI.inkSoft, fontStyle: 'italic', borderLeft: `3px solid ${UI.gold}`, padding: '4px 10px', margin: '0 8px 14px' },
      }, s.retelling));
      body.append(el('div', { style: { display: 'flex', gap: '8px', justifyContent: 'center', flexWrap: 'wrap' } },
        button('Retry fetch', { small: true }, () => { sfx.click(); startMemory(flat); }),
        !progress.completed[s.id]
          ? button('Mark read — challenge later', { kind: 'green', small: true }, () => {
            sfx.click();
            const res = settleSection(flat); // section pay only; serum stays pending
            state = { screen: 'result', flat, res, mvDeferred: true };
            if (res.xp || res.fruit) sfx.fanfare('small');
            render();
          })
          : button('◂ Back to chapters', { kind: 'plain', small: true }, () => { sfx.click(); state = { screen: 'chapters' }; render(); })));
      return;
    }

    // --- play phase: the verse with tap-to-fill blanks ---
    const blankSet = new Set(state.blanks);
    const verseBox = el('div', {
      style: {
        borderRadius: '12px', border: `1.5px solid ${UI.gold}`, background: 'rgba(255,250,238,0.92)',
        boxShadow: 'inset 0 1px 4px rgba(122,82,48,0.18)', padding: '14px 15px', margin: '0 2px 12px',
        fontFamily: 'Georgia, serif', fontSize: '16px', lineHeight: '2.05', color: UI.ink, textAlign: 'left',
      },
    });
    state.tokens.forEach((t) => {
      if (t.prefix) verseBox.append(t.prefix);
      if (blankSet.has(t.idx)) {
        const slotIdx = state.blanks.indexOf(t.idx);
        const bankIdx = state.slots[slotIdx];
        const filled = bankIdx != null;
        const wrongNow = state.checked && filled && state.bank[bankIdx].clean !== t.clean;
        verseBox.append(el('span', {
          style: {
            display: 'inline-block', minWidth: `${Math.max(3, t.clean.length) * 9}px`, textAlign: 'center',
            margin: '0 2px', padding: '1px 8px', borderRadius: '8px', fontFamily: UI.font,
            fontSize: '13.5px', fontWeight: '800', verticalAlign: 'baseline',
            cursor: filled ? 'pointer' : 'default',
            color: filled ? (wrongNow ? '#a33517' : UI.ink) : 'transparent',
            background: filled ? (wrongNow ? 'rgba(214,80,40,0.16)' : 'rgba(255,200,94,0.4)') : 'rgba(74,50,24,0.08)',
            border: `1.5px ${filled ? 'solid' : 'dashed'} ${wrongNow ? '#c26a3a' : UI.gold}`,
            animation: wrongNow ? 'tbShake 0.35s' : 'none',
          },
          onClick: filled ? () => { // tap a filled blank to put the word back
            sfx.click();
            state.bank[bankIdx].used = false;
            state.slots[slotIdx] = null;
            state.checked = false;
            render();
          } : null,
        }, filled ? state.bank[bankIdx].word : '•••'));
      } else {
        verseBox.append(t.display);
      }
      verseBox.append((t.suffix || '') + ' ');
    });
    const d = state.passageData;
    verseBox.append(el('div', { style: { fontSize: '10px', color: UI.inkSoft, textAlign: 'right', marginTop: '8px', fontFamily: UI.font } },
      d.copyright || (d.translation ? `(${d.translation})` : '(ESV)')));
    body.append(verseBox);

    // Word bank.
    body.append(el('div', { style: { fontSize: '10px', letterSpacing: '1.5px', color: UI.inkSoft, textAlign: 'center', marginBottom: '6px' } },
      'TAP THE MISSING WORDS'));
    const bankRow = el('div', { style: { display: 'flex', flexWrap: 'wrap', gap: '7px', justifyContent: 'center', margin: '0 4px 12px' } });
    state.bank.forEach((chip, bi) => {
      bankRow.append(el('span', {
        style: {
          padding: '7px 13px', borderRadius: '999px', fontSize: '13.5px', fontWeight: '800',
          color: chip.used ? 'rgba(74,50,24,0.3)' : UI.ink,
          background: chip.used ? 'rgba(74,50,24,0.06)' : 'linear-gradient(180deg, #fffaef, #f2dfb2)',
          border: `1.5px solid ${chip.used ? 'rgba(122,82,48,0.2)' : UI.gold}`,
          boxShadow: chip.used ? 'none' : 'inset 0 1px 2px rgba(255,255,255,0.7), 0 2px 5px rgba(30,18,6,0.25)',
          cursor: chip.used ? 'default' : 'pointer',
        },
        onClick: chip.used ? null : () => {
          const slotIdx = state.slots.indexOf(null);
          if (slotIdx === -1) return;
          sfx.click();
          chip.used = true;
          state.slots[slotIdx] = bi;
          state.checked = false;
          render();
        },
      }, chip.word));
    });
    body.append(bankRow);

    const allFilled = state.slots.every((v) => v != null);
    body.append(el('div', { style: { display: 'flex', gap: '8px', justifyContent: 'center', alignItems: 'center', flexWrap: 'wrap' } },
      button('◂ Back', { kind: 'plain', small: true }, () => { sfx.click(); narrator.stop(); gotoSection(s.id); render(); }),
      button('Check', { kind: 'green', disabled: !allFilled }, () => {
        const wrong = [];
        state.blanks.forEach((tokenIdx, slotIdx) => {
          const chip = state.bank[state.slots[slotIdx]];
          if (chip.clean !== state.tokens[tokenIdx].clean) wrong.push(slotIdx);
        });
        if (!wrong.length) {
          sfx.correct();
          if (state.practice) {
            toast('✨ Word-perfect. Already minted — practice makes it yours.');
            state = { screen: 'chapters' }; render();
          } else {
            const res = settleSection(flat, { mvJustPassed: true });
            state = { screen: 'result', flat, res };
            sfx.fanfare('full'); // the Lightfound fanfare — a serum is a milestone earn
            render();
          }
        } else {
          // Warm retry: wrong chips shake, then float back to the bank.
          sfx.wrong();
          state.checked = true;
          render();
          setTimeout(() => {
            if (!state || state.screen !== 'memory' || state.phase !== 'play') return;
            for (const slotIdx of wrong) {
              const bi = state.slots[slotIdx];
              if (bi != null) { state.bank[bi].used = false; state.slots[slotIdx] = null; }
            }
            state.checked = false;
            toast('So close — listen once more and try again.');
            render();
          }, 650);
        }
      })));
  }

  // --- 5. Result / payout card ---------------------------------------------
  function renderResult() {
    const { flat, res, mvDeferred } = state;
    const s = flat.section;
    const mv = s.memoryVerse;
    body.append(el('div', { style: { textAlign: 'center', padding: '6px 0 2px', animation: 'tbPop 0.25s' } },
      el('div', { style: { fontSize: '40px', lineHeight: '1' } }, res.serum ? '💎' : '✨'),
      el('div', { style: { fontFamily: 'Georgia, serif', fontSize: '20px', fontWeight: '700', color: UI.ink, margin: '6px 0 2px' } },
        res.serum ? 'Truth Serum minted!' : res.alreadyDone && !res.xp ? 'Studied again' : 'Section complete!'),
      el('div', { style: { fontSize: '11.5px', color: UI.inkSoft } }, `${s.title} · ${s.reference}`)));

    const gains = el('div', { style: { display: 'flex', gap: '9px', justifyContent: 'center', flexWrap: 'wrap', margin: '14px 0' } });
    const gainChip = (icon, label) => el('div', {
      style: {
        display: 'flex', alignItems: 'center', gap: '7px', padding: '8px 15px', borderRadius: '11px',
        background: 'linear-gradient(180deg, #fffaef, #f2dfb2)', border: `1.5px solid ${UI.gold}`,
        fontWeight: '800', fontSize: '14px', color: UI.ink, animation: 'tbFadeUp 0.3s',
        boxShadow: 'inset 0 1px 2px rgba(255,255,255,0.7), 0 3px 7px rgba(30,18,6,0.3)',
      },
    }, el('span', { style: { fontSize: '17px' } }, icon), label);
    if (res.xp) gains.append(gainChip('✨', `+${res.xp} XP`));
    if (res.fruit) gains.append(gainChip('🍓', `+${res.fruit} fruit`));
    if (res.serum) {
      const fam = VERSE_FAMILIES[res.serum.family];
      const lf = LIE_FAMILIES[res.serum.lieFamily];
      gains.append(el('div', {
        style: {
          width: '100%', maxWidth: '330px', margin: '2px auto 0', padding: '11px 14px', borderRadius: '13px',
          background: UI.parchmentDeep, border: `2px solid ${lf.color}`, animation: 'tbGlow 2.5s infinite',
          textAlign: 'center',
        },
      },
        el('div', { style: { fontSize: '13px', fontWeight: '800', color: UI.ink } }, `${res.serum.ref} · ${fam.label} serum`),
        el('div', { style: { fontSize: '10.5px', color: UI.inkSoft, marginTop: '3px' } },
          `Counters ${lf.label} lies — it’s waiting in your Verse Satchel.`)));
    }
    if (!res.xp && !res.fruit && !res.serum) {
      gains.append(el('div', { style: { fontSize: '12px', color: UI.inkSoft, fontStyle: 'italic' } },
        res.alreadyDone ? 'Already studied — the reward was yours the first time.' : ''));
    }
    body.append(gains);

    if (res.capped) {
      body.append(el('div', { style: { textAlign: 'center', fontSize: '11.5px', color: UI.amber, fontStyle: 'italic', margin: '0 12px 10px' } },
        '🕯 The desk lamp dims — three rewarded studies a day. Your progress is saved; rewards return tomorrow.'));
    }
    if (mvDeferred && mv) {
      body.append(el('div', { style: { textAlign: 'center', fontSize: '11.5px', color: UI.amber, fontStyle: 'italic', margin: '0 12px 10px' } },
        `💎 The ${mv.reference} challenge is waiting on the chapter list whenever the text returns.`));
    }
    body.append(el('div', { style: { textAlign: 'center', marginTop: '6px' } },
      button('Continue', { kind: 'green' }, () => { sfx.pageTurn(); state = { screen: 'chapters' }; render(); })));
  }

  // ---------------------------------------------------------------------------
  // Public controller
  // ---------------------------------------------------------------------------
  const controller = {
    open,
    close,
    isOpen: () => !!root,
    /** Read-only progress summary (for the shelf spine / historian flex). */
    getProgress() {
      const done = FLAT.filter((f) => progress.completed[f.section.id]).length;
      return {
        bookId: book.meta.bookId,
        sectionsCompleted: done,
        sectionsTotal: FLAT.length,
        serumsMinted: Object.keys(progress.mvPassed).length,
        rewardedToday: rewardedToday(),
        dailyCap: tuning.dailySectionCap,
        finishedSlice: done === FLAT.length,
      };
    },
    dispose() { close(); narrator.dispose(); },
  };
  if (IS_DEV) {
    controller.dev = {
      forceMock(v) { devFlags.forceMock = !!v; passages.clear(); },
      forceUnavailable(v) { devFlags.forceUnavailable = !!v; },
      async resetProgress() {
        progress = { v: 1, bookId: book.meta.bookId, completed: {}, mvPassed: {}, daily: { day: dayKey(), count: 0 }, lastSectionId: null };
        saveProgress();
      },
      state: () => JSON.parse(JSON.stringify(progress)),
    };
  }
  return controller;
}

export default createTownBook;
