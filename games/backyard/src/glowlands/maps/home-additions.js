// =============================================================================
// glowlands/maps/home-additions.js
// Additive Home Garden dressing for the Phase 1 gateway slice (Ch. 17 row 2).
//
// Design authority: /docs/glowlands-design.md
//   Ch. 6  — Home Garden: the only visible change at home is diegetic
//            furniture on the east side. New elements adopt "worn brass and
//            oiled wood". Signature moments implemented here:
//              (a) Lantern Post flare on daily-reading complete — 0.4 s bloom
//                  pulse + 20 drifting light motes (handle.pulse()),
//              (d) at Radiant, ~30 fireflies orbiting the post in a slow helix.
//            The Wayfarer's Table arrives DAMAGED: spider-cracked glass, the
//            map a blurred parchment silhouette (no labels), six carved seal
//            sockets empty but visible/countable. Hearthlight rule: this
//            module changes NO scene lighting — the garden stays fully bright;
//            the post reads the tier honestly via its own flame only.
//   Ch. 17 — Phase 1 slice, row 2: Eastgate arch, Lantern Post, damaged
//            Wayfarer's Table (six empty sockets), Satchel Hook. Ember stays
//            home and is not touched by this module in any way.
//
// WHAT THIS MODULE IS
//   Pure world dressing + a tiny state surface. build(ctx) constructs one
//   THREE.Group of four set pieces placed for the live HOME map geography
//   (road along z=3 running east to the Meadow Town exit at x=24; cottage at
//   (6.5, -7) yaw -0.35; garden fence south of the road):
//     * Eastgate arch  — spans the east road just before the town exit,
//     * Lantern Post   — road shoulder by the house, visible from the plots,
//     * Wayfarer's Table — worn brass + oiled wood, six seal sockets,
//     * Satchel Hook   — mounted on the cottage's road-facing wall by the door.
//
// WHAT THIS MODULE IS NOT
//   * It never edits dragon-garden-quest.jsx, never touches existing meshes,
//     lights, fog, or the camera. Everything is ADDED under one group.
//   * No new lights (Hearthlight already keeps home bright; the lantern flame
//     is emissive + one additive sprite).
//   * No NPCs, no Ember behavior, no travel logic — the existing exit at
//     (24, 3) keeps doing the traveling; the arch is the doorway it deserved.
//   * No verse text of any kind lives here (labels on the repaired map are
//     town names — world fiction, not scripture).
//
// PERF (Ch. 5.8, ≤120 added draw calls per map): 7 draw calls at rest —
//   ONE merged vertex-colored mesh for ALL wood/brass/leaf/leather across the
//   four set pieces, arch flame cores 1, post flame 1, glow sprite 1,
//   mote/firefly InstancedMesh 1, map parchment 1, cracked glass 1 — plus one
//   per slotted seal (independent visibility), worst case 13 with all six.
//   The two canvas textures are 256 px, drawn once (redrawn only on repair).
//
// ctx CONTRACT (Wire phase supplies this from inside buildHome(), after
// clearWorld(); every member optional-safe so the module can be judged
// standalone):
//   ctx.parent          THREE.Group to add to (the map's worldGroup).
//                       If absent, caller adds handle.group manually.
//   ctx.terrainY(x, z)  ground height sampler (default 0).
//   ctx.addCircleCol(x, z, r)   collision registrar (arch pillars, post,
//                       table). Colliders reset with the host's clearWorld,
//                       matching this module's per-build lifecycle.
//   ctx.addHotspot({x, z, r, type, label})  interaction registrar. Types are
//                       namespaced 'gl_*' so the host's switch ignores them
//                       until the Wire phase handles them:
//                         gl_lantern_post / gl_wayfarers_table / gl_satchel_hook
//   ctx.settings        { reducedMotion } — freezes motes/flicker drift.
//   ctx.now()           epoch ms (default Date.now; injectable for tests).
//
// Lantern tier is read from ../lantern.js (getLantern/onLanternChange —
// safe pre-init, Spark default) so the post always agrees with the HUD.
// handle.setLanternTier(tier) exists as a dev/judging override.
//
// WIRING SKETCH (Wire phase only):
//   import buildHomeAdditions from './glowlands/maps/home-additions.js';
//   // inside buildHome(), after props are placed:
//   homeAdditions = buildHomeAdditions({
//     parent: worldGroup, terrainY, addCircleCol,
//     addHotspot: (h) => hotspots.push(h),
//   });
//   // in the render loop:  homeAdditions.update(dt, tSec);
//   // on daily plan-day completion while home:  homeAdditions.pulse();
//   // when seals land / Table Setting completes:
//   //   homeAdditions.setSeals([1]); homeAdditions.setTableRepaired(true);
// =============================================================================

import * as THREE from 'three';
import { LANTERN_TIERS, getLantern, onLanternChange } from '../lantern.js';

// -----------------------------------------------------------------------------
// Layout — world coordinates on the live HOME map (exported, tunable).
// Walk line reads west→east along the road's north shoulder:
// house / Satchel Hook → Lantern Post → Wayfarer's Table → Eastgate.
// -----------------------------------------------------------------------------
export const HOME_ADDITIONS_LAYOUT = Object.freeze({
  // Arch plane sits across the road (which runs along z = 3) at x = 21.6,
  // just west of the town exit trigger at (24, 3): you pass under it to leave.
  eastgate: Object.freeze({ x: 21.6, z: 3, halfSpan: 2.15 }),
  // Road shoulder by the cottage, in clear sight of every plot across the road.
  lanternPost: Object.freeze({ x: 8.4, z: 1.2 }),
  // Between post and arch on the same shoulder — the map faces the camera.
  table: Object.freeze({ x: 13.8, z: 0.7, yaw: -0.09 }),
  // Flush against the cottage's road-facing wall, one step east of the door
  // (cottage at (6.5, -7), yaw -0.35 — precomputed wall point + wall yaw).
  satchelHook: Object.freeze({ x: 7.2, z: -4.53, yaw: -0.35 }),
});

