// =============================================================================
// glowlands/maps/east-road.js
// THE EAST ROAD (Meadow Town -> Riverbend) — the model road, Phase 1 frontier.
//
// Design authority: /docs/glowlands-design.md
//   Roads interlude — the East Road specified in full (Milepost Oak, Wren's
//                     Crossing, the Low Stones, the Rise, warden's camp edge)
//   Ch. 17 row 8    — Phase 1 scope: road-challenge framework, red-bag road
//                     spawns, wayside micro-plot, graceful Riverbend edge
//   Ch. 3.1         — road-challenge XP row (cap 5/day), level-gate signposts
//   Ch. 5.7 / 5.8   — audio by tone zone; perf budget (<=120 draw calls,
//                     instanced/merged scatter, no postprocessing, r128)
//
// Sibling data: ../data/combat-data.js EAST_ROAD_ENCOUNTERS names the ambush
// anchors ('oak-shadow', 'shrine-row-north/middle/south', 'crest-approach')
// and waymarker ids (east_road_wm_oak, _stones_1..3, _rise). Per its comment,
// "the map module owns coordinates" — this file is that owner. A dev-only
// validator (validateEastRoadMap) cross-checks full coverage.
//
// CTX SURFACE (documented assumption — CONTRACT.md was absent from
// src/glowlands/ at authoring time, so the surface below mirrors the host
// game's internal builders in dragon-garden-quest.jsx one-for-one; the Wire
// phase can pass them straight through. EVERY helper is optional — each use
// is guarded, with compact art-consistent local fallbacks for the essentials
// — so `build({})` still yields a complete, walkable map):
//
//   ctx.THREE            three r128 module (else this file's own pinned import)
//   ctx.worldGroup       THREE.Group to parent the map under (else caller adds
//                        the returned .group)
//   ctx.PAL              host palette tokens (else local copy of the same hexes)
//   ctx.flat/ctx.smooth  material factories (else local equivalents)
//   ctx.makeTerrain(hills, flats) -> (x,z)=>y   pure sampler (else local copy)
//   ctx.setTerrain(fn)   registers sampler as the harness's active terrainY
//   ctx.setPathRoutes(routes)  pre-ground path-wear registration
//   ctx.makeGround(size, base, tintFn)          (else local displaced ground)
//   ctx.addFlagstonePath(pts, w)                (else local instanced stones)
//   ctx.makeOak/makePine/makeRock/makeBush(x,z[,s])  scatter factories
//   ctx.addWildflowers/addGrass/addGroundPatches/addForestRing/addMountains/
//   ctx.addClouds/addSparkles/addButterflies    ambient scatter (skipped if absent)
//   ctx.makeSign(x,z,rot)                       (else local)
//   ctx.makeTextPlate(text, {w,h,bg,fg})        canvas text board (else plain board)
//   ctx.addBoxCol(x,z,hw,hd,rot) / ctx.addCircleCol(x,z,r)
//                        collision registration; when absent, colliders are
//                        collected on the returned .colliders array in the
//                        host's resolveCollisions format:
//                          {type:'c',x,z,r} | {type:'b',x,z,hw,hd,rot}
//   ctx.mergeGeoms(geos, mat)                   static-merge helper (optional)
//   ctx.fetchPassage(ref)                       NOT used here — this module
//                        renders no scripture. Verse text belongs to the
//                        reader/challenge UIs, fetched at runtime (ESV) with
//                        graceful reference+retelling degradation. Nothing in
//                        this file embeds or bundles verse text.
//
// PERF SELF-AUDIT (bespoke, non-ctx draw calls added by this builder):
//   ground 1 + creek 2 + bridge 7 + oak ~11 + noticeboard 3 + red-bag 2
//   + micro-plot 2 + Tobbin camp ~14 + shrine stones 1 (instanced) + offerings 1
//   + waymarkers 5x3=15 + level-gate 8 + warden camp ~16 + sealed gate ~12
//   + valley water 1 + mist 2 + milepost 3 + fallback scatter 5 (instanced)
//   ≈ 105 measured worst case (bare ctx, headless traverse) — under the 120
//   budget; with host ctx helpers the bespoke count drops to ~100 and scatter
//   rides the host's instanced systems. All static flat-shaded meshes.
//   No lights added (budget: lantern owns the point light), no postprocessing.
//
// EMBER: never appears here. Ember stays home in Phase 1 (Dragon Whistle is
// Phase 2, Ch. 18) — this module contains no Ember hooks by design.
// =============================================================================

import * as THREE from 'three'; // r128, pinned in package.json
import { EAST_ROAD_ENCOUNTERS } from '../data/combat-data.js';

// -----------------------------------------------------------------------------
// Identity + labels
// -----------------------------------------------------------------------------
export const MAP_ID = 'EAST_ROAD';
export const MAP_LABEL = '\u{1F6E4}️ The East Road';
export const ZONE_ID = 'east_road'; // matches combat-data zone strings

// -----------------------------------------------------------------------------
// Palette. Prefer ctx.PAL; this is a byte-identical copy of the host game's
// tokens so a bare build({}) still lands on the game's exact art. EAST extends
// it with the road's signature drain: Meadow Town cream/terracotta warmth in
// the west fading mile by mile into Riverbend wet slate in the east.
// -----------------------------------------------------------------------------
const PAL_FALLBACK = {
  grassBase: 0x8cab4c, grassSun: 0xb2c25e, grassShade: 0x5c8a44, soil: 0x7a5138,
  pathStone: 0xc7ad7e, leafLime: 0x9ec455, leafMid: 0x619e46, leafDeep: 0x38714a,
  leafWarm: 0xc98e3f, bark: 0x7a5a3e, stone: 0x9d948a, waterSurf: 0x5fb4c4,
  waterDeep: 0x2e7286, skyTop: 0x4a8fd4, skyMid: 0xa9d3e4, skyHorizon: 0xd9e8d8,
  sun: 0xffe0a8, ambientSky: 0xb4cfe6, ambientGnd: 0x7f8f4e, fog: 0xd3e2ce,
  wood: 0xc9b68c, roof: 0xb5654a, plaster: 0xefe2c8, foam: 0xf4f7f5,
};

// -----------------------------------------------------------------------------
// The road spine (west -> east). Winding on purpose: three S-bends so no
// straightaway shows the whole road, and each landmark hides the next.
// ~3 min end to end at walk speed (Roads interlude), scaled to host units.
// -----------------------------------------------------------------------------
export const ROAD_PTS = [
  [-48, 0], [-40, 1.8], [-33, 4.4], [-26, 3.2], [-19, -1.2], [-12, -4.6],
  [-5, -5.2], [3, -3.4], [10, 0.6], [17, 2.4], [24, 2.8], [31, 1.6],
  [38, 0.4], [44, 0], [50, 0],
];
const ROAD_W = 2.4;

// -----------------------------------------------------------------------------
// Landmark anchor coordinates (the single source of truth — combat-data's
// EAST_ROAD_ENCOUNTERS reference these anchors by name).
// -----------------------------------------------------------------------------
export const LANDMARKS = Object.freeze({
  west_gate: Object.freeze({ x: -48, z: 0 }),
  milepost_oak: Object.freeze({ x: -31.5, z: 7 }),
  wrens_crossing: Object.freeze({ x: -8.2, z: -5.0 }),
  tobbin_camp: Object.freeze({ x: -4.2, z: -8.2 }),
  wayside_plot: Object.freeze({ x: -14.5, z: -7.6 }),
  orchard_steps: Object.freeze({ x: 6.0, z: -8.6 }),
  low_stones: Object.freeze({ x: 19, z: 5.4 }),
  the_rise: Object.freeze({ x: 44.5, z: 0 }),
  warden_camp: Object.freeze({ x: 47, z: 4.6 }),
  riverbend_gate: Object.freeze({ x: 52.5, z: 0 }),
});

// Authored ambush anchors — names LOCKED by combat-data EAST_ROAD_ENCOUNTERS.
// The spawner places patrol units here; every anchor sits just OFF the road
// ribbon so a patrol reads as lurking, not blocking (and 'crest-approach'
// spawns below the crest — the reveal shot itself stays safe, per data note).
export const AMBUSH_ANCHORS = Object.freeze({
  'oak-shadow': Object.freeze({ x: -33.8, z: 9.0 }),      // the oak's dark side
  'shrine-row-north': Object.freeze({ x: 14.2, z: 4.4 }), // walked north..
  'shrine-row-middle': Object.freeze({ x: 19.0, z: 4.8 }),
  'shrine-row-south': Object.freeze({ x: 23.8, z: 4.4 }), // ..to south
  'crest-approach': Object.freeze({ x: 37.5, z: 1.8 }),   // below the crest
});

