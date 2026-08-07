// =============================================================================
// glowlands/audio-motifs.js
// Generative WebAudio motifs for the Phase 1 gateway slice.
//
// Design authority: /docs/glowlands-design.md
//   Ch. 5.7  — audio direction, Truth & Light stingers, THE LIGHTFOUND FANFARE
//              (global rule: one jingle, everywhere, always the same melody;
//              variants exist only in weight — 0.8 s pickup / 1.5 s full)
//   Ch. 7 §8 — Meadow Town's "The Open Door" motif (four-bar rising ukulele
//              figure that answers itself on whistle; pre-save mix drops the
//              whistle and detunes 15 cents, post-save adds a second voice)
//   Roads    — the East Road travel bed (acoustic folk, walk-tempo, the map is
//              navigable by ear)
//   Ch. 2.1  — encounter flow (aggro duck −6 dB), tone rule: tension from
//              rhythm, not dissonance
//
// ENGINE STYLE: mirrors the synth vocabulary of dragon-garden-quest.jsx
// (tone / noiseBurst / pluck-style envelopes on plain oscillators, everything
// scheduled against AudioContext.currentTime, exponential decays, per-call
// throwaway nodes). No samples, no assets, zero bytes of audio shipped.
//
// WIRING (Wire phase only — this module NEVER touches the host file):
// The host game owns the single AudioContext and its unlock lifecycle
// (initAudio() + pointerdown/pointerup/keydown -> unlockAudio -> AC.resume()).
// Inside the host's initAudio(), after the buses exist, the Wire phase calls:
//
//     initGlowlandsAudio({
//       ctx:      AC,          // the host AudioContext
//       sfxBus:   sfxBus,      // host SFX gain bus (jingles, stingers)
//       musicBus: musicBus,    // host music gain bus (motifs; ducking target)
//       isMuted:  () => AUDIO.muted,
//     });
//
// Every play function is a safe no-op until then (and while muted) — exactly
// like the host's own `sq()` guard — so glowlands UI code may call these
// unconditionally. This module never constructs an AudioContext and never
// attaches listeners: the host's unlock pattern stays the single authority.
//
// SCRIPTURE RULE: no verse text lives here (nothing to embed — it's audio).
// =============================================================================

// -----------------------------------------------------------------------------
// Injected environment (Wire phase)
// -----------------------------------------------------------------------------
let ENV = null; // { ctx, sfxBus, musicBus, isMuted }

/**
 * Wire-phase hookup. Idempotent; last call wins (lets a future re-init after
 * an iOS context loss re-point the buses).
 */
export function initGlowlandsAudio({ ctx, sfxBus, musicBus = null, isMuted = () => false }) {
  if (!ctx || !sfxBus) return false;
  ENV = { ctx, sfxBus, musicBus: musicBus || sfxBus, isMuted };
  return true;
}

export function isGlowlandsAudioReady() {
  return !!(ENV && ENV.ctx);
}

// Guard mirroring the host's `sq()`: run fn(now + eps) only when live + audible.
function live() {
  if (!ENV || !ENV.ctx || ENV.isMuted()) return null;
  if (ENV.ctx.state === "suspended") return null; // unlock is the host's job
  return ENV.ctx;
}

// -----------------------------------------------------------------------------
// Synth vocabulary (same family as the host's tone()/noiseBurst()/pianoNote())
// All take an explicit start time t (seconds, AudioContext clock) and route to
// an explicit bus so motifs can sit on music while stingers sit on sfx.
// -----------------------------------------------------------------------------

// Generic enveloped oscillator — the host's tone(), bus-parameterized.
function tone(ac, bus, freq, t, dur, vol, type = "triangle", slideTo = null, lp = null) {
  const o = ac.createOscillator();
  o.type = type;
  o.frequency.setValueAtTime(freq, t);
  if (slideTo) o.frequency.exponentialRampToValueAtTime(Math.max(20, slideTo), t + dur);
  const g = ac.createGain();
  g.gain.setValueAtTime(0.0001, t);
  g.gain.exponentialRampToValueAtTime(vol, t + 0.015);
  g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  let last = o;
  if (lp) {
    const f = ac.createBiquadFilter();
    f.type = "lowpass";
    f.frequency.value = lp;
    o.connect(f);
    last = f;
  }
  last.connect(g);
  g.connect(bus);
  o.start(t);
  o.stop(t + dur + 0.05);
}