// -----------------------------------------------------------------------------
// Palette — copied from the host's PAL grammar (values, not imports: the host
// file stays untouched) + the Ch. 6 "worn brass and oiled wood" trim family.
// -----------------------------------------------------------------------------
const P = Object.freeze({
  wood: 0xc9b68c, bark: 0x7a5a3e, stone: 0x9d948a, leafMid: 0x619e46,
  leafDeep: 0x38714a, soil: 0x7a5138,
  oiledWood: 0x6b4a30,   // dark rubbed timber — trim family base
  brass: 0xb08d3f,       // worn brass fittings
  brassBright: 0xd8b45e, // polished highlights (caps, sockets)
  leather: 0x8a5a34,     // the satchel
  parchment: 0xe8d9b0,
});

const SRGB = (hex) => new THREE.Color(hex).convertSRGBToLinear();

/** Host-style flat-shaded standard material. */
function flat(color, opts = {}) {
  return new THREE.MeshStandardMaterial({
    color: color instanceof THREE.Color ? color : SRGB(color),
    roughness: 0.9, metalness: 0.02, flatShading: true, ...opts,
  });
}

/** Small hue/value jitter so hand-set timber never reads extruded. */
function jit(c, a = 0.05) {
  return c.clone().offsetHSL((Math.random() - 0.5) * 0.012, (Math.random() - 0.5) * 0.05, (Math.random() - 0.5) * a);
}

/** Solid vertex tint (linear) on a geometry, host `fill` grammar. */
function paint(geo, c) {
  const lc = (c instanceof THREE.Color ? c.clone() : new THREE.Color(c)).convertSRGBToLinear();
  const n = geo.attributes.position.count;
  const cols = new Float32Array(n * 3);
  for (let i = 0; i < n; i++) { cols[i * 3] = lc.r; cols[i * 3 + 1] = lc.g; cols[i * 3 + 2] = lc.b; }
  geo.setAttribute('color', new THREE.BufferAttribute(cols, 3));
  return geo;
}

/** Merge painted geometries into one (host mergeGeoms grammar, r128-safe). */
function mergeGeoms(list) {
  const parts = list.map((g) => (g.index ? g.toNonIndexed() : g));
  let vCount = 0;
  parts.forEach((g) => { vCount += g.attributes.position.count; });
  const pos = new Float32Array(vCount * 3);
  const nor = new Float32Array(vCount * 3);
  const col = new Float32Array(vCount * 3);
  let o = 0;
  parts.forEach((g) => {
    pos.set(g.attributes.position.array, o * 3);
    nor.set(g.attributes.normal.array, o * 3);
    if (g.attributes.color) col.set(g.attributes.color.array, o * 3);
    o += g.attributes.position.count;
  });
  const out = new THREE.BufferGeometry();
  out.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  out.setAttribute('normal', new THREE.BufferAttribute(nor, 3));
  out.setAttribute('color', new THREE.BufferAttribute(col, 3));
  parts.forEach((g) => g.dispose && g.dispose());
  return out;
}

/** Lazy shared radial glow texture (host glowTex grammar, warm variant). */
let glowTexCache = null;
function glowTex() {
  if (glowTexCache) return glowTexCache;
  const cv = document.createElement('canvas');
  cv.width = 64; cv.height = 64;
  const g = cv.getContext('2d');
  const grd = g.createRadialGradient(32, 32, 2, 32, 32, 30);
  grd.addColorStop(0, 'rgba(255,235,190,0.95)');
  grd.addColorStop(0.5, 'rgba(255,200,110,0.35)');
  grd.addColorStop(1, 'rgba(255,170,70,0)');
  g.fillStyle = grd; g.fillRect(0, 0, 64, 64);
  glowTexCache = new THREE.CanvasTexture(cv);
  return glowTexCache;
}

// -----------------------------------------------------------------------------
// Tier → flame visuals. Colors come from LANTERN_TIERS (single source of
// truth shared with the HUD); numeric weights live here (CSS rgba strings in
// the tier table are for DOM, not shaders).
// -----------------------------------------------------------------------------
const FLAME_LOOK = Object.freeze({
  spark:   { intensity: 0.35, glowScale: 0.9,  glowOpacity: 0.22, idleMotes: 0 },
  flame:   { intensity: 0.9,  glowScale: 1.5,  glowOpacity: 0.42, idleMotes: 4 },
  beacon:  { intensity: 1.4,  glowScale: 2.1,  glowOpacity: 0.58, idleMotes: 8 },
  radiant: { intensity: 1.9,  glowScale: 2.7,  glowOpacity: 0.72, idleMotes: 30 }, // helix mode
});

const MOTES_MAX = 30;          // fireflies at Radiant = the full pool (Ch. 6, tunable)
const PULSE_MOTES = 20;        // Ch. 6 signature moment (a)
const PULSE_SECONDS = 0.4;     // bloom pulse length
const SEAL_COLORS = [0xffca5e, 0x6fc0e8, 0x9fd86a, 0xffa06a, 0xc9a0ff, 0x7ae8c8]; // seals 1..6