// Waymarker lantern positions — ids LOCKED by combat-data (`waymarkerId`).
// Repelling a stretch's patrol relights its waymarker for the session.
export const WAYMARKER_POSITIONS = Object.freeze({
  east_road_wm_oak: Object.freeze({ x: -29.4, z: 5.6 }),
  east_road_wm_stones_1: Object.freeze({ x: 14.5, z: 4.1 }),
  east_road_wm_stones_2: Object.freeze({ x: 19.2, z: 4.5 }),
  east_road_wm_stones_3: Object.freeze({ x: 23.6, z: 4.1 }),
  east_road_wm_rise: Object.freeze({ x: 40.0, z: -1.6 }),
});

// -----------------------------------------------------------------------------
// Spawns + exits (static data; build() also returns runtime copies).
// West spawn faces east (the journey); the Riverbend spawn is Phase 2 dormant.
// NOTE for Wire phase: 'TOWN' spawn below assumes the saved Meadow Town's
// East Gate interior — reconcile with the town map's own gate coordinates.
// -----------------------------------------------------------------------------
export const SPAWNS = Object.freeze({
  fromMeadowTown: Object.freeze([-45.5, 0]),
  fromRiverbend: Object.freeze([49, 0]),   // dormant until Phase 2
  default: Object.freeze([-45.5, 0]),
});

export const EXITS = Object.freeze([
  Object.freeze({
    x: -49.6, z: 0, r: 2.2, to: 'TOWN', spawn: Object.freeze([15, 0]),
    label: '← Meadow Town', locked: false,
  }),
  Object.freeze({
    // The sealed Riverbend gate — present, visible, and NOT usable in Phase 1.
    // The wire phase must treat locked:true as "never transition"; the warden
    // (and the gate hotspot) deliver the graceful line instead of a wall.
    x: 55, z: 0, r: 2.2, to: 'RIVERBEND', spawn: Object.freeze([2, 0]),
    label: 'Riverbend →', locked: true, unlockPhase: 2,
    lockedLine: "River's high past here — come back soon.",
  }),
]);

// -----------------------------------------------------------------------------
// Road-challenge framework data (Ch. 3.1 + Roads interlude).
// Both challenge types feed the road-challenge XP row, CAPPED 5/day —
// enforcement lives in the road/challenge logic layer, not here.
// -----------------------------------------------------------------------------
export const ROAD_RULES = Object.freeze({
  xpRow: 'road_challenge',
  dailyCap: 5,                    // combined traveler-aid + patrol clears
  aidDurationSecRange: Object.freeze([60, 120]), // tunable per bible
  standingTown: 'meadow_town',    // Standing pays to the nearest town
});

// The 3 authored challenge sites. Two encounter triggers + one traveler-aid
// vignette. Trigger volumes are circles the road passes through; entering one
// arms the listed encounters for the combat layer's spawner (which rolls the
// EXACT rosters/spawnChance defined in combat-data — never more).
// Site 2 covers the road's darker half in one authored stretch: the Low
// Stones shrine row AND the crest approach, so all five combat-data patrols
// (and all five waymarker relights) stay reachable from exactly two triggers.
export const CHALLENGE_SITES = Object.freeze([
  Object.freeze({
    id: 'east_road_site_oak',
    kind: 'encounter',
    x: -31, z: 5.5, r: 6.5,
    encounterIds: Object.freeze(['east_road_milepost_oak']),
    note: 'Milepost Oak stretch — 1 patrol, dusk x1.5',
  }),
  Object.freeze({
    id: 'east_road_site_dark_half',
    kind: 'encounter',
    x: 26, z: 2.8, r: 16,
    encounterIds: Object.freeze([
      'east_road_low_stones_north',
      'east_road_low_stones_middle',
      'east_road_low_stones_south',
      'east_road_the_rise',
    ]),
    note: 'Low Stones shrine row + crest approach — patrols cluster after dusk',
  }),
  Object.freeze({
    id: 'east_road_site_tobbin',
    kind: 'traveler_aid',
    x: -4.2, z: -8.2, r: 3.2,
    vignetteId: 'east_road_aid_tobbin_wheel',
    note: "Wren's Crossing — deliberately patrol-free (the aid cast's camp)",
  }),
]);

// -----------------------------------------------------------------------------
// Traveler-aid vignette — "The Wheel, Again" (Odd Tobbin, the road's running
// joke: his tinker-cart wheel is ALWAYS newly wrong in a NEW way).
// All prose here is ORIGINAL. 60–120 s micro-quest, no combat, no scripture.
// The road logic layer owns state, rewards (XP row above, occasional fruit,
// Standing in Meadow Town) and the once-per-rotation variant pick.
// -----------------------------------------------------------------------------
export const TRAVELER_AID_TOBBIN = Object.freeze({
  id: 'east_road_aid_tobbin_wheel',
  cast: 'odd_tobbin',
  castName: 'Odd Tobbin',
  site: 'tobbin_camp',
  durationSec: 90,               // tunable, within ROAD_RULES.aidDurationSecRange
  greeting: "Ah! Traveler! Don't suppose you know anything about wheels?",
  // Rotating wrong-wheel variants — the logic layer picks the next unseen one
  // per session so the joke never repeats back-to-back.
  wheelVariants: Object.freeze([
    Object.freeze({ id: 'square', line: "It's square. I know it's square. The man SWORE it would round itself off with use." }),
    Object.freeze({ id: 'sideways', line: "Mounted it flat like a table top. Seemed sturdier that way. It was not." }),
    Object.freeze({ id: 'two_wheels', line: "Two wheels nailed together for double the rolling. They disagree about direction." }),
    Object.freeze({ id: 'firewood', line: "Built this one myself from firewood. It's been trying to become firewood again ever since." }),
    Object.freeze({ id: 'millstone', line: "Traded a kettle for a millstone. Grinds wonderfully. Rolls like a grudge." }),
    Object.freeze({ id: 'too_small', line: "The spare was for a wheelbarrow. The cart leans... conversationally now." }),
  ]),
  // Three beats, ~30 s each: find, fetch, fit (3-tap rhythm, mirrors the
  // Raise-the-Roof hammer minigame pattern from Meadow Town).
  steps: Object.freeze([
    Object.freeze({ id: 'inspect', prompt: 'Take a look at the wheel', kind: 'interact' }),
    Object.freeze({ id: 'fetch', prompt: "Fetch the good spare from the cart's rack", kind: 'carry', from: 'cart_rack', to: 'axle' }),
    Object.freeze({ id: 'fit', prompt: 'Seat the wheel — three good taps', kind: 'rhythm3' }),
  ]),
  farewell: "Rolling! Straight, even! ...mostly straight. Wren's Crossing thanks you, friend.",
  rewards: Object.freeze({
    xpRow: 'road_challenge',     // pays via the capped road row (Ch. 3.1)
    fruitChance: 0.35,           // tunable — 'occasional fruit'
    standing: Object.freeze({ town: 'meadow_town', pts: 5 }), // tunable
  }),
});

// -----------------------------------------------------------------------------
// Level-gate signpost — the Ch. 3.1 framework's East Road example. Warm voice,
// never a wall: the Orchard Steps pocket above the road's orchard shoulder.
// The gate SHIPS in Phase 1 (row 9: gates populate with their zones); the
// pocket interior itself lands with the economy pass content drop.
// Level gates never touch main-path access (the Lantern's job) or serums
// (study's job) — this is optional XP-horizon content only.
// -----------------------------------------------------------------------------
export const LEVEL_GATE_SIGNPOSTS = Object.freeze([
  Object.freeze({
    id: 'east_road_orchard_steps',
    zone: ZONE_ID,
    x: LANDMARKS.orchard_steps.x, z: LANDMARKS.orchard_steps.z,
    minLevel: 6,                 // tunable
    pocketId: 'east_road_orchard_overlook',
    pocketShipped: false,        // populates with the economy pass (Ch. 17 row 9)
    signText: 'ORCHARD STEPS',
    lineLocked: "Old steps up through the orchard, rope-tied gardener-tight. A carved note: “Come back at level 6 — the orchard will wait for you.”",
    lineOpen: 'The rope is loose. The steps climb into the leaves.',
  }),
]);

// -----------------------------------------------------------------------------
// The road-warden's camp — Phase 1's graceful frontier edge (Ch. 17 row 8).
// A friendly camp, never a wall. Original prose.
// -----------------------------------------------------------------------------
export const WARDEN = Object.freeze({
  id: 'road_warden_sela',
  name: 'Warden Sela',
  lines: Object.freeze([
    "River's high past here — come back soon.",
    'Kettle’s on, if you’re in no hurry. The valley’s worth a long look.',
    'You hear it, don’t you? Rain down there, even when it’s dry up here.',
    'Gate stays shut till the water minds its manners. Won’t be long, I reckon.',
  ]),
});

