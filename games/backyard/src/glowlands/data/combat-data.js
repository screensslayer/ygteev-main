// =============================================================================
// glowlands/data/combat-data.js
// Truth & Light combat data — Phase 1 "gateway slice" (design bible Ch. 2, Ch. 17)
//
// PURE DATA + tiny pure helpers. ES module. No three.js, no React, no side
// effects, no imports. Safe to import from any glowlands module and from the
// Wire phase in dragon-garden-quest.jsx.
//
// Design authority: /docs/glowlands-design.md
//   Ch. 2    — Truth & Light system (type chart, encounter flow, bestiary, bosses)
//   Ch. 7    — Meadow Town (First Shadow context, prologue lies)
//   Roads    — the East Road (Milepost Oak / Low Stones / the Rise ambush points)
//   Ch. 17   — Phase 1 scope (bestiary ships Whisperling; Murmur Pack and
//              Heavyback are DEFINED here per the combat spec but flagged
//              inPhase1Slice:false so spawners must not place them yet)
//
// SCRIPTURE RULE (LOCKED — orchestrator contract, overrides any older note):
// This file NEVER embeds or bundles verse text. Serum cards carry only an
// accurate `ref` (canonical reference string) plus a `gist` — ORIGINAL,
// kid-appropriate prose faithful to the verse, <= 12 words, NEVER a quote.
// All displayed verse text is fetched at RUNTIME as ESV via
//   ctx.fetchPassage(reference) -> Promise<{reference, translation, text} | {error}>
// (deployed get-bible-passage edge function; returns 503
// {error:"translation_unavailable"} until the ESV key is configured).
// Every card face / Lightburst flare / long-press reader MUST degrade
// gracefully to `ref` + `gist` when the fetch errors. The only bundled verse
// text anywhere in glowlands is the DEV-only mock passage provider
// (import.meta.env.DEV-gated, WEB John 1 only) — it does not live here.
//
// COMBAT COVENANT: nothing here deals damage, bleeds, or dies. No HP. The
// vignette is the only pressure meter; failure resolves via the Fade path.
// Darkness always flees light (see James 4:7 — reference only, fetch at runtime).
//
// MISS-LOG CONTRACT (Ch. 17 row 4 / Ch. 13.6): every failed counter must be
// recorded by the combat logic layer as { lie_id, counter_verse_ref, zone,
// timestamp }. Lie ids in this file are the canonical `lie_id` values.
// =============================================================================

// -----------------------------------------------------------------------------
// Tuning constants (Ch. 2.1, 2.3, 2.4, 2.8 — all values marked tunable in bible)
// -----------------------------------------------------------------------------
export const COMBAT_TUNING = Object.freeze({
  aggroRadiusM: 8,               // Gloomling notices player inside this radius
  ambientDuckDb: -6,             // ambient audio ducks on approach
  timeDilationSatchel: 0.25,     // world speed while satchel wheel is open (single-player)
  vignetteTightenPerSec: 0.02,   // fear pressure, 2%/s while a lie is live
  vignetteFizzleSnap: 0.15,      // wrong family: vignette snaps 15% tighter
  vignetteReleaseSec: 0.8,       // on encounter clear
  lightburstFlareSec: 1.2,       // fetched verse text flare duration on super-effective
  reducedFlashGlowRampSec: 0.6,  // accessibility: Lightburst becomes radial glow ramp
  serumCharges: 5,               // PP analog; Deepwell Vials (Phase 2) raise to 6
  loadout: Object.freeze({ familySlots: 6, cardsPerFamily: 3, maxEquipped: 18 }),
  masteryThresholds: Object.freeze({ bronze: 5, silver: 15, gold: 40 }),
  goldMastery: Object.freeze({ lightburstScale: 1.3, sparkBonus: 0.10 }),
  fadeRegroupSec: 10,            // wake at nearest lit lantern; items/progress intact
  encounterLengthTargetSec: Object.freeze({ trash: [8, 15], elite: [25, 40], boss: [180, 240] }),
  emberSparks: Object.freeze({ trash: [3, 5], elite: [12, 20], boss: 60 }), // cosmetic-only currency
  dissolveFireflies: [20, 30],   // additive firefly sprites on Gloomling dissolve
});

// -----------------------------------------------------------------------------
// Precision tiers (Ch. 2.4). Phase 1 uses TIER_1 and BOSS only.
// -----------------------------------------------------------------------------
export const PRECISION_TIERS = Object.freeze({
  TIER_1: Object.freeze({
    id: 'tier1',
    zones: ['meadow_town', 'east_road', 'riverbend'],
    hardTimerSec: null,          // vignette pressure only, no hard timer
    precision: 'family',         // any charged serum in the correct family is super effective
  }),
  BOSS: Object.freeze({
    id: 'boss',
    zones: [],                   // phase-scripted; timers live on the boss phase data
    hardTimerSec: null,
    precision: 'scripted',
  }),
});

// -----------------------------------------------------------------------------
// The type chart — six lie families vs six verse families, strictly one-to-one
// (Ch. 2.2). No resistances, no immunities, no dual types.
// Families are never color-only: icon + fixed wheel position double-code them.
// -----------------------------------------------------------------------------
export const LIE_FAMILIES = Object.freeze({
  isolation: Object.freeze({
    id: 'isolation',
    label: 'Isolation',
    icon: 'broken-circle',
    color: '#6B7FA3',            // slate blue
    wheelIndex: 0,               // fixed satchel-wheel wedge position
    counterFamily: 'presence',
  }),
  condemnation: Object.freeze({
    id: 'condemnation',
    label: 'Condemnation',
    icon: 'chain',
    color: '#8A8A8A',            // ash grey
    wheelIndex: 1,
    counterFamily: 'grace',
  }),
  fear: Object.freeze({
    id: 'fear',
    label: 'Fear',
    icon: 'jagged-eye',
    color: '#7A5FA8',            // cold violet
    wheelIndex: 2,
    counterFamily: 'courage',
  }),
  worthlessness: Object.freeze({
    id: 'worthlessness',
    label: 'Worthlessness',
    icon: 'cracked-mirror',
    color: '#A08850',            // dull bronze
    wheelIndex: 3,
    counterFamily: 'identity',
  }),
  despair: Object.freeze({
    id: 'despair',
    label: 'Despair',
    icon: 'falling-leaf',
    color: '#8FA382',            // faded green
    wheelIndex: 4,
    counterFamily: 'hope',
  }),
  doubt: Object.freeze({
    id: 'doubt',
    label: 'Doubt',
    icon: 'fogged-lantern',
    color: '#B3A34A',            // murk yellow
    wheelIndex: 5,
    counterFamily: 'trust',
  }),
});