// =============================================================================
// Canvas art for the Wayfarer's Table (map parchment + glass, 256 px each).
// Pre-repair: blurred silhouette, NO labels (Ch. 6 — the player can count the
// sockets and infer the journey's length before they can read the map).
// =============================================================================
function drawParchment(cv, repaired) {
  const w = cv.width, h = cv.height;
  const g = cv.getContext('2d');
  g.clearRect(0, 0, w, h);
  // aged parchment base with darkened edges
  g.fillStyle = '#e8d9b0';
  g.fillRect(0, 0, w, h);
  const edge = g.createRadialGradient(w / 2, h / 2, h * 0.32, w / 2, h / 2, h * 0.75);
  edge.addColorStop(0, 'rgba(122,81,56,0)');
  edge.addColorStop(1, 'rgba(122,81,56,0.4)');
  g.fillStyle = edge; g.fillRect(0, 0, w, h);
  // the journey: home (SW) rising east then north to Everlight (NE)
  const pts = [
    [0.12, 0.78], [0.30, 0.70], [0.46, 0.76], [0.60, 0.58],
    [0.52, 0.38], [0.68, 0.30], [0.80, 0.44], [0.88, 0.18],
  ];
  const names = ['Home', 'Meadow Town', 'Riverbend', 'Lantern Hollow', 'Glimmerton', 'Starcrest', 'Brightharbor', 'Everlight'];
  if (!repaired) {
    // blurred silhouette: fat soft strokes and blobs, deliberately illegible
    g.strokeStyle = 'rgba(122,81,56,0.28)';
    g.lineWidth = 14; g.lineCap = 'round'; g.lineJoin = 'round';
    g.beginPath();
    pts.forEach(([px, py], i) => (i ? g.lineTo(px * w, py * h) : g.moveTo(px * w, py * h)));
    g.stroke();
    g.fillStyle = 'rgba(107,74,48,0.30)';
    pts.forEach(([px, py]) => { g.beginPath(); g.arc(px * w, py * h, 11, 0, Math.PI * 2); g.fill(); });
  } else {
    // resolved: inked road, town dots, small legible labels
    g.strokeStyle = 'rgba(90,58,34,0.85)';
    g.lineWidth = 3; g.lineCap = 'round'; g.lineJoin = 'round';
    g.setLineDash([7, 5]);
    g.beginPath();
    pts.forEach(([px, py], i) => (i ? g.lineTo(px * w, py * h) : g.moveTo(px * w, py * h)));
    g.stroke();
    g.setLineDash([]);
    g.textAlign = 'center'; g.font = 'bold 11px Georgia';
    pts.forEach(([px, py], i) => {
      g.fillStyle = i === pts.length - 1 ? '#a3660e' : '#6b4a30';
      g.beginPath(); g.arc(px * w, py * h, 4.5, 0, Math.PI * 2); g.fill();
      g.fillStyle = '#4c3520';
      g.fillText(names[i], px * w, py * h - 9);
    });
    // compass rose, NE corner
    g.strokeStyle = '#6b4a30'; g.lineWidth = 1.5;
    g.beginPath(); g.arc(w * 0.08, h * 0.14, 9, 0, Math.PI * 2); g.stroke();
    g.beginPath(); g.moveTo(w * 0.08, h * 0.14 - 12); g.lineTo(w * 0.08, h * 0.14 + 12); g.stroke();
    g.beginPath(); g.moveTo(w * 0.08 - 12, h * 0.14); g.lineTo(w * 0.08 + 12, h * 0.14); g.stroke();
  }
}

function drawGlass(cv, repaired) {
  const w = cv.width, h = cv.height;
  const g = cv.getContext('2d');
  g.clearRect(0, 0, w, h);
  // faint diagonal sheen either way
  const sheen = g.createLinearGradient(0, 0, w, h);
  sheen.addColorStop(0.25, 'rgba(255,255,255,0)');
  sheen.addColorStop(0.45, 'rgba(255,255,255,0.20)');
  sheen.addColorStop(0.55, 'rgba(255,255,255,0)');
  g.fillStyle = sheen; g.fillRect(0, 0, w, h);
  if (repaired) return;
  // spider-crack web from an impact point off-center
  const cx = w * 0.42, cy = h * 0.46;
  g.strokeStyle = 'rgba(240,248,255,0.75)';
  g.lineWidth = 1.4;
  const rays = 9;
  for (let i = 0; i < rays; i++) {
    const a = (i / rays) * Math.PI * 2 + Math.sin(i * 7.3) * 0.35;
    let x = cx, y = cy, seg = 10 + Math.sin(i * 3.1) * 4;
    g.beginPath(); g.moveTo(x, y);
    for (let s = 0; s < 5; s++) {
      x += Math.cos(a + Math.sin(s * 5 + i) * 0.4) * seg;
      y += Math.sin(a + Math.cos(s * 3 + i) * 0.4) * seg;
      g.lineTo(x, y);
      seg *= 1.35;
    }
    g.stroke();
  }
  // two concentric partial rings around the impact
  g.lineWidth = 1;
  [14, 26].forEach((r, i) => {
    g.beginPath();
    g.arc(cx, cy, r, i * 1.2, i * 1.2 + Math.PI * 1.4);
    g.stroke();
  });
}

// =============================================================================
// Set-piece geometry builders. Each pushes painted geometries into shared
// part lists; positions are world coordinates (the host worldGroup is at
// the origin, so the group holds world-space children directly).
// =============================================================================

/** Eastgate arch: oiled-wood pillars + shallow arched lintel + brass collars
 *  + pillar-top lantern cages. Flame cores go to `emissiveParts`. */