// Filtered noise burst — the host's noiseBurst(), bus-parameterized.
function noiseBurst(ac, bus, t, dur, vol, freq = 800, q = 1, ftype = "bandpass", freqEnd = null) {
  const b = ac.createBuffer(1, Math.max(1, Math.floor(ac.sampleRate * dur)), ac.sampleRate);
  const dd = b.getChannelData(0);
  for (let i = 0; i < dd.length; i++) dd[i] = Math.random() * 2 - 1;
  const src = ac.createBufferSource();
  src.buffer = b;
  const f = ac.createBiquadFilter();
  f.type = ftype;
  f.frequency.setValueAtTime(freq, t);
  f.Q.value = q;
  if (freqEnd) f.frequency.exponentialRampToValueAtTime(freqEnd, t + dur);
  const g = ac.createGain();
  g.gain.setValueAtTime(vol, t);
  g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  src.connect(f);
  f.connect(g);
  g.connect(bus);
  src.start(t);
  src.stop(t + dur);
}

// Bell: fundamental + one inharmonic partial (2.76x, classic bell shimmer),
// fast attack, long exponential ring.
function bell(ac, bus, freq, t, dur = 1.0, vol = 0.14, detuneCents = 0) {
  [[1, 1, "sine"], [2.76, 0.28, "sine"]].forEach(([mult, vm, type]) => {
    const o = ac.createOscillator();
    o.type = type;
    o.frequency.value = freq * mult;
    o.detune.value = detuneCents;
    const g = ac.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(vol * vm, t + 0.012);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    o.connect(g);
    g.connect(bus);
    o.start(t);
    o.stop(t + dur + 0.05);
  });
}

// Plucked string (ukulele / guitar): triangle with a lowpass that sweeps shut
// fast — the pianoNote() trick tightened to a pluck.
function pluck(ac, bus, freq, t, dur = 0.5, vol = 0.16, detuneCents = 0, brightness = 3200) {
  const o = ac.createOscillator();
  o.type = "triangle";
  o.frequency.value = freq;
  o.detune.value = detuneCents;
  const f = ac.createBiquadFilter();
  f.type = "lowpass";
  f.frequency.setValueAtTime(brightness, t);
  f.frequency.exponentialRampToValueAtTime(Math.max(300, freq * 1.2), t + dur);
  const g = ac.createGain();
  g.gain.setValueAtTime(0.0001, t);
  g.gain.exponentialRampToValueAtTime(vol, t + 0.008); // near-instant attack = pluck
  g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  o.connect(f);
  f.connect(g);
  g.connect(bus);
  o.start(t);
  o.stop(t + dur + 0.05);
}

// Whistle: soft-attack sine with gentle LFO vibrato — Meadow Town's answer voice.
function whistle(ac, bus, freq, t, dur = 0.6, vol = 0.09, detuneCents = 0) {
  const o = ac.createOscillator();
  o.type = "sine";
  o.frequency.value = freq;
  o.detune.value = detuneCents;
  const lfo = ac.createOscillator();
  lfo.type = "sine";
  lfo.frequency.value = 5.5;
  const lfoGain = ac.createGain();
  lfoGain.gain.value = freq * 0.006; // ~10 cents of vibrato
  lfo.connect(lfoGain);
  lfoGain.connect(o.frequency);
  const g = ac.createGain();
  g.gain.setValueAtTime(0.0001, t);
  g.gain.linearRampToValueAtTime(vol, t + 0.08); // breathy ease-in, not a pluck
  g.gain.setValueAtTime(vol, t + Math.max(0.09, dur - 0.15));
  g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  o.connect(g);
  g.connect(bus);
  lfo.start(t);
  o.start(t);
  o.stop(t + dur + 0.05);
  lfo.stop(t + dur + 0.05);
}

// Brushed hand drum: lowpass thump + tiny skin noise.
function handDrum(ac, bus, t, vol = 0.12, pitch = 120) {
  tone(ac, bus, pitch, t, 0.09, vol, "sine", pitch * 0.55);
  noiseBurst(ac, bus, t, 0.05, vol * 0.5, 900, 0.8, "lowpass");
}

// Soft shaker: short high noise, offbeat spice for the travel bed.
function shaker(ac, bus, t, vol = 0.05) {
  noiseBurst(ac, bus, t, 0.05, vol, 5200, 1.6, "highpass");
}

