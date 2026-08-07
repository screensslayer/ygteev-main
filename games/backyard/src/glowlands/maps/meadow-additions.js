// =============================================================================
// glowlands/maps/meadow-additions.js
// Additive Meadow Town dressing for the Phase 1 gateway slice.
//
// Design authority: /docs/glowlands-design.md
//   Ch. 7   — Meadow Town: layout (Library north edge / Chapel Hill northeast /
//             East Fields / East Gate), visual direction (pre-save desaturation,
//             the Gloom stain creeping 2 m/day along the field run and capping
//             at the fountain's bottom step, the 40-string-lantern save wave
//             chapel -> gate over 6 s, the steeple beacon), the Zohar
//             "Stranger at the Fountain" prologue staging, the five scarred
//             plots that become the town's open public garden plots on save,
//             and the East Gate that opens ONLY on save.
//   Ch. 17  — Phase 1 slice row 7 (Meadow Town full zone) + perf pillar
//             (<=120 added draw calls per map; this module adds ~55).
//   Ch. 3.3 — public garden plots (five scarred plots -> open beds on save).
//
// WHAT THIS MODULE IS
//   * A pure three.js (r128, the pinned dep — no new dependencies, no
//     postprocessing) scene-dressing layer called AFTER the host's buildTown().
//     It adds: the Library building (distinct tall silhouette, readable
//     signage, door trigger), Chapel Hill's small chapel + steeple beacon
//     (save-wave origin), the East Gate arch with its gloom-seal visual,
//     the five scarred plots / public garden area in the East Fields, the
//     Gloom stain + wisps over the fields, the 40 string lanterns, and the
//     Zohar fountain-scene staging marks.
//   * A declarative trigger-zone table (MEADOW_TRIGGERS) the Wire phase folds
//     into the host's own `hotspots` / `exits` polling — this module never
//     reads input and never moves the player.
//   * Cheap pre/post-save visual state: everything animates via uniforms,
//     material lerps and instanced-matrix pops. No geometry rebuilds, no
//     added lights (the beacon is emissive + an additive sprite).
//
// WHAT THIS MODULE IS NOT
//   * It never touches dragon-garden-quest.jsx or any mesh the host built
//     (the fountain's own desaturation on stain-cap is the host fountainFx
//     owner's delta, noted for the Wire phase — we stop at its bottom step).
//   * It owns no game state: saved/restoration/creep/staging are POKED IN by
//     the caller via the handle setters. It persists nothing.
//   * Ember does not appear here. Ember never leaves home in Phase 1.
//
// ctx CONTRACT (Wire phase supplies this; EVERY member optional-safe — with
// no ctx at all, build() still returns a standalone group for dev judging):
//   ctx.THREE        — three namespace (default: the pinned r128 import).
//   ctx.worldGroup   — host scene group; when present we add ourselves to it
//                      (host's clearWorld() then disposes us with the map).
//   ctx.terrainY(x,z)-> ground height (default 0) — buildTown's terrain fn.
//   ctx.addBoxCol(x,z,hw,hd,rot) / ctx.addCircleCol(x,z,r) — host colliders.
//   ctx.colliders    — the host collider ARRAY itself; when given, the East
//                      Gate seal blocker is pushed/spliced here so saving the
//                      town physically opens the arch (mirrors the host's
//                      red-bag collider splice pattern). Without it the gate
//                      stays visual-only and the Wire phase gates the exit.
//   ctx.glowNodes    — host array of meshes that get the night-glow treatment.
//   ctx.isSaved()    — initial saved state (default false).
//   ctx.getRestoration() -> 0..100 initial restoration points (default 0).
//   ctx.getGloomCreepM() -> metres crept along the field run (default 0).
//
// USAGE (Wire phase, inside/after the host buildTown()):
//   import buildMeadowAdditions, { MEADOW_TRIGGERS } from
//     './glowlands/maps/meadow-additions.js';
//   const meadow = buildMeadowAdditions({ worldGroup, terrainY, addBoxCol,
//     addCircleCol, colliders, glowNodes, isSaved: () => G.town.saved, ... });
//   // per frame: meadow.update(dt, t);
//   // on save:   meadow.setSaved(true, { onLantern: (i) => sq(...) });
//   // triggers:  meadow.triggers  (fold into hotspots/exits polling)
//
// SCRIPTURE RULE: no verse text lives here (signage and labels are original
// prose; scripture is fetched at runtime elsewhere via ctx.fetchPassage).
// =============================================================================

import * as THREE_NS from 'three';

// -----------------------------------------------------------------------------
// Tunables (every value the bible marks tunable, plus geometry anchors)
// -----------------------------------------------------------------------------
export const MEADOW_TUNING = Object.freeze({
  saveWaveSec: 6,          // Ch. 7: 40 lanterns ignite chapel -> gate over 6 s
  stainBurnSec: 10,        // Ch. 7 gating: stain burns off the field run in 10 s
  sealClearSec: 2.2,       // gloom-seal dissolve on save
  gateDoorSec: 1.4,        // gate doors swing after the seal clears
  lanternCount: 40,        // Ch. 7: exactly 40 string lanterns
  creepPerDayM: 2,         // Ch. 7: stain creeps 2 m/day (server/wire supplies days)
  fieldRunM: 40,           // the bible's ~40 m field run, mapped onto world units
  // world-space stain geometry: edge starts at the plaza's east lip and can
  // creep to the fountain's bottom step (world x ~2.4) — never past it.
  stainEdgeStartX: 12.0,
  stainEdgeCapX: 2.4,
  plotRestorationPts: 5,   // Ch. 7 §6: each replanted plot = 5 restoration pts
});

// -----------------------------------------------------------------------------
// Palette — values copied from the host's PAL (dragon-garden-quest.jsx stays
// untouched; copying is the sibling-module convention) + gloom set (Ch. 7:
// violet-grey stain, dove grey, faded terracotta).
// -----------------------------------------------------------------------------
const PAL = {
  plaster: 0xefe2c8, roof: 0xb5654a, bark: 0x7a5a3e, stone: 0x9d948a,
  wood: 0xc9b68c, leafMid: 0x619e46, leafDeep: 0x38714a, soil: 0x7a5138,
  pathStone: 0xc7ad7e,
};
const GLOOM = {
  stain: 0x554a6e,      // violet-grey body
  stainDeep: 0x3d3454,  // saturated core
  wisp: 0x8a7ab0,       // drifting motes
  vine: 0x4a3f5c,       // seal thorn-vines
  emberRim: 0xffb845,   // burn-off rim (the game's warm gold)
};
const LANTERN_GLASS_DARK = 0x6a5e50;   // unlit bulb
const LANTERN_GLASS_LIT = 0xffd27a;    // lit bulb (emissive)