function buildEastgate(L, parts, emissiveParts, ground) {
  const timber = new THREE.Color(P.oiledWood);
  const brass = new THREE.Color(P.brass);
  const zA = L.z - L.halfSpan, zB = L.z + L.halfSpan;
  const yA = ground(L.x, zA), yB = ground(L.x, zB);
  const H = 3.05;

  [[zA, yA, 1], [zB, yB, -1]].forEach(([pz, py, lean]) => {
    // stone footing
    const foot = paint(new THREE.IcosahedronGeometry(0.34, 0), jit(new THREE.Color(P.stone), 0.08));
    foot.scale(1.25, 0.55, 1.25); foot.translate(L.x, py + 0.1, pz);
    parts.push(foot);
    // pillar with a hand-set lean toward the road
    const pillar = paint(new THREE.BoxGeometry(0.3, H, 0.3), jit(timber, 0.07));
    pillar.rotateX(lean * 0.02);
    pillar.translate(L.x, py + H / 2, pz + lean * 0.03);
    parts.push(pillar);
    // worn brass collar at two-thirds height
    const collar = paint(new THREE.CylinderGeometry(0.24, 0.26, 0.12, 8), jit(brass, 0.06));
    collar.translate(L.x, py + H * 0.64, pz);
    parts.push(collar);
    // pillar-top lantern cage: brass cap + 4 tiny corner ribs + roof cone
    const cageY = py + H + 0.16;
    const cap = paint(new THREE.CylinderGeometry(0.15, 0.17, 0.05, 8), jit(brass, 0.05));
    cap.translate(L.x, cageY - 0.14, pz);
    parts.push(cap);
    [[-1, -1], [1, -1], [-1, 1], [1, 1]].forEach(([rx, rz]) => {
      const rib = paint(new THREE.BoxGeometry(0.025, 0.24, 0.025), jit(brass, 0.05));
      rib.translate(L.x + rx * 0.1, cageY, pz + rz * 0.1);
      parts.push(rib);
    });
    const roof = paint(new THREE.ConeGeometry(0.17, 0.14, 6), jit(brass, 0.07).offsetHSL(0, 0, -0.06));
    roof.translate(L.x, cageY + 0.18, pz);
    parts.push(roof);
    // flame core — separate emissive mesh (flickers with the post's flame)
    const core = paint(new THREE.OctahedronGeometry(0.07, 0), new THREE.Color(0xffd27a));
    core.translate(L.x, cageY, pz);
    emissiveParts.push(core);
  });

  // shallow arched lintel: 5 chord segments over the span + a ridge cap beam
  const yTop = Math.max(yA, yB) + H;
  const segs = 5;
  const rise = 0.42;
  const ptAt = (t) => [zA + (zB - zA) * t, yTop + Math.sin(t * Math.PI) * rise];
  for (let i = 0; i < segs; i++) {
    const [z0, y0] = ptAt(i / segs);
    const [z1, y1] = ptAt((i + 1) / segs);
    const len = Math.hypot(z1 - z0, y1 - y0) + 0.05;
    const seg = paint(new THREE.BoxGeometry(0.22, 0.26, len), jit(timber, 0.06).offsetHSL(0, 0.02, 0.03));
    seg.rotateX(Math.atan2(y1 - y0, z1 - z0));
    seg.translate(L.x, (y0 + y1) / 2 + 0.13, (z0 + z1) / 2);
    parts.push(seg);
  }
  // brass keystone plate at the crown
  const key = paint(new THREE.BoxGeometry(0.26, 0.2, 0.3), jit(brass, 0.05));
  key.translate(L.x, yTop + rise + 0.3, L.z);
  parts.push(key);
  // blank hanging sign plank under the crown (the DOM exit label does the words)
  [-0.18, 0.18].forEach((dz) => {
    const chain = paint(new THREE.CylinderGeometry(0.014, 0.014, 0.26, 4), jit(brass, 0.04).offsetHSL(0, -0.05, -0.08));
    chain.translate(L.x, yTop + rise - 0.03, L.z + dz);
    parts.push(chain);
  });
  const sign = paint(new THREE.BoxGeometry(0.08, 0.34, 0.78), jit(timber, 0.05).offsetHSL(0, 0.03, 0.06));
  sign.translate(L.x, yTop + rise - 0.33, L.z);
  parts.push(sign);
  // young climbing vines hugging each pillar top — the hedge grew back kindly
  [[zA, yA, 1], [zB, yB, -1]].forEach(([pz, py, side]) => {
    [[0.16, H * 0.82, 0.05, 0.16], [-0.13, H * 0.66, -0.12, 0.13], [0.05, H * 0.94, side * 0.14, 0.12]].forEach(([dx, dy, dz, r]) => {
      const lump = paint(
        new THREE.IcosahedronGeometry(r, 0),
        jit(new THREE.Color(Math.random() < 0.5 ? P.leafMid : P.leafDeep), 0.09),
      );
      lump.scale(1.15, 0.85, 1.15);
      lump.translate(L.x + dx, py + dy, pz + dz);
      parts.push(lump);
    });
  });
}

/** Lantern Post: tapered oiled-wood post, brass crossarm, hanging open cage.
 *  Returns the flame-core pivot info (the flame mesh itself is separate). */
function buildLanternPost(L, parts, ground) {
  const timber = new THREE.Color(P.oiledWood);
  const brass = new THREE.Color(P.brass);
  const y0 = ground(L.x, L.z);
  const H = 2.5;
  const foot = paint(new THREE.IcosahedronGeometry(0.24, 0), jit(new THREE.Color(P.stone), 0.08));
  foot.scale(1.3, 0.5, 1.3); foot.translate(L.x, y0 + 0.07, L.z);
  parts.push(foot);
  const post = paint(new THREE.CylinderGeometry(0.075, 0.11, H, 7), jit(timber, 0.06));
  post.rotateZ(0.015); // barely off plumb — hand-set
  post.translate(L.x, y0 + H / 2, L.z);
  parts.push(post);
  // brass band + scrolled crossarm reaching south (toward the plots/camera)
  const band = paint(new THREE.CylinderGeometry(0.1, 0.11, 0.08, 8), jit(brass, 0.05));
  band.translate(L.x, y0 + H - 0.34, L.z);
  parts.push(band);
  const arm = paint(new THREE.BoxGeometry(0.07, 0.07, 0.62), jit(brass, 0.05));
  arm.translate(L.x, y0 + H - 0.08, L.z + 0.26);
  parts.push(arm);
  const armTip = paint(new THREE.CylinderGeometry(0.05, 0.05, 0.07, 6), jit(brass, 0.05).offsetHSL(0, 0, 0.05));
  armTip.rotateX(Math.PI / 2);
  armTip.translate(L.x, y0 + H - 0.08, L.z + 0.6);
  parts.push(armTip);
  // hanging cage under the arm tip: ring, 4 ribs, base dish, roof + hook
  const cage = { x: L.x, y: y0 + H - 0.52, z: L.z + 0.57 };
  const hook = paint(new THREE.CylinderGeometry(0.012, 0.012, 0.18, 4), jit(brass, 0.04));
  hook.translate(cage.x, cage.y + 0.32, cage.z);
  parts.push(hook);
  const roof = paint(new THREE.ConeGeometry(0.16, 0.12, 6), jit(brass, 0.06).offsetHSL(0, 0, -0.05));
  roof.translate(cage.x, cage.y + 0.2, cage.z);
  parts.push(roof);
  [[-1, -1], [1, -1], [-1, 1], [1, 1]].forEach(([rx, rz]) => {
    const rib = paint(new THREE.BoxGeometry(0.02, 0.28, 0.02), jit(brass, 0.05));
    rib.translate(cage.x + rx * 0.09, cage.y + 0.02, cage.z + rz * 0.09);
    parts.push(rib);
  });
  const dish = paint(new THREE.CylinderGeometry(0.13, 0.1, 0.05, 8), jit(brass, 0.05));
  dish.translate(cage.x, cage.y - 0.13, cage.z);
  parts.push(dish);
  return cage;
}