// -----------------------------------------------------------------------------
// Melodic material (frequencies in Hz, equal temperament)
// -----------------------------------------------------------------------------
const N = {
  C3: 130.81, D3: 146.83, E3: 164.81, F3: 174.61, G3: 196.0, A3: 220.0, Bb3: 233.08, B3: 246.94,
  C4: 261.63, D4: 293.66, E4: 329.63, F4: 349.23, G4: 392.0, A4: 440.0, Bb4: 466.16, B4: 493.88,
  C5: 523.25, D5: 587.33, E5: 659.25, F5: 698.46, G5: 783.99, A5: 880.0, B5: 987.77,
  C6: 1046.5, D6: 1174.66, E6: 1318.51, G6: 1567.98,
};

/**
 * The lantern leitmotif (Ch. 5.7 / Ch. 16 "The Everlight"): the melody that
 * hides inside every town motif and the fanfare's resolving interval. Its
 * FIRST INTERVAL — the rising perfect fifth C→G — is the game's "light" sound.
 * Exported so later phases (town motifs, streak-up moments, the Everlight
 * statement) quote from one canonical source instead of re-deriving it.
 */
export const LANTERN_LEITMOTIF = Object.freeze([N.C5, N.G5, N.E5, N.D5, N.C5]);

/**
 * "The Open Door" — Meadow Town's calling card (Ch. 7 §8): a four-bar rising
 * ukulele figure that answers itself on whistle. Exported as data (beat, freq)
 * so future variations can QUOTE it — the design bible has Brightharbor's
 * ferry horn state this exact melody at the finale (Ch. 15 §8).
 * Beats are in quarter-notes at the motif's own tempo.
 */
export const OPEN_DOOR_LEAD = Object.freeze([
  // bar 1 — the door creaks open (rising from the tonic)
  { beat: 0.0, f: N.F4 }, { beat: 0.5, f: N.A4 }, { beat: 1.0, f: N.C5 },
  // bar 2 — a step through
  { beat: 2.0, f: N.D5 }, { beat: 2.5, f: N.C5 }, { beat: 3.0, f: N.A4 },
  // bar 3 — rising again, higher
  { beat: 4.0, f: N.C5 }, { beat: 4.5, f: N.D5 }, { beat: 5.0, f: N.F5 },
  // bar 4 — landing home, open-ended (invites the answer)
  { beat: 6.0, f: N.G5 }, { beat: 7.0, f: N.A5 },
]);

/** The whistle answer: echoes the rise and settles it back to the tonic. */
export const OPEN_DOOR_ANSWER = Object.freeze([
  { beat: 8.0, f: N.A5 }, { beat: 8.75, f: N.G5 }, { beat: 9.5, f: N.F5 },
  { beat: 10.5, f: N.C5 }, { beat: 11.5, f: N.F5 },
]);

/**
 * East Road travel motif — walk-tempo acoustic folk (Roads interlude / Ch. 5.7
 * "saved towns / garden" palette carried onto the road). G mixolydian: bright
 * but road-worn — the flat seventh keeps it "going somewhere" rather than
 * "home". Alternating thumb-bass under a stepping melody.
 */
export const EAST_ROAD_MOTIF = Object.freeze([
  { beat: 0.0, f: N.G4 }, { beat: 0.5, f: N.B4 }, { beat: 1.0, f: N.D5 },
  { beat: 1.5, f: N.E5 }, { beat: 2.0, f: N.D5 }, { beat: 2.5, f: N.B4 },
  { beat: 3.0, f: N.A4 }, { beat: 3.5, f: N.F5 * 0.5 /* F4 — the mixolydian b7 */ },
  { beat: 4.0, f: N.G4 },
]);

// -----------------------------------------------------------------------------
// 1) THE LIGHTFOUND FANFARE (Ch. 5.7 — global rule)
// -----------------------------------------------------------------------------
// A bright ascending figure on bells + plucked strings resolving to the
// lantern leitmotif's first interval (C→G). ONE melody, always. The only
// permitted variant is weight: 'full' (~1.5 s, milestones) vs 'pickup'
// (~0.8 s, small pickups) — same notes, tighter spacing, lighter dressing.
//
// CALLER CONTRACT (bible, LOCKED): play this on every real earn event, and
// NEVER for anything the player did not actually gain.

