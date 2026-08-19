// Gloomlings — the Gloom's little thieves, loose in pre-save Meadow Town.
//
// Twelve of them wander the square with a lurch-and-pause creep. Linger too
// close and one turns, flares its eyes, raises both arms, and comes for your
// pockets — if it reaches you it snatches a common fruit (never rares: rares
// glow, and Gloomlings fear light) or a pinch of gold, then bolts for the
// dark and spooks every Gloomling near it into scattering too. They will not
// go near the forge: its ember is the one light in town.
//
// The world module owns bodies and movement; what stealing DOES is decided
// by the game through hooks:
//   hooks.steal(x, z)          -> mutate inventory, floaties, SFX
//   hooks.playerPos()          -> { x, z }
//   hooks.uiOpen()             -> bool (no muggings under menus)
//   hooks.colliderFor(x, z, r) -> live collider object; we drag it around so
//                                 the player can't phase through a Gloomling
//
// Bodies are shared-material meshes; all per-gloom life is transforms, so 12
// of them cost geometry once. Eyes are unlit MeshBasicMaterial — they glow
// in the dusk without twelve point lights.

export default function spawnGloomlings(ctx) {
  const { THREE, worldGroup, flat, SRGB, fogTex, forgePos, pads, hooks } = ctx;
  const COUNT = 12;

  // shared materials/geometry — per-gloom animation uses transforms only
  const bodyMat = flat(0x4e4959);
  const limbMat = flat(0x44404f);      // arms/feet a shade darker than the body
  const darkMat = flat(0x232030);
  const socketMat = flat(0x1b1826);    // eye pits the glow sits inside
  const eyeMat = new THREE.MeshBasicMaterial({ color: SRGB(0xc887ff) });
  const smudgeMat = new THREE.MeshBasicMaterial({ color: SRGB(0x120f1c), transparent: true, opacity: 0.38, depthWrite: false });
  const wispMat = () => new THREE.SpriteMaterial({ map: fogTex, color: SRGB(0x3f3852), transparent: true, opacity: 0.26, depthWrite: false });

  const bodyGeo = new THREE.IcosahedronGeometry(0.42, 1);
  bodyGeo.scale(1, 1.38, 0.9);
  bodyGeo.translate(0, 0.72, 0);      // lifted so the feet get daylight
  const socketGeo = new THREE.SphereGeometry(0.105, 8, 6);
  socketGeo.scale(1, 1.15, 0.5);
  const eyeGeo = new THREE.SphereGeometry(0.07, 8, 6);
  const armGeo = new THREE.IcosahedronGeometry(0.085, 1);
  armGeo.scale(1, 2.9, 1);
  armGeo.translate(0, -0.23, 0);      // hangs from the shoulder pivot
  const handGeo = new THREE.SphereGeometry(0.08, 7, 6);
  handGeo.scale(1, 0.8, 1.15);        // mitten paw
  const legGeo = new THREE.BoxGeometry(0.1, 0.16, 0.1);
  legGeo.translate(0, 0.14, 0);
  const footGeo = new THREE.BoxGeometry(0.19, 0.075, 0.3);
  footGeo.translate(0, 0.04, 0.05);   // toes forward of the ankle
  const smudgeGeo = new THREE.CircleGeometry(0.42, 8);
  smudgeGeo.rotateX(-Math.PI / 2);

  const nearPad = (x, z, extra = 0) =>
    pads.some(([px, pz, pr]) => Math.hypot(x - px, z - pz) < pr + extra);
  const nearForge = (x, z, r) => forgePos && Math.hypot(x - forgePos.x, z - forgePos.z) < r;
  let litCount = 0; // future: chapter bulbs push the dark back
  const nearLitMast = (x, z) => litCount > 0 && Math.hypot(x - 2.8, z - 3.7) < 2.5 + litCount * 0.05;
  const badSpot = (x, z) => nearPad(x, z, 0.4) || nearForge(x, z, 6.5) || nearLitMast(x, z) || Math.hypot(x, z) > 19;

  function pickSpot(rMin, rMax) {
    for (let i = 0; i < 24; i++) {
      const a = Math.random() * Math.PI * 2, r = rMin + Math.random() * (rMax - rMin);
      const x = Math.cos(a) * r, z = Math.sin(a) * r;
      if (!badSpot(x, z)) return { x, z };
    }
    return { x: 0, z: 9 }; // south plaza is always legal
  }

  const glooms = [];
  for (let i = 0; i < COUNT; i++) {
    const g = new THREE.Group();
    const body = new THREE.Mesh(bodyGeo, bodyMat);
    body.castShadow = true;
    // eyes recessed in dark pits, like the concept
    const mkEye = (sx) => {
      const socket = new THREE.Mesh(socketGeo, socketMat);
      socket.position.set(sx, 0.96, 0.315);
      const eye = new THREE.Mesh(eyeGeo, eyeMat);
      eye.position.set(sx, 0.96, 0.345);
      return [socket, eye];
    };
    const [sockL, eL] = mkEye(-0.155);
    const [sockR, eR] = mkEye(0.155);
    const frown = new THREE.Mesh(new THREE.BoxGeometry(0.09, 0.02, 0.02), darkMat);
    frown.position.set(0, 0.76, 0.4);
    // arms with paws, hinged at the shoulder so they can swing OR reach
    const mkArm = (sx) => {
      const pivot = new THREE.Group();
      pivot.position.set(sx * 0.4, 0.82, 0);
      const arm = new THREE.Mesh(armGeo, limbMat);
      const hand = new THREE.Mesh(handGeo, limbMat);
      hand.position.set(0, -0.46, 0.02);
      pivot.add(arm, hand);
      pivot.rotation.z = sx * 0.14;
      return pivot;
    };
    const armL = mkArm(-1), armR = mkArm(1);
    // legs that actually step: ankle pivots carrying leg + foot
    const mkLeg = (sx) => {
      const pivot = new THREE.Group();
      pivot.position.set(sx * 0.15, 0, 0);
      pivot.add(new THREE.Mesh(legGeo, limbMat), new THREE.Mesh(footGeo, limbMat));
      return pivot;
    };
    const legL = mkLeg(-1), legR = mkLeg(1);
    const smudge = new THREE.Mesh(smudgeGeo, smudgeMat);
    smudge.position.y = 0.02;
    const wisp = new THREE.Sprite(wispMat());
    wisp.position.set(0.06, 1.42, 0);
    wisp.scale.set(0.5, 0.5, 1);
    const trail = new THREE.Sprite(wispMat());   // the smoke it drags behind
    trail.material.opacity = 0.16;
    trail.position.set(0, 0.16, -0.34);
    trail.scale.set(0.66, 0.4, 1);
    g.add(body, sockL, sockR, eL, eR, frown, armL, armR, legL, legR, smudge, wisp, trail);

    const baseScale = 0.86 + Math.random() * 0.08; // siblings, not clones
    g.scale.setScalar(baseScale);

    const home = pickSpot(4.5, 15);
    g.position.set(home.x, 0, home.z);
    worldGroup.add(g);
    glooms.push({
      g, eL, eR, armL, armR, legL, legR, wisp, baseScale,
      col: hooks.colliderFor ? hooks.colliderFor(home.x, home.z, 0.32) : null,
      reach: 0,           // 0 = arms hang, 1 = full grabby reach
      mode: "wander",     // wander | pause | creep | flee
      tgt: pickSpot(4.5, 15),
      ph: Math.random() * 6.28,
      rot: Math.random() * 6.28,
      timer: 1 + Math.random() * 3,
      cd: 3 + Math.random() * 6,   // per-gloom steal cooldown
      hideT: 0,
    });
  }
  let lastStealT = -99; // one mugging at a time, town-wide

  function scatterFrom(x, z, radius = 6, dur = 2.2) {
    for (const gl of glooms) {
      if (Math.hypot(gl.g.position.x - x, gl.g.position.z - z) < radius) {
        gl.mode = "flee";
        gl.timer = dur + Math.random();
        const away = Math.atan2(gl.g.position.z - z, gl.g.position.x - x) + (Math.random() - 0.5) * 0.8;
        gl.tgt = { x: gl.g.position.x + Math.cos(away) * 10, z: gl.g.position.z + Math.sin(away) * 10 };
      }
    }
  }

  function update(dt, t) {
    const pp = hooks.playerPos();
    for (const gl of glooms) {
      const P = gl.g.position, ud = gl;
      ud.cd -= dt;

      if (ud.mode === "gone") continue;
      if (ud.mode === "leave") {
        // the exodus: a beat of hesitation, then a straight sprint out past
        // the tree wall, legs churning; removed once the fog has them
        ud.timer -= dt;
        if (ud.timer <= 0) {
          const dx = ud.tgt.x - P.x, dz = ud.tgt.z - P.z;
          const face = Math.atan2(dx, dz);
          P.x += Math.sin(face) * 2.1 * dt;
          P.z += Math.cos(face) * 2.1 * dt;
          const turn = ((face - ud.rot + Math.PI * 3) % (Math.PI * 2)) - Math.PI;
          ud.rot += turn * Math.min(1, dt * 8);
          gl.g.rotation.y = ud.rot;
          const stride = t * 9 + ud.ph;
          gl.legL.rotation.x = Math.cos(stride) * 0.6;
          gl.legR.rotation.x = Math.cos(stride + Math.PI) * 0.6;
          gl.armL.rotation.x = Math.sin(stride + Math.PI) * 0.35;
          gl.armR.rotation.x = Math.sin(stride) * 0.35;
          P.y = Math.abs(Math.sin(stride)) * 0.05;
          if (ud.col) { ud.col.x = P.x; ud.col.z = P.z; }
          if (Math.hypot(P.x, P.z) > 24) {
            ud.mode = "gone";
            if (ud.col) ud.col.r = 0;
            worldGroup.remove(gl.g);
          }
        }
        continue;
      }

      const dPlayer = Math.hypot(pp.x - P.x, pp.z - P.z);

      // fear of light beats everything: caught in the forge glow → bolt
      if (nearForge(P.x, P.z, 5.5) || nearLitMast(P.x, P.z)) {
        ud.mode = "flee"; ud.timer = 2;
        const src = nearForge(P.x, P.z, 5.5) ? forgePos : { x: 2.8, z: 3.7 };
        const away = Math.atan2(P.z - src.z, P.x - src.x);
        ud.tgt = { x: P.x + Math.cos(away) * 9, z: P.z + Math.sin(away) * 9 };
      }

      // River's lantern makes the player a walking light source — nothing
      // with gloom in its veins will come near, let alone pickpocket. They
      // bolt, but they never leave town: repelled, not defeated.
      if (hooks.hasLantern && hooks.hasLantern()
          && ud.mode !== "flee" && dPlayer < 4.2) {
        ud.mode = "flee"; ud.timer = 1.5 + Math.random() * 0.8;
        const away = Math.atan2(P.z - pp.z, P.x - pp.x) + (Math.random() - 0.5) * 0.5;
        ud.tgt = { x: P.x + Math.cos(away) * 9, z: P.z + Math.sin(away) * 9 };
      }

      if (ud.mode === "wander" || ud.mode === "pause") {
        // the mugging: player lingering close, cooldowns clear, no UI open
        if (dPlayer < 2.3 && ud.cd <= 0 && t - lastStealT > 7 && !hooks.uiOpen()) {
          ud.mode = "creep"; ud.timer = 1.6;
        }
      }

      let speed = 0, face = ud.rot;
      if (ud.mode === "pause") {
        ud.timer -= dt;
        face = ud.rot + dt * 0.35; // slow scanning turn — it is LOOKING
        if (ud.timer <= 0) { ud.mode = "wander"; ud.tgt = pickSpot(4.5, 15); }
      } else if (ud.mode === "wander") {
        const dx = ud.tgt.x - P.x, dz = ud.tgt.z - P.z, dd = Math.hypot(dx, dz);
        if (dd < 0.6) {
          if (Math.random() < 0.45) { ud.mode = "pause"; ud.timer = 1.4 + Math.random() * 2.4; }
          else ud.tgt = pickSpot(4.5, 15);
        } else {
          // the creepy lurch: surge, die down, surge again
          const lurch = Math.pow(Math.max(0, Math.sin(t * 2.1 + ud.ph)), 1.7);
          speed = 0.14 + lurch * 0.62;
          face = Math.atan2(dx, dz);
        }
      } else if (ud.mode === "creep") {
        ud.timer -= dt;
        const dx = pp.x - P.x, dz = pp.z - P.z;
        face = Math.atan2(dx, dz);
        speed = 0.85; // deliberate, unbroken approach — the telegraph
        if (dPlayer < 0.95) {
          lastStealT = t; ud.cd = 12;
          // a broken hook must never kill the frame loop mid-iteration
          try { hooks.steal(P.x, P.z); }
          catch (e) { console.error("[gloomling] steal hook failed", e); }
          scatterFrom(P.x, P.z, 6, 2.2);  // and the whole pack bolts
          ud.mode = "flee"; ud.timer = 3.2;
          const away = Math.atan2(P.z - pp.z, P.x - pp.x) + (Math.random() - 0.5) * 0.6;
          ud.tgt = { x: P.x + Math.cos(away) * 11, z: P.z + Math.sin(away) * 11 };
        } else if (ud.timer <= 0 || dPlayer > 3.4 || hooks.uiOpen()) {
          ud.mode = "wander"; ud.cd = 5; // player slipped away — call it off
        }
      } else if (ud.mode === "flee") {
        ud.timer -= dt;
        const dx = ud.tgt.x - P.x, dz = ud.tgt.z - P.z;
        face = Math.atan2(dx, dz);
        speed = 1.6 + Math.max(0, ud.timer) * 0.5; // burst, then winded
        if (ud.timer <= 0) {
          // Gloomlings NEVER despawn — a spent flee (lantern, forge, scatter,
          // even a successful mugging) just decays into skulking from
          // wherever the run ended. Twelve went in, twelve stay on stage.
          ud.mode = "wander";
          ud.tgt = pickSpot(4.5, 15);
        }
      }

      // steer + keep out of bad ground (soft push, no physics)
      if (speed > 0) {
        const nx = P.x + Math.sin(face) * speed * dt;
        const nz = P.z + Math.cos(face) * speed * dt;
        if (!nearPad(nx, nz, 0.15) || ud.mode === "flee") { P.x = nx; P.z = nz; }
        else ud.tgt = pickSpot(4.5, 15);
      }
      if (ud.col) { ud.col.x = P.x; ud.col.z = P.z; } // solid little body
      const turn = ((face - ud.rot + Math.PI * 3) % (Math.PI * 2)) - Math.PI;
      ud.rot += turn * Math.min(1, dt * (ud.mode === "flee" ? 9 : 4));
      gl.g.rotation.y = ud.rot + Math.sin(t * 1.3 + ud.ph) * 0.05;

      // body language: hunch forward, roll with the lurch, bob on surges
      const moving = speed > 0.1;
      const stride = (ud.mode === "flee" ? t * 8.5 : ud.mode === "creep" ? t * 4.6 : t * 2.6) + ud.ph;
      gl.g.rotation.x = 0.05 + (ud.mode === "creep" ? 0.1 : 0) + Math.sin(stride) * 0.03;
      gl.g.rotation.z = Math.sin(stride * 0.5) * 0.06;
      P.y = moving ? Math.abs(Math.sin(stride)) * 0.05 : 0.005;

      // the little feet: alternate step — lift, swing through, plant
      const step = moving ? 1 : 0.15;
      gl.legL.position.y = Math.max(0, Math.sin(stride)) * 0.09 * step;
      gl.legL.position.z = Math.cos(stride) * 0.1 * step;
      gl.legL.rotation.x = Math.cos(stride) * 0.55 * step;
      gl.legR.position.y = Math.max(0, Math.sin(stride + Math.PI)) * 0.09 * step;
      gl.legR.position.z = Math.cos(stride + Math.PI) * 0.1 * step;
      gl.legR.rotation.x = Math.cos(stride + Math.PI) * 0.55 * step;

      // arms: hang and swing while walking, come UP and OUT when it wants
      // what you're carrying (and stay half-raised while it flees with it)
      const reachTgt = ud.mode === "creep" ? 1 : ud.mode === "flee" ? 0.45 : 0;
      ud.reach += (reachTgt - ud.reach) * Math.min(1, dt * 6);
      const swingL = Math.sin(stride + Math.PI) * 0.3 * step;
      const swingR = Math.sin(stride) * 0.3 * step;
      gl.armL.rotation.x = swingL * (1 - ud.reach) + (-1.3 - Math.sin(t * 9) * 0.06) * ud.reach;
      gl.armR.rotation.x = swingR * (1 - ud.reach) + (-1.3 + Math.sin(t * 9.4) * 0.06) * ud.reach;
      gl.armL.rotation.z = 0.14 * (1 - ud.reach) - 0.1 * ud.reach;   // paws close in
      gl.armR.rotation.z = -0.14 * (1 - ud.reach) + 0.1 * ud.reach;

      // eyes flare while creeping; wisp curls always
      const flare = ud.mode === "creep" ? 1.55 : ud.mode === "flee" ? 1.25 : 1;
      gl.eL.scale.setScalar(flare + Math.sin(t * 6 + ud.ph) * 0.07);
      gl.eR.scale.setScalar(flare + Math.sin(t * 6.4 + ud.ph) * 0.07);
      gl.wisp.position.y = 1.4 + Math.sin(t * 1.7 + ud.ph) * 0.06;
      gl.wisp.material.opacity = 0.2 + Math.sin(t * 1.1 + ud.ph) * 0.07;
    }
  }

  // Season won: every Gloomling runs for the tree line and does not come
  // back. The ONE exception to "they never despawn" — this is the exodus,
  // staggered so the square empties as a fleeing crowd, not a formation.
  function retreatAll() {
    for (const gl of glooms) {
      if (gl.mode === "gone") continue;
      gl.mode = "leave";
      gl.timer = Math.random() * 1.2; // stagger the panic
      const away = Math.atan2(gl.g.position.z, gl.g.position.x) + (Math.random() - 0.5) * 0.6;
      gl.tgt = { x: Math.cos(away) * 30, z: Math.sin(away) * 30 };
    }
  }

  return {
    update,
    retreatAll,
    setLitCount: (n) => { litCount = n; },
    scatterFrom,
    // read-only peek for dev tooling and future quest logic
    peek: () => glooms.map((gl) => ({ x: gl.g.position.x, z: gl.g.position.z, mode: gl.mode })),
  };
}