/** Wayfarer's Table: heavy oiled-wood table, brass corner caps, six carved
 *  seal sockets flanking the recessed map well. Pushes wood/brass into
 *  `parts`; returns socket world positions for the seal-disc mesh. */
function buildTable(L, parts, ground) {
  const timber = new THREE.Color(P.oiledWood);
  const brass = new THREE.Color(P.brass);
  const y0 = ground(L.x, L.z);
  const TOP_Y = y0 + 0.78;
  const cos = Math.cos(L.yaw), sin = Math.sin(L.yaw);
  // local→world for table-space offsets (lx east-west along the top, lz across)
  const W2 = ([lx, lz]) => [L.x + lx * cos + lz * sin, L.z - lx * sin + lz * cos];

  // four stout legs, splayed a breath outward
  [[-0.72, -0.42], [0.72, -0.42], [-0.72, 0.42], [0.72, 0.42]].forEach(([lx, lz]) => {
    const [wx, wz] = W2([lx, lz]);
    const leg = paint(new THREE.BoxGeometry(0.13, 0.78, 0.13), jit(timber, 0.07));
    leg.rotateY(L.yaw);
    leg.rotateX(lz > 0 ? 0.03 : -0.03);
    leg.translate(wx, y0 + 0.39, wz);
    parts.push(leg);
  });
  // skirt rails
  [[0, -0.42, 1.44, 0.08], [0, 0.42, 1.44, 0.08]].forEach(([lx, lz, len, dep]) => {
    const [wx, wz] = W2([lx, lz]);
    const rail = paint(new THREE.BoxGeometry(len, 0.1, dep), jit(timber, 0.05));
    rail.rotateY(L.yaw);
    rail.translate(wx, y0 + 0.68, wz);
    parts.push(rail);
  });
  // top: three planks with per-plank tone (reads hand-joined, not extruded)
  [-0.34, 0, 0.34].forEach((lz) => {
    const [wx, wz] = W2([0, lz]);
    const plank = paint(new THREE.BoxGeometry(1.66, 0.07, 0.34), jit(timber, 0.09).offsetHSL(0, 0.02, 0.04));
    plank.rotateY(L.yaw);
    plank.translate(wx, TOP_Y - 0.035, wz);
    parts.push(plank);
  });
  // raised map well frame (the glass sits inside this)
  [[0, -0.27, 1.18, 0.05], [0, 0.27, 1.18, 0.05], [-0.565, 0, 0.05, 0.59], [0.565, 0, 0.05, 0.59]].forEach(([lx, lz, len, dep]) => {
    const [wx, wz] = W2([lx, lz]);
    const lip = paint(new THREE.BoxGeometry(len, 0.05, dep), jit(timber, 0.05).offsetHSL(0, 0, -0.04));
    lip.rotateY(L.yaw);
    lip.translate(wx, TOP_Y + 0.02, wz);
    parts.push(lip);
  });
  // brass corner caps (Pip's future perch is the NE one — Ch. 6)
  [[-0.8, -0.5], [0.8, -0.5], [-0.8, 0.5], [0.8, 0.5]].forEach(([lx, lz]) => {
    const [wx, wz] = W2([lx, lz]);
    const capG = paint(new THREE.BoxGeometry(0.12, 0.05, 0.12), jit(brass, 0.05));
    capG.rotateY(L.yaw);
    capG.translate(wx, TOP_Y + 0.01, wz);
    parts.push(capG);
  });
  // six carved seal sockets: brass ring + darker recessed bed, 3 north + 3 south
  // of the map well — empty but visible, countable at a glance (Ch. 6).
  const sockets = [];
  [-0.4, 0.4].forEach((lz) => {
    [-0.42, 0, 0.42].forEach((lx) => {
      const [wx, wz] = W2([lx, lz]);
      const ring = paint(new THREE.TorusGeometry(0.075, 0.016, 5, 10), jit(new THREE.Color(P.brassBright), 0.05));
      ring.rotateX(Math.PI / 2);
      ring.translate(wx, TOP_Y + 0.012, wz);
      parts.push(ring);
      const bed = paint(new THREE.CylinderGeometry(0.065, 0.065, 0.015, 10), jit(timber, 0.04).offsetHSL(0, 0, -0.12));
      bed.translate(wx, TOP_Y + 0.004, wz);
      parts.push(bed);
      sockets.push({ x: wx, y: TOP_Y + 0.02, z: wz });
    });
  });
  // seal order reads west→east, north row first (seal 1 = NW socket)
  return { sockets, topY: TOP_Y, W2 };
}

/** Satchel Hook: plank + brass pegs on the cottage wall, a leather Verse
 *  Satchel hanging from the west peg. One merged mesh. */
