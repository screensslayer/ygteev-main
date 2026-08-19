// The Gloom Boss — a crater-headed stone brute planted in front of the
// Meadow Town chapel. Nobody prays while he's on the porch.
//
// Built to the concept: pale faceted stone, huge knuckle-dragging arms with
// claw hands, dark crystal clusters on shoulder/forearm/back, glowing purple
// crack-lines across the chest, purple eyes and a jagged lit grin — and a
// column of dark purple smog pouring out of the crater in his head, feeding
// drifting haze that spreads over the whole square.
//
// Movement is full-body and stateful, no navigation: he GUARDS. Weight
// shifts foot to foot, shoulders breathe, head scans; when the player comes
// close he turns with little shuffling steps, leans IN with arms flaring —
// unless they carry River's lantern, in which case he recoils and shields
// his face. Every few seconds of company he barks a recorded line
// (hooks.bark) and shows it in a bubble over his head. Occasionally he
// slams a knuckle into the dirt (hooks.rumble shakes the camera).
//
// Voice lines live in ../data/gloomboss-lines.js — the same strings the
// recordings were rendered from, so the bubble never drifts from the audio.

import { GLOOMBOSS_LINES } from "../data/gloomboss-lines.js";

export default function spawnGloomBoss(ctx) {
  const { THREE, worldGroup, flat, SRGB, fogTex, hooks, pos } = ctx;

  // ---- materials ----------------------------------------------------------
  const stone = flat(0x9aa0b2);
  const stoneDark = flat(0x7c8296);
  const crystal = flat(0x32204e);
  const crystalLit = new THREE.MeshBasicMaterial({ color: SRGB(0x8a4ae0) });
  const glowPurple = new THREE.MeshBasicMaterial({ color: SRGB(0xc07aff) });
  const mouthPit = new THREE.MeshBasicMaterial({ color: SRGB(0x180f26) });
  const grinGlow = new THREE.MeshBasicMaterial({ color: SRGB(0x9a54ff) });

  const boss = new THREE.Group();
  const rig = new THREE.Group(); // everything that leans/breathes
  boss.add(rig);

  // ---- torso + head -------------------------------------------------------
  const torso = new THREE.Mesh(new THREE.IcosahedronGeometry(1.06, 1), stone);
  torso.scale.set(1.18, 1.0, 0.85);
  torso.position.y = 1.7;
  torso.castShadow = true;
  const belly = new THREE.Mesh(new THREE.IcosahedronGeometry(0.8, 1), stoneDark);
  belly.scale.set(1.05, 0.8, 0.8);
  belly.position.y = 1.05;
  const head = new THREE.Group();
  head.position.y = 2.88;
  const skull = new THREE.Mesh(new THREE.IcosahedronGeometry(0.62, 1), stone);
  skull.scale.set(1.22, 0.88, 0.98);
  skull.castShadow = true;
  head.add(skull);
  // crater rim: jagged ring of chunks around the open top
  for (let i = 0; i < 7; i++) {
    const a = (i / 7) * Math.PI * 2;
    const chunk = new THREE.Mesh(new THREE.TetrahedronGeometry(0.16 + (i % 3) * 0.045), stoneDark);
    chunk.position.set(Math.cos(a) * 0.42, 0.5 + (i % 2) * 0.05, Math.sin(a) * 0.34);
    chunk.rotation.set(a, a * 1.7, a * 0.6);
    head.add(chunk);
  }
  // the pit itself — a dark disc the smoke rises out of
  const pit = new THREE.Mesh(new THREE.CircleGeometry(0.34, 8), mouthPit);
  pit.rotation.x = -Math.PI / 2;
  pit.position.y = 0.52;
  head.add(pit);

  // ---- face ----------------------------------------------------------------
  const mkEye = (sx) => {
    const socket = new THREE.Mesh(new THREE.SphereGeometry(0.16, 8, 6), flat(0x1b1626));
    socket.scale.set(1.15, 1.0, 0.5);
    socket.position.set(sx, 0.08, 0.52);
    const eye = new THREE.Mesh(new THREE.SphereGeometry(0.095, 9, 7), glowPurple);
    eye.position.set(sx, 0.08, 0.585);
    head.add(socket, eye);
    return eye;
  };
  const eyeL = mkEye(-0.27), eyeR = mkEye(0.27);
  // heavy stone brow hooding both eyes — the anger lives here
  const brow = new THREE.Mesh(new THREE.BoxGeometry(0.92, 0.16, 0.34), stoneDark);
  brow.position.set(0, 0.28, 0.42);
  brow.rotation.x = 0.3;
  head.add(brow);
  // the grin: dark pit, glowing backing, jagged grey teeth over it
  const grinBack = new THREE.Mesh(new THREE.BoxGeometry(0.78, 0.2, 0.06), mouthPit);
  grinBack.position.set(0, -0.26, 0.56);
  grinBack.rotation.x = 0.12;
  const grinLit = new THREE.Mesh(new THREE.BoxGeometry(0.72, 0.13, 0.05), grinGlow);
  grinLit.position.set(0, -0.26, 0.585);
  grinLit.rotation.x = 0.12;
  head.add(grinBack, grinLit);
  for (let i = 0; i < 5; i++) {
    const up = i % 2 === 0;
    const tooth = new THREE.Mesh(new THREE.ConeGeometry(0.062, 0.15, 4), stone);
    tooth.position.set(-0.26 + i * 0.13, -0.26 + (up ? 0.09 : -0.09), 0.61);
    tooth.rotation.x = up ? Math.PI : 0;
    head.add(tooth);
  }
  rig.add(torso, belly, head);

  // ---- glowing crack-lines (the "constellations" on his chest/arms) -------
  const crackBits = [];
  const crack = (parent, pts, r = 0.02) => {
    const Z = new THREE.Vector3(0, 0, 1);
    for (let i = 0; i + 1 < pts.length; i++) {
      const a = new THREE.Vector3(...pts[i]), b = new THREE.Vector3(...pts[i + 1]);
      const seg = new THREE.Mesh(new THREE.BoxGeometry(r, r, a.distanceTo(b)), crystalLit);
      seg.position.copy(a).add(b).multiplyScalar(0.5);
      // orient in the PARENT's space: lookAt() would aim at world coords
      seg.quaternion.setFromUnitVectors(Z, new THREE.Vector3().subVectors(b, a).normalize());
      parent.add(seg);
      crackBits.push(seg);
    }
    for (const p of pts) {
      const dot = new THREE.Mesh(new THREE.SphereGeometry(0.035, 5, 4), glowPurple);
      dot.position.set(p[0], p[1], p[2]);
      parent.add(dot);
      crackBits.push(dot);
    }
  };
  crack(rig, [[-0.55, 2.05, 0.72], [-0.3, 1.85, 0.82], [-0.42, 1.6, 0.8]]);
  crack(rig, [[0.35, 2.1, 0.75], [0.6, 1.9, 0.72], [0.5, 1.65, 0.78], [0.75, 1.5, 0.6]]);

  // ---- crystal clusters ----------------------------------------------------
  const cluster = (parent, cx, cy, cz, n, s = 1, allDark = false) => {
    for (let i = 0; i < n; i++) {
      const c = new THREE.Mesh(new THREE.ConeGeometry(0.09 * s, (0.3 + (i % 3) * 0.14) * s, 5),
        !allDark && i === n - 1 ? crystalLit : crystal);
      c.position.set(cx + (i - n / 2) * 0.12 * s, cy + (i % 2) * 0.06, cz + ((i * 7) % 3 - 1) * 0.07);
      c.rotation.set((((i * 13) % 10) - 5) * 0.09, 0, (((i * 7) % 10) - 5) * 0.12);
      c.castShadow = true;
      parent.add(c);
    }
  };
  cluster(rig, -0.85, 2.55, 0.05, 5, 1.15);  // left shoulder ridge
  cluster(rig, 0.55, 2.6, -0.3, 3, 0.9);     // right shoulder, smaller
  cluster(rig, 0, 1.9, -0.75, 4, 1.2);       // back row

  // ---- arms: shoulder pivot -> forearm -> claw hand ------------------------
  const mkArm = (side) => {
    const shoulder = new THREE.Group();
    shoulder.position.set(side * 1.12, 2.35, 0);
    const upper = new THREE.Mesh(new THREE.IcosahedronGeometry(0.42, 1), stone);
    upper.scale.set(1, 1.5, 0.95);
    upper.position.y = -0.42;
    upper.castShadow = true;
    const elbow = new THREE.Group();
    elbow.position.y = -0.95;
    const fore = new THREE.Mesh(new THREE.IcosahedronGeometry(0.38, 1), stone);
    fore.scale.set(1.05, 1.45, 1);
    fore.position.y = -0.42;
    fore.castShadow = true;
    const wrist = new THREE.Group();
    wrist.position.y = -0.92;
    const palm = new THREE.Mesh(new THREE.BoxGeometry(0.52, 0.3, 0.5), stoneDark);
    palm.castShadow = true;
    wrist.add(palm);
    for (let f = 0; f < 4; f++) {
      const finger = new THREE.Mesh(new THREE.BoxGeometry(0.11, 0.3, 0.13), stone);
      finger.position.set(-0.18 + f * 0.12, -0.16, 0.2);
      finger.rotation.x = 0.85; // curled claw
      wrist.add(finger);
    }
    const thumb = new THREE.Mesh(new THREE.BoxGeometry(0.12, 0.24, 0.12), stone);
    thumb.position.set(side * 0.26, -0.1, 0.02);
    thumb.rotation.z = side * 0.7;
    wrist.add(thumb);
    elbow.add(fore, wrist);
    shoulder.add(upper, elbow);
    shoulder.rotation.z = side * 0.34; // arms hang wide of the huge torso
    elbow.rotation.x = -0.22;
    rig.add(shoulder);
    return { shoulder, elbow, wrist };
  };
  const armL = mkArm(-1), armR = mkArm(1);
  cluster(armR.elbow, 0.15, -0.35, 0.28, 3, 0.85, true); // right forearm crystals
  crack(armL.elbow, [[-0.1, -0.25, 0.3], [0.08, -0.5, 0.34], [-0.05, -0.72, 0.3]], 0.016);

  // ---- legs: short, planted, with toe wedges -------------------------------
  const mkLeg = (side) => {
    const hip = new THREE.Group();
    hip.position.set(side * 0.52, 0.9, 0);
    const thigh = new THREE.Mesh(new THREE.IcosahedronGeometry(0.36, 1), stoneDark);
    thigh.scale.set(1, 1.25, 1);
    thigh.position.y = -0.3;
    thigh.castShadow = true;
    const foot = new THREE.Mesh(new THREE.BoxGeometry(0.5, 0.28, 0.62), stone);
    foot.position.set(0, -0.76, 0.08);
    foot.castShadow = true;
    for (let tI = 0; tI < 3; tI++) {
      const toe = new THREE.Mesh(new THREE.ConeGeometry(0.08, 0.16, 4), stoneDark);
      toe.rotation.x = Math.PI / 2.3;
      toe.position.set(-0.15 + tI * 0.15, -0.82, 0.44);
      foot.add ? null : null;
      hip.add(toe);
      toe.position.y = -0.82; // toes ride the hip so foot-lifts carry them
    }
    hip.add(thigh, foot);
    rig.add(hip);
    return { hip, foot };
  };
  const legL = mkLeg(-1), legR = mkLeg(1);

  // ---- ground presence ------------------------------------------------------
  const smudge = new THREE.Mesh(new THREE.CircleGeometry(1.5, 10),
    new THREE.MeshBasicMaterial({ color: SRGB(0x120f1c), transparent: true, opacity: 0.42, depthWrite: false }));
  smudge.rotation.x = -Math.PI / 2;
  smudge.position.y = 0.02;
  const groundGlow = new THREE.Mesh(new THREE.PlaneGeometry(1, 1),
    new THREE.MeshBasicMaterial({ map: fogTex, color: SRGB(0x6a3ea0), transparent: true, opacity: 0.12, depthWrite: false, blending: THREE.AdditiveBlending }));
  groundGlow.rotation.x = -Math.PI / 2;
  groundGlow.scale.set(6.5, 6.5, 1);
  groundGlow.position.y = 0.06;
  groundGlow.renderOrder = 3;
  boss.add(smudge, groundGlow);

  // ---- the head smog column + debris + town-wide spread --------------------
  const puffs = [];
  for (let i = 0; i < 10; i++) {
    const sp = new THREE.Sprite(new THREE.SpriteMaterial({
      map: fogTex, color: SRGB(0x4c3a6e), transparent: true, opacity: 0, depthWrite: false }));
    sp.userData = { off: i / 10, spin: (i % 2 ? 1 : -1) * (0.6 + (i % 3) * 0.3) };
    boss.add(sp);
    puffs.push(sp);
  }
  const debris = [];
  for (let i = 0; i < 6; i++) {
    const rock = new THREE.Mesh(new THREE.TetrahedronGeometry(0.07 + (i % 3) * 0.05), crystal);
    rock.userData = { off: i / 6, wob: i * 2.1 };
    boss.add(rock);
    debris.push(rock);
  }
  // his smog drifts OUT over the square, thickening the town's own haze
  const spread = [];
  for (let i = 0; i < 4; i++) {
    const hm = new THREE.Mesh(new THREE.PlaneGeometry(1, 1),
      new THREE.MeshBasicMaterial({ map: fogTex, color: SRGB(0x7a5aa8), transparent: true, opacity: 0, depthWrite: false }));
    hm.rotation.x = -Math.PI / 2;
    const sc = 9 + i * 2.5;
    hm.scale.set(sc, sc, 1);
    hm.renderOrder = 3;
    const a = Math.random() * Math.PI * 2;
    hm.userData = { vx: Math.cos(a) * 0.35, vz: Math.sin(a) * 0.35, base: 0.1 - i * 0.012, ph: i * 1.7 };
    hm.position.set(pos.x, 0.6 + i * 0.07, pos.z);
    worldGroup.add(hm);
    spread.push(hm);
  }

  // ---- bark bubble ----------------------------------------------------------
  const barkCv = document.createElement("canvas");
  barkCv.width = 640; barkCv.height = 160;
  const barkTex = new THREE.CanvasTexture(barkCv);
  const bark = new THREE.Sprite(new THREE.SpriteMaterial({ map: barkTex, transparent: true, opacity: 0, depthWrite: false }));
  bark.scale.set(5.4, 1.35, 1);
  bark.position.y = 4.6;
  boss.add(bark);
  let barkT = 0;
  function showBark(text) {
    const c = barkCv.getContext("2d");
    c.clearRect(0, 0, 640, 160);
    c.font = "800 40px 'Baloo 2', 'Trebuchet MS', sans-serif";
    c.textAlign = "center"; c.textBaseline = "middle";
    // wrap to two lines max
    const words = text.split(" ");
    const lines = [""];
    for (const w of words) {
      const probe = (lines[lines.length - 1] + " " + w).trim();
      if (c.measureText(probe).width > 590 && lines[lines.length - 1]) lines.push(w);
      else lines[lines.length - 1] = probe;
    }
    lines.slice(0, 2).forEach((ln, i) => {
      const y = 80 + (i - (Math.min(lines.length, 2) - 1) / 2) * 46;
      c.lineWidth = 10; c.lineJoin = "round";
      c.strokeStyle = "rgba(16,8,28,.95)";
      c.strokeText(ln, 320, y);
      c.fillStyle = "#d9b6ff";
      c.fillText(ln, 320, y);
    });
    barkTex.needsUpdate = true;
    barkT = 3.4;
  }

  // ---- placement ------------------------------------------------------------
  boss.position.set(pos.x, 0, pos.z);
  boss.rotation.y = Math.atan2(-pos.x, -pos.z); // face the fountain
  worldGroup.add(boss);
  // a LIVE collider (hooks.colliderFor hands back the object) — it walks
  // out with him and zeroes when he's gone, leaving no invisible wall
  const bossCol = hooks.colliderFor ? hooks.colliderFor(pos.x, pos.z, 1.15) : null;

  // ---- brain ---------------------------------------------------------------
  let lastBark = -99, mood = 0, thumpT = 0, nextThump = 6, rot = boss.rotation.y;
  let leaving = false, gone = false, tauntT = 0;

  // A scripted outburst (e.g. the second light landing on the strings):
  // he flares, slams a knuckle into the dirt, and says his piece — heard
  // and felt (camera shake) even if he's off-screen across the square.
  function taunt(lineId) {
    if (gone || leaving) return;
    const line = GLOOMBOSS_LINES.find((l) => l.id === lineId);
    if (!line) return;
    tauntT = 3.2;
    thumpT = 1.1; // wind up, slam — the rumble hook fires at impact
    if (hooks.bark) hooks.bark(`voices/gloomboss-${line.id}.mp3`);
    showBark(line.text);
  }
  const REST_Z = { L: -0.34, R: 0.34 };

  function update(dt, t) {
    if (gone) return;
    if (leaving) {
      // the long walk out: he faces away from the fountain and stomps for
      // the dark past the chapel, smog guttering out behind him
      const face = Math.atan2(boss.position.x, boss.position.z); // outward
      const turn = ((face - rot + Math.PI * 3) % (Math.PI * 2)) - Math.PI;
      rot += turn * Math.min(1, dt * 1.6);
      boss.rotation.y = rot;
      const sp = Math.abs(turn) < 0.5 ? 0.85 : 0.15; // turn first, then go
      boss.position.x += Math.sin(rot) * sp * dt;
      boss.position.z += Math.cos(rot) * sp * dt;
      const sh = Math.sin(t * 5.2);
      legL.hip.position.y = 0.9 + Math.max(0, sh) * 0.1;
      legR.hip.position.y = 0.9 + Math.max(0, -sh) * 0.1;
      rig.position.y = Math.abs(sh) * 0.05;
      rig.rotation.z = Math.sin(t * 2.6) * 0.05; // heavy side-to-side stomp
      if (bossCol) { bossCol.x = boss.position.x; bossCol.z = boss.position.z; }
      for (const sp2 of puffs) sp2.material.opacity *= 1 - Math.min(1, dt * 0.5);
      for (const hm of spread) hm.material.opacity *= 1 - Math.min(1, dt * 0.5);
      for (const rock of debris) rock.visible = false;
      bark.material.opacity *= 1 - Math.min(1, dt * 2);
      if (Math.hypot(boss.position.x, boss.position.z) > 24) {
        gone = true;
        if (bossCol) bossCol.r = 0;
        worldGroup.remove(boss);
        for (const hm of spread) worldGroup.remove(hm);
      }
      return;
    }
    const pp = hooks.playerPos();
    const dx = pp.x - pos.x, dz = pp.z - pos.z;
    const dPlayer = Math.hypot(dx, dz);
    const near = dPlayer < 5.4;
    const lantern = !!(hooks.hasLantern && hooks.hasLantern());

    // mood: 0 = guard idle, 1 = engaged (lean in, or recoil from the lantern)
    if (tauntT > 0) tauntT -= dt;
    mood += (((near || tauntT > 0) ? 1 : 0) - mood) * Math.min(1, dt * 3);

    // turn to face the player when engaged, chapel-front otherwise — with a
    // shuffle: feet lift alternately while the body pivots, so he steps
    const wantRot = near ? Math.atan2(dx, dz) : Math.atan2(-pos.x, -pos.z);
    const turnDelta = ((wantRot - rot + Math.PI * 3) % (Math.PI * 2)) - Math.PI;
    const turning = Math.abs(turnDelta) > 0.06;
    rot += turnDelta * Math.min(1, dt * 2.2);
    boss.rotation.y = rot;
    if (turning) {
      const sh = Math.sin(t * 9);
      legL.hip.position.y = 0.9 + Math.max(0, sh) * 0.07;
      legR.hip.position.y = 0.9 + Math.max(0, -sh) * 0.07;
      rig.position.y = Math.abs(sh) * 0.03;
    } else {
      legL.hip.position.y += (0.9 - legL.hip.position.y) * 0.2;
      legR.hip.position.y += (0.9 - legR.hip.position.y) * 0.2;
      rig.position.y *= 0.8;
    }

    // breath + weight shift — a mountain that is unmistakably alive
    const breath = Math.sin(t * 1.1);
    torso.scale.y = 1.0 + breath * 0.022;
    rig.rotation.z = Math.sin(t * 0.5) * 0.028;
    rig.position.x = Math.sin(t * 0.5) * 0.05; // rocks onto each foot

    // engaged pose: lean IN with arms flaring — or, if that little flame is
    // out, recoil BACK and shield the face
    const leanIn = mood * (lantern ? -0.1 : 0.14);
    rig.rotation.x += (leanIn - rig.rotation.x) * Math.min(1, dt * 4);
    const flare = mood * (lantern ? 0.05 : 0.3);
    armL.shoulder.rotation.z += ((REST_Z.L - flare) - armL.shoulder.rotation.z) * Math.min(1, dt * 4);
    armR.shoulder.rotation.z += ((REST_Z.R + flare) - armR.shoulder.rotation.z) * Math.min(1, dt * 4);
    const shield = mood * (lantern ? 1 : 0);
    armR.shoulder.rotation.x += ((-shield * 1.5) - armR.shoulder.rotation.x) * Math.min(1, dt * 5);
    // idle arm sway rides on top
    armL.shoulder.rotation.x += (Math.sin(t * 1.3) * 0.05 - (shield ? 0 : armL.shoulder.rotation.x)) * (shield ? 0 : Math.min(1, dt * 4));
    head.rotation.y = near ? 0 : Math.sin(t * 0.4) * 0.3; // scanning the square
    head.rotation.x = mood * (lantern ? -0.12 : 0.1);

    // eyes + cracks pulse; everything burns hotter when he's engaged
    const glow = 1 + Math.sin(t * 5.2) * 0.06 + mood * 0.16;
    eyeL.scale.setScalar(glow);
    eyeR.scale.setScalar(glow);
    grinLit.material = grinGlow;
    for (let i = 0; i < crackBits.length; i++) {
      crackBits[i].visible = Math.sin(t * 2.6 + i * 1.7) > -0.55 - mood;
    }

    // the knuckle slam: wind up, drop, dust — every so often while idle
    thumpT -= dt;
    if (!near && thumpT <= -nextThump) {
      thumpT = 1.1; nextThump = 6 + Math.random() * 6;
    }
    if (thumpT > 0) {
      const k = thumpT > 0.55 ? (1.1 - thumpT) / 0.55 : thumpT / 0.55; // up then down
      armR.shoulder.rotation.x = -k * 1.15;
      if (thumpT <= 0.56 && thumpT + dt > 0.56) {
        if (hooks.rumble) hooks.rumble();
      }
    }

    // smog column: rises, spirals, fattens; debris tumbles inside it
    for (const sp of puffs) {
      const tt = (t * 0.22 + sp.userData.off) % 1;
      sp.position.set(
        Math.sin(t * sp.userData.spin + sp.userData.off * 9) * 0.4 * tt,
        3.25 + tt * 5.6,
        Math.cos(t * sp.userData.spin * 0.8 + sp.userData.off * 7) * 0.3 * tt);
      const sc = 1.0 + tt * 3.0;
      sp.scale.set(sc, sc, 1);
      sp.material.opacity = 0.34 * Math.sin(Math.PI * tt) * (1 + mood * 0.25);
    }
    for (const rock of debris) {
      const tt = (t * 0.3 + rock.userData.off) % 1;
      rock.position.set(
        Math.sin(t * 2 + rock.userData.wob) * 0.35 * tt,
        3.3 + tt * 3.4,
        Math.cos(t * 1.7 + rock.userData.wob) * 0.3 * tt);
      rock.rotation.x += dt * 3; rock.rotation.y += dt * 2.2;
      rock.visible = tt < 0.85;
    }
    for (const hm of spread) {
      hm.position.x += hm.userData.vx * dt;
      hm.position.z += hm.userData.vz * dt;
      if (Math.hypot(hm.position.x, hm.position.z) > 21) {
        hm.position.set(pos.x, hm.position.y, pos.z); // pours out anew
      }
      hm.material.opacity = hm.userData.base * (0.75 + 0.25 * Math.sin(t * 0.4 + hm.userData.ph));
    }

    // the barks — thematic, throttled, lantern-aware
    if (near && t - lastBark > 8 && !hooks.uiOpen()) {
      lastBark = t;
      const pool = lantern
        ? GLOOMBOSS_LINES.filter((l) => l.lantern)
        : GLOOMBOSS_LINES.filter((l) => !l.lantern);
      const line = pool[(Math.random() * pool.length) | 0] || GLOOMBOSS_LINES[0];
      if (hooks.bark) hooks.bark(`voices/gloomboss-${line.id}.mp3`);
      showBark(line.text);
    }
    if (barkT > 0) {
      barkT -= dt;
      bark.material.opacity = Math.min(1, barkT / 0.4) * Math.min(1, (3.4 - barkT) * 4);
      bark.position.y = 4.6 + Math.sin(t * 1.4) * 0.06;
    } else {
      bark.material.opacity = 0;
    }
  }

  return { update, pos, taunt, retreat: () => { leaving = true; } };
}