export const VERSE_FAMILIES = Object.freeze({
  presence: Object.freeze({ id: 'presence', label: 'Presence', counters: 'isolation' }),
  grace:    Object.freeze({ id: 'grace',    label: 'Grace',    counters: 'condemnation' }),
  courage:  Object.freeze({ id: 'courage',  label: 'Courage',  counters: 'fear' }),
  identity: Object.freeze({ id: 'identity', label: 'Identity', counters: 'worthlessness' }),
  hope:     Object.freeze({ id: 'hope',     label: 'Hope',     counters: 'despair' }),
  trust:    Object.freeze({ id: 'trust',    label: 'Trust',    counters: 'doubt' }),
});

/** lieFamilyId -> verseFamilyId (the whole type chart, one-to-one). */
export const TYPE_CHART = Object.freeze({
  isolation: 'presence',
  condemnation: 'grace',
  fear: 'courage',
  worthlessness: 'identity',
  despair: 'hope',
  doubt: 'trust',
});

// -----------------------------------------------------------------------------
// Effectiveness rules (Ch. 2.1, 2.4) — super / glance ("normal") / fizzle.
// Tier 1 (this whole slice): family match = SUPER, anything else = FIZZLE.
// GLANCE is the middle "normal" result — it exists only at precision tier 2+
// (right family, wrong verse) and is included so the resolver is
// forward-complete; nothing in Phase 1 emits it.
// -----------------------------------------------------------------------------
export const EFFECTIVENESS = Object.freeze({
  SUPER: Object.freeze({
    id: 'super',
    label: 'Lightburst',
    clearsLie: true,
    spendsCharge: true,          // every cast spends one charge, hit or miss
    greysOutCard: false,
    vignetteDelta: 0,            // release handled on encounter clear
    // fx: verse text (runtime-fetched via ctx.fetchPassage(card.ref)) flares
    // 1.2 s with its reference, then dissolve to fireflies. On fetch error
    // (translation_unavailable) the flare shows `ref` + `gist` instead.
    fx: 'lightburst',
  }),
  GLANCE: Object.freeze({
    id: 'glance',
    label: 'Glance',             // tier 2+ only: right family, wrong verse ("normal")
    clearsLie: false,
    spendsCharge: true,
    greysOutCard: false,         // "close, keep looking" — the card stays playable
    vignetteDelta: 0.15,         // same vignette cost as a fizzle
    fx: 'stagger-dim',           // lie staggers and re-forms dimmer
  }),
  FIZZLE: Object.freeze({
    id: 'fizzle',
    label: 'Fizzle',
    clearsLie: false,
    spendsCharge: true,
    greysOutCard: true,          // greyed out for THIS encounter only (no spam-guessing)
    vignetteDelta: 0.15,         // fear closes in — vignette snaps 15% tighter
    fx: 'grey-shimmer',          // weak grey shimmer; the lie re-forms louder
  }),
});

/**
 * Resolve one serum cast against one live lie. Pure function.
 *
 * Tier-2 invariant (r2): 'verse' precision REQUIRES an exact ref. It is read
 * from `opts.requiredRef`, falling back to `lie.requiredRef` so tier-2 zone
 * data can carry the invariant on the lie itself instead of every call site.
 * If neither is present, that is a programming error — silently degrading to
 * family precision is forbidden: we throw in dev builds and return the
 * conservative 'glance' (never the too-generous 'super') in production.
 *
 * @param {object} lie   - a lie object from this file ({ family, requiredRef?, ... })
 * @param {object} serum - { family: verseFamilyId, ref: string }
 * @param {object} [opts]
 * @param {'family'|'verse'} [opts.precision='family'] - tier 1 = 'family'
 * @param {string|null} [opts.requiredRef=null] - exact ref demanded at tier 2+
 * @returns {'super'|'glance'|'fizzle'} an EFFECTIVENESS id
 */
export function resolveCast(lie, serum, opts = {}) {
  const precision = opts.precision || 'family';
  const requiredRef = opts.requiredRef || lie.requiredRef || null;
  const familyMatches = TYPE_CHART[lie.family] === serum.family;
  if (!familyMatches) return 'fizzle';                 // wrong family never works, any tier
  if (precision === 'family') return 'super';          // tier 1: any card in the family
  if (!requiredRef) {
    // 'verse' precision with no required ref anywhere: caller bug, not data.
    if (typeof import.meta !== 'undefined' && import.meta.env && import.meta.env.DEV) {
      throw new Error(
        `resolveCast: precision 'verse' for lie "${lie.id}" but no requiredRef ` +
        '(pass opts.requiredRef or author lie.requiredRef)'
      );
    }
    return 'glance'; // prod: conservative, never a free 'super'
  }
  if (serum.ref !== requiredRef) return 'glance';
  return 'super';
}

/** Which verse family counters a given lie family. */
export function getCounterFamily(lieFamilyId) {
  return TYPE_CHART[lieFamilyId] || null;
}