function buildSatchelHook(L, parts, ground) {
  const timber = new THREE.Color(P.oiledWood);
  const brass = new THREE.Color(P.brass);
  const leather = new THREE.Color(P.leather);
  const y0 = ground(L.x, L.z);
  const cos = Math.cos(L.yaw), sin = Math.sin(L.yaw);
  // local frame: lx along the wall, lz out from the wall (outward ≈ toward road)
  const W3 = ([lx, ly, lz]) => [L.x + lx * cos + lz * sin, y0 + ly, L.z - lx * sin + lz * cos];

  const put = (geo, c, [lx, ly, lz], rotY = 0) => {
    const g = paint(geo, c);
    g.rotateY(L.yaw + rotY);
    const [wx, wy, wz] = W3([lx, ly, lz]);
    g.translate(wx, wy, wz);
    parts.push(g);
  };
  // mounting plank flush to the wall
  put(new THREE.BoxGeometry(0.72, 0.5, 0.05), jit(timber, 0.06), [0, 1.28, 0.03]);
  // two brass pegs angled slightly up
  [-0.2, 0.2].forEach((lx) => {
    const peg = paint(new THREE.CylinderGeometry(0.02, 0.026, 0.16, 6), jit(brass, 0.05));
    peg.rotateX(Math.PI / 2 - 0.25);
    peg.rotateY(L.yaw);
    const [wx, wy, wz] = W3([lx, 1.36, 0.1]);
    peg.translate(wx, wy, wz);
    parts.push(peg);
  });
  // the Verse Satchel on the west peg: soft leather body, flap, strap loop
  const body = paint(new THREE.IcosahedronGeometry(0.16, 0), jit(leather, 0.06));
  body.scale(1.0, 1.15, 0.62);
  body.rotateY(L.yaw + 0.1);
  {
    const [wx, wy, wz] = W3([-0.2, 1.06, 0.12]);
    body.translate(wx, wy, wz);
    parts.push(body);
  }
  put(new THREE.BoxGeometry(0.26, 0.14, 0.045), jit(leather, 0.05).offsetHSL(0, 0, -0.05), [-0.2, 1.17, 0.15], 0.1); // flap
  put(new THREE.BoxGeometry(0.035, 0.26, 0.03), jit(leather, 0.04).offsetHSL(0, 0, -0.08), [-0.2, 1.3, 0.12]); // strap
  // small brass clasp catching the light
  put(new THREE.BoxGeometry(0.05, 0.04, 0.03), jit(new THREE.Color(P.brassBright), 0.04), [-0.2, 1.12, 0.2], 0.1);
}