const FANFARE_RISE = [N.C5, N.E5, N.G5, N.A5]; // bright climb...
const FANFARE_RESOLVE = [N.C6, N.G6];          // ...resolving on the lantern fifth

/**
 * @param {{weight?: 'full'|'pickup'}} [opts]
 */
export function playLightfoundFanfare(opts = {}) {
  const ac = live();
  if (!ac) return;
  const bus = ENV.sfxBus;
  const full = (opts.weight || "full") !== "pickup";
  const t0 = ac.currentTime + 0.02;
  const step = full ? 0.11 : 0.062; // same melody, only the weight changes

  // The climb: pluck + bell doubled (plucked strings and bells, per the bible).
  FANFARE_RISE.forEach((f, i) => {
    const t = t0 + i * step;
    pluck(ac, bus, f, t, full ? 0.34 : 0.2, full ? 0.15 : 0.12);
    bell(ac, bus, f, t + 0.005, full ? 0.5 : 0.28, full ? 0.09 : 0.06);
  });

  // The resolve: the lantern leitmotif's first interval, stated on bells.
  const tr = t0 + FANFARE_RISE.length * step + (full ? 0.04 : 0.0);
  bell(ac, bus, FANFARE_RESOLVE[0], tr, full ? 0.7 : 0.34, full ? 0.13 : 0.09);
  bell(ac, bus, FANFARE_RESOLVE[1], tr + (full ? 0.16 : 0.1), full ? 0.95 : 0.42, full ? 0.15 : 0.1);
  pluck(ac, bus, FANFARE_RESOLVE[1] / 2, tr + (full ? 0.16 : 0.1), full ? 0.5 : 0.26, 0.1); // G5 string under the top bell

  if (full) {
    // Milestone dressing only — a soft light-bloom shimmer over the resolve.
    tone(ac, bus, N.G6, tr + 0.3, 0.55, 0.05, "sine", N.G6 * 1.5);
    noiseBurst(ac, bus, tr + 0.22, 0.3, 0.045, 6000, 1.2, "highpass");
  }
}

// -----------------------------------------------------------------------------
// 2) "THE OPEN DOOR" — Meadow Town motif + variation hook (Ch. 7 §8)
// -----------------------------------------------------------------------------
// Four-bar rising ukulele figure answered on whistle.
//   Pre-save mix: whistle answer dropped, everything detuned 15 cents (tunable
//   in the bible; the ear feels the town's un-savedness before the eye does).
//   Post-save: a second ukulele voice joins in parallel thirds.
//
// The options object IS the variation hook: later content (the ferry horn at
// Brightharbor, trailer beds, save-wave moments) re-voices the same exported
// melody by passing transpose/instrument/segment overrides instead of ever
// writing a second copy of the tune.

/**
 * @param {{
 *   saved?: boolean,            // default true; false = pre-save hollowed mix
 *   transposeSemitones?: number,// quote the melody in another key (ferry horn etc.)
 *   detuneCents?: number,       // override; default -15 when !saved, else 0
 *   tempoBpm?: number,          // default 96
 *   leadInstrument?: 'pluck'|'whistle'|'bell', // re-voicing hook (default pluck)
 *   includeAnswer?: boolean,    // override the saved-state default
 *   secondVoice?: boolean,      // override the saved-state default
 * }} [opts]
 * @returns {number} total motif duration in seconds (callers can chain/stage on it)
 */
export function playOpenDoorMotif(opts = {}) {
  const ac = live();
  if (!ac) return 0;
  const bus = ENV.musicBus;
  const saved = opts.saved !== false;
  const detune = opts.detuneCents != null ? opts.detuneCents : (saved ? 0 : -15);
  const semis = opts.transposeSemitones || 0;
  const mult = Math.pow(2, semis / 12);
  const beatSec = 60 / (opts.tempoBpm || 96);
  const withAnswer = opts.includeAnswer != null ? opts.includeAnswer : saved;
  const withSecond = opts.secondVoice != null ? opts.secondVoice : saved;
  const voices = { pluck, whistle, bell };
  const lead = voices[opts.leadInstrument] || pluck;
  const t0 = ac.currentTime + 0.03;

  OPEN_DOOR_LEAD.forEach(({ beat, f }) => {
    const t = t0 + beat * beatSec;
    lead(ac, bus, f * mult, t, beatSec * 0.95, 0.15, detune);
    if (withSecond) lead(ac, bus, f * mult * Math.pow(2, 4 / 12), t + 0.015, beatSec * 0.8, 0.07, detune); // parallel third above
  });
  let endBeat = 8;
  if (withAnswer) {
    OPEN_DOOR_ANSWER.forEach(({ beat, f }) => {
      whistle(ac, bus, f * mult, t0 + beat * beatSec, beatSec * 1.05, 0.085, detune);
    });
    endBeat = 12.5;
  }
  // Brushed hand drum heartbeat under the figure (both mixes — it's the town's pulse).
  for (let b = 0; b < endBeat; b += 2) handDrum(ac, bus, t0 + b * beatSec, saved ? 0.07 : 0.05);

  return endBeat * beatSec;
}