// -----------------------------------------------------------------------------
// Verse pool — REFERENCES ONLY (see SCRIPTURE RULE in the header).
// `ref`  = accurate canonical reference; the UI's ONLY source of verse text is
//          ctx.fetchPassage(ref) at runtime (ESV).
// `gist` = ORIGINAL prose, faithful to the verse, kid-appropriate, <= 12 words,
//          never a quote. It is the card-face line and the graceful-degradation
//          fallback while fetch is pending or errored.
//          AUDIT RULE (r2): a gist must share NO verbatim run of more than 4
//          consecutive words with the ESV (or other common) rendering of its
//          verse. validateCombatData() cannot check this (no bundled text, by
//          design) — any writer touching a gist re-audits it by hand.
// Each lie family has >= 3 valid counters in this pool (writers' rule, Ch. 2.2).
// -----------------------------------------------------------------------------
export const VERSES = Object.freeze({
  // --- Presence (counters Isolation) ---
  'deut_31_6': Object.freeze({
    ref: 'Deuteronomy 31:6',
    family: 'presence',
    gist: 'God goes with you and will never abandon you.',
  }),
  'matt_28_20': Object.freeze({
    ref: 'Matthew 28:20',
    family: 'presence',
    gist: 'Jesus promises he will stay beside his followers forever.',
  }),
  'josh_1_9': Object.freeze({
    ref: 'Joshua 1:9',
    family: 'presence',
    gist: 'Courage comes from knowing God never leaves your side.',
  }),
  'ps_23_4': Object.freeze({
    ref: 'Psalm 23:4',
    family: 'presence',
    gist: 'Even in the darkest valley, God stays right beside you.',
  }),

  // --- Grace (counters Condemnation) ---
  'rom_8_1': Object.freeze({
    ref: 'Romans 8:1',
    family: 'grace',
    gist: 'In Christ, no condemnation is left hanging over you.',
  }),
  '1john_1_9': Object.freeze({
    ref: '1 John 1:9',
    family: 'grace',
    gist: 'When we admit our sins, God faithfully forgives and cleans us.',
  }),
  'ps_103_12': Object.freeze({
    ref: 'Psalm 103:12',
    family: 'grace',
    gist: 'God carries our sins away — farther than east from west.',
  }),

  // --- Courage (counters Fear) ---
  'ps_56_3': Object.freeze({
    ref: 'Psalm 56:3',
    family: 'courage',
    gist: 'On the scared days, put your trust in God.',
  }),
  'isa_41_10': Object.freeze({
    ref: 'Isaiah 41:10',
    family: 'courage',
    gist: 'Do not fear — God strengthens you, helps you, holds you.',
  }),
  '2tim_1_7': Object.freeze({
    ref: '2 Timothy 1:7',
    family: 'courage',
    gist: 'God’s Spirit makes you strong and loving, not timid.',
  }),

  // --- Identity (counters Worthlessness) ---
  'ps_139_14': Object.freeze({
    ref: 'Psalm 139:14',
    family: 'identity',
    gist: 'You were made wonderfully, on purpose, by God.',
  }),
  'eph_2_10': Object.freeze({
    ref: 'Ephesians 2:10',
    family: 'identity',
    gist: 'You are God’s handiwork, created for good work he prepared.',
  }),
  '1john_3_1': Object.freeze({
    ref: '1 John 3:1',
    family: 'identity',
    gist: 'The Father’s great love makes you his own child.',
  }),

  // --- Hope (counters Despair) ---
  'jer_29_11': Object.freeze({
    ref: 'Jeremiah 29:11',
    family: 'hope',
    gist: 'God’s plans for you hold peace, hope, and a future.',
  }),
  'lam_3_22_23': Object.freeze({
    ref: 'Lamentations 3:22-23',
    family: 'hope',
    gist: 'God’s mercies never run out — they restart every morning.',
  }),
  'rom_15_13': Object.freeze({
    ref: 'Romans 15:13',
    family: 'hope',
    gist: 'God can flood your heart with hope, joy, and peace.',
  }),

  // --- Trust (counters Doubt) ---
  'prov_3_5_6': Object.freeze({
    ref: 'Proverbs 3:5-6',
    family: 'trust',
    gist: 'Trust God with your whole heart; he straightens your path.',
  }),
  '1pet_5_7': Object.freeze({
    ref: '1 Peter 5:7',
    family: 'trust',
    gist: 'Hand God every worry — he truly cares about you.',
  }),
  'ps_34_17': Object.freeze({
    ref: 'Psalm 34:17',
    family: 'trust',
    gist: 'God hears his people call out, and he rescues them.',
  }),

  // --- Prologue starters (Ch. 6.5, Ch. 7.5) ---
  'john_8_12': Object.freeze({
    ref: 'John 8:12',
    family: 'identity',          // Jesus as light of the world — the prologue's identity anchor
    gist: 'Jesus, light of the world, leads his followers out of darkness.',
  }),
  'phil_4_13': Object.freeze({
    ref: 'Philippians 4:13',
    family: 'courage',
    gist: 'Christ gives you strength for everything you face.',
  }),
});

/**
 * Starter Truth Serums, in grant order (Ch. 7.5 prologue):
 *  1. John 8:12  — handed by Eli at the gate (the player's first card).
 *  2. Philippians 4:13 — granted on the spot at the first Gloomling tutorial.
 * Maribel's first library study session then mints 3 more (grace pool priority,
 * so the player can free Bram from "One mistake and you're done.").
 */
export const STARTER_SERUMS = Object.freeze(['john_8_12', 'phil_4_13']);
export const FIRST_STUDY_SESSION_MINTS = Object.freeze(['rom_8_1', 'ps_103_12', '1john_1_9']);