// -----------------------------------------------------------------------------
// Trigger zones — declarative, world-space, exported both statically and on
// the build handle. The Wire phase folds these into the host's hotspots/exits
// polling; `requires`/`action` are labels for the wire, not behavior here.
// All positions match the geometry this module builds around the host's
// buildTown() layout (fountain at (0,5), shops at z=-8, east road to x=16).
// -----------------------------------------------------------------------------
export const MEADOW_TRIGGERS = Object.freeze([
  Object.freeze({
    id: 'library_door', kind: 'door', x: -13.3, z: -4.6, r: 1.4,
    label: 'The library — reading desk inside',
    action: 'townbook_open', // wire: townbook.open() (glowlands/townbook.js)
  }),
  Object.freeze({
    id: 'east_gate', kind: 'gate', x: 17.6, z: 0, r: 2.1,
    label: 'The East Gate',
    requires: 'town_saved',        // Ch. 7: opens ONLY when the town is saved
    to: 'EAST_ROAD', spawn: [-26, 0],
    // gentle refusal, lantern-pattern voice — pressure without punishment
    sealedLine: 'A violet seal swirls across the arch. Meadow Town still needs you.',
    farewell: 'eli_east_gate_first_exit', // Ch. 7: scripted, first exit only
  }),
  Object.freeze({
    id: 'fountain_zohar', kind: 'scene', x: 1.8, z: 6.4, r: 3.2,
    label: 'A stranger struggles with a spilled handcart…',
    scene: 'zohar_prologue', // Ch. 7: the compassion test that grants the Lantern
    staging: Object.freeze({
      stranger: Object.freeze([1.5, 6.9]),   // ragged figure by the fountain
      cart: Object.freeze([2.7, 6.1]),       // tipped handcart
      shelter: Object.freeze([-8.2, -4.5]),  // Berry Market awning (walk-the-cart goal)
      bundles: Object.freeze([               // five spilled bundles to regather
        Object.freeze([3.6, 5.4]), Object.freeze([2.1, 7.4]),
        Object.freeze([4.1, 6.9]), Object.freeze([3.2, 7.9]),
        Object.freeze([1.4, 5.0]),
      ]),
    }),
  }),
  // Ch. 7 §6 / Ch. 3.3 — five scarred plots; replant via Rosie's Meadow
  // Replanting Pack; convert to open public garden plots on save.
  Object.freeze({ id: 'public_plot_1', kind: 'plot', x: 13.2, z: 5.2, r: 1.5, action: 'replant', restorationPts: 5 }),
  Object.freeze({ id: 'public_plot_2', kind: 'plot', x: 15.2, z: 4.2, r: 1.5, action: 'replant', restorationPts: 5 }),
  Object.freeze({ id: 'public_plot_3', kind: 'plot', x: 17.0, z: 5.6, r: 1.5, action: 'replant', restorationPts: 5 }),
  Object.freeze({ id: 'public_plot_4', kind: 'plot', x: 14.0, z: 7.2, r: 1.5, action: 'replant', restorationPts: 5 }),
  Object.freeze({ id: 'public_plot_5', kind: 'plot', x: 16.6, z: 7.0, r: 1.5, action: 'replant', restorationPts: 5 }),
]);

export function meadowTriggerById(id) {
  return MEADOW_TRIGGERS.find((t) => t.id === id) || null;
}