// -----------------------------------------------------------------------------
// 3) EAST ROAD travel motif (Roads interlude)
// -----------------------------------------------------------------------------
// One-shot walking phrase, plus a light loop scheduler in the style of the
// host's startMusic() timer chain (phrase → breathing rest → phrase). The loop
// is intentionally sparse: the road is navigable by ear, not wall-to-wall.

/**
 * Play one pass of the East Road walking phrase.
 * @param {{tempoBpm?: number, transposeSemitones?: number}} [opts]
 * @returns {number} phrase duration in seconds
 */
export function playEastRoadMotif(opts = {}) {
  const ac = live();
  if (!ac) return 0;
  const bus = ENV.musicBus;
  const beatSec = 60 / (opts.tempoBpm || 100); // walk tempo
  const mult = Math.pow(2, (opts.transposeSemitones || 0) / 12);
  const t0 = ac.currentTime + 0.03;

  // Stepping melody on guitar-pluck.
  EAST_ROAD_MOTIF.forEach(({ beat, f }) => {
    pluck(ac, bus, f * mult, t0 + beat * beatSec, beatSec * 0.9, 0.13, 0, 2600);
  });
  // Alternating thumb-bass (G2 / D3) — the footsteps of the tune.
  for (let b = 0; b <= 4; b++) {
    pluck(ac, bus, (b % 2 === 0 ? N.G3 / 2 : N.D3) * mult, t0 + b * beatSec, beatSec * 0.95, 0.1, 0, 900);
  }
  // Shaker on the offbeats.
  for (let b = 0.5; b < 4.5; b += 1) shaker(ac, bus, t0 + b * beatSec);

  return 4.5 * beatSec;
}

let eastRoadTimer = null;

/**
 * Start the sparse East Road travel loop (idempotent). Mirrors the host's
 * startMusic() setTimeout-chain pattern; checks mute each cycle. The Wire
 * phase should stop this on zone exit and MUST stop it in the host's cleanup.
 */
export function startEastRoadTravelLoop() {
  if (eastRoadTimer) return;
  const cycle = () => {
    let phraseSec = 0;
    if (live()) phraseSec = playEastRoadMotif();
    // Breathing room between phrases: the road has air in it.
    const restMs = 2500 + Math.random() * 4000;
    eastRoadTimer = setTimeout(cycle, phraseSec * 1000 + restMs);
  };
  cycle();
}

export function stopEastRoadTravelLoop() {
  if (eastRoadTimer) {
    clearTimeout(eastRoadTimer);
    eastRoadTimer = null;
  }
}

// -----------------------------------------------------------------------------
// 4) BATTLE STINGS (Ch. 2.1 encounter flow, Ch. 5.7 stinger spec)
// -----------------------------------------------------------------------------
// Tone rule (LOCKED): tension from rhythm, not dissonance. Nothing here is
// scary-dissonant; the encounter sting is a pulse, not a scream.

/**
 * Encounter-start sting: a Gloomling has noticed the player. Double low-drum
 * hit + a held open fifth with a slow swell — urgency without dissonance —
 * and a breathy rising wash (the whisper arriving). ~1 s.
 * The Wire phase should pair this with duckAmbient(-6, ...) per Ch. 2.1.
 */