/**
 * The verse families EVERY player is guaranteed to hold from the prologue
 * grants above, before the First Shadow and before setting foot on the East
 * Road: identity (john_8_12), courage (phil_4_13), grace (the study mints).
 * NO-SOFT-LOCK ANCHOR (r2, Ch. 2.1): all Phase 1 MANDATORY content — every
 * First Shadow phase and every East Road patrol unit — must be beatable with
 * these three families alone. Presence / hope / trust cards are Phase 1
 * bonus finds; nothing required may depend on them. validateCombatData()
 * enforces this against the boss phases and every road lie pool.
 */
export const PROLOGUE_GUARANTEED_FAMILIES = Object.freeze(['identity', 'courage', 'grace']);

/** Lie families the prologue-guaranteed satchel can always counter. */
export const PROLOGUE_COUNTERABLE_LIE_FAMILIES = Object.freeze(
  Object.keys(TYPE_CHART).filter((lf) => PROLOGUE_GUARANTEED_FAMILIES.includes(TYPE_CHART[lf]))
); // => ['condemnation', 'fear', 'worthlessness']

/** All verse ids belonging to a verse family (satchel/library grouping). */
export function getVersesByFamily(verseFamilyId) {
  return Object.keys(VERSES).filter((id) => VERSES[id].family === verseFamilyId);
}

// -----------------------------------------------------------------------------
// Lies. Writers' rule (Ch. 2.2): second-person, present tense, <= 8 words,
// never referencing real-world self-harm, abuse, or specific sins. Lies attack
// identity and hope, not biography. Each lie's family has >= 3 counters in
// VERSES above. Lie `id` is the canonical miss-log `lie_id`. Lies are ORIGINAL
// game prose (not scripture) — bundling them is fine.
// -----------------------------------------------------------------------------
export const LIES = Object.freeze({
  // Whisperling script (tier 1, tutorial trash — speaks exactly ONE per encounter)
  'lie_ws_small':    Object.freeze({ id: 'lie_ws_small',    family: 'worthlessness', text: 'You’re too small to matter.' }),
  'lie_ws_alone':    Object.freeze({ id: 'lie_ws_alone',    family: 'isolation',     text: 'You’re alone out here.' }),
  'lie_ws_dark':     Object.freeze({ id: 'lie_ws_dark',     family: 'fear',          text: 'Something is waiting in the dark.' }),
  'lie_ws_river':    Object.freeze({ id: 'lie_ws_river',    family: 'despair',       text: 'You’ll never make it to the river.' }),
  'lie_ws_called':   Object.freeze({ id: 'lie_ws_called',   family: 'doubt',         text: 'Did the light really call you?' }),

  // Murmur Pack script (each unit speaks a lie from a DIFFERENT family, in sequence)
  'lie_mp_coming':   Object.freeze({ id: 'lie_mp_coming',   family: 'isolation',     text: 'No one is coming with you.' }),
  'lie_mp_messed':   Object.freeze({ id: 'lie_mp_messed',   family: 'condemnation',  text: 'You already messed this up.' }),
  'lie_mp_unsafe':   Object.freeze({ id: 'lie_mp_unsafe',   family: 'fear',          text: 'The road isn’t safe for you.' }),
  'lie_mp_stronger': Object.freeze({ id: 'lie_mp_stronger', family: 'despair',       text: 'You won’t ever get stronger.' }),
  'lie_mp_matter':   Object.freeze({ id: 'lie_mp_matter',   family: 'worthlessness', text: 'You don’t really matter here.' }),

  // Heavyback script (all Despair — only a Hope answer releases the tendril)
  'lie_hb_forever':  Object.freeze({ id: 'lie_hb_forever',  family: 'despair',       text: 'This weight is yours forever.' }),
  'lie_hb_lighter':  Object.freeze({ id: 'lie_hb_lighter',  family: 'despair',       text: 'Nothing gets lighter from here.' }),
  'lie_hb_sitdown':  Object.freeze({ id: 'lie_hb_sitdown',  family: 'despair',       text: 'Why carry on? Just sit down.' }),
  'lie_hb_tired':    Object.freeze({ id: 'lie_hb_tired',    family: 'despair',       text: 'You’ll be tired forever.' }),

  // First Shadow — Phase 1 (teach; one per family taught so far in the prologue)
  'lie_fs_p1_small': Object.freeze({ id: 'lie_fs_p1_small', family: 'worthlessness', text: 'You’re too small for this.' }),
  'lie_fs_p1_done':  Object.freeze({ id: 'lie_fs_p1_done',  family: 'condemnation',  text: 'One mistake and you’re done.' }), // Bram's lie, echoed back
  'lie_fs_p1_dark':  Object.freeze({ id: 'lie_fs_p1_dark',  family: 'fear',          text: 'The dark is stronger than you.' }),

  // First Shadow — Phase 2 (test; lanterns out, 15 s each). r2: LOCKED to the
  // same three families P1 taught (worthlessness / condemnation / fear) — the
  // prologue-guaranteed satchel counters exactly those, so the timed phase can
  // never be unanswerable (Ch. 2.1 no-soft-lock covenant). The doc's "Three
  // more lies" carries no family constraint; the untaught families debut in
  // P3, where only 3 of 6 answers are required.
  'lie_fs_p2_dim':     Object.freeze({ id: 'lie_fs_p2_dim',     family: 'worthlessness', text: 'Your little flame isn’t worth keeping.' }),
  'lie_fs_p2_out':     Object.freeze({ id: 'lie_fs_p2_out',     family: 'condemnation',  text: 'You let every lantern go out.' }),
  'lie_fs_p2_swallow': Object.freeze({ id: 'lie_fs_p2_swallow', family: 'fear',          text: 'The dark will swallow your lantern.' }),

  // First Shadow — Phase 3 (triumph; all at once, answer any three)
  'lie_fs_p3_beside':  Object.freeze({ id: 'lie_fs_p3_beside',  family: 'isolation',     text: 'No one walks beside you.' }),
  'lie_fs_p3_forgive': Object.freeze({ id: 'lie_fs_p3_forgive', family: 'condemnation',  text: 'You can’t be forgiven again.' }),
  'lie_fs_p3_find':    Object.freeze({ id: 'lie_fs_p3_find',    family: 'fear',          text: 'Fear will always find you.' }),
  'lie_fs_p3_shine':   Object.freeze({ id: 'lie_fs_p3_shine',   family: 'worthlessness', text: 'You were never meant to shine.' }),
  'lie_fs_p3_morning': Object.freeze({ id: 'lie_fs_p3_morning', family: 'despair',       text: 'Morning is never coming.' }),
  'lie_fs_p3_real':    Object.freeze({ id: 'lie_fs_p3_real',    family: 'doubt',         text: 'The light was never real.' }),
});

