// River Lab — design bench for the new River model (the librarian).
// Reference: teen girl, messy top bun, teal hoodie, tan backpack, ripped
// grey skinny jeans, black hi-top sneakers. Supercell-grade low poly:
// chunky faceted silhouettes, flat shading, saturated-but-soft palette.
// Approved model graduates into dragon-garden-quest.jsx as makeRiverGirl().
import * as THREE from "three";

const SRGB = (hex) => new THREE.Color(hex).convertSRGBToLinear();
const flat = (color, opts = {}) => {
  const m = new THREE.MeshStandardMaterial({ roughness: 0.9, metalness: 0.02, flatShading: true, ...opts });
  m.color.copy(SRGB(color));
  if (opts.emissive !== undefined) m.emissive.copy(SRGB(opts.emissive));
  return m;
};

// ---------------- palette (picked off the reference) ----------------
// The model itself now lives IN THE GAME (dragon-garden-quest.jsx,
// makeRiverGirl) — this bench slices it out of the shipped source at
// runtime, so what renders here is exactly what ships. Edit it THERE.
import raw from "./dragon-garden-quest.jsx?raw";
const cut = (a, b) => {
  const i = raw.indexOf(a), j = raw.indexOf(b, i);
  if (i < 0 || j < 0) throw new Error("slice failed: " + a);
  return raw.slice(i, j);
};
export const makeRiverGirl = new Function("THREE", "flat", "SRGB",
  cut("function makeRiverGirl()", "// ---- Villagers:") + "; return makeRiverGirl;")(THREE, flat, SRGB);

// ============================ bench scene ============================
const app = document.getElementById("app");
const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
renderer.outputEncoding = THREE.sRGBEncoding;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
app.appendChild(renderer.domElement);

const scene = new THREE.Scene();
scene.background = SRGB(0xe9ebed);
const cam = new THREE.PerspectiveCamera(33, 1, 0.1, 100);

scene.add(new THREE.HemisphereLight(SRGB(0xfdfdff), SRGB(0xb9b4ac), 0.75));
const key = new THREE.DirectionalLight(SRGB(0xfff3e2), 1.05);
key.position.set(3.5, 6, 4.5);
key.castShadow = true;
key.shadow.mapSize.set(1024, 1024);
scene.add(key);
const rim = new THREE.DirectionalLight(SRGB(0xdfe9ff), 0.35);
rim.position.set(-4, 5, -4);
scene.add(rim);

const ground = new THREE.Mesh(new THREE.CircleGeometry(30, 48).rotateX(-Math.PI / 2),
  new THREE.MeshStandardMaterial({ color: SRGB(0xe4e6e8), roughness: 1 }));
ground.receiveShadow = true;
scene.add(ground);

const river = makeRiverGirl();
scene.add(river);

const LOOK = new THREE.Vector3(0, 1.6, 0);
const CAMS = {
  front: [0, 1.9, 5.6],
  tq: [2.7, 2.0, 4.8],
  side: [5.5, 1.9, 0.25],
  back: [0, 2.0, -5.6],
  face: [0, 2.65, 1.9],
  feet: [0.9, 0.55, 2.2],
  hands: [0.7, 1.45, 1.6],
};
const LOOKS = { face: [0, 2.7, 0], feet: [0, 0.4, 0], hands: [0.32, 1.5, 0] };
window.__cam = (k) => {
  const p = CAMS[k] || CAMS.front;
  cam.position.set(...p);
  cam.lookAt(LOOKS[k] ? new THREE.Vector3(...LOOKS[k]) : LOOK);
  window.__step(1);
  return k;
};
window.__spin = (rad) => { river.rotation.y = rad; window.__step(1); return rad; };
// the game's walk cycle, verbatim (dragon-garden-quest.jsx riverWalk block)
window.__walkPose = (tw) => {
  const U = river.userData, sw = Math.sin(tw);
  U.legL.rotation.x = sw * 0.6;
  U.legR.rotation.x = -sw * 0.6;
  U.armL.rotation.x = -sw * 0.5;
  U.armR.rotation.x = Math.sin(tw + 0.35) * 0.55;
  U.armL.rotation.z = -0.1 - Math.abs(sw) * 0.06;
  U.armR.rotation.z = 0.1 + Math.abs(Math.sin(tw + 0.35)) * 0.06;
  U.body.rotation.x = 0.08;
  river.position.y = Math.abs(sw) * 0.028;
  window.__step(1);
  return "pose " + tw;
};
function __fit() {
  const w = Math.max(320, app.clientWidth || innerWidth), h = Math.max(240, app.clientHeight || innerHeight);
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2.5));
  renderer.setSize(w, h);
  cam.aspect = w / h; cam.updateProjectionMatrix();
}
window.__step = (n = 1) => { __fit(); renderer.render(scene, cam); return "ok"; };
__fit(); window.__cam("front");