export function playEncounterSting() {
  const ac = live();
  if (!ac) return;
  const bus = ENV.sfxBus;
  const t0 = ac.currentTime + 0.02;
  handDrum(ac, bus, t0, 0.16, 95);
  handDrum(ac, bus, t0 + 0.16, 0.14, 95);
  // Open fifth (D3 + A3) — tense but consonant, swelling then gone.
  [N.D3, N.A3].forEach((f) => {
    const o = ac.createOscillator();
    o.type = "triangle";
    o.frequency.value = f;
    const g = ac.createGain();
    g.gain.setValueAtTime(0.0001, t0 + 0.1);
    g.gain.linearRampToValueAtTime(0.09, t0 + 0.45);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + 1.0);
    const flt = ac.createBiquadFilter();
    flt.type = "lowpass";
    flt.frequency.value = 1200;
    o.connect(flt);
    flt.connect(g);
    g.connect(bus);
    o.start(t0 + 0.1);
    o.stop(t0 + 1.05);
  });
  // The whisper wash: breathy noise rising in pitch, never intelligible (LOCKED).
  noiseBurst(ac, bus, t0 + 0.1, 0.7, 0.06, 500, 0.7, "bandpass", 2200);
}

/**
 * Right verse (Ch. 5.7): a rising major-third bell flourish. Sits under the
 * Lightburst; deliberately smaller than the Lightfound fanfare — countering
 * a lie is not an earn event.
 */
export function playVerseStingRight() {
  const ac = live();
  if (!ac) return;
  const bus = ENV.sfxBus;
  const t0 = ac.currentTime + 0.02;
  bell(ac, bus, N.C5, t0, 0.45, 0.12);
  bell(ac, bus, N.E5, t0 + 0.09, 0.6, 0.13); // the rising major third
  bell(ac, bus, N.E6, t0 + 0.2, 0.5, 0.06);  // sparkle octave tail
}

/**
 * Wrong verse / wrong family (Ch. 5.7): a single muffled low thud, and the
 * music bed ducks 6 dB for 1 s. No shame siren — it's a stumble, not a fail
 * state (the vignette carries the pressure).
 */
export function playVerseStingWrong() {
  const ac = live();
  if (!ac) return;
  const bus = ENV.sfxBus;
  const t0 = ac.currentTime + 0.02;
  tone(ac, bus, 130, t0, 0.22, 0.18, "sine", 72, 320);      // the thud, muffled by the lowpass
  noiseBurst(ac, bus, t0, 0.1, 0.08, 240, 0.8, "lowpass");  // felt-mallet skin
  duckAmbient(-6, 1.0);                                     // bible-specified duck
}

// -----------------------------------------------------------------------------
// Ambient ducking (Ch. 2.1 aggro approach −6 dB; Ch. 5.7 wrong-verse duck)
// -----------------------------------------------------------------------------
// Operates on the injected musicBus gain with setTargetAtTime, restoring the
// original level afterward. Re-entrant: overlapping ducks extend the hold and
// the deepest duck wins; the original level is captured once.

let duckState = null; // { orig, timer, depthDb }

/**
 * Duck the music/ambient bed by `db` (negative, e.g. -6) for `seconds`, then
 * restore. Pass seconds = Infinity to hold (aggro approach), then call
 * releaseAmbientDuck() when the encounter resolves.
 */
export function duckAmbient(db = -6, seconds = 1.0) {
  const ac = ENV && ENV.ctx;
  if (!ac || !ENV.musicBus) return;
  const bus = ENV.musicBus;
  if (!duckState) duckState = { orig: bus.gain.value, timer: null, depthDb: 0 };
  if (duckState.timer) {
    clearTimeout(duckState.timer);
    duckState.timer = null;
  }
  duckState.depthDb = Math.min(duckState.depthDb, db); // deepest duck wins
  const target = duckState.orig * Math.pow(10, duckState.depthDb / 20);
  bus.gain.setTargetAtTime(target, ac.currentTime, 0.06);
  if (seconds !== Infinity) {
    duckState.timer = setTimeout(releaseAmbientDuck, seconds * 1000);
  }
}

/** Restore the bed to its pre-duck level (safe to call when not ducked). */
export function releaseAmbientDuck() {
  const ac = ENV && ENV.ctx;
  if (!ac || !duckState) return;
  ENV.musicBus.gain.setTargetAtTime(duckState.orig, ac.currentTime, 0.3);
  if (duckState.timer) clearTimeout(duckState.timer);
  duckState = null;
}

// -----------------------------------------------------------------------------
// Teardown (Wire phase calls from the host effect's cleanup)
// -----------------------------------------------------------------------------
export function disposeGlowlandsAudio() {
  stopEastRoadTravelLoop();
  releaseAmbientDuck();
  ENV = null;
}