/** All lie ids belonging to a lie family. */
export function getLiesByFamily(lieFamilyId) {
  return Object.keys(LIES).filter((id) => LIES[id].family === lieFamilyId);
}

// -----------------------------------------------------------------------------
// Tier-1 Gloomling bestiary (Ch. 2.5). Visual budget per creature: matte-black
// low-poly silhouette <= 800 tris, single 256px gradient texture, 3-bone spline
// sway, one glowing feature; death = shader dissolve into 20-30 firefly sprites.
// NOTE Phase 1 slice ships ONLY the Whisperling (Ch. 17 row 5). Murmur Pack
// (Riverbend) and Heavyback (Murkmire) are defined per the combat spec but
// carry inPhase1Slice:false — spawners must respect the flag.
// -----------------------------------------------------------------------------
export const GLOOMLINGS = Object.freeze({
  whisperling: Object.freeze({
    id: 'whisperling',
    name: 'Whisperling',
    tier: 'trash',
    zoneDebut: 'meadow_town',    // Meadow Town prologue
    inPhase1Slice: true,
    glowFeature: 'eyes',         // the one glowing feature
    triBudget: 800,
    behavior: Object.freeze({
      pattern: 'skittish',       // backs away as the player's lantern nears
      liesPerEncounter: 1,       // one tier-1 lie; flees on any correct family
      fleesOnFirstSuper: true,
      lanternAvoidance: true,
      moveSpeedMult: 0.8,
    }),
    lieScript: Object.freeze(['lie_ws_small', 'lie_ws_alone', 'lie_ws_dark', 'lie_ws_river', 'lie_ws_called']),
    sparks: [3, 5],              // Ember-sparks drop range (cosmetic-only currency)
    encounterLengthTargetSec: [8, 15],
  }),

  murmur_pack: Object.freeze({
    id: 'murmur_pack',
    name: 'Murmur Pack',
    tier: 'trash',
    zoneDebut: 'riverbend',      // Phase 2 — teaches family recognition under variety
    inPhase1Slice: false,        // DO NOT SPAWN in the gateway slice
    glowFeature: 'throat',
    triBudget: 800,              // per unit
    behavior: Object.freeze({
      pattern: 'pack-sequence',
      packSize: [3, 4],          // 3-4 units
      liesPerEncounter: 'one-per-unit',
      distinctFamiliesRequired: true, // each unit speaks a lie from a DIFFERENT family
      fleesOnFirstSuper: false,  // each unit flees only when ITS lie is answered
      moveSpeedMult: 1.0,
    }),
    lieScript: Object.freeze(['lie_mp_coming', 'lie_mp_messed', 'lie_mp_unsafe', 'lie_mp_stronger', 'lie_mp_matter']),
    sparks: [3, 5],              // per unit
    encounterLengthTargetSec: [25, 40],
  }),

  heavyback: Object.freeze({
    id: 'heavyback',
    name: 'Heavyback',
    tier: 'elite',
    zoneDebut: 'murkmire',       // Phase 2 — embodies the carry-more-sink-more rule
    inPhase1Slice: false,        // DO NOT SPAWN in the gateway slice
    glowFeature: 'spine-ridge',
    triBudget: 800,
    behavior: Object.freeze({
      pattern: 'slow-stalker',
      liesPerEncounter: 1,
      fleesOnFirstSuper: true,
      moveSpeedMult: 0.5,
      tendril: Object.freeze({   // grey tendril: phantom pack weight until answered
        movementPenalty: 0.20,   // player movement -20% while latched
        clearedBy: 'hope',       // only answering its Despair lie releases it
      }),
    }),
    lieScript: Object.freeze(['lie_hb_forever', 'lie_hb_lighter', 'lie_hb_sitdown', 'lie_hb_tired']),
    sparks: [12, 20],
    encounterLengthTargetSec: [25, 40],
  }),
});

// -----------------------------------------------------------------------------
// Timer-expiry modes — the ONLY values a boss phase `onExpire` may hold.
// Ch. 2.4 (LOCKED): "Timer expiry = same result as a wrong answer, never
// worse." Expiry must NOT route to the Fade path on its own — Fade happens
// only if the vignette fully closes, exactly as with wrong answers.
// -----------------------------------------------------------------------------
export const ON_EXPIRE_MODES = Object.freeze({
  // Apply EFFECTIVENESS.FIZZLE's vignetteDelta (fear closes in 15%) and replay
  // the lie. No card greys out (the player cast nothing), no charge is spent,
  // and Fade is NEVER triggered directly by the expiry itself.
  AS_WRONG_ANSWER: 'as-wrong-answer',
});

