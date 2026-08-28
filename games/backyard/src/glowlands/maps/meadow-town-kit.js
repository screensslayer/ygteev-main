// Meadow Town building kit — the pre-save, Gloom-dimmed town square.
//
// Seven stone-and-wood buildings on a ring around the fountain, a web of
// UNLIT string lights strung over the square, and the props that give each
// building its job: BUY (Rosie's Seeds), SELL (Berry Market), BUILD
// (Toolworks), the Library, a locked chapel, and two sleeping houses.
//
// Design contract (glowlands bible Ch. 7): pressure without punishment — the
// town is dark and hazed, but readable and friendly. The only warm light in
// the square is the Toolworks forge ember.
//
// The string lights are the town's future progress meter: every chapter the
// player reads lights one bulb. That feature ships later — this kit only
// guarantees the rig for it: bulbs are ONE InstancedMesh in a stable order
// (radial strands clockwise from the chapel, then the perimeter ring), and
// `lights.setLit(n)` colors the first n. Nothing calls it in production yet.
//
// Everything is added to ctx.worldGroup, so the existing disposeWorld pass
// frees it on map change — no SHARED_GPU registrations here.

import spawnGloomlings from "./gloomlings.js";
import spawnGloomBoss from "./gloom-boss.js";

export default function buildMeadowTownKit(ctx) {
  const {
    THREE, worldGroup, flat, SRGB, addBoxCol, addCircleCol,
    makeTextPlate, glowNodes, PAL,
  } = ctx;

  // ---- shared palette: everything desaturated toward dusk ----------------
  const matCache = new Map();
  const M = (hex, opts) => {
    const key = hex + JSON.stringify(opts || {});
    if (!matCache.has(key)) matCache.set(key, flat(hex, opts));
    return matCache.get(key);
  };
  const STONE = 0x8d8679, STONE_DK = 0x6e6337 + 0x2a27; // 0x6e685e
  const TIMBER = 0x5c452f, TIMBER_DK = 0x463526;
  const DOOR_WOOD = 0x6b4a2c, RECESS = 0x14121c;
  const PANE = 0x2e3044;            // unlit window glass — cold, no emissive
  const IRON = 0x3a3a44;
  const box = (w, h, d, hex) => new THREE.Mesh(new THREE.BoxGeometry(w, h, d), M(hex));

  // ---- one building --------------------------------------------------------
  // Local space: gable FRONT faces +Z (toward the fountain once rotated).
  // Returns world-space door + strand anchor so the caller can wire exits.
  function building(cfg) {
    const { x, z, w, d, h, wall, roof } = cfg;
    const rise = w * (cfg.steep ? 0.52 : 0.42);
    const rotY = Math.atan2(-x, -z) + (cfg.skew || 0); // face the fountain
    const g = new THREE.Group();

    // stone foundation course, slightly proud of the walls
    const found = box(w + 0.42, 0.52, d + 0.42, STONE);
    found.position.y = 0.2;
    g.add(found);

    // solid body: walls + both gables in one extrusion (ridge along Z)
    const p = new THREE.Shape();
    p.moveTo(-w / 2, 0); p.lineTo(w / 2, 0); p.lineTo(w / 2, h);
    p.lineTo(0, h + rise); p.lineTo(-w / 2, h); p.lineTo(-w / 2, 0);
    const bodyGeo = new THREE.ExtrudeGeometry(p, { depth: d, bevelEnabled: false });
    bodyGeo.translate(0, 0, -d / 2);
    const body = new THREE.Mesh(bodyGeo, M(wall));
    body.castShadow = true; body.receiveShadow = true;
    g.add(body);

    // timber skeleton: corner posts, front beams, diagonal braces
    [[-1, -1], [1, -1], [-1, 1], [1, 1]].forEach(([sx, sz]) => {
      const post = box(0.16, h + 0.06, 0.16, TIMBER_DK);
      post.position.set(sx * (w / 2 - 0.06), h / 2 + 0.03, sz * (d / 2 - 0.06));
      g.add(post);
    });
    [h - 0.1, 0.6].forEach((by) => {
      const beam = box(w + 0.06, 0.13, 0.09, TIMBER_DK);
      beam.position.set(0, by, d / 2 + 0.02);
      g.add(beam);
    });
    [-1, 1].forEach((s) => {
      const brace = box(0.09, 1.15, 0.07, TIMBER_DK);
      brace.rotation.z = s * 0.62;
      brace.position.set(s * (w / 2 - 0.55), 1.15, d / 2 + 0.03);
      g.add(brace);
      const beamS = box(0.09, 0.13, d + 0.04, TIMBER_DK); // side rails
      beamS.position.set(s * (w / 2 + 0.015), h - 0.1, 0);
      g.add(beamS);
    });

    // layered roof: three stepped rows per side — the mockup's signature
    const ang = Math.atan2(rise, w / 2 + 0.3);
    const sl = Math.hypot(w / 2 + 0.3, rise);
    const rowTint = [0, -0.055, 0.05];
    [1, -1].forEach((sign) => {
      for (let i = 0; i < 3; i++) {
        const t = (i + 0.5) / 3;
        const row = new THREE.Mesh(
          new THREE.BoxGeometry(sl / 3 + 0.24, 0.11, d + 0.9 - i * 0.16),
          M(new THREE.Color(roof).offsetHSL(0, 0, rowTint[i]).getHex()));
        row.rotation.z = -sign * ang;
        row.position.set(sign * (w / 2 + 0.3) * (1 - t), h + rise * t + 0.07 + i * 0.012, 0);
        row.castShadow = true;
        g.add(row);
      }
      const fascia = box(0.1, 0.17, d + 0.72, TIMBER_DK); // eave shadow board
      fascia.position.set(sign * (w / 2 + 0.26), h - 0.02, 0);
      g.add(fascia);
      const rake = box(sl * 0.94, 0.13, 0.1, TIMBER_DK);  // front gable trim
      rake.rotation.z = -sign * ang;
      rake.position.set(sign * (w / 2 + 0.3) * 0.5, h + rise * 0.5 + 0.1, d / 2 + 0.04);
      g.add(rake);
    });
    const cap = box(0.36, 0.14, d + 0.95, new THREE.Color(roof).offsetHSL(0, 0, -0.09).getHex());
    cap.position.y = h + rise + 0.07;
    g.add(cap);

    if (cfg.chimney) {
      const stack = box(0.46, rise + 1.15, 0.46, STONE);
      stack.position.set(w * 0.24, h + rise * 0.4 + 0.35, -d * 0.16);
      const cc = box(0.62, 0.13, 0.62, STONE_DK);
      cc.position.set(w * 0.24, h + rise * 0.4 + 0.98, -d * 0.16);
      g.add(stack, cc);
    }

    // windows: dark panes — nothing in town is lit until the town wakes
    const shutterHex = cfg.shutters ? (cfg.shutterC || 0x565a48) : null;
    (cfg.windows || []).forEach((wc) => {
      const wg = new THREE.Group();
      const fw = wc.w || 0.62, fh = wc.h || 0.72;
      const frame = box(fw + 0.18, fh + 0.18, 0.07, TIMBER_DK);
      const pane = box(fw, fh, 0.06, PANE);
      pane.position.z = 0.015;
      // one thin mullion so the glass reads as panes, not a black hole
      const mull = box(0.05, fh, 0.065, TIMBER_DK);
      mull.position.z = 0.02;
      const sill = box(fw + 0.32, 0.09, 0.17, STONE);
      sill.position.set(0, -(fh / 2 + 0.1), 0.02);
      wg.add(frame, pane, mull, sill);
      if (shutterHex) [-1, 1].forEach((s) => {
        const sh = box(fw * 0.46, fh + 0.12, 0.05, shutterHex);
        sh.position.set(s * (fw / 2 + fw * 0.23 + 0.07), 0, 0.01);
        wg.add(sh);
      });
      if (wc.side === "F") { wg.position.set(wc.u, wc.y, d / 2 + 0.05); }
      else {
        wg.position.set((wc.side === "R" ? 1 : -1) * (w / 2 + 0.05), wc.y, wc.u);
        wg.rotation.y = (wc.side === "R" ? 1 : -1) * Math.PI / 2;
      }
      g.add(wg);
    });

    // the door: a real recessed opening, jambs and lintel, panel ajar unless
    // locked — "the doors can be entered" is the whole brief
    const du = cfg.doorU || 0;
    const recess = box(1.04, 1.72, 0.14, RECESS);
    recess.position.set(du, 0.86, d / 2 - 0.03);
    g.add(recess);
    [-1, 1].forEach((s) => {
      const jamb = box(0.13, 1.8, 0.11, TIMBER_DK);
      jamb.position.set(du + s * 0.58, 0.9, d / 2 + 0.03);
      g.add(jamb);
    });
    const lintel = box(1.32, 0.15, 0.11, TIMBER_DK);
    lintel.position.set(du, 1.86, d / 2 + 0.03);
    g.add(lintel);
    if (cfg.locked) {
      // closed double door, iron bands, one very clear padlock
      [-1, 1].forEach((s) => {
        const leaf = box(0.46, 1.62, 0.07, DOOR_WOOD);
        leaf.position.set(du + s * 0.24, 0.81, d / 2 + 0.02);
        g.add(leaf);
        [0.55, 1.2].forEach((by) => {
          const band = box(0.4, 0.07, 0.03, IRON);
          band.position.set(du + s * 0.24, by, d / 2 + 0.065);
          g.add(band);
        });
      });
      const lock = box(0.17, 0.22, 0.08, IRON);
      lock.position.set(du, 0.86, d / 2 + 0.1);
      const shackle = new THREE.Mesh(new THREE.TorusGeometry(0.075, 0.022, 5, 10, Math.PI), M(IRON));
      shackle.position.set(du, 0.99, d / 2 + 0.1);
      g.add(lock, shackle);
    } else {
      const pivot = new THREE.Group();               // hinge at the left jamb
      pivot.position.set(du - 0.46, 0, d / 2 + 0.05);
      const panel = box(0.84, 1.6, 0.06, DOOR_WOOD);
      panel.position.set(0.42, 0.8, 0);
      const knob = new THREE.Mesh(new THREE.SphereGeometry(0.045, 6, 5), M(IRON));
      knob.position.set(0.74, 0.82, 0.05);
      pivot.add(panel, knob);
      pivot.rotation.y = -(cfg.ajar == null ? 0.92 : cfg.ajar); // swung open
      g.add(pivot);
    }

    // hanging sign on a bracket beside the door
    if (cfg.sign) {
      const arm = box(0.07, 0.07, 0.62, TIMBER_DK);
      arm.position.set(du + 1.0, 2.42, d / 2 + 0.3);
      const drop = box(0.07, 0.34, 0.07, TIMBER_DK);
      drop.position.set(du + 1.0, 2.28, d / 2 + 0.56);
      g.add(arm, drop);
      const plate = makeTextPlate(cfg.sign, { w: 1.75, h: 0.46, bg: "#4e4536", fg: "#cdbd97" });
      plate.position.set(du + 1.0, 1.94, d / 2 + 0.56);
      plate.rotation.z = 0.025;
      g.add(plate);
    }

    g.position.set(x, 0, z);
    g.rotation.y = rotY;
    worldGroup.add(g);
    addBoxCol(x, z, w / 2 + 0.34, d / 2 + 0.34, rotY);

    // world-space helpers for wiring and props
    const L2W = (lx, ly, lz) => ({
      x: x + lx * Math.cos(rotY) + lz * Math.sin(rotY),
      y: ly,
      z: z - lx * Math.sin(rotY) + lz * Math.cos(rotY),
    });
    const fwd = { x: Math.sin(rotY), z: Math.cos(rotY) };
    const right = { x: Math.cos(rotY), z: -Math.sin(rotY) };
    const doorW = L2W(du, 0, d / 2 + 0.55);
    const anchor = L2W(0, h + rise + 0.16, d * 0.2);
    return { g, rotY, fwd, right, L2W, door: { x: doorW.x, z: doorW.z }, anchor, cfg };
  }

  // ---- the ring ------------------------------------------------------------
  // Fountain is at (0,0); the west road comes in along z=0, so the west arc
  // stays open. Order matters: it is the bulb-lighting order (chapel first).
  const B = {};
  B.church = building({
    x: 1.6, z: -13.6, w: 4.6, d: 6.6, h: 3.15, steep: true, locked: true,
    wall: 0xded3b8, roof: 0x7a4f38,
    windows: [
      { side: "F", u: -1.35, y: 1.9, w: 0.5, h: 1.15 }, { side: "F", u: 1.35, y: 1.9, w: 0.5, h: 1.15 },
      { side: "R", u: -1.4, y: 1.7, w: 0.55, h: 0.95 }, { side: "R", u: 1.4, y: 1.7, w: 0.55, h: 0.95 },
    ],
  });
  B.library = building({
    x: 10.6, z: -7.6, w: 4.7, d: 4.5, h: 4.35, sign: "LIBRARY", chimney: true,
    wall: 0xd9cdad, roof: 0x8a5a3c,
    windows: [
      { side: "F", u: -1.35, y: 1.55, w: 0.6, h: 0.85 }, { side: "F", u: 1.35, y: 1.55, w: 0.6, h: 0.85 },
      { side: "F", u: -1.35, y: 3.25, w: 0.6, h: 0.85 }, { side: "F", u: 1.35, y: 3.25, w: 0.6, h: 0.85 },
      { side: "L", u: 0, y: 2.6, w: 0.66, h: 0.9 },
    ],
  });
  B.tools = building({
    x: 12.4, z: 2.2, w: 4.9, d: 4.3, h: 2.95, sign: "TOOLWORKS", chimney: true,
    wall: 0xcabfa8, roof: 0x6f5a44,
    windows: [{ side: "F", u: -1.4, y: 1.5, w: 0.66, h: 0.7 }, { side: "L", u: 0.3, y: 1.5, w: 0.6, h: 0.66 }],
  });
  B.houseA = building({
    x: 6.2, z: 12.2, w: 4.0, d: 3.7, h: 2.55, shutters: true, chimney: true, skew: 0.12,
    wall: 0xd3c39e, roof: 0x8a5a3c, shutterC: 0x565a48,
    windows: [{ side: "F", u: -1.05, y: 1.45, w: 0.56, h: 0.66 }, { side: "F", u: 1.15, y: 1.45, w: 0.56, h: 0.66 }],
  });
  B.houseB = building({
    x: -4.6, z: 12.6, w: 3.8, d: 3.5, h: 2.45, shutters: true, skew: -0.1,
    wall: 0xcfc4ae, roof: 0x9a6a45, shutterC: 0x5a5648,
    windows: [{ side: "F", u: 1.0, y: 1.42, w: 0.56, h: 0.64 }, { side: "R", u: 0, y: 1.42, w: 0.56, h: 0.6 }],
  });
  B.market = building({
    x: -13.4, z: -4.6, w: 4.9, d: 4.3, h: 2.9, sign: "BERRY MARKET",
    wall: 0xdccfae, roof: 0x9a6a45,
    windows: [{ side: "F", u: -1.4, y: 1.5, w: 0.72, h: 0.7 }, { side: "R", u: 0.2, y: 1.5, w: 0.6, h: 0.66 }],
  });
  B.seeds = building({
    x: -8.6, z: -10.4, w: 4.7, d: 4.2, h: 2.85, sign: "ROSIE'S SEEDS", chimney: true,
    wall: 0xd0d0ac, roof: 0x7d6a3f,
    windows: [{ side: "F", u: -1.3, y: 1.5, w: 0.66, h: 0.7 }, { side: "F", u: 1.42, y: 1.5, w: 0.52, h: 0.66 }],
  });

  // ---- per-building props ---------------------------------------------------
  const P = (bp, lx, lz) => bp.L2W(lx, 0, lz);

  { // church: bell tower on the front-left corner, cross finial, no sign
    const bp = B.church, t = bp.L2W(-3.05, 0, 1.55);
    const tw = new THREE.Group();
    const shaft = box(1.5, 4.9, 1.5, 0xded3b8);
    shaft.position.y = 2.45; shaft.castShadow = true;
    const base = box(1.75, 0.55, 1.75, STONE);
    base.position.y = 0.22;
    tw.add(base, shaft);
    [[-1, -1], [1, -1], [-1, 1], [1, 1]].forEach(([sx, sz]) => {
      const post = box(0.13, 0.8, 0.13, TIMBER_DK);
      post.position.set(sx * 0.6, 5.3, sz * 0.6);
      tw.add(post);
    });
    const capRoof = new THREE.Mesh(new THREE.ConeGeometry(1.22, 1.0, 4), M(0x6f5a44));
    capRoof.rotation.y = Math.PI / 4;
    capRoof.position.y = 6.2; capRoof.castShadow = true;
    const bell = new THREE.Mesh(new THREE.SphereGeometry(0.24, 7, 6), M(0x8a7a4e));
    bell.scale.y = 1.25; bell.position.y = 5.35;
    const crossV = box(0.055, 0.46, 0.055, 0xcac2b2);
    crossV.position.y = 6.94;
    const crossH = box(0.26, 0.055, 0.055, 0xcac2b2);
    crossH.position.y = 7.0;
    tw.add(capRoof, bell, crossV, crossH);
    tw.position.set(t.x, 0, t.z);
    tw.rotation.y = bp.rotY;
    worldGroup.add(tw);
    addBoxCol(t.x, t.z, 1.0, 1.0, bp.rotY);
    // round window over the chapel door
    const rose = new THREE.Mesh(new THREE.CylinderGeometry(0.34, 0.34, 0.08, 10), M(PANE));
    rose.rotation.x = Math.PI / 2;
    const rp = bp.L2W(0, 2.75, 3.34);
    rose.position.set(rp.x, rp.y, rp.z);
    rose.rotation.z = bp.rotY;
    const roseRim = new THREE.Mesh(new THREE.TorusGeometry(0.36, 0.05, 5, 12), M(TIMBER_DK));
    roseRim.position.copy(rose.position);
    roseRim.rotation.y = bp.rotY;
    worldGroup.add(rose, roseRim);
  }

  { // market: awning over the window, berry crates, a barrel
    const bp = B.market;
    const awn = box(1.9, 0.07, 0.9, 0x8a5a48);
    const ap = bp.L2W(-1.4, 2.12, 2.55);
    awn.position.set(ap.x, ap.y, ap.z);
    awn.rotation.y = bp.rotY;
    awn.rotateX(0.42);
    worldGroup.add(awn);
    [[-2.2, 3.3, 0x9c4652], [2.4, 3.5, 0x4a5a9c]].forEach(([lx, lz, berry]) => {
      const c = P(bp, lx, lz);
      const crate = box(0.78, 0.42, 0.56, 0x7a5c39);
      crate.position.set(c.x, 0.21, c.z);
      crate.rotation.y = bp.rotY + lx * 0.05;
      crate.castShadow = true;
      worldGroup.add(crate);
      for (let i = 0; i < 4; i++) {
        const fr = new THREE.Mesh(new THREE.SphereGeometry(0.1, 6, 5), M(berry));
        fr.position.set(c.x - 0.17 + (i % 2) * 0.34, 0.5, c.z - 0.1 + Math.floor(i / 2) * 0.2);
        worldGroup.add(fr);
      }
      addCircleCol(c.x, c.z, 0.5);
    });
    const b1 = P(bp, 3.1, 1.6);
    const barrel = new THREE.Mesh(new THREE.CylinderGeometry(0.34, 0.3, 0.74, 9), M(0x6f5438));
    barrel.position.set(b1.x, 0.37, b1.z); barrel.castShadow = true;
    worldGroup.add(barrel);
    addCircleCol(b1.x, b1.z, 0.45);
  }

  { // seeds: window boxes with something still growing, pots by the door
    const bp = B.seeds;
    [-1.3, 1.42].forEach((u) => {
      const wb = box(0.95, 0.17, 0.24, TIMBER);
      const w1 = bp.L2W(u, 1.02, 2.28);
      wb.position.set(w1.x, w1.y, w1.z);
      wb.rotation.y = bp.rotY;
      worldGroup.add(wb);
      for (let i = -1; i <= 1; i++) {
        const bush = new THREE.Mesh(new THREE.IcosahedronGeometry(0.14, 0), M(PAL.leafMid));
        const w2 = bp.L2W(u + i * 0.28, 1.2, 2.28);
        bush.position.set(w2.x, w2.y, w2.z);
        worldGroup.add(bush);
      }
    });
    [[-1.7, 3.0], [1.9, 3.2]].forEach(([lx, lz]) => {
      const c = P(bp, lx, lz);
      const pot = new THREE.Mesh(new THREE.CylinderGeometry(0.24, 0.18, 0.34, 7), M(0x8a5a48));
      pot.position.set(c.x, 0.17, c.z);
      const plant = new THREE.Mesh(new THREE.IcosahedronGeometry(0.24, 0), M(PAL.leafDeep));
      plant.position.set(c.x, 0.5, c.z);
      worldGroup.add(pot, plant);
      addCircleCol(c.x, c.z, 0.35);
    });
  }

  let coals = null, forgeLight = null, forgePos = null;
  { // toolworks: open lean-to sheltering the forge — the square's one warm light
    const bp = B.tools;
    const wallX = 4.9 / 2;
    [[1.15], [3.05]].forEach(([lz]) => {
      const c = bp.L2W(wallX + 1.9, 0, lz - 1.0);
      const post = box(0.14, 1.78, 0.14, TIMBER_DK);
      post.position.set(c.x, 0.89, c.z);
      post.rotation.y = bp.rotY;
      worldGroup.add(post);
    });
    const roofC = bp.L2W(wallX + 1.05, 2.14, 0.15);
    const lean = box(2.35, 0.09, 2.75, 0x6f5a44);
    lean.position.set(roofC.x, roofC.y, roofC.z);
    lean.rotation.y = bp.rotY;
    lean.rotateZ(0.3);
    lean.castShadow = true;
    worldGroup.add(lean);
    const fc = bp.L2W(wallX + 1.15, 0, 0.15);
    const forge = box(1.05, 0.72, 0.85, STONE_DK);
    forge.position.set(fc.x, 0.36, fc.z);
    forge.rotation.y = bp.rotY;
    forge.castShadow = true;
    coals = new THREE.Mesh(new THREE.BoxGeometry(0.72, 0.12, 0.55),
      new THREE.MeshStandardMaterial({ color: SRGB(0xff7a30), emissive: SRGB(0xff5a10), emissiveIntensity: 1.15 }));
    coals.position.set(fc.x, 0.78, fc.z);
    coals.rotation.y = bp.rotY;
    forgePos = { x: fc.x, z: fc.z };
    forgeLight = new THREE.PointLight(SRGB(0xff8a3a), 0.62, 6.0);
    forgeLight.position.set(fc.x, 1.35, fc.z);
    worldGroup.add(forge, coals, forgeLight);
    glowNodes.push(coals);
    addBoxCol(fc.x, fc.z, 0.65, 0.55, bp.rotY);
    const ac = bp.L2W(wallX + 0.7, 0, 1.7);
    const stump = new THREE.Mesh(new THREE.CylinderGeometry(0.26, 0.3, 0.4, 8), M(TIMBER));
    stump.position.set(ac.x, 0.2, ac.z);
    const anvil = box(0.56, 0.26, 0.26, 0x55555f);
    anvil.position.set(ac.x, 0.53, ac.z);
    anvil.rotation.y = bp.rotY;
    worldGroup.add(stump, anvil);
    addCircleCol(ac.x, ac.z, 0.4);
  }

  { // library: ivy up the corner, books left out by the door
    const bp = B.library;
    [[-2.25, 2.0, 0.55, 0.7], [-2.4, 2.0, 1.5, 0.55], [-2.15, 1.85, 2.6, 0.62], [-2.35, 2.1, 3.5, 0.45]]
      .forEach(([lx, lz, ly, r]) => {
        const ivy = new THREE.Mesh(new THREE.IcosahedronGeometry(r, 0), M(PAL.leafDeep));
        const c = bp.L2W(lx, ly, lz);
        ivy.position.set(c.x, c.y, c.z);
        ivy.scale.z = 0.55;
        ivy.rotation.y = bp.rotY + ly;
        worldGroup.add(ivy);
      });
    const bc = P(bp, 1.9, 3.1);
    [0x7a5a5a, 0x5a6a7a, 0x8a7a55].forEach((c, i) => {
      const bk = box(0.34, 0.09, 0.25, c);
      bk.position.set(bc.x, 0.06 + i * 0.095, bc.z);
      bk.rotation.y = bp.rotY + i * 0.35;
      worldGroup.add(bk);
    });
  }

  { // houses: a leaning cart wheel and a barrel — the mockup's street clutter
    const w1 = P(B.houseA, 2.55, 0.9);
    const wheel = new THREE.Mesh(new THREE.CylinderGeometry(0.5, 0.5, 0.09, 10), M(0x35323b));
    wheel.position.set(w1.x, 0.5, w1.z);
    wheel.rotation.set(Math.PI / 2, 0, B.houseA.rotY + 0.35);
    wheel.rotateX(0.22);
    const hub = new THREE.Mesh(new THREE.CylinderGeometry(0.12, 0.12, 0.12, 7), M(0x4a4650));
    hub.position.copy(wheel.position);
    hub.rotation.copy(wheel.rotation);
    worldGroup.add(wheel, hub);
    const b2 = P(B.houseB, -2.3, 0.7);
    const barrel = new THREE.Mesh(new THREE.CylinderGeometry(0.32, 0.28, 0.7, 9), M(0x6f5438));
    barrel.position.set(b2.x, 0.35, b2.z);
    worldGroup.add(barrel);
    addCircleCol(b2.x, b2.z, 0.42);
  }

  // ---- the string-light web -------------------------------------------------
  // A wooden mast by the fountain; strands run from its head to every roof,
  // then building-to-building around the ring. All bulbs are OFF: the reading
  // feature lights them one chapter at a time, in exactly this array order.
  const mast = { x: 2.8, z: 3.7, top: 7.25 };
  {
    const pole = new THREE.Mesh(new THREE.CylinderGeometry(0.075, 0.11, 7.3, 7), M(TIMBER_DK));
    pole.position.set(mast.x, 3.65, mast.z);
    pole.castShadow = true;
    const arm = box(0.66, 0.08, 0.08, TIMBER_DK);
    arm.position.set(mast.x, 7.0, mast.z);
    const foot = new THREE.Mesh(new THREE.CylinderGeometry(0.2, 0.26, 0.3, 7), M(STONE));
    foot.position.set(mast.x, 0.15, mast.z);
    worldGroup.add(pole, arm, foot);
    addCircleCol(mast.x, mast.z, 0.32);
  }

  const ringOrder = ["church", "library", "tools", "houseA", "houseB", "market", "seeds"];
  const wirePts = [];
  const bulbSpots = []; // stable order: radial strands first, then the ring
  function strand(a, b) {
    const dx = b.x - a.x, dy = b.y - a.y, dz = b.z - a.z;
    const len = Math.hypot(dx, dz);
    const sag = 0.16 + len * 0.052;
    const SEG = 13;
    let prev = null;
    for (let i = 0; i <= SEG; i++) {
      const t = i / SEG;
      const pt = new THREE.Vector3(a.x + dx * t, a.y + dy * t - sag * 4 * t * (1 - t), a.z + dz * t);
      if (prev) wirePts.push(prev, pt);
      prev = pt;
    }
    const nB = Math.max(3, Math.floor(len / 0.95));
    for (let k = 1; k <= nB; k++) {
      const t = k / (nB + 1);
      bulbSpots.push(new THREE.Vector3(
        a.x + dx * t, a.y + dy * t - sag * 4 * t * (1 - t) - 0.11, a.z + dz * t));
    }
  }
  const hub = { x: mast.x, y: mast.top, z: mast.z };
  ringOrder.forEach((k) => strand(hub, B[k].anchor));            // radial web
  for (let i = 0; i < ringOrder.length; i++) {                   // perimeter
    strand(B[ringOrder[i]].anchor, B[ringOrder[(i + 1) % ringOrder.length]].anchor);
  }
  const wireGeo = new THREE.BufferGeometry().setFromPoints(wirePts);
  const wires = new THREE.LineSegments(wireGeo, new THREE.LineBasicMaterial({ color: SRGB(0x1b1826) }));
  wires.frustumCulled = false;
  worldGroup.add(wires);

  const UNLIT = SRGB(0x2a2734), LIT = SRGB(0xffd485);
  const bulbs = new THREE.InstancedMesh(
    new THREE.SphereGeometry(0.085, 6, 5),
    new THREE.MeshBasicMaterial({ color: 0xffffff }),
    bulbSpots.length);
  const mtx = new THREE.Matrix4();
  bulbSpots.forEach((p, i) => {
    mtx.makeTranslation(p.x, p.y, p.z);
    bulbs.setMatrixAt(i, mtx);
    bulbs.setColorAt(i, UNLIT);
  });
  bulbs.instanceMatrix.needsUpdate = true;
  if (bulbs.instanceColor) bulbs.instanceColor.needsUpdate = true;
  bulbs.frustumCulled = false; // instances span the square; sphere bounds lie
  worldGroup.add(bulbs);

  // ---- the Gloom haze -------------------------------------------------------
  // Distance fog alone reads as "far away"; the mockup's smoke sits IN the
  // square. Nine soft violet patches drift slowly across the ground and a
  // thin smoke column rises off the forge — all one radial-gradient texture,
  // opacity kept low so the fill cost stays small on phones.
  const fogCv = document.createElement("canvas");
  fogCv.width = fogCv.height = 128;
  {
    const fc2 = fogCv.getContext("2d");
    const grad = fc2.createRadialGradient(64, 64, 6, 64, 64, 62);
    grad.addColorStop(0, "rgba(255,255,255,0.9)");
    grad.addColorStop(0.55, "rgba(255,255,255,0.38)");
    grad.addColorStop(1, "rgba(255,255,255,0)");
    fc2.fillStyle = grad;
    fc2.beginPath(); fc2.arc(64, 64, 63, 0, 6.3); fc2.fill();
  }
  const fogTex = new THREE.CanvasTexture(fogCv);
  // Two kinds of mist, both kept INSIDE the square so the middle of town is
  // never clear: "anchored" patches slowly orbit the fountain plaza, and
  // "drifter" patches wander but re-enter near the center when they stray.
  const hazePatches = [];
  const mkHaze = (ud, sc, y, sprite) => {
    const mat = { map: fogTex, transparent: true, opacity: 0, color: SRGB(0xd9d5ec), depthWrite: false };
    const hm = sprite
      ? new THREE.Sprite(new THREE.SpriteMaterial(mat))
      : new THREE.Mesh(new THREE.PlaneGeometry(1, 1), new THREE.MeshBasicMaterial(mat));
    if (!sprite) hm.rotation.x = -Math.PI / 2;
    hm.scale.set(sc, sprite ? sc * 0.52 : sc, 1);
    hm.position.y = y;
    hm.renderOrder = 3;
    hm.userData = ud;
    worldGroup.add(hm);
    hazePatches.push(hm);
    return hm;
  };
  // the plaza's permanent mist pool: smaller, denser billows than sheets —
  // fog needs visible edges and overlap or it reads as flat lighting.
  // A liberated town has NO haze at all.
  if (!ctx.gloomFree) for (let i = 0; i < 6; i++) {
    mkHaze({
      kind: "orbit",
      orbitR: 1.8 + i * 1.25,
      orbitA: (i / 6) * Math.PI * 2,
      orbitW: (0.03 + i * 0.009) * (i % 2 ? -1 : 1),
      ph: Math.random() * 6.28,
      base: 0.34 - i * 0.02,
    }, 7.5 + i * 1.1, 0.5 + i * 0.07);
  }
  // wanderers between the buildings — quicker, so the motion itself reads
  if (!ctx.gloomFree) for (let i = 0; i < 10; i++) {
    const ha = Math.random() * Math.PI * 2, hr = 3 + Math.random() * 10;
    const hm = mkHaze({
      kind: "drift",
      vx: Math.cos(ha + 1.7) * (0.18 + Math.random() * 0.16),
      vz: Math.sin(ha + 1.7) * (0.18 + Math.random() * 0.16),
      ph: Math.random() * 6.28,
      base: 0.24 + Math.random() * 0.08,
    }, 5.5 + Math.random() * 4.5, 0.42 + Math.random() * 0.55);
    hm.position.x = Math.cos(ha) * hr;
    hm.position.z = Math.sin(ha) * hr;
  }
  // upright wisps: billboards drifting through the square at chest height —
  // from the game's high camera these are what actually says "fog bank"
  if (!ctx.gloomFree) for (let i = 0; i < 5; i++) {
    mkHaze({
      kind: "orbit",
      orbitR: 3 + i * 1.6,
      orbitA: Math.random() * Math.PI * 2,
      orbitW: 0.045 * (i % 2 ? -1 : 1),
      ph: Math.random() * 6.28,
      base: 0.16,
    }, 5.2 + i * 0.8, 1.05, true);
  }
  const smoke = [];
  if (forgePos && !ctx.gloomFree) for (let i = 0; i < 4; i++) {
    const sp = new THREE.Sprite(new THREE.SpriteMaterial({ map: fogTex,
      color: SRGB(0x7a7490), transparent: true, opacity: 0, depthWrite: false }));
    sp.position.set(forgePos.x, 1.1, forgePos.z);
    sp.userData = { off: i / 4 };
    worldGroup.add(sp);
    smoke.push(sp);
  }

  // ---- the Gloom's thieves ---------------------------------------------
  // Movement and bodies live in gloomlings.js; what a successful steal
  // DOES comes in from the game via ctx.gloomHooks.
  const gloomPads = [
    ...Object.values(B).map((bp) => [bp.cfg.x, bp.cfg.z, Math.max(bp.cfg.w, bp.cfg.d) / 2 + 1.1]),
    [0, 0, 3.1],        // fountain
    [mast.x, mast.z, 0.9],
  ];
  // the boss guards the chapel porch, a body-length out from the door
  const bossSpot = (() => {
    const d = B.church.door;
    const L = Math.hypot(d.x, d.z) || 1;
    return { x: d.x - (d.x / L) * 1.7, z: d.z - (d.z / L) * 1.7 };
  })();
  gloomPads.push([bossSpot.x, bossSpot.z, 2.2]); // the little ones keep clear

  const gloomlings = (ctx.gloomHooks && !ctx.gloomFree) ? spawnGloomlings({
    THREE, worldGroup, flat, SRGB, fogTex, forgePos,
    pads: gloomPads, hooks: ctx.gloomHooks,
  }) : null;
  const gloomBoss = (ctx.gloomHooks && !ctx.gloomFree) ? spawnGloomBoss({
    THREE, worldGroup, flat, SRGB, fogTex,
    hooks: ctx.gloomHooks, pos: bossSpot,
    pads: gloomPads.filter(([px, pz]) => !(px === bossSpot.x && pz === bossSpot.z)),
  }) : null;

  const lights = {
    total: bulbSpots.length,
    // world position of bulb i - the light-return flight aims at this
    spot: (i) => (bulbSpots[Math.max(0, Math.min(bulbSpots.length - 1, i | 0))] || new THREE.Vector3()).clone(),
    // Light the first n bulbs (chapters read). Idempotent; clamps.
    setLit(n) {
      const lit = Math.max(0, Math.min(bulbSpots.length, n | 0));
      for (let i = 0; i < bulbSpots.length; i++) bulbs.setColorAt(i, i < lit ? LIT : UNLIT);
      if (bulbs.instanceColor) bulbs.instanceColor.needsUpdate = true;
      if (gloomlings) gloomlings.setLitCount(lit); // light pushes the thieves back
    },
  };

  // Season 1 complete: the whole Gloom cast leaves town, boss last
  function retreatAll(hurry) {
    if (gloomlings && gloomlings.retreatAll) gloomlings.retreatAll(hurry);
    if (gloomBoss && gloomBoss.retreat) gloomBoss.retreat(hurry);
  }

  return {
    gloomlings,
    gloomBoss,
    retreatAll,
    doors: {
      market: B.market.door, seeds: B.seeds.door, tools: B.tools.door,
      library: B.library.door, church: B.church.door,
      // houses are set dressing, but their doors still earn a worn path
      houseA: B.houseA.door, houseB: B.houseB.door,
    },
    anchors: { mast },
    lights,
    update(dt, t) {
      // the forge is the only living light in the pre-save square
      if (coals) coals.material.emissiveIntensity = 1.05 + Math.sin(t * 11.3) * 0.14 + Math.sin(t * 27.1) * 0.06;
      if (forgeLight) forgeLight.intensity = 0.56 + Math.sin(t * 9.7) * 0.09 + Math.sin(t * 23.3) * 0.04;
      // gloom haze: the pool turns over the plaza, the drifters wander the
      // ring — and anything that strays re-enters near the middle of town
      for (const hm of hazePatches) {
        const ud = hm.userData;
        if (ud.kind === "orbit") {
          ud.orbitA += ud.orbitW * dt;
          hm.position.x = Math.cos(ud.orbitA) * ud.orbitR;
          hm.position.z = Math.sin(ud.orbitA) * ud.orbitR;
        } else {
          hm.position.x += ud.vx * dt;
          hm.position.z += ud.vz * dt;
          if (Math.hypot(hm.position.x, hm.position.z) > 16.5) {
            hm.position.x *= -0.28; hm.position.z *= -0.28; // fold back to the plaza
          }
        }
        hm.material.opacity = ud.base * (0.8 + 0.2 * Math.sin(t * 0.36 + ud.ph));
      }
      if (gloomlings) gloomlings.update(dt, t);
      if (gloomBoss) gloomBoss.update(dt, t);
      // forge smoke: four sprites cycling up out of the coals
      for (const sp of smoke) {
        const tt = (t * 0.3 + sp.userData.off) % 1;
        sp.position.y = 1.05 + tt * 2.9;
        sp.position.x = forgePos.x + Math.sin(t * 0.7 + sp.userData.off * 9) * 0.16 * tt;
        sp.position.z = forgePos.z;
        const sc = 0.7 + tt * 1.7;
        sp.scale.set(sc, sc, 1);
        sp.material.opacity = 0.2 * Math.sin(Math.PI * tt);
      }
    },
  };
}