// Audio staging data (Ch. 5.7 + Roads: "the player hears the rain bed fade in
// before they see the water"). The audio layer crossfades on player x.
export const AUDIO = Object.freeze({
  bed: 'meadow_open_door_hollow', // Meadow Town's motif bed, road arrangement
  rainOverlay: 'riverbend_rain_bed',
  rainFadeStartX: 32,             // rain bed starts creeping in
  rainFullX: 46,                  // full mix at the crest — before the reveal
  duckDbOnAggro: -6,
});

// =============================================================================
// build(ctx) — constructs the map. Pure three.js scene assembly + returned
// data; no game-state writes, no network, no scripture.
// =============================================================================
export function build(ctx = {}) {
  const T = ctx.THREE || THREE;
  const PAL = ctx.PAL || PAL_FALLBACK;
  const group = new T.Group();
  group.name = 'east-road';
  if (ctx.worldGroup) ctx.worldGroup.add(group);

  const colliders = []; // used only when ctx lacks collision registration
  const hotspots = [];
  const disposables = []; // geometries/materials created locally
  const anims = [];       // per-frame animation closures fn(dt, t)

  // ---- material helpers (host-identical fallbacks) ---------------------------
  const SRGB = (hex) => new T.Color(hex).convertSRGBToLinear();
  const track = (m) => { disposables.push(m); return m; };
  const flat = ctx.flat || ((color, opts = {}) => track(new T.MeshStandardMaterial({
    color: color instanceof T.Color ? color.clone().convertSRGBToLinear() : SRGB(color),
    roughness: 0.9, metalness: 0.02, flatShading: true, ...opts,
  })));
  const smooth = ctx.smooth || ((color, opts = {}) => track(new T.MeshStandardMaterial({
    color: color instanceof T.Color ? color.clone().convertSRGBToLinear() : SRGB(color),
    roughness: 0.55, metalness: 0.02, ...opts,
  })));
  const geo = (g) => { disposables.push(g); return g; };
  const mesh = (g, m) => { const me = new T.Mesh(g, m); me.castShadow = false; me.receiveShadow = true; return me; };

  const addCircleCol = ctx.addCircleCol || ((x, z, r) => colliders.push({ type: 'c', x, z, r }));
  const addBoxCol = ctx.addBoxCol || ((x, z, hw, hd, rot = 0) => colliders.push({ type: 'b', x, z, hw, hd, rot }));

  const clamp01 = (v) => Math.min(1, Math.max(0, v));
  const smoothstep = (a, b, v) => { const t = clamp01((v - a) / (b - a)); return t * t * (3 - 2 * t); };
  // Palette drain west->east: 0 at Meadow Town end, 1 at the crest.
  const drain = (x) => smoothstep(-24, 46, x);

  // ---- terrain ---------------------------------------------------------------
  // Descends from the West Gate through orchard shoulders into bottomland,
  // then climbs the Rise; past the crest the valley falls away (negative hill)
  // toward the distant floodwater. Road rectangles are flattened EXCEPT the
  // east climb (x>38) so the road genuinely rides up and over the crest.
  const localMakeTerrain = (hills, flats) => (x, z) => {
    let h = 0;
    for (const b of hills) {
      const d2 = ((x - b.x) * (x - b.x) + (z - b.z) * (z - b.z)) / (b.r * b.r);
      h += b.h * Math.exp(-d2 * 2.2);
    }
    let f = 1;
    for (const zn of flats) {
      let d;
      if (zn.c) d = Math.hypot(x - zn.x, z - zn.z) - zn.r;
      else {
        const dx = Math.max(zn.x1 - x, 0, x - zn.x2);
        const dz = Math.max(zn.z1 - z, 0, z - zn.z2);
        d = Math.hypot(dx, dz);
      }
      const t = clamp01(d / zn.f);
      f = Math.min(f, t * t * (3 - 2 * t));
    }
    return h * f;
  };
  const HILLS = [
    // west orchard shoulders (gentle, warm)
    { x: -38, z: 14, r: 9, h: 1.5 }, { x: -24, z: -14, r: 8, h: 1.3 },
    { x: -30, z: -15, r: 7, h: 1.1 }, { x: -12, z: 13, r: 9, h: 1.4 },
    // mid bottomland lumps
    { x: 6, z: 14, r: 9, h: 1.2 }, { x: 12, z: -14, r: 8, h: 1.3 },
    { x: 26, z: -12, r: 8, h: 1.1 }, { x: 30, z: 14, r: 9, h: 1.6 },
    // the Rise — the road climbs this; crest ~x44
    { x: 46, z: 0, r: 14, h: 3.0 },
    { x: 46, z: 16, r: 9, h: 2.4 }, { x: 46, z: -16, r: 9, h: 2.4 },
    // the valley beyond the crest falls away toward the water
    { x: 78, z: 0, r: 22, h: -3.4 },
  ];
  const FLATS = [
    { x1: -52, z1: -1.4, x2: -26, z2: 6.2, f: 3 },
    { x1: -26, z1: -6.4, x2: -12, z2: 5.0, f: 3 },
    { x1: -12, z1: -7.4, x2: 3, z2: -2.2, f: 3 },
    { x1: 3, z1: -5.2, x2: 17, z2: 4.2, f: 3 },
    { x1: 17, z1: -0.6, x2: 38, z2: 4.6, f: 3 },
    { c: 1, x: LANDMARKS.milepost_oak.x, z: LANDMARKS.milepost_oak.z, r: 4.5, f: 3 },
    { c: 1, x: LANDMARKS.tobbin_camp.x, z: LANDMARKS.tobbin_camp.z, r: 4, f: 3 },
    { c: 1, x: LANDMARKS.low_stones.x, z: LANDMARKS.low_stones.z, r: 5.5, f: 3 },
    // no flats east of 38: the road rides the Rise
  ];
  const terrainY = (ctx.makeTerrain || localMakeTerrain)(HILLS, FLATS);
  if (ctx.setTerrain) ctx.setTerrain(terrainY);
  const yAt = (x, z) => terrainY(x, z);

  // ---- path wear + ground ----------------------------------------------------
  const routes = [{ pts: ROAD_PTS, w: ROAD_W }];
  if (ctx.setPathRoutes) ctx.setPathRoutes(routes);

  // creek line (Wren's Crossing): meanders north-south near x=-8.5
  const creekX = (z) => -8.5 + Math.sin(z * 0.18) * 1.4;
  const CREEK_HALF_W = 1.5;

  const SLATE = new T.Color(PAL.grassShade).lerp(new T.Color(PAL.waterDeep), 0.38).offsetHSL(0, -0.12, -0.02);
  const WET_BANK = new T.Color(PAL.soil).offsetHSL(0, -0.04, -0.07);
  const groundTint = (x, z, c) => {
    // west warmth -> east slate (the journey made legible, Roads interlude)
    c.lerp(SLATE, drain(x) * 0.55);
    // wet banks near the creek
    const dCreek = Math.abs(x - creekX(z)) - CREEK_HALF_W;
    if (dCreek < 2.2) c.lerp(WET_BANK, clamp01(1 - Math.max(0, dCreek) / 2.2) * 0.5);
  };

  if (ctx.makeGround) {
    group.add(ctx.makeGround(120, PAL.grassBase, groundTint));
  } else {
    // local fallback: displaced vertex-colored plane
    const SIZE = 120, SEG = 96;
    const gg = geo(new T.PlaneGeometry(SIZE, SIZE, SEG, SEG));
    gg.rotateX(-Math.PI / 2);
    const pos = gg.attributes.position;
    const cols = new Float32Array(pos.count * 3);
    const cBase = SRGB(PAL.grassBase), cSun = SRGB(PAL.grassSun), cSh = SRGB(PAL.grassShade);
    const tmp = new T.Color();
    for (let i = 0; i < pos.count; i++) {
      const x = pos.getX(i), z = pos.getZ(i);
      pos.setY(i, terrainY(x, z));
      tmp.copy(cBase).lerp(Math.sin(x * 0.13 + z * 0.09) > 0.3 ? cSun : cSh, 0.25);
      const lin = tmp.clone();
      groundTint(x, z, lin);
      cols[i * 3] = lin.r; cols[i * 3 + 1] = lin.g; cols[i * 3 + 2] = lin.b;
    }
    gg.setAttribute('color', new T.BufferAttribute(cols, 3));
    gg.computeVertexNormals();
    const gm = mesh(gg, track(new T.MeshStandardMaterial({ vertexColors: true, roughness: 1, flatShading: true })));
    group.add(gm);
  }

  // flagstone road
  if (ctx.addFlagstonePath) {
    ctx.addFlagstonePath(ROAD_PTS, ROAD_W);
  } else {
    // fallback: one InstancedMesh of worn flat stones along the spine
    const stoneG = geo(new T.CylinderGeometry(0.42, 0.46, 0.07, 6));
    let total = 0;
    for (let i = 0; i < ROAD_PTS.length - 1; i++) total += Math.ceil(Math.hypot(ROAD_PTS[i + 1][0] - ROAD_PTS[i][0], ROAD_PTS[i + 1][1] - ROAD_PTS[i][1]) / 0.95) * 2;
    const inst = new T.InstancedMesh(stoneG, flat(PAL.pathStone, { roughness: 1 }), total);
    const dummy = new T.Object3D();
    let n = 0;
    for (let i = 0; i < ROAD_PTS.length - 1 && n < total; i++) {
      const [x1, z1] = ROAD_PTS[i], [x2, z2] = ROAD_PTS[i + 1];
      const len = Math.hypot(x2 - x1, z2 - z1), steps = Math.ceil(len / 0.95);
      const px = -(z2 - z1) / len, pz = (x2 - x1) / len; // perpendicular
      for (let s = 0; s < steps && n < total; s++) {
        const t = s / steps;
        for (const side of [-0.55, 0.55]) {
          if (n >= total) break;
          const jx = (Math.random() - 0.5) * 0.3, jz = (Math.random() - 0.5) * 0.3;
          const x = x1 + (x2 - x1) * t + px * side * (ROAD_W / 2) + jx;
          const z = z1 + (z2 - z1) * t + pz * side * (ROAD_W / 2) + jz;
          dummy.position.set(x, yAt(x, z) + 0.02, z);
          dummy.rotation.set(0, Math.random() * Math.PI, 0);
          const sc = 0.8 + Math.random() * 0.5;
          dummy.scale.set(sc, 1, sc * (0.8 + Math.random() * 0.4));
          dummy.updateMatrix();
          inst.setMatrixAt(n++, dummy.matrix);
        }
      }
    }
    inst.count = n;
    inst.instanceMatrix.needsUpdate = true;
    group.add(inst);
  }

  // ---- the creek + Wren's Crossing bridge ------------------------------------
  {
    // water ribbon: one BufferGeometry strip following creekX(z), 2 layers
    const makeCreekStrip = (halfW, y, colorA, colorB, opacity) => {
      const zs = [];
      for (let z = -34; z <= 34; z += 2) zs.push(z);
      const g = geo(new T.BufferGeometry());
      const verts = [], cols = [];
      const cA = SRGB(colorA), cB = SRGB(colorB), c = new T.Color();
      for (const z of zs) {
        const cx = creekX(z);
        c.copy(cA).lerp(cB, smoothstep(-30, 30, z));
        verts.push(cx - halfW, y, z, cx + halfW, y, z);
        cols.push(c.r, c.g, c.b, c.r, c.g, c.b);
      }
      const idx = [];
      for (let i = 0; i < zs.length - 1; i++) {
        const a = i * 2, b = a + 1, cc = a + 2, d = a + 3;
        idx.push(a, cc, b, b, cc, d);
      }
      g.setAttribute('position', new T.Float32BufferAttribute(verts, 3));
      g.setAttribute('color', new T.Float32BufferAttribute(cols, 3));
      g.setIndex(idx);
      g.computeVertexNormals();
      const m = track(new T.MeshStandardMaterial({
        vertexColors: true, roughness: 0.25, metalness: 0.05,
        transparent: true, opacity,
      }));
      return new T.Mesh(g, m);
    };
    // creek bed sits slightly below the local terrain
    const bedY = Math.min(yAt(-8.5, -5), 0) - 0.18;
    const deep = makeCreekStrip(CREEK_HALF_W, bedY, PAL.waterSurf, PAL.waterDeep, 0.92);
    const shimmer = makeCreekStrip(CREEK_HALF_W * 0.7, bedY + 0.03, PAL.foam, PAL.waterSurf, 0.28);
    group.add(deep, shimmer);
    anims.push((dt, t) => { shimmer.position.z = Math.sin(t * 0.8) * 0.35; shimmer.material.opacity = 0.2 + 0.1 * (0.5 + 0.5 * Math.sin(t * 1.7)); });

    // plank bridge where the road crosses (z ~ -5)
    const bx = creekX(-5); // bridge center x
    const BZ = -5;
    const deckY = yAt(bx - 3, BZ) + 0.16;
    const deck = mesh(geo(new T.BoxGeometry(6.4, 0.14, 2.4)), flat(new T.Color(PAL.wood).offsetHSL(0.004, 0.02, -0.02)));
    deck.position.set(bx, deckY, BZ);
    deck.castShadow = true;
    group.add(deck);
    // plank grooves read: 3 thin darker strips on top (cheap, no texture)
    for (let i = -1; i <= 1; i++) {
      const strip = mesh(geo(new T.BoxGeometry(6.4, 0.02, 0.06)), flat(new T.Color(PAL.bark).offsetHSL(0, 0, 0.06)));
      strip.position.set(bx, deckY + 0.08, BZ + i * 0.7);
      group.add(strip);
    }
    // rails + posts
    for (const side of [-1, 1]) {
      const rail = mesh(geo(new T.BoxGeometry(6.2, 0.09, 0.09)), flat(PAL.bark));
      rail.position.set(bx, deckY + 0.72, BZ + side * 1.12);
      rail.castShadow = true;
      group.add(rail);
      for (const ex of [-2.9, 2.9]) {
        const post = mesh(geo(new T.BoxGeometry(0.12, 0.75, 0.12)), flat(PAL.bark));
        post.position.set(bx + ex, deckY + 0.38, BZ + side * 1.12);
        group.add(post);
      }
      // rails are solid; deck is walkable between them
      addBoxCol(bx, BZ + side * 1.12, 3.1, 0.1, 0);
    }
  }

  // ---- (a) the Milepost Oak --------------------------------------------------
  {
    const { x, z } = LANDMARKS.milepost_oak;
    const y = yAt(x, z);
    const oak = new T.Group();
    // lightning-split: two leaning trunk halves around a charred core
    const barkM = flat(new T.Color(PAL.bark).offsetHSL(0, 0, 0.035));
    const charM = flat(new T.Color(0x2e2620), { roughness: 1 });
    for (const [lean, hgt, r] of [[-0.24, 3.4, 0.42], [0.3, 2.7, 0.36]]) {
      const half = mesh(geo(new T.CylinderGeometry(r * 0.62, r, hgt, 6)), barkM);
      half.position.set(lean * 1.6, hgt / 2, 0);
      half.rotation.z = lean;
      half.castShadow = true;
      oak.add(half);
    }
    const core = mesh(geo(new T.BoxGeometry(0.5, 2.1, 0.34)), charM);
    core.position.set(0.04, 1.0, 0);
    core.rotation.z = 0.04;
    oak.add(core);
    // living half keeps a canopy; dead half keeps one bare branch
    const canopyTones = [PAL.leafDeep, PAL.leafMid, PAL.leafLime, PAL.leafDeep];
    canopyTones.forEach((tok, i) => {
      const b = mesh(geo(new T.IcosahedronGeometry(1.15 - i * 0.14, 0)),
        flat(new T.Color(tok).offsetHSL((Math.random() - 0.5) * 0.03, 0, (Math.random() - 0.5) * 0.04)));
      b.position.set(-1.5 + Math.cos(i * 2.1) * 0.8, 3.4 + i * 0.55, Math.sin(i * 2.4) * 0.7);
      b.castShadow = true;
      oak.add(b);
    });
    const bare = mesh(geo(new T.CylinderGeometry(0.05, 0.09, 1.7, 5)), barkM);
    bare.position.set(1.25, 3.1, 0.1);
    bare.rotation.z = -1.1;
    oak.add(bare);
    // the red-bag hollow: dark mouth low on the split face + the red bag prop.
    // The wire phase links hotspot 'redbag_hollow' to the existing red-bag
    // economy (road spawns, Ch. 1.5) — the prop just marks the spot.
    const mouth = mesh(geo(new T.CircleGeometry(0.26, 8)), flat(0x1c1712, { roughness: 1 }));
    mouth.position.set(0.05, 0.72, 0.24);
    mouth.rotation.x = -0.12;
    oak.add(mouth);
    const bag = mesh(geo(new T.SphereGeometry(0.17, 6, 5)), smooth(0xc23b3b, { emissive: SRGB(0x5a1414), emissiveIntensity: 0.35 }));
    bag.scale.y = 1.25;
    bag.position.set(0.05, 0.68, 0.3);
    oak.add(bag);
    oak.position.set(x, y, z);
    group.add(oak);
    addCircleCol(x, z, 0.95);

    // milepost proper — the road's distance marker, leaning with age
    const mp = new T.Group();
    const mpStone = mesh(geo(new T.BoxGeometry(0.42, 1.05, 0.3)), flat(PAL.stone));
    mpStone.position.y = 0.5;
    mpStone.rotation.z = 0.07;
    mpStone.castShadow = true;
    mp.add(mpStone);
    if (ctx.makeTextPlate) {
      const pl = ctx.makeTextPlate('MEADOW 1 • RIVERBEND 2', { w: 1.5, h: 0.4, bg: '#b9b1a6', fg: '#3c362e' });
      pl.position.set(0, 0.78, 0.18);
      mp.add(pl);
    }
    const mpx = x + 2.1, mpz = z - 2.6;
    mp.position.set(mpx, yAt(mpx, mpz), mpz);
    group.add(mp);
    addCircleCol(mpx, mpz, 0.35);
    hotspots.push({ x, z, r: 2.2, type: 'milepost', id: 'east_road_milepost_oak_lm', label: 'The Milepost Oak' });
    hotspots.push({ x: x + 0.2, z: z + 0.5, r: 1.4, type: 'redbag_hollow', id: 'east_road_redbag_oak', label: 'Something red tucked in the hollow…' });

    // the road noticeboard — traveler-aid quests post here (Roads interlude)
    const nb = new T.Group();
    const wm = WAYMARKER_POSITIONS.east_road_wm_oak;
    const nx = wm.x - 0.9, nz = wm.z + 0.7;
    for (const off of [-0.55, 0.55]) {
      const p = mesh(geo(new T.CylinderGeometry(0.06, 0.08, 1.5, 5)), flat(PAL.bark));
      p.position.set(off, 0.75, 0);
      nb.add(p);
    }
    const board = mesh(geo(new T.BoxGeometry(1.5, 0.9, 0.07)), flat(new T.Color(PAL.wood).offsetHSL(0.004, 0.03, 0.045)));
    board.position.y = 1.25;
    board.castShadow = true;
    nb.add(board);
    if (ctx.makeTextPlate) {
      const pl = ctx.makeTextPlate('ROAD NOTICES', { w: 1.3, h: 0.34, bg: '#efe4c8', fg: '#5a4630' });
      pl.position.set(0, 1.52, 0.06);
      nb.add(pl);
    }
    nb.position.set(nx, yAt(nx, nz), nz);
    nb.rotation.y = 0.5;
    group.add(nb);
    addBoxCol(nx, nz, 0.8, 0.15, 0.5);
    hotspots.push({ x: nx, z: nz, r: 1.6, type: 'road_notice', id: 'east_road_noticeboard', label: 'Road noticeboard — travelers in need post here' });
  }

  // ---- wayside public micro-plot (Ch. 3.3 — one bed, every road) -------------
  {
    const { x, z } = LANDMARKS.wayside_plot;
    const y = yAt(x, z);
    const bed = mesh(geo(new T.BoxGeometry(1.7, 0.22, 1.2)), flat(PAL.soil, { roughness: 1 }));
    bed.position.set(x, y + 0.11, z);
    group.add(bed);
    const rim = mesh(geo(new T.BoxGeometry(1.9, 0.12, 1.4)), flat(new T.Color(PAL.wood).offsetHSL(0, 0, -0.06)));
    rim.position.set(x, y + 0.05, z);
    group.add(rim);
    addBoxCol(x, z, 0.95, 0.7, 0);
    hotspots.push({ x, z, r: 1.5, type: 'public_plot', id: 'east_road_wayside_plot', label: 'Wayside plot — anyone may plant, anyone may water' });
  }

  // ---- (b) Wren's Crossing camp — Odd Tobbin's tinker cart -------------------
  {
    const { x, z } = LANDMARKS.tobbin_camp;
    const y = yAt(x, z);
    const camp = new T.Group();
    // the cart: bed + canopy hoops + shafts, and THE WHEEL (wrong, always)
    const bedM = flat(new T.Color(PAL.wood).offsetHSL(0.01, 0.04, -0.03));
    const cartBed = mesh(geo(new T.BoxGeometry(2.4, 0.5, 1.3)), bedM);
    cartBed.position.set(0, 0.75, 0);
    cartBed.castShadow = true;
    camp.add(cartBed);
    const canopy = mesh(geo(new T.CylinderGeometry(0.85, 0.85, 2.2, 8, 1, true, 0, Math.PI)),
      flat(new T.Color(PAL.roof).offsetHSL(0.02, -0.1, 0.12), { side: T.DoubleSide }));
    canopy.rotation.z = Math.PI / 2;
    canopy.position.set(0, 1.35, 0);
    camp.add(canopy);
    const shaft = mesh(geo(new T.BoxGeometry(1.6, 0.09, 0.09)), bedM);
    shaft.position.set(-1.9, 0.62, 0.35);
    shaft.rotation.z = 0.25;
    camp.add(shaft);
    // good wheel (rear) + the wrong wheel: square, today (comic prop; the
    // vignette's variant text rotates, the prop stays visual shorthand)
    const goodWheel = mesh(geo(new T.CylinderGeometry(0.52, 0.52, 0.1, 10)), flat(PAL.bark));
    goodWheel.rotation.x = Math.PI / 2;
    goodWheel.position.set(0.85, 0.52, 0.72);
    camp.add(goodWheel);
    const wrongWheel = mesh(geo(new T.BoxGeometry(0.95, 0.95, 0.1)), flat(new T.Color(PAL.bark).offsetHSL(0.01, 0, 0.08)));
    wrongWheel.position.set(-0.85, 0.5, 0.72);
    camp.add(wrongWheel);
    anims.push((dt, t) => { wrongWheel.rotation.z = Math.sin(t * 1.3) * 0.08; }); // it... settles
    // spare wheel on the rack (vignette step 'fetch' target)
    const spare = mesh(geo(new T.CylinderGeometry(0.5, 0.5, 0.09, 10)), flat(new T.Color(PAL.bark).offsetHSL(0, 0.04, 0.1)));
    spare.rotation.z = Math.PI / 2;
    spare.position.set(1.35, 1.05, -0.55);
    camp.add(spare);
    // Tobbin himself: compact villager silhouette (body/head/hat/satchel)
    const tob = new T.Group();
    const tBody = mesh(geo(new T.CylinderGeometry(0.24, 0.34, 0.85, 7)), flat(0x6a7d52));
    tBody.position.y = 0.45;
    const tHead = mesh(geo(new T.SphereGeometry(0.22, 8, 7)), smooth(0xe8c49a));
    tHead.position.y = 1.05;
    const tHat = mesh(geo(new T.ConeGeometry(0.3, 0.3, 7)), flat(new T.Color(PAL.roof).offsetHSL(0, -0.15, -0.05)));
    tHat.position.y = 1.26;
    const tSatch = mesh(geo(new T.BoxGeometry(0.26, 0.3, 0.12)), flat(PAL.wood));
    tSatch.position.set(0.26, 0.55, 0.16);
    tob.add(tBody, tHead, tHat, tSatch);
    tob.position.set(-1.7, 0, 1.1);
    tob.rotation.y = 0.8;
    camp.add(tob);
    anims.push((dt, t) => { tob.position.y = Math.abs(Math.sin(t * 2.1)) * 0.02; }); // fussing at the wheel
    // camp dressing: stool + kettle box
    const stool = mesh(geo(new T.CylinderGeometry(0.26, 0.3, 0.32, 6)), bedM);
    stool.position.set(1.6, 0.16, 1.3);
    camp.add(stool);
    camp.position.set(x, y, z);
    camp.rotation.y = -0.35;
    group.add(camp);
    addBoxCol(x, z, 1.5, 0.9, -0.35);
    hotspots.push({
      x: x - 1.5, z: z + 1.0, r: 1.9, type: 'traveler_aid',
      id: TRAVELER_AID_TOBBIN.id, label: 'Help Odd Tobbin with his cart wheel',
    });
  }

  // ---- level-gate signpost example: the Orchard Steps (Ch. 3.1) --------------
  {
    const gate = LEVEL_GATE_SIGNPOSTS[0];
    const { x, z } = gate;
    const y = yAt(x, z);
    // signpost (host makeSign look) + text plate
    const sp = new T.Group();
    const post = mesh(geo(new T.CylinderGeometry(0.07, 0.09, 1.2, 5)), flat(PAL.bark));
    post.position.y = 0.6;
    const board = mesh(geo(new T.BoxGeometry(1.2, 0.55, 0.08)), flat(new T.Color(PAL.wood).offsetHSL(0.004, 0.03, 0.045)));
    board.position.y = 1.15;
    board.castShadow = true;
    sp.add(post, board);
    if (ctx.makeTextPlate) {
      const pl = ctx.makeTextPlate(gate.signText, { w: 1.1, h: 0.4, bg: '#efe4c8', fg: '#5a4630' });
      pl.position.set(0, 1.16, 0.05);
      sp.add(pl);
    }
    sp.position.set(x, y, z);
    sp.rotation.y = 0.3;
    group.add(sp);
    addCircleCol(x, z, 0.3);
    // stile rails (the warm "not yet" barrier) + visible steps climbing south
    for (const [i, off] of [[-0.5, 0], [0.5, 0]].entries()) {
      const rail = mesh(geo(new T.BoxGeometry(1.5, 0.08, 0.08)), flat(PAL.wood));
      rail.position.set(x + 1.1, y + 0.45 + i * 0.35, z + 0.6 + off * 0);
      rail.rotation.y = 0.3;
      group.add(rail);
    }
    addBoxCol(x + 1.1, z + 0.6, 0.8, 0.12, 0.3);
    for (let s = 0; s < 4; s++) {
      const sx = x + 1.5 + s * 0.5, sz = z + 1.3 + s * 0.8;
      const step = mesh(geo(new T.BoxGeometry(1.1, 0.16, 0.5)), flat(PAL.stone));
      step.position.set(sx, yAt(sx, sz) + 0.1 + s * 0.16, sz);
      step.rotation.y = 0.3;
      group.add(step);
    }
    hotspots.push({
      x, z, r: 1.8, type: 'level_gate', id: gate.id,
      label: gate.signText, minLevel: gate.minLevel,
      lineLocked: gate.lineLocked, lineOpen: gate.lineOpen,
    });
  }

  // ---- (c) the Low Stones — half-sunk shrine row -----------------------------
  {
    // six stones, one InstancedMesh: half-sunk, tilted, mossy-dark. The three
    // waymarker lanterns of the stretch stand between them (built below with
    // the shared waymarker factory).
    const stoneG = geo(new T.DodecahedronGeometry(0.8, 0));
    const inst = new T.InstancedMesh(stoneG, flat(new T.Color(PAL.stone).lerp(new T.Color(PAL.leafDeep), 0.18), { roughness: 1 }), 6);
    const dummy = new T.Object3D();
    const row = [[14, 5.2], [16.4, 5.8], [18.8, 6.0], [21.2, 5.8], [23.6, 5.2], [25.4, 4.6]];
    row.forEach(([sx, sz], i) => {
      dummy.position.set(sx, yAt(sx, sz) - 0.35 + (i % 2) * 0.12, sz); // half-sunk
      dummy.rotation.set((Math.random() - 0.5) * 0.4, Math.random() * Math.PI, (Math.random() - 0.5) * 0.5);
      const s = 0.8 + (i % 3) * 0.25;
      dummy.scale.set(s, s * (1.2 + (i % 2) * 0.5), s);
      dummy.updateMatrix();
      inst.setMatrixAt(i, dummy.matrix);
      addCircleCol(sx, sz, 0.7 * s);
    });
    inst.instanceMatrix.needsUpdate = true;
    inst.castShadow = true;
    group.add(inst);
    // flat offering slabs at the row's feet — one merged strip, purely visual
    const slab = mesh(geo(new T.BoxGeometry(10.5, 0.1, 0.8)), flat(new T.Color(PAL.stone).offsetHSL(0.01, 0, -0.08)));
    slab.position.set(19.6, yAt(19.6, 4.6) + 0.05, 4.6);
    slab.rotation.y = -0.06;
    group.add(slab);
    hotspots.push({ x: 19, z: 5.2, r: 4.5, type: 'landmark', id: 'east_road_low_stones_lm', label: 'The Low Stones — an old shrine row, half swallowed by the ground' });
  }

  // ---- waymarker lanterns (all five, ids LOCKED by combat-data) --------------
  // Session-lit state is driven by the combat layer via setWaymarkerLit(id, lit)
  // after a patrol clear. Unlit = cold glass; lit = warm emissive + pulse.
  // NO point lights (Ch. 5.8: the player's lantern owns the point light).
  const waymarkers = {};
  {
    const postM = flat(new T.Color(PAL.bark).offsetHSL(0, 0, 0.02));
    const brassM = flat(new T.Color(PAL.sun).offsetHSL(0.01, -0.25, -0.28), { metalness: 0.35, roughness: 0.5 });
    for (const [id, p] of Object.entries(WAYMARKER_POSITIONS)) {
      const y = yAt(p.x, p.z);
      const g = new T.Group();
      const post = mesh(geo(new T.CylinderGeometry(0.07, 0.1, 2.1, 6)), postM);
      post.position.y = 1.05;
      post.castShadow = true;
      const arm = mesh(geo(new T.BoxGeometry(0.55, 0.07, 0.07)), postM);
      arm.position.set(0.22, 2.05, 0);
      const cage = mesh(geo(new T.BoxGeometry(0.3, 0.4, 0.3)), brassM);
      cage.position.set(0.44, 1.82, 0);
      const glassM = track(new T.MeshStandardMaterial({
        color: SRGB(0x8b8f94), emissive: SRGB(PAL.sun), emissiveIntensity: 0.0,
        roughness: 0.4, flatShading: true,
      }));
      const glass = new T.Mesh(geo(new T.BoxGeometry(0.2, 0.28, 0.2)), glassM);
      glass.position.set(0.44, 1.82, 0);
      g.add(post, arm, cage, glass);
      g.position.set(p.x, y, p.z);
      g.rotation.y = Math.random() * Math.PI * 2;
      group.add(g);
      addCircleCol(p.x, p.z, 0.28);
      waymarkers[id] = { id, x: p.x, z: p.z, lit: false, glassMat: glassM, group: g };
    }
    anims.push((dt, t) => {
      for (const wm of Object.values(waymarkers)) {
        if (wm.lit) wm.glassMat.emissiveIntensity = 0.85 + 0.2 * Math.sin(t * 3 + wm.x);
      }
    });
  }
  const setWaymarkerLit = (id, lit) => {
    const wm = waymarkers[id];
    if (!wm) return false;
    wm.lit = !!lit;
    wm.glassMat.emissiveIntensity = lit ? 0.9 : 0.0;
    wm.glassMat.color.copy(lit ? SRGB(PAL.sun) : SRGB(0x8b8f94));
    return true;
  };

  // ---- (d) the Rise: warden's camp + sealed Riverbend gate + the reveal ------
  {
    // road-warden's camp (the friendly Phase 1 edge — never a wall)
    const { x, z } = LANDMARKS.warden_camp;
    const y = yAt(x, z);
    const camp = new T.Group();
    // tent: two leaning canvas planes + ridge pole
    const canvasM = flat(new T.Color(PAL.plaster).offsetHSL(0.02, -0.1, -0.06), { side: T.DoubleSide });
    for (const side of [-1, 1]) {
      const pane = mesh(geo(new T.PlaneGeometry(2.2, 1.7)), canvasM);
      pane.position.set(0, 0.75, side * 0.62);
      pane.rotation.x = side * 0.72;
      pane.castShadow = true;
      camp.add(pane);
    }
    const ridge = mesh(geo(new T.CylinderGeometry(0.05, 0.05, 2.3, 5)), flat(PAL.bark));
    ridge.rotation.z = Math.PI / 2;
    ridge.position.y = 1.42;
    camp.add(ridge);
    // fire ring + coal glow (emissive only, no light) + kettle tripod
    const ring = mesh(geo(new T.TorusGeometry(0.42, 0.1, 5, 9)), flat(PAL.stone));
    ring.rotation.x = -Math.PI / 2;
    ring.position.set(1.7, 0.08, 0.2);
    camp.add(ring);
    const coalsM = track(new T.MeshStandardMaterial({
      color: SRGB(0x74331e), emissive: SRGB(0xff8a3c), emissiveIntensity: 0.8,
      roughness: 1, flatShading: true,
    }));
    const coals = new T.Mesh(geo(new T.IcosahedronGeometry(0.26, 0)), coalsM);
    coals.scale.y = 0.45;
    coals.position.set(1.7, 0.12, 0.2);
    camp.add(coals);
    anims.push((dt, t) => { coalsM.emissiveIntensity = 0.65 + 0.3 * (0.5 + 0.5 * Math.sin(t * 6.3) * Math.sin(t * 2.1)); });
    for (let i = 0; i < 3; i++) {
      const leg = mesh(geo(new T.CylinderGeometry(0.03, 0.03, 1.0, 4)), flat(PAL.bark));
      const a = (i / 3) * Math.PI * 2;
      leg.position.set(1.7 + Math.cos(a) * 0.3, 0.48, 0.2 + Math.sin(a) * 0.3);
      leg.rotation.set(Math.sin(a) * 0.35, 0, -Math.cos(a) * 0.35);
      camp.add(leg);
    }
    // Warden Sela — standing watch, facing the valley
    const sela = new T.Group();
    const sBody = mesh(geo(new T.CylinderGeometry(0.24, 0.32, 0.95, 7)), flat(0x4e6a76));
    sBody.position.y = 0.5;
    const sHead = mesh(geo(new T.SphereGeometry(0.21, 8, 7)), smooth(0xd9b58c));
    sHead.position.y = 1.13;
    const sHood = mesh(geo(new T.ConeGeometry(0.26, 0.34, 7)), flat(0x3d5560));
    sHood.position.y = 1.3;
    const sStaff = mesh(geo(new T.CylinderGeometry(0.04, 0.05, 1.6, 5)), flat(PAL.bark));
    sStaff.position.set(0.34, 0.8, 0);
    sela.add(sBody, sHead, sHood, sStaff);
    sela.position.set(-1.3, 0, -0.9);
    sela.rotation.y = 1.35; // toward the water
    camp.add(sela);
    // supply crates
    const crate = mesh(geo(new T.BoxGeometry(0.6, 0.5, 0.6)), flat(PAL.wood));
    crate.position.set(-0.2, 0.25, 1.4);
    crate.castShadow = true;
    camp.add(crate);
    camp.position.set(x, y, z);
    camp.rotation.y = -0.5;
    group.add(camp);
    addBoxCol(x, z, 1.4, 0.9, -0.5);
    addCircleCol(x - 1.2, z - 0.8, 0.4); // Sela
    hotspots.push({
      x: x - 1.2, z: z - 1.0, r: 2.0, type: 'npc_warden', id: WARDEN.id,
      label: 'Warden Sela', lines: WARDEN.lines,
    });
  }
  {
    // the sealed gate — VISIBLY sealed, warmly framed (Phase 2 tease).
    // Heavy posts, crossed storm-planks, a coiled rope, and the notice.
    const { x, z } = LANDMARKS.riverbend_gate;
    const y = yAt(x, z);
    const gate = new T.Group();
    const postM = flat(new T.Color(PAL.bark).offsetHSL(0.006, 0.02, -0.02));
    for (const side of [-1, 1]) {
      const post = mesh(geo(new T.CylinderGeometry(0.2, 0.26, 3.1, 7)), postM);
      post.position.set(0, 1.55, side * 2.1);
      post.castShadow = true;
      gate.add(post);
      const cap = mesh(geo(new T.SphereGeometry(0.24, 6, 5)), postM);
      cap.position.set(0, 3.12, side * 2.1);
      gate.add(cap);
    }
    const lintel = mesh(geo(new T.BoxGeometry(0.3, 0.3, 4.7)), postM);
    lintel.position.y = 3.0;
    gate.add(lintel);
    // crossed storm-planks: the "sealed" read, unmistakable at a glance
    for (const rot of [0.5, -0.5]) {
      const plank = mesh(geo(new T.BoxGeometry(0.14, 0.4, 4.6)), flat(new T.Color(PAL.wood).offsetHSL(0, -0.04, -0.1)));
      plank.position.y = 1.5;
      plank.rotation.x = rot;
      plank.castShadow = true;
      gate.add(plank);
    }
    // rope coil at the base — someone SEALED this, tidily; it will open
    const rope = mesh(geo(new T.TorusGeometry(0.3, 0.08, 5, 10)), flat(new T.Color(PAL.wood).offsetHSL(0.01, 0.1, -0.12)));
    rope.rotation.x = -Math.PI / 2;
    rope.position.set(0.3, 0.08, -1.5);
    gate.add(rope);
    // the notice board on the lintel
    const noticeBoard = mesh(geo(new T.BoxGeometry(0.1, 0.6, 2.2)), flat(new T.Color(PAL.wood).offsetHSL(0.004, 0.03, 0.045)));
    noticeBoard.position.set(-0.18, 2.3, 0);
    gate.add(noticeBoard);
    if (ctx.makeTextPlate) {
      const pl = ctx.makeTextPlate('RIVERBEND — ROAD SEALED', { w: 2.0, h: 0.5, bg: '#e8ddc4', fg: '#5a4630' });
      pl.position.set(-0.26, 2.3, 0);
      pl.rotation.y = -Math.PI / 2;
      gate.add(pl);
    }
    gate.position.set(x, y, z);
    group.add(gate);
    // the seal is SOLID: colliders across the gap and flanking rock shoulders
    addBoxCol(x, z, 0.4, 2.4, 0);
    const rockM = flat(new T.Color(PAL.stone).offsetHSL(0.01, 0, -0.05));
    for (const [rx, rz, s] of [[x + 0.4, z + 3.4, 1.5], [x + 0.2, z - 3.4, 1.7], [x - 0.5, z + 4.8, 1.2], [x - 0.3, z - 4.9, 1.3]]) {
      const rock = mesh(geo(new T.DodecahedronGeometry(s, 0)), rockM);
      rock.position.set(rx, yAt(rx, rz) + s * 0.25, rz);
      rock.rotation.set(Math.random(), Math.random() * 3, Math.random());
      rock.castShadow = true;
      group.add(rock);
      addCircleCol(rx, rz, s * 0.85);
    }
    hotspots.push({
      x: x - 1.2, z, r: 2.0, type: 'sealed_gate', id: 'east_road_riverbend_gate',
      label: 'The Riverbend Gate — sealed against the flood',
      line: EXITS[1].lockedLine, unlockPhase: 2,
    });
  }
  {
    // the reveal: flooded valley below the crest. Distant water plane + two
    // drifting mist planes — Riverbend itself is NOT modeled (no two towns
    // visible at ground level; this reveal is the framed exception, kept to
    // silhouette: water, mist, and rain-light. Sound leads: AUDIO.rainFadeStartX.)
    const water = mesh(geo(new T.PlaneGeometry(70, 46)),
      track(new T.MeshStandardMaterial({
        color: SRGB(PAL.waterDeep).lerp(SRGB(0x3b4a56), 0.4),
        roughness: 0.2, metalness: 0.1, transparent: true, opacity: 0.95,
      })));
    water.rotation.x = -Math.PI / 2;
    water.position.set(88, -2.2, 0);
    group.add(water);
    const mistM = track(new T.MeshBasicMaterial({
      color: SRGB(0xbfccd2), transparent: true, opacity: 0.22, depthWrite: false, side: T.DoubleSide,
    }));
    const mists = [];
    for (const [mx, my, mz, w, h] of [[70, 1.2, -6, 40, 5], [76, 2.4, 8, 46, 6]]) {
      const m = new T.Mesh(geo(new T.PlaneGeometry(w, h)), mistM);
      m.position.set(mx, my, mz);
      m.rotation.y = -Math.PI / 2;
      group.add(m);
      mists.push(m);
    }
    anims.push((dt, t) => {
      mists[0].position.z = -6 + Math.sin(t * 0.11) * 3;
      mists[1].position.z = 8 + Math.sin(t * 0.07 + 2) * 4;
    });
  }

  // ---- scatter dressing via ctx (instanced host paths; all optional) ---------
  // Orchard shoulders west, thinning east; pines take over near the crest —
  // the palette drain carried by species, not just tint.
  {
    const oakSpots = [
      [-44, 8], [-40, -6], [-36, 11], [-27, 9], [-24, -8], [-20, 7],
      [-16, -11], [-13, 9], [-2, -12], [1, 8], [8, 10],
    ];
    const pineSpots = [
      [16, -8], [22, 9], [28, -8], [33, 7], [36, -5], [41, 5], [43, -4], [48, 8],
    ];
    const bushSpots = [[-34, 2.2], [-18, -3.8], [-1, -6.2], [13, 3.6], [29, 3.8], [39, -1.8]];
    // Fallback scatter is INSTANCED (perf budget: instanced/merged scatter):
    // one batch per part — trunks, oak canopies, pine cone tiers, bushes —
    // with per-instance PAL-jittered color via setColorAt. 5 draw calls total.
    const useCtxTrees = !!(ctx.makeOak && ctx.makePine);
    if (useCtxTrees) {
      for (const [x, z] of oakSpots) group.add(ctx.makeOak(x, z));
      for (const [x, z] of pineSpots) group.add(ctx.makePine(x, z));
      if (ctx.makeBush) for (const [x, z] of bushSpots) group.add(ctx.makeBush(x, z));
    } else {
      const dummy = new T.Object3D();
      const mkBatch = (g, count) => {
        const inst = new T.InstancedMesh(geo(g), flat(0xffffff), count);
        inst.castShadow = true;
        group.add(inst);
        return inst;
      };
      const setInst = (inst, i, x, y, z, sx, sy, sz, ry, col) => {
        dummy.position.set(x, y, z);
        dummy.rotation.set(0, ry, 0);
        dummy.scale.set(sx, sy, sz);
        dummy.updateMatrix();
        inst.setMatrixAt(i, dummy.matrix);
        inst.setColorAt(i, col);
      };
      const jit = (tok, dh = 0.03, dl = 0.05) =>
        SRGB(tok).offsetHSL((Math.random() - 0.5) * dh, (Math.random() - 0.5) * 0.05, (Math.random() - 0.5) * dl);
      const trunks = mkBatch(new T.CylinderGeometry(0.15, 0.21, 1.2, 5), oakSpots.length + pineSpots.length);
      const blobs = mkBatch(new T.IcosahedronGeometry(1.0, 0), oakSpots.length);
      const cones1 = mkBatch(new T.ConeGeometry(0.9, 1.6, 6), pineSpots.length);
      const cones2 = mkBatch(new T.ConeGeometry(0.55, 1.1, 6), pineSpots.length);
      const bushes = mkBatch(new T.IcosahedronGeometry(0.55, 0), bushSpots.length);
      const barkCol = SRGB(new T.Color(PAL.bark).offsetHSL(0, 0, 0.035).getHex());
      let ti = 0;
      oakSpots.forEach(([x, z], i) => {
        const y = yAt(x, z), s = 0.85 + Math.random() * 0.4;
        setInst(trunks, ti++, x, y + 0.6 * s, z, s, s, s, Math.random() * 3, barkCol);
        setInst(blobs, i, x, y + (1.15 + 0.85) * s, z, s, s * 0.85, s, Math.random() * 3,
          jit([PAL.leafMid, PAL.leafLime, PAL.leafDeep][i % 3]));
      });
      pineSpots.forEach(([x, z], i) => {
        const y = yAt(x, z), s = 0.85 + Math.random() * 0.4;
        const c = jit(PAL.leafDeep, 0.02, 0.04);
        setInst(trunks, ti++, x, y + 0.5 * s, z, s * 0.9, s * 0.85, s * 0.9, Math.random() * 3, barkCol);
        setInst(cones1, i, x, y + 1.5 * s, z, s, s, s, Math.random() * 3, c);
        setInst(cones2, i, x, y + 2.5 * s, z, s, s, s, Math.random() * 3, c.clone().offsetHSL(-0.01, 0.02, 0.04));
      });
      bushSpots.forEach(([x, z], i) => {
        setInst(bushes, i, x, yAt(x, z) + 0.3, z, 1, 0.7, 1, Math.random() * 3, jit(PAL.leafMid));
      });
      for (const inst of [trunks, blobs, cones1, cones2, bushes]) {
        inst.instanceMatrix.needsUpdate = true;
        if (inst.instanceColor) inst.instanceColor.needsUpdate = true;
      }
    }
    for (const [x, z] of oakSpots) addCircleCol(x, z, 0.5);
    for (const [x, z] of pineSpots) addCircleCol(x, z, 0.45);
    // host ambient scatter — instanced single-draw systems; west-weighted so
    // wildflowers thin out as the slate takes over
    if (ctx.addWildflowers) ctx.addWildflowers(46, { x1: -50, z1: -14, x2: 8, z2: 14 });
    if (ctx.addGrass) ctx.addGrass();
    if (ctx.addGroundPatches) ctx.addGroundPatches();
    if (ctx.addForestRing) ctx.addForestRing();
    if (ctx.addMountains) ctx.addMountains();
    if (ctx.addClouds) ctx.addClouds(5);
    if (ctx.addButterflies) ctx.addButterflies(4, 26); // west half only feel
  }

  // ---- atmosphere (optional; single call, transitional tones) ----------------
  // Halfway between Meadow Town cream and Riverbend slate — the audio/visual
  // drain does the per-meter work; atmosphere just meets it in the middle.
  if (ctx.setAtmosphere) {
    const fogMix = new T.Color(PAL.fog).lerp(new T.Color(0xb9c6c9), 0.35).getHex();
    ctx.setAtmosphere(PAL.skyTop, PAL.skyMid, PAL.skyHorizon, fogMix, PAL.sun, 1.35, PAL.ambientSky, PAL.ambientGnd);
  }

  // ---- world edges (soft colliders so nobody walks off the plane) ------------
  addBoxCol(0, 26, 60, 1, 0);
  addBoxCol(0, -26, 60, 1, 0);
  addBoxCol(-52, 0, 1, 26, 0);
  // east edge is the gate rocks + gate collider (already placed)

  // ---- runtime exits/spawns (copies of static data, host format) -------------
  const exits = EXITS.map((e) => ({ ...e, spawn: [...e.spawn] }));
  const spawns = {
    fromMeadowTown: [...SPAWNS.fromMeadowTown],
    fromRiverbend: [...SPAWNS.fromRiverbend],
    default: [...SPAWNS.default],
  };

  // vista beat: first crest arrival — wire phase may run the reveal camera
  // (rain bed is already full here per AUDIO.rainFullX; sound leads sight)
  const revealTrigger = { x: 44.5, z: 0, r: 3.2, id: 'east_road_rise_reveal', once: true };

  // ---- per-frame + teardown --------------------------------------------------
  let elapsed = 0;
  const update = (dt) => {
    elapsed += dt;
    for (const fn of anims) fn(dt, elapsed);
  };
  const dispose = () => {
    if (group.parent) group.parent.remove(group);
    for (const d of disposables) { if (d.dispose) d.dispose(); }
    disposables.length = 0;
    anims.length = 0;
  };

  return {
    id: MAP_ID,
    label: MAP_LABEL,
    zone: ZONE_ID,
    group,
    terrainY,
    spawns,
    exits,
    hotspots,
    colliders,            // populated only when ctx lacks add*Col
    ambushAnchors: AMBUSH_ANCHORS,
    waymarkers,           // id -> {x, z, lit, ...}
    setWaymarkerLit,      // combat layer calls this on patrol clear
    challengeSites: CHALLENGE_SITES,
    travelerAid: TRAVELER_AID_TOBBIN,
    levelGates: LEVEL_GATE_SIGNPOSTS,
    warden: WARDEN,
    audio: AUDIO,
    roadRules: ROAD_RULES,
    revealTrigger,
    update,
    dispose,
  };
}