// =============================================================================
// build(ctx) — the one entry point
// =============================================================================
export function build(ctx = {}) {
  const THREE = ctx.THREE || THREE_NS;
  const terrainY = typeof ctx.terrainY === 'function' ? ctx.terrainY : () => 0;
  const addBoxCol = typeof ctx.addBoxCol === 'function' ? ctx.addBoxCol : () => {};
  const addCircleCol = typeof ctx.addCircleCol === 'function' ? ctx.addCircleCol : () => {};
  const glowNodes = Array.isArray(ctx.glowNodes) ? ctx.glowNodes : null;

  const group = new THREE.Group();
  group.name = 'meadow-additions';

  // ---- material helpers (host vocabulary, copied not imported) -------------
  const SRGB = (hex) => new THREE.Color(hex).convertSRGBToLinear();
  const asLinear = (c) => (c && c.isColor ? c.clone().convertSRGBToLinear() : SRGB(c));
  const mkMat = (color, base, opts = {}) => {
    const m = new THREE.MeshStandardMaterial({ ...base, ...opts });
    m.color.copy(asLinear(color));
    if (opts.emissive !== undefined) m.emissive.copy(asLinear(opts.emissive));
    return m;
  };
  const flat = (color, opts = {}) =>
    mkMat(color, { roughness: 0.9, metalness: 0.02, flatShading: true }, opts);
  const smooth = (color, opts = {}) =>
    mkMat(color, { roughness: 0.85, metalness: 0.02 }, opts);

  // canvas signage plate (host's makeTextPlate pattern, copied)
  function textPlate(text, o = {}) {
    const w = o.w || 3, h = o.h || 0.7;
    const cv = document.createElement('canvas');
    cv.width = 256; cv.height = Math.max(48, Math.round((256 * h) / w));
    const c2 = cv.getContext('2d');
    c2.fillStyle = o.bg || '#f2e6cc';
    c2.fillRect(0, 0, cv.width, cv.height);
    c2.strokeStyle = o.fg || '#4a3117'; c2.lineWidth = 10;
    c2.strokeRect(6, 6, cv.width - 12, cv.height - 12);
    c2.fillStyle = o.fg || '#4a3117';
    c2.font = `bold ${Math.round(cv.height * 0.4)}px 'Trebuchet MS', sans-serif`;
    c2.textAlign = 'center'; c2.textBaseline = 'middle';
    c2.fillText(text, cv.width / 2, cv.height / 2 + 2);
    const tex = new THREE.CanvasTexture(cv);
    const mm = new THREE.Mesh(
      new THREE.BoxGeometry(w, h, 0.08),
      new THREE.MeshBasicMaterial({ map: tex })
    );
    mm.castShadow = true;
    return mm;
  }

  // soft radial glow sprite (beacon / radiance) — additive, zero lights
  function glowSprite(hex, size) {
    const cv = document.createElement('canvas');
    cv.width = cv.height = 64;
    const c2 = cv.getContext('2d');
    const g = c2.createRadialGradient(32, 32, 2, 32, 32, 31);
    const c = new THREE.Color(hex);
    const rgb = `${Math.round(c.r * 255)},${Math.round(c.g * 255)},${Math.round(c.b * 255)}`;
    g.addColorStop(0, `rgba(${rgb},0.9)`);
    g.addColorStop(0.4, `rgba(${rgb},0.35)`);
    g.addColorStop(1, `rgba(${rgb},0)`);
    c2.fillStyle = g; c2.fillRect(0, 0, 64, 64);
    const sp = new THREE.Sprite(new THREE.SpriteMaterial({
      map: new THREE.CanvasTexture(cv), transparent: true, depthWrite: false,
      blending: THREE.AdditiveBlending,
    }));
    sp.scale.set(size, size, 1);
    return sp;
  }

  // gabled building body (host's makeBuilding silhouette language, copied)
  function buildingBody(w, d, h, wallC, roofC, riseMul = 0.36) {
    const b = new THREE.Group();
    const hd2 = d / 2, rise = d * riseMul;
    const prof = new THREE.Shape();
    prof.moveTo(-hd2, 0); prof.lineTo(hd2, 0); prof.lineTo(hd2, h);
    prof.lineTo(0, h + rise); prof.lineTo(-hd2, h); prof.lineTo(-hd2, 0);
    const geo = new THREE.ExtrudeGeometry(prof, { depth: w, bevelEnabled: false });
    geo.translate(0, 0, -w / 2);
    const walls = new THREE.Mesh(geo, flat(wallC));
    walls.rotation.y = Math.PI / 2;
    walls.castShadow = true; walls.receiveShadow = true;
    b.add(walls);
    const slopeLen = Math.hypot(hd2 + 0.3, rise) + 0.15;
    const ang = Math.atan2(rise, hd2 + 0.3);
    [1, -1].forEach((sign) => {
      const slab = new THREE.Mesh(
        new THREE.BoxGeometry(w + 0.7, 0.13, slopeLen),
        flat(roofC, { roughness: 0.8 })
      );
      slab.rotation.x = sign * ang;
      slab.position.set(0, h + rise / 2 + 0.04, (sign * (hd2 + 0.3)) / 2);
      slab.castShadow = true;
      b.add(slab);
    });
    const cap = new THREE.Mesh(new THREE.BoxGeometry(w + 0.8, 0.13, 0.3), flat(roofC));
    cap.position.y = h + rise + 0.05; cap.castShadow = true;
    b.add(cap);
    return { group: b, rise };
  }

  const M = new THREE.Matrix4();
  const Q0 = new THREE.Quaternion();
  const setInst = (mesh, i, x, y, z, sx = 1, sy = 1, sz = 1, rotY = 0) => {
    M.compose(
      new THREE.Vector3(x, y, z),
      rotY ? new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 1, 0), rotY) : Q0,
      new THREE.Vector3(sx, sy, sz)
    );
    mesh.setMatrixAt(i, M);
  };

  // ===========================================================================
  // 1. THE LIBRARY (north edge of the square, west of Berry Market)
  //    Distinct silhouette: tallest facade on the row, steep roof, arched
  //    door, round rose window, ivy — "ivy-covered, tallest interior" (Ch. 7).
  // ===========================================================================
  const LX = -13.3, LZ = -7.6, LW = 4.4, LD = 4.4, LH = 3.4;
  {
    const ly = terrainY(LX, LZ);
    const lib = new THREE.Group();
    const body = buildingBody(LW, LD, LH, PAL.plaster, 0x5a6e9c, 0.5); // steep slate-blue roof
    lib.add(body.group);

    // arched double door (recessed, wood) — the silhouette read at street level
    const door = new THREE.Mesh(
      new THREE.BoxGeometry(1.15, 1.55, 0.1),
      flat(new THREE.Color(PAL.bark).offsetHSL(0, 0.02, -0.06))
    );
    door.position.set(0, 0.78, LD / 2 + 0.05);
    const arch = new THREE.Mesh(
      new THREE.CylinderGeometry(0.58, 0.58, 0.1, 10, 1, false, 0, Math.PI),
      flat(new THREE.Color(PAL.bark).offsetHSL(0, 0.02, -0.06))
    );
    arch.rotation.x = Math.PI / 2; arch.rotation.z = Math.PI / 2;
    arch.position.set(0, 1.55, LD / 2 + 0.05);
    lib.add(door, arch);

    // rose window under the gable — glows softly (reading light, no lamp mesh)
    const rose = new THREE.Mesh(
      new THREE.CircleGeometry(0.42, 10),
      smooth(0x9fd0e8, { emissive: 0xfff2c0, emissiveIntensity: 0.45, roughness: 0.2 })
    );
    rose.position.set(0, LH + 0.55, LD / 2 + 0.07);
    // two tall side windows
    const winGeo = new THREE.BoxGeometry(0.5, 1.0, 0.1);
    const winMat = smooth(0x9fd0e8, { emissive: 0xfff2c0, emissiveIntensity: 0.3, roughness: 0.2 });
    const winL = new THREE.Mesh(winGeo, winMat); winL.position.set(-1.35, 1.6, LD / 2 + 0.06);
    const winR = new THREE.Mesh(winGeo, winMat); winR.position.set(1.35, 1.6, LD / 2 + 0.06);
    lib.add(rose, winL, winR);
    if (glowNodes) glowNodes.push(rose, winL, winR);

    // readable signage: book-brown on parchment, mounted over the door
    const sign = textPlate('LIBRARY', { w: 2.5, h: 0.6, bg: '#f0e6cf', fg: '#4a3117' });
    sign.position.set(0, 2.65, LD / 2 + 0.12);
    lib.add(sign);

    // stone doorstep
    const step = new THREE.Mesh(
      new THREE.BoxGeometry(1.7, 0.16, 0.8),
      flat(new THREE.Color(PAL.stone).offsetHSL(0, 0, 0.04))
    );
    step.position.set(0, 0.08, LD / 2 + 0.5);
    lib.add(step);

    // ivy: one InstancedMesh of flattened icosa tufts climbing the east corner
    const ivyGeo = new THREE.IcosahedronGeometry(0.34, 0);
    const ivy = new THREE.InstancedMesh(ivyGeo, flat(PAL.leafDeep), 12);
    for (let i = 0; i < 12; i++) {
      const t = i / 11;
      setInst(
        ivy, i,
        LW / 2 - 0.1 + Math.sin(i * 2.3) * 0.22,            // hugging the east wall
        0.5 + t * (LH + 0.4),
        (t - 0.5) * 1.6 + Math.cos(i * 1.7) * 0.5,
        0.8 + Math.sin(i * 3.1) * 0.25, 0.7, 0.8
      );
    }
    ivy.instanceMatrix.needsUpdate = true;
    ivy.castShadow = true;
    lib.add(ivy);

    lib.position.set(LX, ly, LZ);
    group.add(lib);
    addBoxCol(LX, LZ, LW / 2 + 0.1, LD / 2 + 0.1, 0);
  }

  // ===========================================================================
  // 2. CHAPEL HILL (northeast) — small chapel + steeple beacon.
  //    The save wave originates here ("chapel to gate", Ch. 7); the steeple
  //    beacon is a slow-pulsing gold EMISSIVE + additive sprite (no light).
  //    The steeple is Ember's ENDGAME landing pad — nothing lands in Phase 1.
  // ===========================================================================
  let beacon = null, beaconCore = null;
  const CHAPEL = { x: 12.2, z: -15.2 };
  {
    const cy = terrainY(CHAPEL.x, CHAPEL.z);
    const ch = new THREE.Group();
    const body = buildingBody(3.0, 2.6, 2.2, PAL.plaster, PAL.roof, 0.55);
    ch.add(body.group);
    // steeple tower + spire on the ridge
    const tower = new THREE.Mesh(new THREE.BoxGeometry(0.9, 1.6, 0.9), flat(PAL.plaster));
    tower.position.set(0, 2.2 + 2.6 * 0.55 + 0.7, 0); tower.castShadow = true;
    const spire = new THREE.Mesh(new THREE.ConeGeometry(0.72, 1.2, 4), flat(PAL.roof));
    spire.rotation.y = Math.PI / 4;
    spire.position.set(0, tower.position.y + 1.35, 0); spire.castShadow = true;
    // beacon core: small emissive orb in the tower's louver
    beaconCore = new THREE.Mesh(
      new THREE.SphereGeometry(0.18, 8, 6),
      smooth(0xffe9b0, { emissive: 0xffd27a, emissiveIntensity: 0.5, roughness: 0.3 })
    );
    beaconCore.position.set(0, tower.position.y + 0.25, 0.5);
    beacon = glowSprite(0xffd88a, 2.4);
    beacon.position.copy(beaconCore.position);
    ch.add(tower, spire, beaconCore, beacon);
    if (glowNodes) glowNodes.push(beaconCore);
    ch.position.set(CHAPEL.x, cy - 0.05, CHAPEL.z);
    group.add(ch);
    addBoxCol(CHAPEL.x, CHAPEL.z, 1.7, 1.5, 0);
  }

  // ===========================================================================
  // 3. THE EAST GATE (end of the east road, x ~16.4) + GLOOM SEAL
  //    Two stone pillars + timber arch; a swirling violet seal plane fills the
  //    opening pre-save (ShaderMaterial — allowed; NOT postprocessing), with
  //    thorn-vine arcs at its foot. On save: seal dissolves (2.2 s), vines
  //    sink, doors swing open, gate lanterns ignite. The physical blocker is
  //    pushed into ctx.colliders (if given) and spliced out on save.
  // ===========================================================================
  const GATE = { x: 16.4, halfSpan: 1.55, height: 3.0 };
  let sealMat = null, sealMesh = null, vines = null;
  let doorL = null, doorR = null, sealColObj = null;
  let gateBulbDark = null, gateBulbLit = null;
  {
    const gGroup = new THREE.Group();
    const gy = terrainY(GATE.x, 0);
    const pillarGeo = new THREE.BoxGeometry(0.8, GATE.height, 0.8);
    const pillarMat = flat(new THREE.Color(PAL.stone).offsetHSL(0, 0, 0.02));
    [-1, 1].forEach((s) => {
      const p = new THREE.Mesh(pillarGeo, pillarMat);
      p.position.set(GATE.x, gy + GATE.height / 2, s * GATE.halfSpan);
      p.castShadow = true;
      gGroup.add(p);
      addBoxCol(GATE.x, s * GATE.halfSpan, 0.5, 0.5, 0);
    });
    // timber arch beam + little roof cap (faded terracotta — Ch. 7 palette)
    const beam = new THREE.Mesh(
      new THREE.BoxGeometry(0.5, 0.45, GATE.halfSpan * 2 + 1.0),
      flat(PAL.bark)
    );
    beam.position.set(GATE.x, gy + GATE.height + 0.2, 0); beam.castShadow = true;
    const gcap = new THREE.Mesh(
      new THREE.BoxGeometry(1.3, 0.14, GATE.halfSpan * 2 + 1.5),
      flat(new THREE.Color(PAL.roof).offsetHSL(0, -0.12, 0.04))
    );
    gcap.position.set(GATE.x, gy + GATE.height + 0.5, 0); gcap.castShadow = true;
    gGroup.add(beam, gcap);

    // swing doors (timber, hinged at the pillars; closed pre-save)
    const doorLeaf = GATE.halfSpan - 0.12;
    const doorGeoL = new THREE.BoxGeometry(0.12, 1.9, doorLeaf);
    doorGeoL.translate(0, 0, -doorLeaf / 2); // hinge at +z end, leaf toward center
    const doorGeoR = new THREE.BoxGeometry(0.12, 1.9, doorLeaf);
    doorGeoR.translate(0, 0, doorLeaf / 2);  // hinge at -z end, leaf toward center
    const doorMat = flat(new THREE.Color(PAL.bark).offsetHSL(0.01, 0, 0.03));
    doorL = new THREE.Mesh(doorGeoL, doorMat);
    doorL.position.set(GATE.x, gy + 0.95, GATE.halfSpan - 0.15);
    doorR = new THREE.Mesh(doorGeoR, doorMat);
    doorR.position.set(GATE.x, gy + 0.95, -(GATE.halfSpan - 0.15));
    doorL.castShadow = doorR.castShadow = true;
    gGroup.add(doorL, doorR);

    // the gloom seal — one plane, one shader, alpha swirl; uClear dissolves it
    sealMat = new THREE.ShaderMaterial({
      transparent: true, depthWrite: false, side: THREE.DoubleSide,
      uniforms: {
        uTime: { value: 0 },
        uClear: { value: 0 },
        uCol: { value: SRGB(GLOOM.stain) },
        uColDeep: { value: SRGB(GLOOM.stainDeep) },
        uRim: { value: SRGB(GLOOM.emberRim) },
      },
      vertexShader: `
        varying vec2 vUv;
        void main() {
          vUv = uv;
          gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
        }`,
      fragmentShader: `
        uniform float uTime, uClear;
        uniform vec3 uCol, uColDeep, uRim;
        varying vec2 vUv;
        // cheap value noise — good enough for smoke, free on mobile
        float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
        float noise(vec2 p){
          vec2 i = floor(p), f = fract(p);
          f = f * f * (3.0 - 2.0 * f);
          return mix(mix(hash(i), hash(i + vec2(1,0)), f.x),
                     mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), f.x), f.y);
        }
        void main() {
          vec2 p = vUv * 4.0;
          float sw = noise(p + vec2(uTime * 0.22, -uTime * 0.13))
                   + 0.5 * noise(p * 2.3 + vec2(-uTime * 0.31, uTime * 0.17));
          sw /= 1.5;
          // soft oval falloff inside the arch
          vec2 c = vUv - 0.5;
          float edge = smoothstep(0.52, 0.30, length(c * vec2(1.0, 1.25)));
          // dissolve: noise-thresholded burn with a warm rim (save moment)
          float keep = smoothstep(uClear - 0.12, uClear + 0.02, sw);
          float rim = smoothstep(uClear - 0.05, uClear, sw)
                    * (1.0 - smoothstep(uClear, uClear + 0.06, sw));
          vec3 col = mix(uColDeep, uCol, sw) + uRim * rim * 2.0;
          float a = edge * (0.55 + 0.30 * sw) * keep * (1.0 - step(0.999, uClear));
          gl_FragColor = vec4(col, a);
        }`,
    });
    sealMesh = new THREE.Mesh(
      new THREE.PlaneGeometry(GATE.halfSpan * 2 - 0.2, GATE.height - 0.3),
      sealMat
    );
    sealMesh.rotation.y = Math.PI / 2;
    sealMesh.position.set(GATE.x, gy + GATE.height / 2 + 0.1, 0);
    gGroup.add(sealMesh);

    // thorn-vine arcs at the seal's foot (one InstancedMesh; sink on clear)
    const vineGeo = new THREE.TorusGeometry(0.5, 0.05, 5, 10, Math.PI);
    vines = new THREE.InstancedMesh(vineGeo, flat(GLOOM.vine), 8);
    for (let i = 0; i < 8; i++) {
      const z = -GATE.halfSpan + 0.35 + (i / 7) * (GATE.halfSpan * 2 - 0.7);
      setInst(
        vines, i, GATE.x + Math.sin(i * 2.1) * 0.15, gy + 0.02, z,
        0.7 + (i % 3) * 0.25, 0.8 + (i % 2) * 0.5, 1, Math.PI / 2 + Math.sin(i) * 0.4
      );
    }
    vines.instanceMatrix.needsUpdate = true;
    gGroup.add(vines);

    // gate lanterns on both pillars: dark pre-save, lit post-save (mesh swap)
    const bulbGeo = new THREE.SphereGeometry(0.14, 8, 6);
    gateBulbDark = new THREE.InstancedMesh(bulbGeo, flat(LANTERN_GLASS_DARK), 2);
    gateBulbLit = new THREE.InstancedMesh(
      bulbGeo,
      smooth(LANTERN_GLASS_LIT, { emissive: 0xffb845, emissiveIntensity: 0.9, roughness: 0.3 })
    , 2);
    [-1, 1].forEach((s, i) => {
      setInst(gateBulbDark, i, GATE.x - 0.1, gy + GATE.height - 0.35, s * (GATE.halfSpan + 0.28));
      setInst(gateBulbLit, i, GATE.x - 0.1, gy + GATE.height - 0.35, s * (GATE.halfSpan + 0.28), 0.001, 0.001, 0.001);
    });
    gateBulbDark.instanceMatrix.needsUpdate = true;
    gateBulbLit.instanceMatrix.needsUpdate = true;
    gGroup.add(gateBulbDark, gateBulbLit);
    if (glowNodes) glowNodes.push(gateBulbLit);

    group.add(gGroup);

    // physical blocker across the opening while sealed
    if (Array.isArray(ctx.colliders)) {
      sealColObj = { type: 'b', x: GATE.x, z: 0, hw: 0.35, hd: GATE.halfSpan, rot: 0 };
      ctx.colliders.push(sealColObj);
    } else {
      // no collider array handed over: the Wire phase must gate the EAST_ROAD
      // exit on triggers[east_gate].requires === 'town_saved' instead.
      sealColObj = null;
    }
  }

  // ===========================================================================
  // 4. PUBLIC GARDEN PLOTS (East Fields) — five scarred plots.
  //    Pre-save/unreplanted: grey-violet crust over dead soil, leaning fence.
  //    Replanted (each): crust shrinks away, soil warms, sprouts spring up.
  //    Post-save: "PUBLIC GARDEN" sign appears — the beds the player healed
  //    become the beds they grow in (Ch. 3.3). All state = instanced matrices
  //    + material color lerps; zero rebuilds.
  // ===========================================================================
  const PLOTS = MEADOW_TRIGGERS.filter((t) => t.kind === 'plot')
    .map((t) => ({ id: t.id, x: t.x, z: t.z, y: terrainY(t.x, t.z) }));
  let plotSoil = null, plotScar = null, plotSprouts = null, plotSign = null;
  let fencePosts = null, fenceRails = null;
  const SPROUTS_PER_PLOT = 4;
  const plotState = PLOTS.map(() => ({ replanted: false, anim: 0 })); // anim 0..1
  {
    const soilGeo = new THREE.BoxGeometry(2.2, 0.18, 1.6);
    plotSoil = new THREE.InstancedMesh(
      soilGeo,
      flat(new THREE.Color(PAL.soil).offsetHSL(0, -0.22, -0.08)) // dead grey-brown
    , PLOTS.length);
    const scarGeo = new THREE.IcosahedronGeometry(0.9, 0);
    plotScar = new THREE.InstancedMesh(scarGeo, flat(GLOOM.stainDeep), PLOTS.length);
    const sproutGeo = new THREE.ConeGeometry(0.16, 0.55, 5);
    plotSprouts = new THREE.InstancedMesh(sproutGeo, flat(PAL.leafMid), PLOTS.length * SPROUTS_PER_PLOT);
    PLOTS.forEach((p, i) => {
      const rot = Math.sin(i * 7.3) * 0.4;
      setInst(plotSoil, i, p.x, p.y + 0.09, p.z, 1, 1, 1, rot);
      setInst(plotScar, i, p.x, p.y + 0.1, p.z, 1.1, 0.14, 0.8, rot + 0.5);
      for (let s = 0; s < SPROUTS_PER_PLOT; s++) {
        const a = (s / SPROUTS_PER_PLOT) * Math.PI * 2 + i;
        setInst(
          plotSprouts, i * SPROUTS_PER_PLOT + s,
          p.x + Math.cos(a) * 0.55, p.y + 0.2, p.z + Math.sin(a) * 0.38,
          0.001, 0.001, 0.001 // hidden until replanted
        );
      }
    });
    plotSoil.instanceMatrix.needsUpdate = true;
    plotScar.instanceMatrix.needsUpdate = true;
    plotSprouts.instanceMatrix.needsUpdate = true;
    plotSoil.receiveShadow = true;
    group.add(plotSoil, plotScar, plotSprouts);

    // low leaning fence ringing the plot area — posts + rails, 2 draw calls
    const ring = [ // loose pentagon around the five plots
      [11.9, 3.4], [16.6, 2.8], [18.4, 5.8], [15.6, 8.6], [12.4, 7.6],
    ];
    const postGeo = new THREE.BoxGeometry(0.14, 0.9, 0.14);
    fencePosts = new THREE.InstancedMesh(postGeo, flat(PAL.wood), ring.length * 3);
    const railGeo = new THREE.BoxGeometry(1, 0.08, 0.1);
    fenceRails = new THREE.InstancedMesh(railGeo, flat(new THREE.Color(PAL.wood).offsetHSL(0, 0, -0.05)), ring.length);
    let pi = 0;
    ring.forEach((a, i) => {
      const b = ring[(i + 1) % ring.length];
      const mx = (a[0] + b[0]) / 2, mz = (a[1] + b[1]) / 2;
      const len = Math.hypot(b[0] - a[0], b[1] - a[1]);
      const ang = Math.atan2(-(b[1] - a[1]), b[0] - a[0]);
      for (let s = 0; s < 3; s++) {
        const t = s / 2;
        const px = a[0] + (b[0] - a[0]) * t, pz = a[1] + (b[1] - a[1]) * t;
        // pre-save lean baked in via slight random rotY only (cheap)
        setInst(fencePosts, pi++, px, terrainY(px, pz) + 0.42, pz, 1, 1, 1, Math.sin(pi * 5.1) * 0.2);
      }
      setInst(fenceRails, i, mx, terrainY(mx, mz) + 0.68, mz, len, 1, 1, ang);
    });
    fencePosts.instanceMatrix.needsUpdate = true;
    fenceRails.instanceMatrix.needsUpdate = true;
    fencePosts.castShadow = true;
    group.add(fencePosts, fenceRails);

    // "PUBLIC GARDEN" sign — hidden until the town is saved
    plotSign = textPlate('PUBLIC GARDEN', { w: 2.6, h: 0.62, bg: '#eaf6d8', fg: '#1d5a2a' });
    const sy = terrainY(12.1, 3.0);
    plotSign.position.set(12.1, sy + 1.35, 3.0);
    plotSign.rotation.y = -0.5;
    plotSign.visible = false;
    const signPost = new THREE.Mesh(new THREE.BoxGeometry(0.14, 1.3, 0.14), flat(PAL.wood));
    signPost.position.set(12.1, sy + 0.65, 3.0);
    signPost.visible = false;
    plotSign.userData.post = signPost;
    group.add(plotSign, signPost);
  }

  // ===========================================================================
  // 5. GLOOM STAIN + WISPS (East Fields -> field run toward the square)
  //    One shader plane hovering just over the grass: violet-grey mottle whose
  //    WEST EDGE (uEdgeX) creeps toward the fountain at 2 m/day (caller feeds
  //    metres via setGloomCreepM). It caps at the fountain's bottom step and
  //    NEVER enters an interior or blocks a doorway (Ch. 7 — pressure without
  //    punishment). On save it burns off west-to-east over 10 s with a warm
  //    rim (uBurnX sweep). The fountain's own water desaturation at cap
  //    belongs to the host's fountainFx owner — noted for the Wire phase.
  // ===========================================================================
  let stainMat = null, stainMesh = null, wisps = null, wispMat = null;
  const WISP_COUNT = 60;
  const wispSeeds = [];
  {
    stainMat = new THREE.ShaderMaterial({
      transparent: true, depthWrite: false,
      uniforms: {
        uTime: { value: 0 },
        uEdgeX: { value: MEADOW_TUNING.stainEdgeStartX }, // world-x of the creep edge
        uBurnX: { value: -100 },                          // burn sweep (save); <edge = off
        uCol: { value: SRGB(GLOOM.stain) },
        uColDeep: { value: SRGB(GLOOM.stainDeep) },
        uRim: { value: SRGB(GLOOM.emberRim) },
      },
      vertexShader: `
        varying vec2 vUv; varying vec3 vW;
        void main() {
          vUv = uv;
          vec4 w = modelMatrix * vec4(position, 1.0);
          vW = w.xyz;
          gl_Position = projectionMatrix * viewMatrix * w;
        }`,
      fragmentShader: `
        uniform float uTime, uEdgeX, uBurnX;
        uniform vec3 uCol, uColDeep, uRim;
        varying vec2 vUv; varying vec3 vW;
        float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
        float noise(vec2 p){
          vec2 i = floor(p), f = fract(p);
          f = f * f * (3.0 - 2.0 * f);
          return mix(mix(hash(i), hash(i + vec2(1,0)), f.x),
                     mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), f.x), f.y);
        }
        void main() {
          float n = noise(vW.xz * 0.55 + vec2(uTime * 0.05, uTime * 0.03))
                  + 0.5 * noise(vW.xz * 1.4 - vec2(uTime * 0.08, 0.0));
          n /= 1.5;
          // west creep edge: ragged by noise, soft over ~2.5 units
          float edge = smoothstep(uEdgeX - 1.2 + n * 2.0, uEdgeX + 1.8 + n * 2.0, vW.x);
          // plane-border fade so the rectangle never reads as a rectangle
          vec2 b = min(vUv, 1.0 - vUv);
          float border = smoothstep(0.0, 0.14, min(b.x, b.y));
          // save burn-off: everything west of uBurnX is gone, warm rim at the front
          float burnKeep = smoothstep(uBurnX, uBurnX + 1.2, vW.x);
          float rim = smoothstep(uBurnX - 0.5, uBurnX + 0.3, vW.x)
                    * (1.0 - smoothstep(uBurnX + 0.3, uBurnX + 1.6, vW.x));
          vec3 col = mix(uColDeep, uCol, n) + uRim * rim * 1.6;
          float a = edge * border * (0.34 + 0.22 * n) * burnKeep;
          gl_FragColor = vec4(col, a);
        }`,
    });
    const stainGeo = new THREE.PlaneGeometry(26, 20, 1, 1);
    stainGeo.rotateX(-Math.PI / 2);
    stainMesh = new THREE.Mesh(stainGeo, stainMat);
    stainMesh.position.set(13, 0.42, 3); // hovers over the field grass
    stainMesh.renderOrder = 2;
    group.add(stainMesh);

    // drifting wisp motes over the stained fields (one Points draw)
    const wp = new Float32Array(WISP_COUNT * 3);
    for (let i = 0; i < WISP_COUNT; i++) {
      const x = 4 + Math.random() * 20, z = -5 + Math.random() * 16;
      wp[i * 3] = x; wp[i * 3 + 1] = terrainY(x, z) + 0.5 + Math.random() * 1.4; wp[i * 3 + 2] = z;
      wispSeeds.push({ ph: Math.random() * Math.PI * 2, sp: 0.15 + Math.random() * 0.25, y0: wp[i * 3 + 1] });
    }
    const wgeo = new THREE.BufferGeometry();
    wgeo.setAttribute('position', new THREE.BufferAttribute(wp, 3));
    wispMat = new THREE.PointsMaterial({
      color: SRGB(GLOOM.wisp), size: 0.09, transparent: true, opacity: 0.5,
      depthWrite: false, blending: THREE.AdditiveBlending, sizeAttenuation: true,
    });
    wisps = new THREE.Points(wgeo, wispMat);
    group.add(wisps);
  }

  // ===========================================================================
  // 6. STRING LANTERNS — 40 bulbs strung chapel -> square -> East Gate.
  //    Wire = one LineSegments; bulbs = TWO InstancedMeshes (dark glass /
  //    emissive lit) swapped per-index by matrix scale during the 6 s save
  //    wave, in path order from the chapel (Ch. 7 save-transformation).
  // ===========================================================================
  let bulbsDark = null, bulbsLit = null;
  const lanternPts = []; // world positions in wave order (chapel first)
  {
    const path = [
      [12.2, -13.6], [11.0, -9.0], [6.0, -6.0], [0.0, -6.2], [-7.0, -6.2],
      [-13.0, -6.0], [-14.6, 0.0], [-9.0, 5.5], [-2.5, 8.6], [4.0, 8.2],
      [9.5, 5.0], [12.5, 2.0], [16.2, 0.8],
    ];
    // cumulative length -> evenly spaced lantern points with catenary sag
    const segLens = [];
    let total = 0;
    for (let i = 0; i < path.length - 1; i++) {
      const l = Math.hypot(path[i + 1][0] - path[i][0], path[i + 1][1] - path[i][1]);
      segLens.push(l); total += l;
    }
    const N = MEADOW_TUNING.lanternCount;
    for (let i = 0; i < N; i++) {
      const d = (i / (N - 1)) * total;
      let acc = 0, si = 0;
      while (si < segLens.length - 1 && acc + segLens[si] < d) { acc += segLens[si]; si++; }
      const t = segLens[si] > 0 ? (d - acc) / segLens[si] : 0;
      const x = path[si][0] + (path[si + 1][0] - path[si][0]) * t;
      const z = path[si][1] + (path[si + 1][1] - path[si][1]) * t;
      // sag: dip mid-segment; slight per-lantern jitter keeps it hand-strung
      const sag = Math.sin(t * Math.PI) * 0.35 + Math.sin(i * 3.7) * 0.06;
      lanternPts.push(new THREE.Vector3(x, terrainY(x, z) + 3.3 - sag, z));
    }
    // wire
    const wirePos = new Float32Array((N - 1) * 6);
    for (let i = 0; i < N - 1; i++) {
      wirePos.set([...lanternPts[i].toArray(), ...lanternPts[i + 1].toArray()], i * 6);
    }
    const wireGeo = new THREE.BufferGeometry();
    wireGeo.setAttribute('position', new THREE.BufferAttribute(wirePos, 3));
    const wire = new THREE.LineSegments(
      wireGeo,
      new THREE.LineBasicMaterial({ color: SRGB(0x4a4038), transparent: true, opacity: 0.7 })
    );
    group.add(wire);
    // bulbs (hang 0.18 under the wire)
    const bulbGeo = new THREE.SphereGeometry(0.11, 7, 6);
    bulbsDark = new THREE.InstancedMesh(bulbGeo, flat(LANTERN_GLASS_DARK), N);
    bulbsLit = new THREE.InstancedMesh(
      bulbGeo,
      smooth(LANTERN_GLASS_LIT, { emissive: 0xffc85e, emissiveIntensity: 1.0, roughness: 0.3 })
    , N);
    lanternPts.forEach((p, i) => {
      setInst(bulbsDark, i, p.x, p.y - 0.18, p.z);
      setInst(bulbsLit, i, p.x, p.y - 0.18, p.z, 0.001, 0.001, 0.001);
    });
    bulbsDark.instanceMatrix.needsUpdate = true;
    bulbsLit.instanceMatrix.needsUpdate = true;
    group.add(bulbsDark, bulbsLit);
    if (glowNodes) glowNodes.push(bulbsLit);
  }

  // ===========================================================================
  // 7. ZOHAR SCENE STAGING (the fountain beat, Ch. 7 prologue)
  //    Static stage props the prologue director (wire/beat code) shows/hides:
  //    tipped handcart, five spilled bundles, a bedroll where the ragged
  //    stranger waits, and three faint gold stage-marks (stranger / cart /
  //    shelter). Positions mirror triggers[fountain_zohar].staging exactly.
  //    Stage flow: 'hidden' -> 'spilled' -> (setBundlesGathered(n)) ->
  //    'revealed' (cart righted, radiance up) -> 'done' (all cleared).
  // ===========================================================================
  const STAGING = meadowTriggerById('fountain_zohar').staging;
  const zohar = { stage: 'hidden', gathered: 0 };
  let cartGroup = null, bundles = null, marks = null, bedroll = null, radiance = null;
  {
    const zg = new THREE.Group();
    // handcart: body + 2 wheels + handle + 2 rails (6 small meshes)
    cartGroup = new THREE.Group();
    const cartWood = flat(new THREE.Color(PAL.wood).offsetHSL(0, -0.08, -0.06));
    const bed = new THREE.Mesh(new THREE.BoxGeometry(1.3, 0.12, 0.8), cartWood);
    const railGeo2 = new THREE.BoxGeometry(1.3, 0.22, 0.08);
    const railA = new THREE.Mesh(railGeo2, cartWood); railA.position.set(0, 0.17, 0.36);
    const railB = new THREE.Mesh(railGeo2, cartWood); railB.position.set(0, 0.17, -0.36);
    const wheelGeo = new THREE.CylinderGeometry(0.3, 0.3, 0.08, 9);
    const wheelMat = flat(new THREE.Color(PAL.bark).offsetHSL(0, 0, -0.04));
    const wA = new THREE.Mesh(wheelGeo, wheelMat);
    wA.rotation.x = Math.PI / 2; wA.position.set(-0.35, -0.05, 0.46);
    const wB = new THREE.Mesh(wheelGeo, wheelMat);
    wB.rotation.x = Math.PI / 2; wB.position.set(-0.35, -0.05, -0.46);
    const handle = new THREE.Mesh(new THREE.BoxGeometry(0.9, 0.07, 0.07), cartWood);
    handle.position.set(0.95, 0.1, 0); handle.rotation.z = 0.25;
    cartGroup.add(bed, railA, railB, wA, wB, handle);
    cartGroup.traverse((o) => { if (o.isMesh) o.castShadow = true; });
    const [cx, cz] = STAGING.cart;
    cartGroup.position.set(cx, terrainY(cx, cz) + 0.42, cz);
    cartGroup.rotation.set(0, 0.7, 0.55); // tipped on its side (pre-help pose)
    zg.add(cartGroup);

    // spilled bundles — one InstancedMesh; regathered ones scale away
    const bundleGeo = new THREE.BoxGeometry(0.34, 0.24, 0.26);
    bundles = new THREE.InstancedMesh(
      bundleGeo,
      flat(new THREE.Color(0xc9a86a), { roughness: 1 }) // burlap
    , STAGING.bundles.length);
    STAGING.bundles.forEach(([bx, bz], i) => {
      setInst(bundles, i, bx, terrainY(bx, bz) + 0.13, bz, 1, 1, 1, i * 1.3);
    });
    bundles.instanceMatrix.needsUpdate = true;
    bundles.castShadow = true;
    zg.add(bundles);

    // the stranger's bedroll by the fountain step (he owns almost nothing)
    bedroll = new THREE.Mesh(
      new THREE.CylinderGeometry(0.16, 0.16, 0.8, 7),
      flat(0x8a7a68, { roughness: 1 })
    );
    const [sx, sz] = STAGING.stranger;
    bedroll.rotation.z = Math.PI / 2;
    bedroll.position.set(sx - 0.5, terrainY(sx, sz) + 0.16, sz + 0.4);
    zg.add(bedroll);

    // three faint gold stage-marks: stranger / cart / shelter walk-target
    const markGeo = new THREE.TorusGeometry(0.5, 0.035, 5, 18);
    marks = new THREE.InstancedMesh(
      markGeo,
      new THREE.MeshBasicMaterial({
        color: SRGB(0xffd27a), transparent: true, opacity: 0.35,
        depthWrite: false, blending: THREE.AdditiveBlending,
      })
    , 3);
    [STAGING.stranger, STAGING.cart, STAGING.shelter].forEach(([mx, mz], i) => {
      M.makeRotationX(-Math.PI / 2);
      M.setPosition(mx, terrainY(mx, mz) + 0.06, mz);
      marks.setMatrixAt(i, M);
    });
    marks.instanceMatrix.needsUpdate = true;
    zg.add(marks);

    // the reveal radiance — additive sprite, popped for the Zohar moment
    radiance = glowSprite(0xfff1c0, 4.5);
    radiance.position.set(sx, terrainY(sx, sz) + 1.2, sz);
    radiance.material.opacity = 0;
    zg.add(radiance);

    zg.visible = false; // 'hidden' until the prologue director stages it
    group.add(zg);
    zohar.group = zg;
    // NOTE: no collider for the cart — the prologue happens on the open plaza
    // and a tipped prop must never wedge the player (no-soft-lock instinct).
  }

  // ===========================================================================
  // State + animation
  // ===========================================================================
  const state = {
    saved: typeof ctx.isSaved === 'function' ? !!ctx.isSaved() : false,
    restoration: typeof ctx.getRestoration === 'function' ? (ctx.getRestoration() || 0) : 0,
    creepM: typeof ctx.getGloomCreepM === 'function' ? (ctx.getGloomCreepM() || 0) : 0,
  };
  let saveAnim = null; // { t, onLantern, litCount }
  let disposed = false;

  function applyCreep() {
    // metres along the bible's ~40 m run -> world-x of the edge, capped at the
    // fountain's bottom step (the stain stops there forever, Ch. 7)
    const worldPerM =
      (MEADOW_TUNING.stainEdgeStartX - MEADOW_TUNING.stainEdgeCapX) / MEADOW_TUNING.fieldRunM;
    stainMat.uniforms.uEdgeX.value = Math.max(
      MEADOW_TUNING.stainEdgeCapX,
      MEADOW_TUNING.stainEdgeStartX - state.creepM * worldPerM
    );
  }

  function applyRestorationAmbience() {
    // subtle pre-save delta: the fields feel less haunted as restoration climbs
    if (!state.saved) {
      wispMat.opacity = 0.5 * (1 - 0.7 * Math.min(1, state.restoration / 100));
    }
  }

  function popLantern(i) {
    const p = lanternPts[i];
    setInst(bulbsLit, i, p.x, p.y - 0.18, p.z, 1.25, 1.25, 1.25); // overshoot pop
    setInst(bulbsDark, i, p.x, p.y - 0.18, p.z, 0.001, 0.001, 0.001);
    bulbsLit.instanceMatrix.needsUpdate = true;
    bulbsDark.instanceMatrix.needsUpdate = true;
  }
  function settleLantern(i) {
    const p = lanternPts[i];
    setInst(bulbsLit, i, p.x, p.y - 0.18, p.z);
    bulbsLit.instanceMatrix.needsUpdate = true;
  }

  function openGateInstant() {
    if (sealMat) sealMat.uniforms.uClear.value = 1;
    if (sealMesh) sealMesh.visible = false;
    if (vines) vines.visible = false;
    if (doorL) doorL.rotation.y = -1.9;
    if (doorR) doorR.rotation.y = 1.9;
    for (let i = 0; i < 2; i++) {
      gateBulbDark.getMatrixAt(i, M);
      const pos = new THREE.Vector3().setFromMatrixPosition(M);
      setInst(gateBulbLit, i, pos.x, pos.y, pos.z);
      setInst(gateBulbDark, i, pos.x, pos.y, pos.z, 0.001, 0.001, 0.001);
    }
    gateBulbLit.instanceMatrix.needsUpdate = true;
    gateBulbDark.instanceMatrix.needsUpdate = true;
    // unblock the arch
    if (sealColObj && Array.isArray(ctx.colliders)) {
      const i = ctx.colliders.indexOf(sealColObj);
      if (i >= 0) ctx.colliders.splice(i, 1);
      sealColObj = null;
    }
  }

  function applySavedInstant() {
    stainMat.uniforms.uBurnX.value = 100; // stain fully burned off
    wisps.visible = false;
    lanternPts.forEach((_, i) => { popLantern(i); settleLantern(i); });
    openGateInstant();
    plotSign.visible = true;
    plotSign.userData.post.visible = true;
  }

  // ---- public setters -------------------------------------------------------
  function setSaved(saved, opts = {}) {
    const was = state.saved;
    state.saved = !!saved;
    if (!saved) return; // un-saving is not a game state; ignore quietly
    if (was) return;    // already saved
    if (opts.animate === false) { applySavedInstant(); return; }
    saveAnim = { t: 0, onLantern: opts.onLantern || null, litCount: 0, doorsT: 0 };
  }

  function setRestoration(pts) {
    state.restoration = Math.max(0, Math.min(100, pts || 0));
    applyRestorationAmbience();
  }

  function setGloomCreepM(m) {
    state.creepM = Math.max(0, m || 0);
    applyCreep();
  }

  function setPlotReplanted(index, replanted = true, opts = {}) {
    const st = plotState[index];
    if (!st) return;
    if (st.replanted === !!replanted) return;
    st.replanted = !!replanted;
    if (opts.animate === false || !replanted) {
      st.anim = replanted ? 1 : 0;
      applyPlotVisual(index, st.anim);
    } // else: update() springs st.anim toward 1
  }

  function applyPlotVisual(i, a) {
    const p = PLOTS[i];
    const rot = Math.sin(i * 7.3) * 0.4;
    // crust shrinks away; soil keeps its footprint (color is shared, so the
    // "warming" read comes from the crust leaving + sprouts arriving)
    const scarS = Math.max(0.001, 1 - a);
    setInst(plotScar, i, p.x, p.y + 0.1, p.z, 1.1 * scarS, 0.14 * scarS, 0.8 * scarS, rot + 0.5);
    for (let s = 0; s < SPROUTS_PER_PLOT; s++) {
      const ang = (s / SPROUTS_PER_PLOT) * Math.PI * 2 + i;
      // spring overshoot on the way in
      const k = a < 1 ? a * (1.2 - 0.2 * a) : 1;
      const sc = Math.max(0.001, k);
      setInst(
        plotSprouts, i * SPROUTS_PER_PLOT + s,
        p.x + Math.cos(ang) * 0.55, p.y + 0.2 + 0.15 * k, p.z + Math.sin(ang) * 0.38,
        sc, sc, sc
      );
    }
    plotScar.instanceMatrix.needsUpdate = true;
    plotSprouts.instanceMatrix.needsUpdate = true;
  }

  function setZoharStage(stage) {
    zohar.stage = stage;
    const zg = zohar.group;
    zg.visible = stage !== 'hidden' && stage !== 'done';
    if (stage === 'spilled') {
      cartGroup.visible = true;
      cartGroup.rotation.set(0, 0.7, 0.55);
      const [cx2, cz2] = STAGING.cart;
      cartGroup.position.set(cx2, terrainY(cx2, cz2) + 0.42, cz2);
      bundles.visible = true;
      setBundlesGathered(0);
      marks.visible = true;
      bedroll.visible = true;
      radiance.material.opacity = 0;
    } else if (stage === 'revealed') {
      // cart righted at the shelter mark; rags -> radiance (the sprite pops,
      // then breathes out in update; the stranger MODEL belongs to the host's
      // villager system — the wire places him, we stage around him)
      const [hx, hz] = STAGING.shelter;
      cartGroup.rotation.set(0, -0.4, 0);
      cartGroup.position.set(hx + 0.9, terrainY(hx, hz) + 0.35, hz + 0.6);
      bundles.visible = false;
      marks.visible = false;
      bedroll.visible = false;
      radiance.material.opacity = 0.95;
    }
  }

  function setBundlesGathered(n) {
    zohar.gathered = Math.max(0, Math.min(STAGING.bundles.length, n | 0));
    STAGING.bundles.forEach(([bx, bz], i) => {
      const s = i < zohar.gathered ? 0.001 : 1;
      setInst(bundles, i, bx, terrainY(bx, bz) + 0.13, bz, s, s, s, i * 1.3);
    });
    bundles.instanceMatrix.needsUpdate = true;
  }

  // ---- per-frame ------------------------------------------------------------
  function update(dt, t) {
    if (disposed) return;
    dt = Math.min(dt || 0.016, 0.1);
    t = t || 0;

    // shader clocks
    sealMat.uniforms.uTime.value = t;
    stainMat.uniforms.uTime.value = t;

    // steeple beacon: slow gold pulse (Ch. 7 signature) — brighter post-save
    const base = state.saved ? 1.0 : 0.45;
    const pulse = base * (0.75 + 0.25 * Math.sin(t * 1.4));
    beaconCore.material.emissiveIntensity = pulse;
    beacon.material.opacity = 0.5 * pulse;

    // wisp drift (position nudge on a handful of floats — cheap)
    if (wisps.visible) {
      const pos = wisps.geometry.attributes.position;
      for (let i = 0; i < WISP_COUNT; i++) {
        const s = wispSeeds[i];
        pos.array[i * 3 + 1] = s.y0 + Math.sin(t * s.sp + s.ph) * 0.25;
      }
      pos.needsUpdate = true;
    }

    // Zohar staging idle: marks breathe; reveal radiance breathes out
    if (zohar.group.visible) {
      if (marks.visible) marks.material.opacity = 0.28 + 0.14 * Math.sin(t * 2.2);
      if (radiance.material.opacity > 0 && zohar.stage === 'revealed') {
        radiance.material.opacity = Math.max(0.25, radiance.material.opacity - dt * 0.12);
        radiance.scale.setScalar(4.5 + Math.sin(t * 1.8) * 0.35);
      }
    }

    // plot replant springs
    for (let i = 0; i < plotState.length; i++) {
      const st = plotState[i];
      if (st.replanted && st.anim < 1) {
        st.anim = Math.min(1, st.anim + dt / 0.6);
        applyPlotVisual(i, st.anim);
      }
    }

    // THE SAVE TRANSFORMATION (Ch. 7): lantern wave 6 s, stain burn 10 s,
    // seal clear 2.2 s, doors 1.4 s after — all on one timeline.
    if (saveAnim) {
      saveAnim.t += dt;
      const T = saveAnim.t;
      // lantern wave chapel -> gate
      const N = lanternPts.length;
      const shouldLit = Math.min(N, Math.floor((T / MEADOW_TUNING.saveWaveSec) * N) + (T > 0 ? 1 : 0));
      while (saveAnim.litCount < shouldLit) {
        const i = saveAnim.litCount++;
        popLantern(i);
        if (saveAnim.onLantern) { try { saveAnim.onLantern(i, N); } catch (e) { /* sfx must never break the wave */ } }
      }
      // settle pops one frame later (cheap overshoot)
      for (let i = 0; i < saveAnim.litCount - 1; i++) settleLantern(i);
      // stain burn-off west -> east
      const bp = Math.min(1, T / MEADOW_TUNING.stainBurnSec);
      stainMat.uniforms.uBurnX.value = 0 + bp * 28; // sweeps across the plane
      if (bp >= 1) wisps.visible = false;
      // seal dissolve, then doors
      const sp = Math.min(1, T / MEADOW_TUNING.sealClearSec);
      sealMat.uniforms.uClear.value = sp;
      if (sp >= 1) {
        if (sealMesh.visible) {
          sealMesh.visible = false;
          if (vines) vines.visible = false; // vines sink with the seal
          if (sealColObj && Array.isArray(ctx.colliders)) {
            const ci = ctx.colliders.indexOf(sealColObj);
            if (ci >= 0) ctx.colliders.splice(ci, 1);
            sealColObj = null;
          }
        }
        saveAnim.doorsT = Math.min(1, saveAnim.doorsT + dt / MEADOW_TUNING.gateDoorSec);
        const e = 1 - Math.pow(1 - saveAnim.doorsT, 3); // ease-out swing
        doorL.rotation.y = -1.9 * e;
        doorR.rotation.y = 1.9 * e;
      }
      // gate lanterns ignite as the wave arrives (last two wave indices)
      if (saveAnim.litCount >= N && gateBulbLit) {
        for (let i = 0; i < 2; i++) {
          gateBulbDark.getMatrixAt(i, M);
          const p = new THREE.Vector3().setFromMatrixPosition(M);
          setInst(gateBulbLit, i, p.x, p.y, p.z);
          setInst(gateBulbDark, i, p.x, p.y, p.z, 0.001, 0.001, 0.001);
        }
        gateBulbLit.instanceMatrix.needsUpdate = true;
        gateBulbDark.instanceMatrix.needsUpdate = true;
      }
      // done?
      if (T >= MEADOW_TUNING.stainBurnSec && saveAnim.doorsT >= 1 && saveAnim.litCount >= N) {
        settleLantern(N - 1);
        plotSign.visible = true;
        plotSign.userData.post.visible = true;
        saveAnim = null;
      }
    }
  }

  function dispose() {
    disposed = true;
    if (sealColObj && Array.isArray(ctx.colliders)) {
      const i = ctx.colliders.indexOf(sealColObj);
      if (i >= 0) ctx.colliders.splice(i, 1);
    }
    group.traverse((o) => {
      if (o.geometry) o.geometry.dispose();
      if (o.material) {
        const mats = Array.isArray(o.material) ? o.material : [o.material];
        mats.forEach((m) => { if (m.map) m.map.dispose(); m.dispose(); });
      }
    });
    if (group.parent) group.parent.remove(group);
  }

  // ---- initial state --------------------------------------------------------
  applyCreep();
  applyRestorationAmbience();
  if (state.saved) applySavedInstant();

  if (ctx.worldGroup && ctx.worldGroup.add) ctx.worldGroup.add(group);

  return {
    group,
    triggers: MEADOW_TRIGGERS,
    state,
    update,
    setSaved,
    setRestoration,
    setGloomCreepM,
    setPlotReplanted,
    setZoharStage,
    setBundlesGathered,
    dispose,
  };
}

export default build;