// -----------------------------------------------------------------------------
// The First Shadow — Meadow Town prologue boss (Ch. 2.6 boss 1, Ch. 7).
// Gates access to the seal arc's trivia battle; NEVER grants the seal itself
// (the seal comes from the Bible Quest). No timers in P1; the covenant of the
// whole game lands in P3: light wins, always.
// -----------------------------------------------------------------------------
export const FIRST_SHADOW = Object.freeze({
  id: 'first_shadow',
  name: 'The First Shadow',
  zone: 'meadow_town',
  arena: 'town_square',
  tier: 'boss',
  precision: 'family',           // tier-1 precision throughout (Meadow Town rule)
  sparks: 60,
  encounterLengthTargetSec: [180, 240],
  missLogZone: 'meadow_town',    // miss-log `zone` value for every failed counter here
  phases: Object.freeze([
    Object.freeze({
      id: 'p1_teach',
      name: 'Teach',
      timerSec: null,            // no timer
      coach: 'eli_banner_text',  // Eli coaching via banner text
      // Three tier-1 lies, one per family the prologue's guaranteed grants
      // counter: worthlessness <- identity (Eli's gate card), condemnation <-
      // grace (Maribel's study mints, freeing Bram), fear <- courage (the
      // tutorial grant). See PROLOGUE_GUARANTEED_FAMILIES.
      lies: Object.freeze(['lie_fs_p1_small', 'lie_fs_p1_done', 'lie_fs_p1_dark']),
      resolveMode: 'sequence',   // one lie at a time, in order
      advanceOn: 'all-answered',
    }),
    Object.freeze({
      id: 'p2_test',
      name: 'Test',
      timerSec: 15,              // 15 s per lie
      stage: Object.freeze({
        extinguishSquareLanterns: true,   // screen darkens except player's lantern radius
        relightOneLanternPerCorrect: true,
      }),
      // r2: same three families as P1, now under time pressure with the
      // lanterns out — guaranteed answerable (see the P2 note in LIES).
      lies: Object.freeze(['lie_fs_p2_dim', 'lie_fs_p2_out', 'lie_fs_p2_swallow']),
      resolveMode: 'sequence',
      advanceOn: 'all-answered',
      onExpire: ON_EXPIRE_MODES.AS_WRONG_ANSWER, // fizzle vignette snap, no grey-out, never Fade directly
    }),
    Object.freeze({
      id: 'p3_triumph',
      name: 'Triumph',
      timerSec: null,
      lies: Object.freeze([      // all at once as swirling smoke-text, one per family
        'lie_fs_p3_beside', 'lie_fs_p3_forgive', 'lie_fs_p3_find',
        'lie_fs_p3_shine', 'lie_fs_p3_morning', 'lie_fs_p3_real',
      ]),
      resolveMode: 'simultaneous',
      // Coverage check (r2): of these six, worthlessness/condemnation/fear are
      // counterable by the guaranteed satchel — exactly answersRequired — so
      // the phase is satisfiable even with zero bonus serums earned.
      answersRequired: 3,        // answer any three, in any order
      advanceOn: 'answer-count',
      finale: Object.freeze({
        // Town lanterns cascade-ignite outward from the player; the First
        // Shadow dissolves fleeing the light. Sets the covenant: light wins, always.
        fx: 'lantern-cascade-from-player',
        lanternCount: 40,
        cascadeSec: 6,           // tunable (Ch. 7.2 save-wave value)
        bossExit: 'dissolve-fleeing-light',
      }),
    }),
  ]),
  calmMode: Object.freeze({
    // Ch. 2.6 Calm Mode table: P2's 15 s windows removed; relight the three
    // lanterns in any order, untimed. Precision, lies, phase structure unchanged.
    p2TimerSec: null,
    p2ResolveMode: 'simultaneous',
    p2AnyOrder: true,
  }),
});