// =============================================================================
// Dev validation (pure; call from dev console / tests, never in the prod loop).
// Confirms this map fully anchors combat-data's East Road contract.
// =============================================================================
export function validateEastRoadMap() {
  const errors = [];
  for (const enc of EAST_ROAD_ENCOUNTERS) {
    if (!AMBUSH_ANCHORS[enc.ambushPoint]) {
      errors.push(`missing ambush anchor '${enc.ambushPoint}' for encounter ${enc.id}`);
    }
    if (!WAYMARKER_POSITIONS[enc.waymarkerId]) {
      errors.push(`missing waymarker position '${enc.waymarkerId}' for encounter ${enc.id}`);
    }
    const covered = CHALLENGE_SITES.some((s) => s.kind === 'encounter' && s.encounterIds.includes(enc.id));
    if (!covered) errors.push(`encounter ${enc.id} not covered by any challenge site trigger`);
  }
  // every challenge-site encounter id must exist in combat-data
  const known = new Set(EAST_ROAD_ENCOUNTERS.map((e) => e.id));
  for (const site of CHALLENGE_SITES) {
    if (site.kind !== 'encounter') continue;
    for (const id of site.encounterIds) {
      if (!known.has(id)) errors.push(`challenge site ${site.id} references unknown encounter '${id}'`);
    }
  }
  // exactly 2 encounter triggers + 1 traveler-aid vignette (task contract)
  const enc = CHALLENGE_SITES.filter((s) => s.kind === 'encounter').length;
  const aid = CHALLENGE_SITES.filter((s) => s.kind === 'traveler_aid').length;
  if (enc !== 2 || aid !== 1) errors.push(`expected 2 encounter triggers + 1 traveler-aid site, got ${enc}+${aid}`);
  return errors;
}