// =============================================================================
// build(ctx) — the module's single entry point.
// =============================================================================
export function build(ctx = {}) {
  const L = HOME_ADDITIONS_LAYOUT;
  const ground = typeof ctx.terrainY === 'function' ? (x, z) => ctx.terrainY(x, z) : () => 0;
  const reducedMotion = !!(ctx.settings && ctx.settings.reducedMotion);
  const nowMs = typeof ctx.now === 'function' ? ctx.now : Date.now;

  const group = new THREE.Group();
  group.name = 'glowlands-home-additions';

  // -- merged wood/brass/leaf dressing (1 draw call) + arch flame cores (1) --
  const woodParts = [];
  const emissiveParts = [];
  buildEastgate(L.eastgate, woodParts, emissiveParts, ground);
  const cage = buildLanternPost(L.lanternPost, woodParts, ground);
  const tableInfo = buildTable(L.table, woodParts, ground);
  buildSatchelHook(L.satchelHook, woodParts, ground);

  const dressing = new THREE.Mesh(mergeGeoms(woodParts), flat(0xffffff, { vertexColors: true }));
  dressing.castShadow = true;
  dressing.receiveShadow = true;
  group.add(dressing);

  // shared flame material — post flame + the two arch cage cores flicker as one
  const flameMat = new THREE.MeshStandardMaterial({
    color: SRGB(0xfff1c0), emissive: SRGB(0xffb845), emissiveIntensity: 0.9,
    roughness: 0.4, flatShading: true,
  });
  const archFlames = new THREE.Mesh(mergeGeoms(emissiveParts), flameMat);
  group.add(archFlames);

  // -- the post's own flame + glow sprite (2 draw calls) --
  const flame = new THREE.Mesh(new THREE.OctahedronGeometry(0.085, 0), flameMat);
  flame.position.set(cage.x, cage.y, cage.z);
  group.add(flame);

  const glow = new THREE.Sprite(new THREE.SpriteMaterial({
    map: glowTex(), color: SRGB(0xffcf7a), transparent: true, opacity: 0.4,
    depthWrite: false, blending: THREE.AdditiveBlending,
  }));
  glow.position.set(cage.x, cage.y, cage.z);
  glow.scale.set(1.5, 1.5, 1);
  group.add(glow);

  // -- light motes / fireflies: ONE InstancedMesh, matrices animated (1 dc) --
  const moteMat = new THREE.MeshStandardMaterial({
    color: SRGB(0xfff1c0), emissive: SRGB(0xffd27a), emissiveIntensity: 1.6,
    transparent: true, opacity: 0.85, depthWrite: false, blending: THREE.AdditiveBlending,
  });
  const motes = new THREE.InstancedMesh(new THREE.OctahedronGeometry(0.03, 0), moteMat, MOTES_MAX);
  motes.frustumCulled = false;
  const moteState = []; // { mode:'drift'|'helix', age, life, x,y,z, vx,vy,vz, seed }
  for (let i = 0; i < MOTES_MAX; i++) moteState.push({ mode: null, age: 0, life: 0, x: 0, y: 0, z: 0, vx: 0, vy: 0, vz: 0, seed: Math.random() * 10 });
  const moteDummy = new THREE.Object3D();
  const hideAllMotes = () => {
    moteDummy.position.set(0, -100, 0); moteDummy.scale.setScalar(0.0001); moteDummy.updateMatrix();
    for (let i = 0; i < MOTES_MAX; i++) motes.setMatrixAt(i, moteDummy.matrix);
    motes.instanceMatrix.needsUpdate = true;
  };
  hideAllMotes();
  group.add(motes);

  // -- Wayfarer's Table map well: parchment + glass (2 dc) --
  const parchCv = document.createElement('canvas');
  parchCv.width = 256; parchCv.height = 128;
  drawParchment(parchCv, false);
  const parchTex = new THREE.CanvasTexture(parchCv);
  const parch = new THREE.Mesh(
    new THREE.PlaneGeometry(1.08, 0.5),
    new THREE.MeshStandardMaterial({ map: parchTex, roughness: 0.95 }),
  );
  parch.rotation.x = -Math.PI / 2;
  parch.rotation.z = L.table.yaw;
  {
    const [px, pz] = tableInfo.W2([0, 0]);
    parch.position.set(px, tableInfo.topY + 0.005, pz);
  }
  group.add(parch);

  const glassCv = document.createElement('canvas');
  glassCv.width = 256; glassCv.height = 128;
  drawGlass(glassCv, false);
  const glassTex = new THREE.CanvasTexture(glassCv);
  const glassMat = new THREE.MeshStandardMaterial({
    map: glassTex, transparent: true, opacity: 0.85, roughness: 0.15, metalness: 0.1,
    color: SRGB(0xdfe9ef), depthWrite: false,
  });
  const glass = new THREE.Mesh(new THREE.PlaneGeometry(1.08, 0.5), glassMat);
  glass.rotation.x = -Math.PI / 2;
  glass.rotation.z = L.table.yaw;
  glass.position.copy(parch.position);
  glass.position.y += 0.02;
  group.add(glass);

  // -- seal discs: one merged mesh of six, all hidden until slotted (1 dc) --
  const sealMats = [];
  const sealGroup = new THREE.Group();
  tableInfo.sockets.forEach((s, i) => {
    const m = new THREE.MeshStandardMaterial({
      color: SRGB(SEAL_COLORS[i]), emissive: SRGB(SEAL_COLORS[i]), emissiveIntensity: 0.55,
      roughness: 0.35, flatShading: true,
    });
    sealMats.push(m);
    const disc = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.06, 0.025, 10), m);
    disc.position.set(s.x, s.y, s.z);
    disc.visible = false;
    sealGroup.add(disc);
  });
  group.add(sealGroup);

  // ---------------------------------------------------------------------------
  // Registration with the host map (all optional)
  // ---------------------------------------------------------------------------
  if (typeof ctx.addCircleCol === 'function') {
    ctx.addCircleCol(L.eastgate.x, L.eastgate.z - L.eastgate.halfSpan, 0.4);
    ctx.addCircleCol(L.eastgate.x, L.eastgate.z + L.eastgate.halfSpan, 0.4);
    ctx.addCircleCol(L.lanternPost.x, L.lanternPost.z, 0.3);
    ctx.addCircleCol(L.table.x, L.table.z, 0.95);
  }
  // Interaction anchors — also returned on the handle so the Wire phase can
  // register them itself if it prefers.
  const hotspots = [
    { x: L.lanternPost.x, z: L.lanternPost.z, r: 2.2, type: 'gl_lantern_post', label: 'The Lantern Post' },
    { x: L.table.x, z: L.table.z, r: 2.4, type: 'gl_wayfarers_table', label: "The Wayfarer's Table" },
    { x: L.satchelHook.x, z: L.satchelHook.z, r: 2.0, type: 'gl_satchel_hook', label: 'Your Verse Satchel' },
  ];
  if (typeof ctx.addHotspot === 'function') hotspots.forEach((h) => ctx.addHotspot({ ...h }));

  if (ctx.parent && ctx.parent.add) ctx.parent.add(group);

  // ---------------------------------------------------------------------------
  // State: lantern tier (live from the lantern store), pulse, seals, repair
  // ---------------------------------------------------------------------------
  let tier = 'spark';
  let look = FLAME_LOOK.spark;
  let flameColor = SRGB(LANTERN_TIERS.spark.flame.color);
  let pulseT = -1; // seconds remaining in the bloom pulse, <0 = idle
  let repaired = false;
  let disposed = false;

  function applyTier(t) {
    if (!FLAME_LOOK[t]) t = 'spark';
    tier = t;
    look = FLAME_LOOK[t];
    flameColor = SRGB(LANTERN_TIERS[t].flame.color);
    flameMat.emissive.copy(flameColor);
    glow.material.color.copy(flameColor);
  }
  applyTier(getLantern().tier);
  const offLantern = onLanternChange((s) => { if (!disposed) applyTier(s.tier); });

  function spawnMote(mode) {
    const m = moteState.find((s) => s.mode === null);
    if (!m) return;
    m.mode = mode;
    m.age = 0;
    m.life = mode === 'drift' ? 1.3 + Math.random() * 0.9 : Infinity;
    m.x = cage.x + (Math.random() - 0.5) * 0.24;
    m.y = cage.y + (Math.random() - 0.5) * 0.15;
    m.z = cage.z + (Math.random() - 0.5) * 0.24;
    m.vx = (Math.random() - 0.5) * 0.5;
    m.vy = 0.7 + Math.random() * 0.9;
    m.vz = (Math.random() - 0.5) * 0.5;
    m.seed = Math.random() * 10;
  }

  // steady-state mote budget for the current tier (helix motes never expire)
  function trimIdleMotes() {
    const want = reducedMotion ? 0 : look.idleMotes;
    const mode = tier === 'radiant' ? 'helix' : 'drift';
    let have = 0;
    moteState.forEach((m) => { if (m.mode === 'helix') have++; });
    if (mode === 'helix') {
      for (let i = have; i < want; i++) spawnMote('helix');
    } else if (have > 0) {
      moteState.forEach((m) => { if (m.mode === 'helix') m.mode = null; });
    }
  }

  const postBase = ground(L.lanternPost.x, L.lanternPost.z);

  function update(dt, tSec) {
    if (disposed) return;
    dt = Math.min(0.1, Math.max(0, dt || 0.016));
    const t = tSec || nowMs() / 1000;

    // flame flicker: cheap layered sines, calmer under reducedMotion
    const wob = reducedMotion ? 0 : Math.sin(t * 9.1) * 0.09 + Math.sin(t * 23.7) * 0.05;
    let inten = look.intensity * (1 + wob);
    let gScale = look.glowScale * (1 + wob * 0.5);
    let gOpacity = look.glowOpacity;

    // signature bloom pulse (Ch. 6a): 0.4 s spike, ease-out
    if (pulseT >= 0) {
      pulseT -= dt;
      const k = Math.max(0, pulseT / PULSE_SECONDS);
      const boost = (1 - k) < 0.35 ? (1 - k) / 0.35 : k / 0.65; // fast attack, soft release
      inten += 2.2 * boost;
      gScale += 1.8 * boost;
      gOpacity = Math.min(0.95, gOpacity + 0.4 * boost);
      if (pulseT < 0) pulseT = -1;
    }
    flameMat.emissiveIntensity = inten;
    glow.scale.set(gScale, gScale, 1);
    glow.material.opacity = gOpacity;
    if (!reducedMotion) flame.rotation.y = t * 0.8;

    // idle mote replenishment: drift tiers trickle, radiant keeps the helix full
    trimIdleMotes();
    if (!reducedMotion && tier !== 'radiant' && look.idleMotes > 0) {
      const active = moteState.reduce((n, m) => n + (m.mode === 'drift' ? 1 : 0), 0);
      if (active < look.idleMotes && Math.random() < dt * 1.6) spawnMote('drift');
    }

    // animate motes
    let dirty = false;
    for (let i = 0; i < MOTES_MAX; i++) {
      const m = moteState[i];
      if (!m.mode) continue;
      m.age += dt;
      if (m.age >= m.life) {
        m.mode = null;
        moteDummy.position.set(0, -100, 0); moteDummy.scale.setScalar(0.0001);
        moteDummy.updateMatrix();
        motes.setMatrixAt(i, moteDummy.matrix);
        dirty = true;
        continue;
      }
      if (m.mode === 'drift') {
        m.x += (m.vx + Math.sin(t * 3 + m.seed) * 0.25) * dt;
        m.y += m.vy * dt;
        m.z += (m.vz + Math.cos(t * 2.6 + m.seed) * 0.25) * dt;
        const fade = 1 - m.age / m.life;
        moteDummy.position.set(m.x, m.y, m.z);
        moteDummy.scale.setScalar(0.6 + fade * 0.7);
      } else {
        // radiant firefly helix: slow orbit climbing the post, wrap at the top
        const a = m.seed * Math.PI * 2 + t * (0.3 + (m.seed % 0.2));
        const r = 0.55 + Math.sin(m.seed * 5 + t * 0.5) * 0.15;
        const yy = postBase + 0.6 + ((m.seed * 3.7 + t * 0.16) % 1) * 2.1; // climbs, wraps at the top
        moteDummy.position.set(L.lanternPost.x + Math.cos(a) * r, yy, L.lanternPost.z + Math.sin(a) * r);
        moteDummy.scale.setScalar(0.75 + Math.sin(t * 4 + m.seed * 9) * 0.3);
      }
      moteDummy.rotation.set(0, t + m.seed, 0);
      moteDummy.updateMatrix();
      motes.setMatrixAt(i, moteDummy.matrix);
      dirty = true;
    }
    if (dirty) motes.instanceMatrix.needsUpdate = true;
  }

  const handle = {
    group,
    hotspots,
    anchors: {
      eastgate: { x: L.eastgate.x, z: L.eastgate.z },
      lanternPost: { x: L.lanternPost.x, z: L.lanternPost.z },
      table: { x: L.table.x, z: L.table.z },
      satchelHook: { x: L.satchelHook.x, z: L.satchelHook.z },
    },
    drawCalls: 13, // worst case (all six seals slotted); 7 at rest
    update,

    /** Daily-reading-complete flare: 0.4 s bloom + 20 drifting motes (Ch. 6a). */
    pulse() {
      if (disposed) return;
      pulseT = PULSE_SECONDS;
      if (!reducedMotion) for (let i = 0; i < PULSE_MOTES; i++) spawnMote('drift');
    },

    /** Dev/judging override; production tier arrives via the lantern store. */
    setLanternTier(t) { applyTier(t); },

    /**
     * Slot earned seals. Accepts a count (3 → seals 1..3) or an array of seal
     * numbers 1..6. Seals slot even while the table is damaged (Ch. 6).
     */
    setSeals(seals) {
      const on = new Set();
      if (typeof seals === 'number') { for (let i = 1; i <= Math.min(6, seals); i++) on.add(i); }
      else if (Array.isArray(seals)) seals.forEach((n) => { if (n >= 1 && n <= 6) on.add(Math.floor(n)); });
      sealGroup.children.forEach((disc, i) => { disc.visible = on.has(i + 1); });
    },

    /** "Table Setting" completion: cracks lift, the map resolves to labels. */
    setTableRepaired(v) {
      repaired = !!v;
      drawParchment(parchCv, repaired);
      parchTex.needsUpdate = true;
      drawGlass(glassCv, repaired);
      glassTex.needsUpdate = true;
      glassMat.opacity = repaired ? 0.45 : 0.85;
      glassMat.roughness = repaired ? 0.08 : 0.15;
    },

    isTableRepaired: () => repaired,
    getLanternTier: () => tier,

    dispose() {
      if (disposed) return;
      disposed = true;
      offLantern();
      if (group.parent) group.parent.remove(group);
      group.traverse((o) => {
        if (o.geometry) o.geometry.dispose();
        if (o.material) {
          const mats = Array.isArray(o.material) ? o.material : [o.material];
          mats.forEach((m) => { if (m.map && m.map !== glowTexCache) m.map.dispose(); m.dispose(); });
        }
      });
      sealMats.length = 0;
    },
  };

  return handle;
}

export default build;