// -----------------------------------------------------------------------------
// East Road encounter definitions (Roads interlude + Ch. 17 row 8).
// Gloom patrols: 1-3 spawns at authored ambush points, denser at dusk and in
// the road's darker (Riverbend) half. Repelling a patrol relights that
// stretch's waymarker for the rest of the session. Phase 1 bestiary is
// Whisperling-only, so every unit below is a Whisperling; lie pools give
// each stretch its own flavor. (Wren's Crossing is deliberately patrol-free —
// it's the traveler-aid cast's camp.) Road challenges feed the Ch. 3.1 road
// XP row (capped 5/day — enforced by the road/challenge logic layer, not
// here). Positions are landmark anchors; the map module owns coordinates,
// including placement of the waymarker lanterns named by `waymarkerId`.
//
// ENCOUNTER SHAPE (r2 — the spawner contract, LOCKED):
//   units[]            The EXACT maximum roster for the patrol. Each unit is
//                      { gloomling, liePool, spawnChance }.
//     spawnChance      Probability (0, 1] that this unit spawns when the
//                      patrol is rolled (`respawn: 'per-session'` = one roll
//                      per encounter per session). Every encounter keeps at
//                      least one unit at 1.0 so a patrol always exists and
//                      its waymarker relight is always achievable.
//     liePool          Candidate lie ids; the unit speaks ONE, chosen after
//                      filterDealableLies(). Every pool contains >= 1 lie
//                      from PROLOGUE_COUNTERABLE_LIE_FAMILIES, so the
//                      guaranteed prologue satchel can always answer
//                      (validated by validateCombatData()).
//   duskDensityMult    Multiplies each unit's spawnChance during dusk/night
//                      on the world clock (Ch. Roads "denser at dusk"),
//                      clamped to 1.0 per unit. It NEVER duplicates units or
//                      draws extras — units[] is the hard roster cap. On a
//                      spawnChance-1.0 unit it is a no-op by design.
//   onEmptyDealablePool  What the spawner MUST do if filterDealableLies() on
//                      a unit's liePool returns [] against the player's
//                      equipped charged cards (only reachable if the player
//                      un-equips the guaranteed starters). Allowed values:
//                        'skip-spawn' — the unit silently does not spawn; the
//                        patrol proceeds with its remaining units, and if NO
//                        unit spawns the encounter counts as clear (waymarker
//                        relights). Ch. 2.1 no-soft-lock rule for roads.
// -----------------------------------------------------------------------------
export const EAST_ROAD_ENCOUNTERS = Object.freeze([
  Object.freeze({
    id: 'east_road_milepost_oak',
    zone: 'east_road',
    landmark: 'milepost_oak',    // the lightning-split oak: red-bag hollow + noticeboard
    ambushPoint: 'oak-shadow',   // authored spawn anchor near the oak's dark side
    units: Object.freeze([
      // 'lie_ws_dark' (fear) keeps the pool dealable by the guaranteed satchel.
      Object.freeze({ gloomling: 'whisperling', spawnChance: 1.0, liePool: Object.freeze(['lie_ws_alone', 'lie_ws_called', 'lie_ws_dark']) }),
      Object.freeze({ gloomling: 'whisperling', spawnChance: 0.4, liePool: Object.freeze(['lie_ws_small']) }),
    ]),
    duskDensityMult: 1.5,        // dusk: the 0.4 straggler becomes 0.6
    waymarkerId: 'east_road_wm_oak',
    relightsWaymarkerOnClear: true,
    onEmptyDealablePool: 'skip-spawn',
    respawn: 'per-session',
    precision: 'family',         // tier 1
  }),

  // The Low Stones — half-sunk shrine row where patrols cluster after dusk.
  // The doc gives this stretch THREE waymarker lanterns to relight, so it
  // gets three patrol entries, one per shrine lantern, walked north to south.
  Object.freeze({
    id: 'east_road_low_stones_north',
    zone: 'east_road',
    landmark: 'low_stones',
    ambushPoint: 'shrine-row-north',
    units: Object.freeze([
      Object.freeze({ gloomling: 'whisperling', spawnChance: 1.0, liePool: Object.freeze(['lie_ws_dark']) }),
    ]),
    duskDensityMult: 2.0,        // the stretch where dusk matters most
    waymarkerId: 'east_road_wm_stones_1', // first of the Low Stones' three lanterns
    relightsWaymarkerOnClear: true,
    onEmptyDealablePool: 'skip-spawn',
    respawn: 'per-session',
    precision: 'family',
  }),
  Object.freeze({
    id: 'east_road_low_stones_middle',
    zone: 'east_road',
    landmark: 'low_stones',
    ambushPoint: 'shrine-row-middle',
    units: Object.freeze([
      // Despair flavor plus a guaranteed-dealable fear fallback in one pool.
      Object.freeze({ gloomling: 'whisperling', spawnChance: 1.0, liePool: Object.freeze(['lie_ws_river', 'lie_ws_dark']) }),
      Object.freeze({ gloomling: 'whisperling', spawnChance: 0.5, liePool: Object.freeze(['lie_ws_small']) }),
    ]),
    duskDensityMult: 2.0,        // dusk: the 0.5 unit is certain — the cluster effect
    waymarkerId: 'east_road_wm_stones_2', // second lantern
    relightsWaymarkerOnClear: true,
    onEmptyDealablePool: 'skip-spawn',
    respawn: 'per-session',
    precision: 'family',
  }),
  Object.freeze({
    id: 'east_road_low_stones_south',
    zone: 'east_road',
    landmark: 'low_stones',
    ambushPoint: 'shrine-row-south',
    units: Object.freeze([
      Object.freeze({ gloomling: 'whisperling', spawnChance: 1.0, liePool: Object.freeze(['lie_ws_small']) }),
      Object.freeze({ gloomling: 'whisperling', spawnChance: 0.5, liePool: Object.freeze(['lie_ws_alone', 'lie_ws_small']) }),
    ]),
    duskDensityMult: 2.0,
    waymarkerId: 'east_road_wm_stones_3', // third lantern
    relightsWaymarkerOnClear: true,
    onEmptyDealablePool: 'skip-spawn',
    respawn: 'per-session',
    precision: 'family',
  }),

  Object.freeze({
    id: 'east_road_the_rise',
    zone: 'east_road',
    landmark: 'the_rise',        // final crest before the Riverbend reveal
    ambushPoint: 'crest-approach', // spawns BELOW the crest — the reveal shot itself stays safe
    units: Object.freeze([
      // 'lie_ws_small' (worthlessness) keeps the flavor pool dealable.
      Object.freeze({ gloomling: 'whisperling', spawnChance: 1.0, liePool: Object.freeze(['lie_ws_called', 'lie_ws_river', 'lie_ws_small']) }),
      Object.freeze({ gloomling: 'whisperling', spawnChance: 0.5, liePool: Object.freeze(['lie_ws_dark']) }),
    ]),
    duskDensityMult: 1.5,
    waymarkerId: 'east_road_wm_rise',
    relightsWaymarkerOnClear: true,
    onEmptyDealablePool: 'skip-spawn',
    respawn: 'per-session',
    precision: 'family',
    // Phase 1 frontier edge: past this encounter sits the road-warden's camp
    // ("River's high past here — come back soon."), owned by the road module.
  }),
]);

// -----------------------------------------------------------------------------
// No-soft-lock rule (Ch. 2.1 — authoritative enforcement is SERVER-side; this
// pure helper lets the client-side generator pre-filter dealable lies).
// Only deal lies that have at least one valid counter among the player's
// currently equipped, CHARGED cards. If grey-outs/empty charges exhaust a
// family mid-encounter, the next miss resolves via the Fade path.
// -----------------------------------------------------------------------------
/**
 * @param {string[]} liePool - candidate lie ids
 * @param {{family: string, charges: number, greyedOut?: boolean}[]} equippedSerums
 * @returns {string[]} lies counterable by at least one equipped, charged, non-greyed card
 */
export function filterDealableLies(liePool, equippedSerums) {
  const liveFamilies = new Set(
    equippedSerums
      .filter((s) => s.charges > 0 && !s.greyedOut)
      .map((s) => s.family)
  );
  return liePool.filter((lieId) => {
    const lie = LIES[lieId];
    return lie && liveFamilies.has(TYPE_CHART[lie.family]);
  });
}

// -----------------------------------------------------------------------------
// Dev-hook validation (pure; call from dev console / tests, never in prod loop).
// Checks the bible's writers' rules AND the no-bundled-scripture rule hold.
// -----------------------------------------------------------------------------
export function validateCombatData() {
  const errors = [];
  // Type chart is a one-to-one bijection
  const counters = Object.values(TYPE_CHART);
  if (new Set(counters).size !== 6 || counters.length !== 6) {
    errors.push('TYPE_CHART must be a one-to-one map of 6 families');
  }
  // Every lie family has >= 3 counter verses in the pool
  for (const lf of Object.keys(LIE_FAMILIES)) {
    const vf = TYPE_CHART[lf];
    if (getVersesByFamily(vf).length < 3) {
      errors.push(`verse family "${vf}" (counters "${lf}") has < 3 verses`);
    }
  }
  // Writers' rule: lies <= 8 words, known family
  for (const lie of Object.values(LIES)) {
    const words = lie.text.replace(/[^\w’' ]/g, '').trim().split(/\s+/).length;
    if (words > 8) errors.push(`lie "${lie.id}" exceeds 8 words (${words})`);
    if (!LIE_FAMILIES[lie.family]) errors.push(`lie "${lie.id}" has unknown family "${lie.family}"`);
  }
  // Verse cards: ref + gist only — NEVER bundled verse text.
  for (const [id, v] of Object.entries(VERSES)) {
    if (!v.ref || typeof v.ref !== 'string') errors.push(`verse "${id}" missing ref`);
    if (!VERSE_FAMILIES[v.family]) errors.push(`verse "${id}" has unknown family "${v.family}"`);
    if (!v.gist) errors.push(`verse "${id}" missing gist (card-face fallback)`);
    const gistWords = (v.gist || '').trim().split(/\s+/).length;
    if (gistWords > 12) errors.push(`verse "${id}" gist exceeds 12 words (${gistWords})`);
    if ('text' in v || 'excerpt' in v) {
      errors.push(`verse "${id}" bundles verse text — scripture must be runtime-fetched via ctx.fetchPassage`);
    }
  }
  // Every referenced lie id exists
  const referenced = [
    ...Object.values(GLOOMLINGS).flatMap((g) => g.lieScript),
    ...FIRST_SHADOW.phases.flatMap((p) => p.lies),
    ...EAST_ROAD_ENCOUNTERS.flatMap((e) => e.units.flatMap((u) => u.liePool)),
  ];
  for (const id of referenced) {
    if (!LIES[id]) errors.push(`referenced lie id "${id}" not in LIES`);
  }
  // Phase 1 slice: East Road encounters must only use in-slice Gloomlings
  for (const enc of EAST_ROAD_ENCOUNTERS) {
    for (const u of enc.units) {
      if (!GLOOMLINGS[u.gloomling] || !GLOOMLINGS[u.gloomling].inPhase1Slice) {
        errors.push(`encounter "${enc.id}" uses out-of-slice gloomling "${u.gloomling}"`);
      }
    }
  }

  // --- No-soft-lock invariants (r2, Ch. 2.1) ---
  // PROLOGUE_GUARANTEED_FAMILIES must match what the prologue actually grants.
  const grantedFamilies = new Set(
    [...STARTER_SERUMS, ...FIRST_STUDY_SESSION_MINTS].map((id) => VERSES[id] && VERSES[id].family)
  );
  for (const f of PROLOGUE_GUARANTEED_FAMILIES) {
    if (!grantedFamilies.has(f)) {
      errors.push(`PROLOGUE_GUARANTEED_FAMILIES lists "${f}" but no prologue grant mints it`);
    }
  }
  const counterable = new Set(PROLOGUE_COUNTERABLE_LIE_FAMILIES);

  // Boss: every MANDATORY lie (P1 sequence, P2 sequence) must be counterable
  // by the guaranteed satchel; count-gated phases need >= answersRequired
  // counterable lies.
  for (const phase of FIRST_SHADOW.phases) {
    const counterableCount = phase.lies.filter((id) => LIES[id] && counterable.has(LIES[id].family)).length;
    if (phase.advanceOn === 'all-answered' && counterableCount < phase.lies.length) {
      errors.push(`boss phase "${phase.id}" requires all answers but has non-guaranteed-counterable lies`);
    }
    if (phase.advanceOn === 'answer-count' && counterableCount < phase.answersRequired) {
      errors.push(`boss phase "${phase.id}" needs ${phase.answersRequired} answers but only ${counterableCount} lies are guaranteed-counterable`);
    }
    if (phase.onExpire !== undefined && !Object.values(ON_EXPIRE_MODES).includes(phase.onExpire)) {
      errors.push(`boss phase "${phase.id}" has unknown onExpire "${phase.onExpire}"`);
    }
  }

  // East Road: every unit pool dealable by the guaranteed satchel; spawner
  // contract fields well-formed.
  for (const enc of EAST_ROAD_ENCOUNTERS) {
    if (enc.onEmptyDealablePool !== 'skip-spawn') {
      errors.push(`encounter "${enc.id}" has unknown onEmptyDealablePool "${enc.onEmptyDealablePool}"`);
    }
    if (!enc.units.some((u) => u.spawnChance === 1.0)) {
      errors.push(`encounter "${enc.id}" has no guaranteed (spawnChance 1.0) unit — waymarker relight not assured`);
    }
    for (const u of enc.units) {
      if (!(u.spawnChance > 0 && u.spawnChance <= 1)) {
        errors.push(`encounter "${enc.id}" unit has spawnChance out of (0, 1]: ${u.spawnChance}`);
      }
      if (!u.liePool.some((id) => LIES[id] && counterable.has(LIES[id].family))) {
        errors.push(`encounter "${enc.id}" has a unit pool with no prologue-guaranteed-counterable lie`);
      }
    }
  }
  return errors; // [] means valid
}
