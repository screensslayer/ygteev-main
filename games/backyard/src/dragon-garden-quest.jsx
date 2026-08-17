import React, { useRef, useEffect, useState } from "react";
import * as THREE from "three";
import { SNORE_B64, EAT_B64 } from "./dragon-sfx.js";
// ---- Glowlands (Phase 1 gateway slice) — all new systems live under ./glowlands/ ----
import {
  initGlowlandsAudio, playLightfoundFanfare, playEncounterSting,
  startEastRoadTravelLoop, stopEastRoadTravelLoop,
  duckAmbient as glowDuckAmbient, releaseAmbientDuck,
} from "./glowlands/audio-motifs.js";
import {
  initLantern, mountLanternHud, unmountLanternHud, getLantern,
  canEnter as lanternCanEnter, showGateRefusal, setLantern as glowSetLantern,
  refreshLantern, LANTERN_TIERS,
} from "./glowlands/lantern.js";
import createSatchel from "./glowlands/satchel.js";
import createTownBook from "./glowlands/townbook.js";
import createPrologue from "./glowlands/prologue.js";
import { startEncounter as glowStartEncounter } from "./glowlands/combat.js";
import { STARTER_SERUMS, FIRST_STUDY_SESSION_MINTS } from "./glowlands/data/combat-data.js";
import buildHomeAdditions from "./glowlands/maps/home-additions.js";
import SplashScreen from "./splash/SplashScreen.jsx";
import { PlatePill, Medallion, SquareButton, EmberPlaque, InventorySheet, StonePanel, LevelBar, SeedShop, CountBadge, LockedSeedNotice, BerryMarket, CommunityInventory, PlayerProfile, Wardrobe, Almanac, Toolworks, InventoryBoard, HarvestForecast, LevelBarH, CharacterStudio, T as T_UI } from "./splash/ui-kit.jsx";
import WeeklyBoardModal from "./splash/WeeklyBoard.jsx";
import ReadingPlayer from "./splash/ReadingPlayer.jsx";
import buildMeadowAdditions, { MEADOW_TRIGGERS, MEADOW_TUNING } from "./glowlands/maps/meadow-additions.js";
import * as EastRoad from "./glowlands/maps/east-road.js";
// Already loaded by main.jsx — reused here for fetchPassage (get-bible-passage).
import { supabase } from "./supabaseClient.js";

/* ============================================================
   DRAGON GARDEN QUEST — v3 "Painted Meadow"
   Art pass inspired by high-end low-poly reference:
   • Flat-shaded faceted geometry everywhere
   • Layered pine forests + snow-capped mountains on the horizon
   • Individual flagstone paths, petaled flowers, chimney smoke
   • Gabled shingle cottage, warm long-shadow lighting
   • Ornate wood-and-gold fantasy UI
   ============================================================ */

// iOS silent-switch workaround: in WKWebView/Safari, pure Web Audio is treated
// as ambient sound and muted by the ringer switch — but a playing <audio>
// ELEMENT flips the page's audio session to "media playback", which ignores
// the switch. We keep a looping silent element alive; started from the PLAY
// button tap (and re-kicked on every in-game tap via unlockAudio).
function makeSilentWav() {
  const rate = 8000, n = rate / 2; // 0.5s of 16-bit mono silence
  const buf = new ArrayBuffer(44 + n * 2);
  const v = new DataView(buf);
  const wstr = (o, s) => { for (let i = 0; i < s.length; i++) v.setUint8(o + i, s.charCodeAt(i)); };
  wstr(0, "RIFF"); v.setUint32(4, 36 + n * 2, true); wstr(8, "WAVEfmt ");
  v.setUint32(16, 16, true); v.setUint16(20, 1, true); v.setUint16(22, 1, true);
  v.setUint32(24, rate, true); v.setUint32(28, rate * 2, true);
  v.setUint16(32, 2, true); v.setUint16(34, 16, true);
  wstr(36, "data"); v.setUint32(40, n * 2, true);
  let b = ""; const u8 = new Uint8Array(buf);
  for (let i = 0; i < u8.length; i += 8192) b += String.fromCharCode.apply(null, u8.subarray(i, i + 8192));
  return "data:audio/wav;base64," + btoa(b);
}
function ensureAudioKeeper() {
  let el = window.__BY_KEEPER;
  if (!el) {
    el = document.createElement("audio");
    el.src = makeSilentWav();
    el.loop = true;
    el.setAttribute("playsinline", "");
    el.preload = "auto";
    window.__BY_KEEPER = el;
  }
  if (el.paused) {
    const pr = el.play();
    if (pr && pr.catch) pr.catch(() => {});
  }
}

const REGROW_SECS = 180; // fallback; home plants regrow after each harvest instead of disappearing
const MAX_HARVESTS = 3;  // a home plant yields this many harvests, then the plot frees up
const FRUIT_PER_HARVEST = 2;

const SEEDS = {
  strawberry: { name: "Strawberry", cost: 50,  currency: "xp",   sell: 6,   grow: 20, regrow: 180, color: 0xe8384f, glow: false, feed: 30 },
  blueberry:  { name: "Blueberry",  cost: 120, currency: "xp",   sell: 15,  grow: 30, regrow: 300, color: 0x4f6de8, glow: false, feed: 40 },
  sunfruit:   { name: "Sunfruit",   cost: 300, currency: "xp",   sell: 45,  grow: 45, regrow: 480, color: 0xffb020, glow: false, feed: 55 },
  // Glow tiers (church-only, quiz-gated): yieldInt mirrors by_rare_seeds.
  // yield_interval_seconds — 1 league berry per interval, so shorter = more
  // per 5 min. All glow trees live 24h. leaf/berry/halo drive the tree look.
  glowberry:  { name: "Glowberry",  cost: 120, currency: "gold", sell: 100, grow: 300, color: 0x7dfcd0, glow: true, feed: 100, yieldInt: 300, rate: "1 berry / 5m",   leaf: 0x1f6a5a, leafGlow: 0x2fae8f, berry: 0x59c8ff, halo: 0x66ccff },
  starberry:  { name: "Starberry",  cost: 200, currency: "gold", sell: 150, grow: 300, color: 0x8fd0ff, glow: true, feed: 120, yieldInt: 150, rate: "2 berries / 5m", leaf: 0x2a4a7a, leafGlow: 0x5a9ae8, berry: 0xdff0ff, halo: 0x9fd0ff },
  dawnberry:  { name: "Dawnberry",  cost: 350, currency: "gold", sell: 220, grow: 300, color: 0xffb3a0, glow: true, feed: 140, yieldInt: 100, rate: "3 berries / 5m", leaf: 0x8a4432, leafGlow: 0xff8a5a, berry: 0xffd9a8, halo: 0xffb080 },
  gloryberry: { name: "Gloryberry", cost: 550, currency: "gold", sell: 320, grow: 300, color: 0xc99aff, glow: true, feed: 160, yieldInt: 75,  rate: "4 berries / 5m", leaf: 0x50257a, leafGlow: 0xa05aff, berry: 0xf0dfff, halo: 0xc9a0ff },
};

// Old Eli's onboarding narration lives as static mp3s in public/voices
// (fetched on first audio init). It used to be base64-inlined right here —
// ~480kB of source in every bundle — and files also make a re-record a
// drop-in rather than a source edit. See tools/gen-intro-lines.mjs.

// Cache-buster for EVERY voice clip we fetch (onboarding, church, Eli's
// one-shots). Re-recording a line reuses its filename, so without this a
// browser happily serves the old take forever. One constant rather than a
// literal per loader, and tools/gen-intro-lines.mjs bumps it automatically
// after a render — the version must never depend on someone remembering.
const VOICE_V = 3;

const MAP_LABELS = {
  HOME: "🏡 Home Meadow", TOWN: "🏘️ Meadow Town", CHURCH: "⛪ Grace Community Garden",
  SHOP_SEEDS: "🌱 Rosie's Rare Seeds", SHOP_MARKET: "🧺 The Berry Market", SHOP_TOOLS: "⚒️ Grimble's Toolworks",
  EASTROAD: "🛤️ The East Road",
};

const FENCE_TIERS = [
  { x1: -6.2, x2: 3.2, z1: 6.2, z2: 14.6, cols: [-4.7, -1.55, 1.6], rows: [7.6, 9.9, 12.2], cost: 0 },
  { x1: -6.2, x2: 9.8, z1: 6.2, z2: 17.0, cols: [-4.7, -1.55, 1.6, 4.75, 7.9], rows: [7.6, 9.9, 12.2, 14.5], cost: 2000 },
  { x1: -9.35, x2: 12.95, z1: 6.2, z2: 19.3, cols: [-7.85, -4.7, -1.55, 1.6, 4.75, 7.9, 11.05], rows: [7.6, 9.9, 12.2, 14.5, 16.8], cost: 4500 },
];
const kitCostAt = (n) => 150 + n * 50;

// c = accent (borders/glows on light cards), t = text (dark enough to read)
const RARITY = {
  strawberry: { tier: "Common", c: "#9ab87a", t: "#5f7d3c" },
  blueberry: { tier: "Uncommon", c: "#6a9ad8", t: "#3868ab" },
  sunfruit: { tier: "Rare", c: "#e0a03a", t: "#a3660e" },
  glowberry: { tier: "Legendary", c: "#7dfcd0", t: "#0f8f68" },
  starberry: { tier: "Epic", c: "#8fd0ff", t: "#2f6ea8" },
  dawnberry: { tier: "Mythic", c: "#ffb3a0", t: "#b0543a" },
  gloryberry: { tier: "Celestial", c: "#c99aff", t: "#7a3ab8" },
};
const LEVEL_XP = (lvl) => 60 + (lvl - 1) * 90;

const BIBLE_QUESTIONS = [
  { q: "How many days did God take to create the world before resting?", o: ["3", "6", "7", "40"], a: 1 },
  { q: "Who built the ark?", o: ["Moses", "Abraham", "Noah", "David"], a: 2 },
  { q: "How did the animals enter Noah's ark?", o: ["One by one", "Two by two", "In herds", "By size"], a: 1 },
  { q: "What did David use to defeat Goliath?", o: ["A sword", "A spear", "A sling and stone", "A bow"], a: 2 },
  { q: "Who was swallowed by a great fish?", o: ["Jonah", "Peter", "Paul", "Elijah"], a: 0 },
  { q: "How many disciples did Jesus choose?", o: ["7", "10", "12", "40"], a: 2 },
  { q: "What is the first book of the Bible?", o: ["Exodus", "Genesis", "Psalms", "Matthew"], a: 1 },
  { q: "Where was Jesus born?", o: ["Nazareth", "Jerusalem", "Bethlehem", "Galilee"], a: 2 },
  { q: "What was Jesus' first miracle?", o: ["Walking on water", "Turning water into wine", "Feeding 5,000", "Healing a blind man"], a: 1 },
  { q: "Who led the Israelites out of Egypt?", o: ["Joshua", "Moses", "Aaron", "Joseph"], a: 1 },
  { q: "What sea did God part for the Israelites?", o: ["The Dead Sea", "The Sea of Galilee", "The Red Sea", "The Jordan River"], a: 2 },
  { q: "In what garden did Adam and Eve live?", o: ["Gethsemane", "Eden", "Canaan", "Zion"], a: 1 },
  { q: "How many loaves fed the five thousand?", o: ["5", "7", "12", "40"], a: 0 },
  { q: "Who denied Jesus three times?", o: ["Judas", "Thomas", "Peter", "John"], a: 2 },
  { q: "What fell from heaven to feed Israel in the desert?", o: ["Quail only", "Manna", "Figs", "Honey"], a: 1 },
  { q: "Who received the Ten Commandments?", o: ["Abraham", "David", "Moses", "Solomon"], a: 2 },
  { q: "How many days was Jonah inside the fish?", o: ["1", "3", "7", "40"], a: 1 },
  { q: "Who was thrown into the lions' den?", o: ["Daniel", "Shadrach", "Jeremiah", "Samson"], a: 0 },
  { q: "What did Jesus calm with the words 'Peace, be still'?", o: ["A crowd", "A storm", "A fire", "A battle"], a: 1 },
  { q: "Whose strength was in his hair?", o: ["Gideon", "Samson", "Saul", "Elisha"], a: 1 },
  { q: "Who was the father of Isaac?", o: ["Jacob", "Noah", "Abraham", "Lot"], a: 2 },
  { q: "How many days and nights did it rain in the flood?", o: ["7", "12", "40", "100"], a: 2 },
  { q: "What did the dove bring back to Noah?", o: ["A fig", "An olive leaf", "A berry", "Wheat"], a: 1 },
  { q: "Who betrayed Jesus for thirty pieces of silver?", o: ["Peter", "Judas", "Pilate", "Herod"], a: 1 },
];
const PLAYER_R = 0.45;

// ================= ART PALETTE — single source of truth (sRGB hex; wrap in SRGB() at use) =================
const PAL = { grassBase: 0x8cab4c, grassSun: 0xb2c25e, grassShade: 0x5c8a44, soil: 0x7a5138, pathStone: 0xc7ad7e, leafLime: 0x9ec455, leafMid: 0x619e46, leafDeep: 0x38714a, leafWarm: 0xc98e3f, bark: 0x7a5a3e, stone: 0x9d948a, waterSurf: 0x5fb4c4, waterDeep: 0x2e7286, skyTop: 0x4a8fd4, skyMid: 0xa9d3e4, skyHorizon: 0xd9e8d8, sun: 0xffe0a8, ambientSky: 0xb4cfe6, ambientGnd: 0x7f8f4e, fog: 0xd3e2ce, wood: 0xc9b68c, roof: 0xb5654a, plaster: 0xefe2c8, foam: 0xf4f7f5 };
// Bespoke non-day atmospheres (shop-interior night / church golden hour) — keep their identity,
// but sun/fog/sky values route through these named variables, never inline hex at call sites.
const ATMO_NIGHT = { top: 0x241f33, mid: 0x35304a, bot: 0x4a4460, fog: 0x2a2438, sun: 0xffd9a0, hemiSky: 0x8a84a8, hemiGnd: 0x4a4458 };
const ATMO_SUNSET = { top: 0x54408c, mid: 0xf0a670, bot: 0xffd9a0, fog: 0xe8a878, sun: 0xff9a4c, hemiSky: 0xf0b890, hemiGnd: 0x6a5438 };

// Curated wardrobe palettes. Raw hex ints — old saved values outside these
// arrays still render fine, they just won't show a selection ring.
// SKIN_TONES — 8-step porcelain -> deep umber ramp, warm throughout
const SKIN_TONES = [0xf7dcc2, 0xf2c9a4, 0xe6b58e, 0xd19a6b, 0xb97f57, 0x9a6540, 0x7a4b30, 0x5c3823];
// HAIR_COLORS — soft black, dark brown, chestnut, copper, golden, sandy blond, silver, rose
const HAIR_COLORS = [0x241813, 0x4a2f1c, 0x77492b, 0xb5502e, 0xc9963c, 0xd9b98a, 0x9a9aa4, 0xd06a8a];
// SHIRT_COLORS — 10 garden-harmonious fabrics: cornflower, lagoon teal,
// fern green, sunflower gold, marigold, terracotta, brick red, wild rose,
// dusk plum, storm slate
const SHIRT_COLORS = [0x3a72c9, 0x2f9a8f, 0x5c8f45, 0xe3b23c, 0xe0862f, 0xc95f3a, 0xb5432f, 0xd06a8a, 0x7a5a9a, 0x4a5568];
// BOOT_COLORS — walnut, charcoal, oxblood, navy, moss, tan, stone, mulberry
const BOOT_COLORS = [0x3f2f20, 0x1e1a16, 0x8a2f24, 0x2d4a7a, 0x2f6e3a, 0xa87840, 0x8d8073, 0x6e4a63];
const HAT_OPTS = [
  { k: "straw", e: "👒", n: "Straw" }, { k: "beanie", e: "🧶", n: "Beanie" },
  { k: "cap", e: "🧢", n: "Flat Cap" }, { k: "bucket", e: "🪣", n: "Bucket" },
  { k: "crown", e: "🌸", n: "Crown" },
  { k: "shroom", e: "🍄", n: "Shroom" }, { k: "none", e: "🚫", n: "None" },
];
const ACC_OPTS = [
  { k: "basket", e: "🧺", n: "Basket" }, { k: "pack", e: "🎒", n: "Backpack" },
  { k: "satchel", e: "👜", n: "Satchel" }, { k: "glasses", e: "👓", n: "Specs" },
  { k: "scarf", e: "🧣", n: "Scarf" }, { k: "stick", e: "🦯", n: "Stick" },
  { k: "none", e: "🚫", n: "None" },
];
const STYLE_OPTS = [
  { k: "tee", e: "👕", n: "Tee" }, { k: "overalls", e: "👖", n: "Overalls" },
  { k: "hoodie", e: "🧥", n: "Hoodie" }, { k: "raincoat", e: "☔", n: "Raincoat" },
  { k: "vest", e: "🦺", n: "Vest" },
];
const HAIR_STYLES = [
  { k: "crop", e: "🌾", n: "Crop" }, { k: "side", e: "🍂", n: "Side Part" },
  { k: "curls", e: "🌀", n: "Curls" }, { k: "pony", e: "🎀", n: "Ponytail" },
  { k: "buns", e: "🍡", n: "Buns" }, { k: "long", e: "🌊", n: "Long" },
];
// ---- Character Studio: the five slabs and what each one edits ----
// Item icons are baked renders of the real meshes (tools/bake-item-icons.mjs);
// "none" has no mesh, so its tile falls back to a carved NONE plate.
const OPT_ICON = (slot, v) => (v === "none" ? null : `/ui/kit/opt/${slot}-${v}.png`);
const asItems = (slot, list) => list.map((o) => ({ v: o.k, name: o.n, icon: OPT_ICON(slot, o.k) }));
const STUDIO_CATS = [
  { key: "hair", slot: "hairStyle", items: asItems("hairStyle", HAIR_STYLES),
    swatches: [{ slot: "hair", label: "HAIR COLOUR", list: HAIR_COLORS }] },
  { key: "clothes", slot: "style", items: asItems("style", STYLE_OPTS),
    swatches: [{ slot: "shirt", label: "COLOUR", list: SHIRT_COLORS },
               { slot: "boots", label: "BOOTS", list: BOOT_COLORS }] },
  { key: "skin", slot: "skin",
    items: SKIN_TONES.map((v) => ({ v, name: "Skin", icon: `/ui/kit/opt/skin-${v}.png` })) },
  { key: "hat", slot: "hat", items: asItems("hat", HAT_OPTS) },
  { key: "extra", slot: "accessory", items: asItems("accessory", ACC_OPTS) },
];

const WOOD_TEX = "radial-gradient(130% 90% at 50% -25%, rgba(255,255,255,0.95), rgba(255,255,255,0) 55%), linear-gradient(180deg, #ffffff 0%, #e9f5fd 50%, #cfe9fa 100%)";
const Corners = () => (
  <>
    {[["top", "left"], ["top", "right"], ["bottom", "left"], ["bottom", "right"]].map(([v, h]) => (
      <span key={v + h} style={{
        position: "absolute", [v]: 6, [h]: 6, width: 15, height: 15, pointerEvents: "none",
        borderTop: v === "top" ? "3px solid #ffb845" : "none",
        borderBottom: v === "bottom" ? "3px solid #ffb845" : "none",
        borderLeft: h === "left" ? "3px solid #ffb845" : "none",
        borderRight: h === "right" ? "3px solid #ffb845" : "none",
        borderRadius: 3, opacity: 0.85, boxShadow: "0 0 6px rgba(255,184,69,0.3)",
      }} />
    ))}
  </>
);
const Ribbon = ({ children }) => (
  <div style={{ textAlign: "center", margin: "0 0 12px" }}>
    <div style={{
      display: "inline-flex", alignItems: "center", gap: 10, padding: "6px 18px",
      background: "linear-gradient(180deg,#ffffff,#dff0fb)", border: "1px solid #2f7fc1",
      boxShadow: "inset 0 0 0 1px rgba(255,184,69,0.3), 0 3px 8px rgba(0,0,0,0.5)",
      borderRadius: 6, color: "#ffb845", fontSize: 15, letterSpacing: 2, fontWeight: 700,
    }}>
      <span style={{ opacity: 0.65, fontSize: 11 }}>◆</span>{children}<span style={{ opacity: 0.65, fontSize: 11 }}>◆</span>
    </div>
  </div>
);
const INTRO_PAGES = [
  { t: "Well, well… so you're the new keeper of this old backyard. I'm Eli — I've tended gardens since before your grandmother could whistle.", focus: "eli" },
  { t: "Mind the cave yonder. Ember sleeps there — a good-hearted dragon with a bottomless belly. Keep him fed, and he'll keep watch over you. Let him go hungry… and he'll help himself to your harvest.", focus: "cave" },
  { t: "Every gardener begins the same way: a seed, a little dirt, and a whole lot of hope. Those three strawberry seeds in your pouch? My gift. Show me what you can do.", focus: "eli", task: "plant", gift: { key: "strawberry", n: 3 } },
  { t: "Ha! Good hands, child. Now comes the gardener's hardest lesson — waiting. When the berries ripen, gather them up.", focus: "eli", task: "harvest" },
  { t: "Hear that rumble from the cave? That's Ember dreaming of breakfast. Throw him a Strawberry by clicking on him — a fed dragon is a happy dragon. Mind, that belly won't stay full for long.", focus: "cave", task: "feed" },
  { t: "Look at that smile! You've the heart of a true gardener. Here — a Blueberry seed. You've earned it.", focus: "eli", gift: { key: "blueberry", n: 1 } },
  { t: "Now hear me well: some seeds are too holy for ordinary dirt. Glowberries take root only in blessed soil — across the river, in the youth group garden.", focus: "bridge" },
  { t: "And if you haven't joined a youth group in the YGTeeV app, don't wait, child. No champion ever grew alone — that fellowship is the richest soil you'll ever plant yourself in.", focus: "eli" },
  { t: "Off you go now. The soil is waiting… and so is Ember's appetite. Find me at the church garden when you're ready.", focus: "eli", end: true },
];
const INTRO_TASK_LABEL = {
  plant: "Plant a Strawberry in your garden",
  harvest: "Harvest your ripe Strawberries",
  feed: "Throw Ember a Strawberry by clicking on him!",
};

// Eli's challenge greeting. The long speech in the quiz card is what a
// gardener hears the FIRST time they try to plant; every planting after
// rotates through these so the toll never reads as the same lecture twice.
// Wander up to Eli at his post and he mutters one of these, dry as dust.
// Voiced at voices/eli-quip-{1..12}.mp3; shuffled so you rarely hear a
// repeat, and rate-limited so he isn't a chatterbox.
// glyphs for the 3D "+1" harvest pops — the rare crops read as their own
// fruit rather than a generic sparkle (which players mistook for XP)
const FRUIT_EMOJI_3D = {
  strawberry: "🍓", blueberry: "🫐", sunfruit: "🍑",
  glowberry: "🔵", starberry: "⭐", dawnberry: "🟠", gloryberry: "🟣",
};

const ELI_QUIPS = [
  /*  1 */ "Hold on, child — I'm searching for encouragement in the book of Job.",
  /*  2 */ "Patience is a fruit of the Spirit. It is not, sadly, a fruit ye can harvest.",
  /*  3 */ "Ah. Ye know Noah waited forty days? Ye've waited four seconds and ye look weary.",
  /*  4 */ "Consider the lilies. They toil not. Neither, I've noticed, do they weed.",
  /*  5 */ "Solomon had seven hundred wives. Man never knew a moment's peace in his garden neither.",
  /*  6 */ "The meek shall inherit the earth. The rest of ye will have to buy seed like everyone else.",
  /*  7 */ "I did tell Methuselah to slow down. Nine hundred sixty-nine years and still in a hurry.",
  /*  8 */ "Jonah ran from his callin'. Spent three days regrettin' it. Mind where ye wander.",
  /*  9 */ "There's a time to plant, and a time to pluck up. This here's a time to stop starin' at me.",
  /* 10 */ "Even the Almighty rested on the seventh day. I'm on about my four thousandth.",
  /* 11 */ "Ask and it shall be given. Ye haven't asked. Ye've just been standin' there.",
  /* 12 */ "David slew a giant with one stone. Ye can't slay one weed with two hands. No judgment.",
];

// Eli's spoken reactions during the challenge (voices/eli-*.mp3). Short,
// and indexed by question so three in a row are never the same grunt.
const ELI_RIGHT_LINES = [
  "Aye, that's it.",
  "Well remembered, child!",
  "Ha! Right ye are.",
];
const ELI_WRONG_LINES = [
  "Nay — not quite.",
  "Hmm. Not so, child.",
  "Ah, close. But no.",
];

const ELI_QUIZ_LINES = [
  /*  1 */ "Back again, are ye? Good. Three questions from the Good Book — two right and the soil is yours.",
  /*  2 */ "Ah, another seed and another test. Ye know the way of it: answer me three, get two right.",
  /*  3 */ "Steady, child. Sacred soil don't open for just anyone. Three questions — two right.",
  /*  4 */ "Ye've the seed, I've the questions. Two of three, and I'll step aside.",
  /*  5 */ "Hold a moment! Blessed ground asks a blessed mind. Three from Scripture — two right.",
  /*  6 */ "So ye return. Let's see if the Word stuck. Three questions, two right, and plant away.",
  /*  7 */ "Not so fast, young gardener. Prove the reading's in ye — two of three.",
  /*  8 */ "Fine seed ye've got there. Now — three questions. Miss more than one and it waits.",
  /*  9 */ "Every planting earns its place. Three from the Good Book, child. Two right.",
  /* 10 */ "Well now! Another go at the blessed soil. Same toll as ever: two of three.",
  /* 11 */ "Patience. This ground's been here longer than us both. Answer three; two right.",
  /* 12 */ "Ye look ready. Let's find out. Three questions from Scripture, two to pass.",
  /* 13 */ "A gardener's hands are only half of it. Show me the other half — three questions.",
  /* 14 */ "Hold there. Seeds are easy; wisdom's the work. Two of three and it's yours.",
  /* 15 */ "Back so soon? Ha! Three questions then, same as always. Two right.",
  /* 16 */ "This soil remembers every seed. Earn it, child — three questions, two right.",
  /* 17 */ "Ah, ye've brought another. Then ye know: three from the Good Book, two right.",
  /* 18 */ "Wait now. Blessed ground, blessed words. Answer me three, and get two of them.",
  /* 19 */ "Ye're keen — I like that. But keen don't plant. Three questions, two right.",
  /* 20 */ "One more time then. Three questions from Scripture; two right and the row is yours.",
];

// Eli's one-time welcome the first time a member enters the community garden.
// Narration: public/voices/church-{1..6}.mp3. No tasks — explanation only.
const CHURCH_INTRO_PAGES = [
  { t: "Welcome explorer — the shared soil of your whole youth group is just over yonder. What grows here, grows for everyone." },
  { t: "You're not alone in these rows. Your friends tend this same ground — you'll see them here, planting right alongside you." },
  { t: "See those plots? Only Glowberry seeds take root in blessed soil like this. You'll bring the seeds from town — but the planting here must be earned." },
  { t: "Before I let you plant, I'll test you — three questions from Scripture you've already studied. Answer two of three, and the soil is yours." },
  { t: "A Glowberry grows into a sacred tree, and every berry it bears is counted toward your youth group's harvest that week. These trees will only last 24 hours, so keep coming back to plant more." },
  { t: "Grow the most berries together, and your garden tops the Garden League. Go on now — plant when you're ready.", end: true },
];

const hexCss = (h) => "#" + h.toString(16).padStart(6, "0");
const Swatch = ({ c, sel, onPick }) => (
  <div onClick={onPick} style={{
    width: 27, height: 27, borderRadius: "50%", background: hexCss(c), cursor: "pointer",
    border: sel ? "3px solid #ffb845" : "2px solid rgba(0,0,0,0.45)",
    boxShadow: sel ? "0 0 9px rgba(255,184,69,0.65)" : "inset 0 1px 2px rgba(255,255,255,0.35), 0 1px 2px rgba(0,0,0,0.4)",
  }} />
);

const GoldCoin = ({ size = 15 }) => (
  <span style={{
    display: "inline-block", width: size, height: size, borderRadius: "50%",
    background: "radial-gradient(circle at 35% 30%, #ffe9a8, #e8b84f 55%, #a06f22)",
    border: "1px solid #6e4a14",
    boxShadow: "inset 0 -2px 3px rgba(90,60,10,0.55), inset 0 1px 2px rgba(255,240,200,0.85), 0 1px 2px rgba(0,0,0,0.4)",
    verticalAlign: "-2px", flex: "0 0 auto",
  }} />
);

export default function DragonGardenQuest() {
  const mountRef = useRef(null);
  const gameRef = useRef(null);

  const [hud, setHud] = useState({
    gold: 25, xp: window.YGTEEV?.profile?.xp ?? 10000, level: 1, hunger: 100,
    map: "HOME", prompt: "", selectedSeed: "strawberry",
    inv: { seeds: { strawberry: 0, blueberry: 0, sunfruit: 0, glowberry: 0, starberry: 0, dawnberry: 0, gloryberry: 0 },
           fruit: { strawberry: 0, blueberry: 0, sunfruit: 0, glowberry: 0, starberry: 0, dawnberry: 0, gloryberry: 0 } },
    league: { mine: 0, fund: 0, endMs: Date.now() + 6048e5, rivals: [], rows: [], pulse: {} },
    showHunger: false, promptType: null,
    intro: { page: null, task: null },
    youth: false,
    outfit: { skin: 0xf2c9a4, hair: 0x4a2f1c, hairStyle: "crop", style: "tee", shirt: 0x3a72c9, boots: 0x3f2f20, hat: "straw", accessory: "basket" },
    build: { hoe: false, fenceTier: 0, kitCost: 150, canPlace: false, deedCost: 2000 },
  });
  const [toasts, setToasts] = useState([]);
  const [shop, setShop] = useState(null);
  const [rampage, setRampage] = useState(false);
  const [started, setStarted] = useState(false);
  // splash stays mounted ~0.6s after START so its slide-away plays while the
  // camera glides home; then it unmounts for good.
  const [splashMounted, setSplashMounted] = useState(true);
  const [quiz, setQuiz] = useState(null);
  const [muted, setMuted] = useState(false);
  const [mapFx, setMapFx] = useState(null);
  const [coinFx, setCoinFx] = useState([]);
  const [tray, setTray] = useState(false);
  const [buildMode, setBuildMode] = useState(false);
  const [counterTalk, setCounterTalk] = useState(null);
  const [bridgeTalk, setBridgeTalk] = useState(false);
  const reqBridgeRef = useRef(() => {});
  reqBridgeRef.current = () => setBridgeTalk(true);
  // 24h harvest forecast, handed over at the chapel picnic table
  const [forecast, setForecast] = useState(null);
  const reqForecastRef = useRef(() => {});
  reqForecastRef.current = (f) => { gameRef.current?.SFX?.sparkle?.(); setForecast(f); };
  // gold-bag pickup: "found" card → Berry Market flyer → closed
  const [goldBagStep, setGoldBagStep] = useState(null);
  const reqGoldBagRef = useRef(() => {});
  reqGoldBagRef.current = () => setGoldBagStep("found");
  // daily red-bag question card: { bagIdx, q, options, phase, picked, busy, result }
  const [redBag, setRedBag] = useState(null);
  const reqRedBagRef = useRef(() => {});
  reqRedBagRef.current = (payload) => setRedBag(payload);
  // Eli's community-garden welcome — current page index (0..5) or null
  const [churchIntro, setChurchIntro] = useState(null);
  const reqChurchIntroRef = useRef(() => {});
  reqChurchIntroRef.current = (n) => setChurchIntro(n);
  // Garden League live board + rank-movement memory (session-scoped)
  const [board, setBoard] = useState(false);
  const [lockedSeed, setLockedSeed] = useState(false);
  const prevRanksRef = useRef({});
  const rankMoveRef = useRef({});
  const introInfo = hud.intro || { page: null, task: null };
  const introDlg = introInfo.page != null;
  const [taskSplash, setTaskSplash] = useState(null);
  // "finish talking to Eli first" notice — rendered over the profile menu
  // (NOT a toast: those can be dropped by the one-at-a-time rule and sit in
  // a layer the user may miss; this is deterministic and self-clearing)
  const [lockNote, setLockNote] = useState(false);
  const [almanac, setAlmanac] = useState(false);
  // Character Studio: which slab is expanded, the avatar render shown on the
  // left, and the outfit as it was on open so CANCEL can put it back.
  const [studioCat, setStudioCat] = useState("hair");
  const [studioAvatar, setStudioAvatar] = useState(null);
  const studioSnap = useRef(null);
  // Read-to-earn-XP: the offer slots in between the gem bar filling and the
  // LEVEL UP badge. The next section is prefetched so the dock can slide in
  // the instant the bar settles.
  const [reading, setReading] = useState(null);
  const [levelBadgeAt, setLevelBadgeAt] = useState(null);
  const nextReadRef = useRef(null);
  const loadNextReading = React.useCallback(() => {
    const api = window.YGTEEV_API;
    if (!api?.nextReading) return;
    api.nextReading()
      .then((d) => { nextReadRef.current = d?.section ? d : null; })
      .catch(() => { nextReadRef.current = null; });
  }, []);
  useEffect(() => { if (started) loadNextReading(); }, [started, loadNextReading]);
  // Levelled up: offer the reading if a section is waiting, otherwise go
  // straight to the badge. Never during Eli's onboarding — he has the floor.
  const onLevelReady = React.useCallback(() => {
    const next = nextReadRef.current;
    if (next && !gameRef.current?.introActive) setReading(next);
    else setLevelBadgeAt(Date.now());
  }, []);
  const endReading = React.useCallback(() => {
    setReading(null);
    setLevelBadgeAt(Date.now());
    // Always refetch, not just on completion. Stopping part-way through
    // banks verses server-side, so the cached offer is stale the moment the
    // player closes — without this a resumed section still says verse 0.
    loadNextReading();
  }, [loadNextReading]);
  const [acquired, setAcquired] = useState(null); // { icon, name } — post-purchase moment
  const [toolNote, setToolNote] = useState(null); // { title, body } — lock/info explainers
  const acquiredTimer = useRef(null);
  const lockNoteTimer = useRef(null);
  // Eli's seed gift card — { key, n, page }; claimed via "ADD TO POCKET"
  const [seedGift, setSeedGift] = useState(null);
  const reqSeedGiftRef = useRef(() => {});
  reqSeedGiftRef.current = (g) => setSeedGift(g);
  // "while you were gone" — Ember's off-map raids, reported on arrival home
  const reqAwayReportRef = useRef(() => {});
  reqAwayReportRef.current = (eaten) => {
    const counts = {};
    eaten.forEach((k) => { counts[k] = (counts[k] || 0) + 1; });
    const parts = Object.entries(counts).map(([k, n]) =>
      `${n} ${SEEDS[k]?.name || "plant"}${n > 1 ? " plants" : " plant"}`);
    const list = parts.length > 1
      ? parts.slice(0, -1).join(", ") + " and " + parts[parts.length - 1]
      : parts[0];
    gameRef.current?.SFX?.wrong?.();
    setToolNote({
      title: "🐉 WHILE YOU WERE GONE",
      body: `Ember got hungry and helped himself to ${list}. Keep his belly full and he'll leave your garden be.`,
    });
  };
  const prevIntroTaskRef = useRef(null);
  useEffect(() => {
    const t = introInfo.task || null;
    if (t && t !== prevIntroTaskRef.current) {
      prevIntroTaskRef.current = t;
      setTaskSplash(t);
      const id = setTimeout(() => setTaskSplash(null), 2050);
      return () => clearTimeout(id);
    }
    if (!t) prevIntroTaskRef.current = null;
  }, [introInfo.task]);
  // Studio lifecycle: snapshot on open, re-render the avatar whenever the
  // outfit actually changes (hud.outfit is a fresh object every sync, so key
  // the effect on its CONTENTS or it re-renders on every game tick).
  const studioOpen = shop === "style";
  const outfitKey = JSON.stringify(hud.outfit);
  useEffect(() => {
    if (!studioOpen) return;
    studioSnap.current = { ...hud.outfit };
    setStudioCat("hair");
  }, [studioOpen]); // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => {
    if (!studioOpen) return;
    setStudioAvatar(gameRef.current?.avatarFull?.() || null);
  }, [studioOpen, outfitKey]);
  const cancelStudio = () => {
    if (studioSnap.current) gameRef.current?.setOutfit(studioSnap.current);
    gameRef.current?.SFX?.click?.();
    setShop("profile");
  };
  const studioW = Math.min(
    360,
    (typeof window !== "undefined" ? window.innerWidth : 360) * 0.92,
    (typeof window !== "undefined" ? window.innerHeight : 640) * 0.74,
  );

  const introNext = () => gameRef.current?.introAdvance();
  const introSkip = () => gameRef.current?.skipIntro();
  const counterShopRef = useRef(false);
  const reqCounterRef = useRef(() => {});
  reqCounterRef.current = (kind) => setCounterTalk({ kind, phase: "ask" });

  const COUNTER_CFG = {
    seeds: { name: "Rosie", emoji: "👩‍🌾", ring: "#4da34a", ask: "Well hello, sprout! Looking for seeds to grow somethin' wonderful?", yes: "Show me the seeds", no: "Just looking", bye: "Come back anytime, dear — the soil misses you already!" },
    market: { name: "Marlo", emoji: "🧑‍🌾", ring: "#d8842f", ask: "Fresh haul today? Have you got somethin' to sell me?", yes: "Yes, let's trade", no: "Not today", bye: "Come back again — my scales are always honest!" },
    tools: { name: "Grimble", emoji: "🧔🏽", ring: "#6a5a9a", ask: "Hmph. After tools and land for that garden o' yers?", yes: "Show me your wares", no: "Just browsing", bye: "Aye. Come back when ye need good iron." },
  };
  const counterYes = () => {
    if (!counterTalk) return;
    counterShopRef.current = true;
    const kind = counterTalk.kind;
    setCounterTalk(null);
    setShop(kind);
  };
  const counterNo = () => {
    setCounterTalk((c) => (c ? { ...c, phase: "bye" } : c));
    setTimeout(() => {
      setCounterTalk(null);
      gameRef.current?.endCounter();
    }, 1500);
  };
  useEffect(() => {
    if (!shop && counterShopRef.current) {
      counterShopRef.current = false;
      gameRef.current?.endCounter();
    }
  }, [shop]);

  // Garden picker — multi-group users choose which community garden to
  // visit when crossing the bridge. { opts: [{id,name}], ex } | null.
  const [gardenPick, setGardenPick] = useState(null);
  const reqGardenPickRef = useRef(() => {});
  reqGardenPickRef.current = (opts, ex) => setGardenPick({ opts, ex });

  const reqTransitionRef = useRef(() => {});
  reqTransitionRef.current = (label) => {
    setMapFx({ label, phase: "in" });
    setTimeout(() => {
      gameRef.current?.doPendingMap();
      setMapFx({ label, phase: "out" });
      setTimeout(() => {
        setMapFx(null);
        gameRef.current?.endTransition();
      }, 640);
    }, 420);
  };
  const flyCoinsRef = useRef(() => {});
  flyCoinsRef.current = (n) => {
    const vw = window.innerWidth, vh = window.innerHeight;
    const batch = Array.from({ length: Math.min(n, 10) }, (_, i) => ({
      id: Math.random().toString(36).slice(2),
      sx: vw * 0.5 + (Math.random() - 0.5) * 140,
      sy: vh * 0.55 + (Math.random() - 0.5) * 70,
      d: i * 55,
    }));
    setCoinFx((c) => [...c, ...batch]);
    setTimeout(() => setCoinFx((c) => c.filter((x) => !batch.includes(x))), 1200);
  };

  // ONE notification at a time: a new message replaces whatever is showing,
  // so notices never stack or queue up. (Its own timeout still only clears
  // the toast it created, so a newer one is never cut short.)
  const toast = (text, kind = "info", art = null) => {
    const id = Math.random().toString(36).slice(2);
    setToasts([{ id, text, kind, art }]);
    setTimeout(() => setToasts((t) => t.filter((x) => x.id !== id)), 3800);
  };

  useEffect(() => {
    // The scene boots on mount and renders live BEHIND the splash overlay;
    // `started` is purely "splash dismissed" (movement gate + audio unlock).
    const mount = mountRef.current;
    const W = () => mount.clientWidth, H = () => mount.clientHeight;

    // ================= RENDERER =================
    const renderer = new THREE.WebGLRenderer({ antialias: true });
    // The world renders at 1x while the title splash covers it (it's just a
    // backdrop there); dismissSplash() restores full retina via G.restoreRes.
    renderer.setPixelRatio(1);
    renderer.setSize(W(), H());
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    // Direct sRGB output — NO render-to-texture grade pass. The old fullscreen
    // post pass roughly doubled fill cost (fatal on WKWebView phones); its mild
    // grade (sat 1.04 / con 1.06 / vig .06) is approximated by ACES tone
    // mapping + exposure here and a free CSS vignette overlay in the JSX.
    renderer.outputEncoding = THREE.sRGBEncoding;
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.1;
    mount.appendChild(renderer.domElement);

    // ================= AUDIO: generative ambient score + synthesized SFX =================
    let AC = null, audioOut = null, musicBus = null, sfxBus = null, fountainGain = null, snoreGain = null, eatBuf = null;
    let voiceBufs = [], voiceSrc = null, voiceGain = null, voiceDuckOrig = null;
    const AUDIO = { muted: false };
    // Recorded music loops (public/music/) — the ONLY music source; maps
    // without a track are silent. HOME's track also covers the title splash
    // (audio can only start on the first user gesture — platform rule).
    const MUSIC_TRACKS = {
      HOME: "/music/home-loop-v2.m4a",  // "Adventure Game" — splash + home garden
      CHURCH: "/music/church-loop-v2.m4a", // "RedLionProduction" — community garden
      TOWN: "/music/town-loop.m4a",        // city-park ambience — Meadow Town
    };
    let trackBufs = {}, trackSrc = null, trackGain = null, trackKey = null, trackWanted = null;
    const MUSIC_FULL = 0.4, MUSIC_DUCKED = 0.11;
    let musicDucked = false;
    function initAudio() {
      if (AC) return;
      try { AC = new (window.AudioContext || window.webkitAudioContext)(); } catch (e) { return; }
      audioOut = AC.createGain(); audioOut.gain.value = AUDIO.muted ? 0 : 0.9; audioOut.connect(AC.destination);
      const verb = AC.createConvolver();
      const vlen = Math.floor(AC.sampleRate * 1.8);
      const imp = AC.createBuffer(2, vlen, AC.sampleRate);
      for (let ch = 0; ch < 2; ch++) {
        const dd = imp.getChannelData(ch);
        for (let i = 0; i < vlen; i++) dd[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / vlen, 2.6);
      }
      verb.buffer = imp;
      const verbGain = AC.createGain(); verbGain.gain.value = 0.4;
      verb.connect(verbGain); verbGain.connect(audioOut);
      musicBus = AC.createGain(); musicBus.gain.value = 0.15; musicBus.connect(audioOut); musicBus.connect(verb);
      sfxBus = AC.createGain(); sfxBus.gain.value = 0.55; sfxBus.connect(audioOut);
      const sfxSend = AC.createGain(); sfxSend.gain.value = 0.12; sfxBus.connect(sfxSend); sfxSend.connect(verb);
      // Glowlands audio rides the host buses (Ch. 5.7); safe no-op until here.
      try { initGlowlandsAudio({ ctx: AC, sfxBus, musicBus, isMuted: () => AUDIO.muted }); } catch (e) {}
      // looping water babble for the fountain (gain driven by proximity)
      const fnBuf = AC.createBuffer(1, Math.floor(AC.sampleRate * 1.5), AC.sampleRate);
      const fnD = fnBuf.getChannelData(0);
      let fnLast = 0;
      for (let i = 0; i < fnD.length; i++) {
        const w = Math.random() * 2 - 1;
        fnLast = fnLast * 0.94 + w * 0.06;
        fnD[i] = fnLast * 2.6 + w * 0.22;
      }
      const fnSrc = AC.createBufferSource(); fnSrc.buffer = fnBuf; fnSrc.loop = true;
      const fnFilt = AC.createBiquadFilter(); fnFilt.type = "bandpass"; fnFilt.frequency.value = 1400; fnFilt.Q.value = 0.7;
      fountainGain = AC.createGain(); fountainGain.gain.value = 0;
      fnSrc.connect(fnFilt); fnFilt.connect(fountainGain); fountainGain.connect(sfxBus);
      fnSrc.start();
      // Eli's voice: decode all clips up front, route straight to the master
      voiceGain = AC.createGain();
      voiceGain.gain.value = 1.1;
      voiceGain.connect(audioOut);
      const b64ToBuf = (b64) => {
        const bin = atob(b64);
        const arr = new Uint8Array(bin.length);
        for (let bi = 0; bi < bin.length; bi++) arr[bi] = bin.charCodeAt(bi);
        return arr.buffer;
      };
      loadIntroVoices();
      // dragon ambience: snore loops behind a proximity gain (like the
      // fountain); the eating clip is decoded once and played on steals
      snoreGain = AC.createGain(); snoreGain.gain.value = 0;
      snoreGain.connect(audioOut);
      AC.decodeAudioData(b64ToBuf(SNORE_B64)).then((buf) => {
        const src = AC.createBufferSource(); src.buffer = buf; src.loop = true;
        src.connect(snoreGain); src.start();
      }).catch(() => {});
      AC.decodeAudioData(b64ToBuf(EAT_B64)).then((buf) => { eatBuf = buf; }).catch(() => {});
      playTrack(trackWanted || (typeof G !== "undefined" && G && G.map) || "HOME");
    }
    function tone(freq, t, dur, vol, type = "triangle", slideTo = null, lp = null) {
      if (!AC) return;
      const o = AC.createOscillator(); o.type = type;
      o.frequency.setValueAtTime(freq, t);
      if (slideTo) o.frequency.exponentialRampToValueAtTime(Math.max(20, slideTo), t + dur);
      const g = AC.createGain();
      g.gain.setValueAtTime(0.0001, t);
      g.gain.exponentialRampToValueAtTime(vol, t + 0.015);
      g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
      let last = o;
      if (lp) { const f = AC.createBiquadFilter(); f.type = "lowpass"; f.frequency.value = lp; o.connect(f); last = f; }
      last.connect(g); g.connect(sfxBus);
      o.start(t); o.stop(t + dur + 0.05);
    }
    function noiseBurst(t, dur, vol, freq = 800, qv = 1, ftype = "bandpass", freqEnd = null) {
      if (!AC) return;
      const b = AC.createBuffer(1, Math.max(1, Math.floor(AC.sampleRate * dur)), AC.sampleRate);
      const dd = b.getChannelData(0);
      for (let i = 0; i < dd.length; i++) dd[i] = Math.random() * 2 - 1;
      const src = AC.createBufferSource(); src.buffer = b;
      const f = AC.createBiquadFilter(); f.type = ftype; f.frequency.setValueAtTime(freq, t); f.Q.value = qv;
      if (freqEnd) f.frequency.exponentialRampToValueAtTime(freqEnd, t + dur);
      const g = AC.createGain(); g.gain.setValueAtTime(vol, t); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
      src.connect(f); f.connect(g); g.connect(sfxBus);
      src.start(t); src.stop(t + dur);
    }
    function stopVoiceClip() {
      if (voiceSrc) { try { voiceSrc.stop(); } catch (e) {} voiceSrc = null; }
      try { G.duckMusic(false); } catch (e) {}
      if (musicBus && voiceDuckOrig != null) {
        musicBus.gain.setTargetAtTime(voiceDuckOrig, AC ? AC.currentTime : 0, 0.3);
        voiceDuckOrig = null;
      }
    }
    // Old Eli's onboarding narration, fetched on first audio init. The
    // player is on the title splash while these land, and playVoiceClip
    // retries for ~4s, so page 1 is never silent in practice.
    let introVoicesRequested = false;
    function loadIntroVoices() {
      if (!AC || introVoicesRequested) return;
      introVoicesRequested = true;
      for (let i = 0; i < INTRO_PAGES.length; i++) {
        fetch(`voices/intro-${i + 1}.mp3?v=${VOICE_V}`)
          .then((r) => r.arrayBuffer())
          .then((ab) => AC.decodeAudioData(ab))
          .then((buf) => { voiceBufs[i] = buf; })
          .catch(() => {});
      }
    }

    // Church-garden intro narration lives as static mp3s in public/voices
    // (fetched on church entry) so it stays out of the initial bundle.
    let churchVoiceBufs = [], churchVoicesRequested = false;
    function loadChurchVoices() {
      if (!AC || churchVoicesRequested) return;
      churchVoicesRequested = true;
      for (let i = 0; i < 6; i++) {
        fetch(`voices/church-${i + 1}.mp3?v=${VOICE_V}`)
          .then((r) => r.arrayBuffer())
          .then((ab) => AC.decodeAudioData(ab))
          .then((buf) => { churchVoiceBufs[i] = buf; })
          .catch(() => {});
      }
    }
    // standalone Eli lines (no page index) — e.g. "I'll be ready when you are"
    const oneShotBufs = {};
    function playVoiceFile(url) {
      if (!AC) initAudio();
      if (!AC) return;
      const start = (buf) => {
        stopVoiceClip();
        try { G.duckMusic(true); } catch (e) {}
        if (musicBus && voiceDuckOrig == null) {
          voiceDuckOrig = musicBus.gain.value;
          musicBus.gain.setTargetAtTime(Math.min(voiceDuckOrig, 0.16), AC.currentTime, 0.08);
        }
        const src = AC.createBufferSource();
        src.buffer = buf;
        src.connect(voiceGain);
        src.onended = () => {
          if (voiceSrc === src) {
            voiceSrc = null;
            try { G.duckMusic(false); } catch (e) {}
            if (musicBus && voiceDuckOrig != null) {
              musicBus.gain.setTargetAtTime(voiceDuckOrig, AC.currentTime, 0.35);
              voiceDuckOrig = null;
            }
          }
        };
        voiceSrc = src;
        src.start();
      };
      if (oneShotBufs[url]) return start(oneShotBufs[url]);
      // Bounded cache. Decoded PCM runs ~10x the mp3, and Eli has nearly 40
      // lines — left uncapped a long session accumulates all of them. Object
      // key order is insertion order, so the first key is the oldest clip.
      const cached = Object.keys(oneShotBufs);
      if (cached.length >= 8) delete oneShotBufs[cached[0]];
      // versioned here rather than at the ~10 call sites, so a re-recorded
      // quip or quiz line can never be served from a stale browser cache
      fetch(`${url}?v=${VOICE_V}`).then((r) => r.arrayBuffer()).then((ab) => AC.decodeAudioData(ab))
        .then((buf) => { oneShotBufs[url] = buf; start(buf); })
        .catch(() => {});
    }

    // opts = { bufs, pageOf } routes home vs. church narration through one player
    function playVoiceClip(i, tries = 0, opts = null) {
      const bufs = opts?.bufs || voiceBufs;
      const pageOf = opts?.pageOf || (() => G.introPage);
      if (!AC) initAudio();
      if (!AC) return;
      if (pageOf() !== i) return;
      if (!bufs[i]) {
        if (tries < 16) setTimeout(() => playVoiceClip(i, tries + 1, opts), 250);
        return;
      }
      stopVoiceClip();
      try { G.duckMusic(true); } catch (e) {}
      if (musicBus && voiceDuckOrig == null) {
        voiceDuckOrig = musicBus.gain.value;
        musicBus.gain.setTargetAtTime(Math.min(voiceDuckOrig, 0.16), AC.currentTime, 0.08);
      }
      const src = AC.createBufferSource();
      src.buffer = bufs[i];
      src.connect(voiceGain);
      src.onended = () => {
        if (voiceSrc === src) {
          voiceSrc = null;
          try { G.duckMusic(false); } catch (e) {}
      if (musicBus && voiceDuckOrig != null) {
            musicBus.gain.setTargetAtTime(voiceDuckOrig, AC.currentTime, 0.35);
            voiceDuckOrig = null;
          }
        }
      };
      voiceSrc = src;
      src.start();
    }

    function stopTrack(fadeSec = 1.2) {
      if (!trackSrc) { trackKey = null; return; }
      const src = trackSrc, g = trackGain;
      trackSrc = null; trackGain = null; trackKey = null;
      try {
        g.gain.setTargetAtTime(0, AC.currentTime, fadeSec / 3);
        setTimeout(() => { try { src.stop(); } catch (e) {} }, fadeSec * 1000 + 200);
      } catch (e) { try { src.stop(); } catch (e2) {} }
    }

    function playTrack(key) {
      trackWanted = key;
      if (!AC) return; // initAudio retries with trackWanted
      if (trackKey === key) return;
      const url = MUSIC_TRACKS[key];
      if (!url) { stopTrack(); return; } // no track for this map = silence
      const startBuf = (buf) => {
        if (trackWanted !== key || !AC) return;
        stopTrack(0.8);
        const src = AC.createBufferSource();
        src.buffer = buf;
        src.loop = true;
        // skip codec padding at the seam so the loop stays tight
        src.loopStart = 0.03;
        src.loopEnd = Math.max(1, buf.duration - 0.06);
        const g = AC.createGain();
        g.gain.value = 0;
        g.gain.setTargetAtTime(musicDucked ? MUSIC_DUCKED : MUSIC_FULL, AC.currentTime + 0.05, 0.6);
        src.connect(g); g.connect(audioOut);
        src.start();
        trackSrc = src; trackGain = g; trackKey = key;
      };
      if (trackBufs[key]) { startBuf(trackBufs[key]); return; }
      fetch(url)
        .then((r) => r.arrayBuffer())
        .then((ab) => AC.decodeAudioData(ab))
        .then((buf) => { trackBufs[key] = buf; startBuf(buf); })
        .catch(() => {}); // failed load = silence, never an error
    }

    const sq = (fn) => { if (AC && !AUDIO.muted) fn(AC.currentTime + 0.01); };
    const SFX = {
      step: () => sq((t) => { noiseBurst(t, 0.07, 0.15, 450 + Math.random() * 300, 1.4); tone(85 + Math.random() * 30, t, 0.05, 0.05, "sine"); }),
      plant: () => sq((t) => { noiseBurst(t, 0.14, 0.2, 300, 0.8, "lowpass"); tone(480, t + 0.04, 0.14, 0.14, "triangle", 700); }),
      harvest: () => sq((t) => { tone(620, t, 0.09, 0.16, "triangle", 900); tone(930, t + 0.08, 0.12, 0.16, "triangle", 1240); noiseBurst(t, 0.05, 0.1, 2000, 2, "highpass"); }),
      coin: (n = 1) => sq((t) => { for (let i = 0; i < n; i++) { tone(1318.5, t + i * 0.08, 0.1, 0.12, "sine"); tone(1975.5, t + i * 0.08 + 0.03, 0.12, 0.08, "sine"); } }),
      feed: () => sq((t) => { noiseBurst(t, 0.1, 0.3, 220, 0.8, "lowpass"); noiseBurst(t + 0.12, 0.1, 0.26, 190, 0.8, "lowpass"); tone(150, t, 0.16, 0.14, "square", 85); }),
      roar: () => sq((t) => { tone(210, t, 0.75, 0.32, "sawtooth", 62); noiseBurst(t, 0.6, 0.24, 380, 0.7, "lowpass", 120); }),
      correct: () => sq((t) => { tone(880, t, 0.12, 0.16, "sine"); tone(1108.7, t + 0.09, 0.16, 0.16, "sine"); }),
      wrong: () => sq((t) => { tone(185, t, 0.28, 0.18, "square", 130); }),
      pass: () => sq((t) => { [659.25, 784, 1046.5].forEach((f, i) => tone(f, t + i * 0.1, 0.24, 0.16, "triangle")); }),
      fail: () => sq((t) => { tone(300, t, 0.3, 0.16, "sawtooth", 200, 900); tone(220, t + 0.26, 0.42, 0.16, "sawtooth", 140, 800); }),
      sparkle: () => sq((t) => { tone(1568, t, 0.28, 0.1, "sine", 2349); tone(2093, t + 0.06, 0.24, 0.07, "sine", 2637); }),
      level: () => sq((t) => { [523.25, 659.25, 784, 1046.5].forEach((f, i) => tone(f, t + i * 0.09, 0.26, 0.15, "triangle")); }),
      whoosh: () => sq((t) => { noiseBurst(t, 0.4, 0.16, 300, 0.8, "bandpass", 2400); }),
      sleep: () => sq((t) => { tone(392, t, 0.5, 0.08, "sine", 262); }),
      wake: () => sq((t) => { tone(262, t, 0.4, 0.1, "sine", 440); }),
      click: () => sq((t) => { tone(1150, t, 0.04, 0.08, "square"); }),
      itemGet: () => sq((t) => {
        [523.25, 659.25, 784, 1046.5].forEach((f, i) => tone(f, t + i * 0.07, 0.2, 0.15, "triangle"));
        tone(1568, t + 0.3, 0.5, 0.11, "sine", 2093);
        tone(2093, t + 0.38, 0.4, 0.07, "sine");
      }),
    };
    const unlockAudio = () => { initAudio(); if (AC && AC.state === "suspended") AC.resume(); ensureAudioKeeper(); };
    window.addEventListener("pointerdown", unlockAudio);
    window.addEventListener("pointerup", unlockAudio); // iOS user-activation for media .play() is strictest here
    window.addEventListener("keydown", unlockAudio);

    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(46, W() / H(), 0.1, 400);

    // ---- Lights: gold sun / cool blue sky fill — the warm-lit / cool-shadow split ----
    const hemi = new THREE.HemisphereLight(PAL.ambientSky, PAL.ambientGnd, 0.66); // lifted so shade reads blue-green, not a dark hole
    hemi.color.convertSRGBToLinear(); hemi.groundColor.convertSRGBToLinear();
    scene.add(hemi);
    const sun = new THREE.DirectionalLight(PAL.sun, 1.45);
    sun.color.convertSRGBToLinear();
    sun.position.set(16, 17, 9); // slightly lower sun = longer golden-hour shadows
    sun.castShadow = true;
    sun.shadow.mapSize.set(2048, 2048);
    sun.shadow.camera.left = -42; sun.shadow.camera.right = 42;
    sun.shadow.camera.top = 42; sun.shadow.camera.bottom = -42;
    sun.shadow.bias = -0.0004;
    sun.shadow.normalBias = 0.025;
    scene.add(sun);
    scene.add(sun.target);
    const fill = new THREE.DirectionalLight(0x9ab8d8, 0.2); // cool counter-fill: pushes shadow facets toward blue
    fill.color.convertSRGBToLinear();
    fill.position.set(-14, 14, -8);
    scene.add(fill);
    // character rim light — layer 2 is the "character layer". Only player
    // rigs opt into it (makePlayer enables layer 2 on its meshes), so this
    // cool back light separates characters from the terrain — dark outfits
    // stop reading as blobs from behind — without re-lighting the world.
    const charRim = new THREE.DirectionalLight(0x9fc4ff, 0.5);
    charRim.color.convertSRGBToLinear();
    charRim.position.set(-7, 10, -12);
    charRim.layers.set(2);
    scene.add(charRim);
    camera.layers.enable(2); // camera must see layer 2 or the light is culled

    // ---- Gradient sky dome ----
    const skyMat = new THREE.ShaderMaterial({
      side: THREE.BackSide, depthWrite: false,
      uniforms: {
        cTop: { value: new THREE.Color(PAL.skyTop) },
        cMid: { value: new THREE.Color(PAL.skyMid) },
        cBot: { value: new THREE.Color(PAL.skyHorizon) },
      },
      vertexShader: `varying vec3 vP; void main(){ vP = position; gl_Position = projectionMatrix*modelViewMatrix*vec4(position,1.0); }`,
      fragmentShader: `varying vec3 vP; uniform vec3 cTop; uniform vec3 cMid; uniform vec3 cBot;
        void main(){
          float h = normalize(vP).y;
          vec3 col = h > 0.0 ? mix(cMid, cTop, pow(h, 0.55)) : mix(cMid, cBot, pow(-h, 0.8));
          gl_FragColor = vec4(col, 1.0);
        }`,
    });
    const sky = new THREE.Mesh(new THREE.SphereGeometry(160, 20, 12), skyMat);
    sky.renderOrder = -1;
    scene.add(sky);

    // Day fog tuned tighter than the brief's 45/112: with the follow-cam ~10u behind
    // the player, frame-top geometry sits at 35-55u, so the melt must start by ~30u
    // and land ~50% cream by 55u for aerial perspective to read on this small map.
    // Linear fog, PAL.fog cream — never gray. hemiI is per-preset so lifting day
    // shade doesn't wash out night.
    const setAtmosphere = (top, mid, bot, fogC, sunC, sunI, hemiSky, hemiGnd, fogNear = 30, fogFar = 76, hemiI = 0.66) => {
      skyMat.uniforms.cTop.value.set(top).convertSRGBToLinear();
      skyMat.uniforms.cMid.value.set(mid).convertSRGBToLinear();
      skyMat.uniforms.cBot.value.set(bot).convertSRGBToLinear();
      scene.fog = new THREE.Fog(new THREE.Color(fogC).convertSRGBToLinear(), fogNear, fogFar);
      sun.color.set(sunC).convertSRGBToLinear(); sun.intensity = sunI;
      hemi.color.set(hemiSky).convertSRGBToLinear();
      hemi.groundColor.set(hemiGnd).convertSRGBToLinear();
      hemi.intensity = hemiI;
    };

    // ================= HELPERS =================
    // Flat-shaded standard material — the low-poly signature
    // decode authored sRGB hex colors to linear — restores true color separation
    const SRGB = (hex) => new THREE.Color(hex).convertSRGBToLinear();
    const asLinear = (c) => (c && c.isColor ? c.clone().convertSRGBToLinear() : SRGB(c));
    const mkMat = (color, base, opts) => {
      const m = new THREE.MeshStandardMaterial({ ...base, ...opts });
      m.color.copy(asLinear(color));
      if (opts && opts.emissive !== undefined) m.emissive.copy(asLinear(opts.emissive));
      return m;
    };
    const flat = (color, opts = {}) => mkMat(color, { roughness: 0.9, metalness: 0.02, flatShading: true }, opts);
    const smooth = (color, opts = {}) => mkMat(color, { roughness: 0.85, metalness: 0.02 }, opts);

    // ---- wind: vertex-shader sway for instanced foliage ----
    const windT = { value: 0 };
    function addWind(material, amp, hDiv) {
      // GLSL needs float literals ("0.0000", never "0") and each variant its own program
      const ampF = amp.toFixed(4), amp2F = (amp * 0.6).toFixed(4), hDivF = hDiv.toFixed(3);
      material.customProgramCacheKey = () => `wind_${ampF}_${hDivF}`;
      material.onBeforeCompile = (sh) => {
        sh.uniforms.uWindT = windT;
        sh.vertexShader = sh.vertexShader
          .replace("#include <common>", "#include <common>\nuniform float uWindT;\nvarying vec2 vWpz;")
          .replace("#include <begin_vertex>", `#include <begin_vertex>
            #ifdef USE_INSTANCING
              vec2 wpz = vec2(instanceMatrix[3].x, instanceMatrix[3].z);
            #else
              vec2 wpz = vec2(0.0);
            #endif
            vWpz = wpz;
            float hf = clamp(position.y / ${hDivF}, 0.0, 1.0);
            float swy = sin(uWindT * 2.0 + wpz.x * 0.35 + wpz.y * 0.27) + 0.5 * sin(uWindT * 3.7 + wpz.x * 0.8);
            transformed.x += swy * ${ampF} * hf;
            transformed.z += cos(uWindT * 1.6 + wpz.y * 0.4) * ${amp2F} * hf;`);
        sh.fragmentShader = sh.fragmentShader
          .replace("#include <common>", "#include <common>\nuniform float uWindT;\nvarying vec2 vWpz;")
          .replace("#include <aomap_fragment>", `#include <aomap_fragment>
            {
              float cw_ = sin(vWpz.x * 0.045 + uWindT * 0.5) + sin(vWpz.y * 0.05 - uWindT * 0.35) + sin((vWpz.x + vWpz.y) * 0.03 + uWindT * 0.22);
              float cs_ = smoothstep(1.15, 2.3, cw_);
              float cf_ = 1.0 - cs_ * 0.26;
              reflectedLight.directDiffuse *= cf_;
              reflectedLight.indirectDiffuse *= cf_;
            }`);
      };
    }

    // soft drifting cloud shade for non-instanced surfaces (the terrain)
    function addCloudShade(material) {
      material.customProgramCacheKey = () => "cloudshade_v1";
      material.onBeforeCompile = (sh) => {
        sh.uniforms.uWindT = windT;
        sh.vertexShader = sh.vertexShader
          .replace("#include <common>", "#include <common>\nvarying vec2 vCw;")
          .replace("#include <begin_vertex>", "#include <begin_vertex>\n  vCw = (modelMatrix * vec4(transformed, 1.0)).xz;");
        sh.fragmentShader = sh.fragmentShader
          .replace("#include <common>", "#include <common>\nuniform float uWindT;\nvarying vec2 vCw;")
          .replace("#include <aomap_fragment>", `#include <aomap_fragment>
            {
              float cw_ = sin(vCw.x * 0.045 + uWindT * 0.5) + sin(vCw.y * 0.05 - uWindT * 0.35) + sin((vCw.x + vCw.y) * 0.03 + uWindT * 0.22);
              float cs_ = smoothstep(1.15, 2.3, cw_);
              float cf_ = 1.0 - cs_ * 0.26;
              reflectedLight.directDiffuse *= cf_;
              reflectedLight.indirectDiffuse *= cf_;
            }`);
      };
    }

    // ---- Collision system ----
    let colliders = [];
    const addCircleCol = (x, z, r) => colliders.push({ type: "c", x, z, r });
    const addBoxCol = (x, z, hw, hd, rot = 0) => colliders.push({ type: "b", x, z, hw, hd, rot });

    // ---- art-directed terrain: gaussian hills, masked flat around gameplay zones ----
    let terrainY = () => 0;
    const RIVER_X = (z) => -14 + Math.sin(z * 0.18) * 1.6;
    const SAND = new THREE.Color(PAL.pathStone).offsetHSL(0.018, -0.05, -0.12).convertSRGBToLinear();
    const BANK_SHADE = new THREE.Color(PAL.grassShade).convertSRGBToLinear();
    const BANK_WET = new THREE.Color(PAL.soil).offsetHSL(0, -0.04, -0.07).convertSRGBToLinear();
    const MORTAR = new THREE.Color(PAL.stone).offsetHSL(0.012, 0, -0.075).convertSRGBToLinear();
    function makeTerrain(hills, flats) {
      return (x, z) => {
        let h = 0;
        for (const b of hills) {
          const d2 = ((x - b.x) * (x - b.x) + (z - b.z) * (z - b.z)) / (b.r * b.r);
          h += b.h * Math.exp(-d2 * 2.2);
        }
        let flat = 1;
        for (const zn of flats) {
          let d;
          if (zn.c) d = Math.hypot(x - zn.x, z - zn.z) - zn.r;
          else {
            const dx = Math.max(zn.x1 - x, 0, x - zn.x2);
            const dz = Math.max(zn.z1 - z, 0, z - zn.z2);
            d = Math.hypot(dx, dz);
          }
          const t = Math.min(1, Math.max(0, d / zn.f));
          flat = Math.min(flat, t * t * (3 - 2 * t));
        }
        return h * flat;
      };
    }

    function pushOutOfCircle(pos, cx, cz, cr) {
      const dx = pos.x - cx, dz = pos.z - cz;
      const d = Math.hypot(dx, dz), min = cr + PLAYER_R;
      if (d < min && d > 0.0001) {
        pos.x = cx + (dx / d) * min;
        pos.z = cz + (dz / d) * min;
      }
    }
    function resolveCollisions(pos, dragonObj, dragonSolid) {
      for (let pass = 0; pass < 2; pass++) {
        for (const c of colliders) {
          if (c.type === "c") pushOutOfCircle(pos, c.x, c.z, c.r);
          else {
            const cos = Math.cos(c.rot), sin = Math.sin(c.rot);
            const dx = pos.x - c.x, dz = pos.z - c.z;
            let lx = dx * cos - dz * sin;
            let lz = dx * sin + dz * cos;
            const nx = Math.max(-c.hw, Math.min(c.hw, lx));
            const nz = Math.max(-c.hd, Math.min(c.hd, lz));
            let px = lx - nx, pz = lz - nz;
            const d = Math.hypot(px, pz);
            if (d < PLAYER_R) {
              if (d > 0.0001) {
                lx = nx + (px / d) * PLAYER_R;
                lz = nz + (pz / d) * PLAYER_R;
              } else {
                const ox = c.hw + PLAYER_R - Math.abs(lx);
                const oz = c.hd + PLAYER_R - Math.abs(lz);
                if (ox < oz) lx = (lx < 0 ? -1 : 1) * (c.hw + PLAYER_R);
                else lz = (lz < 0 ? -1 : 1) * (c.hd + PLAYER_R);
              }
              pos.x = c.x + lx * cos + lz * sin;
              pos.z = c.z - lx * sin + lz * cos;
            }
          }
        }
        if (dragonSolid && dragonObj) pushOutOfCircle(pos, dragonObj.position.x, dragonObj.position.z, 1.55);
      }
    }

    // ---- Trees: multi-tier pines + faceted oaks ----
    // Canopies pick from the PAL leaf ramp (lime/mid/deep + rare warm autumn accent).
    // leafC = per-mesh jittered sRGB color derived from a PAL token (flat() converts to linear).
    // Jitter widened to ~±8° hue so neighboring blobs never share one flat green.
    const leafC = (tok, dl = 0.05) =>
      new THREE.Color(tok).offsetHSL((Math.random() - 0.5) * 0.045, (Math.random() - 0.5) * 0.05, (Math.random() - 0.5) * dl);
    // Authored species shifts — olive workhorse / yellow-green / blue-green(teal), ~60/25/15.
    // ONE shift per tree (all its canopy meshes share it) so a stand reads as mixed species,
    // not one asset stamped — A Short Hike's mustard-next-to-teal forest trick.
    const speciesShift = () => {
      const r = Math.random();
      return r < 0.6
        ? { h: -0.008 + Math.random() * 0.016, s: -0.045, l: 0 } // olive (subtle drift)
        : r < 0.85
          ? { h: -0.034 - Math.random() * 0.018, s: 0.015, l: 0.02 } // yellow-green
          : { h: 0.028 + Math.random() * 0.02, s: -0.035, l: -0.03 }; // blue-green / teal
    };
    const spC = (tok, sp, dl = 0.04) => leafC(tok, dl).offsetHSL(sp.h, sp.s, sp.l);
    const warmCanopy = () => Math.random() < 0.12; // ~1-in-8 trees go ochre/autumn
    const barkC = () => new THREE.Color(PAL.bark).offsetHSL(0, 0, 0.035); // lifted so shadow side never goes black
    // ---- canopy shade patches: one instanced flattened dome of cool moist grass under
    // every tree so trunks grow OUT of the meadow instead of floating on it (critic:
    // "darkened soft patch under every tree canopy"). One draw call per map.
    // Resources built ONCE and reused by every map. disposeWorld() frees
    // everything else hanging off worldGroup, so anything shared has to be
    // registered here or the next map comes up with holes in it.
    const SHARED_GPU = new Set();
    const shareGpu = (r) => { SHARED_GPU.add(r); return r; };

    const shadeGeo = new THREE.IcosahedronGeometry(1, 0); shareGpu(shadeGeo);
    const SHADE_MAX = 110;
    let shadeInst = null, shadeCount = 0, shadeCol = null;
    function addCanopyShade(x, z, r) {
      if (!shadeInst || shadeInst.parent !== worldGroup) {
        shadeInst = new THREE.InstancedMesh(shadeGeo, flat(0xffffff, { roughness: 1 }), SHADE_MAX);
        shadeInst.receiveShadow = true;
        shadeInst.frustumCulled = false;
        // pre-size the color buffer BEFORE dropping count, else setColorAt allocates
        // a zero-length buffer (count is live at allocation time) and instances go black
        shadeInst.instanceColor = new THREE.InstancedBufferAttribute(new Float32Array(SHADE_MAX * 3), 3);
        shadeInst.count = 0; shadeCount = 0;
        shadeCol = new THREE.Color();
        worldGroup.add(shadeInst);
      }
      if (shadeCount >= SHADE_MAX) return;
      instDummy.position.set(x + (Math.random() - 0.5) * 0.2, terrainY(x, z) + 0.015, z + (Math.random() - 0.5) * 0.2);
      instDummy.rotation.set(0, Math.random() * Math.PI, 0);
      instDummy.scale.set(r * (0.9 + Math.random() * 0.3), 0.055, r * (0.75 + Math.random() * 0.35));
      instDummy.updateMatrix();
      shadeInst.setMatrixAt(shadeCount, instDummy.matrix);
      // cool moist grass a step below ground value — reads as shade+leaf-litter, not a hole
      shadeCol.copy(SRGB(PAL.grassShade)).lerp(SRGB(PAL.leafDeep), 0.22)
        .offsetHSL((Math.random() - 0.5) * 0.015, -0.06, 0.02 + (Math.random() - 0.5) * 0.03);
      shadeInst.setColorAt(shadeCount, shadeCol);
      shadeCount++; shadeInst.count = shadeCount;
      shadeInst.instanceMatrix.needsUpdate = true;
      if (shadeInst.instanceColor) shadeInst.instanceColor.needsUpdate = true;
    }
    // ---- one transformed, uniformly-tinted lump destined for a mergeGeoms canopy.
    // Whole canopies become ONE vertex-colored mesh, so richer silhouettes cost
    // FEWER draw calls than the old per-blob meshes. col must already be linear.
    const canopyVCMat = flat(0xffffff, { vertexColors: true }); shareGpu(canopyVCMat);
    const lumpE = new THREE.Euler(), lumpM = new THREE.Matrix4();
    function lumpG(geo, sx, sy, sz, rx, ry, rz, px, py, pz, col) {
      geo.scale(sx, sy, sz);
      lumpE.set(rx, ry, rz);
      lumpM.makeRotationFromEuler(lumpE).setPosition(px, py, pz);
      geo.applyMatrix4(lumpM);
      const n = geo.attributes.position.count, arr = new Float32Array(n * 3);
      for (let i = 0; i < n; i++) { arr[i * 3] = col.r; arr[i * 3 + 1] = col.g; arr[i * 3 + 2] = col.b; }
      geo.setAttribute("color", new THREE.BufferAttribute(arr, 3));
      return geo;
    }
    function makePine(x, z, s = 1) {
      const g = new THREE.Group();
      const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.13 * s, 0.24 * s, 1.3 * s, 5), flat(barkC()));
      trunk.position.y = 0.6 * s; trunk.castShadow = true;
      // one species tint per tree; crown shifts WARM (toward yellow-green) instead of
      // brighter — keeps a strict two-step ramp, no near-white lit facets
      const sp = speciesShift();
      // EVERY pine sits somewhere on the leafDeep->leafMid band (0.1-0.45), and ~30%
      // jump well into the mid/olive range — so a stand always mixes dark-teal,
      // olive and sage conifers instead of repeating one bottle green
      const mixMid = 0.1 + Math.random() * 0.35 + (Math.random() < 0.3 ? 0.3 : 0);
      // proportion variants: squat-wide / standard / tall-narrow silhouettes
      const pr = Math.random();
      const wid = pr < 0.3 ? 1.14 : pr < 0.75 ? 1.0 : 0.86;
      const hgt = pr < 0.3 ? 0.88 : pr < 0.75 ? 1.0 : 1.18;
      const tiers = [
        [1.18, 1.3, 1.15, 0.006, -0.022],
        [0.86, 1.15, 1.95, -0.018, 0.03],
        [0.52, 1.0, 2.7, -0.04, 0.062],
      ];
      const parts = tiers.map(([r, h, y, wh, dl], i) =>
        lumpG(new THREE.ConeGeometry(r * s * wid, h * s * hgt, 6), 1, 1, 1,
          0, i * 0.5 + (Math.random() - 0.5) * 0.35, 0, 0, y * s * hgt, 0,
          new THREE.Color(PAL.leafDeep).lerp(new THREE.Color(PAL.leafMid), Math.min(0.75, mixMid))
            .offsetHSL(sp.h + wh + (Math.random() - 0.5) * 0.02, sp.s + 0.02, sp.l + dl + (Math.random() - 0.5) * 0.015)
            .convertSRGBToLinear()));
      const canopy = new THREE.Mesh(mergeGeoms(parts), canopyVCMat);
      canopy.castShadow = true;
      g.add(canopy, trunk);
      g.position.set(x, terrainY(x, z), z);
      g.rotation.y = Math.random() * Math.PI;
      addCircleCol(x, z, 0.5 * s);
      addCanopyShade(x, z, 1.15 * s);
      swayers.push({ g, ph: Math.random() * 9, amp: 1 });
      return g;
    }
    function makeOak(x, z, s = 1) {
      const g = new THREE.Group();
      // tapered trunk + 1-2 branch stubs that visibly enter the canopy
      const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.13 * s, 0.34 * s, 1.7 * s, 6), flat(barkC()));
      trunk.position.y = 0.82 * s; trunk.castShadow = true;
      g.add(trunk);
      const barkMat = flat(barkC());
      const nb = 1 + (Math.random() < 0.55 ? 1 : 0);
      for (let i = 0; i < nb; i++) {
        const a = Math.random() * Math.PI * 2, lean = 0.62 + Math.random() * 0.25;
        const br = new THREE.Mesh(new THREE.CylinderGeometry(0.045 * s, 0.085 * s, 1.05 * s, 5), barkMat);
        br.position.set(Math.cos(a) * 0.42 * s, (1.5 + Math.random() * 0.3) * s, Math.sin(a) * 0.42 * s);
        br.rotation.set(Math.sin(a) * lean, 0, -Math.cos(a) * lean);
        br.castShadow = true;
        g.add(br);
      }
      // 5-7 irregular lumps with the mass pushed off-axis + a wide flat deep-teal
      // underside skirt 25% darker — draped foliage with shadow beneath, not balloons.
      // All lumps merge into ONE vertex-colored mesh (fewer draw calls than before).
      const warm = warmCanopy();
      const sp = speciesShift();
      const tokLow = warm ? PAL.leafWarm : PAL.leafDeep;
      const tokMid = warm ? PAL.leafWarm : PAL.leafMid;
      const tokTop = warm ? PAL.leafWarm : PAL.leafLime;
      const cx = (Math.random() - 0.5) * 0.55, cz = (Math.random() - 0.5) * 0.55;
      const parts = [];
      // underside skirt: teal-leaning cool shade — lifted so the shadow side reads
      // blue-green, never a near-black hole
      parts.push(lumpG(new THREE.IcosahedronGeometry(1.08 * s, 1.08 * s >= 1.0 ? 1 : 0), 1, 0.5, 1,
        Math.random() * Math.PI, Math.random() * Math.PI, Math.random() * Math.PI,
        cx * s, 1.8 * s, cz * s,
        spC(tokLow, sp, 0.02).offsetHSL(0.024, -0.06, -0.04).convertSRGBToLinear()));
      const n = 4 + Math.floor(Math.random() * 3);
      // one designated sun-kissed lobe per canopy (warm-lit vs cool-shade lobe read)
      const sunLobe = 1 + Math.floor(Math.random() * n);
      for (let i = 0; i < n; i++) {
        const a = (i / n) * Math.PI * 2 + Math.random() * 1.5;
        const hi = i / Math.max(1, n - 1);
        const rad = (i === 0 ? 0.12 : 0.4 + Math.random() * 0.5) * (1 - hi * 0.45) * s;
        const r = Math.max(0.34 * s, (0.9 - hi * 0.3) * (0.82 + Math.random() * 0.34) * s);
        const tok = hi < 0.34 ? tokLow : hi < 0.72 ? tokMid : tokTop;
        let lc = spC(tok, sp).offsetHSL(0, 0, hi * 0.02 + (Math.random() - 0.5) * 0.025);
        // top lime lumps pull back toward the workhorse mid-green so big canopies
        // never wash out into pale plastic lime
        if (tok === tokTop && !warm) lc = lc.lerp(new THREE.Color(PAL.leafMid), 0.3);
        if (i + 1 === sunLobe && !warm) lc = lc.offsetHSL(-0.014, 0.02, 0.032); // warm-lit lobe
        // big lobes get one subdivision — more facets = richer flat-shaded value
        // steps on large canopies instead of giant paper planes
        parts.push(lumpG(new THREE.IcosahedronGeometry(r, r >= 1.0 ? 1 : 0), 1, 0.6 + Math.random() * 0.2, 1,
          Math.random() * Math.PI, Math.random() * Math.PI, Math.random() * Math.PI,
          cx * s + Math.cos(a) * rad, (2.05 + hi * 0.85 + (Math.random() - 0.5) * 0.2) * s, cz * s + Math.sin(a) * rad,
          lc.convertSRGBToLinear()));
      }
      const canopy = new THREE.Mesh(mergeGeoms(parts), canopyVCMat);
      canopy.castShadow = true;
      g.add(canopy);
      g.position.set(x, terrainY(x, z), z);
      addCircleCol(x, z, 0.55 * s);
      addCanopyShade(x, z, 1.3 * s);
      swayers.push({ g, ph: Math.random() * 9, amp: 1 });
      return g;
    }
    const makeTree = (x, z, s = 1) => (Math.random() < 0.55 ? makePine(x, z, s) : makeOak(x, z, s));
    function makeCypress(x, z, s = 1) {
      const g = new THREE.Group();
      const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.1 * s, 0.16 * s, 0.7 * s, 5), flat(barkC()));
      trunk.position.y = 0.35 * s; trunk.castShadow = true;
      const sp = speciesShift();
      const c1 = new THREE.Mesh(new THREE.ConeGeometry(0.55 * s, 2.6 * s, 6), flat(spC(PAL.leafDeep, sp, 0.03)));
      c1.position.y = 1.9 * s; c1.castShadow = true;
      const c2 = new THREE.Mesh(new THREE.ConeGeometry(0.3 * s, 1.2 * s, 6), flat(spC(PAL.leafDeep, sp, 0.03).offsetHSL(-0.024, 0.02, 0.04)));
      c2.position.y = 3.1 * s; c2.castShadow = true;
      c2.rotation.y = 0.5;
      g.add(trunk, c1, c2);
      g.position.set(x, terrainY(x, z), z);
      addCircleCol(x, z, 0.42 * s);
      addCanopyShade(x, z, 0.85 * s);
      swayers.push({ g, ph: Math.random() * 9, amp: 0.6 });
      return g;
    }
    const CHERRY_PINKS = [0xe8a0c8, 0xf0b8d8, 0xdd8fbc];
    function makeCherry(x, z, s = 1) {
      const g = new THREE.Group();
      const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.16 * s, 0.26 * s, 1.3 * s, 6), flat(barkC()));
      trunk.position.y = 0.65 * s; trunk.castShadow = true;
      const c1 = new THREE.Mesh(new THREE.IcosahedronGeometry(1.0 * s, 0), flat(CHERRY_PINKS[Math.floor(Math.random() * 3)]));
      c1.position.y = 1.9 * s; c1.castShadow = true; c1.scale.y = 0.84;
      c1.rotation.set(Math.random(), Math.random(), Math.random());
      const c2 = new THREE.Mesh(new THREE.IcosahedronGeometry(0.62 * s, 0), flat(CHERRY_PINKS[Math.floor(Math.random() * 3)]));
      c2.position.set(0.5 * s, 2.35 * s, 0.2 * s); c2.castShadow = true; c2.scale.y = 0.84;
      c2.rotation.set(Math.random(), Math.random(), Math.random());
      g.add(trunk, c1, c2);
      g.position.set(x, terrainY(x, z), z);
      addCircleCol(x, z, 0.5 * s);
      addCanopyShade(x, z, 1.1 * s);
      swayers.push({ g, ph: Math.random() * 9, amp: 1.25 });
      return g;
    }

    // ---- Faceted rocks (warm pale granite, moss-capped) ----
    const instDummy = new THREE.Object3D();
    const mossGeo = new THREE.IcosahedronGeometry(1, 0); shareGpu(mossGeo);
    const mossMat = flat(PAL.leafDeep, { roughness: 1 }); shareGpu(mossMat);
    const MOSS_MAX = 48;
    let mossInst = null, mossCount = 0;
    function addMossCap(x, y, z, s) {
      // one InstancedMesh of flattened moss domes per map (recreated after clearWorld)
      if (!mossInst || mossInst.parent !== worldGroup) {
        mossInst = new THREE.InstancedMesh(mossGeo, mossMat, MOSS_MAX);
        mossInst.castShadow = true; mossInst.receiveShadow = true;
        mossInst.frustumCulled = false;
        mossInst.count = 0; mossCount = 0;
        worldGroup.add(mossInst);
      }
      if (mossCount >= MOSS_MAX) return;
      instDummy.position.set(x + (Math.random() - 0.5) * 0.08 * s, y, z + (Math.random() - 0.5) * 0.08 * s);
      instDummy.rotation.set((Math.random() - 0.5) * 0.3, Math.random() * Math.PI, (Math.random() - 0.5) * 0.3);
      instDummy.scale.set(0.46 * s, 0.16 * s, 0.46 * s);
      instDummy.updateMatrix();
      mossInst.setMatrixAt(mossCount, instDummy.matrix);
      mossCount++; mossInst.count = mossCount;
      mossInst.instanceMatrix.needsUpdate = true;
    }
    // baked two-tone facet split (Lonely Mountains): sun-facing facets warm-lit,
    // grazing facets keep the base khaki, away facets cool toward the sky ambient
    const ROCK_SUN = new THREE.Vector3(16, 17, 9).normalize();
    function bakeRockFacets(geo, dark, rotE) {
      const g = geo.index ? geo.toNonIndexed() : geo;
      const pos = g.attributes.position;
      // warm grey-tan, sat BELOW the flower highlights in value (no popcorn-white pebbles)
      const base = new THREE.Color(PAL.stone).offsetHSL(0.02, dark ? 0.02 : 0.045, dark ? -0.12 : -0.045)
        .offsetHSL(0, 0, (Math.random() - 0.5) * 0.05).convertSRGBToLinear();
      const lit = base.clone().offsetHSL(0.012, 0.03, 0.055);
      const cool = base.clone().lerp(SRGB(PAL.ambientSky), 0.3).offsetHSL(0, 0, -0.055);
      const cols = new Float32Array(pos.count * 3);
      const va = new THREE.Vector3(), vb = new THREE.Vector3(), vc = new THREE.Vector3(), vn = new THREE.Vector3();
      for (let i = 0; i < pos.count; i += 3) {
        va.fromBufferAttribute(pos, i); vb.fromBufferAttribute(pos, i + 1); vc.fromBufferAttribute(pos, i + 2);
        vb.sub(va); vc.sub(va); vn.crossVectors(vb, vc).normalize();
        if (rotE) vn.applyEuler(rotE);
        const d = vn.dot(ROCK_SUN);
        const fc = d > 0.3 ? lit : d > -0.1 ? base : cool;
        for (let k = 0; k < 3; k++) { cols[(i + k) * 3] = fc.r; cols[(i + k) * 3 + 1] = fc.g; cols[(i + k) * 3 + 2] = fc.b; }
      }
      g.setAttribute("color", new THREE.BufferAttribute(cols, 3));
      return g;
    }
    function makeRock(x, z, s = 1, dark = false, opts = {}) {
      const rotE = new THREE.Euler(Math.random() * 3, Math.random() * 3, Math.random() * 3);
      const geo = bakeRockFacets(new THREE.IcosahedronGeometry(0.55 * s, 0), dark, rotE);
      const sy = 0.75 + Math.random() * 0.4;
      // opts.sink: half-buried boulder — crown barely proud of the meadow, grass skirt hugs it
      const ry = opts.y != null ? opts.y : (opts.sink ? 0.04 : 0.21) * s + terrainY(x, z);
      if (opts.wet) {
        // wet band: darken + cool everything near/below the waterline (-0.16) so in-stream
        // stones read soaked at the base instead of dry pebbles floating on blue
        const posA = geo.attributes.position, colA = geo.attributes.color;
        const wetC = new THREE.Color(PAL.stone).offsetHSL(0.01, 0.02, -0.21).convertSRGBToLinear().lerp(SRGB(PAL.waterDeep), 0.22);
        const wv = new THREE.Vector3(), cv = new THREE.Color();
        for (let vi = 0; vi < posA.count; vi++) {
          wv.fromBufferAttribute(posA, vi).applyEuler(rotE);
          const wy = ry + wv.y * sy;
          const t = Math.max(0, Math.min(1, (0.0 - wy) / 0.14)); // dry above ~0, fully wet below waterline
          if (t > 0) {
            cv.fromBufferAttribute(colA, vi).lerp(wetC, t * 0.85);
            colA.setXYZ(vi, cv.r, cv.g, cv.b);
          }
        }
      }
      const r = new THREE.Mesh(geo, flat(0xffffff, { vertexColors: true }));
      // sunk ~25% into the meadow so the boulder sits IN the land (or explicit y for in-stream stones)
      r.position.set(x, ry, z);
      r.rotation.copy(rotE);
      r.scale.set(1, sy, 1);
      r.castShadow = true; r.receiveShadow = true;
      if (!opts.noCol) addCircleCol(x, z, 0.52 * s);
      if (s >= 0.5 && !opts.noMoss) addMossCap(x, r.position.y + (opts.sink ? 0.42 : 0.3) * s, z, s * 0.82); // top-cap accent only
      if (!opts.noCol) rockBases.push([x, z, s]); // addGrass spawns hugging tufts here
      return r;
    }

    // ---- Petaled flowers ----
    // blossom colorways derived from PAL — warm white / blush / gold (golden-hour meadow set)
    const BLOOM_WHITE = new THREE.Color(PAL.plaster).offsetHSL(0.03, -0.27, 0.06);
    const BLOOM_BLUSH = new THREE.Color(PAL.roof).offsetHSL(-0.083, 0.16, 0.28);
    const BLOOM_GOLD = new THREE.Color(PAL.sun).offsetHSL(0.014, -0.2, -0.18);
    // saturated poppy-red accent species (Short Hike red foliage accents) — headliner, used sparingly
    const BLOOM_RED = new THREE.Color(PAL.roof).offsetHSL(-0.015, 0.3, -0.02);
    const PETALS = [BLOOM_WHITE, BLOOM_BLUSH, BLOOM_GOLD, BLOOM_RED, BLOOM_BLUSH.clone().offsetHSL(-0.06, -0.1, 0.02)];
    const FLOWER_STEM = new THREE.Color(PAL.grassShade).offsetHSL(0, 0.06, 0.0);
    const FLOWER_LEAF = new THREE.Color(PAL.leafLime).offsetHSL(0, -0.08, -0.04);
    function makeFlower(x, z) {
      const g = new THREE.Group();
      const stem = new THREE.Mesh(new THREE.CylinderGeometry(0.025, 0.035, 0.4, 5), flat(FLOWER_STEM));
      stem.position.y = 0.2;
      const leaf = new THREE.Mesh(new THREE.SphereGeometry(0.09, 5, 4), flat(FLOWER_LEAF));
      leaf.position.set(0.08, 0.16, 0); leaf.scale.set(1.6, 0.4, 0.8);
      const center = new THREE.Mesh(new THREE.SphereGeometry(0.06, 6, 5), flat(0xffdf6a, { emissive: 0xcc9a20, emissiveIntensity: 0.3 }));
      center.position.y = 0.42;
      g.add(stem, leaf, center);
      g.position.y = terrainY(x, z);
      const pc = PETALS[Math.floor(Math.random() * PETALS.length)];
      for (let i = 0; i < 5; i++) {
        const a = (i / 5) * Math.PI * 2;
        const p = new THREE.Mesh(new THREE.SphereGeometry(0.07, 5, 4), flat(pc, { emissive: pc, emissiveIntensity: 0.12 }));
        p.position.set(Math.cos(a) * 0.1, 0.42, Math.sin(a) * 0.1);
        p.scale.set(1.4, 0.35, 0.9); p.rotation.y = -a;
        g.add(p);
      }
      g.position.set(x, terrainY(x, z), z);
      g.rotation.y = Math.random() * Math.PI;
      swayers.push({ g, ph: Math.random() * 9, amp: 0.5 });
      return g;
    }

    function addWildflowers(count, area, avoid, edgeSegs) {
      const stemGeo = new THREE.ConeGeometry(0.035, 0.34, 4);
      stemGeo.translate(0, 0.17, 0);
      // multi-bloom head: one fat lobe + two smaller satellites so blooms read as blooms, not noise
      const hMain = new THREE.IcosahedronGeometry(0.085, 0); hMain.translate(0, 0.37, 0);
      const hA = new THREE.IcosahedronGeometry(0.052, 0); hA.translate(0.075, 0.31, 0.02);
      const hB = new THREE.IcosahedronGeometry(0.046, 0); hB.translate(-0.05, 0.325, -0.06);
      const headGeo = mergeGeoms([hMain, hA, hB]);
      const stems = new THREE.InstancedMesh(stemGeo, flat(FLOWER_STEM, { roughness: 1 }), count);
      const heads = new THREE.InstancedMesh(headGeo, flat(0xffffff, { roughness: 0.7, emissive: 0xffffff, emissiveIntensity: 0.06 }), count);
      addWind(stems.material, 0.05, 0.34);
      addWind(heads.material, 0.05, 0.42);
      stems.receiveShadow = true;
      const m = new THREE.Matrix4(), q = new THREE.Quaternion(), e = new THREE.Euler();
      const pv = new THREE.Vector3(), sc = new THREE.Vector3(), col = new THREE.Color();
      // 4 colorways: white/gold filler, blush + saturated red the accents; drifts lean one way
      const ways = [BLOOM_WHITE, BLOOM_GOLD, BLOOM_BLUSH, BLOOM_RED];
      const pickWay = () => { const r = Math.random(); return r < 0.3 ? 0 : r < 0.62 ? 1 : r < 0.84 ? 2 : 3; };
      // clustered drifts, never uniform-random; ~half hug path edges + fence lines where the eye travels
      const centers = [];
      let ct = 0;
      const nClusters = Math.max(5, Math.round(count / 11));
      while (centers.length < nClusters && ct < nClusters * 40) {
        ct++;
        let cx, cz;
        const roll = Math.random();
        if (roll < 0.18 && edgeSegs && edgeSegs.length) {
          // drift along a fence line / field edge
          const [x1, z1, x2, z2] = edgeSegs[Math.floor(Math.random() * edgeSegs.length)];
          const t = Math.random();
          cx = x1 + (x2 - x1) * t + (Math.random() - 0.5) * 0.8;
          cz = z1 + (z2 - z1) * t + (Math.random() - 0.5) * 0.8;
        } else if (roll < 0.5 && pathRoutes.length) {
          // deliberate accent: a drift along a path edge
          const rt = pathRoutes[Math.floor(Math.random() * pathRoutes.length)];
          const si = Math.floor(Math.random() * (rt.pts.length - 1));
          const [x1, z1] = rt.pts[si], [x2, z2] = rt.pts[si + 1];
          const t = Math.random();
          const dx = x2 - x1, dz = z2 - z1, L = Math.hypot(dx, dz) || 1;
          const side = Math.random() < 0.5 ? -1 : 1;
          const off = (rt.w || 1.5) * 0.6 + 0.7 + Math.random() * 0.9;
          cx = x1 + dx * t + (-dz / L) * side * off;
          cz = z1 + dz * t + (dx / L) * side * off;
        } else if (roll < 0.62 && rockBases.length) {
          const [rx, rz, rs] = rockBases[Math.floor(Math.random() * rockBases.length)];
          const a0 = Math.random() * Math.PI * 2;
          cx = rx + Math.cos(a0) * (0.7 * rs + 0.5); cz = rz + Math.sin(a0) * (0.7 * rs + 0.5);
        } else {
          cx = (Math.random() - 0.5) * area; cz = (Math.random() - 0.5) * area;
        }
        if (Math.abs(cx) > area / 2 || Math.abs(cz) > area / 2) continue;
        if (avoid && avoid(cx, cz)) continue;
        centers.push([cx, cz, pickWay()]);
      }
      let placed = 0, tries = 0;
      while (placed < count && tries < count * 14 && centers.length) {
        tries++;
        const [cx, cz, way] = centers[Math.floor(Math.random() * centers.length)];
        const a = Math.random() * Math.PI * 2, rr = (Math.random() + Math.random()) * 1.1;
        const x = cx + Math.cos(a) * rr, z = cz + Math.sin(a) * rr;
        if (Math.abs(x) > area / 2 || Math.abs(z) > area / 2) continue;
        if (avoid && avoid(x, z)) continue;
        e.set((Math.random() - 0.5) * 0.3, Math.random() * Math.PI, (Math.random() - 0.5) * 0.3);
        q.setFromEuler(e);
        pv.set(x, terrainY(x, z), z);
        const wPick = Math.random() < 0.7 ? way : pickWay();
        // red accent species carries bigger multi-bloom heads; whites stay filler-sized
        const sce = (0.8 + Math.random() * 0.8) * (wPick === 3 ? 1.3 : wPick === 0 ? 0.9 : 1);
        sc.set(sce, sce, sce);
        m.compose(pv, q, sc);
        stems.setMatrixAt(placed, m);
        heads.setMatrixAt(placed, m);
        col.copy(ways[wPick])
          .offsetHSL((Math.random() - 0.5) * 0.02, 0, (Math.random() - 0.5) * 0.06)
          .convertSRGBToLinear();
        heads.setColorAt(placed, col);
        placed++;
      }
      stems.count = placed; heads.count = placed;
      stems.instanceMatrix.needsUpdate = true; heads.instanceMatrix.needsUpdate = true;
      if (heads.instanceColor) heads.instanceColor.needsUpdate = true;
      worldGroup.add(stems, heads);
    }

    function addPavedPlaza(px1, pz1, px2, pz2) {
      // mortar lifted toward the stone family so the gaps read as seams, not shadow holes
      const base = new THREE.Mesh(new THREE.BoxGeometry(px2 - px1, 0.06, pz2 - pz1), flat(new THREE.Color(PAL.stone).offsetHSL(0.012, 0, -0.075), { roughness: 1 }));
      base.position.set((px1 + px2) / 2, 0.03, (pz1 + pz2) / 2);
      base.receiveShadow = true;
      addCloudShade(base.material);
      worldGroup.add(base);
      const cells = [];
      for (let x = px1 + 0.6; x < px2 - 0.3; x += 0.94)
        for (let z = pz1 + 0.6; z < pz2 - 0.3; z += 0.94)
          cells.push([x + (Math.random() - 0.5) * 0.12, z + (Math.random() - 0.5) * 0.12]);
      const geo = new THREE.CylinderGeometry(0.5, 0.53, 0.1, 6);
      const inst = new THREE.InstancedMesh(geo, flat(0xffffff, { roughness: 1 }), cells.length);
      addWind(inst.material, 0.0, 1.0);
      inst.receiveShadow = true;
      const m = new THREE.Matrix4(), q = new THREE.Quaternion(), e = new THREE.Euler();
      const pv = new THREE.Vector3(), sc = new THREE.Vector3(), col = new THREE.Color();
      cells.forEach(([x, z], i) => {
        e.set(0, Math.random() * Math.PI, 0); q.setFromEuler(e);
        pv.set(x, 0.06, z);
        const sp = 0.9 + Math.random() * 0.18;
        sc.set(sp, 1, sp * (0.9 + Math.random() * 0.2));
        m.compose(pv, q, sc);
        inst.setMatrixAt(i, m);
        col.setHex(PAL.pathStone).convertSRGBToLinear().offsetHSL(0.004 * (Math.random() - 0.5), (Math.random() - 0.5) * 0.05, (Math.random() - 0.5) * 0.2);
        inst.setColorAt(i, col);
      });
      inst.instanceMatrix.needsUpdate = true;
      if (inst.instanceColor) inst.instanceColor.needsUpdate = true;
      worldGroup.add(inst);
    }

    function makeTulip(x, z) {
      const g = new THREE.Group();
      const stem = new THREE.Mesh(new THREE.CylinderGeometry(0.03, 0.04, 0.5, 5), flat(FLOWER_STEM));
      stem.position.y = 0.25;
      const leaf = new THREE.Mesh(new THREE.SphereGeometry(0.1, 5, 4), flat(FLOWER_LEAF));
      leaf.position.set(0.09, 0.2, 0); leaf.scale.set(1.8, 0.35, 0.7); leaf.rotation.z = -0.4;
      // tulip cups run a touch richer than the wildflower drifts, same 3-way family
      const c = [
        BLOOM_GOLD.clone().offsetHSL(0, 0.1, -0.04),
        BLOOM_BLUSH.clone().offsetHSL(0, 0.12, -0.08),
        BLOOM_WHITE,
        BLOOM_GOLD.clone().offsetHSL(-0.035, 0.12, -0.06),
      ][Math.floor(Math.random() * 4)];
      const cup = new THREE.Mesh(new THREE.SphereGeometry(0.13, 6, 5), flat(c, { emissive: c, emissiveIntensity: 0.15 }));
      cup.position.y = 0.55; cup.scale.set(1, 1.25, 1);
      const cupTop = new THREE.Mesh(new THREE.ConeGeometry(0.13, 0.12, 6), flat(c));
      cupTop.position.y = 0.66; cupTop.rotation.x = Math.PI;
      g.add(stem, leaf, cup, cupTop);
      g.position.set(x, terrainY(x, z), z);
      g.rotation.y = Math.random() * Math.PI;
      g.rotation.z = (Math.random() - 0.5) * 0.15;
      swayers.push({ g, ph: Math.random() * 9, amp: 0.6 });
      return g;
    }
    const mixFlower = (x, z) => (Math.random() < 0.5 ? makeFlower(x, z) : makeTulip(x, z));
    function makeBush(x, z, s = 1) {
      // never slice into a scatter boulder — slide out to the rock's edge instead
      // (raw bush/rock mesh intersections read as a placement bug at close camera)
      for (const [rx, rz, rs] of rockBases) {
        const need = 0.95 * rs + 0.55 * s; // full rock footprint + bush radius
        let dx = x - rx, dz = z - rz;
        const d = Math.hypot(dx, dz);
        if (d < need) {
          if (d < 1e-4) { dx = 1; dz = 0; }
          const k = need / (d || 1);
          x = rx + dx * k; z = rz + dz * k;
        }
      }
      const g = new THREE.Group();
      // ONE species per bush (per-lump random tokens read as patchwork noise) in the
      // lime/mid band + rare ochre; dark cool base skirt seats it into the grass.
      // Lumps merge into a single vertex-colored mesh — 1 draw call per bush.
      const sp = speciesShift();
      const tok = Math.random() < 0.1 ? PAL.leafWarm : Math.random() < 0.45 ? PAL.leafLime : PAL.leafMid;
      const parts = [];
      parts.push(lumpG(new THREE.IcosahedronGeometry(0.52 * s, 0), 1.15, 0.5, 1.15,
        Math.random(), Math.random(), Math.random(), 0, 0.15 * s, 0,
        spC(PAL.leafDeep, sp, 0.02).offsetHSL(0.01, -0.06, -0.05).convertSRGBToLinear()));
      const nl = 2 + (Math.random() < 0.5 ? 1 : 0);
      for (let i = 0; i < nl; i++) {
        const a = Math.random() * Math.PI * 2, rad = i === 0 ? 0 : (0.26 + Math.random() * 0.16) * s;
        const r = (i === 0 ? 0.55 : 0.34 + Math.random() * 0.1) * s;
        parts.push(lumpG(new THREE.IcosahedronGeometry(r, 0), 1, 0.72 + Math.random() * 0.16, 1,
          Math.random(), Math.random(), Math.random(),
          Math.cos(a) * rad, (i === 0 ? 0.4 : 0.3 + Math.random() * 0.18) * s, Math.sin(a) * rad,
          spC(tok, sp).offsetHSL(0, 0, i === 0 ? 0 : 0.025).convertSRGBToLinear()));
      }
      const m = new THREE.Mesh(mergeGeoms(parts), canopyVCMat);
      m.castShadow = true;
      g.add(m);
      g.position.set(x, terrainY(x, z), z);
      addCircleCol(x, z, 0.5 * s);
      swayers.push({ g, ph: Math.random() * 9, amp: 0.8 });
      return g;
    }
    function addSprouts(count, area, avoid) {
      const geo = new THREE.IcosahedronGeometry(0.1, 0);
      geo.translate(0, 0.07, 0);
      const inst = new THREE.InstancedMesh(geo, flat(0xffffff, { roughness: 1 }), count);
      addWind(inst.material, 0.028, 0.16);
      inst.receiveShadow = true;
      const m = new THREE.Matrix4(), q = new THREE.Quaternion(), e = new THREE.Euler();
      const p = new THREE.Vector3(), sc = new THREE.Vector3(), col = new THREE.Color();
      let placed = 0, tries = 0;
      while (placed < count && tries < count * 12) {
        tries++;
        const x = (Math.random() - 0.5) * area, z = (Math.random() - 0.5) * area;
        if (avoid && avoid(x, z)) continue;
        e.set(0, Math.random() * Math.PI, 0); q.setFromEuler(e);
        p.set(x, terrainY(x, z), z);
        sc.set(1.2 + Math.random(), 0.4 + Math.random() * 0.4, 1.2 + Math.random());
        m.compose(p, q, sc);
        inst.setMatrixAt(placed, m);
        // grass-ramp tint tied to the shared noise field — sprouts blend into the meadow
        // instead of reading as dark saturated blobs
        const sw = meadowNoise(x, z) + (Math.random() - 0.5) * 0.3;
        col.copy(SRGB(PAL.grassBase));
        if (sw > 0) col.lerp(SRGB(PAL.grassSun), Math.min(1, sw) * 0.6);
        else col.lerp(SRGB(PAL.grassShade), Math.min(1, -sw) * 0.55);
        col.offsetHSL((Math.random() - 0.5) * 0.02, -0.04, 0.02 + (Math.random() - 0.5) * 0.06);
        inst.setColorAt(placed, col);
        placed++;
      }
      inst.count = placed;
      inst.instanceMatrix.needsUpdate = true;
      if (inst.instanceColor) inst.instanceColor.needsUpdate = true;
      worldGroup.add(inst);
    }

    function makeFence(x1, z1, x2, z2) {
      // hand-set timber fence merged into ONE vertex-colored mesh (1 draw call per run):
      // warm tan-orange wood, per-post hue/value jitter + lean wobble, rails segmented
      // post-to-post with darkened end-grain where they meet posts (faked joinery)
      const g = new THREE.Group();
      const dx = x2 - x1, dz = z2 - z1, len = Math.hypot(dx, dz);
      const n = Math.max(2, Math.round(len / 1.2));
      const yaw = -Math.atan2(dz, dx);
      // saturated warm timber — PAL.wood pulled toward PAL.bark (A Short Hike fence family)
      const timber = new THREE.Color(PAL.wood).lerp(new THREE.Color(PAL.bark), 0.3).offsetHSL(-0.01, 0.16, 0.015);
      const geoms = [];
      const tmpC = new THREE.Color();
      const paint = (bg, c, endDip) => {
        // solid vertex tint; endDip darkens vertices near the box's ±x ends (rail joinery)
        const posA = bg.attributes.position, cols = new Float32Array(posA.count * 3);
        const bb = bg.boundingBox || (bg.computeBoundingBox(), bg.boundingBox);
        const hx = Math.max(0.001, bb.max.x);
        for (let vi = 0; vi < posA.count; vi++) {
          tmpC.copy(c);
          if (endDip && Math.abs(posA.getX(vi)) > hx - 0.14) tmpC.offsetHSL(0.004, 0.02, -0.085);
          cols[vi * 3] = tmpC.r; cols[vi * 3 + 1] = tmpC.g; cols[vi * 3 + 2] = tmpC.b;
        }
        bg.setAttribute("color", new THREE.BufferAttribute(cols, 3));
        return bg;
      };
      const postPts = [];
      for (let i = 0; i <= n; i++) {
        const t = i / n;
        const px = x1 + dx * t, pz = z1 + dz * t;
        const h = 0.86 + Math.random() * 0.1;
        postPts.push([px, pz, h]);
        const pc = timber.clone()
          .offsetHSL((Math.random() - 0.5) * 0.016, (Math.random() - 0.5) * 0.09, -0.045 + (Math.random() - 0.5) * 0.075)
          .convertSRGBToLinear();
        const pg = paint(new THREE.BoxGeometry(0.14 * (0.94 + Math.random() * 0.14), h, 0.145 * (0.94 + Math.random() * 0.14)), pc, false);
        pg.rotateX((Math.random() - 0.5) * 0.1);   // hand-set lean, ~±3°
        pg.rotateZ((Math.random() - 0.5) * 0.1);
        pg.translate(px, h / 2, pz);
        geoms.push(pg);
      }
      // rails segmented between posts so each carries its own tone + joined ends
      [0.7, 0.365].forEach((ry, ri) => {
        for (let i = 0; i < n; i++) {
          const [ax, az] = postPts[i], [bx, bz] = postPts[i + 1];
          const segL = Math.hypot(bx - ax, bz - az) + 0.06;
          const rc = timber.clone()
            .offsetHSL((Math.random() - 0.5) * 0.014, (Math.random() - 0.5) * 0.07, 0.035 + (Math.random() - 0.5) * 0.07)
            .convertSRGBToLinear();
          // rare sagging rail: one end slipped its joint — reads hand-built, not extruded
          const sag = ri === 1 && Math.random() < 0.06;
          const rg = paint(new THREE.BoxGeometry(segL, 0.095, 0.075), rc, true);
          rg.rotateZ((Math.random() - 0.5) * 0.055 + (sag ? (Math.random() < 0.5 ? 0.17 : -0.17) : 0));
          rg.rotateY(yaw);
          rg.translate((ax + bx) / 2, ry - (sag ? 0.09 : 0) + (ri ? 0 : (Math.random() - 0.5) * 0.045), (az + bz) / 2);
          geoms.push(rg);
        }
      });
      const fence = new THREE.Mesh(mergeGeoms(geoms), flat(0xffffff, { vertexColors: true }));
      fence.castShadow = true; fence.receiveShadow = true;
      g.add(fence);
      addBoxCol((x1 + x2) / 2, (z1 + z2) / 2, Math.abs(dx) / 2 + 0.12, Math.abs(dz) / 2 + 0.12, 0);
      return g;
    }
    function makeSign(x, z, rotY = 0) {
      const g = new THREE.Group();
      const post = new THREE.Mesh(new THREE.CylinderGeometry(0.07, 0.09, 1.2, 5), flat(PAL.bark));
      post.position.y = 0.6;
      const board = new THREE.Mesh(new THREE.BoxGeometry(1.2, 0.55, 0.08), flat(new THREE.Color(PAL.wood).offsetHSL(0.004, 0.03, 0.045)));
      board.position.y = 1.15; board.castShadow = true;
      g.add(post, board); g.position.set(x, 0, z); g.rotation.y = rotY;
      addCircleCol(x, z, 0.28);
      return g;
    }

    // ---- shared low-frequency meadow noise: >0 = dry sunlit patch, <0 = cool moist patch ----
    // two value-noise octaves; ground tint, grass ramp, and clover patches all sample the
    // SAME field so tuft color agrees with the ground beneath it.
    const meadowNoise = (x, z) =>
      0.35 * (Math.sin(x * 0.11 + z * 0.045) + Math.sin(z * 0.09 - x * 0.05)) +
      0.6 * Math.sin(x * 0.033 + 1.7) * Math.sin(z * 0.041 + 0.4);
    // second decorrelated channel for the pale-sage macro patches
    const meadowNoise2 = (x, z) => meadowNoise(z * 1.63 + 31.0, x * 1.63 - 12.0);

    // ---- path routes, registered per-map BEFORE makeGround so the ground itself
    // carries a worn dry-earth ribbon under/around the flagstones (path carved INTO
    // the land instead of coins floating on grass) ----
    let pathRoutes = [];
    const setPathRoutes = (routes) => { pathRoutes = routes; };
    function pathWear(x, z) {
      // 1 at a route's centerline -> 0 at the edge of its worn band
      let wear = 0;
      for (const rt of pathRoutes) {
        const band = (rt.w || 1.5) * 0.6 + 0.85;
        const pts = rt.pts;
        for (let i = 0; i < pts.length - 1; i++) {
          const x1 = pts[i][0], z1 = pts[i][1], x2 = pts[i + 1][0], z2 = pts[i + 1][1];
          const dx = x2 - x1, dz = z2 - z1;
          const L2 = dx * dx + dz * dz || 1;
          let t = ((x - x1) * dx + (z - z1) * dz) / L2;
          t = t < 0 ? 0 : t > 1 ? 1 : t;
          const px = x1 + dx * t - x, pz = z1 + dz * t - z;
          const w = 1 - Math.sqrt(px * px + pz * pz) / band;
          if (w > wear) wear = w;
        }
      }
      return wear;
    }
    const rockBases = []; // makeRock registers; addGrass hugs each base with tufts

    // ---- tiny geometry merge (r128 has no bundled BufferGeometryUtils) ----
    function mergeGeoms(list) {
      const parts = list.map((g) => (g.index ? g.toNonIndexed() : g));
      let vCount = 0;
      parts.forEach((g) => { vCount += g.attributes.position.count; });
      const pos = new Float32Array(vCount * 3), nor = new Float32Array(vCount * 3);
      const hasCol = parts.every((g) => g.attributes.color);
      const colA = hasCol ? new Float32Array(vCount * 3) : null;
      let o = 0;
      parts.forEach((g) => {
        pos.set(g.attributes.position.array, o * 3);
        nor.set(g.attributes.normal.array, o * 3);
        if (hasCol) colA.set(g.attributes.color.array, o * 3);
        o += g.attributes.position.count;
      });
      const out = new THREE.BufferGeometry();
      out.setAttribute("position", new THREE.BufferAttribute(pos, 3));
      out.setAttribute("normal", new THREE.BufferAttribute(nor, 3));
      if (hasCol) out.setAttribute("color", new THREE.BufferAttribute(colA, 3));
      return out;
    }
    // ---- Ground: faceted, hand-painted color variation ----
    function makeGround(size, color, tintFn, heightFn) {
      const groundH = heightFn || ((x, z) => terrainY(x, z));
      const geo = new THREE.PlaneGeometry(size, size, 76, 76);
      const pos = geo.attributes.position;
      const colors = [];
      // desaturate ~12% + nudge warm so the base escapes plastic lime
      const base = new THREE.Color(color).offsetHSL(0.006, -0.075, 0.008).convertSRGBToLinear();
      const deep = base.clone().offsetHSL(0.008, 0.02, -0.11);
      const cSun = SRGB(PAL.grassSun), cShade = SRGB(PAL.grassShade);
      const cSage = new THREE.Color(PAL.grassShade).offsetHSL(0.012, -0.13, 0.11).convertSRGBToLinear();
      const cWorn = new THREE.Color(PAL.pathStone).offsetHSL(-0.006, -0.06, -0.1).convertSRGBToLinear();
      const cStraw = new THREE.Color(PAL.grassSun).offsetHSL(0.012, -0.1, 0.03).convertSRGBToLinear();
      // two extra painted-macro channels (A Short Hike): dry ochre crests + fresh moist green
      const cOchre = new THREE.Color(PAL.grassSun).offsetHSL(-0.032, 0.045, -0.005).convertSRGBToLinear();
      const cFresh = new THREE.Color(PAL.grassShade).offsetHSL(-0.012, 0.09, 0.035).convertSRGBToLinear();
      // baked aerial perspective: far terrain melts toward a bluer fog family
      const cFar = new THREE.Color(PAL.fog).lerp(new THREE.Color(PAL.skyMid), 0.35).convertSRGBToLinear();
      const tmp = new THREE.Color();
      for (let i = 0; i < pos.count; i++) {
        const wx = pos.getX(i), wz = -pos.getY(i);
        pos.setZ(i, groundH(wx, wz) + (Math.random() - 0.5) * 0.1);
        tmp.copy(base).lerp(deep, Math.random() * Math.random() * 0.38);
        // macro hue drift — sunlit hilltops go dry yellow-green, hollows go cool teal-green,
        // with a second decorrelated pale-sage channel so no big patch holds one hue
        const w = meadowNoise(wx, wz);
        if (w > 0) tmp.lerp(cSun, Math.min(1, w * 1.2) * 0.85);
        else tmp.lerp(cShade, Math.min(1, -w * 1.15) * 0.9);
        if (w > 0.5) tmp.lerp(cOchre, Math.min(1, (w - 0.5) * 2.2) * 0.6); // dry crests bake ochre
        const w2 = meadowNoise2(wx, wz);
        if (w2 > 0.18) tmp.lerp(cSage, Math.min(1, w2 - 0.18) * 0.55);
        if (w2 < -0.3) tmp.lerp(cFresh, Math.min(1, -w2 - 0.3) * 0.6); // moist fresh-green pools
        // worn dry-earth ribbon under registered path routes: straw fringe -> trodden dirt core
        const wear = pathWear(wx, wz);
        if (wear > 0) {
          tmp.lerp(cStraw, Math.min(1, wear * 2.2) * 0.7);
          tmp.lerp(cWorn, Math.pow(Math.min(1, wear * 1.12), 1.6) * 0.85);
        }
        if (tintFn) tintFn(wx, wz, tmp);
        // distance desaturation ramp (aerial perspective baked into the vertex colors)
        const dR = Math.hypot(wx, wz);
        if (dR > size * 0.31) tmp.lerp(cFar, Math.min(1, (dR - size * 0.31) / (size * 0.3)) * 0.42);
        const v = 0.95 + Math.random() * 0.1;
        colors.push(tmp.r * v, tmp.g * v, tmp.b * v);
      }
      geo.setAttribute("color", new THREE.Float32BufferAttribute(colors, 3));
      const gm = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 1, flatShading: true });
      addCloudShade(gm);
      const m = new THREE.Mesh(geo, gm);
      m.rotation.x = -Math.PI / 2; m.receiveShadow = true;
      return m;
    }

    // ---- Flagstone paths (instanced individual stones) ----
    function addFlagstonePath(points, width = 1.5) {
      const stones = [];
      for (let i = 0; i < points.length - 1; i++) {
        const [x1, z1] = points[i], [x2, z2] = points[i + 1];
        const len = Math.hypot(x2 - x1, z2 - z1);
        const dirX = (x2 - x1) / len, dirZ = (z2 - z1) / len;
        const perpX = -dirZ, perpZ = dirX;
        const n = Math.floor(len / 0.85);
        for (let j = 0; j <= n; j++) {
          const t = j / Math.max(1, n);
          const lateral = ((j % 2 === 0 ? -1 : 1) * (0.16 + Math.random() * 0.12)) * (width / 1.5);
          stones.push({
            x: x1 + dirX * len * t + perpX * lateral + (Math.random() - 0.5) * 0.07,
            z: z1 + dirZ * len * t + perpZ * lateral + (Math.random() - 0.5) * 0.07,
            s: 0.62 + Math.random() * 0.68,
            rot: Math.random() * Math.PI,
          });
          // shoulder litter: occasional half-buried broken stone / pebble off the run's edge
          if (Math.random() < 0.38) {
            const side = Math.random() < 0.5 ? -1 : 1;
            const off = (width / 1.5) * (0.62 + Math.random() * 0.55);
            stones.push({
              x: x1 + dirX * len * t + perpX * side * off + (Math.random() - 0.5) * 0.2,
              z: z1 + dirZ * len * t + perpZ * side * off + (Math.random() - 0.5) * 0.2,
              s: 0.16 + Math.random() * 0.24,
              rot: Math.random() * Math.PI,
              frag: true,
            });
          }
        }
      }
      const geo = new THREE.CylinderGeometry(0.5, 0.56, 0.12, 6);
      {
        // baked bevel split: bright top face, shadowed side wall — stones read set INTO the earth
        const nor = geo.attributes.normal, bevCols = new Float32Array(nor.count * 3);
        for (let vi = 0; vi < nor.count; vi++) {
          const up = nor.getY(vi) > 0.7;
          bevCols[vi * 3] = up ? 1 : 0.66; bevCols[vi * 3 + 1] = up ? 1 : 0.645; bevCols[vi * 3 + 2] = up ? 1 : 0.615;
        }
        geo.setAttribute("color", new THREE.BufferAttribute(bevCols, 3));
      }
      const inst = new THREE.InstancedMesh(geo, flat(0xffffff, { vertexColors: true }), stones.length);
      addWind(inst.material, 0.0, 1.0);
      inst.receiveShadow = true; inst.castShadow = true;
      const m = new THREE.Matrix4(), q = new THREE.Quaternion(), e = new THREE.Euler();
      const p = new THREE.Vector3(), sc = new THREE.Vector3(), col = new THREE.Color();
      // 3 discrete stone shades so runs read hand-laid, not confetti
      const SHADE3 = [0, -0.055, 0.05];
      stones.forEach((st, i) => {
        // settled tilt + sunk 30-50% into the worn-dirt ribbon; fragments bury deeper
        e.set((Math.random() - 0.5) * 0.09, st.rot, (Math.random() - 0.5) * 0.09); q.setFromEuler(e);
        p.set(st.x, terrainY(st.x, st.z) + (st.frag ? 0.002 : 0.014 + Math.random() * 0.018), st.z);
        sc.set(st.s, st.frag ? 0.7 : 0.75 + Math.random() * 0.4, st.s * (0.8 + Math.random() * 0.4));
        m.compose(p, q, sc);
        inst.setMatrixAt(i, m);
        // 3 tone families (warm ochre / cool grey / moss-edged) + discrete value steps
        col.setHex(PAL.pathStone).convertSRGBToLinear();
        const fam = Math.random();
        if (fam < 0.3) col.lerp(SRGB(PAL.stone), 0.5 + Math.random() * 0.2); // cool grey slab
        else if (fam < 0.45) col.lerp(SRGB(PAL.leafDeep), 0.16 + Math.random() * 0.1); // moss-kissed
        col.offsetHSL((Math.random() - 0.5) * 0.012, (Math.random() - 0.5) * 0.03,
          SHADE3[Math.floor(Math.random() * 3)] + (Math.random() - 0.5) * 0.05 + (st.frag ? -0.05 : 0) - 0.015);
        inst.setColorAt(i, col);
      });
      inst.instanceMatrix.needsUpdate = true;
      if (inst.instanceColor) inst.instanceColor.needsUpdate = true;
      worldGroup.add(inst);
    }

    // ---- Instanced grass tufts: crossed-blade clusters (thin triangles, not cones),
    // 2 variants, each ONE draw call. Vertex gradient roots each blade in the ground
    // color (instance tint = ground hue beneath) and only the tips catch warm sun ----
    function bladeTuftGeo(nBlades, hMin, hMax, spread) {
      const pos = [], nor = [], col = [];
      const va = new THREE.Vector3(), vb = new THREE.Vector3(), vn = new THREE.Vector3();
      for (let i = 0; i < nBlades; i++) {
        const a = (i / nBlades) * Math.PI * 2 + Math.random() * 1.1;
        const bx = Math.cos(a), bz = Math.sin(a);
        const h = hMin + Math.random() * (hMax - hMin);
        const lean = spread * (0.5 + Math.random());
        const bw = 0.045 + Math.random() * 0.035;
        const ox = bx * 0.06 * Math.random(), oz = bz * 0.06 * Math.random();
        const px = -bz * bw, pz = bx * bw;
        const tx = ox + bx * lean + (Math.random() - 0.5) * 0.05;
        const tz = oz + bz * lean + (Math.random() - 0.5) * 0.05;
        pos.push(ox - px, 0, oz - pz, ox + px, 0, oz + pz, tx, h, tz);
        va.set(2 * px, 0, 2 * pz); vb.set(tx - (ox - px), h, tz - (oz - pz));
        vn.crossVectors(va, vb).normalize();
        for (let k = 0; k < 3; k++) nor.push(vn.x, vn.y, vn.z);
        // root sits IN the ground (matches instance tint), tip runs lighter + warm
        const rv = 0.86 + Math.random() * 0.08;
        col.push(rv * 0.98, rv, rv * 0.96, rv * 0.98, rv, rv * 0.96, 1.3, 1.24, 1.0);
      }
      const g = new THREE.BufferGeometry();
      g.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3));
      g.setAttribute("normal", new THREE.Float32BufferAttribute(nor, 3));
      g.setAttribute("color", new THREE.Float32BufferAttribute(col, 3));
      return g;
    }
    // compat shim for older cone-spec callers (e.g. river bank tufts): maps the old
    // [radius, height, ...] spec onto the new blade-cluster geometry. Callers use
    // FrontSide materials, so the back faces are baked in (flipped winding).
    function tuftGeo(spec) {
      const hs = spec.map((s) => s[1]);
      const g = bladeTuftGeo(spec.length + 3, Math.min(...hs) * 0.75, Math.max(...hs) * 1.1, 0.16);
      const P = g.attributes.position.array, N = g.attributes.normal.array, C = g.attributes.color.array;
      const n = P.length;
      const P2 = new Float32Array(n * 2), N2 = new Float32Array(n * 2), C2 = new Float32Array(n * 2);
      P2.set(P); N2.set(N); C2.set(C);
      for (let t = 0; t < n; t += 9) {
        const o = n + t;
        for (let k = 0; k < 3; k++) {
          const src = t + [0, 2, 1][k] * 3, dst = o + k * 3;
          for (let d = 0; d < 3; d++) {
            P2[dst + d] = P[src + d];
            N2[dst + d] = -N[src + d];
            C2[dst + d] = C[src + d];
          }
        }
      }
      const out = new THREE.BufferGeometry();
      out.setAttribute("position", new THREE.BufferAttribute(P2, 3));
      out.setAttribute("normal", new THREE.BufferAttribute(N2, 3));
      out.setAttribute("color", new THREE.BufferAttribute(C2, 3));
      return out;
    }
    // clump field: dense drifts and near-bare patches, not even stubble
    const grassClump = (x, z) =>
      0.5 + 0.5 * Math.sin(x * 0.21 + z * 0.29 + 2.1) * Math.sin(x * 0.16 - z * 0.185 + 0.7);
    function addGrass(count, area, avoid) {
      // three tuft silhouettes (spiky / low fan / tall arching) so close-camera grass
      // never reads as one stamped star shape; all share one wind material
      const geoSpike = bladeTuftGeo(7, 0.26, 0.48, 0.13);
      const geoFan = bladeTuftGeo(6, 0.14, 0.28, 0.24);
      const geoTall = bladeTuftGeo(5, 0.4, 0.64, 0.3);
      const mat = flat(0xffffff, { vertexColors: true, side: THREE.DoubleSide });
      addWind(mat, 0.075, 0.4);
      const nSpike = Math.round(count * 0.5), nFan = Math.round(count * 0.34), nTall = count - nSpike - nFan;
      const spikes = new THREE.InstancedMesh(geoSpike, mat, nSpike);
      const fans = new THREE.InstancedMesh(geoFan, mat, nFan);
      const talls = new THREE.InstancedMesh(geoTall, mat, nTall);
      spikes.receiveShadow = true; fans.receiveShadow = true; talls.receiveShadow = true;
      const m = new THREE.Matrix4(), q = new THREE.Quaternion(), e = new THREE.Euler();
      const p = new THREE.Vector3(), sc = new THREE.Vector3(), col = new THREE.Color();
      // same warm-desat base the ground itself uses, so roots melt into the terrain
      const cBase = new THREE.Color(PAL.grassBase).offsetHSL(0.006, -0.075, 0.008).convertSRGBToLinear();
      const cSun = SRGB(PAL.grassSun), cShade = SRGB(PAL.grassShade);
      const tint = (x, z) => {
        // sample the SAME noise field + the same lerp weights the ground uses, so the
        // tuft ROOT color equals the dirt below it — only the vertex-gradient tips contrast
        const wj = meadowNoise(x, z) + (Math.random() - 0.5) * 0.16;
        col.copy(cBase);
        if (wj > 0) col.lerp(cSun, Math.min(1, wj * 1.15) * 0.8);
        else col.lerp(cShade, Math.min(1, -wj * 1.1) * 0.85);
        col.offsetHSL((Math.random() - 0.5) * 0.01, 0, 0.01 + (Math.random() - 0.5) * 0.025);
        return col;
      };
      const put = (inst, idx, x, z, s) => {
        e.set((Math.random() - 0.5) * 0.35, Math.random() * Math.PI, (Math.random() - 0.5) * 0.35);
        q.setFromEuler(e);
        p.set(x, terrainY(x, z) - 0.03, z);
        sc.set(s, s * (0.8 + Math.random() * 0.7), s);
        m.compose(p, q, sc);
        inst.setMatrixAt(idx, m);
        inst.setColorAt(idx, tint(x, z));
      };
      let pS = 0, pF = 0, pT = 0;
      // tufts hugging each scatter-rock base ground the boulders in the meadow
      for (const [rx, rz, rs] of rockBases) {
        if (Math.abs(rx) > area / 2 || Math.abs(rz) > area / 2) continue;
        const k = 2 + (Math.random() < 0.6 ? 1 : 0);
        for (let i = 0; i < k && pS < nSpike; i++) {
          const a = Math.random() * Math.PI * 2, d = 0.58 * rs + 0.14 + Math.random() * 0.1;
          put(spikes, pS++, rx + Math.cos(a) * d, rz + Math.sin(a) * d, 1.0 + Math.random() * 0.5);
        }
      }
      let tries = 0;
      while (pS + pF + pT < nSpike + nFan + nTall && tries < count * 16) {
        tries++;
        const x = (Math.random() - 0.5) * area, z = (Math.random() - 0.5) * area;
        if (avoid && avoid(x, z)) continue;
        // clump-noise gate: dense drifts + near-bare patches, biased into shade pockets
        let pAcc = 0.06 + 0.94 * Math.pow(grassClump(x, z), 1.5);
        if (meadowNoise(x, z) < -0.1) pAcc = Math.min(1, pAcc + 0.2);
        if (Math.random() > pAcc) continue;
        const s = 0.65 + Math.random() * 1.05;
        const roll = Math.random();
        // tall arching tufts live inside dense clumps only — accents, not carpet
        if (pT < nTall && roll < 0.16 && grassClump(x, z) > 0.55) put(talls, pT++, x, z, s * 0.9);
        else if (pF < nFan && (pS >= nSpike || roll < 0.5)) put(fans, pF++, x, z, s);
        else if (pS < nSpike) put(spikes, pS++, x, z, s);
        else if (pF < nFan) put(fans, pF++, x, z, s);
        else if (pT < nTall) put(talls, pT++, x, z, s * 0.9);
      }
      spikes.count = pS; fans.count = pF; talls.count = pT;
      spikes.instanceMatrix.needsUpdate = true; fans.instanceMatrix.needsUpdate = true; talls.instanceMatrix.needsUpdate = true;
      if (spikes.instanceColor) spikes.instanceColor.needsUpdate = true;
      if (fans.instanceColor) fans.instanceColor.needsUpdate = true;
      if (talls.instanceColor) talls.instanceColor.needsUpdate = true;
      worldGroup.add(spikes, fans, talls);
    }

    // ---- Instanced clover / dry-grass ground patches (one draw call) ----
    function addGroundPatches(count, area, avoid) {
      const geo = new THREE.IcosahedronGeometry(0.6, 0);
      geo.scale(1, 0.14, 1);
      const inst = new THREE.InstancedMesh(geo, flat(0xffffff), count);
      inst.receiveShadow = true;
      const m = new THREE.Matrix4(), q = new THREE.Quaternion(), e = new THREE.Euler();
      const p = new THREE.Vector3(), sc = new THREE.Vector3(), col = new THREE.Color();
      const cSun = SRGB(PAL.grassSun), cBase = SRGB(PAL.grassBase);
      let placed = 0, tries = 0;
      while (placed < count && tries < count * 14) {
        tries++;
        const x = (Math.random() - 0.5) * area, z = (Math.random() - 0.5) * area;
        if (avoid && avoid(x, z)) continue;
        // dry clover discs live on the sunlit patches of the noise field
        if (meadowNoise(x, z) < 0.05 && Math.random() < 0.75) continue;
        e.set(0, Math.random() * Math.PI, 0); q.setFromEuler(e);
        p.set(x, terrainY(x, z) + 0.005, z);
        const s = 0.7 + Math.random() * 1.0;
        sc.set(s, 0.55 + Math.random() * 0.4, s * (0.75 + Math.random() * 0.5));
        m.compose(p, q, sc);
        inst.setMatrixAt(placed, m);
        // dry straw sitting AT ground value — reads as a worn patch, never bright popcorn
        col.copy(cSun).offsetHSL(0.008, -0.045, -0.02).lerp(cBase, 0.25 + Math.random() * 0.3)
          .offsetHSL((Math.random() - 0.5) * 0.015, 0, (Math.random() - 0.5) * 0.035);
        inst.setColorAt(placed, col);
        placed++;
      }
      inst.count = placed;
      inst.instanceMatrix.needsUpdate = true;
      if (inst.instanceColor) inst.instanceColor.needsUpdate = true;
      worldGroup.add(inst);
    }

    // ---- Border forest ring (2 draw calls: trunks + foliage) ----
    function addForestRing(rMin, rMax, count, exitPts = []) {
      const trunkGeo = new THREE.CylinderGeometry(0.14, 0.22, 1, 5);
      trunkGeo.translate(0, 0.5, 0);
      const coneGeo = new THREE.ConeGeometry(1, 1.2, 6);
      const trunks = new THREE.InstancedMesh(trunkGeo, flat(PAL.bark), count);
      const cones = new THREE.InstancedMesh(coneGeo, flat(0xffffff), count * 3);
      trunks.castShadow = true; cones.castShadow = true;
      const m = new THREE.Matrix4(), q = new THREE.Quaternion(), e = new THREE.Euler();
      const p = new THREE.Vector3(), sc = new THREE.Vector3(), col = new THREE.Color();
      const hazeCol = SRGB(PAL.fog);
      let ti = 0, ci = 0, tries = 0;
      while (ti < count && tries < count * 20) {
        tries++;
        const a = Math.random() * Math.PI * 2;
        const r = rMin + Math.random() * (rMax - rMin);
        const x = Math.cos(a) * r, z = Math.sin(a) * r;
        if (exitPts.some(([ex, ez]) => Math.hypot(x - ex, z - ez) < 5)) continue;
        const s = 1.1 + Math.random() * 1.3;
        const baseRot = Math.random() * Math.PI;
        e.set(0, baseRot, 0); q.setFromEuler(e);
        p.set(x, terrainY(x, z), z); sc.set(s, s, s);
        m.compose(p, q, sc);
        trunks.setMatrixAt(ti, m);
        // ring canopies live in the leafDeep band with a per-tree SPECIES shift, so the
        // tree line drifts olive/mustard/teal along its length instead of one repeated
        // green; fog still melts them into the horizon
        const sp = speciesShift();
        // wider species spread than before (deep/mid/lime picks) so the tree line
        // drifts teal->olive->sage along its length
        const rt = Math.random();
        const green = spC(rt < 0.6 ? PAL.leafDeep : rt < 0.9 ? PAL.leafMid : PAL.leafLime, sp, 0.06).convertSRGBToLinear();
        // atmospheric haze: desaturate + lift toward the fog/sky family with distance
        // so the far ring RECEDES instead of sitting saturated on the pale hills
        const hazeT = 0.16 + ((r - rMin) / Math.max(0.001, rMax - rMin)) * 0.3;
        green.lerp(hazeCol, hazeT);
        const tiers = [[1.15, 1.3, 1.15], [0.85, 1.15, 1.95], [0.52, 1.0, 2.7]];
        let tn = 0;
        for (const [tr, th, ty] of tiers) {
          e.set(0, baseRot + tn * 0.5, 0); q.setFromEuler(e); // staggered tier rotation
          p.set(x, terrainY(x, z) + ty * s, z); sc.set(tr * s, th * s, tr * s);
          m.compose(p, q, sc);
          cones.setMatrixAt(ci, m);
          // crown warms slightly (sun-from-above), never brightens into plastic
          cones.setColorAt(ci, col.copy(green).offsetHSL(-0.008 * tn, 0, tn * 0.012));
          ci++; tn++;
        }
        ti++;
      }
      trunks.count = ti; cones.count = ci;
      trunks.instanceMatrix.needsUpdate = true;
      cones.instanceMatrix.needsUpdate = true;
      if (cones.instanceColor) cones.instanceColor.needsUpdate = true;
      worldGroup.add(trunks, cones);
    }

    // ---- Distant mountains ----
    function addMountains(list) {
      list.forEach(([x, z, r, h, snow]) => {
        const mtn = new THREE.Mesh(new THREE.ConeGeometry(r, h, 7), flat(0x7d8a9c));
        mtn.position.set(x, h / 2 - 1, z);
        mtn.rotation.y = Math.random() * Math.PI;
        worldGroup.add(mtn);
        if (snow) {
          const cap = new THREE.Mesh(new THREE.ConeGeometry(r * 0.42, h * 0.34, 7), flat(0xf2f5f8));
          cap.position.set(x, h - h * 0.17 - 1, z);
          cap.rotation.y = mtn.rotation.y;
          worldGroup.add(cap);
        }
      });
    }

    // ---- Clouds ----
    let clouds = [];
    function addClouds(n) {
      const mat = flat(0xffffff, { emissive: 0xffffff, emissiveIntensity: 0.15, transparent: true, opacity: 0.94, roughness: 1 });
      for (let i = 0; i < n; i++) {
        const g = new THREE.Group();
        const puffs = 3 + Math.floor(Math.random() * 3);
        for (let j = 0; j < puffs; j++) {
          const s = 1.3 + Math.random() * 1.7;
          const puff = new THREE.Mesh(new THREE.IcosahedronGeometry(s, 0), mat);
          puff.position.set(j * 1.9 - puffs, Math.random() * 0.6, (Math.random() - 0.5) * 1.6);
          puff.scale.y = 0.5;
          g.add(puff);
        }
        g.position.set((Math.random() - 0.5) * 100, 18 + Math.random() * 8, (Math.random() - 0.5) * 100);
        g.userData.speed = 0.4 + Math.random() * 0.5;
        worldGroup.add(g); clouds.push(g);
      }
    }

    // ---- Sparkles ----
    let sparkles = null;
    function addSparkles(cx, cz, area, n = 60) {
      const positions = new Float32Array(n * 3);
      for (let i = 0; i < n; i++) {
        positions[i * 3] = cx + (Math.random() - 0.5) * area;
        positions[i * 3 + 1] = 0.3 + Math.random() * 2.4;
        positions[i * 3 + 2] = cz + (Math.random() - 0.5) * area;
      }
      const geo = new THREE.BufferGeometry();
      geo.setAttribute("position", new THREE.BufferAttribute(positions, 3));
      sparkles = new THREE.Points(geo, new THREE.PointsMaterial({
        color: SRGB(0xbdffe9), size: 0.14, transparent: true, opacity: 0.85,
        blending: THREE.AdditiveBlending, depthWrite: false,
      }));
      worldGroup.add(sparkles);
    }

    // ---- Player: chibi rig, fully outfit-driven for the wardrobe ----
    function makePlayer() {
      const o = G.outfit;
      // TWO skin materials, ONE color (applyOutfitTo keeps them in lockstep):
      // the face/neck use smooth shading so light breaks at anatomy instead
      // of random triangles (faceted skulls read as dirt/stubble patches at
      // gameplay distance), while hands/limbs keep the flat facet language.
      const skinMat = flat(o.skin, { roughness: 0.8 });
      const skinSmoothMat = smooth(o.skin, { roughness: 0.75 });
      const shirtMat = flat(o.shirt, { roughness: 0.75 });
      const collarMat = flat(o.shirt);
      collarMat.color.offsetHSL(0, 0, -0.08);
      const bootMat = flat(o.boots);
      const hairMat = flat(o.hair, { roughness: 0.85 });
      // open SHEET pieces (long-hair fall) get their own double-sided copy;
      // making ALL hair double-sided leaked bang backfaces through the
      // hood's face window from rear angles
      const hairMatDS = flat(o.hair, { roughness: 0.85 });
      hairMatDS.side = THREE.DoubleSide;
      const hoodMat = flat(o.shirt);
      hoodMat.color.offsetHSL(0, 0.02, -0.06);
      hoodMat.side = THREE.DoubleSide; // hood is an open shell too
      // fixed light trim — cuffs, collar edge, buttons, sole rims. Reads on
      // every shirt color and keeps dark outfits from going value-mush.
      const trimMat = flat(0xf2e6c8, { roughness: 0.6 });
      const beltMat = flat(0x4a3826, { roughness: 0.9 });
      const buckleMat = flat(0xd9a441, { roughness: 0.45, metalness: 0.25 });
      const pantMat = flat(0x6b5a3e, { roughness: 0.95 });

      const g = new THREE.Group();
      const body = new THREE.Group();
      body.position.y = 0.5;
      g.add(body);

      // -- hips / tucked-shirt torso / belt: the shirt tucks into pants so
      //    torso and legs read as separate masses (no more tube smock)
      const hips = new THREE.Mesh(new THREE.CylinderGeometry(0.235, 0.255, 0.17, 10), pantMat);
      hips.position.y = 0.065; hips.scale.z = 0.85; hips.castShadow = true;
      const belt = new THREE.Mesh(new THREE.CylinderGeometry(0.245, 0.25, 0.075, 10), beltMat);
      belt.position.y = 0.175; belt.scale.z = 0.85;
      const buckle = new THREE.Mesh(new THREE.BoxGeometry(0.075, 0.055, 0.02), buckleMat);
      buckle.position.set(0, 0.175, 0.216);
      const torsoProfile = [
        [0.25, 0.20], [0.235, 0.27], [0.215, 0.37], [0.24, 0.49],
        [0.255, 0.57], [0.21, 0.635], [0.115, 0.67],
      ];
      const torso = new THREE.Mesh(
        new THREE.LatheGeometry(torsoProfile.map(([r, y]) => new THREE.Vector2(r, y)), 12), shirtMat);
      torso.scale.z = 0.88; torso.castShadow = true;
      // collar: cream trim edge under a shirt-toned fold, plus a short neck
      const collarTrim = new THREE.Mesh(new THREE.CylinderGeometry(0.15, 0.185, 0.05, 9), trimMat);
      collarTrim.position.y = 0.655;
      const collar = new THREE.Mesh(new THREE.CylinderGeometry(0.135, 0.16, 0.06, 9), collarMat);
      collar.position.y = 0.695;
      // short skin neck — must poke visibly above the collar so the head
      // doesn't sit snowman-style on the shirt
      const neck = new THREE.Mesh(new THREE.CylinderGeometry(0.09, 0.112, 0.17, 9), skinSmoothMat);
      neck.position.y = 0.735;
      body.add(hips, belt, buckle, torso, neck);

      // -- outfit STYLE registry: five layered looks over the same torso.
      //    userData.styles{} — applyOutfitTo shows exactly one. The shirt
      //    color drives the torso + styleMat (a derived darker/warmer
      //    accent); overalls and vest carry fixed denim/leather fabrics so
      //    they read as workwear under any shirt pick.
      const styleMat = flat(o.shirt, { roughness: 0.85 });
      styleMat.color.offsetHSL(0.03, 0.04, -0.13);
      const denimMat = flat(0x3d5478, { roughness: 0.95 });
      const denimDark = flat(0x2f4260, { roughness: 0.95 });
      const leatherMat = flat(0x9a7648, { roughness: 0.9 });
      leatherMat.side = THREE.DoubleSide; // vest shell is open at the front
      const leatherDark = flat(0x7c5c34, { roughness: 0.9 });
      const styles = {};
      const mkStyleSet = (key) => { const s = new THREE.Group(); body.add(s); styles[key] = s; return s; };
      { // classic tee — collar fold, cream trim edge, buttons down the chest
        const s = mkStyleSet("tee");
        s.add(collarTrim, collar);
        [[0.545, 0.222], [0.44, 0.215], [0.335, 0.198]].forEach(([by, bz]) => {
          const btn = new THREE.Mesh(new THREE.CylinderGeometry(0.024, 0.024, 0.016, 6), trimMat);
          btn.rotation.x = Math.PI / 2; btn.position.set(0, by, bz);
          s.add(btn);
        });
      }
      { // overalls — denim waist + chest bib + brass buttons + patch pocket,
        // straps over the shoulders crossing at the back; shirt shows on the
        // torso and sleeves like a proper work outfit
        const s = mkStyleSet("overalls");
        s.add(collarTrim.clone(), collar.clone());
        // tall denim waist swallows the base belt so the overalls own the hip line
        const waist = new THREE.Mesh(new THREE.CylinderGeometry(0.252, 0.274, 0.3, 10), denimMat);
        waist.position.y = 0.2; waist.scale.z = 0.86; waist.castShadow = true;
        const bib = new THREE.Mesh(new THREE.BoxGeometry(0.27, 0.22, 0.05), denimMat);
        bib.position.set(0, 0.445, 0.2); bib.rotation.x = 0.1; bib.castShadow = true;
        const pocket = new THREE.Mesh(new THREE.BoxGeometry(0.155, 0.105, 0.022), denimDark);
        pocket.position.set(0, 0.415, 0.238); pocket.rotation.x = 0.1;
        const stitch = new THREE.Mesh(new THREE.BoxGeometry(0.27, 0.02, 0.024), trimMat);
        stitch.position.set(0, 0.548, 0.212); stitch.rotation.x = 0.1; // top hem of the bib
        s.add(waist, bib, pocket, stitch);
        [-1, 1].forEach((side) => {
          const strapF = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.26, 0.032), denimMat);
          strapF.position.set(0.095 * side, 0.605, 0.155); strapF.rotation.x = -0.34;
          // back straps: long slats from the waistband up over the shoulders,
          // proud of the torso so they read as straps, not stickers
          const strapB = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.4, 0.05), denimMat);
          strapB.position.set(0.08 * side, 0.5, -0.205);
          strapB.rotation.x = 0.24; strapB.rotation.z = side * 0.3; // crossed X at the back
          const brass = new THREE.Mesh(new THREE.CylinderGeometry(0.032, 0.032, 0.02, 6), buckleMat);
          brass.rotation.x = Math.PI / 2 + 0.1; brass.position.set(0.1 * side, 0.535, 0.235);
          s.add(strapF, strapB, brass);
        });
      }
      { // hoodie — ribbed collar + hem, kangaroo pouch, drawstrings, and the
        // hood draped down across the shoulder blades
        const s = mkStyleSet("hoodie");
        const rib = new THREE.Mesh(new THREE.CylinderGeometry(0.15, 0.185, 0.075, 9), styleMat);
        rib.position.y = 0.665;
        const hem = new THREE.Mesh(new THREE.CylinderGeometry(0.252, 0.268, 0.13, 10), styleMat);
        hem.position.y = 0.21; hem.scale.z = 0.86; // deep rib hem — covers the base belt/buckle
        const pouch = new THREE.Mesh(new THREE.BoxGeometry(0.235, 0.135, 0.055), styleMat);
        pouch.position.set(0, 0.325, 0.185); pouch.rotation.x = 0.14; pouch.castShadow = true;
        const hoodDown = new THREE.Mesh(
          new THREE.SphereGeometry(0.185, 10, 6, 0, Math.PI * 2, 0, Math.PI * 0.58), hoodMat);
        hoodDown.position.set(0, 0.6, -0.19); hoodDown.rotation.x = 2.45;
        hoodDown.scale.set(1.2, 0.85, 1); hoodDown.castShadow = true;
        s.add(rib, hem, pouch, hoodDown);
        [-1, 1].forEach((side) => {
          const cord = new THREE.Mesh(new THREE.CylinderGeometry(0.013, 0.013, 0.11, 5), trimMat);
          cord.position.set(0.055 * side, 0.565, 0.225); cord.rotation.x = 0.12;
          const aglet = new THREE.Mesh(new THREE.SphereGeometry(0.022, 5, 4), trimMat);
          aglet.position.set(0.055 * side, 0.505, 0.235);
          s.add(cord, aglet);
        });
      }
      { // raincoat — longer skirted hem swallowing the belt line, storm
        // placket with toggle clasps, flap collar; all in the shirt color
        // with the derived accent on trim so it reads as one waxed cloth
        const s = mkStyleSet("raincoat");
        const skirt = new THREE.Mesh(new THREE.CylinderGeometry(0.252, 0.318, 0.36, 10), shirtMat);
        skirt.position.y = 0.09; skirt.scale.z = 0.88; skirt.castShadow = true;
        const hemBand = new THREE.Mesh(new THREE.CylinderGeometry(0.318, 0.325, 0.05, 10), styleMat);
        hemBand.position.y = -0.065; hemBand.scale.z = 0.88;
        const placket = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.44, 0.028), styleMat);
        placket.position.set(0, 0.42, 0.208); placket.rotation.x = 0.06;
        const rainCollar = new THREE.Mesh(new THREE.CylinderGeometry(0.15, 0.19, 0.07, 9), styleMat);
        rainCollar.position.y = 0.665;
        s.add(skirt, hemBand, placket, rainCollar);
        [[0.55], [0.42], [0.29]].forEach(([ty]) => {
          const toggle = new THREE.Mesh(new THREE.CylinderGeometry(0.016, 0.016, 0.085, 5), buckleMat);
          toggle.rotation.z = Math.PI / 2; toggle.position.set(0, ty, 0.228);
          s.add(toggle);
        });
        [-1, 1].forEach((side) => {
          const flap = new THREE.Mesh(new THREE.BoxGeometry(0.11, 0.045, 0.1), styleMat);
          flap.position.set(0.085 * side, 0.645, 0.135);
          flap.rotation.set(-0.35, side * 0.35, side * -0.15);
          s.add(flap);
        });
      }
      { // adventurer vest — open tan-leather shell over the shirt, cargo
        // pockets with studs, lapel edges; belt + buckle below finish it
        const s = mkStyleSet("vest");
        s.add(collarTrim.clone(), collar.clone());
        const shell = new THREE.Mesh(
          new THREE.CylinderGeometry(0.242, 0.285, 0.37, 10, 1, true, 0.55, Math.PI * 2 - 1.1), leatherMat);
        shell.position.y = 0.43; shell.scale.z = 0.88; shell.castShadow = true;
        const yoke = new THREE.Mesh(
          new THREE.CylinderGeometry(0.2, 0.246, 0.06, 10, 1, true, 0.55, Math.PI * 2 - 1.1), leatherDark);
        yoke.position.y = 0.625; yoke.scale.z = 0.88;
        yoke.material.side = THREE.DoubleSide;
        s.add(shell, yoke);
        [-1, 1].forEach((side) => {
          const lapel = new THREE.Mesh(new THREE.BoxGeometry(0.05, 0.34, 0.055), leatherDark);
          lapel.position.set(0.145 * side, 0.44, 0.2);
          lapel.rotation.y = side * 0.6; lapel.rotation.x = 0.05;
          const pocket = new THREE.Mesh(new THREE.BoxGeometry(0.105, 0.095, 0.05), leatherDark);
          pocket.position.set(0.185 * side, 0.32, 0.19); pocket.rotation.y = side * 0.68;
          pocket.castShadow = true;
          const pflap = new THREE.Mesh(new THREE.BoxGeometry(0.11, 0.038, 0.055), leatherMat);
          pflap.position.set(0.185 * side, 0.375, 0.193); pflap.rotation.y = side * 0.68;
          const stud = new THREE.Mesh(new THREE.SphereGeometry(0.02, 5, 4), buckleMat);
          stud.position.set(0.19 * side, 0.352, 0.212); stud.rotation.y = side * 0.68;
          s.add(lapel, pocket, pflap, stud);
        });
      }

      // -- head — smooth-shaded sphere: the face is the one place the facet
      //    language hurts (random triangles across the jaw read as dirt at
      //    gameplay distance), so shading here breaks at anatomy — brow,
      //    cheek, jaw — while hats/hair/body stay faceted around it.
      //    Raised so a few px of neck always shows between chin and collar.
      const head = new THREE.Group();
      head.position.y = 0.92;
      body.add(head);
      const skull = new THREE.Mesh(new THREE.SphereGeometry(0.3, 16, 12), skinSmoothMat);
      skull.position.y = 0.13; skull.scale.set(1.05, 1.01, 0.97); skull.castShadow = true;
      head.add(skull);
      // ear nubs — smooth so they share the face's tone and shading
      const earL = new THREE.Mesh(new THREE.SphereGeometry(0.062, 8, 6), skinSmoothMat);
      earL.position.set(-0.3, 0.105, 0.015); earL.scale.set(0.5, 0.85, 0.68);
      earL.rotation.y = -0.3;
      const earR = earL.clone(); earR.position.x = 0.3; earR.rotation.y = 0.3;
      head.add(earL, earR);
      // eyes — cream sclera + dark iris + bright catchlight. The sclera
      // crescent is what keeps eyes from collapsing into black voids at
      // phone distance. Raised eye line so hat brims never cut the pupils.
      // Blink contract: eyeL/eyeR are the groups the frame loop scales in y.
      const scleraMat = smooth(0xfff4e2, { roughness: 0.5 });
      const irisMat = smooth(0x2a1a12, { roughness: 0.28 });
      const eyeL = new THREE.Group();
      eyeL.position.set(-0.124, 0.196, 0.242);
      eyeL.rotation.x = -0.24; // aim up at the high chase camera so the eye disc reads fully open, not a sleepy slit
      {
        const sclera = new THREE.Mesh(new THREE.SphereGeometry(0.074, 9, 7), scleraMat);
        sclera.scale.set(1, 1, 0.58);
        const iris = new THREE.Mesh(new THREE.SphereGeometry(0.053, 9, 7), irisMat);
        iris.position.set(0, -0.004, 0.026); iris.scale.set(1, 1, 0.6);
        const glint = new THREE.Mesh(new THREE.SphereGeometry(0.021, 6, 5),
          smooth(0xffffff, { roughness: 0.2, emissive: 0xffffff, emissiveIntensity: 0.7 }));
        glint.position.set(0.018, 0.018, 0.052);
        eyeL.add(sclera, iris, glint);
      }
      const eyeR = eyeL.clone(); eyeR.position.x = 0.124;
      // brows — thin hair-colored slats with a friendly outward tilt,
      // lifted clear of the bigger eyes
      const browL = new THREE.Mesh(new THREE.BoxGeometry(0.1, 0.022, 0.024), hairMat);
      browL.position.set(-0.124, 0.295, 0.235); browL.rotation.set(-0.3, 0, 0.14);
      const browR = browL.clone(); browR.position.x = 0.124; browR.rotation.z = -0.14;
      const nose = new THREE.Mesh(new THREE.ConeGeometry(0.03, 0.06, 5), skinSmoothMat);
      nose.rotation.x = Math.PI / 2; nose.position.set(0, 0.125, 0.3);
      const mouth = new THREE.Mesh(new THREE.TorusGeometry(0.054, 0.0135, 4, 9, Math.PI * 0.78), flat(0x7a3d30));
      mouth.rotation.set(-0.24, 0, Math.PI * 1.11);
      mouth.position.set(0, 0.058, 0.276);
      const blushMat = smooth(0xe89a7a, { roughness: 1 });
      blushMat.transparent = true; blushMat.opacity = 0.5;
      const blushL = new THREE.Mesh(new THREE.SphereGeometry(0.048, 6, 4), blushMat);
      blushL.position.set(-0.182, 0.09, 0.228); blushL.scale.set(1, 0.6, 0.42);
      const blushR = blushL.clone(); blushR.position.x = 0.182;
      head.add(eyeL, eyeR, browL, browR, nose, mouth, blushL, blushR);

      // (the old always-visible hair layer — fringe torus, spikes, tufts,
      // sideburns, nape shell — is gone: it ignored the hat/style registry
      // and poked through hoods. Under-hat framing now lives in each
      // style's fringePart.)

      // 3) hairstyle registry — one group per style; applyOutfitTo shows the
      //    picked one and repoints userData.hairMesh at it. Every style is
      //    split into userData.crownPart (the top mass — hidden under any
      //    solid hat) and userData.tailPart (below-the-hat-line mass —
      //    ponytails, curls at the nape, long sheets — hidden only by the
      //    hood), so hats compress hair sensibly instead of deleting it.
      const hairSheenMat = flat(0x7a5638, { roughness: 0.55 });
      hairSheenMat.side = THREE.DoubleSide;
      const hairStyles = {};
      const mkStyle = (key) => {
        const s = new THREE.Group();
        const crownPart = new THREE.Group();
        const tailPart = new THREE.Group();
        const fringePart = new THREE.Group();
        s.add(crownPart, tailPart, fringePart);
        s.userData.crownPart = crownPart;
        s.userData.tailPart = tailPart;
        s.userData.fringePart = fringePart;
        // shared under-hat fringe: a shallow bang band across the brow plus
        // two temple tufts — shown ONLY when a solid hat hides the crown, so
        // hooded/hatted heads keep framed faces instead of going bald
        const OPEN = 1.6;
        // sized well INSIDE the hood/hat shells (r 0.345+) so no facet can
        // poke through them at any head yaw — visible only via the face window
        const bang = new THREE.Mesh(
          new THREE.SphereGeometry(0.316, 12, 3, Math.PI / 2 - OPEN * 0.34, OPEN * 0.68, Math.PI * 0.30, Math.PI * 0.13), hairMat);
        bang.position.y = 0.135; bang.scale.set(0.99, 1, 0.97);
        fringePart.add(bang);
        [-1, 1].forEach((side) => {
          const tuft = new THREE.Mesh(new THREE.DodecahedronGeometry(0.058, 0), hairMat);
          tuft.position.set(0.222 * side, 0.09, 0.17);
          tuft.rotation.set(0.2, side * 0.6, 0);
          tuft.scale.set(0.65, 1.1, 0.7);
          fringePart.add(tuft);
        });
        head.add(s);
        hairStyles[key] = s;
        return { crownPart, tailPart, fringePart };
      };
      // shared faceted bowl: a full cap over the crown (no scalp shows from
      // above) + a phi-cut band that leaves a window for the face
      const mkBowl = (sc = 1.03) => {
        const b = new THREE.Group();
        const OPEN = 1.6; // radians of face-window opening
        const capTop = new THREE.Mesh(
          new THREE.SphereGeometry(0.328, 12, 4, 0, Math.PI * 2, 0, Math.PI * 0.3), hairMat);
        const band = new THREE.Mesh(
          new THREE.SphereGeometry(0.328, 12, 5, Math.PI / 2 + OPEN / 2, Math.PI * 2 - OPEN, Math.PI * 0.3, Math.PI * 0.33), hairMat);
        capTop.position.y = 0.135; capTop.scale.set(sc, 1, sc - 0.03);
        band.position.y = 0.135; band.scale.set(sc, 1, sc - 0.03);
        capTop.castShadow = true;
        b.add(capTop, band);
        return b;
      };
      // sheen band: keeps dark hair from rendering as an unlit void
      const mkSheen = () => {
        const sheen = new THREE.Mesh(
          new THREE.SphereGeometry(0.337, 12, 2, -0.6, 2.5, Math.PI * 0.15, Math.PI * 0.15), hairSheenMat);
        sheen.position.y = 0.135; sheen.scale.set(1.03, 1, 1.0);
        return sheen;
      };
      const mkClump = (parent, cx, cy, cz, cr, ry, sx = 1, sy = 0.82, sz = 0.9) => {
        const clump = new THREE.Mesh(new THREE.DodecahedronGeometry(cr, 0), hairMat);
        clump.position.set(cx, cy, cz); clump.rotation.set(0.3, ry, 0.2);
        clump.scale.set(sx, sy, sz); clump.castShadow = true;
        parent.add(clump);
        return clump;
      };
      { // crop — the classic messy bowl, chunky faceted clumps on top
        const { crownPart } = mkStyle("crop");
        crownPart.add(mkBowl(), mkSheen());
        mkClump(crownPart, 0.12, 0.44, 0.03, 0.125, 0.5);
        mkClump(crownPart, -0.22, 0.38, -0.09, 0.11, -0.4);
        mkClump(crownPart, 0.05, 0.34, -0.26, 0.12, 2.6);
      }
      { // side part — bowl combed hard to one side, big sweep over the brow
        const { crownPart } = mkStyle("side");
        crownPart.add(mkBowl(1.04), mkSheen());
        const sweep = mkClump(crownPart, 0.1, 0.385, 0.155, 0.155, 0.35, 1.45, 0.52, 0.95);
        sweep.rotation.set(0.42, 0.3, -0.3);
        const sweep2 = mkClump(crownPart, -0.17, 0.4, 0.06, 0.12, -0.3, 0.9, 0.5, 0.8);
        sweep2.rotation.set(0.25, -0.25, 0.25);
        mkClump(crownPart, -0.05, 0.35, -0.24, 0.115, 2.9);
      }
      { // curls — icosa cloud hugging the crown, a few peeking at the nape
        const { crownPart, tailPart } = mkStyle("curls");
        const curl = (parent, cx, cy, cz, cr) => {
          const c = new THREE.Mesh(new THREE.IcosahedronGeometry(cr, 0), hairMat);
          c.position.set(cx, cy, cz);
          c.rotation.set(cx * 7, cy * 9, cz * 5); // deterministic pseudo-random spin
          c.castShadow = true;
          parent.add(c);
        };
        [[0, 0.44, 0.02, 0.155], [0.19, 0.4, 0.13, 0.125], [-0.19, 0.4, 0.13, 0.125],
         [0.26, 0.34, -0.06, 0.125], [-0.26, 0.34, -0.06, 0.125],
         [0.16, 0.37, -0.22, 0.12], [-0.16, 0.37, -0.22, 0.12], [0, 0.4, -0.2, 0.13],
         [0.27, 0.18, -0.14, 0.11], [-0.27, 0.18, -0.14, 0.11],
        ].forEach(([cx, cy, cz, cr]) => curl(crownPart, cx, cy, cz, cr));
        // nape curls survive under hats — hair still peeks below a beanie
        [[0.16, 0.03, -0.24, 0.095], [-0.16, 0.03, -0.24, 0.095], [0, 0.0, -0.28, 0.1]]
          .forEach(([cx, cy, cz, cr]) => curl(tailPart, cx, cy, cz, cr));
      }
      { // ponytail — bowl + tied tail that survives (and pokes under) hats
        const { crownPart, tailPart } = mkStyle("pony");
        crownPart.add(mkBowl(), mkSheen());
        mkClump(crownPart, 0.17, 0.42, 0.06, 0.115, 0.5);
        const puff = new THREE.Mesh(new THREE.IcosahedronGeometry(0.115, 0), hairMat);
        puff.position.set(0, 0.17, -0.33); puff.scale.set(1, 0.92, 0.95);
        puff.castShadow = true;
        const tie = new THREE.Mesh(new THREE.CylinderGeometry(0.065, 0.072, 0.055, 6), trimMat);
        tie.position.set(0, 0.075, -0.355); tie.rotation.x = 0.35;
        const tail = new THREE.Mesh(new THREE.ConeGeometry(0.105, 0.42, 6), hairMat);
        tail.position.set(0, -0.1, -0.385); tail.rotation.x = Math.PI - 0.18;
        tail.castShadow = true;
        const tip = new THREE.Mesh(new THREE.IcosahedronGeometry(0.07, 0), hairMat);
        tip.position.set(0, -0.29, -0.41); tip.scale.set(0.85, 1.1, 0.85);
        tailPart.add(tie, puff, tail, tip);
      }
      { // twin buns — bowl + two tied buns riding high on the sides
        const { crownPart } = mkStyle("buns");
        crownPart.add(mkBowl(), mkSheen());
        [-1, 1].forEach((side) => {
          const bun = new THREE.Mesh(new THREE.IcosahedronGeometry(0.125, 0), hairMat);
          bun.position.set(0.235 * side, 0.45, -0.05);
          bun.rotation.set(0.4, side * 0.8, 0);
          bun.scale.set(1, 0.92, 1); bun.castShadow = true;
          const tie = new THREE.Mesh(new THREE.TorusGeometry(0.062, 0.02, 4, 8), trimMat);
          tie.position.set(0.225 * side, 0.365, -0.045);
          tie.rotation.set(0.5, 0, side * -0.5);
          crownPart.add(bun, tie);
        });
      }
      { // long — bowl + a back sheet down to the shoulders + face curtains
        const { crownPart, tailPart } = mkStyle("long");
        crownPart.add(mkBowl(1.04), mkSheen());
        mkClump(crownPart, 0.14, 0.43, 0.02, 0.12, 0.5);
        // wider wrap: the sheet's side edges reach forward past the ears so
        // the face curtains continue it instead of floating detached
        const sheet = new THREE.Mesh(
          new THREE.CylinderGeometry(0.325, 0.375, 0.5, 12, 1, true, Math.PI * 0.45, Math.PI * 1.1), hairMatDS);
        sheet.position.set(0, -0.04, -0.02); sheet.scale.z = 0.94;
        sheet.castShadow = true;
        tailPart.add(sheet);
        // stepped hem: longer strand panels cut from the SAME cylinder
        // surface as the sheet (identical radius/curvature/normals), so they
        // shade continuously with it — chunky steps, never detached teeth
        [ { start: 0.86, len: 0.28, drop: 0.14 },
          { start: 1.22, len: 0.24, drop: 0.09 },
          { start: 0.58, len: 0.24, drop: 0.09 } ].forEach((seg) => {
          const panel = new THREE.Mesh(
            new THREE.CylinderGeometry(0.372, 0.362, 0.2, 12, 1, true, Math.PI * seg.start, Math.PI * seg.len), hairMatDS);
          panel.position.set(0, -0.19 - seg.drop, -0.02);
          panel.scale.z = 0.94;
          panel.castShadow = true;
          tailPart.add(panel);
        });
        // front curtains: thick falls that tuck up under the bowl band and
        // hug the head, continuing the sheet's side edges past the ears
        [-1, 1].forEach((side) => {
          const curtain = new THREE.Mesh(new THREE.DodecahedronGeometry(0.11, 0), hairMat);
          curtain.position.set(0.272 * side, 0.03, 0.1);
          curtain.rotation.set(0.08, side * 0.28, side * -0.08);
          curtain.scale.set(0.78, 2.0, 0.95); curtain.castShadow = true;
          tailPart.add(curtain);
          // taper each curtain to a point so the fall ends like the hem does
          const cTip = new THREE.Mesh(new THREE.ConeGeometry(0.062, 0.15, 4), hairMat);
          cTip.position.set(0.272 * side, -0.235, 0.1);
          cTip.rotation.x = Math.PI;
          tailPart.add(cTip);
        });
      }
      // contract: hairMesh points at the ACTIVE style group (applyOutfitTo
      // repoints it whenever the style changes)
      let hairMesh = hairStyles.crop;

      // -- hat bobber carries every hat variant; wardrobe toggles visibility
      const hatG = new THREE.Group();
      hatG.position.y = 0.325;
      head.add(hatG);
      const hatVariants = {};
      {
        const hv = new THREE.Group(); // straw — seats on the head, tipped back
        hv.position.y = 0.01;
        hv.rotation.x = -0.09; // brim up in front: both eyes read fully under it
        const brim = new THREE.Mesh(new THREE.CylinderGeometry(0.46, 0.5, 0.06, 10), flat(0xe0b354, { roughness: 0.95 }));
        brim.castShadow = true;
        const crown = new THREE.Mesh(new THREE.CylinderGeometry(0.21, 0.29, 0.22, 9), flat(0xd9a441, { roughness: 0.95 }));
        crown.position.y = 0.13;
        const band = new THREE.Mesh(new THREE.CylinderGeometry(0.302, 0.308, 0.075, 9), flat(0xb5432f));
        band.position.y = 0.055;
        // dark translucent skirt under the brim — fakes the contact shadow
        // where hat meets hair, killing the floating-brim gap
        const contactMat = flat(0x1a1410, { roughness: 1 });
        contactMat.transparent = true; contactMat.opacity = 0.24;
        const contact = new THREE.Mesh(new THREE.CylinderGeometry(0.3, 0.335, 0.05, 10, 1, true), contactMat);
        contact.position.y = -0.038;
        hv.add(brim, crown, band, contact);
        hatG.add(hv); hatVariants.straw = hv;
      }
      {
        const hv = new THREE.Group(); // beanie — sits high, tipped back off the brow
        hv.rotation.x = -0.08;
        const dome = new THREE.Mesh(new THREE.SphereGeometry(0.31, 10, 7, 0, Math.PI * 2, 0, Math.PI / 2), flat(0xb5432f, { roughness: 0.95 }));
        dome.position.y = -0.038; dome.castShadow = true;
        const fold = new THREE.Mesh(new THREE.TorusGeometry(0.29, 0.05, 6, 12), flat(0x8a2f24));
        fold.rotation.x = Math.PI / 2; fold.position.y = -0.014;
        const pom = new THREE.Mesh(new THREE.SphereGeometry(0.07, 7, 6), flat(0xf0e0c0));
        pom.position.y = 0.29;
        hv.add(dome, fold, pom);
        hatG.add(hv); hatVariants.beanie = hv;
      }
      // (the hood hat was cut from the roster — old saves fall back to none)
      {
        const hv = new THREE.Group(); // flower crown — rides atop the clumpy hair
        hv.position.y = 0.12;
        const ring = new THREE.Mesh(new THREE.TorusGeometry(0.285, 0.035, 6, 14), flat(0x3f8f3f));
        ring.rotation.x = Math.PI / 2; ring.position.y = 0.02;
        hv.add(ring);
        for (let i = 0; i < 6; i++) {
          const a = (i / 6) * Math.PI * 2;
          const fc = [0xff7ab8, 0xffd24a, 0xffffff][i % 3];
          const fl = new THREE.Mesh(new THREE.SphereGeometry(0.05, 6, 5), flat(fc, { emissive: fc, emissiveIntensity: 0.2 }));
          fl.position.set(Math.cos(a) * 0.285, 0.04, Math.sin(a) * 0.285);
          hv.add(fl);
        }
        hatG.add(hv); hatVariants.crown = hv;
      }
      {
        const hv = new THREE.Group(); // flat cap — low tweed dome + stubby front brim
        hv.position.y = -0.012;
        hv.rotation.x = -0.07;
        const capMat = flat(0x77804e, { roughness: 0.95 });
        const capDark = flat(0x596340, { roughness: 0.95 });
        const dome = new THREE.Mesh(
          new THREE.SphereGeometry(0.34, 10, 6, 0, Math.PI * 2, 0, Math.PI * 0.52), capMat);
        dome.scale.set(1.02, 0.6, 1.1); dome.rotation.x = 0.09; dome.castShadow = true;
        const btnc = new THREE.Mesh(new THREE.SphereGeometry(0.045, 6, 4), capDark);
        btnc.position.y = 0.2;
        const band = new THREE.Mesh(new THREE.CylinderGeometry(0.318, 0.33, 0.09, 10), capDark);
        band.position.y = -0.045; band.scale.z = 0.98;
        const brim = new THREE.Mesh(new THREE.CylinderGeometry(0.17, 0.19, 0.032, 8), capDark);
        brim.position.set(0, -0.06, 0.28); brim.scale.set(1.6, 1, 1); brim.rotation.x = 0.1;
        hv.add(dome, btnc, band, brim);
        hatG.add(hv); hatVariants.cap = hv;
      }
      {
        const hv = new THREE.Group(); // bucket hat — canvas crown + sloped brim
        hv.position.y = 0.005;
        hv.rotation.x = -0.15; // front brim tipped UP: eyes + blush stay visible from the chase cam
        const bkMat = flat(0xd9c9a0, { roughness: 0.95 });
        bkMat.side = THREE.DoubleSide; // brim is an open shell
        const bkBand = flat(0xc9705a, { roughness: 0.9 });
        const crown = new THREE.Mesh(new THREE.CylinderGeometry(0.245, 0.3, 0.21, 10), bkMat);
        crown.position.y = 0.09; crown.castShadow = true;
        const band = new THREE.Mesh(new THREE.CylinderGeometry(0.297, 0.306, 0.07, 10), bkBand);
        band.position.y = 0.025;
        const brim = new THREE.Mesh(new THREE.CylinderGeometry(0.3, 0.415, 0.1, 10, 1, true), bkMat);
        brim.position.y = -0.068; brim.castShadow = true;
        const contactMatB = flat(0x1a1410, { roughness: 1 });
        contactMatB.transparent = true; contactMatB.opacity = 0.24;
        const contact = new THREE.Mesh(new THREE.CylinderGeometry(0.29, 0.325, 0.05, 10, 1, true), contactMatB);
        contact.position.y = -0.085;
        hv.add(crown, band, brim, contact);
        hatG.add(hv); hatVariants.bucket = hv;
      }
      {
        const hv = new THREE.Group(); // toadstool cap — red dome, cream gills, white spots
        hv.position.y = -0.012;
        hv.rotation.x = -0.06;
        const mCap = flat(0xd4523a, { roughness: 0.85 });
        mCap.side = THREE.DoubleSide;
        const cap = new THREE.Mesh(
          new THREE.SphereGeometry(0.42, 11, 6, 0, Math.PI * 2, 0, Math.PI * 0.55), mCap);
        cap.scale.set(1, 0.74, 1); cap.castShadow = true;
        const gills = new THREE.Mesh(new THREE.TorusGeometry(0.39, 0.05, 5, 12), flat(0xf0e2c4, { roughness: 0.95 }));
        gills.rotation.x = Math.PI / 2; gills.position.y = -0.005;
        const spotMat = flat(0xf6efe2, { roughness: 0.9 });
        [[0, 0.29, 0.08, 0.085], [0.24, 0.17, 0.19, 0.065], [-0.28, 0.15, -0.08, 0.07],
         [0.1, 0.2, -0.27, 0.06], [-0.08, 0.27, 0.16, 0.045]].forEach(([sx2, sy2, sz2, sr]) => {
          const spot = new THREE.Mesh(new THREE.SphereGeometry(sr, 6, 4), spotMat);
          spot.position.set(sx2, sy2, sz2);
          // aim local +z along the cap normal, then squash z so spots hug the dome
          spot.lookAt(sx2 * 3, sy2 * 3 + 0.4, sz2 * 3);
          spot.scale.z = 0.45;
          hv.add(spot);
        });
        const contactMatM = flat(0x1a1410, { roughness: 1 });
        contactMatM.transparent = true; contactMatM.opacity = 0.24;
        const contact = new THREE.Mesh(new THREE.CylinderGeometry(0.29, 0.335, 0.055, 10, 1, true), contactMatM);
        contact.position.y = -0.035;
        hv.add(cap, gills, contact);
        hatG.add(hv); hatVariants.shroom = hv;
      }

      // -- arms: shoulder cap + sleeve + trim cuff, then a lower-arm group
      //    with a static elbow bend (frame loop swings the whole arm on
      //    rotation.x; the bend and A-pose tilt survive because they live on
      //    the group's z and the child's x)
      const mkArm = (side) => {
        const a = new THREE.Group();
        a.position.set(0.295 * side, 0.60, 0);
        a.rotation.z = side * 0.26; // relaxed A-pose: daylight between arm and torso
        const cap = new THREE.Mesh(new THREE.SphereGeometry(0.105, 7, 6), shirtMat);
        cap.scale.set(1, 0.88, 1); cap.castShadow = true;
        const sleeve = new THREE.Mesh(new THREE.CylinderGeometry(0.094, 0.08, 0.17, 7), shirtMat);
        sleeve.position.y = -0.11; sleeve.castShadow = true;
        const lower = new THREE.Group();
        lower.position.y = -0.21;
        lower.rotation.x = -0.42;       // permanent elbow bend, hands rest forward
        lower.rotation.z = -side * 0.14; // forearm angles back in so hands land by the thighs
        // full-length sleeve: the forearm stays shirt-colored down to a
        // cream wrist cuff, so only the mitt reads as skin (no pale pipes)
        const fore = new THREE.Mesh(new THREE.CylinderGeometry(0.076, 0.062, 0.13, 7), shirtMat);
        fore.position.y = -0.06; fore.castShadow = true;
        // slimmer cream cuff — a value tick, not a white bracelet that
        // merges with pale skin into one slab
        const cuff = new THREE.Mesh(new THREE.CylinderGeometry(0.063, 0.068, 0.034, 7), trimMat);
        cuff.position.y = -0.13;
        // mitt hand — chunky palm + four stubby fingers + a fat thumb wedge.
        // The whole mitt is turned so the palm faces the thigh (no more
        // splayed palm-back paddles) and bent forward at the wrist. Scaled
        // up as a group so the finger stagger reads at gameplay distance.
        const hand = new THREE.Group();
        hand.position.y = -0.18;
        hand.rotation.x = 0.36;
        hand.rotation.y = side * 1.25; // palm in toward the leg
        hand.scale.setScalar(1.28);    // cartoon-mitt chunk — reads from the chase cam
        const palm = new THREE.Mesh(new THREE.BoxGeometry(0.125, 0.115, 0.098), skinMat);
        palm.position.y = -0.045; palm.castShadow = true;
        for (let fi = 0; fi < 4; fi++) {
          const flen = [0.052, 0.072, 0.066, 0.046][fi]; // index..pinky stagger
          const fg = new THREE.Mesh(new THREE.BoxGeometry(0.033, flen, 0.086), skinMat);
          fg.position.set((-0.0465 + fi * 0.031) * side, -0.098 - flen / 2 + 0.014, 0);
          fg.rotation.x = 0.17; fg.rotation.z = (fi - 1.5) * 0.06 * side;
          fg.castShadow = true;
          hand.add(fg);
        }
        const thumb = new THREE.Mesh(new THREE.BoxGeometry(0.056, 0.1, 0.06), skinMat);
        thumb.position.set(-0.08 * side, -0.035, 0.032);
        thumb.rotation.z = side * 0.5; thumb.rotation.x = 0.3;
        thumb.castShadow = true;
        hand.add(palm, thumb);
        lower.add(fore, cuff, hand);
        a.add(cap, sleeve, lower);
        a.userData.lower = lower;
        body.add(a);
        return a;
      };
      const armR = mkArm(1), armL = mkArm(-1);

      // -- legs: ~15% longer than the old rig; knee implied by the
      //    thigh->shin taper; boots get a cuff, rounded toe, and a light
      //    sole rim so they separate from the pants at any boot color
      const mkLeg = (side) => {
        const l = new THREE.Group();
        l.position.set(0.13 * side, 0.08, 0);
        const thigh = new THREE.Mesh(new THREE.CylinderGeometry(0.104, 0.088, 0.22, 7), pantMat);
        thigh.position.y = -0.1; thigh.castShadow = true;
        // calves carry real mass — the leg reads as leg, not a tapered stick
        const shin = new THREE.Mesh(new THREE.CylinderGeometry(0.086, 0.066, 0.19, 7), pantMat);
        shin.position.y = -0.29; shin.castShadow = true;
        // cream sock line between pant and boot — value break that reads on
        // any pant/boot color combo, then a chunky overhanging boot cuff
        const sock = new THREE.Mesh(new THREE.CylinderGeometry(0.072, 0.068, 0.035, 7), trimMat);
        sock.position.y = -0.345;
        const bcuff = new THREE.Mesh(new THREE.CylinderGeometry(0.107, 0.09, 0.085, 7), bootMat);
        bcuff.position.y = -0.4; bcuff.castShadow = true;
        // boot body + distinct heel block + kicked-up toe wedge: three
        // masses so ground contact reads on the stepping stones
        const foot = new THREE.Mesh(new THREE.SphereGeometry(0.096, 7, 5), bootMat);
        foot.position.set(0, -0.458, 0.045); foot.scale.set(1.02, 0.62, 1.5); foot.castShadow = true;
        const heel = new THREE.Mesh(new THREE.BoxGeometry(0.15, 0.08, 0.105), bootMat);
        heel.position.set(0, -0.478, -0.06); heel.castShadow = true;
        const toe = new THREE.Mesh(new THREE.BoxGeometry(0.13, 0.08, 0.1), bootMat);
        toe.position.set(0, -0.483, 0.155); toe.rotation.x = 0.3; toe.castShadow = true;
        const sole = new THREE.Mesh(new THREE.BoxGeometry(0.168, 0.034, 0.315), trimMat);
        sole.position.set(0, -0.513, 0.05);
        l.add(thigh, shin, sock, bcuff, foot, heel, toe, sole);
        body.add(l);
        return l;
      };
      const legR = mkLeg(1), legL = mkLeg(-1);

      // -- accessories — one visible at a time
      const acc = {};
      {
        const basketG = new THREE.Group(); // woven back-basket with straps
        const basket = new THREE.Mesh(new THREE.CylinderGeometry(0.175, 0.14, 0.3, 7), flat(0xb5854a));
        basket.position.set(0, 0.42, -0.34); basket.castShadow = true;
        const basketRim = new THREE.Mesh(new THREE.TorusGeometry(0.165, 0.032, 5, 8), flat(0x8a5f2e));
        basketRim.rotation.x = Math.PI / 2; basketRim.position.set(0, 0.575, -0.34);
        const bandR = new THREE.Mesh(new THREE.TorusGeometry(0.16, 0.022, 4, 8), flat(0x8a5f2e));
        bandR.rotation.x = Math.PI / 2; bandR.position.set(0, 0.36, -0.343);
        const strapL = new THREE.Mesh(new THREE.BoxGeometry(0.055, 0.4, 0.03), beltMat);
        strapL.position.set(-0.14, 0.5, -0.09); strapL.rotation.x = -0.45;
        const strapR = strapL.clone(); strapR.position.x = 0.14;
        basketG.add(basket, basketRim, bandR, strapL, strapR);
        body.add(basketG); acc.basket = basketG;
      }
      {
        const stickG = new THREE.Group(); // rides the lower arm, follows the elbow
        const staff = new THREE.Mesh(new THREE.CylinderGeometry(0.035, 0.045, 0.95, 6), flat(0x6e4a2c));
        staff.position.y = -0.28;
        const knob = new THREE.Mesh(new THREE.SphereGeometry(0.06, 7, 6), flat(0x8a5f2e));
        knob.position.y = 0.2;
        stickG.add(staff, knob);
        stickG.position.set(0.03, -0.185, 0.02);
        stickG.rotation.x = 0.42; // counter the elbow bend so it hangs plumb-ish
        stickG.rotation.z = -0.12;
        armR.userData.lower.add(stickG); acc.stick = stickG;
      }
      {
        const scarfG = new THREE.Group(); // chunky loop + a draped tail down the back
        const scarfMat = flat(0xe0862f, { roughness: 0.9 });
        const loop = new THREE.Mesh(new THREE.TorusGeometry(0.2, 0.062, 6, 12), scarfMat);
        loop.rotation.x = Math.PI / 2; loop.position.y = 0.66; loop.scale.z = 0.9;
        // tail as three chained segments: a knot anchoring it to the
        // shoulder, an upper drop hugging the back, then a gravity kink
        // that drifts sideways before the cream tip — cloth, not a plank
        const knot = new THREE.Mesh(new THREE.BoxGeometry(0.115, 0.105, 0.08), scarfMat);
        knot.position.set(0.115, 0.615, -0.175); knot.rotation.set(0.3, 0.15, -0.2);
        knot.castShadow = true;
        const tail = new THREE.Mesh(new THREE.BoxGeometry(0.115, 0.24, 0.045), scarfMat);
        tail.position.set(0.115, 0.475, -0.235); tail.rotation.set(0.14, 0, -0.06);
        tail.castShadow = true;
        const tailKink = new THREE.Mesh(new THREE.BoxGeometry(0.11, 0.17, 0.042), scarfMat);
        tailKink.position.set(0.15, 0.3, -0.255); tailKink.rotation.set(-0.1, 0, -0.28);
        tailKink.castShadow = true;
        const tailTip = new THREE.Mesh(new THREE.BoxGeometry(0.112, 0.08, 0.044), trimMat);
        tailTip.position.set(0.175, 0.19, -0.245); tailTip.rotation.set(-0.16, 0, -0.34);
        scarfG.add(loop, knot, tail, tailKink, tailTip);
        body.add(scarfG); acc.scarf = scarfG;
      }
      {
        const glassesG = new THREE.Group(); // round amber specs — ride the head
        const rimMat = flat(0x9a6a2e, { roughness: 0.4, metalness: 0.25 });
        [-1, 1].forEach((side) => {
          const rim = new THREE.Mesh(new THREE.TorusGeometry(0.082, 0.015, 5, 12), rimMat);
          rim.position.set(0.122 * side, 0.185, 0.3);
          glassesG.add(rim);
          const temple = new THREE.Mesh(new THREE.BoxGeometry(0.015, 0.015, 0.29), rimMat);
          temple.position.set(0.255 * side, 0.19, 0.165);
          temple.rotation.y = side * 2.75;
          glassesG.add(temple);
        });
        const bridge = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.017, 0.017), rimMat);
        bridge.position.set(0, 0.205, 0.3);
        glassesG.add(bridge);
        head.add(glassesG); acc.glasses = glassesG;
      }
      {
        const packG = new THREE.Group(); // camper backpack + bedroll
        const packMat = flat(0x5d7a43, { roughness: 0.95 });
        const packDark = flat(0x47603a, { roughness: 0.95 });
        const main = new THREE.Mesh(new THREE.BoxGeometry(0.3, 0.34, 0.15), packMat);
        main.position.set(0, 0.42, -0.3); main.castShadow = true;
        const flap = new THREE.Mesh(new THREE.BoxGeometry(0.31, 0.13, 0.16), packDark);
        flap.position.set(0, 0.535, -0.3); flap.rotation.x = 0.08;
        const clasp = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.11, 0.02), trimMat);
        clasp.position.set(0, 0.475, -0.383);
        const pocket = new THREE.Mesh(new THREE.BoxGeometry(0.19, 0.14, 0.05), packDark);
        pocket.position.set(0, 0.325, -0.385);
        const bedroll = new THREE.Mesh(new THREE.CylinderGeometry(0.055, 0.055, 0.34, 7), trimMat);
        bedroll.rotation.z = Math.PI / 2; bedroll.position.set(0, 0.63, -0.29);
        const strapL = new THREE.Mesh(new THREE.BoxGeometry(0.055, 0.4, 0.03), beltMat);
        strapL.position.set(-0.14, 0.5, -0.09); strapL.rotation.x = -0.45;
        const strapR = strapL.clone(); strapR.position.x = 0.14;
        packG.add(main, flap, clasp, pocket, bedroll, strapL, strapR);
        body.add(packG); acc.pack = packG;
      }
      {
        const satchelG = new THREE.Group(); // cross-body leather satchel
        const satMat = flat(0x8a5f2e, { roughness: 0.9 });
        // strap: right shoulder -> left hip, one slat on the chest + one on the back
        const strapF = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.56, 0.022), beltMat);
        strapF.position.set(-0.02, 0.42, 0.23); strapF.rotation.z = 0.68;
        const strapB = strapF.clone(); strapB.position.z = -0.23;
        const shoulder = new THREE.Mesh(new THREE.BoxGeometry(0.065, 0.035, 0.42), beltMat);
        shoulder.position.set(0.2, 0.63, 0); shoulder.rotation.z = -0.25;
        const bag = new THREE.Mesh(new THREE.BoxGeometry(0.22, 0.18, 0.11), satMat);
        bag.position.set(-0.26, 0.16, 0.12); bag.rotation.y = 0.32; bag.rotation.z = 0.08;
        bag.castShadow = true;
        const bagFlap = new THREE.Mesh(new THREE.BoxGeometry(0.23, 0.095, 0.12), flat(0x6e4a24, { roughness: 0.9 }));
        bagFlap.position.set(-0.26, 0.22, 0.12); bagFlap.rotation.y = 0.32; bagFlap.rotation.z = 0.08;
        const stud = new THREE.Mesh(new THREE.SphereGeometry(0.024, 5, 4), buckleMat);
        stud.position.set(-0.235, 0.16, 0.185);
        satchelG.add(strapF, strapB, shoulder, bag, bagFlap, stud);
        body.add(satchelG); acc.satchel = satchelG;
      }
      acc.none = new THREE.Group();
      body.add(acc.none);

      g.userData = {
        body, head, hatG, hatBaseY: 0.325, hatBaseY0: 0.325, armL, armR, legL, legR, eyeL, eyeR,
        blinkT: 2, blinkD: 0, idleT: 0, lookT: 0, lookDir: 0,
        skinMat, skinSmoothMat, shirtMat, collarMat, bootMat, hairMat, hairMatDS, hoodMat, hairMesh, hairStyles, hatVariants, acc,
        blushMat, hairSheenMat, styleMat, styles,
      };
      // opt every mesh into layer 2 — the character-rim-light layer — so
      // player rigs (local + remote) get the back light the world doesn't
      g.traverse((ob) => { if (ob.isMesh) ob.layers.enable(2); });
      return g;
    }

    // ---- Villagers: shopkeepers, customers, strollers ----
    function makeVillager(x, z, rotY, opts = {}) {
      const g = new THREE.Group();
      const shirt = opts.shirt || 0xc9705a;
      const body = new THREE.Mesh(new THREE.CylinderGeometry(0.24, 0.32, 0.66, 8), flat(shirt));
      body.position.y = 0.55; body.castShadow = true;
      const head = new THREE.Mesh(new THREE.SphereGeometry(0.22, 9, 7), smooth(opts.skin || 0xf2c49b));
      head.position.y = 1.08; head.castShadow = true;
      const armL = new THREE.Mesh(new THREE.CylinderGeometry(0.07, 0.07, 0.42, 5), flat(shirt));
      armL.position.set(-0.32, 0.66, 0);
      const armR = armL.clone(); armR.position.x = 0.32;
      g.add(body, head, armL, armR);
      if (opts.hat === "straw") {
        const brim = new THREE.Mesh(new THREE.CylinderGeometry(0.36, 0.38, 0.05, 8), flat(0xe0b354));
        brim.position.y = 1.22;
        const top = new THREE.Mesh(new THREE.CylinderGeometry(0.15, 0.2, 0.18, 7), flat(0xd9a441));
        top.position.y = 1.32;
        g.add(brim, top);
      } else if (opts.hat === "hood") {
        const hood = new THREE.Mesh(new THREE.SphereGeometry(0.25, 8, 6), flat(opts.hood || 0x8a5f9a));
        hood.position.y = 1.12; hood.scale.set(1.05, 1, 1.05);
        g.add(hood);
      } else {
        const hair = new THREE.Mesh(new THREE.SphereGeometry(0.23, 8, 6), flat(opts.hair || 0x5a3a22));
        hair.position.y = 1.16; hair.scale.set(1, 0.7, 1);
        g.add(hair);
      }
      if (opts.beard) {
        const beard = new THREE.Mesh(new THREE.SphereGeometry(0.16, 7, 6), flat(0xe8e4dc));
        beard.position.set(0, 0.94, 0.16); beard.scale.set(1, 1.15, 0.8);
        g.add(beard);
      }
      if (opts.cane) {
        const cane = new THREE.Mesh(new THREE.CylinderGeometry(0.035, 0.035, 0.95, 5), flat(0x6e4a2c));
        cane.position.set(0.42, 0.48, 0.12); cane.rotation.z = -0.12;
        g.add(cane);
      }
      if (opts.holding) {
        const item = new THREE.Mesh(new THREE.SphereGeometry(0.1, 7, 6), smooth(opts.holding, { roughness: 0.3 }));
        item.position.set(0.32, 0.76, 0.2);
        g.add(item);
      }
      if (opts.scale) g.scale.setScalar(opts.scale);
      g.position.set(x, 0, z);
      g.rotation.y = rotY;
      worldGroup.add(g);
      if (opts.solid !== false) addCircleCol(x, z, 0.38);
      if (!opts.manual) npcs.push({ g, type: opts.walk ? "walk" : "bob", ph: Math.random() * 9, walk: opts.walk, wt: Math.random() * 2, baseRot: rotY });
      return g;
    }

    // ---- Dragon (flat-shaded, rigged for sleep/wake poses) ----
    // ---- the snapping turtle: low-poly like Ember, pure mischief ----
    function makeTurtle() {
      const g = new THREE.Group();
      const shellMat = flat(0x4a7a3c, { roughness: 0.85 });
      const shellRim = flat(0x3a5c2e, { roughness: 0.9 });
      const skin = flat(0x7a9a4c, { roughness: 0.9 });
      const cream = flat(0xd8c89a, { roughness: 0.95 });
      // domed faceted shell + darker rim skirt
      const shell = new THREE.Mesh(new THREE.IcosahedronGeometry(0.85, 0), shellMat);
      shell.scale.set(1.1, 0.55, 1.35);
      shell.position.y = 0.5;
      shell.castShadow = true;
      const rim = new THREE.Mesh(new THREE.CylinderGeometry(0.98, 1.08, 0.18, 9), shellRim);
      rim.scale.set(1, 1, 1.28);
      rim.position.y = 0.3;
      const belly = new THREE.Mesh(new THREE.CylinderGeometry(0.92, 0.86, 0.14, 9), cream);
      belly.scale.set(1, 1, 1.22);
      belly.position.y = 0.16;
      g.add(shell, rim, belly);
      // neck + boxy snapper head with an underbite jaw
      const neck = new THREE.Mesh(new THREE.CylinderGeometry(0.22, 0.28, 0.5, 7), skin);
      neck.rotation.x = Math.PI / 2.6;
      neck.position.set(0, 0.4, 1.25);
      const head = new THREE.Group();
      const skull = new THREE.Mesh(new THREE.BoxGeometry(0.52, 0.4, 0.62), skin);
      skull.castShadow = true;
      const beak = new THREE.Mesh(new THREE.ConeGeometry(0.16, 0.3, 4), shellRim);
      beak.rotation.x = Math.PI / 2;
      beak.position.set(0, -0.02, 0.42);
      const jaw = new THREE.Mesh(new THREE.BoxGeometry(0.44, 0.14, 0.5), cream);
      jaw.position.set(0, -0.24, 0.1);
      // googly eyes, Ember-style
      const eyeW = flat(0xf2f2f2); const eyeB = flat(0x1c1c24);
      [-1, 1].forEach((sx) => {
        const e = new THREE.Mesh(new THREE.SphereGeometry(0.12, 7, 6), eyeW);
        e.position.set(0.2 * sx, 0.18, 0.22);
        const pu = new THREE.Mesh(new THREE.SphereGeometry(0.055, 6, 5), eyeB);
        pu.position.set(0.2 * sx, 0.19, 0.32);
        head.add(e, pu);
      });
      head.add(skull, beak, jaw);
      head.position.set(0, 0.52, 1.62);
      g.add(neck, head);
      // four paddling flippers + stumpy tail
      const flippers = [];
      [[-0.95, 1, 0.78], [0.95, 1, 0.78], [-0.9, -1, -0.7], [0.9, -1, -0.7]].forEach(([fx, side, fz], i) => {
        const f = new THREE.Mesh(new THREE.BoxGeometry(0.62, 0.1, 0.34), skin);
        f.position.set(fx, 0.22, fz);
        f.rotation.y = 0.5 * Math.sign(fx) * (fz > 0 ? 1 : -1) * 0.6;
        f.userData.ph = i * 1.7;
        g.add(f); flippers.push(f);
      });
      const tail = new THREE.Mesh(new THREE.ConeGeometry(0.14, 0.5, 5), skin);
      tail.rotation.x = -Math.PI / 2.2;
      tail.position.set(0, 0.26, -1.35);
      g.add(tail);
      g.userData = { flippers, head, jaw, shellTopY: 0.9 };
      return g;
    }

    function makeDragon() {
      // Lab-v3 Ember (designed in /dragon-lab.html): one lathed torso
      // silhouette, segmented red belly plates, boned wings with real
      // membranes, articulated jaw + tongue + eyelids, googly white eyes.
      // Palette: black hide / red belly+membrane / purple horns+brows+claws.
      const DC = { hide: 0x332a42, hideD: 0x272033, hideXD: 0x1c1628, red: 0xb5303c, redB: 0xd0424b, accent: 0x9b59c9, cream: 0xf2ead2, mouth: 0x4a1420 };
      const g = new THREE.Group();
      const V = (x, y, z) => new THREE.Vector3(x, y, z);
      const shadowed = (m) => { m.castShadow = true; return m; };
      const seg = (a, bp, r0, r1, mat, radial = 6) => {
        const dir = new THREE.Vector3().subVectors(bp, a);
        const m = shadowed(new THREE.Mesh(new THREE.CylinderGeometry(r1, r0, dir.length(), radial), mat));
        m.position.copy(a).addScaledVector(dir, 0.5);
        m.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir.clone().normalize());
        return m;
      };

      // -- torso: single lathed silhouette + red plate wedges + spikes --
      const PROF = [[0.14, 0.06], [0.16, 0.52], [0.32, 0.84], [0.72, 1.02], [1.08, 1.07], [1.46, 0.99], [1.8, 0.8], [2.06, 0.56], [2.2, 0.36], [2.3, 0.05]];
      const bodyRad = (y) => {
        for (let i = 0; i < PROF.length - 1; i++) {
          const [y0, r0] = PROF[i], [y1, r1] = PROF[i + 1];
          if (y >= y0 && y <= y1) return r0 + (r1 - r0) * ((y - y0) / (y1 - y0));
        }
        return 0.5;
      };
      const torso = new THREE.Group();
      g.add(torso);
      torso.add(shadowed(new THREE.Mesh(new THREE.LatheGeometry(PROF.map(([y, r]) => new THREE.Vector2(r, y)), 9), flat(DC.hide))));
      for (const [y0, y1] of [[0.3, 0.62], [0.66, 1.02], [1.06, 1.42], [1.46, 1.74]]) {
        const pts = [];
        for (let i = 0; i <= 4; i++) {
          const y = y0 + (y1 - y0) * i / 4;
          pts.push(new THREE.Vector2(bodyRad(y) * (1.02 + 0.05 * Math.sin(Math.PI * i / 4)), y));
        }
        torso.add(new THREE.Mesh(new THREE.LatheGeometry(pts, 5, -0.71, 1.42), flat(DC.red, { roughness: 0.7 })));
      }
      [[1.98, -0.48, 0.30], [1.7, -0.72, 0.26], [1.4, -0.88, 0.22], [1.05, -0.95, 0.19]].forEach(([y, z, s]) => {
        const sp = new THREE.Mesh(new THREE.ConeGeometry(s * 0.55, s * 1.9, 4), flat(DC.accent));
        sp.position.set(0, y, z); sp.rotation.x = -0.85;
        torso.add(sp);
      });
      torso.add(seg(V(0, 2.05, 0.1), V(0, 2.5, 0.26), 0.42, 0.3, flat(DC.hide), 8)); // neck

      // -- head --
      const headG = new THREE.Group();
      headG.position.set(0, 2.66, 0.3);
      g.add(headG);
      const cranium = shadowed(new THREE.Mesh(new THREE.SphereGeometry(0.82, 10, 8), flat(DC.hide)));
      cranium.scale.set(1.04, 0.92, 1.0); cranium.position.y = 0.3;
      const cheekL = new THREE.Mesh(new THREE.SphereGeometry(0.34, 8, 6), flat(DC.hide));
      cheekL.position.set(-0.48, 0.02, 0.42);
      const cheekR = cheekL.clone(); cheekR.position.x = 0.48;
      const snout = shadowed(new THREE.Mesh(new THREE.SphereGeometry(0.6, 8, 6), flat(DC.hide)));
      snout.scale.set(1.06, 0.5, 1.42); snout.position.set(0, 0.04, 0.64);
      const noseL = new THREE.Mesh(new THREE.SphereGeometry(0.11, 6, 5), flat(DC.hideD));
      noseL.position.set(-0.22, 0.26, 1.34);
      const noseR = noseL.clone(); noseR.position.x = 0.22;
      const throat = new THREE.Mesh(new THREE.BoxGeometry(0.86, 0.34, 1.0), flat(DC.mouth, { roughness: 1 }));
      throat.position.set(0, -0.28, 0.52);
      headG.add(cranium, cheekL, cheekR, snout, noseL, noseR, throat);
      for (const [x, z, s] of [[-0.5, 0.5, 0.17], [-0.28, 0.8, 0.22], [0.04, 0.58, 0.15], [0.3, 0.86, 0.23], [0.5, 0.46, 0.15]]) {
        const tooth = new THREE.Mesh(new THREE.ConeGeometry(s * 0.6, s * 1.7, 5), flat(DC.cream, { roughness: 0.5 }));
        tooth.rotation.x = Math.PI; tooth.rotation.z = (x < 0 ? -1 : 1) * 0.18;
        tooth.position.set(x, -0.18, 0.6 + z * 0.55);
        headG.add(tooth);
      }

      // jaw (articulated) + lower teeth + tongue
      const jaw = new THREE.Group();
      jaw.position.set(0, -0.26, 0.08);
      headG.add(jaw);
      const jawMesh = shadowed(new THREE.Mesh(new THREE.SphereGeometry(0.54, 8, 6), flat(DC.hideD)));
      jawMesh.scale.set(0.96, 0.42, 1.4); jawMesh.position.set(0, -0.08, 0.52);
      const chin = new THREE.Mesh(new THREE.SphereGeometry(0.28, 7, 5), flat(DC.hideXD));
      chin.scale.set(1, 0.55, 0.8); chin.position.set(0, -0.13, 1.02);
      jaw.add(jawMesh, chin);
      for (const [x, z, s] of [[-0.4, 0.9, 0.18], [-0.12, 0.58, 0.13], [0.2, 0.95, 0.21], [0.44, 0.6, 0.13]]) {
        const tooth = new THREE.Mesh(new THREE.ConeGeometry(s * 0.58, s * 1.6, 5), flat(DC.cream, { roughness: 0.5 }));
        tooth.rotation.z = (x < 0 ? 1 : -1) * 0.2;
        tooth.position.set(x, 0.05, 0.34 + z * 0.6);
        jaw.add(tooth);
      }
      const tongue = new THREE.Group();
      tongue.position.set(0.08, 0.02, 0.78);
      jaw.add(tongue);
      const tSegs = [];
      let tParent = tongue;
      for (let i = 0; i < 3; i++) {
        const tg = new THREE.Group();
        tg.position.z = i === 0 ? 0 : 0.34;
        const slab = new THREE.Mesh(new THREE.BoxGeometry(0.32 - i * 0.06, 0.075, 0.4), flat(DC.redB, { roughness: 0.55 }));
        slab.position.z = 0.18;
        tg.add(slab);
        tParent.add(tg);
        tParent = tg;
        tSegs.push(tg);
      }
      const tongueTip = new THREE.Mesh(new THREE.ConeGeometry(0.11, 0.2, 4), flat(DC.redB, { roughness: 0.55 }));
      tongueTip.rotation.x = Math.PI / 2; tongueTip.position.z = 0.44;
      tParent.add(tongueTip);

      // eyes: both white, mismatched googly sizes, articulated lids
      const eyeWarm = SRGB(0xfff2dc), eyeHot = SRGB(0xff2810);
      const makeEye = (x, r, pupilR) => {
        const eg = new THREE.Group();
        eg.position.set(x, 0.5, 0.74);
        headG.add(eg);
        const ball = new THREE.Mesh(new THREE.SphereGeometry(r, 10, 8),
          new THREE.MeshStandardMaterial({ color: SRGB(0xf6f4f0), roughness: 0.3, emissive: eyeWarm.clone(), emissiveIntensity: 0.12 }));
        const pupil = new THREE.Mesh(new THREE.SphereGeometry(pupilR, 8, 6), flat(0x17101d, { roughness: 0.2 }));
        pupil.position.z = r * 0.78;
        const glint = new THREE.Mesh(new THREE.SphereGeometry(pupilR * 0.26, 6, 5),
          new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.1, emissive: 0xffffff, emissiveIntensity: 0.4 }));
        glint.position.set(pupilR * 0.4, pupilR * 0.45, r * 0.94);
        const lid = new THREE.Mesh(new THREE.SphereGeometry(r * 1.12, 10, 6, 0, Math.PI * 2, 0, Math.PI * 0.55), flat(DC.hideD));
        lid.rotation.x = -1.45;
        eg.add(ball, pupil, glint, lid);
        return { g: eg, ball, pupil, lid, r };
      };
      const eyeL = makeEye(-0.42, 0.33, 0.13);
      const eyeR = makeEye(0.4, 0.25, 0.14);
      eyeL.g.rotation.y = -0.12; eyeR.g.rotation.y = 0.1;

      // purple brow ridges + swept-back horns + crest
      // brows ride IN FRONT of the eyeballs so the rage-lower scowls over
      // them instead of clipping through the spheres
      const browL = new THREE.Mesh(new THREE.BoxGeometry(0.46, 0.14, 0.26), flat(DC.accent));
      browL.position.set(-0.43, 0.9, 0.86); browL.rotation.set(-0.5, 0, -0.12);
      const browR = browL.clone(); browR.position.x = 0.41; browR.rotation.z = 0.12;
      browL.userData.by = browL.position.y; browR.userData.by = browR.position.y;
      headG.add(browL, browR);
      for (const side of [-1, 1]) {
        headG.add(seg(V(0.42 * side, 0.78, -0.05), V(0.72 * side, 1.1, -0.5), 0.12, 0.07, flat(DC.accent), 5));
        headG.add(seg(V(0.72 * side, 1.1, -0.5), V(0.86 * side, 1.22, -0.85), 0.07, 0.015, flat(DC.accent), 5));
      }
      [[0.98, -0.3, 0.5], [0.8, -0.62, 0.38]].forEach(([y, z, s]) => {
        const cs = new THREE.Mesh(new THREE.ConeGeometry(0.13 * s + 0.05, 0.5 * s + 0.1, 4), flat(DC.accent));
        cs.position.set(0, y, z); cs.rotation.x = -0.7;
        headG.add(cs);
      });

      // -- wings: root socket → humerus → fingers + stretched membrane --
      const makeWing = (side) => {
        const wg = new THREE.Group();
        wg.position.set(0.34 * side, 1.98, -0.42);
        g.add(wg);
        const s = (v) => V(v.x * side, v.y, v.z);
        wg.add(new THREE.Mesh(new THREE.SphereGeometry(0.2, 7, 5), flat(DC.hide)));
        const elbow = s(V(0.5, 0.42, -0.12));
        const f1 = s(V(1.35, 0.78, -0.3)), f2 = s(V(1.42, 0.22, -0.28)), f3 = s(V(1.05, -0.28, -0.2));
        const inner = s(V(0.18, -0.5, -0.05));
        wg.add(seg(V(0, 0, 0), elbow, 0.09, 0.07, flat(DC.hideD), 5));
        wg.add(seg(elbow, f1, 0.06, 0.02, flat(DC.hideD), 5));
        wg.add(seg(elbow, f2, 0.05, 0.02, flat(DC.hideD), 5));
        wg.add(seg(elbow, f3, 0.05, 0.02, flat(DC.hideD), 5));
        const eb = new THREE.Mesh(new THREE.SphereGeometry(0.09, 6, 5), flat(DC.hideD));
        eb.position.copy(elbow);
        wg.add(eb);
        const lerpIn = (a2, b2, k, pull) => a2.clone().lerp(b2, k).multiplyScalar(1 - pull);
        const rimPts = [elbow, f1, lerpIn(f1, f2, 0.5, 0.16), f2, lerpIn(f2, f3, 0.5, 0.14), f3, lerpIn(f3, inner, 0.5, 0.1), inner];
        const verts = [];
        for (let i = 0; i < rimPts.length - 1; i++) {
          verts.push(0, 0, 0, rimPts[i].x, rimPts[i].y, rimPts[i].z, rimPts[i + 1].x, rimPts[i + 1].y, rimPts[i + 1].z);
        }
        const memGeo = new THREE.BufferGeometry();
        memGeo.setAttribute("position", new THREE.Float32BufferAttribute(verts, 3));
        memGeo.computeVertexNormals();
        wg.add(shadowed(new THREE.Mesh(memGeo, flat(DC.redB, { side: THREE.DoubleSide, roughness: 0.65 }))));
        wg.rotation.set(0, 0.5 * side, -0.12 * side);
        return wg;
      };
      const wingL = makeWing(-1), wingR = makeWing(1);

      // -- arms + legs with purple claws --
      const makeArm = (side) => {
        const ag = new THREE.Group();
        ag.position.set(0.6 * side, 1.76, 0.3);
        g.add(ag);
        ag.add(new THREE.Mesh(new THREE.SphereGeometry(0.22, 8, 6), flat(DC.hide)));
        const elbow = V(0.24 * side, -0.36, 0.28), wrist = V(0.3 * side, -0.56, 0.46);
        ag.add(seg(V(0, 0, 0), elbow, 0.15, 0.11, flat(DC.hideD), 6));
        ag.add(seg(elbow, wrist, 0.11, 0.09, flat(DC.hideD), 6));
        const paw = new THREE.Mesh(new THREE.SphereGeometry(0.15, 7, 5), flat(DC.hideXD));
        paw.position.copy(wrist);
        ag.add(paw);
        for (let i = -1; i <= 1; i++) {
          const claw = new THREE.Mesh(new THREE.ConeGeometry(0.045, 0.15, 4), flat(DC.accent, { roughness: 0.45 }));
          claw.rotation.x = Math.PI / 2;
          claw.position.set(wrist.x + i * 0.08, wrist.y - 0.03, wrist.z + 0.16);
          ag.add(claw);
        }
        return ag;
      };
      const makeLeg = (side) => {
        const lg = new THREE.Group();
        lg.position.set(0.52 * side, 0.66, 0.04);
        g.add(lg);
        const haunch = shadowed(new THREE.Mesh(new THREE.SphereGeometry(0.4, 8, 6), flat(DC.hideD)));
        haunch.scale.set(0.92, 1.0, 1.05); haunch.position.set(0.04 * side, -0.14, 0);
        const foot = new THREE.Mesh(new THREE.SphereGeometry(0.29, 8, 5), flat(DC.hideXD));
        foot.scale.set(1.08, 0.48, 1.4); foot.position.set(0.08 * side, -0.53, 0.18);
        lg.add(haunch, foot);
        for (let i = -1; i <= 1; i++) {
          const claw = new THREE.Mesh(new THREE.ConeGeometry(0.07, 0.2, 4), flat(DC.accent, { roughness: 0.45 }));
          claw.rotation.x = Math.PI / 2;
          claw.position.set(0.08 * side + i * 0.15, -0.56, 0.52);
          lg.add(claw);
        }
        return lg;
      };
      const armL = makeArm(-1), armR = makeArm(1);
      const legL = makeLeg(-1), legR = makeLeg(1);

      // -- tail: shrinking segments, purple spikes, red fin --
      const tail0 = new THREE.Group();
      tail0.position.set(0, 0.6, -0.78);
      g.add(tail0);
      const t0m = shadowed(new THREE.Mesh(new THREE.SphereGeometry(0.36, 8, 6), flat(DC.hide)));
      t0m.scale.set(1, 0.9, 1.3); t0m.position.z = -0.2;
      tail0.add(t0m);
      const tail1 = new THREE.Group();
      tail1.position.set(0, 0.05, -0.52);
      tail0.add(tail1);
      const t1m = new THREE.Mesh(new THREE.SphereGeometry(0.25, 7, 5), flat(DC.hideD));
      t1m.scale.set(1, 0.9, 1.35); t1m.position.z = -0.18;
      tail1.add(t1m);
      const tail2 = new THREE.Group();
      tail2.position.set(0, 0.05, -0.46);
      tail1.add(tail2);
      const t2m = new THREE.Mesh(new THREE.SphereGeometry(0.16, 7, 5), flat(DC.hide));
      t2m.scale.set(1, 0.9, 1.45); t2m.position.z = -0.15;
      tail2.add(t2m);
      [[tail0, 0.17, -0.28], [tail1, 0.14, -0.22], [tail2, 0.11, -0.18]].forEach(([tseg, s, z]) => {
        const spike = new THREE.Mesh(new THREE.ConeGeometry(s * 0.7, s * 2.2, 4), flat(DC.accent));
        spike.position.set(0, 0.2, z); spike.rotation.x = -0.55;
        tseg.add(spike);
      });
      const finShape = new THREE.Shape();
      finShape.moveTo(0, 0); finShape.lineTo(0.02, 0.3); finShape.lineTo(0.34, 0.18);
      finShape.lineTo(0.2, 0); finShape.lineTo(0.34, -0.18); finShape.lineTo(0.02, -0.3); finShape.lineTo(0, 0);
      const fin = new THREE.Mesh(new THREE.ShapeGeometry(finShape), flat(DC.redB, { side: THREE.DoubleSide, roughness: 0.65 }));
      fin.rotation.y = Math.PI / 2; fin.rotation.z = Math.PI / 2;
      fin.position.set(0, 0.05, -0.5);
      tail2.add(fin);

      g.userData = {
        torso, headG, jaw, tongue, tSegs, eyeL, eyeR, browL, browR,
        wingL, wingR, wLbase: wingL.rotation.clone(), wRbase: wingR.rotation.clone(),
        armL, armR, legL, legR, tail0, tail1, tail2,
        eyeWarm, eyeHot,
        ctl: { blink: 0, nextBlink: 2, tongue: 0, nextTongue: 6, jaw: 0, rage: 0 },
      };
      return g;
    }

    // ---- Plants ----
    function buildPlantMesh(seedKey, stage, lite) {
      const s = SEEDS[seedKey];
      const g = new THREE.Group();
      const stemH = [0.25, 0.55, 0.8][stage];
      const stem = new THREE.Mesh(new THREE.CylinderGeometry(0.05, 0.07, stemH, 5), flat(new THREE.Color(PAL.leafMid).offsetHSL(0, 0, -0.05)));
      stem.position.y = stemH / 2; stem.castShadow = true;
      g.add(stem);
      const leafGeo = new THREE.SphereGeometry(0.16 + stage * 0.06, 6, 5);
      const leafMat = flat(leafC(PAL.leafMid, 0.04));
      for (let i = 0; i < 2 + stage; i++) {
        const leaf = new THREE.Mesh(leafGeo, leafMat);
        const a = (i / (2 + stage)) * Math.PI * 2;
        leaf.position.set(Math.cos(a) * 0.2, stemH * 0.7, Math.sin(a) * 0.2);
        leaf.scale.set(1, 0.5, 1.4); leaf.rotation.y = -a;
        g.add(leaf);
      }
      // crop-colored outline shell (backface trick): strawberry reads red,
      // blueberry blue, sunfruit gold from the first sprout, so the garden
      // tells you what's planted where at a glance
      {
        const outlineMat = new THREE.MeshBasicMaterial({ color: SRGB(s.color), side: THREE.BackSide });
        [...g.children].forEach((m) => {
          if (!m.isMesh) return;
          const sh = new THREE.Mesh(m.geometry, outlineMat);
          sh.position.copy(m.position); sh.rotation.copy(m.rotation);
          sh.scale.copy(m.scale).multiplyScalar(1.14);
          g.add(sh);
        });
      }
      if (stage === 2) {
        const berryMat = new THREE.MeshStandardMaterial({
          color: SRGB(s.color), roughness: 0.3,
          emissive: s.glow ? SRGB(s.color) : new THREE.Color(0x000000), emissiveIntensity: s.glow ? 0.9 : 0,
        });
        for (let i = 0; i < 4; i++) {
          const b = new THREE.Mesh(new THREE.SphereGeometry(0.12, 8, 8), berryMat);
          const a = (i / 4) * Math.PI * 2 + 0.5;
          b.position.set(Math.cos(a) * 0.26, stemH * 0.75 + (i % 2) * 0.14, Math.sin(a) * 0.26);
          b.castShadow = true; g.add(b);
        }
        if (s.glow && !lite) {
          const light = new THREE.PointLight(SRGB(s.color), 0.9, 4);
          light.position.y = stemH * 0.8; g.add(light);
        }
      }
      return g;
    }

    // the sacred Glowberry grows into a small magical tree over four stages
    function buildGlowTree(stage, seedKey) {
      const sd = SEEDS[seedKey] || SEEDS.glowberry;
      const g = new THREE.Group();
      const trunkMat = flat(0x4a3a5c, { roughness: 0.85 });
      const leafMat = new THREE.MeshStandardMaterial({ color: SRGB(sd.leaf), emissive: SRGB(sd.leafGlow), emissiveIntensity: 0.3, flatShading: true, roughness: 0.8 });
      const berryMat = new THREE.MeshStandardMaterial({ color: SRGB(sd.berry), emissive: SRGB(sd.berry), emissiveIntensity: 1.5, roughness: 0.25 });
      if (stage === 0) {
        const stem = new THREE.Mesh(new THREE.CylinderGeometry(0.04, 0.06, 0.3, 5), flat(new THREE.Color(PAL.leafMid).offsetHSL(0, 0, -0.05)));
        stem.position.y = 0.15;
        const bud = new THREE.Mesh(new THREE.IcosahedronGeometry(0.11, 0), leafMat);
        bud.position.y = 0.36;
        g.add(stem, bud);
        g.userData = { berryMat };
        return g;
      }
      const h = [0, 0.6, 1.05, 1.5][stage];
      const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.07 + stage * 0.02, 0.11 + stage * 0.03, h, 6), trunkMat);
      trunk.position.y = h / 2; trunk.castShadow = true;
      g.add(trunk);
      const canopies = stage === 1
        ? [[0, h + 0.22, 0, 0.3]]
        : stage === 2
          ? [[0, h + 0.3, 0, 0.42], [0.28, h + 0.05, 0.12, 0.28]]
          : [[0, h + 0.42, 0, 0.55], [0.38, h + 0.12, 0.16, 0.36], [-0.34, h + 0.18, -0.1, 0.33]];
      canopies.forEach(([cx, cy, cz, r]) => {
        const c = new THREE.Mesh(new THREE.IcosahedronGeometry(r, 0), leafMat);
        c.position.set(cx, cy, cz);
        c.rotation.set(Math.random() * 3, Math.random() * 3, 0);
        c.castShadow = true;
        g.add(c);
      });
      const nB = [0, 1, 3, 8][stage];
      for (let i = 0; i < nB; i++) {
        const [cx, cy, cz, r] = canopies[i % canopies.length];
        const a = (i / Math.max(1, nB)) * Math.PI * 2 + i * 0.9;
        const b = new THREE.Mesh(new THREE.SphereGeometry(0.06, 7, 6), berryMat);
        b.position.set(cx + Math.cos(a) * r * 0.85, cy + Math.sin(a * 1.7) * r * 0.55, cz + Math.sin(a) * r * 0.85);
        g.add(b);
      }
      if (stage === 3) {
        const halo = new THREE.Sprite(new THREE.SpriteMaterial({ map: glowTex, transparent: true, opacity: 0.4, depthWrite: false, blending: THREE.AdditiveBlending, color: SRGB(sd.halo) }));
        halo.scale.set(2.2, 2.2, 1);
        halo.position.y = h + 0.42;
        g.add(halo);
        g.userData = { berryMat, halo };
      } else g.userData = { berryMat };
      return g;
    }

    function makePlot(x, z, special = false) {
      const g = new THREE.Group();
      // tilled bed: dark furrow base + 4 lighter turned-earth ridges, timber frame with
      // corner posts — all merged into ONE vertex-colored mesh; per-bed HSL jitter so
      // the six beds never read as one stamp
      const soilC = new THREE.Color(special ? 0x4a3b5c : PAL.soil)
        .offsetHSL((Math.random() - 0.5) * 0.02, (Math.random() - 0.5) * 0.07, (Math.random() - 0.5) * 0.08);
      const furrowC = soilC.clone().offsetHSL(0.004, 0.03, -0.075).convertSRGBToLinear();
      const ridgeC = soilC.clone().offsetHSL(0.008, -0.03, 0.065).convertSRGBToLinear();
      const rimC = new THREE.Color(special ? 0x8a6dbd : PAL.wood)
        .lerp(new THREE.Color(special ? 0x8a6dbd : PAL.bark), special ? 0 : 0.28)
        .offsetHSL(-0.008, special ? 0 : 0.12, -0.03 + (Math.random() - 0.5) * 0.05).convertSRGBToLinear();
      const postC = rimC.clone().offsetHSL(0.004, 0.02, -0.06);
      const solid = (bg, c) => {
        const cnt = bg.attributes.position.count, cols = new Float32Array(cnt * 3);
        for (let vi = 0; vi < cnt; vi++) { cols[vi * 3] = c.r; cols[vi * 3 + 1] = c.g; cols[vi * 3 + 2] = c.b; }
        bg.setAttribute("color", new THREE.BufferAttribute(cols, 3));
        return bg;
      };
      const parts = [];
      const base = solid(new THREE.BoxGeometry(1.5, 0.2, 1.5), furrowC);
      base.translate(0, 0.1, 0); parts.push(base);
      // beds all read the same — the old random "just watered" dark half made
      // some plots look dirty/broken next to their neighbours
      const watered = false;
      const wetC = soilC.clone().offsetHSL(0.006, 0.05, -0.16).convertSRGBToLinear();
      [-0.54, -0.18, 0.18, 0.54].forEach((rz) => {
        const rw = 1.36 - Math.abs(rz) * 0.08;
        const wet = watered && rz < 0;
        const rC = (wet ? wetC : ridgeC).clone().offsetHSL(0, 0, (Math.random() - 0.5) * 0.045);
        const ridge = solid(new THREE.BoxGeometry(rw, 0.07, 0.2), rC);
        ridge.rotateY((Math.random() - 0.5) * 0.05);
        ridge.translate((Math.random() - 0.5) * 0.05, 0.225, rz);
        parts.push(ridge);
      });
      if (watered) {
        // damp fill between the wet ridges — sits above the base, below the ridge crowns
        const damp = solid(new THREE.BoxGeometry(1.44, 0.016, 0.68), wetC.clone().offsetHSL(0, 0, -0.03));
        damp.translate(0, 0.206, -0.37);
        parts.push(damp);
      }
      // frame rails (4 sides) + squat corner posts
      [[0, -0.85, 1.7, 0.12], [0, 0.85, 1.7, 0.12], [-0.85, 0, 0.12, 1.7], [0.85, 0, 0.12, 1.7]].forEach(([fx, fz, w, d]) => {
        const rail = solid(new THREE.BoxGeometry(w, 0.14, d), rimC.clone().offsetHSL(0, 0, (Math.random() - 0.5) * 0.04));
        rail.translate(fx, 0.07, fz); parts.push(rail);
      });
      [[-0.85, -0.85], [0.85, -0.85], [-0.85, 0.85], [0.85, 0.85]].forEach(([px, pz]) => {
        const post = solid(new THREE.BoxGeometry(0.16, 0.26, 0.16), postC);
        post.rotateY((Math.random() - 0.5) * 0.1);
        post.translate(px, 0.13, pz); parts.push(post);
      });
      // trodden-dirt spill skirt under the frame + a few kicked-up clods around the
      // base — the bed sits in worked earth instead of hovering on lawn
      const spillC = soilC.clone().lerp(new THREE.Color(PAL.pathStone), 0.34).offsetHSL(0.002, -0.05, -0.02).convertSRGBToLinear();
      const spill = solid(new THREE.CylinderGeometry(1.14, 1.3, 0.05, 10), spillC);
      spill.rotateY(Math.random() * Math.PI);
      spill.translate((Math.random() - 0.5) * 0.08, 0.024, (Math.random() - 0.5) * 0.08);
      parts.push(spill);
      for (let ci = 0; ci < 4; ci++) {
        const ca = Math.random() * Math.PI * 2, cr = 0.98 + Math.random() * 0.3;
        const clod = solid(new THREE.IcosahedronGeometry(0.045 + Math.random() * 0.04, 0),
          furrowC.clone().offsetHSL(0, 0, (Math.random() - 0.5) * 0.07));
        clod.rotateY(Math.random() * Math.PI);
        clod.translate(Math.cos(ca) * cr, 0.045, Math.sin(ca) * cr);
        parts.push(clod);
      }
      const bed = new THREE.Mesh(mergeGeoms(parts), flat(0xffffff, { vertexColors: true, roughness: 1 }));
      bed.receiveShadow = true; bed.castShadow = true;
      g.add(bed);
      if (special) {
        const runeMat = new THREE.MeshStandardMaterial({ color: SRGB(0x9fffe0), emissive: SRGB(0x63ffc9), emissiveIntensity: 0.7 });
        for (let i = 0; i < 4; i++) {
          const rune = new THREE.Mesh(new THREE.BoxGeometry(0.1, 0.05, 0.28), runeMat);
          const a = (i / 4) * Math.PI * 2;
          rune.position.set(Math.cos(a) * 0.83, 0.13, Math.sin(a) * 0.83);
          rune.rotation.y = a; g.add(rune);
        }
      }
      // per-bed pose jitter: slight yaw + footprint scale so six beds never read as
      // one duplicated stamp (position itself stays exactly on the plot grid)
      g.rotation.y = (Math.random() - 0.5) * 0.1;
      const ps = 0.96 + Math.random() * 0.07;
      g.scale.set(ps, 1, ps);
      g.position.set(x, 0, z);
      return g;
    }

    // ---- Weekly garden league (Monday through Sunday night) ----
    function computeWeek() {
      const now = new Date();
      const ws = new Date(now); ws.setHours(0, 0, 0, 0);
      ws.setDate(ws.getDate() - ((now.getDay() + 6) % 7)); // back to Monday
      const we = new Date(ws); we.setDate(we.getDate() + 7);
      const hrs = (now - ws) / 3.6e6;
      return {
        key: ws.toISOString().slice(0, 10),
        endMs: we.getTime(),
        mine: 0, fund: 0, pending: 0,
        rivals: [
          { name: "St. Mark's Youth", rate: 3.4, berries: Math.round(3.4 * hrs * (0.8 + Math.random() * 0.4)), acc: 0 },
          { name: "River Chapel Kids", rate: 2.6, berries: Math.round(2.6 * hrs * (0.8 + Math.random() * 0.4)), acc: 0 },
          { name: "Hilltop Ministry", rate: 1.9, berries: Math.round(1.9 * hrs * (0.8 + Math.random() * 0.4)), acc: 0 },
        ],
      };
    }
    async function loadWeekSave() {
      try {
        if (!window.storage) return;
        const r = await window.storage.get("grace-garden-week");
        if (r && r.value) {
          const d = JSON.parse(r.value);
          if (d.key === G.week.key) { G.week.mine = d.mine || 0; G.week.fund = d.fund || 0; G.week.pending = 0; }
        }
      } catch (e) { /* first run or storage unavailable */ }
    }
    function saveWeek() {
      try {
        // persist the SERVER figure only — folding the optimistic pending
        // count in here made last session's prediction reload as fact, and
        // the header drifted further from the league board every session
        if (window.storage) window.storage.set("grace-garden-week", JSON.stringify({ key: G.week.key, mine: G.week.mine, fund: G.week.fund }));
      } catch (e) {}
    }

    // ---- full game-state persistence: inventory, gold, home plots, dragon ----
    // Plot timers are saved as wall-clock-anchored "seconds left" so plants
    // keep growing (and regrowing) while the game is closed. Saves are
    // change-driven (checked every 4s) plus a flush when the page hides.
    let stateLoaded = false, lastStateSig = null, lastStateCheck = 0;
    function serializeState() {
      return {
        v: 1,
        savedAt: Date.now(),
        gold: G.gold,
        hunger: Math.round(G.hunger),
        level: G.level,
        gems: G.gems,
        selectedSeed: G.selectedSeed,
        selectedFruit: G.selectedFruit,
        activeKind: G.activeKind,
        goldBag: G.goldBagFound ? 1 : 0,
        awayEaten: G.awayEaten || [],
        inv: G.inv,
        homePlots: G.homePlots.map((p) => p.seed ? {
          seed: p.seed,
          h: p.harvests || 0,
          regrowLeft: p.regrowAt != null ? Math.max(0, Math.round(p.regrowAt - G.time)) : null,
          growLeft: p.regrowAt == null ? Math.max(0, Math.round(p.plantedAt + (SEEDS[p.seed]?.grow || 20) - G.time)) : null,
        } : null),
      };
    }
    // structural signature — live countdowns deliberately excluded so idle
    // ticking doesn't spam writes; the payload still carries exact timers
    function stateSig() {
      return JSON.stringify([
        G.gold, G.inv, G.selectedSeed, Math.round(G.hunger / 10), G.goldBagFound, G.level, G.gems,
        G.homePlots.map((p) => p.seed ? p.seed + (p.regrowAt != null ? "r" : "g") : "-"),
      ]);
    }
    function saveState() {
      try { if (window.storage) window.storage.set("garden-state", JSON.stringify(serializeState())); } catch (e) {}
    }
    function applyState(d) {
      if (!d || d.v !== 1) return;
      const off = Math.max(0, (Date.now() - (d.savedAt || Date.now())) / 1000); // seconds spent offline
      if (typeof d.gold === "number") G.gold = d.gold;
      if (d.inv) { Object.assign(G.inv.seeds, d.inv.seeds || {}); Object.assign(G.inv.fruit, d.inv.fruit || {}); }
      if (typeof d.level === "number") G.level = Math.max(1, d.level | 0);
      if (typeof d.gems === "number") G.gems = Math.min(GEMS_PER_LEVEL - 1, Math.max(0, d.gems | 0));
      if (d.selectedSeed && SEEDS[d.selectedSeed]) G.selectedSeed = d.selectedSeed;
      // saves from before the rare tiles existed could hold an unshowable crop
      if (!SEEDS[G.selectedSeed]) G.selectedSeed = "strawberry";
      if (d.selectedFruit && SEEDS[d.selectedFruit]) G.selectedFruit = d.selectedFruit;
      if (d.activeKind === "seed" || d.activeKind === "fruit") G.activeKind = d.activeKind;
      if (G.selectedSeed === "glowberry" && G.map !== "CHURCH") G.selectedSeed = "strawberry"; // glow seeds are church-only
      G.goldBagFound = d.goldBag === 1;
      if (Array.isArray(d.awayEaten)) G.awayEaten = d.awayEaten; // report survives a restart
      if (typeof d.hunger === "number") G.hunger = Math.min(100, Math.max(0, d.hunger)); // exact restore — a starving Ember stays starving
      if (Array.isArray(d.homePlots)) {
        d.homePlots.forEach((sp, i) => {
          if (i >= G.homePlots.length) return;
          const p = G.homePlots[i];
          if (!sp || !SEEDS[sp.seed]) { p.seed = null; p.regrowAt = null; p.harvests = 0; return; }
          p.seed = sp.seed;
          p.harvests = sp.h || 0;
          const grow = SEEDS[sp.seed].grow;
          if (sp.regrowLeft != null) {
            p.plantedAt = G.time - grow; // fully-grown baseline
            p.regrowAt = G.time + Math.max(0, sp.regrowLeft - off);
          } else {
            const left = Math.max(0, (sp.growLeft || 0) - off);
            p.plantedAt = G.time - (grow - left);
            p.regrowAt = null;
          }
        });
      }
    }
    const flushState = () => { if (stateLoaded) saveState(); };
    const onVisFlush = () => { if (document.visibilityState === "hidden") flushState(); };
    document.addEventListener("visibilitychange", onVisFlush);
    window.addEventListener("pagehide", flushState);

    // ---- YGTeeV backend: XP spend sync (optimistic local, server reconciles) ----
    function syncXpSpend(amount, itemKey) {
      const api = window.YGTEEV_API;
      if (!api) return;
      api.spendXp(amount, itemKey)
        .then((r) => { if (r && typeof r.remaining_xp === "number") G.xp = r.remaining_xp; })
        .catch(() => { G.xp += amount; toast("⚠️ Purchase didn't sync — refunded.", "warn"); });
    }

    // ---- YGTeeV backend: real Garden League standings (poll every 60s) ----
    async function syncLeague() {
      const api = window.YGTEEV_API;
      if (!api) return;
      try {
        const rows = await api.getLeague();
        const myGid = G.activeGarden?.id || window.YGTEEV?.profile?.groupId;
        const mine = rows.find((r) => r.group_id === myGid);
        const serverMine = mine ? mine.berries : 0;
        // The server figure is authoritative. Our optimistic +1s are only a
        // PREDICTION of credits the accrual cron hasn't posted yet, so retire
        // as many of them as the server just absorbed — the sum never ticks
        // backwards, and any over-prediction is worked off instead of
        // compounding until the header disagrees with the league board.
        const absorbed = Math.max(0, serverMine - G.week.mine);
        G.week.pending = Math.max(0, (G.week.pending || 0) - absorbed);
        G.week.mine = serverMine;
        G.week.fund = mine ? mine.fund : 0;
        G.week.myName = G.activeGarden?.name || window.YGTEEV?.profile?.groupName || (mine ? mine.group_name : null);
        G.week.rivals = rows
          .filter((r) => r.group_id !== myGid)
          .slice(0, 8)
          .map((r) => ({ name: r.group_name, berries: r.berries, rate: 0, acc: 0 }));
        // full board for the Garden League view (multiplier precomputed server-side)
        G.week.rows = rows.map((r) => ({
          id: r.group_id, name: r.group_name, berries: r.berries,
          mult: Number(r.multiplier) || 1, adjusted: r.adjusted ?? r.berries,
          active: r.active_count || 0, mine: r.group_id === myGid,
        }));
        try { G.pulse = await api.getPulse(myGid); } catch (e) { /* pulse is cosmetic */ }
      } catch (e) { /* standings are cosmetic between polls */ }
    }
    // ---- YGTeeV backend: daily red bags (server decides spots + rewards) ----
    async function syncRedBags() {
      const api = window.YGTEEV_API;
      if (!api || !api.getRedBags) return;
      try {
        const fresh = await api.getRedBags();
        // UTC-day rollover mid-session: answered bags come back as fresh
        // 'hidden' rows — drop yesterday's meshes so they respawn anew
        const rolled = (G.redBags || []).some((o) => {
          const n = fresh.find((x) => x.bag_idx === o.bag_idx);
          return n && (o.status === "correct" || o.status === "wrong") && n.status === "hidden";
        });
        if (rolled) [0, 1, 2].forEach((i) => removeRedBag(i, false));
        G.redBags = fresh;
        if (G.map === "HOME") spawnRedBags();
      } catch (e) { /* bags are a daily bonus — fail quiet */ }
    }
    if (window.YGTEEV_API) { syncLeague(); setInterval(syncLeague, 60000); syncRedBags(); setInterval(syncRedBags, 300000); }

    // ================= GAME STATE =================
    // Player levelling: gems fill a 10-slot bar, each full bar is a level.
    // Gems are awarded PER SUCCESSFUL HARVEST (not per fruit).
    const GEMS_PER_LEVEL = 10;
    const HARVEST_GEMS = { strawberry: 1, blueberry: 2, sunfruit: 3 };
    const G = {
      gold: 25, xp: window.YGTEEV?.profile?.xp ?? 10000, level: 1,
      // Fullness drains over 260s. With the sleep/wake thresholds below this
      // gives Ember a 2-minute nap after a full feed, then a hungry stretch
      // before he raids.
      hunger: 100, hungerRate: 100 / 260,
      inv: { seeds: { strawberry: 0, blueberry: 0, sunfruit: 0, glowberry: 0, starberry: 0, dawnberry: 0, gloryberry: 0 },
             fruit: { strawberry: 0, blueberry: 0, sunfruit: 0, glowberry: 0, starberry: 0, dawnberry: 0, gloryberry: 0 } },
      level: 1, gems: 0, // gems within the current level (0..9)
      selectedSeed: "strawberry",
      selectedFruit: "strawberry",
      activeKind: "seed", // "seed" -> plots plant it; "fruit" -> Ember eats it
      map: "HOME",
      homePlots: Array.from({ length: 6 }, () => ({ seed: null, plantedAt: 0 })),
      churchPlots: Array.from({ length: 324 }, () => ({ seed: null, plantedAt: 0, collectAt: null })),
      time: 0,
      dragonState: "idle", dragonTimer: 0, shakeT: 0,
      prowlIdx: 0, prowlFrenzyT: 0, prowlNextFrenzy: 0, prowlFireT: 0,
      dragonMood: "sleep", sleepBlend: 1, wakeT: 0, dragonHappyT: 0,
      emberHappyT: 0, // >0 keeps the "EMBER IS HAPPY!" sign up, then it dismisses
      week: computeWeek(), quizActive: false, saveT: 0, lastCollectToast: -9,
      eliQuizN: 0, // how many times Eli has issued the challenge (rotates his greeting)
      playerHopT: 0, transitioning: false, pendingMap: null, hungerAlertT: 0,
      hungerPlaqueT: 0, // how long the hangry plaque has nagged (auto-hides at 60s)
      outfit: { skin: 0xf2c9a4, hair: 0x4a2f1c, hairStyle: "crop", style: "tee", shirt: 0x3a72c9, boots: 0x3f2f20, hat: "straw", accessory: "basket" },
      build: { hoe: false, fenceTier: 0, kitsBought: 0, extraPlots: [] },
      buildActive: false, ghostOk: false, ghostCell: null,
      counterActive: false, counterKind: null, counterNear: false, exitLatch: false,
      introActive: false, introFocus: null, introLock: false, introTask: null, introTaskDone: null,
      introCelebrate: null, introCelebrateT: 0, introCelebrateNext: null,
      introPage: null, introGave: false, introGiftClaimed: {},
      churchIntroPage: null, churchIntroDone: false,
      eliQuipCd: 0, eliQuipNear: false, eliQuipBag: [], // idle banter at his post
      awayEaten: [], // plants Ember raided while the player was off the home map
      youthGroup: false, bridgeNoteShown: false, goldBagFound: false,
      readingLock: false, readingNagT: -99, readingGraceUntil: 0, // exits shut while a passage plays
      plotRows: [], forecastShown: false, // picnic-table 24h harvest forecast
      redBags: null, // today's server-issued bags: [{ bag_idx, status, spot }]
      // Title splash: cinematic camera holds + intro/movement stay gated
      // until the START GAME tap flips this off (see SplashScreen).
      splashActive: true,
    };
    gameRef.current = G;
    loadWeekSave();
    G.SFX = SFX;
    G.HARVEST_GEMS = HARVEST_GEMS;
    G.toggleMute = () => {
      AUDIO.muted = !AUDIO.muted;
      if (audioOut) audioOut.gain.value = AUDIO.muted ? 0 : 0.9;
      try { if (window.storage) window.storage.set("by-muted", AUDIO.muted ? "1" : "0"); } catch (e) {}
      return AUDIO.muted;
    };
    G.reqTransition = (label) => reqTransitionRef.current(label);
    G.reqGardenPick = (opts, ex) => reqGardenPickRef.current(opts, ex);
    if (import.meta.env && import.meta.env.DEV) {
      window.__BY_G = G; // dev-only test hook
      G.__dev = () => ({ px: playerPos.x, pz: playerPos.z, prompt: currentPrompt ? currentPrompt.type : null, ac: AC ? AC.state : null, keeper: window.__BY_KEEPER ? !window.__BY_KEEPER.paused : false, live: liveCh ? Object.keys(livePlayers).length : null });
      G.__redBags = { spawn: () => spawnRedBags(), sync: () => syncRedBags(), remove: (i) => removeRedBag(i, false) };
      G.__tp = (x, z) => { playerPos.x = x; playerPos.z = z; };
      G.__plots = (n) => plotNodes.slice(0, n || 8).map((nd) => ({ i: nd.idx, sp: nd.special, st: nd.stage, plant: !!nd.plant, seed: nd.data() && nd.data().seed, x: nd.x, z: nd.z }));
      G.__renderInfo = () => ({ calls: renderer.info.render.calls, tris: renderer.info.render.triangles, geoms: renderer.info.memory.geometries, texs: renderer.info.memory.textures, progs: renderer.info.programs ? renderer.info.programs.length : 0 });
      G.__toast = toast; // headless tests drive the notification stack
      G.__level = (n) => awardGems(n || GEMS_PER_LEVEL); // force a level-up
      G.__openShop = (k) => setShop(k); // headless tests jump straight into a shop
      G.__openBoard = (v = true) => setBoard(v); // ...and into the league board
      G.__musicGain = () => (trackGain ? +trackGain.gain.value.toFixed(3) : null);
      G.__dragon = () => (dragon ? { x: dragon.position.x, z: dragon.position.z } : null);
      // turtle-vs-bridge clearance checks
      G.__turtle = () => {
        if (!turtle) return null;
        const bb = new THREE.Box3().setFromObject(turtle);
        return { x: +turtle.position.x.toFixed(3), z: +turtle.userData.z.toFixed(3),
                 dir: turtle.userData.dir, top: +bb.max.y.toFixed(3) };
      };
      G.__turtleTo = (z, dir) => { if (turtle) { turtle.userData.z = z; if (dir) turtle.userData.dir = dir; } };
      G.__playerY = () => player.position.y;
      G.__playerUD = () => player.userData;
      G.__hatBox = () => {
        const u = player.userData;
        player.updateMatrixWorld(true);
        const hv = Object.values(u.hatVariants).find((h) => h.visible);
        const cb = new THREE.Box3().setFromObject(u.hairMesh.userData.crownPart);
        const hb = hv ? new THREE.Box3().setFromObject(hv) : null;
        return { crownTop: +cb.max.y.toFixed(4),
                 hatTop: hb ? +hb.max.y.toFixed(4) : null,
                 hatBot: hb ? +hb.min.y.toFixed(4) : null,
                 hatBaseY: +u.hatBaseY.toFixed(4) };
      };
      window.__BY_HAIR_STYLES = HAIR_STYLES.map((o) => o.k);
      window.__BY_STYLE_OPTS = STYLE_OPTS.map((o) => o.k);
      window.__BY_SKIN = SKIN_TONES;
      G.__ride = () => { G.turtleSeq = { phase: "ride", t: 0 }; };
      // world -> screen px, so headless tests can tap exact ground targets
      G.__screen = (x, z, y = 0.1) => {
        const v = new THREE.Vector3(x, y, z).project(camera);
        return { x: (v.x * 0.5 + 0.5) * W(), y: (-v.y * 0.5 + 0.5) * H() };
      };
    }
    G.reqCounter = (kind) => reqCounterRef.current(kind);
    G.reqSeedGift = (g) => reqSeedGiftRef.current(g);
    G.reqAwayReport = (eaten) => reqAwayReportRef.current(eaten);
    G.refreshLeague = () => syncLeague(); // opening the board forces a fetch
    // server-credited XP (reading, questions) lands back in the wallet
    G.applyXp = (total) => { if (typeof total === "number") { G.xp = total; syncHud(); } };
    G.reqBridge = () => reqBridgeRef.current();
    G.reqForecast = (f) => reqForecastRef.current(f);
    G.reqGoldBag = () => reqGoldBagRef.current();
    G.reqRedBag = (p) => reqRedBagRef.current(p);
    G.reqChurchIntro = (n) => reqChurchIntroRef.current(n);
    G.flyCoins = (n) => flyCoinsRef.current(n);
    G.doPendingMap = () => { if (G.pendingMap) { loadMap(G.pendingMap.to, G.pendingMap.spawn); G.pendingMap = null; } };
    G.endTransition = () => { G.transitioning = false; };

    // ================= GLOWLANDS FOUNDATIONS (Wire Step A) =================
    // Everything below is glue only: passage fetching, glow-state persistence,
    // the shared ctx bridge, and the dev hook skeleton. Maps / HUD / prologue
    // are wired in later steps (buildGlowHome / buildGlowMeadow / buildEastRoad
    // / glowEnterTown stubs further down).

    // ---- fetchPassage: RUNTIME ESV via the deployed get-bible-passage edge
    // function. Verse text is NEVER bundled; successes cache in-memory for the
    // session (errors are not cached so a 503 recovers once the key exists).
    const glowPassageCache = new Map();
    async function glowFetchPassage(reference, translation = "ESV") {
      const ref = String(reference || "").trim();
      if (!ref) return { error: "missing_reference" };
      const key = translation + ":" + ref.toLowerCase().replace(/\s+/g, " ");
      if (glowPassageCache.has(key)) return glowPassageCache.get(key);
      try {
        let token = null;
        try { token = (await supabase.auth.getSession()).data.session?.access_token || null; } catch (e) {}
        if (!token) return { error: "not_signed_in" };
        const res = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/get-bible-passage`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${token}`,
            apikey: import.meta.env.VITE_SUPABASE_ANON_KEY,
          },
          body: JSON.stringify({ reference: ref, translation }),
        });
        const j = await res.json().catch(() => null);
        if (!res.ok || !j || j.error) return { error: (j && j.error) || `http_${res.status}` };
        const out = { reference: j.reference, translation: j.translation, text: j.text };
        glowPassageCache.set(key, out);
        return out;
      } catch (e) {
        return { error: "network_failed" };
      }
    }

    // ---- glow-state: the one storage blob shared by every glowlands module
    // (satchel serums, quest beats, reading days...). Modules read-modify-write
    // it preserving fields they don't own; reads go THROUGH to storage so the
    // satchel's own persistence never races a stale cache here. glowStateCache
    // exists for boot hydration + the dev hook snapshot only.
    let glowStateCache = null;
    async function readGlowStateRaw() {
      try {
        if (!window.storage) return glowStateCache;
        const r = await window.storage.get("glow-state").catch(() => null);
        const raw = r && typeof r === "object" && "value" in r ? r.value : r;
        glowStateCache = raw ? (typeof raw === "string" ? JSON.parse(raw) : raw) : (glowStateCache || {});
      } catch (e) { glowStateCache = glowStateCache || {}; }
      return glowStateCache;
    }
    function getGlowState() { return glowStateCache != null && !window.storage ? glowStateCache : readGlowStateRaw(); }
    function setGlowState(next) {
      glowStateCache = next || {};
      try { if (window.storage) window.storage.set("glow-state", JSON.stringify(glowStateCache)); } catch (e) {}
    }
    async function glowMutate(fn) { // read-modify-write preserving unowned fields
      const gs = (await readGlowStateRaw()) || {};
      try { fn(gs); } catch (e) {}
      setGlowState(gs);
    }

    // ---- the shared ctx bridge (per the module-header contracts in
    // src/glowlands/*.js). World/map hooks (ctx.world, terrain/collider/scatter
    // helpers) are appended by the map wire steps.
    const glowStorage = { // late-binds window.storage (installed pre-mount in prod)
      get: (k) => (window.storage ? window.storage.get(k) : Promise.resolve(null)),
      set: (k, v) => (window.storage ? window.storage.set(k, v) : Promise.resolve()),
    };
    const glowCtx = {
      fetchPassage: glowFetchPassage,
      storage: glowStorage,
      getGlowState, setGlowState,
      // Rewards ride the host wallets (optimistic-local, same as red bags).
      awardXp: (n) => { const v = Math.max(0, Math.round(n || 0)); if (v) G.xp += v; },
      awardGold: (n) => { const v = Math.max(0, Math.round(n || 0)); if (v) { G.gold += v; try { G.flyCoins && G.flyCoins(Math.min(8, v)); } catch (e) {} } },
      awardFruit: (n) => { const v = Math.max(0, Math.round(n || 0)); if (v) G.inv.fruit.strawberry += v; },
      getFruitCount: () => Object.values(G.inv.fruit).reduce((a, b) => a + (b || 0), 0),
      spendFruit: (n) => {
        let need = Math.max(0, Math.round(n || 0));
        if (Object.values(G.inv.fruit).reduce((a, b) => a + (b || 0), 0) < need) return false;
        for (const k of Object.keys(G.inv.fruit)) {
          const take = Math.min(need, G.inv.fruit[k] || 0);
          G.inv.fruit[k] -= take; need -= take;
          if (!need) break;
        }
        return true;
      },
      awardSparks: (n) => { const v = Math.max(0, Math.round(n || 0)); if (v) glowMutate((gs) => { gs.sparks = (gs.sparks || 0) + v; }); },
      logMiss: (m) => glowMutate((gs) => { (gs.missLog = gs.missLog || []).push(m); if (gs.missLog.length > 200) gs.missLog.splice(0, gs.missLog.length - 200); }),
      grantItem: (item) => glowMutate((gs) => { (gs.items = gs.items || []).push({ id: item && item.id, name: item && item.name, at: Date.now() }); }),
      onSealEarned: (n) => glowMutate((gs) => { const s = new Set(gs.seals || []); s.add(n); gs.seals = [...s].sort(); }),
      // Encounter plumbing (combat.js is self-contained off this ctx).
      startEncounter: (id) => glowStartEncounter(glowCtx, id),
      setTimeDilation: (m) => { G.glowTimeDilation = typeof m === "number" && m > 0 ? m : 1; }, // applied to dt by a later wire step
      duckAmbient: (on) => { try { on === false ? releaseAmbientDuck() : glowDuckAmbient(); } catch (e) {} },
      isDusk: () => false, // host has no day cycle yet; road dusk density lands with the map step
      // Host services
      sfx: SFX,
      fanfare: (weight) => { try { playLightfoundFanfare(weight); } catch (e) {} },
      openTodaysPlan: () => { try { if (window.YGTEEV_API && window.YGTEEV_API.openTodaysPlan) window.YGTEEV_API.openTodaysPlan(); } catch (e) {} },
      settings: { calmMode: false, reducedFlash: false, reducedMotion: false },
      mount: document.body,
      now: () => Date.now(),
      random: Math.random,
    };
    G.glowTimeDilation = 1;

    // ---- the Verse Satchel: persistent serum collection (no HUD mounted yet —
    // the HUD button + panel entry points land with the HUD wire step).
    const glowSatchel = createSatchel({
      storage: glowStorage,
      fetchPassage: glowFetchPassage,
      fanfare: glowCtx.fanfare,
      sfx: SFX,
      settings: glowCtx.settings,
    });
    glowCtx.getEquippedSerums = glowSatchel.getEquippedSerums;
    glowCtx.spendSerumCharge = glowSatchel.spendSerumCharge;
    glowCtx.satchel = { mintSerum: glowSatchel.mintSerum, mintByVerseId: glowSatchel.mintByVerseId, recharge: glowSatchel.recharge };

    // ---- dev hook skeleton (contract: window.__BY_G.__glow.*) ----
    if (import.meta.env && import.meta.env.DEV) {
      G.__glow = {
        tpMap: (name, x, z) => {
          let n = String(name || "").toUpperCase();
          if (n === "EAST_ROAD") n = "EASTROAD";
          let s = Array.isArray(x) ? [x[0], x[1]] : typeof x === "number" ? [x, z] : undefined;
          if (!s && n === "EASTROAD") s = [...EastRoad.SPAWNS.default];
          loadMap(n, s);
          return G.map;
        },
        startEncounter: (id) => glowStartEncounter(glowCtx, id),
        openBook: () => { const tb = glowEnsureTownBook(); return tb && tb.open ? tb.open() : Promise.reject(new Error("townbook unavailable")); },
        setLantern: (tier) => glowSetLantern(tier),
        grantSerums: () => {
          const ids = [...STARTER_SERUMS, ...FIRST_STUDY_SESSION_MINTS];
          return ids.map((id) => glowSatchel.mintByVerseId(id, { source: "dev" }));
        },
        state: async () => ({
          glow: await readGlowStateRaw(),
          lantern: getLantern(),
          satchel: glowSatchel.getEquippedSerums ? glowSatchel.getEquippedSerums() : null,
          timeDilation: G.glowTimeDilation,
        }),
        ctx: glowCtx,
      };
    }

    const syncHud = () => setHud({
      gold: G.gold, xp: G.xp, level: G.level, hunger: Math.max(0, G.hunger),
      map: G.map, prompt: promptText, selectedSeed: G.selectedSeed,
      selectedFruit: G.selectedFruit, activeKind: G.activeKind,
      level: G.level, gems: G.gems, gemFx: G.pendingGemFx,
      avatarPortrait: avatarUrlCache,
      inv: JSON.parse(JSON.stringify(G.inv)),
      showHunger: ((G.dragonState !== "idle" || G.hunger < 32) && G.hungerPlaqueT < 60) || G.hungerAlertT > 0 || G.emberHappyT > 0,
      emberHappy: Math.round((Math.max(0, Math.min(100, G.hunger)) / 100) * 7) >= 7, // happy == meter full (same 7-slot math as the plaque)
      outfit: { ...G.outfit },
      intro: { page: G.introPage, task: G.introTask, celebrate: G.introCelebrate },
      youth: G.youthGroup,
      build: {
        hoe: G.build.hoe, fenceTier: G.build.fenceTier,
        kitCost: kitCostAt(G.build.kitsBought),
        canPlace: !!(G.ghostOk && G.ghostCell),
        deedCost: FENCE_TIERS[G.build.fenceTier + 1] ? FENCE_TIERS[G.build.fenceTier + 1].cost : null,
      },
      promptType: currentPrompt ? currentPrompt.type : null,
      league: {
        mine: G.week.mine + (G.week.pending || 0), fund: G.week.fund, endMs: G.week.endMs, myName: G.week.myName,
        rivals: G.week.rivals.map((r) => ({ name: r.name, berries: r.berries })),
        rows: G.week.rows || [],
        pulse: G.pulse || {},
      },
    });

    // ================= WORLDS =================
    let worldGroup = null;
    let plotNodes = [], exits = [], hotspots = [];
    let dragon = null, dragonHome = new THREE.Vector3();
    let goldBag = null; // one-time glowing pouch on the town road
    let marketArrow = null; // 5s cue after the Berry Market flyer: arrow to town
    let emberBar = null; // floating 7-gem hunger meter above Ember
    let turtle = null; // snapping-turtle easter egg, patrols the river at home
    // how close a RIDDEN turtle may get to the bridge centreline (z = 3)
    // before it turns back; the deck plus its posts occupy |z-3| < 1.15
    const TURTLE_BRIDGE_HALF = 2.2;
    let shopWords = []; // floating verb signs over the town shops
    let redBagMeshes = {}; // today's hidden question-pouches on HOME, by bag_idx
    let butterflies = [], glowNodes = [], embers = [], smokes = [], caveLight = null, npcs = [], zzz = [];
    let gardener = null, gardenerCtl = { mode: "post", t: 0, post: [0, 0], postRot: 0 }, bursts = [], timerSprite = null, winsSprite = null, water = null, foams = [], riverFoam = null, swayers = [], petals = [], fountainFx = null;
    let buildCells = [], ghostMesh = null, buildMarkers = null, counterKeeper = null;
    // Glowlands per-map handles live further down (glowHomeHandle /
    // glowMeadowHandle / glowRoadHandle) and are torn down in clearWorld.

    // "Z" sprite texture for Ember's snoring
    const zzzCanvas = document.createElement("canvas");
    zzzCanvas.width = 64; zzzCanvas.height = 64;
    const zctx = zzzCanvas.getContext("2d");
    zctx.font = "bold 46px Georgia";
    zctx.textAlign = "center"; zctx.textBaseline = "middle";
    zctx.lineWidth = 7; zctx.strokeStyle = "rgba(40,30,70,0.9)";
    zctx.strokeText("Z", 32, 34);
    zctx.fillStyle = "#efe6ff";
    zctx.fillText("Z", 32, 34);
    const zzzTex = new THREE.CanvasTexture(zzzCanvas); shareGpu(zzzTex);

    // soft radial glow for the magical Glowberry tree
    const glowCv = document.createElement("canvas");
    glowCv.width = 64; glowCv.height = 64;
    const gcx = glowCv.getContext("2d");
    const grd = gcx.createRadialGradient(32, 32, 2, 32, 32, 30);
    grd.addColorStop(0, "rgba(150,225,255,0.95)");
    grd.addColorStop(0.5, "rgba(90,180,255,0.35)");
    grd.addColorStop(1, "rgba(60,140,255,0)");
    gcx.fillStyle = grd; gcx.fillRect(0, 0, 64, 64);
    const glowTex = new THREE.CanvasTexture(glowCv); shareGpu(glowTex);

    // floating league countdown (canvas texture, redrawn once per second)
    const timerCanvas = document.createElement("canvas");
    timerCanvas.width = 360; timerCanvas.height = 110;
    const timerCtx = timerCanvas.getContext("2d");
    const timerTex = new THREE.CanvasTexture(timerCanvas); shareGpu(timerTex);
    let lastTimerSec = -1;
    function drawLeagueTimer(str) {
      timerCtx.clearRect(0, 0, 360, 110);
      timerCtx.fillStyle = "rgba(26,16,6,0.88)";
      timerCtx.fillRect(4, 4, 352, 102);
      timerCtx.strokeStyle = "#ffb845"; timerCtx.lineWidth = 5;
      timerCtx.strokeRect(6, 6, 348, 98);
      timerCtx.textAlign = "center"; timerCtx.textBaseline = "middle";
      timerCtx.fillStyle = "#ffb845"; timerCtx.font = "bold 19px Georgia";
      timerCtx.fillText("⏳ GARDEN LEAGUE ENDS IN", 180, 32);
      timerCtx.fillStyle = "#ffb845"; timerCtx.font = "bold 42px Georgia";
      timerCtx.fillText(str, 180, 74);
      timerTex.needsUpdate = true;
    }

    // Trophy tally above the league countdown — faux-3D gold lettering
    // (extrusion stack + gradient face + glint) on a canvas.
    //
    // Two lines rather than one: "1 ALL TIME WIN" on a single line would have
    // to shrink to about half height to fit the sprite's ~3.6 world-unit
    // width, and this has to read from across the garden. An "ALL TIME"
    // eyebrow says the same thing and keeps the count big.
    //
    // Both lines share the ORIGINAL canvas and sprite size. The sign already
    // sits near the top of frame in normal play, so a taller sprite would run
    // straight off the screen — the eyebrow has to fit inside the footprint.
    let lastWinsDrawn = -1;
    const winsCanvas = document.createElement("canvas");
    winsCanvas.width = 512; winsCanvas.height = 170;
    const winsCtx = winsCanvas.getContext("2d");
    const winsTex = new THREE.CanvasTexture(winsCanvas); shareGpu(winsTex);
    function drawWinsLine(text, cy, size, depth) {
      const c = winsCtx, cx = winsCanvas.width / 2;
      c.textAlign = "center"; c.textBaseline = "middle";
      c.font = `900 ${size}px 'Trebuchet MS', 'Arial Black', sans-serif`;
      // extrusion stack: dark bronze receding downward
      for (let i = depth; i >= 1; i--) {
        const k = i / depth;
        c.fillStyle = `rgb(${Math.round(112 - 44 * k)}, ${Math.round(72 - 30 * k)}, ${Math.round(20 - 10 * k)})`;
        c.fillText(text, cx, cy + i * (size / 35));
      }
      // outline + gold gradient face
      c.lineWidth = size * 0.107; c.lineJoin = "round"; c.strokeStyle = "rgba(56,30,4,0.92)";
      c.strokeText(text, cx, cy);
      const g = c.createLinearGradient(0, cy - size * 0.52, 0, cy + size * 0.52);
      g.addColorStop(0, "#fff4c8"); g.addColorStop(0.42, "#ffd257");
      g.addColorStop(0.55, "#f2a92c"); g.addColorStop(1, "#c97f14");
      c.fillStyle = g;
      c.fillText(text, cx, cy);
      // top-edge glint
      c.save();
      c.beginPath(); c.rect(0, cy - size * 0.55, winsCanvas.width, size * 0.21); c.clip();
      c.fillStyle = "rgba(255,255,255,0.55)";
      c.fillText(text, cx, cy);
      c.restore();
    }
    function drawWins(n) {
      winsCtx.clearRect(0, 0, winsCanvas.width, winsCanvas.height);
      winsCtx.save();
      winsCtx.letterSpacing = "7px"; // the eyebrow reads as a label, not a word
      drawWinsLine("ALL TIME", 30, 34, 5);
      winsCtx.restore();
      drawWinsLine(`🏆 ${n} WIN${n === 1 ? "" : "S"}`, 104, 76, 9);
      winsTex.needsUpdate = true;
    }

    const player = makePlayer();
    scene.add(player);
    function applyOutfitTo(mesh, o) {
      const u = mesh.userData;
      const hsl = {};
      u.skinMat.color.copy(asLinear(o.skin ?? 0xf2c49b));
      // face/neck share the exact same tone as hands — one skin per preset
      if (u.skinSmoothMat) u.skinSmoothMat.color.copy(u.skinMat.color);
      // hair gets a value floor: pure-black picks lift to very dark brown /
      // blue-black so the mass still catches light instead of going void
      const hairC = asLinear(o.hair ?? 0x5a3a22);
      hairC.getHSL(hsl);
      if (hsl.l < 0.045) hairC.setHSL(hsl.h, Math.max(hsl.s, 0.22), 0.045);
      u.hairMat.color.copy(hairC);
      if (u.hairMatDS) u.hairMatDS.color.copy(hairC);
      // sheen band = one clean value step above the base — generous on dark
      // hair so the mass shows flat facet planes instead of a murky void
      if (u.hairSheenMat) u.hairSheenMat.color.copy(hairC).offsetHSL(0.015, 0.05, hsl.l < 0.12 ? 0.075 : 0.055);
      u.shirtMat.color.copy(asLinear(o.shirt ?? 0x3a72c9));
      u.collarMat.color.copy(asLinear(o.shirt ?? 0x3a72c9)).offsetHSL(0, 0, -0.08);
      u.hoodMat.color.copy(asLinear(o.shirt ?? 0x3a72c9)).offsetHSL(0, 0.02, -0.02);
      // dark shirts crush the derived collar/hood to black — clamp them.
      // The hood floor is deliberately generous: an all-dark hooded outfit
      // must still read as fabric, not a void, at gameplay distance.
      u.collarMat.color.getHSL(hsl);
      if (hsl.l < 0.05) u.collarMat.color.setHSL(hsl.h, hsl.s, 0.05);
      u.hoodMat.color.getHSL(hsl);
      if (hsl.l < 0.09) u.hoodMat.color.setHSL(hsl.h, Math.max(hsl.s, 0.12), 0.09);
      u.bootMat.color.copy(asLinear(o.boots ?? 0x3f2f20));
      if (u.styleMat) {
        // secondary outfit accent — darker/warmer sibling of the shirt so
        // hoodie ribs / raincoat trim always read as the same garment
        u.styleMat.color.copy(asLinear(o.shirt ?? 0x3a72c9)).offsetHSL(0.03, 0.04, -0.13);
        u.styleMat.color.getHSL(hsl);
        if (hsl.l < 0.06) u.styleMat.color.setHSL(hsl.h, Math.max(hsl.s, 0.14), 0.06);
      }
      if (u.blushMat) {
        // blush follows the skin: darker tones get a warmer, subtler flush
        const sk = asLinear(o.skin ?? 0xf2c49b);
        const lum = sk.r * 0.5 + sk.g * 0.35 + sk.b * 0.15;
        u.blushMat.color.copy(sk).offsetHSL(-0.05, 0.28, lum > 0.3 ? -0.04 : 0.12);
        u.blushMat.opacity = lum > 0.3 ? 0.46 : 0.4;
      }
      // unknown/missing keys fall back gracefully (old saves, undressed
      // remote players) — hat/accessory to "none", hairstyle to "crop"
      const hatK = o.hat && (u.hatVariants[o.hat] || o.hat === "none") ? o.hat : "none";
      const accK = o.accessory && u.acc[o.accessory] ? o.accessory : "none";
      const styleK = u.hairStyles[o.hairStyle] ? o.hairStyle : "crop";
      // outfit set — old saves without a style key fall back to the tee
      if (u.styles) {
        const setK = u.styles[o.style] ? o.style : "tee";
        Object.keys(u.styles).forEach((k) => { u.styles[k].visible = setK === k; });
      }
      Object.keys(u.hatVariants).forEach((k) => { u.hatVariants[k].visible = hatK === k; });
      Object.keys(u.hairStyles).forEach((k) => { u.hairStyles[k].visible = styleK === k; });
      const st = u.hairStyles[styleK];
      u.hairMesh = st; // contract: hairMesh is always the active style's mesh
      // hats compress hair: solid hats hide the crown mass but keep tails /
      // nape peeking below the brim; the hood swallows everything but the
      // base fringe; open toppers (crown) ride the full style
      const openHat = hatK === "none" || hatK === "crown";
      // The hat rides ON TOP of the hair. Hats used to delete the crown mass
      // and swap in a fringe stub, which read as the hat breaking the hair.
      st.userData.crownPart.visible = true;
      st.userData.tailPart.visible = true;
      if (st.userData.fringePart) st.userData.fringePart.visible = false;
      // solid hats also press the tail mass down so ponytails/curls emerge
      // BELOW the brim instead of clipping up through it
      st.userData.tailPart.position.y = 0; // the crown is there now; nothing to duck under
      // Sit the hat ON the hair. Measure the two for real rather than
      // guessing: crown heights barely differ between styles, so the thing
      // that decides whether hair pokes through is how tall the HAT is —
      // the cap and the bucket top out below the hair bowl, the beanie and
      // the shroom clear it easily. Reset to the base first so repeated
      // calls can't stack lift on lift.
      const hatBase = u.hatBaseY0 != null ? u.hatBaseY0 : 0.325;
      u.hatG.position.y = hatBase;
      let lift = 0;
      if (!openHat && u.hatVariants[hatK]) {
        mesh.updateMatrixWorld(true);
        const cb = new THREE.Box3().setFromObject(st.userData.crownPart);
        const hb = new THREE.Box3().setFromObject(u.hatVariants[hatK]);
        if (isFinite(cb.max.y) && isFinite(hb.max.y)) {
          lift = Math.max(0, cb.max.y - hb.max.y + 0.022); // 0.022 = visible cap over the hair
        }
      }
      u.hatBaseY = hatBase + lift;
      u.hatG.position.y = u.hatBaseY;
      Object.keys(u.acc).forEach((k) => { u.acc[k].visible = accK === k; });
    }
    // ---- Avatar portrait ---------------------------------------------
    // Renders the player model (current outfit) once into a small offscreen
    // canvas and hands back a data URL, so the stone medallions in the HUD
    // and the Ledger show the real character. Re-rendered only when the
    // outfit changes, never per frame.
    let avatarRenderer = null, avatarUrlCache = null;
    function renderAvatarPortrait() {
      try {
        if (!avatarRenderer) {
          avatarRenderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true });
          avatarRenderer.setSize(256, 256);
          avatarRenderer.setPixelRatio(1);
          avatarRenderer.setClearColor(0x000000, 0);
          avatarRenderer.outputEncoding = renderer.outputEncoding;
        }
        const pScene = new THREE.Scene();
        const hemi = new THREE.HemisphereLight(SRGB(0xffffff), SRGB(0x9aa88f), 0.95);
        const key = new THREE.DirectionalLight(SRGB(0xfff3d8), 1.25);
        key.position.set(2.2, 3.4, 2.6);
        const rim = new THREE.DirectionalLight(SRGB(0xbcd8ff), 0.5);
        rim.position.set(-2.4, 1.8, -2.2);
        pScene.add(hemi, key, rim);

        const model = makePlayer();
        applyOutfitTo(model, G.outfit);
        model.rotation.y = 0.42;           // three-quarter view
        pScene.add(model);

        // Headshot framing: measure the built model and aim at the top of it
        // (hat + head + shoulders) rather than guessing fixed heights.
        model.updateMatrixWorld(true); // required before Box3.setFromObject
        const bb = new THREE.Box3().setFromObject(model);
        const topY = bb.max.y, botY = bb.min.y;
        const h = Math.max(0.001, topY - botY);
        const aimY = topY - h * 0.17;          // just under the hat crown
        const cam = new THREE.PerspectiveCamera(26, 256 / 256, 0.1, 40);
        cam.position.set(0, aimY + h * 0.02, h * 1.62);
        cam.lookAt(0, aimY, 0);
        avatarRenderer.setSize(256, 256);
        avatarRenderer.render(pScene, cam);

        // Trim to the character's silhouette so the medallion can size it
        // predictably (the raw render carries a lot of empty margin).
        const src = avatarRenderer.domElement;
        const cut = document.createElement("canvas");
        cut.width = src.width; cut.height = src.height;
        const cx2 = cut.getContext("2d");
        cx2.drawImage(src, 0, 0);
        const dat = cx2.getImageData(0, 0, cut.width, cut.height).data;
        let minX = cut.width, minY = cut.height, maxX = -1, maxY = -1;
        for (let y = 0; y < cut.height; y++) {
          for (let x = 0; x < cut.width; x++) {
            if (dat[(y * cut.width + x) * 4 + 3] > 8) {
              if (x < minX) minX = x; if (x > maxX) maxX = x;
              if (y < minY) minY = y; if (y > maxY) maxY = y;
            }
          }
        }
        if (maxX > minX && maxY > minY) {
          const pad = 4;
          minX = Math.max(0, minX - pad); minY = Math.max(0, minY - pad);
          maxX = Math.min(cut.width - 1, maxX + pad); maxY = Math.min(cut.height - 1, maxY + pad);
          const out = document.createElement("canvas");
          out.width = maxX - minX + 1; out.height = maxY - minY + 1;
          out.getContext("2d").drawImage(cut, minX, minY, out.width, out.height, 0, 0, out.width, out.height);
          avatarUrlCache = out.toDataURL("image/png");
        } else {
          avatarUrlCache = src.toDataURL("image/png");
        }
        pScene.traverse((o) => { if (o.geometry && o !== model) o.geometry.dispose?.(); });
        return avatarUrlCache;
      } catch (e) { return null; }
    }
    G.avatarPortrait = () => avatarUrlCache || renderAvatarPortrait();
    // Item icons for the Character Studio. The avatar keeps every variant as
    // its own sub-object (userData.hatVariants / acc / hairStyles / styles),
    // so an icon is the WHOLE rig built and dressed as normal, with
    // everything except that one item hidden and the camera framed on its
    // bounds. The item is therefore the real game mesh, lit and posed the
    // same way it will be worn — just without anyone wearing it.
    const ITEM_SLOT = {
      hat:       (u, v) => [u.hatVariants[v]],
      accessory: (u, v) => [u.acc[v]],
      hairStyle: (u, v) => [u.hairStyles[v]],
      // "clothes" is the garment, which means the torso it is cut for:
      // u.styles[v] alone is only the trim (hoodie ribs, overall straps).
      // body is the parent of the ENTIRE rig, so the head and legs come off
      // again below — otherwise showing the shirt shows the whole character.
      style:     (u, v) => [u.body, u.styles && u.styles[v]],
    };
    const ITEM_HIDE = { style: (u) => [u.head, u.legL, u.legR] };
    function renderItemIcon(slot, value, size = 192, spin = null) {
      try {
        if (!avatarRenderer) {
          avatarRenderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true });
          avatarRenderer.setPixelRatio(1);
          avatarRenderer.setClearColor(0x000000, 0);
          avatarRenderer.outputEncoding = renderer.outputEncoding;
        }
        const pScene = new THREE.Scene();
        const hemi = new THREE.HemisphereLight(SRGB(0xffffff), SRGB(0x9aa88f), 1.0);
        const key = new THREE.DirectionalLight(SRGB(0xfff3d8), 1.3);
        key.position.set(2.2, 3.4, 2.6);
        const rim = new THREE.DirectionalLight(SRGB(0xbcd8ff), 0.55);
        rim.position.set(-2.4, 1.8, -2.2);
        pScene.add(hemi, key, rim);

        const model = makePlayer();
        // hats squash the hair and a brim shades a garment, so every item is
        // dressed bare-headed unless the hat IS the item
        const patch = { [slot]: value };
        if (slot !== "hat") patch.hat = "none";
        if (slot !== "accessory") patch.accessory = "none";
        applyOutfitTo(model, { ...G.outfit, ...patch });
        model.rotation.y = spin != null ? spin : 0.5;
        pScene.add(model);

        let parts;
        if (slot === "skin") {
          // no mesh owns "skin" — a faceted bead in the tone reads as a
          // material sample without dragging a face into the tile
          const bead = new THREE.Mesh(new THREE.IcosahedronGeometry(0.3, 1),
            flat(asLinear(value).getHex()));
          bead.position.set(0, 1, 0);
          model.add(bead);
          parts = [bead];
        } else {
          parts = (ITEM_SLOT[slot] ? ITEM_SLOT[slot](model.userData, value) : []).filter(Boolean);
        }
        if (!parts.length) return null; // "none" has nothing to show

        // Two isolation modes. A discrete item (hat, hair, bag) is a variant
        // group: blank the rig, then reveal that one subtree. A GARMENT is
        // cut from the body itself, so there the dressed model is kept as
        // applyOutfitTo left it and only the non-garment parts come off —
        // blanket-revealing the body subtree would also un-hide the hat and
        // accessory variants that the patch had just switched off.
        if (ITEM_HIDE[slot]) {
          ITEM_HIDE[slot](model.userData).forEach((t) => { if (t) t.visible = false; });
        } else {
          model.traverse((o) => { if (o.isMesh) o.visible = false; });
          parts.forEach((t) => {
            t.traverse((o) => { o.visible = true; });
            for (let a = t.parent; a; a = a.parent) a.visible = true;
          });
        }

        // Frame on what is actually ON SCREEN. Box3.setFromObject ignores
        // visibility, so measuring the parts would include the bits just
        // hidden and shrink every tile to fit a phantom body.
        model.updateMatrixWorld(true);
        const bb = new THREE.Box3(), one = new THREE.Box3();
        model.traverse((o) => {
          if (!o.isMesh || !o.visible) return;
          for (let a = o.parent; a; a = a.parent) if (!a.visible) return;
          one.setFromObject(o);
          if (!one.isEmpty()) bb.union(one);
        });
        if (bb.isEmpty()) return null;
        const c = bb.getCenter(new THREE.Vector3());
        const r = Math.max(0.05, bb.getSize(new THREE.Vector3()).length() * 0.5);
        const cam = new THREE.PerspectiveCamera(30, 1, 0.01, 40);
        const d = r / Math.tan((30 * Math.PI) / 180 / 2) * 0.92; // snug, small margin
        cam.position.set(c.x + d * 0.32, c.y + d * 0.28, c.z + d * 0.9);
        cam.lookAt(c);
        avatarRenderer.setSize(size, size);
        avatarRenderer.render(pScene, cam);
        const url = avatarRenderer.domElement.toDataURL("image/png");
        pScene.traverse((o) => { if (o.geometry && o !== model) o.geometry.dispose?.(); });
        return url;
      } catch (e) { return null; }
    }
    G.renderItemIcon = renderItemIcon;

    // Full-body avatar for the Character Studio's left pane. Same rig and
    // lights as the medallion headshot, framed on the whole model and
    // re-rendered whenever the outfit changes.
    let avatarFullCache = null, avatarFullKey = "";
    function renderAvatarFull(size = 384) {
      const key = JSON.stringify(G.outfit);
      if (avatarFullCache && avatarFullKey === key) return avatarFullCache;
      try {
        if (!avatarRenderer) {
          avatarRenderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true });
          avatarRenderer.setPixelRatio(1);
          avatarRenderer.setClearColor(0x000000, 0);
          avatarRenderer.outputEncoding = renderer.outputEncoding;
        }
        const pScene = new THREE.Scene();
        const hemi = new THREE.HemisphereLight(SRGB(0xffffff), SRGB(0x9aa88f), 1.0);
        const key2 = new THREE.DirectionalLight(SRGB(0xfff3d8), 1.3);
        key2.position.set(2.2, 3.4, 2.6);
        const rim = new THREE.DirectionalLight(SRGB(0xbcd8ff), 0.55);
        rim.position.set(-2.4, 1.8, -2.2);
        pScene.add(hemi, key2, rim);
        const model = makePlayer();
        applyOutfitTo(model, G.outfit);
        model.rotation.y = 0.42;
        pScene.add(model);
        model.updateMatrixWorld(true);
        const bb = new THREE.Box3().setFromObject(model);
        const c = bb.getCenter(new THREE.Vector3());
        const h = Math.max(0.001, bb.max.y - bb.min.y);
        const cam = new THREE.PerspectiveCamera(24, 0.62, 0.1, 40);
        cam.position.set(0, c.y, h * 2.9);
        cam.lookAt(0, c.y, 0);
        avatarRenderer.setSize(Math.round(size * 0.62), size);
        avatarRenderer.render(pScene, cam);
        // trim the empty margin, exactly as the medallion headshot does, so
        // the studio can scale the character to fill its pane
        const src = avatarRenderer.domElement;
        const cut = document.createElement("canvas");
        cut.width = src.width; cut.height = src.height;
        const cx2 = cut.getContext("2d");
        cx2.drawImage(src, 0, 0);
        const dat = cx2.getImageData(0, 0, cut.width, cut.height).data;
        let mnX = cut.width, mnY = cut.height, mxX = -1, mxY = -1;
        for (let y = 0; y < cut.height; y++) for (let x = 0; x < cut.width; x++) {
          if (dat[(y * cut.width + x) * 4 + 3] > 8) {
            if (x < mnX) mnX = x; if (x > mxX) mxX = x;
            if (y < mnY) mnY = y; if (y > mxY) mxY = y;
          }
        }
        if (mxX > mnX && mxY > mnY) {
          const out = document.createElement("canvas");
          out.width = mxX - mnX + 1; out.height = mxY - mnY + 1;
          out.getContext("2d").drawImage(cut, mnX, mnY, out.width, out.height, 0, 0, out.width, out.height);
          avatarFullCache = out.toDataURL("image/png");
        } else {
          avatarFullCache = src.toDataURL("image/png");
        }
        avatarFullKey = key;
        pScene.traverse((o) => { if (o.geometry && o !== model) o.geometry.dispose?.(); });
        return avatarFullCache;
      } catch (e) { return null; }
    }
    G.avatarFull = () => renderAvatarFull();
    // Eli (and any other spoken scene) pulls the music down so the dialogue
    // reads; it lifts back when the conversation closes.
    G.duckMusic = (on) => {
      musicDucked = !!on;
      if (trackGain && AC) {
        trackGain.gain.setTargetAtTime(musicDucked ? MUSIC_DUCKED : MUSIC_FULL, AC.currentTime, 0.28);
      }
    };


    // NOTE: no syncHud() here — applyOutfit runs during scene setup, before
    // the HUD's own locals exist. The 0.15s hud tick publishes the new
    // portrait a moment later.
    function applyOutfit() { applyOutfitTo(player, G.outfit); avatarUrlCache = null; renderAvatarPortrait(); }
    applyOutfit();
    function saveOutfit() {
      try { if (window.storage) window.storage.set("garden-outfit", JSON.stringify(G.outfit)); } catch (e) {}
    }
    (async () => {
      try {
        if (!window.storage) return;
        const r = await window.storage.get("garden-outfit");
        if (r && r.value) {
          Object.assign(G.outfit, JSON.parse(r.value));
          if (G.outfit.hat === "hood") G.outfit.hat = "none"; // hood was removed from the roster
          applyOutfit();
        }
      } catch (e) { /* first visit */ }
    })();
    G.setOutfit = (patch) => { Object.assign(G.outfit, patch); applyOutfit(); saveOutfit(); SFX.click(); };
    G.styleActive = false;
    // dev-only: exercise the remote-live-player dressing path (partial /
    // legacy outfits) without needing a second presence connection
    G.__dressTest = (o) => {
      const m = makePlayer();
      applyOutfitTo(m, o || {});
      m.traverse((x) => { if (x.geometry) x.geometry.dispose?.(); });
      return true;
    };

    // ---- Live groupmates in the community garden (presence + broadcast) ----
    // Joined only while on the CHURCH map; every member of the active garden
    // sees each other walk around in realtime, wearing their real outfits.
    let liveCh = null, livePlayers = {}, liveSendGate = 0;
    const lastSent = { x: 0, z: 0, a: 0, m: false, t: -9 };
    const MY_LIVE_ID = window.YGTEEV?.profile?.id || null;
    function makeNameTag(name) {
      const cv = document.createElement("canvas");
      cv.width = 256; cv.height = 64;
      const c = cv.getContext("2d");
      c.textAlign = "center"; c.textBaseline = "middle";
      c.font = "bold 30px 'Trebuchet MS', sans-serif";
      const tw = Math.min(240, c.measureText(name).width + 36);
      const x0 = 128 - tw / 2, r = 17;
      c.beginPath();
      c.moveTo(x0 + r, 6);
      c.arcTo(x0 + tw, 6, x0 + tw, 58, r);
      c.arcTo(x0 + tw, 58, x0, 58, r);
      c.arcTo(x0, 58, x0, 6, r);
      c.arcTo(x0, 6, x0 + tw, 6, r);
      c.closePath();
      c.fillStyle = "rgba(18,34,54,0.62)"; c.fill();
      c.fillStyle = "#eaf6ff";
      c.fillText(name, 128, 33, 224);
      const tex = new THREE.CanvasTexture(cv);
      const sp = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, transparent: true, depthWrite: false }));
      sp.scale.set(1.7, 0.42, 1);
      sp.position.y = 2.35; // clear of the hat brim — 1.82 clipped behind it
      return sp;
    }
    function ensureLivePlayer(id, meta) {
      let lp = livePlayers[id];
      if (!lp) {
        const mesh = makePlayer();
        applyOutfitTo(mesh, (meta && meta.outfit) || {});
        mesh.position.set(0, -60, 0); // parked underground until the first position arrives
        const tag = makeNameTag((meta && meta.name) || "Gardener");
        mesh.add(tag);
        scene.add(mesh);
        lp = livePlayers[id] = { mesh, tag, name: (meta && meta.name) || null, tgt: null, lastMsg: G.time, hopT: 0, dressed: !!(meta && meta.outfit) };
      } else if (meta) {
        if (meta.outfit && !lp.dressed) {
          applyOutfitTo(lp.mesh, meta.outfit);
          lp.dressed = true;
        }
        // a position packet can create the avatar before presence meta lands —
        // swap the placeholder "Gardener" tag for the real name when it arrives
        if (meta.name && meta.name !== lp.name) {
          lp.mesh.remove(lp.tag);
          lp.tag.material.map.dispose(); lp.tag.material.dispose();
          lp.tag = makeNameTag(meta.name);
          lp.mesh.add(lp.tag);
          lp.name = meta.name;
        }
      }
      return lp;
    }
    function removeLivePlayer(id) {
      const lp = livePlayers[id];
      if (!lp) return;
      scene.remove(lp.mesh);
      delete livePlayers[id];
    }
    function joinLiveGarden() {
      leaveLiveGarden();
      const api = window.YGTEEV_API;
      if (!api || !api.joinGarden || !MY_LIVE_ID) return;
      const gid = G.activeGarden?.id || window.YGTEEV?.profile?.groupId;
      if (!gid) return;
      liveCh = api.joinGarden(gid, {
        me: { id: MY_LIVE_ID, name: window.YGTEEV?.profile?.name || "Gardener", outfit: { ...G.outfit } },
        onSync: (state) => {
          const seen = {};
          for (const key in state) {
            if (key === MY_LIVE_ID) continue;
            seen[key] = true;
            ensureLivePlayer(key, state[key][0]);
          }
          for (const id in livePlayers) if (!seen[id]) removeLivePlayer(id);
        },
        onPos: (p) => {
          if (!p || p.i === MY_LIVE_ID) return;
          const lp = ensureLivePlayer(p.i, null);
          lp.tgt = p;
          lp.lastMsg = G.time;
        },
        onAct: (p) => {
          if (!p || p.i === MY_LIVE_ID) return;
          const lp = livePlayers[p.i];
          if (lp) {
            lp.hopT = 0.32;
            spawnBurst(lp.mesh.position.x, lp.mesh.position.z, 0x7dfcd0, 6, { glow: true, vy: 2, y0: 0.5 });
          }
        },
      });
    }
    function leaveLiveGarden() {
      if (liveCh) { try { liveCh.leave(); } catch (e) {} liveCh = null; }
      for (const id in livePlayers) scene.remove(livePlayers[id].mesh);
      livePlayers = {};
      lastSent.t = -9;
    }
    if (import.meta.env && import.meta.env.DEV) {
      window.__BY_LIVE = () => ({ ch: !!liveCh, players: Object.keys(livePlayers).map((id) => ({ id, pos: livePlayers[id].mesh.position.toArray(), tgt: livePlayers[id].tgt })) });
    }

    // floating quest marker for Eli's tasks
    const questMarker = new THREE.Group();
    {
      const qCone = new THREE.Mesh(new THREE.ConeGeometry(0.24, 0.45, 8),
        new THREE.MeshStandardMaterial({ color: SRGB(0xffb845), emissive: SRGB(0xff9a20), emissiveIntensity: 0.9, flatShading: true }));
      qCone.rotation.x = Math.PI;
      const qHalo = new THREE.Sprite(new THREE.SpriteMaterial({ map: glowTex, color: SRGB(0xffb845), transparent: true, opacity: 0.5, depthWrite: false, blending: THREE.AdditiveBlending }));
      qHalo.scale.set(1.15, 1.15, 1);
      qHalo.position.y = 0.12;
      questMarker.add(qCone, qHalo);
      questMarker.visible = false;
      scene.add(questMarker);
    }

    // ---- Garden expansion: hoe, plot kits, fence deeds (all XP) ----
    function syncHomePlotCount() {
      while (G.homePlots.length < 6 + G.build.extraPlots.length) G.homePlots.push({ seed: null, plantedAt: 0 });
    }
    function saveBuild() {
      try { if (window.storage) window.storage.set("garden-build", JSON.stringify(G.build)); } catch (e) {}
    }
    (async () => {
      try {
        if (!window.storage) { stateLoaded = true; }
        else {
          const r = await window.storage.get("garden-build").catch(() => null);
          if (r && r.value) {
            Object.assign(G.build, JSON.parse(r.value));
            syncHomePlotCount(); // extra plots exist before state restores into them
          }
          const s = await window.storage.get("garden-state").catch(() => null);
          if (s && s.value) applyState(JSON.parse(s.value));
          if ((r && r.value) || (s && s.value)) { if (G.map === "HOME") loadMap("HOME"); }
        }
      } catch (e) { /* fresh save */ }
      stateLoaded = true;
      // Glowlands: hydrate glow-state alongside the garden save, then read the
      // lantern through its source ladder (server > derivation > Spark).
      // Read-only + optional-safe; a failure here never blocks the garden.
      try { await readGlowStateRaw(); } catch (e) {}
      try { initLantern(glowCtx); } catch (e) {}
    })();
    G.startCounter = (kind) => {
      if (G.counterActive) return;
      G.counterActive = true;
      G.counterKind = kind;
      if (counterKeeper) {
        playerAngle = Math.atan2(counterKeeper.x - playerPos.x, counterKeeper.z - playerPos.z);
        player.rotation.y = playerAngle;
      }
      SFX.click();
      if (G.reqCounter) G.reqCounter(kind);
    };
    G.endCounter = () => { G.counterActive = false; G.counterKind = null; };

    // ---- Old Eli's welcome: a one-time sage introduction ----
    function saveIntroDone() {
      try { if (window.storage) window.storage.set("garden-intro", "1"); } catch (e) {}
    }
    G.saveIntroDone = saveIntroDone;
    G.startIntro = () => {
      if (G.introActive || G.map !== "HOME" || gardener) return;
      G.introActive = true;
      G.introLock = true; // the player watches; no wandering off mid-welcome
      G.introPage = null;
      G.introGave = false;
      G.introGiftClaimed = {};
      gardener = makeVillager(4.6, -3.4, 0, { shirt: 0x7a8a5a, hat: "straw", beard: true, cane: true, manual: true, solid: false });
      gardener.rotation.y = Math.atan2(playerPos.x - 4.6, playerPos.z + 3.4);
      gardenerCtl = { mode: "approach", t: 0, post: [4.6, -3.4], postRot: 0, announced: false };
      playerAngle = Math.atan2(4.6 - playerPos.x, -3.4 - playerPos.z);
      player.rotation.y = playerAngle;
      SFX.click();
    };
    G.setIntroFocus = (f) => { G.introFocus = f; };
    // After the Berry Market flyer: pan toward the town road and float a
    // glowing arrow pointing the way. Clears itself after ~5 seconds.
    G.startMarketCue = () => {
      if (G.map !== "HOME" || marketArrow) return;
      const g = new THREE.Group();
      const gold = new THREE.MeshStandardMaterial({ color: SRGB(0xffc94a), emissive: SRGB(0xffb32e), emissiveIntensity: 0.9, flatShading: true, roughness: 0.35 });
      const head = new THREE.Mesh(new THREE.ConeGeometry(0.42, 0.9, 6), gold);
      head.rotation.z = -Math.PI / 2; // cone +Y -> +X (toward the town exit)
      head.position.x = 0.75;
      const shaft = new THREE.Mesh(new THREE.BoxGeometry(1.1, 0.3, 0.3), gold);
      shaft.position.x = -0.15;
      const halo = new THREE.Sprite(new THREE.SpriteMaterial({ map: glowTex, color: SRGB(0xffd76a), transparent: true, opacity: 0.5, depthWrite: false, blending: THREE.AdditiveBlending }));
      halo.scale.set(3.2, 3.2, 1);
      g.add(shaft, head, halo);
      g.position.set(13.0, 2.1, 3.4); // over the east road, aimed at the exit
      worldGroup.add(g);
      marketArrow = g;
      G.marketCueT = 5;
      SFX.sparkle();
    };
    G.clearMarketCue = () => {
      if (marketArrow) { worldGroup.remove(marketArrow); marketArrow = null; }
      G.marketCueT = 0;
    };
    G.onIntroEvent = (ev) => { G.introTaskDone = ev; }; // game-loop advances the story
    function applyIntroPage(n) {
      G.introPage = n;
      G.introLock = true;
      const pg = INTRO_PAGES[n];
      G.introFocus = (pg && pg.focus) || "eli";
      playVoiceClip(n);
    }
    G.introAdvance = () => {
      if (G.introPage == null) return;
      const pg = INTRO_PAGES[G.introPage];
      if (!pg) { G.introPage = null; return; }
      // gift gate: a page that gifts seeds shows the "add to pocket" card
      // AFTER Eli's line, before advancing. Claiming re-calls this.
      if (pg.gift && !G.introGiftClaimed[G.introPage]) {
        if (G.reqSeedGift) G.reqSeedGift({ ...pg.gift, page: G.introPage });
        return;
      }
      if (pg.end) {
        G.introPage = null;
        stopVoiceClip();
        G.finishIntro();
      } else if (pg.task) {
        G.introPage = null;
        stopVoiceClip();
        G.introTask = pg.task;
        G.introTaskDone = null;
        G.introLock = false;
        G.introFocus = null;
      } else {
        applyIntroPage(G.introPage + 1);
      }
      syncHud();
    };
    G.replayIntro = () => {
      try { if (window.storage) window.storage.delete("garden-intro"); } catch (e) {}
      if (G.map === "HOME" && !G.introActive && !gardener) {
        G.hunger = 100; G.hungerAlertT = 0; // Ember sits out the replay happy
        G.startIntro();
        return true;
      }
      toast("Return to the Home Meadow to replay Eli's welcome!", "warn");
      return false;
    };
    // Grant an intro seed gift once (the "ADD TO POCKET" button), then let
    // the story continue past the page.
    G.claimIntroGift = (page) => {
      const pg = INTRO_PAGES[page];
      if (!pg || !pg.gift || G.introGiftClaimed[page]) return;
      G.introGiftClaimed[page] = true;
      G.inv.seeds[pg.gift.key] = (G.inv.seeds[pg.gift.key] || 0) + pg.gift.n;
      SFX.itemGet();
      spawnBurst(playerPos.x, playerPos.z, SEEDS[pg.gift.key].color, 7, { glow: true, vy: 2.2, y0: 0.8 });
      syncHud();
    };
    G.finishIntro = () => {
      G.introTask = null; G.introTaskDone = null;
      G.introPage = null;
      G.introActive = false;
      G.introFocus = null; // camera glides back to the player
      G.introLock = false; // controls return immediately — Eli strolls off on his own
      saveIntroDone();
      if (gardener) {
        gardenerCtl = { mode: "leave", leavePath: G.youthGroup ? [[-13.2, 3], [-24, 3]] : [[-9.9, 3]], leaveIdx: 0, t: 0, post: [0, 0], postRot: 0 };
      }
    };
    G.skipIntro = () => {
      stopVoiceClip();
      // don't leave a skipper empty-handed — grant any unclaimed starter gifts
      INTRO_PAGES.forEach((pg, i) => { if (pg.gift) G.claimIntroGift(i); });
      G.introTask = null; G.introTaskDone = null;
      G.introCelebrate = null; G.introCelebrateT = 0;
      G.introPage = null;
      G.introActive = false;
      G.introFocus = null;
      G.introLock = false;
      saveIntroDone();
      if (gardener) { worldGroup.remove(gardener); gardener = null; }
    };

    // ---- Community garden welcome (first CHURCH entry, members only) ----
    function saveChurchIntroDone() {
      G.churchIntroDone = true;
      try { if (window.storage) window.storage.set("garden-church-intro", "1"); } catch (e) {}
    }
    G.startChurchIntro = () => {
      if (G.churchIntroDone || G.churchIntroPage != null || G.map !== "CHURCH" || !gardener) return;
      loadChurchVoices();
      G.introLock = true;
      G.introFocus = "eli";
      // his post is clear across the garden — pop him a few steps out along
      // that line so the walk-up to the newcomer reads as a short greeting
      const dx = gardener.position.x - playerPos.x, dz = gardener.position.z - playerPos.z;
      const d = Math.hypot(dx, dz) || 1;
      gardener.position.set(playerPos.x + (dx / d) * 4.5, terrainY(playerPos.x, playerPos.z), playerPos.z + (dz / d) * 4.5);
      gardener.visible = true;
      gardenerCtl = { mode: "approach", church: true, t: 0, post: [-3.4, 3.0], postRot: 2.4, announced: false };
    };
    G.churchStartPage = (n) => {
      G.churchIntroPage = n;
      G.introLock = true;
      G.introFocus = "eli";
      playVoiceClip(n, 0, { bufs: churchVoiceBufs, pageOf: () => G.churchIntroPage });
      if (G.reqChurchIntro) G.reqChurchIntro(n);
    };
    const endChurchIntro = () => {
      stopVoiceClip();
      G.churchIntroPage = null;
      G.introFocus = null;
      G.introLock = false;
      saveChurchIntroDone();
      if (gardener) gardenerCtl.mode = "return"; // back to his post, not off the map
      if (G.reqChurchIntro) G.reqChurchIntro(null);
    };
    G.churchIntroNext = () => {
      if (G.churchIntroPage == null) return;
      const pg = CHURCH_INTRO_PAGES[G.churchIntroPage];
      if (!pg || pg.end) { endChurchIntro(); return; }
      G.churchStartPage(G.churchIntroPage + 1);
    };
    G.skipChurchIntro = () => endChurchIntro();

    G.setYouthGroup = (v) => {
      const was = G.youthGroup;
      G.youthGroup = !!v;
      try { if (window.storage) window.storage.set("garden-youthgroup", G.youthGroup ? "1" : "0"); } catch (e) {}
      if (G.youthGroup && !was) {
        if (G.map === "HOME") {
          loadMap("HOME");
          setTimeout(() => {
            spawnBurst(-13.2, 3, 0xffb845, 14, { glow: true, vy: 2.6, spread: 2.6, y0: 0.6 });
            spawnBurst(-11.5, 3, 0x8fd8ff, 8, { glow: true, vy: 2.2, spread: 1.4, y0: 0.5 });
          }, 60);
        }
        toast("🔨 The youth group rebuilt the bridge! The way west is open.", "gold");
        SFX.level();
      }
      syncHud();
    };
    (async () => {
      try {
        if (window.YGTEEV_MEMBER === true) { G.youthGroup = true; return; }
        if (!window.storage) return;
        const r = await window.storage.get("garden-youthgroup").catch(() => null);
        if (r && r.value === "1") { G.youthGroup = true; if (G.map === "HOME") loadMap("HOME"); }
      } catch (e) {}
    })();

    let introTimer = null;
    // Eli's intro must not start behind the splash — wait for dismissal.
    const scheduleIntro = () => {
      introTimer = setTimeout(() => {
        if (G.splashActive) return scheduleIntro();
        G.startIntro();
      }, 1500);
    };
    (async () => {
      try {
        if (!window.storage) return;
        const r = await window.storage.get("by-muted").catch(() => null);
        if (r && r.value === "1") {
          AUDIO.muted = true;
          if (audioOut) audioOut.gain.value = 0;
          setMuted(true); // keep the HUD button's icon in sync
        }
      } catch (e) {}
    })();
    (async () => {
      try {
        if (!window.storage) { scheduleIntro(); return; }
        const r = await window.storage.get("garden-intro").catch(() => null);
        if (!r || !r.value) scheduleIntro();
      } catch (e) {
        scheduleIntro();
      }
    })();
    (async () => {
      try {
        if (!window.storage) return;
        const rq = await window.storage.get("garden-eli-quiz-n").catch(() => null);
        if (rq && rq.value) G.eliQuizN = parseInt(rq.value, 10) || 0;
        const r = await window.storage.get("garden-church-intro").catch(() => null);
        if (r && r.value === "1") G.churchIntroDone = true;
      } catch (e) {}
    })();
    G.buyHoe = () => {
      if (G.build.hoe) { toast("You already own the hoe!", "warn"); return false; }
      if (G.xp < 500) { toast("Not enough XP — the hoe costs ✨500", "warn"); return false; }
      G.xp -= 500; G.build.hoe = true; saveBuild(); syncXpSpend(500, "hoe");
      SFX.pass();
      toast("⛏️ Hoe acquired! A 🔨 Build button awaits at your home garden.");
      return true;
    };
    G.buyDeed = () => {
      const next = FENCE_TIERS[G.build.fenceTier + 1];
      if (!next) { toast("Your fence is at its grandest already!", "warn"); return false; }
      if (G.xp < next.cost) { toast(`Not enough XP — this deed costs ✨${next.cost}`, "warn"); return false; }
      G.xp -= next.cost; G.build.fenceTier++; saveBuild(); syncXpSpend(next.cost, "fence_deed");
      SFX.level();
      toast("🚧 The fence grows! Fresh ground opens for planting.", "gold");
      if (G.map === "HOME") loadMap("HOME");
      return true;
    };
    G.placePlot = () => {
      if (!G.buildActive || !G.ghostOk || !G.ghostCell) return;
      const cost = kitCostAt(G.build.kitsBought);
      if (G.xp < cost) { toast(`Not enough XP — this kit costs ✨${cost}`, "warn"); return; }
      G.xp -= cost;
      syncXpSpend(cost, "plot_kit");
      G.build.kitsBought++;
      const cell = G.ghostCell;
      G.build.extraPlots.push({ x: cell.x, z: cell.z });
      G.homePlots.push({ seed: null, plantedAt: 0 });
      cell.taken = true;
      if (G.addLivePlot) G.addLivePlot(cell.x, cell.z, G.homePlots.length - 1);
      saveBuild();
      SFX.plant(); SFX.sparkle();
      G.playerHopT = 0.32;
      toast(`🧱 New plot built! (−✨${cost})`, "gold");
    };
    const playerPos = new THREE.Vector3(0, 0, 4);
    let playerAngle = 0, stepT = 0.2;

    const ring = new THREE.Mesh(
      new THREE.TorusGeometry(1.15, 0.05, 8, 32),
      new THREE.MeshStandardMaterial({ color: SRGB(0xffd76a), emissive: SRGB(0xffc430), emissiveIntensity: 0.9, transparent: true, opacity: 0.9 })
    );
    ring.rotation.x = -Math.PI / 2;
    ring.visible = false;
    scene.add(ring);

    function clearWorld() {
    // Free the GPU side of a map we are done with. scene.remove() only
    // detaches: three.js keeps the vertex buffers and textures alive until
    // something calls dispose(), so without this every map change leaked
    // ~375 geometries and a few textures that never came back. The JS heap
    // looked fine throughout, because the leak is entirely GPU-side.
    function disposeWorld(root) {
      const seen = new Set();
      let geo = 0, mat = 0, tex = 0;
      const dropTex = (t) => {
        if (!t || SHARED_GPU.has(t) || seen.has(t)) return;
        seen.add(t); t.dispose(); tex++;
      };
      root.traverse((o) => {
        if (o.geometry && !SHARED_GPU.has(o.geometry) && !seen.has(o.geometry)) {
          seen.add(o.geometry); o.geometry.dispose(); geo++;
        }
        const mats = Array.isArray(o.material) ? o.material : (o.material ? [o.material] : []);
        for (const m of mats) {
          if (!m || SHARED_GPU.has(m) || seen.has(m)) continue;
          seen.add(m);
          // a material's own textures go too, unless they're shared canvases
          ["map", "alphaMap", "emissiveMap", "normalMap", "roughnessMap", "bumpMap"]
            .forEach((k) => dropTex(m[k]));
          m.dispose(); mat++;
        }
      });
      return { geo, mat, tex };
    }

      // Glowlands handles first: their dispose() unhooks listeners (e.g. the
      // Lantern Post's onLanternChange subscription) before the group drops.
      if (glowHomeHandle) { try { glowHomeHandle.dispose(); } catch (e) {} glowHomeHandle = null; }
      if (glowMeadowHandle) { try { glowMeadowHandle.dispose(); } catch (e) {} glowMeadowHandle = null; }
      if (glowRoadHandle) { try { glowRoadHandle.dispose(); } catch (e) {} glowRoadHandle = null; }
      if (worldGroup) { scene.remove(worldGroup); disposeWorld(worldGroup); }
      worldGroup = new THREE.Group();
      scene.add(worldGroup);
      plotNodes = []; exits = []; hotspots = []; dragon = null;
      butterflies = []; glowNodes = []; clouds = []; embers = []; smokes = []; sparkles = null; caveLight = null; npcs = []; zzz = [];
      gardener = null; gardenerCtl = { mode: "post", t: 0, post: [0, 0], postRot: 0 }; bursts = []; floaties = []; timerSprite = null; lastTimerSec = -1; winsSprite = null; lastWinsDrawn = -1; water = null; foams = []; riverFoam = null; swayers = []; petals = []; fountainFx = null; goldBag = null; redBagMeshes = {}; shopWords = []; emberBar = null; turtle = null; G.turtleSeq = null;
      throwns.forEach((t) => worldGroup.remove(t.m)); throwns = [];
      buildCells = []; ghostMesh = null; buildMarkers = null; counterKeeper = null;
      // the "already greeted" latch belongs to the keeper we just destroyed —
      // without this, leaving a shop mid-latch blocks the auto-greeting in the
      // next shop you walk into
      G.counterNear = false;
      colliders = [];
      pathRoutes = []; rockBases.length = 0;
    }

    function refreshPlotVisual(node) {
      if (node.plant) { node.plotMesh.remove(node.plant); node.plant = null; }
      const p = node.data();
      if (p.seed) {
        if (node.special) {
          const age = G.time - p.plantedAt;
          const stage = age >= 300 ? 3 : age >= 150 ? 2 : age >= 60 ? 1 : 0;
          node.stage = stage;
          node.plant = buildGlowTree(stage, p.seed);
          node.plant.position.y = 0.27;
        } else {
          const elapsed = G.time - p.plantedAt;
          const total = SEEDS[p.seed].grow;
          const stage = p.regrowAt != null ? (G.time >= p.regrowAt ? 2 : 1)
            : elapsed >= total ? 2 : elapsed >= total * 0.5 ? 1 : 0;
          node.stage = stage;
          node.plant = buildPlantMesh(p.seed, stage, false);
          node.plant.position.y = 0.2;
        }
        node.plotMesh.add(node.plant);
      } else node.stage = -1;
    }

    // radial progress ring over a plant growing toward its FIRST maturity —
    // a scene sprite, so it stays visible even while dialogue hides the DOM
    // readouts (the onboarding case)
    // Sacred-tree countdown: while it grows, time to maturity; once mature,
    // time to the next auto-harvested berry. Mirrors the home garden's
    // regrow badge so both gardens read the same way.
    function updateGlowBadge(node, p, age) {
      const MAT = 300;
      const active = !!p.seed;
      if (!active) {
        if (node.glowBadge) {
          node.plotMesh.remove(node.glowBadge);
          node.glowBadge.material.map.dispose();
          node.glowBadge.material.dispose();
          node.glowBadge = null;
        }
        return;
      }
      if (!node.glowBadge) {
        const cv = document.createElement("canvas");
        cv.width = 230; cv.height = 84;
        const tex = new THREE.CanvasTexture(cv);
        const sp = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, transparent: true, depthWrite: false, fog: false }));
        sp.scale.set(1.34, 0.49, 1);
        sp.position.set(0, 2.42, 0); // refined below from the tree's real bounds
        sp.userData = { cv, tex, lastKey: "" };
        node.plotMesh.add(sp);
        node.glowBadge = sp;
      }
      const growing = age < MAT;
      const yi = SEEDS[p.seed]?.yieldInt || 300;
      const secs = growing
        ? Math.max(0, Math.ceil(MAT - age))
        : Math.max(0, Math.ceil((p.nextYield != null ? p.nextYield : p.plantedAt + MAT + yi) - G.time));
      const ud = node.glowBadge.userData;
      const key = (growing ? "g" : "y") + secs;
      if (key !== ud.lastKey) {
        ud.lastKey = key;
        const c = ud.cv.getContext("2d");
        c.clearRect(0, 0, 230, 84);
        const rr = (x, y, w, h, r) => {
          c.beginPath();
          c.moveTo(x + r, y);
          c.arcTo(x + w, y, x + w, y + h, r);
          c.arcTo(x + w, y + h, x, y + h, r);
          c.arcTo(x, y + h, x, y, r);
          c.arcTo(x, y, x + w, y, r);
          c.closePath();
        };
        rr(6, 10, 218, 62, 26);
        c.fillStyle = "rgba(14,26,34,0.86)"; c.fill();
        c.lineWidth = 4;
        c.strokeStyle = growing ? "#7dd0ff" : "#7dfcd0";
        c.stroke();
        c.textAlign = "center"; c.textBaseline = "middle";
        c.fillStyle = growing ? "#bfe6ff" : "#9dffdf";
        c.font = "bold 34px Georgia";
        const mm = Math.floor(secs / 60), ss = String(secs % 60).padStart(2, "0");
        c.fillText(`${growing ? "🌱" : "✨"} ${mm}:${ss}`, 115, 43);
        ud.tex.needsUpdate = true;
      }
      // Sit the badge above the tree's ACTUAL top rather than a guessed
      // height — canopies differ per stage and per tier, and eyeballed
      // offsets kept leaving the badge buried in the leaves. Measured once
      // per growth stage, not per frame.
      const bd = node.glowBadge.userData;
      if (bd.forStage !== node.stage) {
        bd.forStage = node.stage;
        let top = 2.42;
        if (node.plant) {
          node.plant.updateMatrixWorld(true);
          const bb = new THREE.Box3().setFromObject(node.plant);
          const base = node.plotMesh.getWorldPosition(new THREE.Vector3()).y;
          if (isFinite(bb.max.y)) top = (bb.max.y - base) + 0.62; // clear of the leaves
        }
        bd.topY = Math.max(1.9, top);
      }
      node.glowBadge.position.y = bd.topY + Math.sin(G.time * 1.6 + node.idx) * 0.05;
    }

    function updateGrowRing(node, p, stage) {
      const active = p.seed && p.regrowAt == null && stage !== 2 && !node.special;
      if (!active) {
        if (node.growRing) {
          node.plotMesh.remove(node.growRing);
          node.growRing.material.map.dispose();
          node.growRing.material.dispose();
          node.growRing = null;
        }
        return;
      }
      if (!node.growRing) {
        const cv = document.createElement("canvas");
        cv.width = 96; cv.height = 96;
        const tex = new THREE.CanvasTexture(cv);
        const sp = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, transparent: true, depthWrite: false }));
        sp.scale.set(0.62, 0.62, 1);
        sp.position.set(0, 1.35, 0);
        sp.userData = { cv, tex, lastStep: -1 };
        node.plotMesh.add(sp);
        node.growRing = sp;
      }
      const total = SEEDS[p.seed].grow;
      const pct = Math.max(0, Math.min(1, (G.time - p.plantedAt) / total));
      const ud = node.growRing.userData;
      const step = Math.round(pct * 48);
      if (step !== ud.lastStep) {
        ud.lastStep = step;
        const c = ud.cv.getContext("2d");
        c.clearRect(0, 0, 96, 96);
        c.beginPath(); c.arc(48, 48, 40, 0, Math.PI * 2);
        c.fillStyle = "rgba(58,38,20,0.78)"; c.fill();
        c.lineWidth = 5; c.strokeStyle = "rgba(30,18,8,0.9)"; c.stroke();
        c.beginPath(); c.arc(48, 48, 32, -Math.PI / 2, -Math.PI / 2 + Math.max(0.02, pct) * Math.PI * 2);
        c.lineWidth = 9; c.lineCap = "round"; c.strokeStyle = "#f0c261"; c.stroke();
        c.font = "30px serif"; c.textAlign = "center"; c.textBaseline = "middle";
        c.fillText("🌱", 48, 50);
        ud.tex.needsUpdate = true;
      }
      node.growRing.position.y = 1.35 + Math.sin(G.time * 1.6 + node.idx) * 0.05;
    }

    // floating "next fruit in M:SS" pill over home plants that are regrowing after a harvest
    function updateRegrowBadge(node, p, stage) {
      const active = p.seed && p.regrowAt != null && stage !== 2;
      if (!active) {
        if (node.regrowSprite) {
          node.plotMesh.remove(node.regrowSprite);
          node.regrowSprite.material.map.dispose();
          node.regrowSprite.material.dispose();
          node.regrowSprite = null;
        }
        return;
      }
      if (!node.regrowSprite) {
        const cv = document.createElement("canvas");
        cv.width = 220; cv.height = 108;
        const tex = new THREE.CanvasTexture(cv);
        const sp = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, transparent: true, depthWrite: false, fog: false }));
        sp.scale.set(1.55, 0.76, 1);
        sp.position.set(0, 1.62, 0);
        sp.userData = { cv, tex, lastKey: "" };
        node.plotMesh.add(sp);
        node.regrowSprite = sp;
      }
      const sec = Math.max(0, Math.ceil(p.regrowAt - G.time));
      const cost = Math.max(1, Math.ceil(sec / 10));
      const holding = typeof rushHold !== "undefined" && rushHold && rushHold.idx === node.idx;
      const holdPct = holding ? Math.min(1, (performance.now() - rushHold.t0) / 900) : 0;
      const ud = node.regrowSprite.userData;
      const key = sec + "|" + cost + "|" + Math.round(holdPct * 30);
      if (key !== ud.lastKey) {
        ud.lastKey = key;
        const c = ud.cv.getContext("2d");
        c.clearRect(0, 0, 220, 108);
        const rr = (x, y, w, h, r) => {
          c.beginPath();
          c.moveTo(x + r, y);
          c.arcTo(x + w, y, x + w, y + h, r);
          c.arcTo(x + w, y + h, x, y + h, r);
          c.arcTo(x, y + h, x, y, r);
          c.arcTo(x, y, x + w, y, r);
          c.closePath();
        };
        rr(6, 6, 208, 96, 20);
        c.fillStyle = "rgba(26,16,6,0.84)"; c.fill();
        c.strokeStyle = "#ffb845"; c.lineWidth = 4; c.stroke();
        // hold progress: a gold fill sweeping the plaque from the left
        if (holdPct > 0) {
          c.save();
          rr(6, 6, 208, 96, 20); c.clip();
          c.fillStyle = "rgba(255,184,69,0.30)";
          c.fillRect(6, 6, 208 * holdPct, 96);
          c.restore();
        }
        c.textAlign = "center"; c.textBaseline = "middle";
        c.fillStyle = "#ffb845"; c.font = "bold 34px Georgia";
        c.fillText(`⏳ ${Math.floor(sec / 60)}:${String(sec % 60).padStart(2, "0")}`, 110, 34);
        c.fillStyle = holding ? "#ffe9b8" : "rgba(255,226,180,0.85)";
        c.font = "800 22px 'Baloo 2', 'Trebuchet MS', sans-serif";
        c.fillText(holding ? "Hold to hurry…" : `HOLD ⏩ ${cost} ✦`, 110, 76);
        ud.tex.needsUpdate = true;
      }
      node.regrowSprite.position.y = 1.62 + Math.sin(G.time * 1.6 + node.idx) * 0.05;
    }

    function addPlots(arr, positions, special) {
      positions.forEach(([x, z], i) => {
        const plotMesh = makePlot(x, z, special);
        worldGroup.add(plotMesh);
        const node = { plotMesh, data: () => arr[i], idx: i, x, z, special, plant: null, stage: -1, arr };
        plotNodes.push(node);
        refreshPlotVisual(node);
      });
    }

    function addChurchPlotField(positions) {
      const n = positions.length;
      // dark tilled rims with rich brown soil mounds — proper dirt plots
      const rims = new THREE.InstancedMesh(new THREE.BoxGeometry(0.86, 0.06, 0.86), flat(new THREE.Color(PAL.soil).offsetHSL(0, -0.04, -0.13), { roughness: 1 }), n);
      const soils = new THREE.InstancedMesh(new THREE.BoxGeometry(0.72, 0.18, 0.72), flat(0xffffff, { roughness: 1 }), n);
      rims.receiveShadow = true; soils.receiveShadow = true; soils.castShadow = true;
      const m = new THREE.Matrix4();
      const scol = new THREE.Color();
      positions.forEach(([x, z], i) => {
        m.makeTranslation(x, 0.1, z); rims.setMatrixAt(i, m);
        m.makeTranslation(x, 0.17, z); soils.setMatrixAt(i, m);
        soils.setColorAt(i, scol.setHex(PAL.soil).convertSRGBToLinear().offsetHSL(0.005 * (Math.random() - 0.5), 0, (Math.random() - 0.5) * 0.09));
        const anchor = new THREE.Group();
        anchor.position.set(x, 0, z);
        worldGroup.add(anchor);
        const node = { plotMesh: anchor, data: () => G.churchPlots[i], idx: i, x, z, special: true, plant: null, stage: -1, arr: G.churchPlots };
        plotNodes.push(node);
        refreshPlotVisual(node);
      });
      rims.instanceMatrix.needsUpdate = true;
      soils.instanceMatrix.needsUpdate = true;
      if (soils.instanceColor) soils.instanceColor.needsUpdate = true;
      worldGroup.add(rims, soils);
    }

    // A fruit lobbed at Ember: arcs from the player to his snout, then calls
    // back so the eat/burst effects fire on impact.
    let throwns = [];
    function throwFruit(fromX, fromZ, toX, toY, toZ, colorHex, onLand) {
      const c = SRGB(colorHex);
      const m = new THREE.Mesh(
        new THREE.IcosahedronGeometry(0.17, 0),
        new THREE.MeshStandardMaterial({ color: c, emissive: c, emissiveIntensity: 0.35, flatShading: true })
      );
      m.position.set(fromX, 1.0, fromZ);
      m.castShadow = true;
      worldGroup.add(m);
      throwns.push({
        m, t: 0, dur: 0.52,
        x0: fromX, y0: 1.0, z0: fromZ,
        x1: toX, y1: toY, z1: toZ,
        spin: 6 + Math.random() * 4,
        onLand,
      });
    }

    // Fill the gem bar; every 10 gems is a level. The bar shows itself, the
    // new gems pop in, then it slides away (UI side handles the animation).
    function awardGems(n) {
      if (!n) return;
      let levelled = 0;
      const from = G.gems;
      G.gems += n;
      while (G.gems >= GEMS_PER_LEVEL) { G.gems -= GEMS_PER_LEVEL; G.level++; levelled++; }
      G.pendingGemFx = { from, gained: n, level: G.level, levelled, at: Date.now() };
      if (levelled) SFX.level();
      else SFX.sparkle();
      syncHud();
    }

    function spawnBurst(x, z, colorHex, n = 6, opts = {}) {
      const bc = SRGB(colorHex);
      for (let k = 0; k < n; k++) {
        const bm = new THREE.Mesh(new THREE.IcosahedronGeometry(opts.size || 0.07, 0),
          new THREE.MeshStandardMaterial({ color: bc, emissive: bc, emissiveIntensity: opts.glow ? 1.6 : 0.25, flatShading: true }));
        bm.position.set(
          x + (Math.random() - 0.5) * (opts.spread || 0.4),
          opts.y0 !== undefined ? opts.y0 : 0.4,
          z + (Math.random() - 0.5) * (opts.spread || 0.4)
        );
        worldGroup.add(bm);
        bursts.push({ m: bm, vx: (Math.random() - 0.5) * (opts.vs || 1.2), vy: (opts.vy || 2) + Math.random() * 1.2, vz: (Math.random() - 0.5) * (opts.vs || 1.2), ttl: opts.ttl || 0.9 });
      }
    }

    // Small world-anchored "+2 🍓" text that rises off a plot and fades —
    // quieter than a toast for routine feedback the player is looking at.
    let floaties = [];
    // painted fruit art for the community "+1" pops, preloaded so the canvas
    // can draw them the instant a tree yields
    const FRUIT_ART = {};
    ["glowberry", "starberry", "dawnberry", "gloryberry"].forEach((k) => {
      const im = new Image();
      im.src = `/ui/kit/fruit-${k}.png`;
      FRUIT_ART[k] = im;
    });

    // "+1 🍓"-style pop with the REAL painted fruit and a glow behind it
    function spawnFruitPop(x, z, key, y0) {
      const art = FRUIT_ART[key];
      const cv = document.createElement("canvas");
      cv.width = 420; cv.height = 210;
      const c = cv.getContext("2d");
      const tint = { glowberry: "#7dfcd0", starberry: "#9fd0ff", dawnberry: "#ffb080", gloryberry: "#c9a0ff" }[key] || "#ffd76a";
      // soft radial bloom behind the whole pop
      const grd = c.createRadialGradient(300, 105, 8, 300, 105, 108);
      grd.addColorStop(0, tint + "cc");
      grd.addColorStop(0.45, tint + "55");
      grd.addColorStop(1, tint + "00");
      c.fillStyle = grd;
      c.beginPath(); c.arc(300, 105, 108, 0, Math.PI * 2); c.fill();
      // "+1" in the game's display face, gold gradient like the harvest pop
      c.textAlign = "center"; c.textBaseline = "middle";
      c.font = "900 96px 'Baloo 2', 'Trebuchet MS', sans-serif";
      c.shadowColor = tint; c.shadowBlur = 26;
      c.fillStyle = "#ffd76a"; c.fillText("+1", 130, 108);
      c.shadowBlur = 0;
      c.lineWidth = 14; c.lineJoin = "round"; c.strokeStyle = "#3a2410";
      c.strokeText("+1", 130, 108);
      const gg = c.createLinearGradient(0, 58, 0, 152);
      gg.addColorStop(0, "#fff8e2"); gg.addColorStop(0.4, "#ffd156"); gg.addColorStop(1, "#e8912e");
      c.fillStyle = gg; c.fillText("+1", 130, 108);
      // the fruit itself, glowing
      if (art && art.complete && art.naturalWidth) {
        c.save();
        c.shadowColor = tint; c.shadowBlur = 34;
        c.drawImage(art, 224, 17, 172, 172);
        c.shadowBlur = 18;
        c.drawImage(art, 224, 17, 172, 172); // second pass deepens the bloom
        c.restore();
      }
      const sp = new THREE.Sprite(new THREE.SpriteMaterial({
        map: new THREE.CanvasTexture(cv), transparent: true, depthWrite: false, fog: false,
      }));
      sp.scale.set(0.01, 0.01, 1);
      sp.position.set(x, y0, z);
      worldGroup.add(sp);
      floaties.push({ sp, ttl: 3.1, age: 0, bw: 1.6, bh: 0.8, slow: true }); // half-size: the painted fruit read huge over the trees
    }
    // AAA reward pop: gold-gradient display text with glow bed + deep outline,
    // fog-proof, pops in with an overshoot then drifts up and fades
    function spawnFloatie(x, z, text, y0 = 1.0, opts = null) {
      const big = !!(opts && opts.big);
      const cv = document.createElement("canvas"); cv.width = 320; cv.height = 128;
      const cx = cv.getContext("2d");
      cx.textAlign = "center"; cx.textBaseline = "middle";
      cx.font = "900 62px 'Baloo 2', 'Trebuchet MS', sans-serif";
      cx.shadowColor = "#ffd76a"; cx.shadowBlur = 26;
      cx.fillStyle = "#ffd76a"; cx.fillText(text, 160, 66);
      cx.shadowBlur = 0;
      cx.lineWidth = 12; cx.lineJoin = "round"; cx.strokeStyle = "#4a2c10";
      cx.strokeText(text, 160, 66);
      const grad = cx.createLinearGradient(0, 28, 0, 104);
      grad.addColorStop(0, "#fff8e2"); grad.addColorStop(0.4, "#ffd156"); grad.addColorStop(1, "#e8912e");
      cx.fillStyle = grad; cx.fillText(text, 160, 66);
      const sp = new THREE.Sprite(new THREE.SpriteMaterial({ map: new THREE.CanvasTexture(cv), transparent: true, depthWrite: false, fog: false }));
      sp.scale.set(0.01, 0.01, 1); // pops in via the tick's overshoot curve
      sp.position.set(x, y0, z);
      worldGroup.add(sp);
      floaties.push({ sp, ttl: big ? 3.1 : 1.45, age: 0, bw: big ? 3.0 : 1.9, bh: big ? 1.2 : 0.76, slow: big });
    }

    function addPetals(spots, colorsArr, count, hMax) {
      const pGeo = new THREE.PlaneGeometry(0.1, 0.14);
      for (let i = 0; i < count; i++) {
        const [bx, bz] = spots[i % spots.length];
        const sx = bx + (Math.random() - 0.5) * 3.2, sz = bz + (Math.random() - 0.5) * 3.2;
        const c = colorsArr[Math.floor(Math.random() * colorsArr.length)];
        const pt = new THREE.Mesh(pGeo, flat(c, { side: THREE.DoubleSide, emissive: c, emissiveIntensity: 0.15, transparent: true, opacity: 0.95 }));
        pt.userData = { sx, sz, ph: Math.random() * 9, sp: 0.08 + Math.random() * 0.06, h: hMax * (0.7 + Math.random() * 0.5), gy: terrainY(sx, sz) };
        worldGroup.add(pt); petals.push(pt);
      }
    }

    function addButterflies(n, area) {
      for (let i = 0; i < n; i++) {
        const c = [0xffa8d0, 0xa8d8ff, 0xfff3a0][i % 3];
        const b = new THREE.Mesh(new THREE.ConeGeometry(0.09, 0.16, 4), flat(c, { emissive: c, emissiveIntensity: 0.25 }));
        b.userData = { cx: (Math.random() - 0.5) * area, cz: (Math.random() - 0.5) * area, ph: Math.random() * 9, r: 1 + Math.random() * 2 };
        worldGroup.add(b); butterflies.push(b);
      }
    }

    function addChimneySmoke(parent, lx, ly, lz) {
      for (let i = 0; i < 4; i++) {
        const puff = new THREE.Mesh(new THREE.IcosahedronGeometry(0.22, 0),
          flat(0xe8e8ea, { transparent: true, opacity: 0.7, roughness: 1 }));
        puff.userData = { ph: i / 4, lx, ly, lz };
        parent.add(puff); smokes.push(puff);
      }
    }

    function makeTextPlate(text, o = {}) {
      const w = o.w || 3, h = o.h || 0.7;
      const cv = document.createElement("canvas");
      cv.width = 256; cv.height = Math.max(48, Math.round(256 * h / w));
      const c2 = cv.getContext("2d");
      c2.fillStyle = o.bg || "#f2e6cc";
      c2.fillRect(0, 0, cv.width, cv.height);
      c2.strokeStyle = o.fg || "#4a3117"; c2.lineWidth = 10;
      c2.strokeRect(6, 6, cv.width - 12, cv.height - 12);
      c2.fillStyle = o.fg || "#4a3117";
      c2.font = `bold ${Math.round(cv.height * 0.4)}px 'Trebuchet MS', sans-serif`;
      c2.textAlign = "center"; c2.textBaseline = "middle";
      c2.fillText(text, cv.width / 2, cv.height / 2 + 2);
      const tex = new THREE.CanvasTexture(cv);
      const mm = new THREE.Mesh(new THREE.BoxGeometry(w, h, 0.08), new THREE.MeshBasicMaterial({ map: tex }));
      mm.castShadow = true;
      return mm;
    }

    function refreshBuildMarkers() {
      if (buildMarkers) { worldGroup.remove(buildMarkers); buildMarkers = null; }
      const free = buildCells.filter((c) => !c.taken);
      if (!free.length) return;
      const mg = new THREE.PlaneGeometry(1.95, 1.95);
      mg.rotateX(-Math.PI / 2);
      buildMarkers = new THREE.InstancedMesh(mg,
        new THREE.MeshBasicMaterial({ color: SRGB(0x7dfcd0), transparent: true, opacity: 0.16, depthWrite: false, side: THREE.DoubleSide }), free.length);
      const mm = new THREE.Matrix4();
      free.forEach((c, i) => { mm.makeTranslation(c.x, 0.05, c.z); buildMarkers.setMatrixAt(i, mm); });
      buildMarkers.instanceMatrix.needsUpdate = true;
      buildMarkers.visible = false;
      worldGroup.add(buildMarkers);
    }
    G.addLivePlot = (x, z, idx) => {
      const plotMesh = makePlot(x, z, false);
      worldGroup.add(plotMesh);
      const node = { plotMesh, data: () => G.homePlots[idx], idx, x, z, special: false, plant: null, stage: -1, arr: G.homePlots };
      plotNodes.push(node);
      refreshPlotVisual(node);
      spawnBurst(x, z, 0x6b4a2f, 8, { vy: 1.8, spread: 0.7, y0: 0.3 });
      refreshBuildMarkers();
    };

    // -------- HOME --------
    function buildHome() {
      clearWorld();
      setAtmosphere(PAL.skyTop, PAL.skyMid, PAL.skyHorizon, PAL.fog, PAL.sun, 1.45, PAL.ambientSky, PAL.ambientGnd);

      const FT = FENCE_TIERS[G.build.fenceTier];
      const inGarden = (x, z, m = 1.1) => x > FT.x1 - m && x < FT.x2 + m && z > FT.z1 - m && z < FT.z2 + m;
      // rolling hills, flat around every gameplay zone; river carves through the west
      const homeBase = makeTerrain(
        [{ x: 16, z: -16, r: 7, h: 1.5 }, { x: 22, z: 12, r: 8, h: 1.6 }, { x: -24, z: 16, r: 7, h: 1.4 },
         { x: 12, z: 20, r: 6, h: 1.2 }, { x: 26, z: -4, r: 6, h: 1.1 }, { x: -24, z: -14, r: 7, h: 1.5 }],
        [{ x1: FT.x1 - 1.8, z1: FT.z1 - 1.6, x2: FT.x2 + 1.8, z2: FT.z2 + 1.6, f: 3 }, { x1: -9, z1: -23, x2: 9, z2: -8.5, f: 4 },
         { c: 1, x: 6.5, z: -7, r: 4.6, f: 3 },
         { x1: -26, z1: 1.2, x2: 26, z2: 4.8, f: 3 }, { x1: -1.6, z1: -6, x2: 1.6, z2: 7, f: 3 }]
      );
      // Bridge deck profile, shared by terrainY and the mesh below so the
      // walkable surface and the planks can never disagree. A tall humpback:
      // the snapping turtle patrols straight through this span, and at the
      // old 0.34 rise it swam through the planks instead of under them.
      // The ruin uses the same curve — it is the same bridge, collapsed, and
      // its surviving ends would clip the turtle just as the whole one did.
      const BRIDGE_ARCH = 1.35;
      const BRIDGE_SPAN = 6.4, BRIDGE_X0 = -16.4;
      const bridgeDeckY = (x) => BRIDGE_ARCH * Math.sin(((x - BRIDGE_X0) / BRIDGE_SPAN) * Math.PI);
      if (import.meta.env && import.meta.env.DEV) G.__deckY = bridgeDeckY;
      // The LAND. The bridge deck is deliberately not part of it: the ground
      // mesh is built from this, and folding the deck in raised a hump of
      // earth under the span that dammed the river. Invisible at the old
      // 0.34 arch because the planks covered it; obvious at 1.35.
      const homeGroundY = (x, z) => {
        let h = homeBase(x, z);
        const rd = Math.abs(x - RIVER_X(z));
        if (rd < 3.2) { const t = 1 - rd / 3.2; h -= 0.62 * t * t; } // river banks
        return h;
      };
      // What you STAND on — the land, plus the bridge deck where there is one.
      terrainY = (x, z) => {
        if (Math.abs(z - 3) < 1.15 && x > -16.4 && x < -10.0) {
          // broken bridge: the collapsed middle has NO deck — you fall to the
          // river line (colliders already seal both edges). Members get the
          // full walkable arch.
          const inGap = !G.youthGroup && x > -14.45 && x < -12.25;
          if (!inGap) return bridgeDeckY(x); // bridge deck
        }
        return homeGroundY(x, z);
      };
      // path routes registered BEFORE the ground so the terrain carries the worn ribbon
      const homeRoutes = [
        { pts: [[0, 7.0], [0, 1], [0, -4]], w: 1.5 },
        { pts: [[0, 3], [14, 3], [24, 3]], w: 1.5 },
        { pts: [[0, 3], [-9.0, 3]], w: 1.5 },
        { pts: [[-17.2, 3], [-24, 3]], w: 1.5 },
        { pts: [[4.6, 2.6], [5.55, -3.9]], w: 1.1 }, // spur off the road to the cottage doorstep
      ];
      setPathRoutes(homeRoutes);
      // trodden garden floor: worn dry grass -> packed earth patches inside the fence
      const GARDEN_WORN = new THREE.Color(PAL.grassSun).offsetHSL(-0.022, -0.14, -0.045).convertSRGBToLinear();
      const GARDEN_TROD = new THREE.Color(PAL.soil).offsetHSL(0.012, -0.16, 0.1).convertSRGBToLinear();
      worldGroup.add(makeGround(80, PAL.grassBase, (x, z, c) => {
        const rd = Math.abs(x - RIVER_X(z));
        if (rd < 3.4) c.lerp(SAND, 1 - rd / 3.4);
        if (rd < 3.0) c.lerp(BANK_SHADE, (1 - rd / 3.0) * 0.45); // cool moist rim so the river sits IN the land
        if (rd < 2.6) c.lerp(BANK_WET, Math.pow(1 - rd / 2.6, 0.7) * 0.75); // wet soil fill toward the riverbed
        const ridge = 1 - Math.abs(rd - 1.9) / 0.95; // extra dark band right at the waterline
        if (ridge > 0) c.lerp(BANK_WET, ridge * 0.65);
        // worked garden interior — soft edge falloff at the fence, patchy packed earth within
        const gdx = Math.min(x - (FT.x1 - 0.6), (FT.x2 + 0.6) - x);
        const gdz = Math.min(z - (FT.z1 - 0.6), (FT.z2 + 0.6) - z);
        const gIn = Math.min(1, Math.min(gdx, gdz) / 1.1);
        if (gIn > 0) {
          c.lerp(GARDEN_WORN, gIn * 0.55);
          const tn = 0.5 + 0.5 * Math.sin(x * 1.45 + z * 2.15 + 1.3) * Math.sin(x * 0.85 - z * 1.55);
          c.lerp(GARDEN_TROD, gIn * (0.12 + tn * 0.58));
        }
      }, homeGroundY));

      // the river dividing the home meadow from the community garden
      // depth-banded vertex gradient: teal channel core -> lighter cyan -> pale glowing rim at the banks
      const wGeo = new THREE.PlaneGeometry(4.2, 80, 6, 60);
      wGeo.rotateX(-Math.PI / 2);
      const wPos = wGeo.attributes.position;
      const wData = [];
      const wCols = [];
      const wDeep = SRGB(PAL.waterDeep).offsetHSL(0, -0.02, -0.035); // desaturated blue-green channel core
      const wMid = SRGB(PAL.waterSurf);
      // shallows warm toward the sand bed so the water shares the scene's golden grade
      const wRim = SRGB(PAL.waterSurf).lerp(SRGB(PAL.foam), 0.35).lerp(SAND, 0.18).offsetHSL(0.01, -0.05, 0.02);
      const wTmp = new THREE.Color();
      for (let wi = 0; wi < wPos.count; wi++) {
        const lat = wPos.getX(wi);
        const wz = wPos.getZ(wi);
        wPos.setX(wi, RIVER_X(wz) + lat);
        wData.push([wi, wz, lat]);
        const a = Math.min(1, Math.abs(lat) / 2.1);
        if (a < 0.6) wTmp.copy(wDeep).lerp(wMid, a / 0.6);
        else wTmp.copy(wMid).lerp(wRim, Math.pow((a - 0.6) / 0.4, 1.7));
        wCols.push(wTmp.r, wTmp.g, wTmp.b);
      }
      wGeo.setAttribute("color", new THREE.Float32BufferAttribute(wCols, 3));
      water = new THREE.Mesh(wGeo, new THREE.MeshStandardMaterial({
        color: 0xffffff, vertexColors: true, roughness: 0.22, metalness: 0.14, // enough gloss for a sun-aligned glint on the ripple crests
        emissive: SRGB(PAL.waterDeep), emissiveIntensity: 0.22,
        transparent: true, opacity: 0.88,
      }));
      water.position.y = -0.16;
      water.receiveShadow = true; // bridge + bank trees shade the surface; hemisphere cools the shaded water
      water.userData.verts = wData;
      worldGroup.add(water);

      // ---- wet-mud shoreline strips: a smooth analytic ribbon following RIVER_X on both banks.
      // It hides the raw water-plane/terrain sawtooth intersection: the water edge now dies into
      // this strip (same sine curve, no triangulation jags) and the strip's inner edge dips
      // below the surface to double as the visible riverbed shelf.
      {
        // land only — the strip must duck under the bridge, not climb it
        const bankY = homeGroundY;
        const bedSand = SAND.clone().offsetHSL(0.004, -0.07, 0.075); // pale submerged shelf — reads as warm teal shallows through the water
        const mudWet = BANK_WET.clone().offsetHSL(0, -0.02, -0.045); // dark damp contact ring just above the waterline
        const mudSand = SAND.clone().offsetHSL(0.004, -0.02, -0.03); // damp sand mid-band
        const mudOut = SAND.clone().lerp(BANK_SHADE, 0.42).offsetHSL(0, 0, -0.02); // blends into the tinted bank grass
        const stripParts = [];
        const mTmp = new THREE.Color();
        [-1, 1].forEach((side) => {
          const sg = new THREE.PlaneGeometry(1.5, 80, 3, 96);
          sg.rotateX(-Math.PI / 2);
          const sp = sg.attributes.position;
          const sCols = new Float32Array(sp.count * 3);
          for (let vi = 0; vi < sp.count; vi++) {
            const lx = sp.getX(vi); // -0.75..0.75 across the strip
            const vz = sp.getZ(vi);
            const latAbs = 2.0 + side * lx; // 1.25..2.75 from channel center
            const wx = RIVER_X(vz) + side * latAbs;
            sp.setX(vi, wx);
            sp.setY(vi, bankY(wx, vz) + 0.05);
            // waterline sits at latAbs ~1.34-1.63 (t 0.06-0.25): keep that whole zone pale
            // low-contrast shelf so the rippling crossing line never reads as dark teeth
            const t = (latAbs - 1.25) / 1.5;
            if (t < 0.22) mTmp.copy(bedSand);
            else if (t < 0.42) mTmp.copy(bedSand).lerp(mudWet, (t - 0.22) / 0.2);
            else if (t < 0.68) mTmp.copy(mudWet).lerp(mudSand, (t - 0.42) / 0.26);
            else mTmp.copy(mudSand).lerp(mudOut, (t - 0.68) / 0.32);
            const jit = 0.94 + Math.random() * 0.12; // subtle facet sparkle so it isn't a dead ribbon
            sCols[vi * 3] = mTmp.r * jit; sCols[vi * 3 + 1] = mTmp.g * jit; sCols[vi * 3 + 2] = mTmp.b * jit;
          }
          sg.setAttribute("color", new THREE.BufferAttribute(sCols, 3));
          stripParts.push(sg);
        });
        const mudStrip = new THREE.Mesh(mergeGeoms(stripParts),
          new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.62, metalness: 0.03, side: THREE.DoubleSide })); // damp sheen; DoubleSide — the mirrored west ribbon reverses winding
        mudStrip.receiveShadow = true;
        worldGroup.add(mudStrip);
      }

      // foam — ONE InstancedMesh, matrices animated per frame:
      // irregular drifting glints + slow thin dashes hugging both waterlines (Tunic-style
      // shoreline contour) + anchored wake Vs and broken foam rings at the mid-stream boulders
      riverFoam = new THREE.InstancedMesh(
        new THREE.BoxGeometry(0.16, 0.05, 0.46),
        flat(PAL.foam, { emissive: PAL.foam, emissiveIntensity: 0.12, transparent: true, opacity: 0.85 }), 52);
      riverFoam.frustumCulled = false;
      // drifting glints: random length/width, intensity 30-70%, biased toward the sunlit (east) half
      for (let fi = 0; fi < 14; fi++)
        foams.push({ z: -38 + Math.random() * 76, sp: 1.6 + Math.random() * 1.9, off: -0.7 + Math.random() * 2.5,
          ry: (Math.random() - 0.5) * 0.6, ln: 0.65 + Math.random() * 1.9, w: 0.3 + Math.random() * 0.65,
          al: 0.3 + Math.random() * 0.4 });
      for (let fi = 0; fi < 16; fi++) {
        const side = fi % 2 ? 1 : -1;
        foams.push({ z: -36 + fi * 4.6 + Math.random() * 2.2, sp: 0.35 + Math.random() * 0.4,
          off: side * (2.4 + Math.random() * 0.28), ry: 0, hug: true,
          ln: 2.0 + Math.random() * 1.7, w: 0.45, al: 0.45 + Math.random() * 0.3 });
      }
      worldGroup.add(riverFoam);

      // bank stones: decorative pebbles along both shores + abutment stones at the bridge ends (no collision)
      const pebbles = new THREE.InstancedMesh(new THREE.IcosahedronGeometry(0.14, 0), flat(PAL.stone), 88);
      pebbles.frustumCulled = false;
      pebbles.castShadow = true; pebbles.receiveShadow = true;
      let pebN = 0;
      const putPebble = (px, pz, sc) => {
        if (pebN >= 88) return;
        instDummy.position.set(px, terrainY(px, pz) + 0.05 * sc, pz);
        instDummy.rotation.set(Math.random() * 3, Math.random() * 3, Math.random() * 3);
        instDummy.scale.set(sc * (0.8 + Math.random() * 0.8), sc * (0.45 + Math.random() * 0.35), sc * (0.8 + Math.random() * 0.8));
        instDummy.updateMatrix();
        pebbles.setMatrixAt(pebN++, instDummy.matrix);
      };
      for (let pi = 0; pi < 48; pi++) {
        const pz = -37 + Math.random() * 74;
        if (Math.abs(pz - 3) < 1.7) continue; // keep the bridge walkway clear
        const px = RIVER_X(pz) + (Math.random() < 0.5 ? -1 : 1) * (2.25 + Math.random() * 1.0);
        putPebble(px, pz, 0.9 + Math.random() * 1.5);
      }
      // chunkier stones hugging the bridge abutments
      putPebble(-16.7, 1.7, 2.4); putPebble(-16.8, 4.4, 2.1);
      putPebble(-9.9, 1.65, 2.2); putPebble(-9.8, 4.35, 2.5);

      // ---- erosion rock clusters: anchor boulder + 2-3 mediums + pebble scatter hugging the
      // banks and bridge footings — ONE InstancedMesh, decorative only (zero new collision)
      const bankGeo = bakeRockFacets(new THREE.IcosahedronGeometry(0.55, 0), false, null);
      {
        // shared wet/contact band: the lower belt of every bank rock darkens toward damp
        // stone, so shoreline boulders read soaked at the waterline instead of pasted on
        const bPos = bankGeo.attributes.position, bCol = bankGeo.attributes.color;
        const dampC = new THREE.Color(PAL.stone).offsetHSL(0.01, 0.02, -0.18).convertSRGBToLinear().lerp(SRGB(PAL.waterDeep), 0.15);
        const bTmp = new THREE.Color();
        for (let vi = 0; vi < bPos.count; vi++) {
          const t = Math.max(0, Math.min(1, (-0.02 - bPos.getY(vi)) / 0.4));
          if (t > 0) {
            bTmp.fromBufferAttribute(bCol, vi).lerp(dampC, t * 0.7);
            bCol.setXYZ(vi, bTmp.r, bTmp.g, bTmp.b);
          }
        }
      }
      const bankRocks = new THREE.InstancedMesh(bankGeo, flat(0xffffff, { vertexColors: true }), 44);
      bankRocks.castShadow = true; bankRocks.receiveShadow = true; bankRocks.frustumCulled = false;
      let bankN = 0;
      const bankCol = new THREE.Color();
      const putBankRock = (bx, bz, bs, by = null, mossy = false) => {
        if (bankN >= 44) return;
        const y = by != null ? by : 0.16 * bs + terrainY(bx, bz);
        instDummy.position.set(bx, y, bz);
        instDummy.rotation.set(0, (Math.random() - 0.5) * 1.3, 0); // yaw only — keeps the baked sun-facet split honest
        instDummy.scale.set(bs, bs * (0.7 + Math.random() * 0.45), bs * (0.82 + Math.random() * 0.35));
        instDummy.updateMatrix();
        bankRocks.setMatrixAt(bankN, instDummy.matrix);
        bankCol.setScalar(0.88 + Math.random() * 0.24);
        bankRocks.setColorAt(bankN, bankCol);
        bankN++;
        if (mossy && bs >= 0.5) addMossCap(bx, y + 0.3 * bs, bz, bs * 0.82);
      };
      [[-24, -1], [-12.6, 1], [9.5, 1], [16.5, -1], [24.5, 1], [-30.5, 1]].forEach(([cz, side]) => {
        const ax = RIVER_X(cz) + side * (2.45 + Math.random() * 0.45);
        putBankRock(ax, cz, 0.85 + Math.random() * 0.35, null, true); // anchor
        const nMed = 2 + (Math.random() < 0.5 ? 1 : 0);
        for (let ci = 0; ci < nMed; ci++) {
          const aa = Math.random() * Math.PI * 2, rr = 0.6 + Math.random() * 0.55;
          putBankRock(ax + Math.cos(aa) * rr * 0.7, cz + Math.sin(aa) * rr * 1.5, 0.3 + Math.random() * 0.22);
        }
        for (let ci = 0; ci < 3; ci++)
          putPebble(ax + (Math.random() - 0.5) * 1.9, cz + (Math.random() - 0.5) * 2.4, 0.7 + Math.random());
      });
      // stone footings where the bridge meets the banks
      putBankRock(-16.95, 1.35, 0.6, null, true); putBankRock(-16.85, 4.7, 0.52);
      putBankRock(-9.65, 1.3, 0.55); putBankRock(-9.95, 4.78, 0.58, null, true);
      bankRocks.count = bankN;
      if (bankRocks.instanceColor) bankRocks.instanceColor.needsUpdate = true;
      worldGroup.add(bankRocks);

      // mid-stream boulders breaking the surface — wet-banded bases, mossy crowns,
      // broken foam collars where water meets rock + anchored wake Vs trailing downstream
      [[-9, 0.45], [13, -0.5], [25, 0.35]].forEach(([bz, boff]) => {
        const bx = RIVER_X(bz) + boff;
        worldGroup.add(makeRock(bx, bz, 0.78, false, { noCol: true, y: -0.3, wet: true }));
        [-1, 1].forEach((vs) => {
          const fz = bz + 0.62;
          foams.push({ z: fz, sp: 0, off: (bx + vs * 0.34 - RIVER_X(fz)) / 0.7, ry: vs * 0.42, ln: 0.85, w: 0.5, anch: true, al: 0.6 });
        });
        // broken collar: 3 short tangent dashes hugging the waterline around the rock
        const a0 = Math.random() * Math.PI * 2;
        for (let ci = 0; ci < 3; ci++) {
          const aa = a0 + ci * 2.2 + (Math.random() - 0.5) * 0.4;
          const fx = bx + Math.cos(aa) * 0.44, fz = bz + Math.sin(aa) * 0.44;
          foams.push({ z: fz, sp: 0, off: (fx - RIVER_X(fz)) / 0.7, ry: -aa, ln: 0.55, w: 0.38, anch: true, al: 0.55 + Math.random() * 0.2 });
        }
      });
      riverFoam.count = foams.length;
      // bake per-glint intensity: dimmer glints tint toward the water so they read as
      // catching light at 30-70%, not as painted-on white lane markings
      {
        const fc = new THREE.Color(), foamC = SRGB(PAL.foam), surfC = SRGB(PAL.waterSurf);
        foams.forEach((fd, fi) => {
          fc.copy(surfC).lerp(foamC, fd.al != null ? fd.al + 0.3 : 1);
          riverFoam.setColorAt(fi, fc);
        });
        if (riverFoam.instanceColor) riverFoam.instanceColor.needsUpdate = true;
      }

      // reed / cattail clumps at the waterline — merged geometry, ONE InstancedMesh, wind-swayed
      const reedParts = [];
      const tintGeo = (g, c) => {
        const nn = g.attributes.position.count, arr = new Float32Array(nn * 3);
        for (let vi = 0; vi < nn; vi++) { arr[vi * 3] = c.r; arr[vi * 3 + 1] = c.g; arr[vi * 3 + 2] = c.b; }
        g.setAttribute("color", new THREE.BufferAttribute(arr, 3));
        return g;
      };
      const reedStemC = SRGB(PAL.grassShade).offsetHSL(0.015, 0.06, -0.02);
      const reedStemC2 = SRGB(PAL.leafDeep).offsetHSL(0, 0.04, 0.02);
      const reedHeadC = SRGB(PAL.bark).offsetHSL(0, 0.06, -0.05);
      [[0.95, 0, 0, 0.1, true], [0.75, 0.12, 0.07, -0.14, true], [0.6, -0.11, -0.08, 0.16, false], [0.82, -0.05, 0.13, -0.08, false]]
        .forEach(([h, ox, oz, tilt, head], si) => {
          const stem = new THREE.CylinderGeometry(0.016, 0.03, h, 4);
          stem.translate(0, h / 2, 0);
          tintGeo(stem, si % 2 ? reedStemC2 : reedStemC);
          stem.rotateX(tilt); stem.rotateZ(tilt * 0.6); stem.translate(ox, 0, oz);
          reedParts.push(stem);
          if (head) {
            const hd = new THREE.CylinderGeometry(0.045, 0.05, 0.2, 5);
            hd.translate(0, h + 0.08, 0);
            tintGeo(hd, reedHeadC);
            hd.rotateX(tilt); hd.rotateZ(tilt * 0.6); hd.translate(ox, 0, oz);
            reedParts.push(hd);
          }
        });
      const reeds = new THREE.InstancedMesh(mergeGeoms(reedParts), flat(0xffffff, { vertexColors: true }), 40);
      addWind(reeds.material, 0.055, 0.6);
      reeds.castShadow = true; reeds.frustumCulled = false;
      let reedN = 0;
      const reedCol = new THREE.Color();
      for (let ri = 0; ri < 120 && reedN < 40; ri++) {
        const rz = -36 + Math.random() * 72;
        if (Math.abs(rz - 3) < 2.7) continue; // keep the bridge approach clear
        const side = Math.random() < 0.5 ? -1 : 1;
        const rx = RIVER_X(rz) + side * (1.95 + Math.random() * 0.55);
        instDummy.position.set(rx, terrainY(rx, rz) - 0.04, rz);
        instDummy.rotation.set(0, Math.random() * Math.PI * 2, 0);
        const rs = 0.8 + Math.random() * 0.55;
        instDummy.scale.set(rs, rs * (0.85 + Math.random() * 0.45), rs);
        instDummy.updateMatrix();
        reeds.setMatrixAt(reedN, instDummy.matrix);
        reedCol.setScalar(0.9 + Math.random() * 0.2);
        reeds.setColorAt(reedN, reedCol);
        reedN++;
      }
      reeds.count = reedN;
      if (reeds.instanceColor) reeds.instanceColor.needsUpdate = true;
      worldGroup.add(reeds);

      // bank tuft clusters: dense moist-green grass hugging both shores (the river corridor
      // should read RICHER than the open meadow) — ONE InstancedMesh, clustered not uniform
      {
        const bankTuftG = bladeTuftGeo(8, 0.26, 0.5, 0.15);
        const bankTufts = new THREE.InstancedMesh(bankTuftG,
          flat(0xffffff, { vertexColors: true, roughness: 1, side: THREE.DoubleSide }), 96);
        addWind(bankTufts.material, 0.06, 0.4);
        bankTufts.castShadow = true; bankTufts.receiveShadow = true; bankTufts.frustumCulled = false;
        const btCol = new THREE.Color();
        const btShade = SRGB(PAL.grassShade), btDeep = SRGB(PAL.leafDeep), btBase = SRGB(PAL.grassBase);
        let btN = 0;
        for (let ci = 0; ci < 16 && btN < 96; ci++) {
          const cz = -36 + Math.random() * 72;
          if (Math.abs(cz - 3) < 2.6) continue; // bridge approach stays clear
          const cSide = Math.random() < 0.5 ? -1 : 1;
          const cLat = 2.45 + Math.random() * 0.75;
          const nT = 4 + Math.floor(Math.random() * 4);
          for (let ti = 0; ti < nT && btN < 96; ti++) {
            const tz = cz + (Math.random() - 0.5) * 2.2;
            const tLat = Math.max(2.2, cLat + (Math.random() - 0.5) * 0.9);
            const tx = RIVER_X(tz) + cSide * tLat;
            instDummy.position.set(tx, terrainY(tx, tz) - 0.03, tz);
            instDummy.rotation.set(0, Math.random() * Math.PI * 2, 0);
            const ts = 0.75 + Math.random() * 0.65;
            instDummy.scale.set(ts, ts * (0.8 + Math.random() * 0.5), ts);
            instDummy.updateMatrix();
            bankTufts.setMatrixAt(btN, instDummy.matrix);
            // moist ramp: shade-green leaning teal near the water, drier toward the meadow
            btCol.copy(btShade).lerp(btDeep, Math.random() * 0.45).lerp(btBase, Math.max(0, tLat - 2.5) * 0.5)
              .offsetHSL((Math.random() - 0.5) * 0.015, 0, (Math.random() - 0.5) * 0.05);
            bankTufts.setColorAt(btN, btCol);
            btN++;
          }
        }
        bankTufts.count = btN;
        if (bankTufts.instanceColor) bankTufts.instanceColor.needsUpdate = true;
        worldGroup.add(bankTufts);
      }

      // lily pads in the slow sections, riding just above the ripple crest
      const lilies = new THREE.InstancedMesh(
        new THREE.CylinderGeometry(0.26, 0.3, 0.03, 7), flat(PAL.leafMid), 7);
      lilies.receiveShadow = true; lilies.frustumCulled = false;
      const lilyCol = new THREE.Color();
      const lilyMid = SRGB(PAL.leafMid), lilyLime = SRGB(PAL.leafLime);
      [[14.5, 0.4], [16.8, -0.6], [22.5, 0.2], [-14.5, -0.4], [-19.5, 0.5], [-26.5, -0.3], [28.5, 0.4]].forEach(([lz, loff], li) => {
        instDummy.position.set(RIVER_X(lz) + loff, -0.095, lz);
        instDummy.rotation.set(0, Math.random() * Math.PI * 2, 0);
        const ls = 0.75 + Math.random() * 0.5;
        instDummy.scale.set(ls, 1, ls);
        instDummy.updateMatrix();
        lilies.setMatrixAt(li, instDummy.matrix);
        lilyCol.copy(lilyMid).lerp(lilyLime, Math.random() * 0.6).offsetHSL(0.01, -0.16, (Math.random() - 0.5) * 0.05 - 0.02);
        lilies.setColorAt(li, lilyCol);
      });
      if (lilies.instanceColor) lilies.instanceColor.needsUpdate = true;
      pebbles.count = pebN;
      worldGroup.add(pebbles, lilies);

      // arched wooden bridge — whole for youth-group members, collapsed otherwise
      const bridge = new THREE.Group();
      const deckH = bridgeDeckY;
      // dock-wood treatment: 3 warm albedo steps per plank + baked dark undersides/end-grain
      const PLANK_TONES = [
        new THREE.Color(PAL.wood).offsetHSL(0, 0.01, -0.045), // workhorse bleached tan
        new THREE.Color(PAL.wood).offsetHSL(0.006, -0.02, 0.035), // sun-dried pale step
        new THREE.Color(PAL.wood).offsetHSL(-0.004, 0.03, -0.105), // aged damp step
      ];
      const bakePlankShade = (bg) => {
        // top face full, side walls dipped, undersides + sawn ends darkest — weight without cost
        const nrm = bg.attributes.normal, pc = new Float32Array(nrm.count * 3);
        for (let vi = 0; vi < nrm.count; vi++) {
          const ny = nrm.getY(vi), nz = Math.abs(nrm.getZ(vi));
          const v = ny > 0.5 ? 1 : ny < -0.5 ? 0.52 : nz > 0.5 ? 0.68 : 0.82;
          pc[vi * 3] = v; pc[vi * 3 + 1] = v; pc[vi * 3 + 2] = v * 0.97;
        }
        bg.setAttribute("color", new THREE.BufferAttribute(pc, 3));
        return bg;
      };
      const plankGeo = bakePlankShade(new THREE.BoxGeometry(0.68, 0.09, 2.3));
      const plankTone = (bx) => PLANK_TONES[Math.floor(Math.abs(Math.sin(bx * 37.7)) * 3) % 3];
      const mkPlank = (bx, ry = 0, drop = 0, rz = null) => {
        const plank = new THREE.Mesh(plankGeo, flat(plankTone(bx), { vertexColors: true }));
        const slope = BRIDGE_ARCH * (Math.PI / BRIDGE_SPAN) * Math.cos(((bx - BRIDGE_X0) / BRIDGE_SPAN) * Math.PI);
        plank.rotation.z = rz != null ? rz : Math.atan(slope);
        plank.rotation.y = ry;
        plank.position.set(bx, deckH(bx) - 0.02 - drop, 3);
        plank.castShadow = true; plank.receiveShadow = true;
        bridge.add(plank);
      };
      const plankXs = Array.from({ length: 9 }, (_, bi) => -16.05 + bi * 0.72);
      if (G.youthGroup) {
        plankXs.forEach((bx) => mkPlank(bx));
      } else {
        [0, 1, 2, 6, 7, 8].forEach((bi) => mkPlank(plankXs[bi]));
        mkPlank(plankXs[3], 0.25, 0.42, -0.85); // snapped, hanging into the water
        mkPlank(plankXs[5], -0.2, 0.5, 0.8);
        const drift = new THREE.Mesh(bakePlankShade(new THREE.BoxGeometry(0.66, 0.08, 1.4)),
          flat(PLANK_TONES[2], { vertexColors: true }));
        drift.position.set(-13.6, -0.08, 4.6);
        drift.rotation.set(0.06, 0.7, 0.1);
        drift.castShadow = true;
        worldGroup.add(drift);
        // contact-shadow decals on the water under the collapsed spans + the drifted plank —
        // gives the collapse vignette weight the 2048 shadow map can't resolve at this scale
        const aoGeoA = new THREE.PlaneGeometry(2.7, 2.0);
        aoGeoA.rotateX(-Math.PI / 2); aoGeoA.translate(-13.35, 0, 3.15);
        const aoGeoB = new THREE.PlaneGeometry(1.8, 1.15);
        aoGeoB.rotateX(-Math.PI / 2); aoGeoB.rotateY(0.7);
        aoGeoB.translate(-13.6, 0.001, 4.6);
        const wreckAO = new THREE.Mesh(mergeGeoms([aoGeoA, aoGeoB]),
          flat(new THREE.Color(PAL.waterDeep).offsetHSL(0, -0.12, -0.15),
            { transparent: true, opacity: 0.38, depthWrite: false }));
        wreckAO.position.y = -0.104; // above the ripple crest, below the planks
        worldGroup.add(wreckAO);
      }
      const postXs = G.youthGroup ? [-16.2, -14.7, -13.2, -11.7, -10.2] : [-16.2, -14.7, -11.7, -10.2];
      [-1, 1].forEach((side) => {
        let prev = null;
        postXs.forEach((px) => {
          const post = new THREE.Mesh(new THREE.BoxGeometry(0.12, 0.62, 0.12), flat(new THREE.Color(PAL.wood).offsetHSL(0, 0.02, -0.09)));
          post.position.set(px, deckH(px) + 0.29, 3 + side * 1.08);
          post.castShadow = true;
          bridge.add(post);
          const gapJump = !G.youthGroup && prev === -14.7 && px === -11.7;
          if (prev !== null && !gapJump) {
            const midx = (prev + px) / 2;
            const rlen = px - prev;
            const rail = new THREE.Mesh(new THREE.BoxGeometry(Math.hypot(rlen, deckH(px) - deckH(prev)) + 0.05, 0.09, 0.09), flat(new THREE.Color(PAL.wood).offsetHSL(0, 0, -0.03)));
            rail.position.set(midx, deckH(midx) + 0.56, 3 + side * 1.08);
            rail.rotation.z = Math.atan2(deckH(px) - deckH(prev), rlen);
            bridge.add(rail);
          } else if (gapJump) {
            const stub = new THREE.Mesh(new THREE.BoxGeometry(0.8, 0.09, 0.09), flat(new THREE.Color(PAL.wood).offsetHSL(0, 0, -0.03)));
            stub.position.set(prev + 0.35, deckH(prev) + 0.42, 3 + side * 1.08);
            stub.rotation.z = -0.7;
            bridge.add(stub);
          }
          prev = px;
        });
      });
      worldGroup.add(bridge);
      if (G.youthGroup) {
        addBoxCol(-13.2, 4.22, 3.2, 0.12, 0);
        addBoxCol(-13.2, 1.78, 3.2, 0.12, 0);
      } else {
        // sealed at both gap edges; short rails on the intact ends
        addBoxCol(-12.35, 3, 0.16, 1.35, 0);
        addBoxCol(-14.35, 3, 0.16, 1.35, 0);
        addBoxCol(-10.95, 4.22, 1.0, 0.12, 0);
        addBoxCol(-10.95, 1.78, 1.0, 0.12, 0);
        addBoxCol(-15.45, 4.22, 1.0, 0.12, 0);
        addBoxCol(-15.45, 1.78, 1.0, 0.12, 0);
        // BRIDGE OUT sign by the east approach
        const signPost = new THREE.Mesh(new THREE.CylinderGeometry(0.07, 0.09, 1.15, 6), flat(PAL.bark));
        signPost.position.set(-9.3, 0.57, 4.5);
        const outPlate = makeTextPlate("BRIDGE OUT", { w: 1.8, h: 0.55, bg: "#e8d8b0", fg: "#8a2f24" });
        outPlate.position.set(-9.3, 1.25, 4.5);
        outPlate.rotation.y = 0.5;
        worldGroup.add(signPost, outPlate);
        addCircleCol(-9.3, 4.5, 0.35);
        hotspots.push({ x: -10.7, z: 3, r: 2.5, type: "bridge", label: "The bridge is out…" });
      }
      // (the old straight river walls are gone — an analytic boundary in the
      // frame loop follows the meander instead, so the bank is reachable
      // everywhere and the water still keeps you out)
      // stones laid over the worn ribbon (route 3 stops short of the bridge deck — planks reach x≈-10)
      homeRoutes.forEach((rt) => addFlagstonePath(rt.pts, rt.w));

      // ---- Cottage: one clean solid body (extruded gable profile) + roof slabs ----
      const house = new THREE.Group();
      // pentagon profile = walls AND gable ends in a single watertight piece
      const prof = new THREE.Shape();
      prof.moveTo(-2, 0); prof.lineTo(2, 0); prof.lineTo(2, 2.3);
      prof.lineTo(0, 3.55); prof.lineTo(-2, 2.3); prof.lineTo(-2, 0);
      const bodyGeo = new THREE.ExtrudeGeometry(prof, { depth: 5, bevelEnabled: false });
      bodyGeo.translate(0, 0, -2.5);
      // warm honeyed-walnut walls (PAL.bark lifted well clear of chocolate), darker timber accents
      const wallTone = new THREE.Color(PAL.bark).offsetHSL(0.012, 0.07, 0.17);
      const timberTone = new THREE.Color(PAL.bark).offsetHSL(0.004, 0.04, 0.06);
      const plankLineTone = new THREE.Color(PAL.bark).offsetHSL(0.008, 0.05, 0.115);
      const bodyMesh = new THREE.Mesh(bodyGeo, flat(wallTone));
      bodyMesh.rotation.y = Math.PI / 2; // ridge runs along X, front face at z=+2
      bodyMesh.castShadow = true; bodyMesh.receiveShadow = true;
      house.add(bodyMesh);
      // timber corner posts + base trim, flush against the walls
      const timberMat = flat(timberTone);
      [[-2.42, -1.9], [2.42, -1.9], [-2.42, 1.9], [2.42, 1.9]].forEach(([px, pz]) => {
        const post = new THREE.Mesh(new THREE.BoxGeometry(0.17, 2.34, 0.17), timberMat);
        post.position.set(px, 1.17, pz); post.castShadow = true;
        house.add(post);
      });
      // stone plinth strip — separates the timber walls from the grass (ground connection)
      const baseTrim = new THREE.Mesh(new THREE.BoxGeometry(5.24, 0.34, 4.24), flat(new THREE.Color(PAL.stone).offsetHSL(0.006, 0.02, -0.05), { roughness: 1 }));
      baseTrim.position.y = 0.17; baseTrim.receiveShadow = true; baseTrim.castShadow = true;
      house.add(baseTrim);
      // darker footing course under the plinth — the wall never meets bare grass
      const footing = new THREE.Mesh(new THREE.BoxGeometry(5.44, 0.14, 4.44), flat(new THREE.Color(PAL.stone).offsetHSL(0.004, 0.01, -0.14), { roughness: 1 }));
      footing.position.y = 0.07; footing.receiveShadow = true;
      house.add(footing);
      // trodden-dirt skirt hugging the footprint: the cabin sits IN the lawn, grass
      // reads cleared at the walls instead of clipping the planks
      const skirt = new THREE.Mesh(new THREE.CylinderGeometry(3.5, 3.78, 0.06, 18),
        flat(new THREE.Color(PAL.soil).lerp(new THREE.Color(PAL.pathStone), 0.42).offsetHSL(0.002, -0.06, -0.025), { roughness: 1 }));
      skirt.scale.set(1.0, 1, 0.76);
      skirt.position.y = 0.012;
      skirt.receiveShadow = true;
      house.add(skirt);
      // thin plank lines, flush on each face (frames cover them at openings)
      const plankLineMat = flat(plankLineTone);
      [0.62, 1.18, 1.74].forEach((py) => {
        const f = new THREE.Mesh(new THREE.BoxGeometry(4.55, 0.05, 0.04), plankLineMat);
        f.position.set(0, py, 2.02); house.add(f);
        const bk = f.clone(); bk.position.z = -2.02; house.add(bk);
        const sl = new THREE.Mesh(new THREE.BoxGeometry(0.04, 0.05, 3.7), plankLineMat);
        sl.position.set(-2.52, py, 0); house.add(sl);
        const sr = sl.clone(); sr.position.x = 2.52; house.add(sr);
      });
      // plank lines continue up the gable peaks so the end faces keep the same board
      // frequency as the long walls (no stretched bare triangle)
      [[2.32, 3.5], [2.72, 2.4], [3.1, 1.3]].forEach(([py, ln]) => {
        const gl = new THREE.Mesh(new THREE.BoxGeometry(0.04, 0.05, ln), plankLineMat);
        gl.position.set(-2.52, py, 0); house.add(gl);
        const gr2 = gl.clone(); gr2.position.x = 2.52; house.add(gr2);
      });
      // baked eave shadow: a darker AO band where the walls tuck under the roof overhang
      const eaveMat = flat(wallTone.clone().offsetHSL(0.004, 0.015, -0.125));
      [2.03, -2.03].forEach((ez) => {
        const band = new THREE.Mesh(new THREE.BoxGeometry(4.55, 0.2, 0.045), eaveMat);
        band.position.set(0, 2.19, ez);
        house.add(band);
      });
      // roof: muted terracotta (A Short Hike cabin) — slabs, alternating shingle bands, ridge cap
      const buildRoofSide = (sign) => {
        const grp = new THREE.Group();
        const slab = new THREE.Mesh(new THREE.BoxGeometry(6.0, 0.15, 2.85), flat(PAL.roof, { roughness: 0.85 }));
        slab.castShadow = true; slab.receiveShadow = true;
        grp.add(slab);
        const rowA = flat(new THREE.Color(PAL.roof).offsetHSL(0, -0.03, -0.045));
        const rowB = flat(new THREE.Color(PAL.roof).offsetHSL(0.006, -0.02, 0.025));
        [-1.02, -0.34, 0.34, 1.02].forEach((rz, i) => {
          const row = new THREE.Mesh(new THREE.BoxGeometry(6.04, 0.06, 0.58), i % 2 ? rowA : rowB);
          row.position.set(0, 0.1, rz);
          grp.add(row);
        });
        grp.rotation.x = sign * 0.544;
        grp.position.set(0, 2.9, sign * 1.17);
        return grp;
      };
      house.add(buildRoofSide(1), buildRoofSide(-1));
      const ridgeCap = new THREE.Mesh(new THREE.BoxGeometry(6.1, 0.16, 0.42), flat(new THREE.Color(PAL.roof).offsetHSL(0, -0.05, -0.08)));
      ridgeCap.position.y = 3.64; ridgeCap.castShadow = true;
      house.add(ridgeCap);
      // door: cream border trim standing PROUD of a recessed warm-brown panel (never black),
      // with a lit transom pane above — the cabin reads inhabited
      const creamMat = flat(new THREE.Color(PAL.plaster).offsetHSL(0, -0.06, 0.005));
      const doorPanel = new THREE.Mesh(new THREE.BoxGeometry(0.88, 1.56, 0.09), flat(new THREE.Color(PAL.bark).offsetHSL(0.01, 0.06, 0.015)));
      doorPanel.position.set(0, 0.78, 2.02);
      // vertical plank grooves on the door face
      const grooveMat = flat(new THREE.Color(PAL.bark).offsetHSL(0.006, 0.04, -0.05));
      [-0.16, 0.16].forEach((gx) => {
        const gr = new THREE.Mesh(new THREE.BoxGeometry(0.035, 1.44, 0.02), grooveMat);
        gr.position.set(gx, 0.78, 2.07);
        house.add(gr);
      });
      const trimL = new THREE.Mesh(new THREE.BoxGeometry(0.14, 1.78, 0.14), creamMat);
      trimL.position.set(-0.5, 0.89, 2.05);
      const trimR = trimL.clone(); trimR.position.x = 0.5;
      const trimT = new THREE.Mesh(new THREE.BoxGeometry(1.16, 0.14, 0.14), creamMat);
      trimT.position.set(0, 1.71, 2.05);
      const transom = new THREE.Mesh(new THREE.BoxGeometry(0.52, 0.2, 0.06),
        smooth(new THREE.Color(PAL.sun).offsetHSL(0, 0.05, -0.06), { emissive: new THREE.Color(PAL.sun).offsetHSL(0.005, 0.1, -0.12), emissiveIntensity: 0.85, roughness: 0.3 }));
      transom.position.set(0, 1.38, 2.08);
      const knob = new THREE.Mesh(new THREE.SphereGeometry(0.05, 6, 5), smooth(0xd9b95a, { metalness: 0.4, roughness: 0.4 }));
      knob.position.set(0.3, 0.76, 2.1);
      const step = new THREE.Mesh(new THREE.BoxGeometry(1.3, 0.14, 0.7), flat(new THREE.Color(PAL.stone).offsetHSL(0, 0, 0.03)));
      step.position.set(0, 0.07, 2.42); step.receiveShadow = true;
      house.add(doorPanel, trimL, trimR, trimT, transom, knob, step);
      // windows: cream border trim + sill, glass recessed BEHIND the trim with a calm
      // sky tint (no more blown white quads), cross mullions between
      [-1.5, 1.5].forEach((wx) => {
        const glass = new THREE.Mesh(new THREE.BoxGeometry(0.8, 0.8, 0.05),
          smooth(new THREE.Color(PAL.skyMid).offsetHSL(0.02, 0.06, -0.14), { emissive: new THREE.Color(PAL.sun).offsetHSL(0, 0.02, -0.28), emissiveIntensity: 0.22, roughness: 0.15 }));
        glass.position.set(wx, 1.42, 2.02);
        const wtL = new THREE.Mesh(new THREE.BoxGeometry(0.1, 0.98, 0.12), creamMat);
        wtL.position.set(wx - 0.44, 1.42, 2.05);
        const wtR = wtL.clone(); wtR.position.x = wx + 0.44;
        const wtT = new THREE.Mesh(new THREE.BoxGeometry(0.98, 0.1, 0.12), creamMat);
        wtT.position.set(wx, 1.9, 2.05);
        const sill = new THREE.Mesh(new THREE.BoxGeometry(1.08, 0.09, 0.2), creamMat);
        sill.position.set(wx, 0.93, 2.07); sill.castShadow = true;
        const barV = new THREE.Mesh(new THREE.BoxGeometry(0.05, 0.8, 0.05), creamMat);
        barV.position.set(wx, 1.42, 2.045);
        const barH = new THREE.Mesh(new THREE.BoxGeometry(0.8, 0.05, 0.05), creamMat);
        barH.position.set(wx, 1.42, 2.045);
        house.add(glass, wtL, wtR, wtT, sill, barV, barH);
      });
      // foundation dressing: rain barrel by the door + firewood stack under the east window
      const barrelWood = new THREE.Color(PAL.wood).lerp(new THREE.Color(PAL.bark), 0.45).offsetHSL(0, 0.1, -0.02);
      const barrel = new THREE.Mesh(new THREE.CylinderGeometry(0.21, 0.24, 0.52, 8), flat(barrelWood));
      barrel.position.set(-0.95, 0.26, 2.35); barrel.castShadow = true;
      const bandMat = flat(new THREE.Color(PAL.bark).offsetHSL(0, -0.02, -0.1));
      [0.12, 0.4].forEach((by) => {
        const band = new THREE.Mesh(new THREE.CylinderGeometry(0.235, 0.245, 0.05, 8), bandMat);
        band.position.set(-0.95, by, 2.35);
        house.add(band);
      });
      house.add(barrel);
      const logEnd = new THREE.Color(PAL.wood).offsetHSL(0.004, 0.02, 0.06);
      const logSide = new THREE.Color(PAL.bark).offsetHSL(0.006, 0.05, 0.03);
      [[1.15, 0.12, 0], [1.45, 0.12, 0.2], [1.75, 0.12, -0.15], [1.3, 0.32, 0.1], [1.6, 0.32, -0.05], [1.45, 0.5, 0]].forEach(([lx, ly, lj]) => {
        const log = new THREE.Mesh(new THREE.CylinderGeometry(0.105, 0.115, 0.62, 7),
          flat(logSide.clone().offsetHSL(0, 0, (Math.random() - 0.5) * 0.05)));
        log.rotation.x = Math.PI / 2;
        log.rotation.z = (Math.random() - 0.5) * 0.06;
        log.position.set(lx + lj * 0.1, ly, 2.28);
        log.castShadow = true;
        const cap = new THREE.Mesh(new THREE.CylinderGeometry(0.085, 0.085, 0.03, 7), flat(logEnd));
        cap.rotation.x = Math.PI / 2;
        cap.position.set(lx + lj * 0.1, ly, 2.6);
        house.add(log, cap);
      });
      // stone chimney sitting on the roof slope — warm pale stone
      const chimney = new THREE.Mesh(new THREE.BoxGeometry(0.62, 1.9, 0.62), flat(PAL.stone));
      chimney.position.set(1.5, 3.7, -0.95); chimney.castShadow = true;
      const chimTop = new THREE.Mesh(new THREE.BoxGeometry(0.78, 0.2, 0.78), flat(new THREE.Color(PAL.stone).offsetHSL(0, 0, -0.07)));
      chimTop.position.set(1.5, 4.72, -0.95);
      house.add(chimney, chimTop);
      addChimneySmoke(house, 1.5, 4.95, -0.95);
      house.position.set(6.5, 0, -7);
      house.rotation.y = -0.35;
      worldGroup.add(house);
      addBoxCol(6.5, -7, 2.65, 2.15, -0.35);

      // Garden fence — sized by the current expansion tier, gate on the south side
      worldGroup.add(makeFence(FT.x1, FT.z1, -1.1, FT.z1));
      worldGroup.add(makeFence(1.1, FT.z1, FT.x2, FT.z1));
      worldGroup.add(makeFence(FT.x1, FT.z2, FT.x2, FT.z2));
      worldGroup.add(makeFence(FT.x1, FT.z1, FT.x1, FT.z2));
      worldGroup.add(makeFence(FT.x2, FT.z1, FT.x2, FT.z2));
      // hand-dressing: small pebbles kicked along the fence line so the enclosure
      // reads as a worked space, not a prim drawn on the lawn (decor only, no collision)
      for (let i = 0; i < 9; i++) {
        const side = Math.random();
        let pbx, pbz;
        if (side < 0.5) {
          pbx = FT.x1 + 0.5 + Math.random() * (FT.x2 - FT.x1 - 1);
          pbz = (side < 0.25 ? FT.z1 : FT.z2) + (Math.random() - 0.5) * 0.65;
        } else {
          pbx = (side < 0.75 ? FT.x1 : FT.x2) + (Math.random() - 0.5) * 0.65;
          pbz = FT.z1 + 0.5 + Math.random() * (FT.z2 - FT.z1 - 1);
        }
        if (Math.abs(pbx) < 1.4 && Math.abs(pbz - FT.z1) < 0.9) continue; // keep the gate clear
        worldGroup.add(makeRock(pbx, pbz, 0.12 + Math.random() * 0.12, false, { noCol: true, noMoss: true }));
      }
      // Garden storytelling set — scarecrow, leaning tools, watering can, crates, clay
      // pot, compost heap, stepping stones. Pure decor (no colliders), every position
      // off the build-cell grid, ALL merged into ONE vertex-colored mesh (+1 draw call).
      {
        const gpParts = [];
        const fill = (bg, c) => {
          const lc = c.clone().convertSRGBToLinear();
          const cnt = bg.attributes.position.count, cols = new Float32Array(cnt * 3);
          for (let vi = 0; vi < cnt; vi++) { cols[vi * 3] = lc.r; cols[vi * 3 + 1] = lc.g; cols[vi * 3 + 2] = lc.b; }
          bg.setAttribute("color", new THREE.BufferAttribute(cols, 3));
          gpParts.push(bg);
          return bg;
        };
        const woodTool = new THREE.Color(PAL.wood).lerp(new THREE.Color(PAL.bark), 0.42).offsetHSL(0, 0.05, 0);
        const metal = new THREE.Color(PAL.stone).lerp(new THREE.Color(PAL.ambientSky), 0.3).offsetHSL(0, -0.04, -0.02);
        const straw = new THREE.Color(PAL.grassSun).offsetHSL(0.01, 0.16, 0.1);
        const shirt = new THREE.Color(PAL.roof).offsetHSL(0, -0.08, 0.02);
        const crateC = new THREE.Color(PAL.wood).offsetHSL(0.004, 0.04, -0.05);
        const potC = new THREE.Color(PAL.roof).offsetHSL(0.012, -0.02, 0.07);
        const compostC = new THREE.Color(PAL.soil).offsetHSL(0.006, -0.06, 0.06);
        const stoneC = new THREE.Color(PAL.pathStone).offsetHSL(-0.004, -0.04, -0.03);
        const jit = (c, a = 0.04) => c.clone().offsetHSL(0, 0, (Math.random() - 0.5) * a * 2);
        // -- scarecrow: the focal vertical behind the plots, just outside the north
        //    fence right of the gate (never a build cell, road is 2.3 units further on)
        {
          const sx = 2.6, sz = FT.z1 - 0.85, lean = 0.06, S = 1.18;
          const pole = fill(new THREE.CylinderGeometry(0.045 * S, 0.055 * S, 1.62 * S, 6), woodTool);
          pole.rotateZ(lean); pole.translate(sx, 0.81 * S, sz);
          const arms = fill(new THREE.CylinderGeometry(0.035 * S, 0.035 * S, 1.06 * S, 6), woodTool);
          arms.rotateZ(Math.PI / 2 + 0.05); arms.rotateY(0.18); arms.translate(sx + 0.02, 1.18 * S, sz);
          const tunic = fill(new THREE.BoxGeometry(0.4 * S, 0.52 * S, 0.22 * S), shirt);
          tunic.rotateY(0.16); tunic.rotateZ(lean); tunic.translate(sx + 0.015, 0.98 * S, sz);
          const sleeveL = fill(new THREE.BoxGeometry(0.4 * S, 0.15 * S, 0.16 * S), jit(shirt, 0.03));
          sleeveL.rotateZ(0.09); sleeveL.translate(sx - 0.38 * S, 1.18 * S, sz);
          const sleeveR = fill(new THREE.BoxGeometry(0.4 * S, 0.15 * S, 0.16 * S), jit(shirt, 0.03));
          sleeveR.rotateZ(-0.07); sleeveR.translate(sx + 0.42 * S, 1.19 * S, sz);
          const head = fill(new THREE.IcosahedronGeometry(0.17 * S, 0), straw);
          head.translate(sx + 0.04, 1.42 * S, sz);
          const hat = fill(new THREE.ConeGeometry(0.24 * S, 0.2 * S, 7), jit(straw, 0.05).offsetHSL(0, -0.04, -0.05));
          hat.rotateZ(-0.12); hat.translate(sx + 0.05, 1.58 * S, sz);
          const brim = fill(new THREE.CylinderGeometry(0.26 * S, 0.28 * S, 0.03, 8), jit(straw, 0.04).offsetHSL(0, -0.05, -0.08));
          brim.rotateZ(-0.12); brim.translate(sx + 0.05, 1.5 * S, sz);
          const skirt = fill(new THREE.ConeGeometry(0.2 * S, 0.34 * S, 7), jit(straw, 0.05));
          skirt.translate(sx + 0.01, 0.6 * S, sz);
        }
        // -- leaning tools against the inside of the west fence (rake + spade)
        {
          const tx = FT.x1 + 0.14, tz = FT.z2 - 1.35;
          const rakeH = fill(new THREE.CylinderGeometry(0.028, 0.028, 1.24, 5), jit(woodTool));
          rakeH.rotateZ(-0.42); rakeH.translate(tx + 0.26, 0.56, tz);
          const rakeHead = fill(new THREE.BoxGeometry(0.05, 0.07, 0.34), metal);
          rakeHead.translate(tx + 0.5, 0.06, tz);
          const spadeH = fill(new THREE.CylinderGeometry(0.028, 0.028, 1.1, 5), jit(woodTool));
          spadeH.rotateZ(-0.36); spadeH.rotateY(0.3); spadeH.translate(tx + 0.22, 0.5, tz + 0.55);
          const spadeB = fill(new THREE.BoxGeometry(0.16, 0.24, 0.035), metal.clone().offsetHSL(0, 0, -0.04));
          spadeB.rotateX(0.16); spadeB.translate(tx + 0.4, 0.12, tz + 0.62);
        }
        // -- watering can resting by the front-left bed (mid-frame from the south camera)
        {
          const wx = FT.cols[0] + 1.55, wz = FT.rows[1] + 0.75, rot = 0.7;
          const body = fill(new THREE.CylinderGeometry(0.17, 0.2, 0.3, 8), metal.clone().offsetHSL(0, 0, 0.04));
          body.translate(wx, 0.15, wz);
          const spout = fill(new THREE.CylinderGeometry(0.03, 0.055, 0.36, 5), jit(metal, 0.03));
          spout.rotateZ(1.05); spout.rotateY(rot); spout.translate(wx + Math.cos(rot) * 0.27, 0.25, wz - Math.sin(rot) * 0.27);
          const handle = fill(new THREE.BoxGeometry(0.06, 0.17, 0.035), jit(metal, 0.03));
          handle.rotateY(rot); handle.translate(wx - Math.cos(rot) * 0.21, 0.3, wz + Math.sin(rot) * 0.21);
        }
        // -- crate pair + terracotta pot tucked in the near-right fence corner
        {
          const cx = FT.x2 - 0.62, cz = FT.z2 - 0.66;
          const c1 = fill(new THREE.BoxGeometry(0.52, 0.34, 0.44), jit(crateC));
          c1.rotateY(0.22); c1.translate(cx, 0.17, cz);
          const c2 = fill(new THREE.BoxGeometry(0.4, 0.28, 0.36), jit(crateC, 0.06));
          c2.rotateY(-0.35); c2.translate(cx - 0.12, 0.48, cz + 0.05);
          const pot = fill(new THREE.CylinderGeometry(0.13, 0.09, 0.2, 7), potC);
          pot.translate(cx - 0.62, 0.1, cz + 0.28);
          const potSoil = fill(new THREE.CylinderGeometry(0.1, 0.1, 0.05, 7), compostC);
          potSoil.translate(cx - 0.62, 0.19, cz + 0.28);
        }
        // -- compost heap against the outside of the west fence, hand fork stuck in
        {
          const mx = FT.x1 - 0.62, mz = FT.z2 - 0.42;
          const heap = fill(new THREE.IcosahedronGeometry(0.34, 0), compostC);
          heap.scale(1.15, 0.55, 1); heap.rotateY(0.6); heap.translate(mx, 0.14, mz);
          const forkH = fill(new THREE.CylinderGeometry(0.022, 0.022, 0.62, 5), jit(woodTool));
          forkH.rotateZ(0.5); forkH.rotateY(0.4); forkH.translate(mx + 0.14, 0.44, mz - 0.1);
        }
        // -- worn stepping stones up the central walkway from the gate
        for (let si = 0; si < 5; si++) {
          const st = fill(new THREE.CylinderGeometry(0.2 + Math.random() * 0.07, 0.24 + Math.random() * 0.07, 0.055, 6), jit(stoneC, 0.05));
          st.rotateY(Math.random() * Math.PI);
          st.translate((Math.random() - 0.5) * 0.24, 0.03, FT.z1 + 0.7 + si * 1.12);
        }
        const gardenProps = new THREE.Mesh(mergeGeoms(gpParts), flat(0xffffff, { vertexColors: true, roughness: 1 }));
        gardenProps.castShadow = true; gardenProps.receiveShadow = true;
        worldGroup.add(gardenProps);
      }
      // plots: 6 starters on the first two rows + every purchased kit
      syncHomePlotCount();
      const basePlotPos = [];
      for (let r = 0; r < 2; r++) for (let c = 0; c < 3; c++) basePlotPos.push([FT.cols[c], FT.rows[r]]);
      const allPlotPos = [...basePlotPos, ...G.build.extraPlots.map((e) => [e.x, e.z])];
      addPlots(G.homePlots, allPlotPos, false);
      // build grid cells for this tier
      buildCells = [];
      FT.cols.forEach((cx) => FT.rows.forEach((rz) => {
        const taken = allPlotPos.some(([px, pz]) => Math.hypot(px - cx, pz - rz) < 0.6);
        buildCells.push({ x: cx, z: rz, taken });
      }));
      // ghost plot for Build Mode
      ghostMesh = new THREE.Group();
      const gRim = new THREE.Mesh(new THREE.BoxGeometry(1.7, 0.14, 1.7),
        new THREE.MeshStandardMaterial({ color: SRGB(PAL.wood), transparent: true, opacity: 0.5, emissive: SRGB(0x6ee87a), emissiveIntensity: 0.5, flatShading: true }));
      gRim.position.y = 0.05;
      const gSoil = new THREE.Mesh(new THREE.BoxGeometry(1.5, 0.22, 1.5),
        new THREE.MeshStandardMaterial({ color: SRGB(PAL.soil), transparent: true, opacity: 0.5, emissive: SRGB(0x6ee87a), emissiveIntensity: 0.4, flatShading: true }));
      gSoil.position.y = 0.11;
      ghostMesh.add(gRim, gSoil);
      ghostMesh.visible = false;
      ghostMesh.userData = { gRim, gSoil };
      worldGroup.add(ghostMesh);
      refreshBuildMarkers();

      // Cave: rock archway (pillars + lintel) with a true dark interior room.
      // The big mound sits well BEHIND the entrance so nothing intersects it.
      // cool gray-mauve stone (ties the cave to the background mountains) with a faint
      // self-glow floor so no unlit facet can ever reach black
      const caveStone = (dl) => {
        const c = new THREE.Color(PAL.stone).lerp(new THREE.Color(PAL.ambientSky), 0.24).offsetHSL(0.01, 0.03, dl);
        return flat(c, { roughness: 1, emissive: c.clone().offsetHSL(0.01, 0.04, -0.02), emissiveIntensity: 0.16 });
      };
      const mound = new THREE.Mesh(new THREE.IcosahedronGeometry(5.4, 0), caveStone(-0.13));
      mound.position.set(0, 1.7, -19.6);
      mound.scale.set(1.6, 1.15, 1.0);
      mound.rotation.set(0.15, 0.5, 0.05);
      mound.castShadow = true; mound.receiveShadow = true;
      worldGroup.add(mound);
      const mound2 = new THREE.Mesh(new THREE.IcosahedronGeometry(3.1, 0), caveStone(-0.17));
      mound2.position.set(-5.6, 1.0, -16.8);
      mound2.rotation.set(0.5, 1.2, 0.2);
      mound2.scale.set(1.2, 0.9, 1);
      mound2.castShadow = true; mound2.receiveShadow = true;
      worldGroup.add(mound2);
      const mound3 = mound2.clone();
      mound3.position.set(5.6, 0.9, -16.6);
      mound3.rotation.set(1.1, 2.3, 0.4);
      worldGroup.add(mound3);
      // NO moss caps on the cave mass: the hand-placed flat caps hovered off the
      // irregular boulder faces (and showed dark undersides from the entrance
      // view) — the cave reads better as bare stone, grounded by base grass.
      // interior room: ONE merged vertex-colored shell with a mouth->depths gradient —
      // warm ember-brown at the opening falling toward near-black at the back wall, so
      // the cavity reads DEEP instead of a flat evenly-lit backdrop. The ember point
      // light layers its warm falloff on top of the baked gradient.
      const innerNear = new THREE.Color(PAL.soil).offsetHSL(0.004, -0.09, -0.075).convertSRGBToLinear();
      const innerFar = new THREE.Color(PAL.soil).offsetHSL(-0.01, -0.22, -0.245).convertSRGBToLinear();
      const paintDepth = (bg) => {
        const posA = bg.attributes.position, cols = new Float32Array(posA.count * 3);
        const dc = new THREE.Color();
        for (let vi = 0; vi < posA.count; vi++) {
          // t: 0 at the mouth plane (z=-12) -> 1 deep inside (z=-16.4); slight extra
          // darkening low in the corners so the floor line melts into shadow
          const t = Math.min(1, Math.max(0, (-12 - posA.getZ(vi)) / 4.4));
          const corner = Math.min(1, Math.abs(posA.getX(vi)) / 2.3) * 0.14;
          // ceilings are shadowed from the very mouth — without this the warm
          // ceiling band read as a bright floating shelf from outside
          const ceil = posA.getY(vi) > 2.9 ? 0.5 : 0;
          dc.copy(innerNear).lerp(innerFar, Math.min(1, Math.pow(t, 0.75) + corner * t + ceil));
          cols[vi * 3] = dc.r; cols[vi * 3 + 1] = dc.g; cols[vi * 3 + 2] = dc.b;
        }
        bg.setAttribute("color", new THREE.BufferAttribute(cols, 3));
        return bg;
      };
      const roomParts = [];
      const roomBox = (w, h, d, x, y, z) => {
        const bgeo = new THREE.BoxGeometry(w, h, d);
        bgeo.translate(x, y, z);
        roomParts.push(paintDepth(bgeo));
      };
      roomBox(4.6, 3.4, 0.3, 0, 1.7, -16.4);   // back wall
      roomBox(0.3, 3.4, 4.6, -2.3, 1.7, -14.3); // left wall
      roomBox(0.3, 3.4, 4.6, 2.3, 1.7, -14.3);  // right wall
      roomBox(4.9, 0.3, 4.6, 0, 3.3, -14.3);    // ceiling
      roomBox(4.6, 0.06, 4.6, 0, 0.03, -14.3);  // floor
      const caveRoom = new THREE.Mesh(mergeGeoms(roomParts),
        // whisper of ember-warm self-glow so the deepest corner never hits pure #000
        flat(0xffffff, { vertexColors: true, roughness: 1, emissive: innerNear.clone().offsetHSL(0.014, 0.18, -0.04), emissiveIntensity: 0.14 }));
      worldGroup.add(caveRoom);
      // facade fill: plug every sightline beside/above the room out to the mounds so
      // no backface or sky void can peek through the entrance frame (the old black
      // rectangular hole above the mouth)
      const fillMat = caveStone(-0.11);
      const mkFill = (r, sx, sy, sz, x, y, z, rx, ry, rz) => {
        const m = new THREE.Mesh(new THREE.IcosahedronGeometry(r, 0), fillMat);
        m.position.set(x, y, z); m.scale.set(sx, sy, sz); m.rotation.set(rx, ry, rz);
        m.castShadow = true; m.receiveShadow = true;
        worldGroup.add(m);
      };
      // shoulder boulders over the room, tucked behind the lintel + under the mound crown
      mkFill(2.6, 1.9, 0.85, 1.0, -1.1, 4.35, -15.2, 0.2, 0.7, 0.1);
      mkFill(2.6, 1.8, 0.8, 1.0, 1.6, 4.3, -15.1, 0.4, 2.1, 0.15);
      // flank boulders plugging the pillar-to-mound gaps left and right of the room
      mkFill(2.0, 1.15, 1.5, 1.2, -4.0, 1.7, -14.6, 0.3, 1.4, 0.1);
      mkFill(2.0, 1.15, 1.5, 1.2, 4.0, 1.7, -14.6, 0.7, 2.6, 0.2);
      // rubble seating the mouth: small decorative stones (no collision, no moss)
      [[-2.7, -11.7, 0.3], [-1.9, -11.4, 0.2], [2.4, -11.5, 0.26], [3.1, -11.9, 0.34], [1.2, -11.3, 0.16], [-3.9, -11.9, 0.22], [4.3, -11.6, 0.18]]
        .forEach(([rx, rz, rs]) => worldGroup.add(makeRock(rx, rz, rs, false, { noCol: true, noMoss: true })));
      // entrance frame: stacked pillar boulders + a lintel stone across the top
      const mkPillar = (x) => {
        const p1 = new THREE.Mesh(new THREE.IcosahedronGeometry(1.5, 0), caveStone(-0.08));
        p1.position.set(x, 1.0, -12.4);
        p1.rotation.set(Math.random(), Math.random(), Math.random());
        p1.scale.set(0.95, 1.25, 1.1);
        p1.castShadow = true; p1.receiveShadow = true;
        const p2 = new THREE.Mesh(new THREE.IcosahedronGeometry(1.0, 0), caveStone(-0.12));
        p2.position.set(x * 0.92, 2.6, -12.7);
        p2.rotation.set(Math.random(), Math.random(), Math.random());
        p2.castShadow = true;
        worldGroup.add(p1, p2);
      };
      mkPillar(-3.3); mkPillar(3.3);
      const lintel = new THREE.Mesh(new THREE.IcosahedronGeometry(1.7, 0), caveStone(-0.10));
      lintel.position.set(0, 3.75, -13.1);
      lintel.scale.set(2.5, 0.95, 0.95);
      lintel.rotation.set(0.2, 0.4, 0.1);
      lintel.castShadow = true;
      worldGroup.add(lintel);
      // plug the lintel-to-mound sliver where the interior ceiling (warm brown)
      // showed through above the mouth's right corner
      mkFill(1.1, 2.0, 0.95, 1.0, 1.95, 3.5, -12.9, 0.3, 1.2, 0.15);
      worldGroup.add(makeRock(5.4, -13.2, 1.3, true, { noMoss: true }));
      worldGroup.add(makeRock(-5.4, -12.8, 1.2, true, { noMoss: true }));
      // colliders: pillars, sealed cavity, and the rock mass behind
      addCircleCol(-3.3, -12.4, 1.5);
      addCircleCol(3.3, -12.4, 1.5);
      addBoxCol(0, -14.6, 2.3, 2.0, 0);
      addCircleCol(-4.6, -19.2, 4.4);
      addCircleCol(4.6, -19.2, 4.4);
      addCircleCol(0, -21.5, 4.2);
      addCircleCol(-5.6, -16.8, 2.6);
      addCircleCol(5.6, -16.6, 2.6);

      caveLight = new THREE.PointLight(SRGB(0xff8a3a), 1.5, 13);
      caveLight.position.set(0, 1.6, -13.8);
      worldGroup.add(caveLight);
      for (let i = 0; i < 7; i++) {
        const em = new THREE.Mesh(new THREE.SphereGeometry(0.06, 5, 5),
          new THREE.MeshStandardMaterial({ color: SRGB(0xff9a4a), emissive: SRGB(0xff7a20), emissiveIntensity: 2 }));
        em.userData = { ph: Math.random() * 9, sp: 0.4 + Math.random() * 0.5, x: (Math.random() - 0.5) * 2.4 };
        worldGroup.add(em); embers.push(em);
      }

      // soft contact shadow under Ember — anchors the dragon to the cave threshold
      const dragonShadow = new THREE.Mesh(new THREE.CircleGeometry(1.0, 16),
        new THREE.MeshBasicMaterial({ color: new THREE.Color(PAL.soil).offsetHSL(0, -0.18, -0.27).convertSRGBToLinear(), transparent: true, opacity: 0.38, depthWrite: false }));
      dragonShadow.rotation.x = -Math.PI / 2;
      dragonShadow.scale.set(1.25, 0.9, 1);
      dragonShadow.position.set(0, 0.04, -11.35);
      worldGroup.add(dragonShadow);
      // the river's crankiest resident
      turtle = makeTurtle();
      turtle.position.set(RIVER_X(10), -0.16, 10);
      turtle.userData.z = 10;
      turtle.userData.dir = -1;
      G.turtleSeq = null;
      G.turtleCd = 0;
      worldGroup.add(turtle);

      dragon = makeDragon();
      dragon.position.set(0, 0, -11.4);
      // floating hunger meter — always above Ember, same 7-gem language as
      // the plaque. Lives in worldGroup (not the dragon group) so his squash
      // and-stretch animation can't warp it; updateDragon tracks his position.
      {
        const cv = document.createElement("canvas");
        cv.width = 448; cv.height = 112;
        const tex = new THREE.CanvasTexture(cv);
        // fog:false — the cave sits deep in the fogged distance and the scene
        // fog was washing the meter to pastel; UI must stay full-strength
        emberBar = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, transparent: true, depthWrite: false, fog: false }));
        emberBar.scale.set(3.0, 0.75, 1);
        emberBar.userData = { cv, tex, last: "" };
        worldGroup.add(emberBar);
      }
      dragon.scale.setScalar(0.7); // lab rig is taller than the old model
      dragonHome.copy(dragon.position);
      worldGroup.add(dragon);
      for (let i = 0; i < 3; i++) {
        const sp = new THREE.Sprite(new THREE.SpriteMaterial({ map: zzzTex, transparent: true, opacity: 0, depthWrite: false }));
        sp.userData = { ph: i / 3 };
        worldGroup.add(sp); zzz.push(sp);
      }

      // signs face south — the follow-camera always views from the south,
      // so the board reads face-on to the player
      worldGroup.add(makeSign(-20, 1.4, 0));
      [[-9.5, -8, 1.3], [12, -10, 1.1], [-9, 15.5, 1.4], [14, 12, 1.2], [-19, 6.5, 1.0], [18, -3, 1.3], [9, 16, 1.1], [-20.5, -14, 1.4], [20, 15, 1.2], [-19, 18, 1.1], [16, 18, 1.3], [24, 6, 1.0], [-21, -4, 1.2]]
        .forEach(([x, z, s]) => { if (!inGarden(x, z, 1.3)) worldGroup.add(makeTree(x, z, s)); });
      addPetals([[12, -10], [9, 16], [20, 15], [-9, 15.5]], [0x8fbe62, 0xd8c05a], 14, 3.6);
      // 3 size classes: pebble-cluster smalls, mids, plus half-buried boulders with grass skirts
      [[-8, 0, 0.8, false], [7, 7, 0.7, false], [-3, -6, 0.85, false], [11, 5, 0.6, false], [-9.4, -2.5, 0.65, true],
       [13.5, 17.5, 0.42, false], [-6.2, 8.6, 0.38, false], [19.5, 12.5, 0.45, false], [8.5, -3.2, 0.4, true]]
        .forEach(([x, z, s, d]) => { if (!inGarden(x, z, 1.2)) worldGroup.add(makeRock(x, z, s, d)); });
      [[15.5, 22.5, 1.5, false], [-12.5, 12.5, 1.35, false], [10.5, 10.8, 1.2, true]]
        .forEach(([x, z, s, d]) => { if (!inGarden(x, z, 1.2)) worldGroup.add(makeRock(x, z, s, d, { sink: true })); });
      const homeAvoid = (x, z) =>
        (Math.abs(z - 3) < 1.6 && Math.abs(x) < 26) ||
        (Math.abs(x) < 1.5 && z > -5 && z < 7) ||
        inGarden(x, z, 0.9) ||
        Math.hypot(x, z + 16) < 7 ||
        Math.abs(x - RIVER_X(z)) < 3.6;
      // hero flowers: clumps of 2-4 seeded where the eye travels — path shoulders,
      // the garden fence line — plus a few free meadow drifts (never far-corner-only)
      const heroSeeds = [];
      for (let ci = 0; ci < 9; ci++) heroSeeds.push([(Math.random() - 0.5) * 40, (Math.random() - 0.5) * 40]);
      for (let ci = 0; ci < 8; ci++) heroSeeds.push([(Math.random() - 0.5) * 44, 3 + (Math.random() < 0.5 ? -1 : 1) * (2.4 + Math.random() * 1.6)]); // road shoulders
      for (let ci = 0; ci < 6; ci++) { // garden fence line, just outside the rails
        const t = Math.random();
        heroSeeds.push(Math.random() < 0.5
          ? [FT.x1 + (FT.x2 - FT.x1) * t, (Math.random() < 0.5 ? FT.z1 : FT.z2) + (Math.random() < 0.5 ? -1 : 1) * 1.6]
          : [(Math.random() < 0.5 ? FT.x1 : FT.x2) + (Math.random() < 0.5 ? -1 : 1) * 1.6, FT.z1 + (FT.z2 - FT.z1) * t]);
      }
      for (const [cx, cz] of heroSeeds) {
        if (homeAvoid(cx, cz)) continue;
        const k = 2 + Math.floor(Math.random() * 3);
        for (let fi = 0; fi < k; fi++) {
          const fa = Math.random() * Math.PI * 2, fr = 0.35 + Math.random() * 0.85;
          const fx = cx + Math.cos(fa) * fr, fz = cz + Math.sin(fa) * fr;
          if (!homeAvoid(fx, fz)) worldGroup.add(mixFlower(fx, fz));
        }
      }
      [[9.5, 9.5, 1], [-9.5, 17, 0.9], [16, 6.5, 1.1], [-19, -6, 1], [11, -13, 0.9], [-8.5, -3.5, 0.8], [21, 9, 1]]
        .forEach(([x, z, bs]) => { if (!inGarden(x, z, 1.2)) worldGroup.add(makeBush(x, z, bs)); });
      addSprouts(430, 64, homeAvoid);

      const fenceEdges = [
        [FT.x1, FT.z1 - 1.5, FT.x2, FT.z1 - 1.5], [FT.x1, FT.z2 + 1.5, FT.x2, FT.z2 + 1.5],
        [FT.x1 - 1.5, FT.z1, FT.x1 - 1.5, FT.z2], [FT.x2 + 1.5, FT.z1, FT.x2 + 1.5, FT.z2],
      ];
      addGrass(7800, 70, homeAvoid);
      addGroundPatches(90, 70, homeAvoid);
      addWildflowers(400, 66, homeAvoid, fenceEdges);
      addForestRing(34, 40, 60, [[24, 3], [-24, 3]]);
      addMountains([[-34, -52, 17, 21, true], [8, -58, 21, 26, true], [44, -46, 15, 17, false], [-52, 20, 14, 15, true], [52, 26, 16, 18, false]]);
      addClouds(6);
      addButterflies(6, 30);

      // east + west world edges: nobody walks around the map entrances
      addBoxCol(25.0, 0, 0.2, 34);            // east back wall
      addBoxCol(23.6, 5.0, 1.8, 0.15);        // east funnel, north lip
      addBoxCol(23.6, 1.0, 1.8, 0.15);        // east funnel, south lip
      addBoxCol(-25.0, 0, 0.2, 34);           // west back wall
      addBoxCol(-23.6, 5.0, 1.8, 0.15);       // west funnel, north lip
      addBoxCol(-23.6, 1.0, 1.8, 0.15);       // west funnel, south lip
      exits = [
        { x: 24, z: 3, r: 2.2, to: "TOWN", spawn: [-16, 0], label: "Meadow Town →" },
        { x: -24, z: 3, r: 2.2, to: "CHURCH", spawn: [26, 0], label: "← " + (G.activeGarden?.name || ((window.YGTEEV?.profile?.memberships || []).length > 1 ? "Community Gardens" : "Community Garden")) },
      ];
      hotspots = [{ x: 0, z: -10.4, r: 3.4, type: "dragon", label: "Feed Ember the dragon" }];

      // —— Glowlands: Home Garden annex (Eastgate arch, Lantern Post,
      //    Wayfarer's Table, Satchel Hook) — additive, after props are placed.
      buildGlowHome();

      // one-time find: a glowing pouch dropped on the road toward town
      if (!G.goldBagFound) {
        goldBag = new THREE.Group();
        const sack = new THREE.Mesh(new THREE.IcosahedronGeometry(0.32, 0), flat(0xa87848, { roughness: 0.9 }));
        sack.scale.set(1, 0.82, 1); sack.position.y = 0.27; sack.castShadow = true;
        const neck = new THREE.Mesh(new THREE.CylinderGeometry(0.09, 0.15, 0.15, 6), flat(0x8a5f2e));
        neck.position.y = 0.56;
        const tie = new THREE.Mesh(new THREE.TorusGeometry(0.1, 0.028, 5, 8), flat(0x6e4a2c));
        tie.rotation.x = Math.PI / 2; tie.position.y = 0.52;
        goldBag.add(sack, neck, tie);
        const coinMat = new THREE.MeshStandardMaterial({ color: SRGB(0xffd45e), emissive: SRGB(0xd8a428), emissiveIntensity: 0.5, roughness: 0.3 });
        [[0.32, 0.03, 0.18, 0.4], [0.42, 0.02, -0.08, 1.2], [-0.3, 0.02, 0.3, 2.1]].forEach(([cx, cy, cz, rot]) => {
          const coin = new THREE.Mesh(new THREE.CylinderGeometry(0.065, 0.065, 0.028, 8), coinMat);
          coin.position.set(cx, cy + 0.014, cz); coin.rotation.y = rot;
          goldBag.add(coin);
        });
        const bagGlow = new THREE.Sprite(new THREE.SpriteMaterial({ map: glowTex, color: SRGB(0xffd870), transparent: true, opacity: 0.55, depthWrite: false, blending: THREE.AdditiveBlending }));
        bagGlow.scale.set(1.7, 1.7, 1);
        bagGlow.position.y = 0.4;
        goldBag.add(bagGlow);
        goldBag.userData.glow = bagGlow;
        // floating "!" so the find can't be missed
        const mark = new THREE.Group();
        const markMat = new THREE.MeshStandardMaterial({ color: SRGB(0xffc832), emissive: SRGB(0xd89a18), emissiveIntensity: 0.9, roughness: 0.4 });
        const markBar = new THREE.Mesh(new THREE.CylinderGeometry(0.075, 0.105, 0.5, 6), markMat);
        markBar.position.y = 0.42;
        const markDot = new THREE.Mesh(new THREE.SphereGeometry(0.085, 8, 6), markMat);
        mark.add(markBar, markDot);
        mark.position.y = 1.0;
        goldBag.add(mark);
        goldBag.userData.mark = mark;
        goldBag.scale.setScalar(1.45);
        goldBag.position.set(8.5, 0, 3.9);
        worldGroup.add(goldBag);
        hotspots.push({ x: 8.5, z: 3.9, r: 2.1, type: "goldbag", label: "A glowing pouch lies in the road…" });
        addCircleCol(8.5, 3.9, 0.62); // solid until picked up
        goldBag.userData.col = colliders[colliders.length - 1];
      }

      spawnRedBags(); // today's hidden question-pouches (if the server list is in)
    }

    // ---- daily red bags: hidden Bible-question pouches on the HOME map ----
    // 12 hiding places in the grass near trees/bushes — clear of the road,
    // the path, the max-tier garden fence, the cave mouth, and the river.
    // The server picks 3 spot indexes per day; we just dress the set.
    const RED_BAG_SPOTS = [
      [19.4, -4.6], [12.8, -12.2], [-7.6, -6.2], [17.6, 15.8],
      [-6.0, 22.6], [5.2, 23.8], [23.0, 18.5], [27.5, -9.0],
      [26.8, 9.4], [-4.5, 26.5], [11.5, -17.5], [-7.8, 27.0],
    ];
    function makeRedBag() {
      const bag = new THREE.Group();
      const sack = new THREE.Mesh(new THREE.IcosahedronGeometry(0.32, 0), flat(0xa83232, { roughness: 0.9 }));
      sack.scale.set(1, 0.82, 1); sack.position.y = 0.27; sack.castShadow = true;
      const neck = new THREE.Mesh(new THREE.CylinderGeometry(0.09, 0.15, 0.15, 6), flat(0x7a2424));
      neck.position.y = 0.56;
      const tie = new THREE.Mesh(new THREE.TorusGeometry(0.1, 0.028, 5, 8), flat(0x5c1c1c));
      tie.rotation.x = Math.PI / 2; tie.position.y = 0.52;
      bag.add(sack, neck, tie);
      const bagGlow = new THREE.Sprite(new THREE.SpriteMaterial({ map: glowTex, color: SRGB(0xff6a5a), transparent: true, opacity: 0.38, depthWrite: false, blending: THREE.AdditiveBlending }));
      bagGlow.scale.set(1.4, 1.4, 1);
      bagGlow.position.y = 0.4;
      bag.add(bagGlow);
      bag.userData.glow = bagGlow;
      // small floating "!" — subtler than the gold find, but spottable
      const mark = new THREE.Group();
      const markMat = new THREE.MeshStandardMaterial({ color: SRGB(0xe0483a), emissive: SRGB(0xb02a20), emissiveIntensity: 0.9, roughness: 0.4 });
      const markBar = new THREE.Mesh(new THREE.CylinderGeometry(0.075, 0.105, 0.5, 6), markMat);
      markBar.position.y = 0.42;
      const markDot = new THREE.Mesh(new THREE.SphereGeometry(0.085, 8, 6), markMat);
      mark.add(markBar, markDot);
      mark.position.y = 0.92;
      bag.add(mark);
      bag.userData.mark = mark;
      bag.scale.setScalar(1.15);
      return bag;
    }
    function spawnRedBags() {
      if (G.map !== "HOME" || !worldGroup) return;
      (G.redBags || []).forEach((b) => {
        if (b.status !== "hidden" && b.status !== "opened") return; // answered = gone
        if (redBagMeshes[b.bag_idx]) return;
        const [x, z] = RED_BAG_SPOTS[b.spot % RED_BAG_SPOTS.length];
        const bag = makeRedBag();
        bag.position.set(x, terrainY ? terrainY(x, z) : 0, z);
        worldGroup.add(bag);
        hotspots.push({ x, z, r: 1.9, type: "redbag", bagIdx: b.bag_idx, label: "A little red pouch hides in the grass…" });
        addCircleCol(x, z, 0.5);
        bag.userData.col = colliders[colliders.length - 1];
        redBagMeshes[b.bag_idx] = bag;
      });
    }
    function removeRedBag(bagIdx, burst) {
      const m = redBagMeshes[bagIdx];
      if (m) {
        if (burst) spawnBurst(m.position.x, m.position.z, 0xe05a4a, 8, { glow: true, vy: 2.0, y0: 0.4 });
        const ci = colliders.indexOf(m.userData.col);
        if (ci >= 0) colliders.splice(ci, 1);
        worldGroup.remove(m);
        delete redBagMeshes[bagIdx];
      }
      hotspots = hotspots.filter((h) => !(h.type === "redbag" && h.bagIdx === bagIdx));
    }
    // Called by the question card after the server grades the answer.
    // The reward was already granted server-side (xp) or is client-owned
    // (gold, lives in the garden save) — this applies it to the session.
    G.redBagResolve = (bagIdx, r) => {
      const b = (G.redBags || []).find((x) => x.bag_idx === bagIdx);
      if (b) b.status = r.correct ? "correct" : "wrong";
      removeRedBag(bagIdx, true);
      if (r.correct) {
        if (r.reward_kind === "gold") {
          G.gold += r.reward_amount;
          SFX.coin(2);
          if (G.flyCoins) G.flyCoins(Math.min(2 + r.reward_amount, 8));
        } else {
          if (typeof r.total_xp === "number") G.xp = r.total_xp;
          else G.xp += r.reward_amount;
          SFX.sparkle();
          spawnFloatie(playerPos.x, playerPos.z, `+${r.reward_amount} ✨`, 2.2);
        }
        G.playerHopT = 0.32;
      }
    };

    // -------- TOWN --------
    function buildTown() {
      clearWorld();
      setAtmosphere(PAL.skyTop, PAL.skyMid, PAL.skyHorizon, PAL.fog, PAL.sun, 1.45, PAL.ambientSky, PAL.ambientGnd);

      terrainY = makeTerrain(
        [{ x: 14, z: -13, r: 6, h: 1.2 }, { x: -14, z: 13, r: 6, h: 1.3 }, { x: 16, z: 12, r: 6, h: 1.2 }, { x: -16, z: -12, r: 7, h: 1.4 }],
        [{ x1: -22, z1: -1.7, x2: 18, z2: 1.7, f: 3 }, { x1: -1.5, z1: -11, x2: 1.5, z2: 1, f: 3 },
         { c: 1, x: 11, z: 19, r: 4.2, f: 3 }, { c: 1, x: -13.5, z: 18.5, r: 4, f: 3 }, { c: 1, x: -4.5, z: 20.5, r: 4, f: 3 },
         { x1: -8.6, z1: -10.4, x2: 8.6, z2: -3, f: 3 }, { c: 1, x: 0, z: 5, r: 3.6, f: 3 },
         { x1: -16.1, z1: -11.5, x2: 11.9, z2: 12.9, f: 3 }]
      );
      const townRoutes = [
        { pts: [[-20, 0], [-15.9, 0]], w: 2.2 },
        { pts: [[11.6, 0], [16, 0]], w: 2.2 },
      ];
      setPathRoutes(townRoutes);
      worldGroup.add(makeGround(66, PAL.grassBase, (x, z, c) => {
        if (x > -16.1 && x < 11.9 && z > -11.5 && z < 12.9) c.lerp(MORTAR, 0.85);
      }));
      addPavedPlaza(-15.6, -11, 11.4, 12.4); // wide enough that no building overhangs the edge
      townRoutes.forEach((rt) => addFlagstonePath(rt.pts, rt.w));

      // warm plaster set (all derived from PAL.plaster) + roof desaturator (~25%)
      // so every roof keeps its hue identity but sits inside the palette
      const PLASTER_CREAM = new THREE.Color(PAL.plaster);
      const PLASTER_SAGE = new THREE.Color(PAL.plaster).offsetHSL(0.101, -0.21, -0.115);
      const PLASTER_LAV = new THREE.Color(PAL.plaster).offsetHSL(0.614, -0.28, -0.07);
      const roofTone = (hex) => {
        const c = new THREE.Color(hex), hsl = { h: 0, s: 0, l: 0 };
        c.getHSL(hsl);
        return c.setHSL(hsl.h, hsl.s * 0.75, hsl.l);
      };

      function makeBuilding(x, z, w, d, h, wallC, roofC, rotY = 0) {
        const b = new THREE.Group();
        // solid extruded body: walls + gable ends in one piece (ridge along X)
        const hd2 = d / 2, rise = d * 0.36;
        const bProf = new THREE.Shape();
        bProf.moveTo(-hd2, 0); bProf.lineTo(hd2, 0); bProf.lineTo(hd2, h);
        bProf.lineTo(0, h + rise); bProf.lineTo(-hd2, h); bProf.lineTo(-hd2, 0);
        const bGeo = new THREE.ExtrudeGeometry(bProf, { depth: w, bevelEnabled: false });
        bGeo.translate(0, 0, -w / 2);
        const walls = new THREE.Mesh(bGeo, flat(wallC));
        walls.rotation.y = Math.PI / 2;
        walls.castShadow = true; walls.receiveShadow = true;
        b.add(walls);
        // overhanging roof slabs + ridge cap
        const slopeLen = Math.hypot(hd2 + 0.3, rise) + 0.15;
        const ang = Math.atan2(rise, hd2 + 0.3);
        [1, -1].forEach((sign) => {
          const slab = new THREE.Mesh(new THREE.BoxGeometry(w + 0.7, 0.13, slopeLen), flat(roofC, { roughness: 0.8 }));
          slab.rotation.x = sign * ang;
          slab.position.set(0, h + rise / 2 + 0.04, sign * (hd2 + 0.3) / 2);
          slab.castShadow = true;
          b.add(slab);
        });
        const cap = new THREE.Mesh(new THREE.BoxGeometry(w + 0.8, 0.13, 0.3), flat(roofC));
        cap.position.y = h + rise + 0.05; cap.castShadow = true;
        b.add(cap);
        const door = new THREE.Mesh(new THREE.BoxGeometry(0.8, 1.4, 0.1), flat(new THREE.Color(PAL.bark).offsetHSL(0, 0.02, -0.04)));
        door.position.set(0, 0.7, d / 2 + 0.05);
        const frame = new THREE.Mesh(new THREE.BoxGeometry(0.85, 0.85, 0.1), flat(PLASTER_CREAM));
        frame.position.set(w / 4 + 0.3, h * 0.55, d / 2 + 0.04);
        const win = new THREE.Mesh(new THREE.BoxGeometry(0.68, 0.68, 0.1),
          smooth(0x9fd0e8, { emissive: 0xfff2c0, emissiveIntensity: 0.3, roughness: 0.2 }));
        win.position.set(w / 4 + 0.3, h * 0.55, d / 2 + 0.07);
        b.add(door, frame, win);
        b.position.set(x, 0, z); b.rotation.y = rotY;
        addBoxCol(x, z, w / 2 + 0.1, d / 2 + 0.1, rotY);
        return b;
      }
      // (the three dressing houses that used to arc along the bottom of
      // town were cut — non-functional set dressing in the grass)

      // ---- three branded shops you can actually walk into ----
      function shopFront(x, z, brand) {
        const cfg = {
          seeds: { wall: PLASTER_SAGE, roof: roofTone(0x4da34a), sign: "ROSIE'S SEEDS", fg: "#1d5a2a", bg: "#eaf6d8" },
          market: { wall: PLASTER_CREAM, roof: roofTone(0xd8842f), sign: "BERRY MARKET", fg: "#7a3a10", bg: "#ffedc8" },
          tools: { wall: PLASTER_LAV, roof: roofTone(0x6a5a9a), sign: "TOOLWORKS", fg: "#2f2a4a", bg: "#e8e2f6" },
        }[brand];
        worldGroup.add(makeBuilding(x, z, 5, 4.2, 2.7, cfg.wall, cfg.roof));
        const plate = makeTextPlate(cfg.sign, { w: 3.1, h: 0.68, bg: cfg.bg, fg: cfg.fg });
        plate.position.set(x, 2.4, z + 2.28);
        worldGroup.add(plate);
        const mat = new THREE.Mesh(new THREE.BoxGeometry(1.5, 0.05, 0.8), flat(cfg.roof, { roughness: 1 }));
        mat.position.set(x, 0.03, z + 2.5);
        worldGroup.add(mat);
        if (brand === "seeds") {
          [[x - 1.8, z + 2.5], [x + 1.9, z + 2.6]].forEach(([px, pz]) => {
            const pot = new THREE.Mesh(new THREE.CylinderGeometry(0.24, 0.18, 0.32, 7), flat(new THREE.Color(PAL.roof).offsetHSL(-0.015, 0.08, -0.06)));
            pot.position.set(px, 0.16, pz);
            const bushy = new THREE.Mesh(new THREE.IcosahedronGeometry(0.26, 0), flat(PAL.leafMid));
            bushy.position.set(px, 0.48, pz);
            worldGroup.add(pot, bushy);
          });
        } else if (brand === "market") {
          [[x - 1.9, z + 2.6, 0xe8384f], [x + 1.9, z + 2.7, 0x4f6de8]].forEach(([px, pz, c]) => {
            const crate = new THREE.Mesh(new THREE.BoxGeometry(0.72, 0.4, 0.52), flat(new THREE.Color(PAL.bark).offsetHSL(0.006, 0, 0.06)));
            crate.position.set(px, 0.2, pz); crate.castShadow = true;
            worldGroup.add(crate);
            for (let i = 0; i < 4; i++) {
              const fr = new THREE.Mesh(new THREE.SphereGeometry(0.09, 7, 6), smooth(c, { roughness: 0.3 }));
              fr.position.set(px - 0.18 + (i % 2) * 0.36, 0.47, pz - 0.1 + Math.floor(i / 2) * 0.2);
              worldGroup.add(fr);
            }
          });
        } else {
          const anv = new THREE.Mesh(new THREE.BoxGeometry(0.55, 0.3, 0.3), flat(0x5a5a66));
          anv.position.set(x + 1.9, 0.44, z + 2.6);
          const anvB = new THREE.Mesh(new THREE.BoxGeometry(0.35, 0.3, 0.35), flat(0x4a4a55));
          anvB.position.set(x + 1.9, 0.15, z + 2.6);
          worldGroup.add(anv, anvB);
        }
      }
      // the three main shops line the TOP (north) of the square, fronts facing
      // south — the player sees them the moment they walk in from the west road
      shopFront(-8.2, -8, "market");
      shopFront(0, -8, "seeds");
      shopFront(8.2, -8, "tools");

      // AAA floating verbs over each storefront: glow bed + deep outline +
      // vertical gradient face on a high-res canvas sprite, with an additive
      // halo behind. They bob and pulse in the frame loop and never expire.
      function makeFloatWord(text, x, z, tone) {
        const cv = document.createElement("canvas");
        cv.width = 512; cv.height = 192;
        const c = cv.getContext("2d");
        c.textAlign = "center"; c.textBaseline = "middle";
        c.font = "900 112px 'Baloo 2', 'Trebuchet MS', sans-serif";
        c.shadowColor = tone.glow; c.shadowBlur = 44;
        c.fillStyle = tone.glow;
        c.fillText(text, 256, 100); c.fillText(text, 256, 100);
        c.shadowBlur = 0;
        c.lineWidth = 16; c.lineJoin = "round"; c.strokeStyle = tone.outline;
        c.strokeText(text, 256, 100);
        const grad = c.createLinearGradient(0, 44, 0, 156);
        grad.addColorStop(0, "#fff8e2"); grad.addColorStop(0.38, tone.core); grad.addColorStop(1, tone.deep);
        c.fillStyle = grad;
        c.fillText(text, 256, 100);
        const tex = new THREE.CanvasTexture(cv);
        const word = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, transparent: true, depthWrite: false }));
        word.scale.set(3.4, 1.28, 1);
        const halo = new THREE.Sprite(new THREE.SpriteMaterial({ map: glowTex, color: new THREE.Color(tone.glow), transparent: true, opacity: 0.32, depthWrite: false, blending: THREE.AdditiveBlending }));
        halo.scale.set(5.4, 2.7, 1);
        const g = new THREE.Group();
        g.add(halo, word);
        g.position.set(x, 5.05, z);
        g.userData = { baseY: 5.05, ph: Math.random() * 6.28, halo };
        worldGroup.add(g);
        shopWords.push(g);
      }
      makeFloatWord("SELL",  -8.2, -8, { core: "#ffd156", deep: "#d8842f", glow: "#ffd76a", outline: "#4a2c10" });
      makeFloatWord("BUY",    0,   -8, { core: "#8ce06a", deep: "#3f8f3f", glow: "#8dfc90", outline: "#17421d" });
      makeFloatWord("BUILD",  8.2, -8, { core: "#b8a8f8", deep: "#6a5a9a", glow: "#b0a0ff", outline: "#2a2348" });

      // ---- street life on the plaza ----
      makeVillager(2.6, -2.6, -2.3, { shirt: 0x5a86c9 });
      makeVillager(3.5, -3.3, 0.9, { shirt: 0xd06a8a, hair: 0x8a5f2e });
      makeVillager(-3.9, -4.4, 0.5, { shirt: 0xe0a03a, scale: 0.72 });
      makeVillager(-11.5, 0.8, 1.7, { shirt: 0x8a5f9a, hat: "hood", hood: 0x6a4a8a });
      makeVillager(0, -1.4, 0, { shirt: 0x6ab8a0, hair: 0x4a3a2a, scale: 0.82, solid: false,
        walk: { a: [-7, -1.4], b: [7, -1.4], speed: 0.24 } });

      const fBase = new THREE.Mesh(new THREE.CylinderGeometry(1.8, 2, 0.5, 9), flat(new THREE.Color(PAL.stone).offsetHSL(0, 0, 0.06)));
      fBase.position.set(0, 0.25, 5); fBase.castShadow = true;
      const fWater = new THREE.Mesh(new THREE.CylinderGeometry(1.5, 1.5, 0.2, 9),
        smooth(PAL.waterSurf, { roughness: 0.22, emissive: PAL.waterDeep, emissiveIntensity: 0.25 }));
      fWater.position.set(0, 0.5, 5);
      const foam = new THREE.Mesh(new THREE.TorusGeometry(0.7, 0.07, 5, 14),
        smooth(0xdff4ff, { emissive: 0xbfe8ff, emissiveIntensity: 0.4 }));
      foam.rotation.x = -Math.PI / 2; foam.position.set(0, 0.62, 5);
      const fSpire = new THREE.Mesh(new THREE.ConeGeometry(0.3, 1.1, 6), flat(new THREE.Color(PAL.stone).offsetHSL(0, 0, 0.06)));
      fSpire.position.set(0, 1.05, 5);
      worldGroup.add(fBase, fWater, foam, fSpire);
      addCircleCol(0, 5, 2.2);
      glowNodes.push(foam);

      // ---- living fountain: droplet spray, jet core, rippling surface, splash rings ----
      const DROPS = 110;
      const dropPos = new Float32Array(DROPS * 3);
      const dropData = [];
      for (let di = 0; di < DROPS; di++)
        dropData.push({ t: Math.random() * 0.7, life: 0.55 + Math.random() * 0.25, vx: 0, vy: 2.6, vz: 0 });
      const dropGeo = new THREE.BufferGeometry();
      dropGeo.setAttribute("position", new THREE.BufferAttribute(dropPos, 3));
      const drops = new THREE.Points(dropGeo, new THREE.PointsMaterial({
        color: SRGB(0xcfeeff), size: 0.085, transparent: true, opacity: 0.85,
        depthWrite: false, blending: THREE.AdditiveBlending, sizeAttenuation: true,
      }));
      worldGroup.add(drops);
      const jet = new THREE.Mesh(new THREE.CylinderGeometry(0.05, 0.12, 0.7, 7),
        smooth(0xd8f2ff, { transparent: true, opacity: 0.7, roughness: 0.1, emissive: 0x9fd8f0, emissiveIntensity: 0.5 }));
      jet.position.set(0, 1.5, 5);
      worldGroup.add(jet);
      const ripGeo = new THREE.CircleGeometry(1.46, 28);
      ripGeo.rotateX(-Math.PI / 2);
      const ripBase = [];
      const rpAttr = ripGeo.attributes.position;
      for (let ri = 0; ri < rpAttr.count; ri++) ripBase.push(Math.hypot(rpAttr.getX(ri), rpAttr.getZ(ri)));
      const ripple = new THREE.Mesh(ripGeo, smooth(new THREE.Color(PAL.waterSurf).offsetHSL(0, 0, 0.1), { transparent: true, opacity: 0.75, roughness: 0.15, emissive: new THREE.Color(PAL.waterDeep).offsetHSL(0, 0, 0.06), emissiveIntensity: 0.3 }));
      ripple.position.set(0, 0.615, 5);
      worldGroup.add(ripple);
      const splashRings = [];
      for (let ri = 0; ri < 4; ri++) {
        const rg = new THREE.Mesh(new THREE.TorusGeometry(0.3, 0.025, 5, 18),
          smooth(0xeaf8ff, { transparent: true, opacity: 0.5, emissive: 0xbfe8ff, emissiveIntensity: 0.4 }));
        rg.rotation.x = -Math.PI / 2;
        rg.userData = { ph: ri / 4, lx: 0, lz: 0, br: 1, prev: 1 };
        worldGroup.add(rg); splashRings.push(rg);
      }
      fountainFx = { drops, dropData, jet, ripple, ripBase, rings: splashRings, cx: 0, cz: 5 };

      [[-15, -12, 1.2], [14, -13, 1.3], [-16, 10, 1.1], [15, 9, 1.2], [15.5, 16, 1.0], [-17, 13.5, 1.3]]
        .forEach(([x, z, s]) => worldGroup.add(makeTree(x, z, s)));
      [[12.8, -5, 0.6, false], [-16.5, -5.5, 0.7, false], [13, 3, 0.55, true]]
        .forEach(([x, z, s, d]) => worldGroup.add(makeRock(x, z, s, d)));
      const townAvoid = (x, z) =>
        (x > -15 && x < 10.5 && z > -11.5 && z < 12.9) ||
        (Math.abs(z) < 1.7 && x > -21 && x < 17);
      for (let ci = 0; ci < 9; ci++) {
        const cx = (Math.random() - 0.5) * 40, cz = (Math.random() - 0.5) * 34;
        if (townAvoid(cx, cz)) continue;
        const k = 2 + Math.floor(Math.random() * 3);
        for (let fi = 0; fi < k; fi++) {
          const fa = Math.random() * Math.PI * 2, fr = 0.35 + Math.random() * 0.85;
          const fx = cx + Math.cos(fa) * fr, fz = cz + Math.sin(fa) * fr;
          if (!townAvoid(fx, fz)) worldGroup.add(mixFlower(fx, fz));
        }
      }
      [[10, 7.5, 0.9], [-10.5, 9.5, 0.8], [12, -4, 0.9], [-14, -6, 1]]
        .forEach(([x, z, bs]) => worldGroup.add(makeBush(x, z, bs)));
      addSprouts(300, 56, townAvoid);

      addGrass(4400, 60, townAvoid);
      addGroundPatches(50, 60, townAvoid);
      addWildflowers(190, 58, townAvoid);
      addForestRing(28, 34, 52, [[-20, 0]]);
      addMountains([[-28, -50, 16, 19, true], [20, -54, 20, 24, true], [48, -30, 13, 14, false], [-50, 18, 15, 16, true]]);
      addClouds(5);
      addButterflies(4, 24);

      // west world edge: the HOME exit is the only way out — wall + funnel
      // lips mirror the home-meadow treatment so nobody walks around it
      addBoxCol(-21.2, 0, 0.2, 30);           // back wall behind the exit
      addBoxCol(-19.6, 2.0, 1.8, 0.15);       // funnel, north lip
      addBoxCol(-19.6, -2.0, 1.8, 0.15);      // funnel, south lip
      exits = [
        { x: -20, z: 0, r: 2.2, to: "HOME", spawn: [21, 3] },
        // spawn well inside the shop (not at the doorway) so turning around
        // doesn't walk the player out through the door gap into the void
        { x: -8.2, z: -5.05, r: 1.3, to: "SHOP_MARKET", spawn: [0, 2] },
        { x: 0, z: -5.05, r: 1.3, to: "SHOP_SEEDS", spawn: [0, 2] },
        { x: 8.2, z: -5.05, r: 1.3, to: "SHOP_TOOLS", spawn: [0, 2] },
      ];
      hotspots = [];

      // —— Glowlands: Meadow Town dressing (library, chapel, East Gate,
      //    gloom stain, public plots) + prologue trigger zones.
      buildGlowMeadow();
    }

    // -------- SHOP INTERIORS: walk in, browse, talk at the counter --------
    function buildShopInterior(name) {
      clearWorld();
      const kind = name === "SHOP_SEEDS" ? "seeds" : name === "SHOP_MARKET" ? "market" : "tools";
      const CFG = {
        // sage-cream plaster walls, warm plank floor, desaturated-leaf trim — no pure green
        seeds: { floor: new THREE.Color(PAL.pathStone).offsetHSL(0.004, 0.02, -0.055), wall: new THREE.Color(PAL.plaster).offsetHSL(0.05, -0.12, -0.05), trim: new THREE.Color(PAL.leafMid).offsetHSL(0, -0.18, 0.05), keeper: { shirt: 0x4da34a, hat: "straw" }, sign: "ROSIE'S RARE SEEDS", fg: "#1d5a2a", bg: "#eaf6d8", lamp: 0xd8ffc0, back: [0, -3.3] },
        market: { floor: 0x9a8a72, wall: 0xf2e2c2, trim: 0xd8842f, keeper: { shirt: 0xc9963c, hair: 0x2a1a0e }, sign: "THE BERRY MARKET", fg: "#7a3a10", bg: "#ffedc8", lamp: 0xffd9a0, back: [-8.2, -3.3] },
        tools: { floor: 0x6a6472, wall: 0xcfcadd, trim: 0x6a5a9a, keeper: { shirt: 0x8a6fd0, hair: 0x2a1a0e, beard: true }, sign: "GRIMBLE'S TOOLWORKS", fg: "#2f2a4a", bg: "#e8e2f6", lamp: 0xffc890, back: [8.2, -3.3] },
      }[kind];
      setAtmosphere(ATMO_NIGHT.top, ATMO_NIGHT.mid, ATMO_NIGHT.bot, ATMO_NIGHT.fog, ATMO_NIGHT.sun, 0.55, ATMO_NIGHT.hemiSky, ATMO_NIGHT.hemiGnd, 8, 42, 0.52);
      terrainY = () => 0;
      const floor = new THREE.Mesh(new THREE.BoxGeometry(15, 0.2, 11), flat(CFG.floor, { roughness: 0.95 }));
      floor.position.set(0, -0.1, -0.5); floor.receiveShadow = true;
      worldGroup.add(floor);
      const wallMat = flat(CFG.wall, { roughness: 0.95 });
      const back = new THREE.Mesh(new THREE.BoxGeometry(15, 3.4, 0.3), wallMat);
      back.position.set(0, 1.7, -6); back.receiveShadow = true;
      const left = new THREE.Mesh(new THREE.BoxGeometry(0.3, 3.4, 11), wallMat);
      left.position.set(-7.5, 1.7, -0.5);
      const right = left.clone(); right.position.x = 7.5;
      worldGroup.add(back, left, right);
      addBoxCol(0, -6, 7.6, 0.35); addBoxCol(-7.5, -0.5, 0.35, 5.7); addBoxCol(7.5, -0.5, 0.35, 5.7);
      const lipL = new THREE.Mesh(new THREE.BoxGeometry(5.6, 1.1, 0.3), wallMat);
      lipL.position.set(-4.6, 0.55, 5);
      const lipR = lipL.clone(); lipR.position.x = 4.6;
      worldGroup.add(lipL, lipR);
      addBoxCol(-4.6, 5, 2.8, 0.3); addBoxCol(4.6, 5, 2.8, 0.3);
      const trimB = new THREE.Mesh(new THREE.BoxGeometry(15, 0.25, 0.36), flat(CFG.trim));
      trimB.position.set(0, 0.12, -5.96); worldGroup.add(trimB);
      const plate = makeTextPlate(CFG.sign, { w: 4.6, h: 0.9, bg: CFG.bg, fg: CFG.fg });
      plate.position.set(0, 2.55, -5.78);
      worldGroup.add(plate);
      const counter = new THREE.Mesh(new THREE.BoxGeometry(4.6, 1.05, 1.1), flat(new THREE.Color(PAL.bark).offsetHSL(0.006, -0.05, 0.12)));
      counter.position.set(0, 0.52, -2.4); counter.castShadow = true; counter.receiveShadow = true;
      const counterTop = new THREE.Mesh(new THREE.BoxGeometry(4.9, 0.12, 1.3), flat(CFG.trim));
      counterTop.position.set(0, 1.12, -2.4);
      worldGroup.add(counter, counterTop);
      addBoxCol(0, -2.4, 2.45, 0.75);
      makeVillager(0, -3.6, 0, { ...CFG.keeper, solid: false });
      counterKeeper = { x: 0, z: -3.6, kind };
      const mkLamp = (lx, lz) => {
        const bulb = new THREE.Mesh(new THREE.SphereGeometry(0.12, 8, 6),
          new THREE.MeshStandardMaterial({ color: SRGB(0xfff0b0), emissive: SRGB(0xffdf80), emissiveIntensity: 1.2 }));
        bulb.position.set(lx, 2.6, lz);
        const pl = new THREE.PointLight(SRGB(CFG.lamp), 0.9, 11);
        pl.position.set(lx, 2.45, lz);
        worldGroup.add(bulb, pl);
        glowNodes.push(bulb);
      };
      mkLamp(-3.5, -2.2); mkLamp(3.5, -2.2);
      const rug = new THREE.Mesh(new THREE.CircleGeometry(1.15, 10), flat(CFG.trim, { roughness: 1 }));
      rug.rotation.x = -Math.PI / 2; rug.position.set(0, 0.02, 4);
      worldGroup.add(rug);

      if (kind === "seeds") {
        const shelf = new THREE.Mesh(new THREE.BoxGeometry(6, 0.14, 0.8), flat(new THREE.Color(PAL.bark).offsetHSL(0, 0.02, 0.03)));
        shelf.position.set(-3.4, 1.5, -5.4); worldGroup.add(shelf);
        const sackCols = [0xe8384f, 0x4f6de8, 0xffb020, 0x7dfcd0, 0x9ab87a, 0xd06a8a];
        for (let i = 0; i < 6; i++) {
          const sack = new THREE.Mesh(new THREE.IcosahedronGeometry(0.22, 0), flat(0xd8c49a));
          sack.position.set(-5.9 + i, 1.78, -5.4);
          sack.scale.set(1, 1.2, 1);
          const tie = new THREE.Mesh(new THREE.SphereGeometry(0.07, 6, 5), flat(sackCols[i]));
          tie.position.set(-5.9 + i, 2.04, -5.4);
          worldGroup.add(sack, tie);
        }
        [[-6.4, 0.6], [6.4, 0.2], [6.2, -3.9]].forEach(([px, pz]) => {
          const pot = new THREE.Mesh(new THREE.CylinderGeometry(0.3, 0.22, 0.42, 7), flat(new THREE.Color(PAL.roof).offsetHSL(-0.015, 0.08, -0.06)));
          pot.position.set(px, 0.21, pz);
          const pl2 = new THREE.Mesh(new THREE.IcosahedronGeometry(0.32, 0), flat(PAL.leafMid));
          pl2.position.set(px, 0.62, pz);
          worldGroup.add(pot, pl2);
          addCircleCol(px, pz, 0.42);
        });
        for (let i = 0; i < 4; i++) {
          const herb = new THREE.Mesh(new THREE.ConeGeometry(0.12, 0.4, 5), flat(new THREE.Color(PAL.leafMid).offsetHSL(0, -0.06, -0.03)));
          herb.rotation.x = Math.PI;
          herb.position.set(2 + i * 1.1, 2.62, -5.5);
          worldGroup.add(herb);
        }
        makeVillager(-4.2, 0.9, 2.4, { shirt: 0x8a5f9a, hat: "hood", hood: 0x6a4a8a });
      } else if (kind === "market") {
        [[-6.2, -4.6, 0xe8384f], [-6.2, -3.1, 0x4f6de8], [-6.2, -1.6, 0xffb020], [6.2, -4.6, 0xe8384f], [6.2, -3.1, 0xffb020]].forEach(([px, pz, c]) => {
          const crate = new THREE.Mesh(new THREE.BoxGeometry(1.0, 0.5, 0.8), flat(0x9a7245));
          crate.position.set(px, 0.25, pz); crate.castShadow = true;
          worldGroup.add(crate);
          addBoxCol(px, pz, 0.55, 0.45);
          for (let i = 0; i < 6; i++) {
            const fr = new THREE.Mesh(new THREE.SphereGeometry(0.11, 8, 6), smooth(c, { roughness: 0.3 }));
            fr.position.set(px - 0.3 + (i % 3) * 0.3, 0.58, pz - 0.15 + Math.floor(i / 3) * 0.3);
            worldGroup.add(fr);
          }
        });
        const beam = new THREE.Mesh(new THREE.BoxGeometry(1.2, 0.07, 0.07), flat(0x8a6238));
        beam.position.set(-2.9, 2.4, -3.4);
        const pan = new THREE.Mesh(new THREE.CylinderGeometry(0.24, 0.24, 0.06, 8), flat(0xc9963c));
        pan.position.set(-2.9, 1.9, -3.4);
        worldGroup.add(beam, pan);
        makeVillager(4.6, -0.5, 2.7, { shirt: 0x5a86c9, holding: 0xe8384f });
      } else {
        for (let i = 0; i < 4; i++) {
          const handle = new THREE.Mesh(new THREE.CylinderGeometry(0.05, 0.05, 0.9, 5), flat(0x8a6238));
          handle.position.set(-5.4 + i * 1.2, 2.0, -5.62);
          const head = new THREE.Mesh(new THREE.BoxGeometry(0.34, 0.16, 0.16), flat(0x5a5a66));
          head.position.set(-5.4 + i * 1.2, 2.46, -5.62);
          worldGroup.add(handle, head);
        }
        const forge = new THREE.Mesh(new THREE.BoxGeometry(1.6, 0.9, 1.2), flat(0x4a4a55));
        forge.position.set(5.6, 0.45, -4.6); forge.castShadow = true;
        const coals = new THREE.Mesh(new THREE.BoxGeometry(1.2, 0.16, 0.8),
          new THREE.MeshStandardMaterial({ color: SRGB(0xff7a30), emissive: SRGB(0xff5a10), emissiveIntensity: 1.4 }));
        coals.position.set(5.6, 0.95, -4.6);
        worldGroup.add(forge, coals);
        addBoxCol(5.6, -4.6, 0.85, 0.65);
        glowNodes.push(coals);
        const fl2 = new THREE.PointLight(SRGB(0xff8a3a), 1.0, 8);
        fl2.position.set(5.6, 1.4, -4.6);
        worldGroup.add(fl2);
        const anv = new THREE.Mesh(new THREE.BoxGeometry(0.8, 0.35, 0.4), flat(0x5a5a66));
        anv.position.set(-5.4, 0.64, -1.6);
        const anvB = new THREE.Mesh(new THREE.BoxGeometry(0.5, 0.45, 0.5), flat(0x3f3f4a));
        anvB.position.set(-5.4, 0.22, -1.6);
        worldGroup.add(anv, anvB);
        addBoxCol(-5.4, -1.6, 0.5, 0.35);
        const barrel = new THREE.Mesh(new THREE.CylinderGeometry(0.4, 0.34, 0.8, 8), flat(0x8a6238));
        barrel.position.set(6.3, 0.4, 0.8);
        worldGroup.add(barrel);
        addCircleCol(6.3, 0.8, 0.5);
        makeVillager(-3.6, -0.3, 2.2, { shirt: 0xc9963c, scale: 0.85 });
      }

      exits = [{ x: 0, z: 5.5, r: 1.6, to: "TOWN", spawn: CFG.back }];
      addBoxCol(0, 6.9, 2.4, 0.3);
      hotspots = [{ x: 0, z: -2.4, r: 2.7, type: "counter", kind, label: kind === "market" ? "Talk to Marlo" : kind === "seeds" ? "Talk to Rosie" : "Talk to Grimble" }];
    }

    // -------- GRACE COMMUNITY GARDEN (golden hour, 324 sacred plots) --------
    function buildChurch() {
      clearWorld();
      setAtmosphere(ATMO_SUNSET.top, ATMO_SUNSET.mid, ATMO_SUNSET.bot, ATMO_SUNSET.fog, ATMO_SUNSET.sun, 1.5, ATMO_SUNSET.hemiSky, ATMO_SUNSET.hemiGnd, 34, 92, 0.6);

      terrainY = makeTerrain(
        [{ x: -22, z: -17, r: 8, h: 1.6 }, { x: 22, z: -17, r: 8, h: 1.5 }, { x: -24, z: 15, r: 8, h: 1.5 },
         { x: 24, z: 16, r: 8, h: 1.6 }, { x: 0, z: 21, r: 7, h: 1.2 }],
        [{ c: 1, x: 0, z: 0, r: 7, f: 3.5 },
         { x1: 5, z1: 1.2, x2: 18, z2: 12.8, f: 3 }, { x1: -18, z1: 1.2, x2: -5, z2: 12.8, f: 3 },
         { x1: 5, z1: -12.8, x2: 18, z2: -1.2, f: 3 }, { x1: -18, z1: -12.8, x2: -5, z2: -1.2, f: 3 },
         { x1: -3.8, z1: -26.5, x2: 3.8, z2: -17.6, f: 3 },
         { c: 1, x: 3.3, z: -16.6, r: 1.8, f: 2 }, { c: 1, x: 9, z: -19, r: 3, f: 2.5 },
         { x1: -24, z1: -1.7, x2: 32, z2: 1.7, f: 3 }, { x1: -1.5, z1: -18, x2: 1.5, z2: 15, f: 3 }]
      );
      // promenade, cross paths, and plaza rings — registered before the ground so it carries the worn ribbon
      const ringPts = (r, n) => Array.from({ length: n + 1 }, (_, i) => [Math.cos((i / n) * Math.PI * 2) * r, Math.sin((i / n) * Math.PI * 2) * r]);
      const churchRoutes = [
        { pts: [[30, 0], [6, 0]], w: 2.0 },
        { pts: [[-6, 0], [-22, 0]], w: 1.7 },
        { pts: [[0, 6], [0, 14]], w: 1.6 },
        { pts: [[0, -6], [0, -17]], w: 1.6 },
        { pts: ringPts(4.4, 14), w: 1.3 },
        { pts: ringPts(2.4, 10), w: 1.1 },
      ];
      setPathRoutes(churchRoutes);
      worldGroup.add(makeGround(86, PAL.grassBase));
      churchRoutes.forEach((rt) => addFlagstonePath(rt.pts, rt.w));

      const sunDisc = new THREE.Mesh(new THREE.SphereGeometry(4.6, 12, 10),
        new THREE.MeshBasicMaterial({ color: 0xffd9a0 }));
      sunDisc.position.set(-62, 8, -40);
      worldGroup.add(sunDisc);

      // Chapel at the north end, doors opening onto the plaza
      const chapel = new THREE.Group();
      const cProf = new THREE.Shape();
      cProf.moveTo(-2.5, 0); cProf.lineTo(2.5, 0); cProf.lineTo(2.5, 3.2);
      cProf.lineTo(0, 4.7); cProf.lineTo(-2.5, 3.2); cProf.lineTo(-2.5, 0);
      const cGeo = new THREE.ExtrudeGeometry(cProf, { depth: 7, bevelEnabled: false });
      cGeo.translate(0, 0, -3.5);
      const nave = new THREE.Mesh(cGeo, flat(0xf5ecd8));
      nave.castShadow = true; nave.receiveShadow = true;
      const roof = new THREE.Group();
      const cAng = Math.atan2(1.5, 2.8);
      const cSlope = Math.hypot(2.8, 1.5) + 0.15;
      [1, -1].forEach((sign) => {
        const slab = new THREE.Mesh(new THREE.BoxGeometry(cSlope, 0.14, 7.6), flat(0x5a7a9a, { roughness: 0.75 }));
        slab.rotation.z = -sign * cAng;
        slab.position.set(sign * 1.4, 3.99, 0);
        slab.castShadow = true;
        roof.add(slab);
      });
      const cCap = new THREE.Mesh(new THREE.BoxGeometry(0.32, 0.14, 7.7), flat(0x4a6a8a));
      cCap.position.y = 4.76; cCap.castShadow = true;
      roof.add(cCap);
      const steeple = new THREE.Mesh(new THREE.BoxGeometry(1.4, 2.4, 1.4), flat(0xf5ecd8));
      steeple.position.set(0, 4.6, 2.2); steeple.castShadow = true;
      const spire = new THREE.Mesh(new THREE.ConeGeometry(1, 1.7, 4), flat(0x5a7a9a));
      spire.position.set(0, 6.7, 2.2); spire.rotation.y = Math.PI / 4;
      const crossV = new THREE.Mesh(new THREE.BoxGeometry(0.12, 0.9, 0.12), smooth(0xf5d98a, { emissive: 0xf5d98a, emissiveIntensity: 0.6 }));
      crossV.position.set(0, 7.95, 2.2);
      const crossH = new THREE.Mesh(new THREE.BoxGeometry(0.55, 0.12, 0.12), crossV.material);
      crossH.position.set(0, 8.05, 2.2);
      const chDoor = new THREE.Mesh(new THREE.BoxGeometry(1.1, 1.8, 0.1), flat(0x7a5233));
      chDoor.position.set(0, 0.9, 3.55);
      const rose = new THREE.Mesh(new THREE.CylinderGeometry(0.5, 0.5, 0.1, 10),
        smooth(0x8ab8ff, { emissive: 0x6a9aff, emissiveIntensity: 0.6 }));
      rose.rotation.x = Math.PI / 2; rose.position.set(0, 2.4, 3.56);
      chapel.add(nave, roof, steeple, spire, crossV, crossH, chDoor, rose);
      chapel.position.set(0, 0, -22);
      worldGroup.add(chapel);
      addBoxCol(0, -22, 2.65, 3.65, 0);

      // painted name sign by the chapel path
      const signCv = document.createElement("canvas");
      signCv.width = 512; signCv.height = 200;
      const sctx = signCv.getContext("2d");
      sctx.fillStyle = "#e9d6a6"; sctx.fillRect(0, 0, 512, 200);
      sctx.strokeStyle = "#6b4a2f"; sctx.lineWidth = 14; sctx.strokeRect(10, 10, 492, 180);
      sctx.fillStyle = "#3a2812"; sctx.textAlign = "center"; sctx.textBaseline = "middle";
      // Sign shows the active youth group's name, wrapped to two lines.
      const gName = (G.activeGarden?.name || window.YGTEEV?.profile?.groupName || "Community Garden").trim();
      let line1 = gName, line2 = "";
      if (gName.length > 14) {
        const words = gName.split(/\s+/);
        let a = "", b = "";
        for (const w of words) {
          if (!b && (a + " " + w).trim().length <= 16) a = (a + " " + w).trim();
          else b = (b + " " + w).trim();
        }
        line1 = a || gName.slice(0, 16); line2 = b;
      }
      const fs1 = line1.length > 12 ? 40 : 52;
      const fs2 = line2.length > 12 ? 40 : 52;
      if (line2) {
        sctx.font = `bold ${fs1}px Georgia`; sctx.fillText(line1, 256, 72);
        sctx.font = `bold ${fs2}px Georgia`; sctx.fillText(line2, 256, 134);
      } else {
        sctx.font = `bold ${fs1}px Georgia`; sctx.fillText(line1, 256, 100);
      }
      const signTex = new THREE.CanvasTexture(signCv);
      const signG = new THREE.Group();
      [-1.15, 1.15].forEach((px) => {
        const post = new THREE.Mesh(new THREE.CylinderGeometry(0.08, 0.1, 1.6, 6), flat(0x6b4a2f));
        post.position.set(px, 0.8, 0); post.castShadow = true;
        signG.add(post);
      });
      const signBack = new THREE.Mesh(new THREE.BoxGeometry(2.8, 1.15, 0.1), flat(0x6b4a2f));
      signBack.position.set(0, 1.55, 0); signBack.castShadow = true;
      const signFace = new THREE.Mesh(new THREE.PlaneGeometry(2.6, 1.0), new THREE.MeshBasicMaterial({ map: signTex }));
      signFace.position.set(0, 1.55, 0.06);
      signG.add(signBack, signFace);
      signG.position.set(3.3, 0, -16.6);
      signG.rotation.y = 0.35;
      worldGroup.add(signG);
      addBoxCol(3.3, -16.6, 1.45, 0.2, 0.35);

      // stone cross monument at the plaza heart
      const monBase = new THREE.Mesh(new THREE.CylinderGeometry(1.0, 1.25, 0.5, 8), flat(0xaeb4bd));
      monBase.position.y = 0.25; monBase.castShadow = true;
      const monCol = new THREE.Mesh(new THREE.BoxGeometry(0.34, 1.6, 0.34), flat(0x9aa0ab));
      monCol.position.y = 1.3; monCol.castShadow = true;
      const monV = new THREE.Mesh(new THREE.BoxGeometry(0.2, 1.1, 0.2), smooth(0xf5d98a, { emissive: 0xf0c860, emissiveIntensity: 0.7 }));
      monV.position.y = 2.6;
      const monH = new THREE.Mesh(new THREE.BoxGeometry(0.72, 0.2, 0.2), monV.material);
      monH.position.y = 2.75;
      worldGroup.add(monBase, monCol, monV, monH);
      glowNodes.push(monV);
      const monLight = new THREE.PointLight(SRGB(0xffd9a0), 0.9, 14);
      monLight.position.set(0, 3, 0);
      worldGroup.add(monLight);
      addCircleCol(0, 0, 1.15);

      // floating countdown above the cross
      timerSprite = new THREE.Sprite(new THREE.SpriteMaterial({ map: timerTex, transparent: true, depthWrite: false }));
      timerSprite.scale.set(3.4, 1.04, 1);
      // the stack sits low (just over the cross) — the portrait camera crops
      // anything much above ~4.5 world-units at typical distances
      timerSprite.position.set(0, 3.55, 0);
      worldGroup.add(timerSprite);
      // trophy tally floats above the countdown
      winsSprite = new THREE.Sprite(new THREE.SpriteMaterial({ map: winsTex, transparent: true, depthWrite: false }));
      winsSprite.scale.set(3.6, 1.2, 1);
      winsSprite.position.set(0, 4.85, 0);
      worldGroup.add(winsSprite);
      drawWins(G.pulse && typeof G.pulse.league_wins === "number" ? G.pulse.league_wins : 0);
      lastWinsDrawn = G.pulse && typeof G.pulse.league_wins === "number" ? G.pulse.league_wins : 0;

      // 324 small sacred plots in four quadrant fields (2 instanced draw calls)
      const plotPositions = [];
      const Q = 9, SP = 1.15;
      [[-11.5, 7], [11.5, 7], [-11.5, -7], [11.5, -7]].forEach(([cx, cz]) => {
        for (let gx = 0; gx < Q; gx++) for (let gz = 0; gz < Q; gz++) {
          plotPositions.push([cx + (gx - (Q - 1) / 2) * SP, cz + (gz - (Q - 1) / 2) * SP]);
        }
      });
      // tilled dirt beds under each quadrant, framed in wooden edging
      [[-11.5, 7], [11.5, 7], [-11.5, -7], [11.5, -7]].forEach(([cx, cz]) => {
        const bed = new THREE.Mesh(new THREE.BoxGeometry(11.2, 0.08, 11.2),
          flat(new THREE.Color(0x5f4530).offsetHSL(0, 0, (Math.random() - 0.5) * 0.04), { roughness: 1 }));
        bed.position.set(cx, 0.04, cz);
        bed.receiveShadow = true;
        worldGroup.add(bed);
        [[0, -5.75, 11.7, 0.16], [0, 5.75, 11.7, 0.16], [-5.75, 0, 0.16, 11.7], [5.75, 0, 0.16, 11.7]].forEach(([ox, oz, w, d]) => {
          const board = new THREE.Mesh(new THREE.BoxGeometry(w, 0.26, d), flat(0x8a6238));
          board.position.set(cx + ox, 0.13, cz + oz);
          board.castShadow = true; board.receiveShadow = true;
          worldGroup.add(board);
        });
      });
      addChurchPlotField(plotPositions);

      // glow-stones marking each field corner
      [[-11.5, 7], [11.5, 7], [-11.5, -7], [11.5, -7]].forEach(([cx, cz]) => {
        [[-5.4, -5.4], [5.4, -5.4], [-5.4, 5.4], [5.4, 5.4]].forEach(([ox, oz]) => {
          const gs = new THREE.Mesh(new THREE.IcosahedronGeometry(0.28, 0),
            new THREE.MeshStandardMaterial({ color: SRGB(0x9fffe0), emissive: SRGB(0x63ffc9), emissiveIntensity: 0.8, flatShading: true }));
          gs.position.set(cx + ox, 0.24, cz + oz);
          worldGroup.add(gs); glowNodes.push(gs);
        });
      });
      addSparkles(0, 0, 34, 150);

      // Old Gardener Eli, keeper of the sacred plots
      gardener = makeVillager(-3.4, 3.0, 2.4, { shirt: 0x7a8a5a, hat: "straw", beard: true, cane: true, manual: true, solid: false });
      gardenerCtl = { mode: "post", t: 0, post: [-3.4, 3.0], postRot: 2.4 };

      // youth group picnic by the chapel
      const table = new THREE.Mesh(new THREE.BoxGeometry(2.4, 0.12, 1.1), flat(0xb9895a));
      table.position.set(9, 0.75, -19); table.castShadow = true;
      const tLegs = new THREE.Mesh(new THREE.BoxGeometry(2, 0.7, 0.9), flat(0x8a6238));
      tLegs.position.set(9, 0.35, -19);
      worldGroup.add(table, tLegs);
      addBoxCol(9, -19, 1.35, 0.75, 0);
      makeVillager(7.8, -20.2, Math.PI - 0.3, { shirt: 0xe86a5a, hair: 0x3a2a1a, scale: 0.9 });
      makeVillager(9.1, -20.4, Math.PI, { shirt: 0x5ab86a, hat: "hood", hood: 0x4a6fa8, scale: 0.9 });
      makeVillager(10.4, -20.1, Math.PI + 0.3, { shirt: 0xe8b84a, hair: 0x6e4a2c, scale: 0.9 });

      // string lights flanking the plaza
      [5.2, -5.2].forEach((sx) => {
        const pA = new THREE.Mesh(new THREE.CylinderGeometry(0.08, 0.1, 2.6, 5), flat(0x8a6238));
        pA.position.set(sx, 1.3, -4.4);
        const pB = pA.clone(); pB.position.z = 4.4;
        worldGroup.add(pA, pB);
        addCircleCol(sx, -4.4, 0.2); addCircleCol(sx, 4.4, 0.2);
        for (let i = 0; i < 9; i++) {
          const t = i / 8;
          const bulb = new THREE.Mesh(new THREE.SphereGeometry(0.09, 6, 6),
            new THREE.MeshStandardMaterial({ color: SRGB(0xfff0b0), emissive: SRGB(0xffdf80), emissiveIntensity: 1.2 }));
          bulb.position.set(sx, 2.5 - Math.sin(t * Math.PI) * 0.55, -4.4 + t * 8.8);
          worldGroup.add(bulb); glowNodes.push(bulb);
        }
      });
      const warm = new THREE.PointLight(SRGB(0xffd9a0), 0.85, 20);
      warm.position.set(0, 3.2, 0);
      worldGroup.add(warm);

      // lantern-lined promenade
      const mkLantern = (x, z) => {
        const g = new THREE.Group();
        const post = new THREE.Mesh(new THREE.CylinderGeometry(0.05, 0.07, 1.5, 5), flat(0x3a3a44));
        post.position.y = 0.75;
        const cage = new THREE.Mesh(new THREE.BoxGeometry(0.24, 0.3, 0.24),
          new THREE.MeshStandardMaterial({ color: SRGB(0xfff0b0), emissive: SRGB(0xffd980), emissiveIntensity: 1.1 }));
        cage.position.y = 1.62;
        const cap = new THREE.Mesh(new THREE.ConeGeometry(0.22, 0.18, 4), flat(0x3a3a44));
        cap.position.y = 1.84; cap.rotation.y = Math.PI / 4;
        g.add(post, cage, cap);
        g.position.set(x, 0, z);
        worldGroup.add(g);
        glowNodes.push(cage);
        addCircleCol(x, z, 0.16);
      };
      [[9, 1.9], [16, 1.9], [23, 1.9], [9, -1.9], [16, -1.9], [23, -1.9], [-9, 1.9], [-9, -1.9], [-16, 1.9], [-16, -1.9], [1.9, 10], [-1.9, 10], [1.9, -13], [-1.9, -13]]
        .forEach(([x, z]) => mkLantern(x, z));

      // orchard variety: cypress avenue, cherry blossoms, mixed groves
      [[19.5, 2.8], [23.5, 2.8], [27.5, 2.8], [19.5, -2.8], [23.5, -2.8], [27.5, -2.8]]
        .forEach(([x, z]) => worldGroup.add(makeCypress(x, z, 1 + Math.random() * 0.25)));
      const CHERRY_SPOTS = [[-17.8, 15.4], [-5.2, 15.7], [5.2, 15.7], [17.8, 15.4], [-17.8, -15.4], [-5.2, -15.7], [5.2, -15.7], [17.8, -15.4]];
      CHERRY_SPOTS.forEach(([x, z]) => worldGroup.add(makeCherry(x, z, 1 + Math.random() * 0.3)));
      addPetals(CHERRY_SPOTS, CHERRY_PINKS, 36, 4.4);
      [[-20, 4, 1.2], [-20, -4, 1.3], [21, 9, 1.1], [24, -8, 1.3], [-25, 10, 1.2], [-25, -9, 1.1], [10, 16, 1.2], [-10, 16, 1.1], [14, -16, 1.2], [-14, -16, 1.3], [27, 12, 1.0], [-27, 13, 1.2], [26, -13, 1.1]]
        .forEach(([x, z, sc]) => worldGroup.add(makeTree(x, z, sc)));
      [[-6.5, -13.5, 0.8, false], [6.5, 14.8, 0.9, true], [26, 5, 0.8, false], [-24, -2, 0.9, true]]
        .forEach(([x, z, sc, d]) => worldGroup.add(makeRock(x, z, sc, d)));
      const churchAvoid = (x, z) =>
        (Math.abs(z) < 1.8 && x > -23 && x < 31) ||
        (Math.abs(x) < 1.6 && z > -18 && z < 15) ||
        Math.hypot(x, z) < 5.6 ||
        (x > -4 && x < 4 && z > -26.5 && z < -17.5) ||
        Math.hypot(x - 9, z + 19) < 3.2 ||
        (Math.abs(Math.abs(x) - 11.5) < 5.5 && Math.abs(Math.abs(z) - 7) < 5.5);
      for (let ci = 0; ci < 16; ci++) {
        const cx = (Math.random() - 0.5) * 56, cz = (Math.random() - 0.5) * 44;
        if (churchAvoid(cx, cz)) continue;
        const k = 2 + Math.floor(Math.random() * 3);
        for (let fi = 0; fi < k; fi++) {
          const fa = Math.random() * Math.PI * 2, fr = 0.35 + Math.random() * 0.85;
          const fx = cx + Math.cos(fa) * fr, fz = cz + Math.sin(fa) * fr;
          if (!churchAvoid(fx, fz)) worldGroup.add(mixFlower(fx, fz));
        }
      }
      [[-19, 10.5, 1], [19, 10.5, 1], [-19, -10.5, 1], [19, -10.5, 0.9], [7, 15, 0.9], [-7, 15, 0.9], [-7, -10, 0.8], [25, 4.5, 0.9]]
        .forEach(([x, z, bs]) => worldGroup.add(makeBush(x, z, bs)));
      addSprouts(470, 74, churchAvoid);

      addGrass(7200, 78, churchAvoid);
      addGroundPatches(90, 78, churchAvoid);
      addWildflowers(340, 74, churchAvoid);
      addForestRing(38, 45, 76, [[30, 0]]);
      addMountains([[-48, -52, 18, 21, true], [16, -60, 20, 24, true], [-62, 10, 15, 16, false], [52, -34, 14, 15, true]]);
      addClouds(5);
      addButterflies(8, 34);

      // east world edge: wall + funnel lips behind the HOME exit
      addBoxCol(31.2, 0, 0.2, 34);            // back wall behind the exit
      addBoxCol(29.6, 2.0, 1.8, 0.15);        // funnel, north lip
      addBoxCol(29.6, -2.0, 1.8, 0.15);       // funnel, south lip
      exits = [{ x: 30, z: 0, r: 2.2, to: "HOME", spawn: [-21, 3], label: "Home Meadow →" }];
      hotspots = [];
    }

    // —— Glowlands map/story wiring (Phase 1 gateway slice) ——
    let glowHomeHandle = null, glowMeadowHandle = null, glowRoadHandle = null;
    // ---------------------------------------------------------------------
    // GLOWLANDS PHASE 1 KILL SWITCH
    // Phase 1 (Meadow Town prologue, Verse Satchel, lantern, Town Book, East
    // Road) is parked, not deleted: every module under src/glowlands/ stays in
    // the repo and on the `glowlands-phase1` branch / `glowlands-phase1-slice`
    // tag. Flip this to true to bring the whole slice back.
    // ---------------------------------------------------------------------
    const GLOW_ENABLED = false;
    let glowTownBook = null, glowPrologue = null, glowHudMounted = false;
    let glowTriggers = []; // proximity triggers for the current map only
    function glowWorldCtx(extra = {}) {
      return Object.assign({}, glowCtx, {
        THREE, worldGroup, terrainY, PAL, flat, smooth,
        addCircleCol, addBoxCol, glowNodes,
        world: {
          getPlayerPos: () => ({ x: playerPos.x, z: playerPos.z }),
          tp: (x, z) => { playerPos.x = x; playerPos.z = z; },
          map: () => G.map,
          loadMap: (n, s) => loadMap(n, s),
          spawnBurst, spawnFloatie,
        },
      }, extra);
    }
    function glowEnsureHud() {
      if (!GLOW_ENABLED) return;
      if (glowHudMounted && document.querySelector("[data-glow-hud-satchel]")) return;
      glowHudMounted = true;
      // Component remounts (HMR/dev) appended orphaned buttons straight into
      // <body> where they flowed into the HUD pill row — dedupe + position.
      document.querySelectorAll("[data-glow-hud-satchel]").forEach((n) => n.remove());
      // Lantern STATE still drives Glowlands gating, but its HUD chip
      // ("Spark") and the verse-satchel button are no longer shown.
      try { initLantern(glowCtx); } catch (e) {}
    }
    function glowEnsureTownBook() {
      if (!GLOW_ENABLED) return null;
      if (!glowTownBook) {
        try { glowTownBook = createTownBook(glowWorldCtx()); } catch (e) { console.warn("[glow] townbook", e); }
      }
      return glowTownBook;
    }
    function buildGlowHome() {
      if (!GLOW_ENABLED) return;
      glowTriggers = [];
      try {
        glowHomeHandle = buildHomeAdditions(glowWorldCtx());
        if (glowHomeHandle && glowHomeHandle.group && !glowHomeHandle.group.parent) worldGroup.add(glowHomeHandle.group);
      } catch (e) { console.warn("[glow] home additions", e); }
      glowEnsureHud();
    }
    function buildGlowMeadow() {
      if (!GLOW_ENABLED) { glowTriggers = []; return; }
      try { glowMeadowHandle = buildMeadowAdditions(glowWorldCtx()); }
      catch (e) { console.warn("[glow] meadow additions", e); glowMeadowHandle = null; }
      glowTriggers = (MEADOW_TRIGGERS || []).map((t) => ({ ...t }));
      // The East Gate opens ONLY once the town is saved (design bible Ch. 7).
      const saved = !!(glowMeadowHandle && glowMeadowHandle.state && glowMeadowHandle.state.saved);
      if (saved) {
        const gate = (MEADOW_TRIGGERS || []).find((t) => /gate/i.test(t.id || "")) || { x: 26.5, z: 3 };
        exits = [...exits, {
          x: gate.x, z: gate.z, r: 2.2, to: "EASTROAD",
          spawn: (EastRoad.SPAWNS && EastRoad.SPAWNS.fromMeadowTown) || [-45.5, 0],
          label: "The East Road →",
        }];
      }
      glowEnsureHud();
    }
    function buildEastRoad() {
      if (!GLOW_ENABLED) { glowTriggers = []; return; }
      clearWorld();
      glowTriggers = [];
      try {
        // keep host ambient scatter off the road spine + Wren's creek band
        const roadDist = (x, z) => {
          let bd = Infinity;
          const P = EastRoad.ROAD_PTS;
          for (let i = 0; i < P.length - 1; i++) {
            const [x1, z1] = P[i], [x2, z2] = P[i + 1];
            const dx = x2 - x1, dz = z2 - z1;
            const L2 = dx * dx + dz * dz || 1;
            const tt = Math.max(0, Math.min(1, ((x - x1) * dx + (z - z1) * dz) / L2));
            bd = Math.min(bd, Math.hypot(x - (x1 + dx * tt), z - (z1 + dz * tt)));
          }
          return bd;
        };
        const roadAvoid = (x, z) => roadDist(x, z) < 2.2 || (x > -12.4 && x < -4.6);
        glowRoadHandle = EastRoad.build(glowWorldCtx({
          // host world builders so the road rides the game's exact art systems
          makeTerrain,
          setTerrain: (fn) => { terrainY = fn; },
          setPathRoutes,
          makeGround, addFlagstonePath,
          makeOak, makePine, makeBush,
          makeSign, makeTextPlate,
          setAtmosphere,
          // ambient scatter, adapted to the corridor (module calls these with
          // loose args; host signatures are (count, area, avoid)):
          addWildflowers: (count) => addWildflowers(count || 46, 100, (x, z) => roadAvoid(x, z) || Math.abs(z) > 16 || x > 10),
          addGrass: () => addGrass(4800, 104, (x, z) => roadAvoid(x, z) || Math.abs(z) > 22),
          addGroundPatches: () => addGroundPatches(60, 104, (x, z) => roadAvoid(x, z) || Math.abs(z) > 22),
          addMountains: () => addMountains([[-30, -58, 18, 22, true], [22, -60, 20, 24, true], [-44, 56, 16, 18, false], [10, 60, 20, 23, true]]),
          addClouds, addButterflies,
        }));
        if (glowRoadHandle.terrainY) terrainY = glowRoadHandle.terrainY;
        exits = [];
        for (const e2 of glowRoadHandle.exits || []) {
          if (e2.locked) {
            glowTriggers.push({ id: "locked_" + (e2.to || "gate"), x: e2.x, z: e2.z, r: e2.r || 2.2, label: e2.lockedLine || "It's sealed for now.", lockedLine: e2.lockedLine });
            continue;
          }
          exits.push({ x: e2.x, z: e2.z, r: e2.r || 2.2, to: e2.to === "MEADOW_TOWN" ? "TOWN" : e2.to, spawn: e2.spawn, label: e2.label || "" });
        }
        hotspots = [];
        for (const s of glowRoadHandle.challengeSites || []) {
          glowTriggers.push({ id: s.id, x: s.x, z: s.z, r: s.r || 2.6, label: s.prompt || s.label || "Take a closer look", site: s });
        }
        if (glowRoadHandle.travelerAid) {
          const ta = glowRoadHandle.travelerAid;
          glowTriggers.push({ id: ta.id || "traveler_aid", x: ta.x, z: ta.z, r: ta.r || 2.4, label: ta.prompt || "Someone needs help", site: ta });
        }
      } catch (e) {
        console.warn("[glow] east road", e);
        glowRoadHandle = null;
        exits = [{ x: -49.6, z: 0, r: 2.4, to: "TOWN", spawn: [15, 0], label: "← Meadow Town" }];
      }
      glowEnsureHud();
    }
    async function glowInteract(t) {
      if (!GLOW_ENABLED) return;
      try {
        if (!t) return;
        if (t.lockedLine) { spawnFloatie(playerPos.x, playerPos.z, t.lockedLine); return; }
        if (/book|library_desk|reading/i.test(t.id || "")) { const tb = glowEnsureTownBook(); if (tb && tb.open) { await tb.open(); return; } }
        if (t.site && t.site.encounterId) { await glowCtx.startEncounter(t.site.encounterId); return; }
        if (glowPrologue && glowPrologue.interact) { await glowPrologue.interact(t.id); return; }
      } catch (e) { console.warn("[glow] interact", e); }
    }
    function glowEnterTown() {
      if (!GLOW_ENABLED) return;
      glowEnsureHud();
      (async () => {
        try {
          if (!glowPrologue) {
            glowPrologue = createPrologue(glowWorldCtx({
              meadow: () => glowMeadowHandle,
              townBook: () => glowEnsureTownBook(),
            }));
            await glowPrologue.start();
          } else if (glowPrologue.resume) {
            await glowPrologue.resume();
          }
        } catch (e) { console.warn("[glow] prologue", e); }
      })();
    }

    function loadMap(name, spawn) {
      // per-map music: recorded loop when we have one, generative otherwise
      try { playTrack(name); } catch (e) {}
      if (G.introActive) {
        stopVoiceClip();
        G.introTask = null; G.introTaskDone = null;
        G.introPage = null;
        G.introActive = false;
        G.introFocus = null;
        G.introLock = false;
        G.saveIntroDone();
      }
      if (name === "EAST_ROAD") name = "EASTROAD"; // module id alias
      // Phase 1 parked: old saves pointing at the East Road land in town
      if (!GLOW_ENABLED && name === "EASTROAD") name = "TOWN";
      if (G.clearMarketCue) { marketArrow = null; G.marketCueT = 0; }
      G.__fenceIn = null; // fence auto-select re-evaluates on the new map
      G.map = name;
      SFX.whoosh();
      if (name === "HOME") buildHome(); // buildHome calls buildGlowHome itself
      else if (name === "TOWN") buildTown(); // buildTown calls buildGlowMeadow itself
      else if (name === "CHURCH") { buildChurch(); glowTriggers = []; }
      else if (name === "EASTROAD") buildEastRoad();
      else { buildShopInterior(name); glowTriggers = []; }
      // Glowlands map-entry hooks (prologue resume in town, road travel bed)
      if (name === "TOWN") setTimeout(() => { if (G.map === "TOWN" && !G.transitioning) glowEnterTown(); }, 1400);
      if (name === "EASTROAD") { try { startEastRoadTravelLoop(); } catch (e) {} }
      else { try { stopEastRoadTravelLoop(); } catch (e) {} }
      if (window.YGTEEV_API) { if (name === "CHURCH") joinLiveGarden(); else leaveLiveGarden(); }
      // "while you were gone…" — report any off-map raids once the garden loads
      if (name === "HOME" && G.awayEaten && G.awayEaten.length && G.reqAwayReport) {
        const eaten = G.awayEaten.slice();
        G.awayEaten = [];
        setTimeout(() => { if (G.map === "HOME") G.reqAwayReport(eaten); }, 900);
      }
      // First community-garden visit: Eli walks up and explains the rules.
      // Fire after the transition settles (and only if still on CHURCH).
      if (name === "CHURCH" && !G.churchIntroDone) {
        loadChurchVoices();
        setTimeout(() => { if (G.map === "CHURCH" && !G.transitioning) G.startChurchIntro(); }, 1400);
      }
      // the community garden's sacred plots only take glowberries — preselect
      // them on entry (even at ×0), and drop back to a seed you own on exit
      if (name === "CHURCH") {
        // auto-select the LOWEST rare seed the player owns (×0 fallback)
        G.selectSeed(["glowberry", "starberry", "dawnberry", "gloryberry"].find((k) => G.inv.seeds[k] > 0) || "glowberry");
      } else if (SEEDS[G.selectedSeed]?.glow) {
        G.selectedSeed = ["strawberry", "blueberry", "sunfruit"].find((k) => G.inv.seeds[k] > 0) || "strawberry";
      }
      if (spawn) playerPos.set(spawn[0], 0, spawn[1]);
      camera.position.set(playerPos.x, 7.8, playerPos.z + 9.6);
      G.exitLatch = true; // don't re-trigger a doorway we just spawned beside
    }
    loadMap("HOME");

    // ================= INPUT =================
    const keys = {};
    const onKey = (e, down) => {
      keys[e.key.toLowerCase()] = down;
      if (down && (e.key === "e" || e.key === "E" || e.key === " ")) doAction();
      if (down && (e.key === "q" || e.key === "Q")) cycleSeed();
    };
    const kd = (e) => onKey(e, true), ku = (e) => onKey(e, false);
    window.addEventListener("keydown", kd);
    window.addEventListener("keyup", ku);

    const joy = { active: false, id: null, ox: 0, oy: 0, dx: 0, dy: 0 };
    const onTouchStart = (e) => {
      for (const t of e.changedTouches) {
        // floating joystick anywhere on the 3D view (edge to edge). UI
        // buttons are separate DOM elements, so touches on them don't reach
        // the canvas; a quick tap here still registers ~0 drag and lets
        // tap-to-act fire on release.
        if (!joy.active) {
          joy.active = true; joy.id = t.identifier; joy.ox = t.clientX; joy.oy = t.clientY; joy.dx = 0; joy.dy = 0;
        }
      }
    };
    const onTouchMove = (e) => {
      for (const t of e.changedTouches) {
        if (joy.active && t.identifier === joy.id) {
          joy.dx = Math.max(-1, Math.min(1, (t.clientX - joy.ox) / 55));
          joy.dy = Math.max(-1, Math.min(1, (t.clientY - joy.oy) / 55));
        }
      }
    };
    const onTouchEnd = (e) => {
      for (const t of e.changedTouches)
        if (joy.active && t.identifier === joy.id) { joy.active = false; joy.dx = 0; joy.dy = 0; }
    };
    mount.addEventListener("touchstart", onTouchStart, { passive: true });
    mount.addEventListener("touchmove", onTouchMove, { passive: true });
    mount.addEventListener("touchend", onTouchEnd, { passive: true });

    // Tap-to-act: a short tap on the 3D view (not a joystick drag, not a UI
    // button) that lands on/near the highlighted target triggers the same
    // action as the big button. doAction() already no-ops when nothing is
    // in range.
    const tap = { t: 0, x: 0, y: 0, moved: true };
    // press-and-hold on a regrowing plant: buy the wait down with XP.
    // Armed on pointer-down, fills over ~0.9s, cancelled by lift or drag.
    let rushHold = null; // { idx, t0 }
    const onTapDown = (e) => {
      tap.t = performance.now(); tap.x = e.clientX; tap.y = e.clientY;
      tap.moved = false;
      rushHold = null;
      if (e.target && e.target.tagName === "CANVAS" && !shopOpenRef.current && !G.quizActive) {
        const sx = e.clientX, sy = e.clientY;
        const R = Math.max(34, Math.min(64, Math.min(W(), H()) * 0.085));
        for (const n of plotNodes) {
          if (n.special) continue;
          const p2 = n.data();
          if (!p2 || !p2.seed || p2.regrowAt == null || G.time >= p2.regrowAt) continue;
          const s2 = toScreen(n.x, 0.9, n.z);
          if (s2.behind) continue;
          if (Math.hypot(sx - s2.x, sy - s2.y) < R * 1.3
              && Math.hypot(playerPos.x - n.x, playerPos.z - n.z) <= TAP_REACH) {
            rushHold = { idx: n.idx, t0: performance.now() };
            break;
          }
        }
      }
    };
    const onTapMove = (e) => {
      if (Math.hypot(e.clientX - tap.x, e.clientY - tap.y) > 18) tap.moved = true;
      if (rushHold && Math.hypot(e.clientX - tap.x, e.clientY - tap.y) > 26) rushHold = null;
    };
    // How far a tapped plot may be from the player. Generous enough to work
    // anywhere in your own garden / the quadrant you're standing in, but not
    // clear across the map.
    const TAP_REACH = 15;
    const TAP_PICK = 0.95; // ground-space radius that counts as "on a plot"

    // Screen-space picking. The old version unprojected the tap onto the
    // GROUND plane, but plants and Ember are tall: with the camera looking
    // down ~40 degrees, tapping the thing you can SEE lands a metre or more
    // behind its base, so taps regularly missed. We now project each
    // candidate to pixels and take the nearest one to the finger.
    const toScreen = (x, y, z) => {
      const v = new THREE.Vector3(x, y, z).project(camera);
      return { x: (v.x * 0.5 + 0.5) * W(), y: (-v.y * 0.5 + 0.5) * H(), behind: v.z > 1 };
    };

    const onTapUp = (e) => {
      rushHold = null; // lifted before the hold completed — just a tap
      if (tap.moved || performance.now() - tap.t > 500) return;
      if (!(e.target && e.target.tagName === "CANVAS")) return; // UI buttons handle themselves
      if (G.quizActive) return;

      const sx = e.clientX, sy = e.clientY;
      const R = Math.max(34, Math.min(64, Math.min(W(), H()) * 0.085)); // finger-sized

      // --- plots: aim at the plant's body, not the soil ---
      let picked = null, pickD = R;
      for (const n of plotNodes) {
        const p = n.data();
        const hy = p && p.seed ? 0.45 : 0.08;   // ripe plants sit above the bed
        const s2 = toScreen(n.x, hy, n.z);
        if (s2.behind) continue;
        const d = Math.hypot(sx - s2.x, sy - s2.y);
        if (d < pickD) { pickD = d; picked = n; }
      }

      // --- Ember: pick him if the finger is closer to him than to any plot ---
      let dragonD = Infinity;
      if (dragon && G.map === "HOME") {
        const ds = toScreen(dragon.position.x, dragon.position.y + 0.75, dragon.position.z);
        if (!ds.behind) dragonD = Math.hypot(sx - ds.x, sy - ds.y);
      }
      if (dragonD < R * 1.35 && dragonD < pickD) {
        if (Math.hypot(playerPos.x - dragon.position.x, playerPos.z - dragon.position.z) <= TAP_REACH) {
          currentPrompt = { type: "dragon" };
          doAction();
          return;
        }
      }

      if (picked) {
        if (Math.hypot(playerPos.x - picked.x, playerPos.z - picked.z) > TAP_REACH) {
          toast("Too far — walk closer to that plot", "warn");
          return;
        }
        const p = picked.data();
        const type = !p.seed ? "plant" : picked.stage === 2 ? "harvest" : null;
        if (!type) return; // still growing / regrowing — nothing to do yet
        currentPrompt = { type, node: picked }; // doAction reads currentPrompt
        doAction();
        return;
      }

      // --- the one-time glowing pouch on the town road ---
      if (goldBag && !G.goldBagFound) {
        const gs = toScreen(goldBag.position.x, goldBag.position.y + 0.35, goldBag.position.z);
        if (!gs.behind && Math.hypot(sx - gs.x, sy - gs.y) < R * 1.7
            && Math.hypot(playerPos.x - goldBag.position.x, playerPos.z - goldBag.position.z) <= TAP_REACH) {
          currentPrompt = { type: "goldbag" };
          doAction();
          return;
        }
      }

      // --- red pouches ---
      for (const rk in redBagMeshes) {
        const rm = redBagMeshes[rk];
        if (!rm) continue;
        const bs = toScreen(rm.position.x, rm.position.y + 0.3, rm.position.z);
        if (bs.behind) continue;
        if (Math.hypot(sx - bs.x, sy - bs.y) < R
            && Math.hypot(playerPos.x - rm.position.x, playerPos.z - rm.position.z) <= TAP_REACH) {
          currentPrompt = { type: "redbag", bagIdx: Number(rk) };
          doAction();
          return;
        }
      }

      // --- anything else already in range (bridge, counters, glow nodes) ---
      if (!currentPrompt) return;
      const node = currentPrompt.node;
      if (!node || typeof node.x !== "number") { doAction(); return; }
      const ns = toScreen(node.x, 0.3, node.z);
      if (!ns.behind && Math.hypot(sx - ns.x, sy - ns.y) < R * 1.6) doAction();
    };

    mount.addEventListener("pointerdown", onTapDown);
    mount.addEventListener("pointermove", onTapMove);
    mount.addEventListener("pointerup", onTapUp);

    // ================= ACTIONS =================
    let promptText = "";
    let currentPrompt = null;

    function cycleSeed() {
      const ownedKeys = Object.keys(SEEDS).filter((k) => G.inv.seeds[k] > 0);
      if (!ownedKeys.length) return;
      const i = ownedKeys.indexOf(G.selectedSeed);
      G.selectedSeed = ownedKeys[(i + 1) % ownedKeys.length];
    }
    G.selectSeed = (k) => { G.selectedSeed = k; G.activeKind = "seed"; };
    G.selectFruit = (k) => { G.selectedFruit = k; G.activeKind = "fruit"; };
    G.openShopBuy = (key) => {
      const s = SEEDS[key];
      if (s.currency === "xp") {
        if (G.xp < s.cost) { toast("Not enough XP!", "warn"); return; }
        G.xp -= s.cost;
        syncXpSpend(s.cost, "seed_" + key);
        SFX.sparkle();
      } else {
        if (G.gold < s.cost) { toast("Not enough gold!", "warn"); return; }
        G.gold -= s.cost;
        SFX.coin(1);
      }
      G.inv.seeds[key]++;
    };
    // Sell chosen quantities per fruit (clamped to what's actually held).
    G.sellFruit = (counts) => {
      let total = 0, count = 0;
      Object.keys(SEEDS).forEach((k) => {
        const n = Math.max(0, Math.min(G.inv.fruit[k], Math.floor(counts?.[k] || 0)));
        if (n > 0) { total += n * SEEDS[k].sell; count += n; G.inv.fruit[k] -= n; }
      });
      if (!count) return;   // the market bar already prompts; nothing to say
      G.gold += total;
      // no toast — the coins flying into the gold counter tell the story
      SFX.coin(3);
      if (G.flyCoins) G.flyCoins(Math.min(3 + Math.floor(count / 2), 10));
    };
    G.sellAll = () => G.sellFruit({ ...G.inv.fruit });

    function doAction() {
      if (G.quizActive) return;
      if (!currentPrompt) return;
      const { type, node } = currentPrompt;
      if (type === "glow") { const t = currentPrompt.glow; currentPrompt = null; glowInteract(t); return; }
      if (type === "plant") {
        if (G.activeKind === "fruit") { toast("That's food for Ember — pick a seed to plant.", "warn"); return; }
        const key = G.selectedSeed;
        if (!G.inv.seeds[key] || G.inv.seeds[key] <= 0) {
          const anyOther = Object.keys(G.inv.seeds).some((k2) => k2 !== key && G.inv.seeds[k2] > 0 && !SEEDS[k2].glow === !SEEDS[key].glow);
          toast(anyOther
            ? `No ${SEEDS[key].name} seeds left — switch to another seed pouch!`
            : "You're out of seeds — buy more in town!", "warn");
          SFX.wrong();
          return;
        }
        if (SEEDS[key].glow && !node.special) { toast("✨ Glowberries only take root in the church's glowing plots!", "warn"); return; }
        if (node.special && !SEEDS[key].glow) { toast("These sacred plots are reserved for Glowberries ✨", "warn"); return; }
        if (node.special) { G.startQuiz(node.idx); return; }
        G.inv.seeds[key]--;
        const p = node.data(); p.seed = key; p.plantedAt = G.time; p.regrowAt = null; p.harvests = 0;
        refreshPlotVisual(node);
        SFX.plant();
        spawnBurst(node.x, node.z, 0x6b4a2f, 7, { vy: 1.6, spread: 0.6, y0: 0.3 });
        G.playerHopT = 0.32;
        if (G.onIntroEvent) G.onIntroEvent("plant");
        // a prowling Ember pounces on anything freshly planted
        if (G.map === "HOME" && G.dragonState === "prowl" && dragon) {
          G.dragonState = "rampage_out";
          G.rampageTarget = node.idx;
          setRampage(true);
          toast("🐉 Ember spotted your fresh plant — he's charging!", "danger");
          G.shakeT = 0.6;
          SFX.roar();
        }
      } else if (type === "harvest") {
        const p = node.data();
        const s = SEEDS[p.seed];
        awardGems(HARVEST_GEMS[p.seed] || 1);
        G.inv.fruit[p.seed] += FRUIT_PER_HARVEST;
        SFX.harvest();
        spawnBurst(node.x, node.z, s.color, 6, { glow: s.glow, vy: 2.4, y0: 0.6 });
        G.playerHopT = 0.32;
        if (G.onIntroEvent) G.onIntroEvent("harvest");
        p.harvests = (p.harvests || 0) + 1;
        spawnFloatie(node.x, node.z, `+${FRUIT_PER_HARVEST} ${FRUIT_EMOJI[p.seed] || "🍓"}`);
        if (p.harvests >= MAX_HARVESTS) {
          toast(`🥀 The ${s.name} plant is spent — the plot is free.`, "gold");
          p.seed = null; p.regrowAt = null; p.harvests = 0;
          spawnBurst(node.x, node.z, 0x9a8a6c, 5, { vy: 1.2, spread: 0.5, y0: 0.3 });
        } else {
          p.regrowAt = G.time + (s.regrow || REGROW_SECS);
        }
        refreshPlotVisual(node);
      } else if (type === "dragon") {
        // full belly (meter reads full) — no force-feeding, no wasted fruit.
        // Never during onboarding: Eli sits Ember at a full meter so his
        // hunger clock can't run over the welcome, which made "throw Ember a
        // Strawberry" an impossible task.
        if (!G.introActive && Math.round((Math.max(0, Math.min(100, G.hunger)) / 100) * 7) >= 7) {
          SFX.wrong();
          toast("Ember is full and happy — save your fruit for later!", "warn");
          return;
        }
        const order = ["strawberry", "blueberry", "sunfruit", "glowberry", "starberry", "dawnberry", "gloryberry"];
        // the fruit picked in the Home Inventory, else the first one in the basket
        const k = (G.activeKind === "fruit" && G.inv.fruit[G.selectedFruit] > 0)
          ? G.selectedFruit
          : order.find((f) => G.inv.fruit[f] > 0);
        if (!k) { SFX.wrong(); toast("All out of fruit. Grow your plants to harvest more.", "warn"); return; }
        G.inv.fruit[k]--;
        // lob it at his snout — the meal lands when the fruit does
        if (dragon) {
          throwFruit(playerPos.x, playerPos.z, dragon.position.x, dragon.position.y + 0.9, dragon.position.z + 0.5,
            SEEDS[k].color, () => {
              SFX.feed();
              spawnBurst(dragon.position.x, dragon.position.z + 0.9, SEEDS[k].color, 6, { vy: 1.6, spread: 0.5, y0: 1 });
              G.dragonHappyT = 1.2;
            });
        }
        const bonus = SEEDS[k].feed || 30;
        G.hunger = Math.min(100, G.hunger + bonus);
        // full belly: swap to the HAPPY sign for a beat, then let it dismiss
        G.hungerPlaqueT = 0; // fed — the nag timer starts over
        if (G.hunger >= 100) { G.emberHappyT = 2.8; G.hungerAlertT = 0; }
        else G.hungerAlertT = 3;
        // no feeding toast at all — the throw, the munch and the gem meter
        // on his plaque already show what happened
        G.playerHopT = 0.32;
        if (G.dragonState === "prowl" || G.dragonState === "rampage_out") {
          // fed mid-prowl OR mid-charge — satisfied, he breaks off and heads
          // back to his cave instead of eating the plant
          G.dragonState = "rampage_back";
        }
        if (G.onIntroEvent) G.onIntroEvent("feed");
      } else if (type === "toolsmith") setShop("tools");
      else if (type === "counter") G.startCounter(currentPrompt.kind);
      else if (type === "bridge") { if (G.reqBridge) G.reqBridge(); }
      else if (type === "goldbag") {
        G.goldBagFound = true;
        G.gold += 5;
        SFX.coin(2);
        if (G.flyCoins) G.flyCoins(4);
        if (goldBag) {
          spawnBurst(goldBag.position.x, goldBag.position.z, 0xffd45e, 8, { glow: true, vy: 2.2, y0: 0.4 });
          const ci = colliders.indexOf(goldBag.userData.col);
          if (ci >= 0) colliders.splice(ci, 1); // stop blocking once collected
          worldGroup.remove(goldBag);
          goldBag = null;
        }
        hotspots = hotspots.filter((h) => h.type !== "goldbag");
        G.playerHopT = 0.32;
        if (G.reqGoldBag) G.reqGoldBag();
      }
      else if (type === "redbag") {
        const api = window.YGTEEV_API;
        const bi = currentPrompt.bagIdx;
        if (!api || !api.openRedBag) { toast("The pouch is knotted tight…", "warn"); return; }
        SFX.click();
        api.openRedBag(bi)
          .then((r) => {
            if (r && r.q) {
              const b = (G.redBags || []).find((x) => x.bag_idx === bi);
              if (b && b.status === "hidden") b.status = "opened";
              G.reqRedBag({ bagIdx: bi, q: r.q, options: r.options, phase: "q", picked: null, busy: false, result: null });
            } else {
              removeRedBag(bi, false); // already answered elsewhere — clear it
              toast("This pouch has already been opened.", "warn");
            }
          })
          .catch(() => toast("⚠️ The pouch won't budge — try again.", "warn"));
      }
      else if (type === "seedshop") setShop("seeds");
      else if (type === "market") setShop("market");
    }
    G.doAction = doAction;

    // ---- Old Gardener Eli: the quiz gatekeeper ----
    G.startQuiz = (plotIdx) => {
      const key = G.selectedSeed;
      // first challenge ever = the full speech (introLine null); after that,
      // rotate the short greetings so repeat plantings stay fresh
      const lineNo = G.eliQuizN > 0 ? ((G.eliQuizN - 1) % ELI_QUIZ_LINES.length) + 1 : 0;
      const introLine = lineNo ? ELI_QUIZ_LINES[lineNo - 1] : null;
      G.eliQuizN++;
      // narration for the rotating lines lives at voices/eli-quiz-N.mp3;
      // playVoiceFile no-ops quietly if a clip hasn't been generated yet
      playVoiceFile(lineNo ? `voices/eli-quiz-${lineNo}.mp3` : "voices/eli-intro.mp3");
      try { if (window.storage) window.storage.set("garden-eli-quiz-n", String(G.eliQuizN)); } catch (e) {}
      G.inv.seeds[key]--; // the seed leaves your pouch while Eli tests you
      G.quizActive = true;
      const api = window.YGTEEV_API;
      if (api) {
        // Server-side quiz: questions come from Bible plans the player has
        // already completed (fallback: Eli's basic pool). No answers in the
        // payload — grading happens per-answer via by_answer_quiz.
        api.startQuiz()
          .then((r) => {
            const qs = r.questions.map((q) => ({ q: q.question, o: q.options, a: -1 }));
            setQuiz({ qs, idx: 0, correct: 0, wrong: 0, picked: null, phase: "intro", results: [], plotIdx, seedKey: key, attemptId: r.attemptId, introLine });
          })
          .catch(() => {
            G.inv.seeds[key]++;
            G.quizActive = false;
            toast("⚠️ Eli couldn't find his question scroll — try again.", "danger");
            if (gardener) gardenerCtl.mode = "return";
          });
      } else {
        const pool = [...BIBLE_QUESTIONS];
        const qs = [];
        for (let i = 0; i < 3; i++) qs.push(pool.splice(Math.floor(Math.random() * pool.length), 1)[0]);
        setQuiz({ qs, idx: 0, correct: 0, wrong: 0, picked: null, phase: "intro", results: [], plotIdx, seedKey: key, introLine });
      }
      SFX.click();
      if (gardener) {
        gardener.visible = true;
        gardener.position.set(playerPos.x + 1.15, 0, playerPos.z + 0.35);
        gardener.rotation.y = Math.atan2(playerPos.x - gardener.position.x, playerPos.z - gardener.position.z);
        playerAngle = Math.atan2(gardener.position.x - playerPos.x, gardener.position.z - playerPos.z);
        player.rotation.y = playerAngle;
        gardenerCtl.mode = "greet";
      }
    };
    G.quizPass = (plotIdx, seedKey, attemptId) => {
      G.quizActive = false;
      setTimeout(() => playVoiceFile("voices/eli-pass.mp3"), 150); // just after the answer sting
      const api = window.YGTEEV_API;
      const localPlant = (plantedAtGameTime) => {
        G.churchPlots[plotIdx] = { seed: seedKey, plantedAt: plantedAtGameTime != null ? plantedAtGameTime : G.time, nextYield: null };
        const node = plotNodes.find((n) => n.special && n.idx === plotIdx);
        if (node) refreshPlotVisual(node);
      };
      if (api && attemptId) {
        api.plantRare(attemptId, plotIdx, seedKey, 0, G.activeGarden?.id ?? null)
          .then((r) => {
            // Map server wall-clock maturity onto the game clock so growth
            // stages + yield timers line up with the server's berry accrual.
            const secsUntilMature = Math.max(0, (new Date(r.matures_at).getTime() - Date.now()) / 1000);
            localPlant(G.time + secsUntilMature - 300);
            toast("🌱 'Well studied, child!' Eli lets you plant the Glowberry.");
            SFX.pass();
            try { if (liveCh) liveCh.sendAct({ i: MY_LIVE_ID }); } catch (e) {}
          })
          .catch(() => {
            G.inv.seeds[seedKey]++; // server refused (plot taken / attempt expired) — refund
            toast("😮 That plot couldn't take the seed — try another spot.", "warn");
          });
      } else {
        localPlant(null);
        toast("🌱 'Well studied, child!' Eli lets you plant the Glowberry.");
        SFX.pass();
      }
      gardenerCtl.mode = "return";
    };
    // Walking away mid-challenge: the seed goes BACK in the pouch and no
    // attempt result is submitted, so it never counts as a loss. The server
    // attempt is simply abandoned (it expires on its own).
    G.quizLeave = (seedKey) => {
      if (!G.quizActive) return;
      G.quizActive = false;
      stopVoiceClip();
      if (seedKey) G.inv.seeds[seedKey]++; // seed returns — no penalty
      playVoiceFile("voices/church-leave.mp3");
      SFX.click();
      if (gardener) gardenerCtl.mode = "return"; // back to his post, patient
      syncHud();
    };
    G.speakQuizVerdict = (right, qIdx) => {
      const n = (qIdx % 3) + 1;
      playVoiceFile(`voices/eli-${right ? "right" : "wrong"}-${n}.mp3`);
    };
    G.quizFail = () => {
      G.quizActive = false;
      setTimeout(() => playVoiceFile("voices/eli-fail.mp3"), 150); // just after the answer sting
      toast("😤 'Study the Word!' — Old Eli pockets your seed and shuffles off!", "danger");
      SFX.fail();
      if (gardener) { gardenerCtl.mode = "flee"; gardenerCtl.t = 0; }
    };

    // ---- YGTeeV backend: shared community plots (load + realtime) ----
    G.applyServerPlots = (rows) => {
      if (!Array.isArray(rows)) return;
      // keep the untouched server rows too — the picnic-table forecast needs
      // expires_at / yield_interval_seconds, which the game-clock mapping
      // below throws away
      G.plotRows = rows;
      const nowS = Date.now() / 1000;
      const prev = G.churchPlots.slice();
      for (let i = 0; i < G.churchPlots.length; i++) {
        G.churchPlots[i] = { seed: null, plantedAt: 0, nextYield: null };
      }
      for (const r of rows) {
        const idx = r.plot_idx;
        if (idx == null || idx < 0 || idx >= G.churchPlots.length) continue;
        // Server matures_at (wall clock) → game-clock plantedAt so stage +
        // yield timers line up. 300 = glowberry base grow seconds.
        const maturesGame = G.time + (new Date(r.matures_at).getTime() / 1000 - nowS);
        const plantedAt = maturesGame - 300;
        const was = prev[idx];
        // This runs again on every realtime plot change (anyone planting
        // anywhere in the garden). Carry the yield cursor across for trees
        // that did not actually change, or each refresh restarts their
        // clock and the optimistic counter re-earns their whole history.
        const same = was && was.seed === r.seed_key && Math.abs(was.plantedAt - plantedAt) < 2;
        G.churchPlots[idx] = {
          seed: r.seed_key, plantedAt,
          nextYield: same ? was.nextYield : null,
        };
      }
      if (G.map === "CHURCH") {
        for (const n of plotNodes) if (n.special) refreshPlotVisual(n);
      }
    };
    // How many berries the group's trees will bring in over the next 24h.
    // Mirrors the server's by_accrue_berries maths exactly: a plot pays one
    // berry per yield_interval_seconds from matures_at until expires_at, so
    // the forecast is simply (yield by then) - (yield paid by now).
    const yieldBy = (r, atMs) => {
      const mat = new Date(r.matures_at).getTime();
      const end = Math.min(atMs, new Date(r.expires_at).getTime());
      return Math.max(0, Math.floor((end - mat) / 1000 / r.yield_interval_seconds));
    };
    G.forecast24h = () => {
      const now = Date.now(), then = now + 86400000;
      const per = {};
      let total = 0, trees = 0, ripening = 0;
      for (const r of G.plotRows || []) {
        if (r.status && r.status !== "active") continue;
        if (new Date(r.expires_at).getTime() <= now) continue; // already spent
        trees++;
        if (new Date(r.matures_at).getTime() > now) ripening++;
        const n = yieldBy(r, then) - yieldBy(r, now);
        if (n <= 0) continue;
        per[r.seed_key] = (per[r.seed_key] || 0) + n;
        total += n;
      }
      const rows = Object.entries(per)
        .map(([key, n]) => ({ key, n, name: SEEDS[key]?.name || key }))
        .sort((a, b) => b.n - a.n);
      return { total, trees, ripening, rows };
    };

    // Active garden = which youth group's community garden we're in.
    // Single-membership users are auto-assigned; multi-membership users
    // pick at the bridge each time they cross.
    let plotsChannel = null;
    G.resubscribePlots = (gid) => {
      try { if (plotsChannel) plotsChannel.unsubscribe(); } catch (e) {}
      plotsChannel = window.YGTEEV_API
        ? window.YGTEEV_API.subscribePlots(gid, () => {
            window.YGTEEV_API.getPlots(G.activeGarden?.id).then((rows) => G.applyServerPlots(rows)).catch(() => {});
          })
        : null;
    };
    G.enterGarden = (opt, ex) => {
      G.activeGarden = { id: opt.id, name: opt.name };
      window.YGTEEV_API.getPlots(opt.id).then((rows) => G.applyServerPlots(rows)).catch(() => {});
      G.resubscribePlots(opt.id);
      syncLeague();
      G.transitioning = true;
      G.pendingMap = { to: ex.to, spawn: ex.spawn };
      if (G.reqTransition) G.reqTransition("⛪ " + opt.name);
    };
    G.cancelGardenPick = () => { G.exitLatch = true; };
    if (window.YGTEEV_API && window.YGTEEV_MEMBER) {
      const memberships = window.YGTEEV?.profile?.memberships || [];
      if (memberships.length === 1) {
        G.activeGarden = { id: memberships[0].group_id, name: memberships[0].group_name };
        syncLeague(); // re-run now that the active garden is known (boot sync ran before this)
      }
      const bootGid = G.activeGarden?.id ?? null;
      window.YGTEEV_API.getPlots(bootGid).then((rows) => G.applyServerPlots(rows)).catch(() => {});
      G.resubscribePlots(bootGid);
    }

    // ---- Community garden auto-harvest → weekly league ----
    function yieldGlowBerry(i) {
      // Berries only count toward the youth group's garden — no personal
      // gold. (The server cron independently credits the authoritative
      // league total; these local counters keep the UI live between polls.)
      // Local optimistic tick. G.week.mine is the SERVER's group-wide total
      // (refreshed by syncLeague every 60s); counting straight into it made
      // the header jump — the poll would snap it to the group figure, the
      // local +1s piled on top, and the next poll snapped it again. Pending
      // berries are tracked separately and folded in when the server catches up.
      G.week.pending = (G.week.pending || 0) + 1;
      G.week.fund += 35;
      if (G.time - G.lastCollectToast > 2) {
        G.lastCollectToast = G.time;
        SFX.sparkle();
        const node = plotNodes.find((n) => n.special && n.idx === i);
        if (node) {
          spawnBurst(node.x, node.z, SEEDS[G.churchPlots[i]?.seed]?.berry || 0x59c8ff, 4, { glow: true, vy: 2.4, y0: 1.4, spread: 0.5 });
          // show the crop that actually dropped (the old "✨" read as XP),
          // bigger and slower so it's readable from the garden camera
          const fkey = G.churchPlots[i]?.seed;
          const popY = (node.glowBadge?.userData?.topY ?? 2.9) + 0.55; // above the badge
          spawnFruitPop(node.x, node.z, fkey, popY);
        }
      }
      G.saveT = 0.2;
    }
    function expireGlowTree(i) {
      const p = G.churchPlots[i];
      p.seed = null; p.nextYield = null;
      const node = plotNodes.find((n) => n.special && n.idx === i);
      if (node) updateGlowBadge(node, p, 0); // drop the countdown with the tree
      if (node) {
        refreshPlotVisual(node);
        spawnBurst(node.x, node.z, 0x8fd8ff, 12, { glow: true, vy: 2.2, spread: 0.9, y0: 1 });
      }
      toast("🌙 A sacred tree finished its 24-hour cycle and faded to stardust.");
      SFX.sleep();
    }

    // ================= DRAGON =================
    // Chomping one-shot at the dragon's position, volume by distance —
    // audible only if you're close enough on the home map to witness it.
    function playEatSound() {
      if (!AC || !eatBuf || !dragon || G.map !== "HOME") return;
      const d = Math.hypot(playerPos.x - dragon.position.x, playerPos.z - dragon.position.z);
      const vol = Math.max(0, 1 - d / 22) * 0.9;
      if (vol < 0.02) return;
      const src = AC.createBufferSource(); src.buffer = eatBuf;
      const g = AC.createGain(); g.gain.value = vol;
      src.connect(g); g.connect(audioOut);
      src.start();
    }
    // Ember's patrol loop when the garden has nothing to steal: cave mouth →
    // west meadow → along the road → east meadow → behind the house → back.
    // Clears the house box, cave rocks, garden plots, and the big bushes.
    const PROWL_PATH = [[0, -8.6], [-5, -7], [-7, -3.5], [-5, 2.4], [0, 3.4], [5, 3.2], [9, 0], [10.5, -4.5], [10, -9.8], [4, -9.8]];
    function triggerRampage() {
      const planted = G.homePlots.map((p, i) => (p.seed ? i : -1)).filter((i) => i >= 0);
      G.hungerAlertT = 6;
      if (!planted.length) {
        // nothing to eat — he stays hangry and prowls the meadow until fed.
        // Hunger is NOT reset here: only actually eating refills him.
        G.dragonState = "prowl";
        G.prowlIdx = 0;
        G.prowlFrenzyT = 0;
        G.prowlNextFrenzy = 4 + Math.random() * 4;
        toast("🐉 EMBER IS HANGRY! He's prowling the meadow for food!", "danger");
        if (G.map === "HOME" && dragon) { G.shakeT = 0.6; SFX.roar(); }
        return;
      }
      // hunger stays EMPTY for the whole charge — the refill lands at the
      // moment he actually eats the plant (the Math.max(…, 55) at arrival),
      // so the meter tells the truth: starving on the way out, fed after.
      const victim = planted[Math.floor(Math.random() * planted.length)];
      if (G.map === "HOME" && dragon) {
        G.dragonState = "rampage_out";
        G.rampageTarget = victim;
        setRampage(true);
        toast("🐉 EMBER IS HANGRY! He's charging the garden!", "danger");
        G.shakeT = 0.8;
        SFX.roar();
      } else {
        // Off-map raid: the player is in town / the community garden and
        // can't see any of this. Toasting here fires into an empty room, so
        // the loss is banked and reported the moment they walk back home.
        const lostKey = G.homePlots[victim].seed;
        G.homePlots[victim].seed = null;
        G.homePlots[victim].regrowAt = null;
        G.homePlots[victim].harvests = 0;
        G.awayEaten = [...(G.awayEaten || []), lostKey];
        // tell them where they ARE — a drop-down carrying the crop's own
        // inventory tile so the loss is unmistakable from another map
        toast(`🐉 Ember ate your ${SEEDS[lostKey]?.name || "plant"} back home!`, "danger",
              `/ui/kit/inv-seed-${lostKey}.png`);
        G.hunger = Math.max(G.hunger, 55); // he ate — same refill as an on-screen raid
        G.saveT = 0.2;
      }
    }

    function updateDragon(dt) {
      if (!dragon) return;
      const u = dragon.userData;
      const t = G.time;

      // ---- floating hunger meter ----
      if (emberBar) {
        emberBar.position.set(dragon.position.x, dragon.position.y + 3.1 + Math.sin(t * 1.5) * 0.05, dragon.position.z);
        const pct = Math.max(0, Math.min(100, G.hunger));
        const gems = Math.round((pct / 100) * 7);
        const full = gems >= 7;
        const key = gems + (full ? "F" : "");
        const bd = emberBar.userData;
        if (key !== bd.last) {
          bd.last = key;
          const c = bd.cv.getContext("2d");
          c.clearRect(0, 0, 448, 112);
          const rr = (x, y, w, h, r) => { c.beginPath(); c.moveTo(x + r, y); c.arcTo(x + w, y, x + w, y + h, r); c.arcTo(x + w, y + h, x, y + h, r); c.arcTo(x, y + h, x, y, r); c.arcTo(x, y, x + w, y, r); c.closePath(); };
          rr(6, 24, 436, 64, 18);
          c.fillStyle = "#2e1c0d"; c.fill();
          c.lineWidth = 7; c.strokeStyle = "#150d05"; c.stroke();
          for (let i = 0; i < 7; i++) {
            const cx = 52 + i * 57.3, cy = 56;
            const lit = i < gems;
            c.save();
            if (lit) { c.shadowColor = full ? "#4aff80" : "#ff5040"; c.shadowBlur = 10; }
            c.beginPath();
            c.moveTo(cx, cy - 23); c.lineTo(cx + 17, cy); c.lineTo(cx, cy + 23); c.lineTo(cx - 17, cy);
            c.closePath();
            c.fillStyle = lit ? (full ? "#35d55c" : "#e8402e") : "#180d04";
            c.fill();
            c.lineWidth = 5;
            c.strokeStyle = lit ? (full ? "#0f6b28" : "#6e150c") : "#0d0702";
            c.stroke();
            c.restore();
            if (lit) {
              c.beginPath(); c.moveTo(cx - 5, cy - 13); c.lineTo(cx + 2, cy - 7); c.lineTo(cx - 6, cy - 3);
              c.closePath(); c.fillStyle = "rgba(255,255,255,.34)"; c.fill();
            }
          }
          bd.tex.needsUpdate = true;
        }
      }

      // mood with hysteresis: naps when full, wakes when hungry
      const prevMood = G.dragonMood;
      if (G.dragonState !== "idle") G.dragonMood = "awake";
      else if (G.hunger >= 64) G.dragonMood = "sleep";
      else if (G.hunger < 54) G.dragonMood = "awake"; // 100 -> 54 at this rate = ~2 min
      if (prevMood !== G.dragonMood) {
        if (G.dragonMood === "awake") { G.wakeT = 0.9; G.hungerAlertT = 4.5; toast("🐉 Ember stirs awake — he's getting hungry!", "warn"); SFX.wake(); }
        else { SFX.sleep(); }
      }
      G.sleepBlend += ((G.dragonMood === "sleep" ? 1 : 0) - G.sleepBlend) * Math.min(1, dt * 2.2);
      const b = G.sleepBlend;
      if (G.wakeT > 0) G.wakeT -= dt;
      const L = (a, c) => a + (c - a) * b;

      // ---- lab-v3 rig pose (mood logic above is unchanged) ----
      const c = u.ctl;
      const hangry = G.hunger < 30 && G.dragonState === "idle";
      const rampaging = G.dragonState !== "idle";
      const wp = G.wakeT > 0 ? Math.sin(((0.9 - G.wakeT) / 0.9) * Math.PI) : 0;

      // torso breathing — light awake, deep + squashy asleep
      const breathe = Math.sin(t * (1.6 + (1 - b) * 0.8)) * (0.014 + 0.045 * b);
      u.torso.scale.set(1 + breathe * b * 0.5, 1 + breathe, 1 + breathe * b * 0.5);

      // eyelids: sleep + autonomous blinks
      c.nextBlink -= dt;
      if (c.nextBlink <= 0) c.nextBlink = 1.6 + Math.random() * 3.4;
      const blinkTarget = Math.max(b, c.nextBlink < 0.13 ? 1 : 0);
      c.blink += (blinkTarget - c.blink) * Math.min(1, dt * 18);
      u.eyeL.lid.rotation.x = -1.45 + c.blink * 1.5;
      u.eyeR.lid.rotation.x = -1.45 + c.blink * 1.5;

      // googly pupil wander (awake only)
      const wander = 0.16 * (1 - b);
      u.eyeL.pupil.position.x = Math.sin(t * 0.7) * wander * u.eyeL.r;
      u.eyeL.pupil.position.y = Math.cos(t * 0.9) * wander * u.eyeL.r * 0.6;
      u.eyeR.pupil.position.x = Math.sin(t * 1.13 + 2) * wander * u.eyeR.r;
      u.eyeR.pupil.position.y = Math.cos(t * 0.77 + 1) * wander * u.eyeR.r * 0.6;

      // rage: brows slam + eyes run hot (hangry idle AND rampage)
      c.rage += (((hangry || rampaging) ? 1 : 0) - c.rage) * Math.min(1, dt * 4);
      u.eyeL.ball.material.emissive.copy(u.eyeWarm).lerp(u.eyeHot, c.rage);
      u.eyeR.ball.material.emissive.copy(u.eyeWarm).lerp(u.eyeHot, c.rage);
      u.eyeL.ball.material.emissiveIntensity = 0.12 * (1 - b) + c.rage * 0.55;
      u.eyeR.ball.material.emissiveIntensity = 0.12 * (1 - b) + c.rage * 0.5;
      u.browL.position.y = u.browL.userData.by - c.rage * 0.1;
      u.browR.position.y = u.browR.userData.by - c.rage * 0.1;
      u.browL.rotation.z = -0.12 - c.rage * 0.45;
      u.browR.rotation.z = 0.12 + c.rage * 0.45;

      // tongue: streams out on a rampage, tip out asleep, random lolls idle
      let tongueTarget;
      if (rampaging) tongueTarget = 1;
      else if (b > 0.5) tongueTarget = 0.35;
      else {
        c.nextTongue -= dt;
        if (c.nextTongue <= 0) c.nextTongue = 6 + Math.random() * 9;
        tongueTarget = c.nextTongue < 2.2 ? 1 : 0;
      }
      if (wp > 0) tongueTarget = Math.max(tongueTarget, wp * 0.55); // yawn
      c.tongue += (tongueTarget - c.tongue) * Math.min(1, dt * 5);
      const out = c.tongue;
      u.tongue.visible = out > 0.04;
      u.tongue.scale.setScalar(Math.max(0.01, out));
      u.tongue.rotation.x = 0.25 + (1 - out) * -0.6 + Math.sin(t * 10.7) * 0.16 * out;
      u.tSegs[1].rotation.x = Math.sin(t * 13.2 + 1) * 0.35 * out;
      u.tSegs[2].rotation.x = Math.sin(t * 15.7 + 2) * 0.5 * out;

      // jaw: yawn on wake, panting chomp on rampage, slack asleep
      let jawTarget = rampaging ? 0.55 + Math.sin(t * 15) * 0.3 : L(0, 0.16);
      jawTarget = Math.max(jawTarget, wp * 0.9);
      c.jaw += (jawTarget - c.jaw) * Math.min(1, dt * 8);
      u.jaw.rotation.x = c.jaw * 0.55;

      // head: idle sway ↔ sleepy droop, rear-back stretch on wake, chaos on rampage
      u.headG.position.set(0, 2.66 - 0.26 * b + wp * 0.1, 0.3 + 0.1 * b);
      u.headG.rotation.set(
        L(Math.sin(t * 1.3) * 0.05, 0.42) - wp * 0.55 + (rampaging ? 0.2 + Math.sin(t * 13) * 0.12 : 0),
        L(Math.sin(t * 0.8) * 0.16, 0.12) + (rampaging ? Math.sin(t * 17) * 0.2 : 0),
        L(Math.sin(t * 1.1) * 0.03, 0.06));

      // wings: folded asleep, slow idle flaps, agitated when hangry, unfurl on wake
      const flap = rampaging ? Math.sin(t * 16) * 0.6
        : hangry ? Math.sin(t * 10) * 0.35
        : Math.sin(t * 2.2) * 0.1 * (1 - b);
      u.wingL.rotation.set(u.wLbase.x + 0.3 * b, u.wLbase.y - 0.35 * b, u.wLbase.z + 0.25 * b + flap + wp * 0.9);
      u.wingR.rotation.set(u.wRbase.x + 0.3 * b, u.wRbase.y + 0.35 * b, u.wRbase.z - 0.25 * b - flap - wp * 0.9);

      // limbs: stride on rampage, limp-relaxed otherwise
      if (rampaging) {
        const st = t * 9;
        u.legL.rotation.x = Math.sin(st) * 1.0;
        u.legR.rotation.x = -Math.sin(st) * 1.0;
        u.armL.rotation.set(-Math.sin(st) * 0.9, 0, 0.18);
        u.armR.rotation.set(Math.sin(st) * 0.9, 0, -0.18);
      } else {
        u.legL.rotation.x *= 1 - Math.min(1, dt * 6);
        u.legR.rotation.x *= 1 - Math.min(1, dt * 6);
        u.armL.rotation.set(0.4 * b + Math.sin(t * 1.8) * 0.07 * (1 - b), 0, 0.06 + 0.14 * b);
        u.armR.rotation.set(0.4 * b + Math.sin(t * 1.8 + 2) * 0.07 * (1 - b) - 0.18 * (1 - b), 0, -0.06 - 0.14 * b);
      }

      // tail sway — lazy asleep, whipping on rampage
      const tailF = rampaging ? 4.5 : 1.9 - b;
      u.tail0.rotation.y = Math.sin(t * tailF) * (rampaging ? 0.35 : 0.3);
      u.tail1.rotation.y = Math.sin(t * tailF + 0.8) * (rampaging ? 0.5 : 0.35);
      u.tail2.rotation.y = Math.sin(t * tailF + 1.6) * (rampaging ? 0.6 : 0.4);

      if (G.dragonState === "idle") {
        dragon.position.y = Math.sin(t * 2) * 0.05 * (1 - b) - 0.06 * b + wp * 0.12;
        if (G.dragonHappyT > 0) {
          G.dragonHappyT -= dt;
          dragon.rotation.z = Math.sin(t * 12) * 0.08 * (1 - b);
        } else dragon.rotation.z = 0;
      } else if (G.dragonState === "rampage_out" || G.dragonState === "rampage_back") {
        const targetNode = plotNodes.find((n) => !n.special && n.idx === G.rampageTarget && n.arr === G.homePlots);
        const dest = G.dragonState === "rampage_out" && targetNode
          ? new THREE.Vector3(targetNode.x, 0, targetNode.z - 1.6)
          : dragonHome;
        const dir = dest.clone().sub(dragon.position); dir.y = 0;
        const dist = dir.length();
        if (dist < 0.4) {
          if (G.dragonState === "rampage_out") {
            // player stepped back to the title mid-charge — call it off
            if (targetNode && !G.splashActive) {
              const lost = SEEDS[G.homePlots[G.rampageTarget].seed]?.name || "plant";
              G.homePlots[G.rampageTarget].seed = null;
              refreshPlotVisual(targetNode);
              toast(`🐉 Ember gobbled your ${lost} plant, roots and all!`, "danger");
              G.shakeT = 0.6;
              playEatSound();
              spawnBurst(targetNode.x, targetNode.z, 0x6b4a2f, 8, { vy: 2, spread: 0.7 });
            }
            G.hunger = Math.max(G.hunger, 55); // eating is what refills him (prowl charges arrive at 0)
            G.dragonState = "rampage_back";
          } else {
            G.dragonState = "idle";
            setRampage(false);
            dragon.rotation.y = 0;
            dragon.rotation.x = 0;
          }
        } else {
          dir.normalize();
          dragon.position.addScaledVector(dir, dt * 6.5);
          dragon.rotation.y = Math.atan2(dir.x, dir.z);
          dragon.position.y = Math.abs(Math.sin(t * 9)) * 0.3;
          dragon.rotation.x = -0.22; // charging lean
        }
      } else if (G.dragonState === "prowl") {
        // hangry patrol: stalks the loop until he's fed (or something is
        // planted — doAction turns that into an immediate charge)
        G.prowlNextFrenzy -= dt;
        if (G.prowlFrenzyT > 0) {
          // crazy burst: spins and hops in place
          G.prowlFrenzyT -= dt;
          dragon.rotation.y += dt * 9;
          dragon.position.y = Math.abs(Math.sin(t * 13)) * 0.35;
          dragon.rotation.x = 0;
          if (G.prowlFrenzyT <= 0) G.prowlNextFrenzy = 6 + Math.random() * 5;
        } else {
          const wp = PROWL_PATH[G.prowlIdx % PROWL_PATH.length];
          const dir = new THREE.Vector3(wp[0], 0, wp[1]).sub(dragon.position); dir.y = 0;
          const dist = dir.length();
          if (dist < 0.5) G.prowlIdx = (G.prowlIdx + 1) % PROWL_PATH.length;
          else {
            dir.normalize();
            dragon.position.addScaledVector(dir, dt * 2.4);
            dragon.rotation.y = Math.atan2(dir.x, dir.z);
            dragon.position.y = Math.abs(Math.sin(t * 7)) * 0.22;
            dragon.rotation.x = -0.12; // stalking lean
          }
          if (G.prowlNextFrenzy <= 0) {
            G.prowlFrenzyT = 1.4;
            const pd = Math.hypot(playerPos.x - dragon.position.x, playerPos.z - dragon.position.z);
            if (pd < 14 && Math.random() < 0.4) SFX.roar();
            if (pd < 8) G.shakeT = Math.max(G.shakeT, 0.25);
          }
        }
        // fire trail: flames drip off behind him and slowly gutter out
        // (during a frenzy spin the trail wraps into a ring around him)
        G.prowlFireT -= dt;
        if (G.prowlFireT <= 0) {
          G.prowlFireT = G.prowlFrenzyT > 0 ? 0.045 : 0.075;
          const fx = dragon.position.x - Math.sin(dragon.rotation.y) * 0.85;
          const fz = dragon.position.z - Math.cos(dragon.rotation.y) * 0.85;
          const fc = [0xff8c2a, 0xffb020, 0xe0482a][Math.floor(Math.random() * 3)];
          spawnBurst(fx, fz, fc, 1, { glow: true, size: 0.12 + Math.random() * 0.08, vy: 0.5, vs: 0.3, ttl: 0.9 + Math.random() * 0.5, spread: 0.5, y0: 0.1 });
        }
      }
    }

    // ================= LOOP =================
    const clock = new THREE.Clock();
    let hudTick = 0;
    let raf;

    function animate() {
      raf = requestAnimationFrame(animate);
      const dt = Math.min(clock.getDelta(), 0.05);
      // Glowlands per-map animation beds (foam, creep, waymarkers, stain)
      if (glowRoadHandle && G.map === "EASTROAD" && glowRoadHandle.update) glowRoadHandle.update(dt * (G.glowTimeDilation || 1));
      if (glowMeadowHandle && G.map === "TOWN" && glowMeadowHandle.update) glowMeadowHandle.update(dt * (G.glowTimeDilation || 1));
      if (glowHomeHandle && G.map === "HOME" && glowHomeHandle.update) glowHomeHandle.update(dt * (G.glowTimeDilation || 1), G.time);
      G.time += dt;

      let mx = 0, mz = 0;
      if (keys["w"] || keys["arrowup"]) mz -= 1;
      if (keys["s"] || keys["arrowdown"]) mz += 1;
      if (keys["a"] || keys["arrowleft"]) mx -= 1;
      if (keys["d"] || keys["arrowright"]) mx += 1;
      mx += joy.dx; mz += joy.dy;
      const mLen = Math.hypot(mx, mz);
      const speed = 6.2;
      const moving = mLen > 0.08 && !shopOpenRef.current && !G.introLock && !G.turtleSeq;
      if (moving) {
        mx /= Math.max(1, mLen); mz /= Math.max(1, mLen);
        playerPos.x += mx * speed * dt;
        playerPos.z += mz * speed * dt;
        if (G.map === "EASTROAD") {
          // the road corridor is long east-west (town exit -49.6 … sealed gate 55)
          playerPos.x = Math.max(-51, Math.min(56, playerPos.x));
          playerPos.z = Math.max(-24, Math.min(24, playerPos.z));
        } else {
          const bound = G.map === "HOME" ? 33 : G.map === "CHURCH" ? 34 : 26;
          playerPos.x = Math.max(-bound, Math.min(bound, playerPos.x));
          playerPos.z = Math.max(-bound, Math.min(bound, playerPos.z));
        }
        playerAngle = Math.atan2(mx, mz);
        stepT += dt;
        if (stepT > 0.3) {
          stepT = 0;
          SFX.step();
          spawnBurst(playerPos.x - mx * 0.35, playerPos.z - mz * 0.35, 0x9a8a6c, 1, { size: 0.05, vy: 0.7, vs: 0.5, ttl: 0.4, y0: 0.08 });
        }
      }

      if (!G.turtleSeq) resolveCollisions(playerPos, dragon, G.map === "HOME" && (G.dragonState === "idle" || G.dragonState === "prowl"));
      // river boundary that FOLLOWS the meander: you can stand right at the
      // water's edge anywhere along the bank, but not wade in. The bridge
      // deck band is exempt (members cross there; the broken middle has its
      // own seals), and the turtle overrides it while you're riding.
      if (G.map === "HOME" && !G.turtleSeq && Math.abs(playerPos.z - 3) > 1.15) {
        const rc = RIVER_X(playerPos.z);
        const rd2 = playerPos.x - rc;
        if (Math.abs(rd2) < 1.75) playerPos.x = rc + (rd2 >= 0 ? 1.75 : -1.75);
      }
      // solid groupmates in the community garden (they move, so push
      // dynamically off their current position; skip parked-underground ones)
      if (G.map === "CHURCH") {
        for (const id in livePlayers) {
          const m = livePlayers[id].mesh;
          if (m.position.y > -30) pushOutOfCircle(playerPos, m.position.x, m.position.z, 0.55);
        }
      }
      // Eli is solid too — he moves (approach/leave/greet), so collide off
      // his live position rather than a stale spawn-point collider
      if (gardener && gardener.visible) pushOutOfCircle(playerPos, gardener.position.x, gardener.position.z, 0.42);

      player.position.copy(playerPos);
      const groundY = terrainY(playerPos.x, playerPos.z);
      if (G.styleActive) { player.rotation.y += dt * 0.7; playerAngle = player.rotation.y; }
      else player.rotation.y += (playerAngle - player.rotation.y) * 0.25;

      // ---- chibi rig animation ----
      const pu = player.userData;
      if (moving) {
        const tw = G.time * 11;
        const sw = Math.sin(tw);
        pu.legL.rotation.x = sw * 0.72;
        pu.legR.rotation.x = -sw * 0.72;
        // asymmetric arm swing — different amplitudes + a slight phase lead
        // on the right so the gait doesn't read as a metronome
        pu.armL.rotation.x = -sw * 0.7;
        pu.armR.rotation.x = Math.sin(tw + 0.35) * 0.78;
        // arms wing slightly outward on the swing so they visibly clear the
        // torso at overview distance (base splay is +-0.26, matching mkArm)
        pu.armL.rotation.z = -0.26 - Math.abs(sw) * 0.09;
        pu.armR.rotation.z = 0.26 + Math.abs(Math.sin(tw + 0.35)) * 0.09;
        pu.body.rotation.x += (0.13 - pu.body.rotation.x) * 0.2;    // lean into the run
        pu.body.rotation.z = Math.sin(tw * 0.5) * 0.03;             // hip sway at half cadence
        pu.head.rotation.y *= 0.75;
        pu.head.rotation.x += (-0.07 - pu.head.rotation.x) * 0.2;   // chin up against the lean
        pu.hatG.position.y = pu.hatBaseY + Math.abs(sw) * 0.035;
        pu.hatG.rotation.x = Math.sin(tw - 1.1) * 0.05;             // hat follow-through lag
        pu.body.scale.y += (1 - pu.body.scale.y) * 0.3;
        pu.idleT = 0; pu.lookT = 0;
      } else {
        pu.legL.rotation.x *= 0.75;
        pu.legR.rotation.x *= 0.75;
        // ease out of the swing into a gentle offset breathing sway
        pu.armL.rotation.x = pu.armL.rotation.x * 0.85 + Math.sin(G.time * 2.1 + 1.2) * 0.012;
        pu.armR.rotation.x = pu.armR.rotation.x * 0.85 + Math.sin(G.time * 2.1) * 0.012;
        pu.armL.rotation.z += (-0.26 - pu.armL.rotation.z) * 0.2;   // settle back to rest splay
        pu.armR.rotation.z += (0.26 - pu.armR.rotation.z) * 0.2;
        pu.body.rotation.x *= 0.75;
        pu.body.rotation.z *= 0.8;
        pu.head.rotation.x *= 0.85;
        pu.body.scale.y = 1 + Math.sin(G.time * 2.1) * 0.015;
        pu.hatG.position.y = pu.hatBaseY;
        pu.hatG.rotation.x *= 0.85;
        pu.idleT += dt;
        if (pu.lookT <= 0 && pu.idleT > 2.2 && Math.random() < dt * 0.35) {
          pu.lookT = 1.6;
          pu.lookDir = (Math.random() < 0.5 ? -1 : 1) * (0.45 + Math.random() * 0.4);
        }
        if (pu.lookT > 0) {
          pu.lookT -= dt;
          const lk = Math.sin(Math.min(1, (1.6 - pu.lookT) / 1.6) * Math.PI);
          pu.head.rotation.y = pu.lookDir * lk;
        } else pu.head.rotation.y *= 0.9;
      }
      pu.blinkT -= dt;
      if (pu.blinkT <= 0) { pu.blinkT = 2.2 + Math.random() * 3; pu.blinkD = 0.12; }
      if (pu.blinkD > 0) pu.blinkD -= dt;
      const eyeS = pu.blinkD > 0 ? 0.12 : 1;
      pu.eyeL.scale.y = eyeS; pu.eyeR.scale.y = eyeS;
      // action hop with squash-and-stretch
      let hop = 0;
      if (G.playerHopT > 0) {
        G.playerHopT -= dt;
        hop = Math.sin((1 - G.playerHopT / 0.32) * Math.PI);
      }
      player.scale.set(1 + hop * 0.12, 1 - hop * 0.2, 1 + hop * 0.12);
      player.position.y = groundY + hop * 0.3 + (moving ? Math.abs(Math.sin(G.time * 11)) * 0.05 : 0);

      // ---- the snapping turtle: swim, lure, tantrum, yeet ----
      if (turtle && G.map === "HOME") {
        const TU = turtle.userData;
        const bob = Math.sin(G.time * 2.1) * 0.05;
        if (G.turtleCd > 0) G.turtleCd -= dt;
        const seq = G.turtleSeq;
        if (!seq || seq.phase === "ride") {
          // patrol the river (faster with a passenger — showing off)
          const spd = seq ? 2.2 : 1.1;
          let nz = TU.z + TU.dir * spd * dt;
          // The repaired bridge is tall enough for the turtle but nowhere
          // near tall enough for a standing passenger, so a ridden turtle
          // balks and turns back. Only when the span is actually whole —
          // the collapsed middle is open sky, and a rider fits through it.
          // Guarded on "was outside": boarding while it is already under the
          // bridge must let it swim clear, not trap it flipping every frame.
          if (seq && G.youthGroup) {
            const outsideNow = Math.abs(TU.z - 3) >= TURTLE_BRIDGE_HALF;
            if (outsideNow && Math.abs(nz - 3) < TURTLE_BRIDGE_HALF) {
              TU.dir *= -1;
              nz = TU.z;
              if (!seq.balked) {
                seq.balked = true;
                toast("🐢 Too low! The turtle won't duck under the bridge with you aboard.", "warn");
              }
            }
          }
          TU.z = nz;
          if (TU.z > 15) { TU.z = 15; TU.dir = -1; }
          if (TU.z < -16) { TU.z = -16; TU.dir = 1; }
          // hug the east bank a touch — that's the side players can reach
          const rx = RIVER_X(TU.z) + 0.5;
          const ahead = RIVER_X(TU.z + TU.dir) + 0.5;
          turtle.position.set(rx, -0.16 + bob, TU.z);
          turtle.rotation.y = Math.atan2(ahead - rx, TU.dir);
          turtle.rotation.z = Math.sin(G.time * 2.1) * 0.03;
          TU.flippers.forEach((f) => { f.rotation.x = Math.sin(G.time * (seq ? 9 : 5) + f.userData.ph) * 0.5; });
          TU.head.rotation.y = Math.sin(G.time * 0.7) * 0.3;
          TU.jaw.position.y = -0.24 + Math.max(0, Math.sin(G.time * 1.3)) * -0.06;
        }
        const onBridgeRoad = Math.abs(playerPos.z - 3) < 2 && playerPos.x > -18 && playerPos.x < -9;
        if (!seq && G.turtleCd <= 0 && !G.introActive && !G.introLock && !shopOpenRef.current && !onBridgeRoad
            && Math.hypot(playerPos.x - turtle.position.x, playerPos.z - turtle.position.z) < 4.6) {
          G.turtleSeq = { phase: "board", t: 0, fx: playerPos.x, fz: playerPos.z, fy: player.position.y };
          SFX.whoosh();
        }
        if (G.turtleSeq) {
          const q = G.turtleSeq;
          q.t += dt;
          const shellY = () => turtle.position.y + TU.shellTopY;
          if (q.phase === "board") {
            const k = Math.min(1, q.t / 0.5);
            playerPos.x = q.fx + (turtle.position.x - q.fx) * k;
            playerPos.z = q.fz + (turtle.position.z - q.fz) * k;
            player.position.set(playerPos.x, q.fy + (shellY() - q.fy) * k + Math.sin(k * Math.PI) * 1.4, playerPos.z);
            if (k >= 1) { q.phase = "ride"; q.t = 0; }
          } else if (q.phase === "ride") {
            playerPos.x = turtle.position.x; playerPos.z = turtle.position.z;
            player.position.set(playerPos.x, shellY(), playerPos.z);
            player.rotation.y = turtle.rotation.y;
            if (q.t > 3.2) { q.phase = "shake"; q.t = 0; SFX.roar(); }
          } else if (q.phase === "shake") {
            // full-body tantrum — the passenger rattles with the shell
            turtle.rotation.y += Math.sin(G.time * 38) * 0.12;
            turtle.rotation.z = Math.sin(G.time * 31) * 0.1;
            playerPos.x = turtle.position.x; playerPos.z = turtle.position.z;
            player.position.set(playerPos.x + Math.sin(G.time * 40) * 0.08, shellY(), playerPos.z);
            if (q.t > 1.2) {
              q.phase = "toss"; q.t = 0;
              q.fx = playerPos.x; q.fz = playerPos.z; q.fy = shellY();
              // land on the meadow east of the river, near the main home area
              q.tx = RIVER_X(turtle.position.z) + 7.5;
              q.tz = Math.max(-2, Math.min(9, turtle.position.z));
              SFX.whoosh();
              toast("🐢 SNAP! The turtle has had enough of passengers!", "warn");
            }
          } else if (q.phase === "toss") {
            const k = Math.min(1, q.t / 0.85);
            playerPos.x = q.fx + (q.tx - q.fx) * k;
            playerPos.z = q.fz + (q.tz - q.fz) * k;
            const gy = terrainY(playerPos.x, playerPos.z);
            player.position.set(playerPos.x, q.fy + (gy - q.fy) * k + Math.sin(k * Math.PI) * 3.4, playerPos.z);
            player.rotation.x = k * Math.PI * 2; // comedic tumble
            if (k >= 1) {
              q.phase = "sprawl"; q.t = 0;
              player.rotation.x = -Math.PI / 2; // face-down in the grass
              spawnBurst(playerPos.x, playerPos.z, 0x9a8a6c, 7, { vy: 1.6, spread: 0.7, y0: 0.2 });
              G.shakeT = 0.3;
            }
          } else if (q.phase === "sprawl") {
            player.position.y = terrainY(playerPos.x, playerPos.z) + 0.25;
            if (q.t > 0.9) {
              player.rotation.x = 0;
              G.playerHopT = 0.32; // dusts off and pops back to their feet
              G.turtleSeq = null;
              G.turtleCd = 10; // the turtle needs a moment before the next prank
            }
          }
        }
      }

      // ---- live groupmates: broadcast my position, animate theirs ----
      if (liveCh && G.map === "CHURCH") {
        liveSendGate -= dt;
        if (liveSendGate <= 0) {
          const dxy = Math.abs(playerPos.x - lastSent.x) + Math.abs(playerPos.z - lastSent.z);
          let dAng = playerAngle - lastSent.a;
          dAng = Math.atan2(Math.sin(dAng), Math.cos(dAng));
          if (dxy > 0.06 || Math.abs(dAng) > 0.1 || moving !== lastSent.m || G.time - lastSent.t > 2.5) {
            lastSent.x = playerPos.x; lastSent.z = playerPos.z; lastSent.a = playerAngle; lastSent.m = moving; lastSent.t = G.time;
            liveSendGate = 0.12; // ~8 Hz max while actually moving
            try { liveCh.sendPos({ i: MY_LIVE_ID, x: +playerPos.x.toFixed(2), z: +playerPos.z.toFixed(2), a: +playerAngle.toFixed(2), m: moving }); } catch (e) {}
          } else liveSendGate = 0.05;
        }
      }
      for (const id in livePlayers) {
        const lp = livePlayers[id];
        if (!lp.tgt) continue;
        if (G.time - lp.lastMsg > 30) { removeLivePlayer(id); continue; }
        const m = lp.mesh, ru = m.userData;
        if (m.position.y < -30) m.position.set(lp.tgt.x, 0, lp.tgt.z); // first packet: snap into place
        m.position.x += (lp.tgt.x - m.position.x) * Math.min(1, dt * 9);
        m.position.z += (lp.tgt.z - m.position.z) * Math.min(1, dt * 9);
        let rda = lp.tgt.a - m.rotation.y;
        rda = Math.atan2(Math.sin(rda), Math.cos(rda));
        m.rotation.y += rda * Math.min(1, dt * 10);
        const drifting = Math.hypot(lp.tgt.x - m.position.x, lp.tgt.z - m.position.z) > 0.06;
        const walking = lp.tgt.m || drifting;
        if (walking) {
          const sw = Math.sin(G.time * 11 + m.position.x);
          ru.legL.rotation.x = sw * 0.7; ru.legR.rotation.x = -sw * 0.7;
          ru.armL.rotation.x = -sw * 0.6; ru.armR.rotation.x = sw * 0.6;
          ru.hatG.position.y = ru.hatBaseY + Math.abs(sw) * 0.035;
        } else {
          ru.legL.rotation.x *= 0.75; ru.legR.rotation.x *= 0.75;
          ru.armL.rotation.x *= 0.75; ru.armR.rotation.x *= 0.75;
          ru.hatG.position.y = ru.hatBaseY;
          ru.body.scale.y = 1 + Math.sin(G.time * 2.1 + m.position.z) * 0.015;
        }
        let rHop = 0;
        if (lp.hopT > 0) { lp.hopT -= dt; rHop = Math.sin((1 - lp.hopT / 0.32) * Math.PI); }
        m.scale.set(1 + rHop * 0.12, 1 - rHop * 0.2, 1 + rHop * 0.12);
        m.position.y = terrainY(m.position.x, m.position.z) + rHop * 0.3 + (walking ? Math.abs(Math.sin(G.time * 11 + m.position.x)) * 0.05 : 0);
      }

      if (G.introTask && G.introTaskDone === G.introTask) {
        // Don't jump straight to Eli's next line — hold a celebratory beat
        // so the player sees their win land (and, for feed, watches the
        // whole fruit lob + munch play out before the camera leaves).
        const INTRO_TASK_IDX = { plant: 2, harvest: 3, feed: 4 };
        const done = G.introTask;
        G.introCelebrate = done;
        G.introCelebrateT = done === "feed" ? 3.6 : 2.6;
        G.introCelebrateNext = INTRO_TASK_IDX[done] + 1;
        G.introTask = null; G.introTaskDone = null;
        SFX.pass();
        try {
          if (done === "feed" && dragon) spawnBurst(dragon.position.x, dragon.position.z, 0xffd76a, 8, { glow: true, vy: 2.6, y0: 1.6, spread: 0.9 });
          else { const n = plotNodes.find((nn) => nn.data().seed) || plotNodes[0]; if (n) spawnBurst(n.x, n.z, 0xff8a9a, 7, { glow: true, vy: 2.4, y0: 1.0, spread: 0.7 }); }
        } catch (e) {}
        syncHud();
      }
      for (const w of shopWords) {
        w.position.y = w.userData.baseY + Math.sin(G.time * 1.4 + w.userData.ph) * 0.12;
        w.userData.halo.material.opacity = 0.26 + (Math.sin(G.time * 2.2 + w.userData.ph) + 1) * 0.07;
      }
      if (G.marketCueT > 0) {
        G.marketCueT -= dt;
        if (marketArrow) {
          marketArrow.position.y = 2.1 + Math.sin(G.time * 2.4) * 0.18;
          const pulse = 0.75 + Math.sin(G.time * 5) * 0.25;
          marketArrow.children.forEach((m) => { if (m.material && m.material.emissiveIntensity != null) m.material.emissiveIntensity = pulse; });
        }
        if (G.marketCueT <= 0) G.clearMarketCue();
      }
      if (G.introCelebrateT > 0 && G.introActive) {
        G.introCelebrateT -= dt;
        if (G.introCelebrateT <= 0) {
          G.introCelebrate = null;
          applyIntroPage(G.introCelebrateNext);
          syncHud();
        }
      }
      // guide the eye: bobbing marker over the task target
      {
        const qt = G.introTask;
        let qx = null, qy = 0, qz = 0;
        if (qt && G.map === "HOME") {
          if (qt === "plant") {
            const n = plotNodes.find((nn) => !nn.data().seed);
            if (n) { qx = n.x; qz = n.z; qy = 1.25; }
          } else if (qt === "harvest") {
            const n = plotNodes.find((nn) => nn.data().seed);
            if (n) { qx = n.x; qz = n.z; qy = 1.5; }
          } else if (qt === "feed") {
            if (dragon) { qx = dragon.position.x; qz = dragon.position.z + 0.8; qy = 2.9; }
            else { qx = 0; qz = -9.5; qy = 2.6; }
          }
        }
        if (qx == null) questMarker.visible = false;
        else {
          questMarker.visible = true;
          questMarker.position.set(qx, qy + Math.sin(G.time * 3) * 0.16, qz);
          questMarker.rotation.y = G.time * 1.6;
        }
      }
      // Picnic table by the chapel: the youth group works out what the
      // garden will bring in. Same approach/re-arm shape as the bridge note.
      if (G.map === "CHURCH" && !G.transitioning && !G.quizActive && G.churchIntroPage == null) {
        const td = Math.hypot(playerPos.x - 9, playerPos.z - (-18.6));
        if (td < 3.0 && !G.forecastShown && !shopOpenRef.current) {
          G.forecastShown = true;
          if (G.reqForecast) G.reqForecast(G.forecast24h());
        } else if (td > 4.8 && G.forecastShown) {
          G.forecastShown = false; // re-arm: walking back up asks again
        }
      }
      if (!G.youthGroup && G.map === "HOME" && !G.transitioning && !G.introActive && !G.turtleSeq) {
        const bd = Math.hypot(playerPos.x - (-10.7), playerPos.z - 3);
        if (bd < 2.6 && !G.bridgeNoteShown && !shopOpenRef.current) {
          G.bridgeNoteShown = true;
          if (G.reqBridge) G.reqBridge();
        } else if (bd > 4.2 && G.bridgeNoteShown) {
          G.bridgeNoteShown = false; // re-arm: the note shows again on the next approach
        }
      }
      if (counterKeeper && !G.transitioning) {
        // The keeper stands BEHIND the counter (z -3.6) and its collider stops
        // the player at z ~ -1.3, so dead-centre is already ~2.3 away and any
        // off-centre approach is further. The old 2.35 trigger was therefore
        // unreachable in practice and players had to press the button. Match
        // the hotspot's own reach (r 2.7) with headroom so walking up to any
        // of the three shop counters starts the keeper's dialogue on its own.
        const cdist = Math.hypot(playerPos.x - counterKeeper.x, playerPos.z - counterKeeper.z);
        if (cdist > 4.2) G.counterNear = false; // re-arm once clearly away
        else if (cdist < 3.2 && !G.counterNear && !G.counterActive && !shopOpenRef.current) {
          G.counterNear = true;
          G.startCounter(counterKeeper.kind);
        }
      }
      if (G.exitLatch) {
        let insideAny = false;
        for (const ex of exits) {
          if (Math.hypot(playerPos.x - ex.x, playerPos.z - ex.z) < ex.r + 0.35) { insideAny = true; break; }
        }
        if (!insideAny) G.exitLatch = false;
      } else {
        for (const ex of exits) {
          if (!G.transitioning && !G.turtleSeq && Math.hypot(playerPos.x - ex.x, playerPos.z - ex.z) < ex.r) {
            // Mid-reading: the passage is playing or the question is up. The
            // player can still walk and tend the garden, but leaving the map
            // would tear the audio and the question out from under them, so
            // the exits are shut until they finish or stop.
            if (G.readingLock || G.time < (G.readingGraceUntil || 0)) {
              // Deliberately NOT latched: the exit latch only clears once the
              // player steps clear of every exit, which would strand someone
              // who finished their reading while standing on the road. The
              // nag throttle is what stops the spam instead.
              //
              // The grace window covers the moment the reading ends: without
              // it, tapping Done while stood on the road teleports you on the
              // same frame, which reads as the button doing it.
              if (G.readingLock && G.time - (G.readingNagT || -99) > 4) {
                G.readingNagT = G.time;
                SFX.wrong();
                toast("Finish your reading before leaving home.", "warn");
              }
              break;
            }
            // Crossing the bridge with multiple youth groups → ask which
            // community garden to visit before loading the map.
            if (ex.to === "CHURCH") {
              const memberships = window.YGTEEV?.profile?.memberships || [];
              if (window.YGTEEV_API && memberships.length > 1) {
                G.exitLatch = true; // don't refire while the picker is open
                if (G.reqGardenPick) {
                  G.reqGardenPick(
                    memberships.map((m) => ({ id: m.group_id, name: m.group_name })),
                    ex
                  );
                }
                break;
              }
            }
            G.transitioning = true;
            G.pendingMap = { to: ex.to, spawn: ex.spawn };
            const tLabel = ex.to === "CHURCH" && G.activeGarden
              ? "⛪ " + G.activeGarden.name
              : (MAP_LABELS[ex.to] || ex.to);
            if (G.reqTransition) G.reqTransition(tLabel);
            break;
          }
        }
      }

      // Auto-equip by location at home: inside the fence you're a planter
      // (lowest seed you own), outside you're headed for Ember (lowest fruit).
      // Runs during onboarding too — Eli's first tasks are "plant a seed" and
      // "throw Ember a fruit", which is exactly what this picks for you, and
      // while a dialogue box is up the player can't move so nothing shifts.
      if (G.map === "HOME") {
        const FT2 = FENCE_TIERS[G.build.fenceTier];
        const inside = playerPos.x > FT2.x1 - 0.4 && playerPos.x < FT2.x2 + 0.4
                    && playerPos.z > FT2.z1 - 0.4 && playerPos.z < FT2.z2 + 0.4;
        if (inside !== G.__fenceIn) {
          G.__fenceIn = inside;
          if (inside) {
            G.selectSeed(["strawberry", "blueberry", "sunfruit"].find((k) => G.inv.seeds[k] > 0) || "strawberry");
          } else {
            G.selectFruit(["strawberry", "blueberry", "sunfruit", "glowberry", "starberry", "dawnberry", "gloryberry"].find((k) => G.inv.fruit[k] > 0) || "strawberry");
          }
          syncHud();
        }
      }

      // hold-to-rush: complete the purchase when the hold fills
      if (rushHold) {
        const rn = plotNodes.find((n) => !n.special && n.idx === rushHold.idx && n.arr === G.homePlots);
        const rp = rn && rn.data();
        if (!rn || !rp || !rp.seed || rp.regrowAt == null || G.time >= rp.regrowAt) rushHold = null;
        else if ((performance.now() - rushHold.t0) / 1000 >= 0.9) {
          const left = Math.max(0, rp.regrowAt - G.time);
          const cost = Math.max(1, Math.ceil(left / 10));
          if (G.xp >= cost) {
            G.xp -= cost;
            rp.regrowAt = G.time; // ripens on this very tick
            SFX.sparkle();
            spawnBurst(rn.x, rn.z, 0xffd45e, 9, { glow: true, vy: 2.4, y0: 0.7 });
            spawnFloatie(rn.x, rn.z, `-${cost} ✦`, 1.4);
          } else {
            SFX.wrong();
            toast("Not enough XP to hurry the harvest.", "warn");
          }
          tap.moved = true; // eat the release so onTapUp doesn't double-act
          rushHold = null;
          syncHud();
        }
      }
      for (const node of plotNodes) {
        const p = node.data();
        if (!p.seed) { if (node.regrowSprite) updateRegrowBadge(node, p, -1); if (node.growRing) updateGrowRing(node, p, -1); continue; }
        if (node.special) {
          const age = G.time - p.plantedAt;
          const st = age >= 300 ? 3 : age >= 150 ? 2 : age >= 60 ? 1 : 0;
          if (st !== node.stage) refreshPlotVisual(node);
          updateGlowBadge(node, p, age);
          if (node.plant) {
            node.plant.rotation.y = Math.sin(G.time * 0.8 + node.idx) * 0.05;
            const ud = node.plant.userData || {};
            if (ud.berryMat) ud.berryMat.emissiveIntensity = 1.3 + Math.sin(G.time * 2.5 + node.idx) * 0.5;
            if (ud.halo) ud.halo.material.opacity = 0.32 + Math.sin(G.time * 1.7 + node.idx) * 0.14;
          }
        } else {
          const elapsed = G.time - p.plantedAt;
          const total = SEEDS[p.seed].grow;
          const stage = p.regrowAt != null ? (G.time >= p.regrowAt ? 2 : 1)
            : elapsed >= total ? 2 : elapsed >= total * 0.5 ? 1 : 0;
          if (stage !== node.stage) refreshPlotVisual(node);
          if (node.plant && stage === 2) node.plant.rotation.y = Math.sin(G.time * 1.5 + node.idx) * 0.08;
          updateRegrowBadge(node, p, stage);
          updateGrowRing(node, p, stage);
        }
      }

      // The title splash is a "paused" world: Ember neither gets hungrier nor
      // raids the garden while the player is still in the menu. Eli's
      // onboarding (home intro or church welcome) pauses the clock too —
      // a new player shouldn't be punished for listening.
      if (!G.splashActive && !G.introActive && G.churchIntroPage == null) {
        G.hunger = Math.max(0, G.hunger - G.hungerRate * dt);
        if (G.hungerAlertT > 0) G.hungerAlertT -= dt;
        // The hangry plaque is a nag, not furniture: an empty meter used to
        // pin it on screen indefinitely (dragonState stays non-idle while he
        // prowls). Give it a minute, then let it go — feeding him, or any
        // fresh alert, brings it straight back.
        if (G.dragonState !== "idle" || G.hunger < 32) G.hungerPlaqueT += dt;
        else G.hungerPlaqueT = 0;
        if (G.emberHappyT > 0) G.emberHappyT = Math.max(0, G.emberHappyT - dt);
        if (G.hunger <= 0 && G.dragonState === "idle") {
          // let the EMPTY meter register before he charges — no surprise rampages
          G.zeroHoldT = (G.zeroHoldT || 0) + dt;
          if (G.zeroHoldT > 0.6) { G.zeroHoldT = 0; triggerRampage(); }
        } else if (G.hunger > 0) G.zeroHoldT = 0;
      }
      updateDragon(dt);
      // snoring fades in as you approach a sleeping Ember (like the fountain)
      if (snoreGain) {
        let st = 0;
        if (dragon && G.map === "HOME" && G.dragonState === "idle") {
          const sd = Math.hypot(playerPos.x - dragon.position.x, playerPos.z - dragon.position.z);
          st = G.sleepBlend * Math.max(0, 1 - sd / 13) * 0.55;
        }
        snoreGain.gain.value += (st - snoreGain.gain.value) * Math.min(1, dt * 4);
      }

      windT.value = G.time;
      for (const swn of swayers) {
        swn.g.rotation.z = Math.sin(G.time * 1.15 + swn.ph) * 0.02 * swn.amp;
        swn.g.rotation.x = Math.cos(G.time * 0.9 + swn.ph) * 0.014 * swn.amp;
      }
      for (const pt of petals) {
        const pd = pt.userData;
        const cyc = (G.time * pd.sp + pd.ph) % 1;
        pt.position.set(
          pd.sx + Math.sin(G.time * 0.8 + pd.ph * 7) * 1.1 + cyc * 2.4,
          pd.gy + 0.15 + pd.h * (1 - cyc),
          pd.sz + Math.cos(G.time * 0.6 + pd.ph * 5) * 0.9
        );
        pt.rotation.x = G.time * 1.5 + pd.ph;
        pt.rotation.y = G.time * 1.1 + pd.ph * 2;
      }
      for (const b of butterflies) {
        const d = b.userData;
        b.position.set(
          d.cx + Math.cos(G.time * 0.6 + d.ph) * d.r,
          1.2 + Math.sin(G.time * 2.4 + d.ph) * 0.35,
          d.cz + Math.sin(G.time * 0.5 + d.ph) * d.r
        );
        b.rotation.z = Math.sin(G.time * 14 + d.ph) * 0.6;
      }
      for (const gl of glowNodes) gl.material.emissiveIntensity = 1 + Math.sin(G.time * 3 + gl.position.x) * 0.3;
      for (const c of clouds) {
        c.position.x += c.userData.speed * dt;
        if (c.position.x > 65) c.position.x = -65;
      }
      if (water) {
        const wp = water.geometry.attributes.position;
        for (const [ii, wz, lat] of water.userData.verts)
          wp.setY(ii, Math.sin(wz * 0.6 + G.time * 2.2 + lat * 1.3) * 0.045);
        wp.needsUpdate = true;
      }
      if (riverFoam) {
        for (let fi = 0; fi < foams.length; fi++) {
          const fd = foams[fi];
          fd.z += fd.sp * dt;
          if (fd.z > 38) fd.z = -38;
          instDummy.position.set(RIVER_X(fd.z) + fd.off * 0.7, -0.1 + Math.sin(G.time * 3 + fd.z) * 0.03, fd.z);
          // everything follows the local flow tangent; drifting glints add only a small
          // per-glint offset + slow wobble on top (no more perpendicular lane markers)
          const tang = Math.atan(0.288 * Math.cos(fd.z * 0.18));
          const fry = fd.hug ? tang
            : fd.anch ? fd.ry : tang + fd.ry * 0.6 + Math.sin(G.time * 0.8 + fi) * 0.14;
          instDummy.rotation.set(0, fry, 0);
          instDummy.scale.set(fd.w || 1, 1, fd.ln);
          instDummy.updateMatrix();
          riverFoam.setMatrixAt(fi, instDummy.matrix);
        }
        riverFoam.instanceMatrix.needsUpdate = true;
      }
      if (ghostMesh) {
        const bActive = G.buildActive && G.map === "HOME";
        ghostMesh.visible = false;
        if (buildMarkers) {
          buildMarkers.visible = bActive;
          if (bActive) buildMarkers.material.opacity = 0.13 + Math.sin(G.time * 3) * 0.05;
        }
        G.ghostCell = null; G.ghostOk = false;
        if (bActive) {
          let best = null, bd = 5.4;
          for (const c of buildCells) {
            if (c.taken) continue;
            const d = Math.hypot(playerPos.x - c.x, playerPos.z - c.z);
            if (d < bd) { bd = d; best = c; }
          }
          if (best) {
            G.ghostCell = best;
            const afford = G.xp >= kitCostAt(G.build.kitsBought);
            G.ghostOk = afford;
            ghostMesh.visible = true;
            ghostMesh.position.set(best.x, 0.02 + Math.sin(G.time * 4) * 0.02, best.z);
            const gc = afford ? SRGB(0x6ee87a) : SRGB(0xe86a5a);
            ghostMesh.userData.gRim.material.emissive.copy(gc);
            ghostMesh.userData.gSoil.material.emissive.copy(gc);
          }
        }
      }
      if (fountainFx) {
        const F = fountainFx;
        const dp = F.drops.geometry.attributes.position;
        for (let di = 0; di < F.dropData.length; di++) {
          const dd = F.dropData[di];
          dd.t += dt;
          let px = F.cx + dd.vx * dd.t;
          let py = 1.5 + dd.vy * dd.t - 5.5 * dd.t * dd.t;
          let pz = F.cz + dd.vz * dd.t;
          if (dd.t > dd.life || py < 0.62) {
            dd.t = 0;
            dd.life = 0.5 + Math.random() * 0.3;
            const ang = Math.random() * Math.PI * 2;
            const spd = 0.3 + Math.random() * 0.8;
            dd.vx = Math.cos(ang) * spd;
            dd.vz = Math.sin(ang) * spd;
            dd.vy = 2.3 + Math.random() * 1.2;
            px = F.cx; py = 1.5; pz = F.cz;
          }
          dp.setXYZ(di, px, py, pz);
        }
        dp.needsUpdate = true;
        F.jet.scale.set(1 + Math.sin(G.time * 13) * 0.12, 1 + Math.sin(G.time * 9) * 0.08, 1 + Math.cos(G.time * 11) * 0.12);
        const rpp = F.ripple.geometry.attributes.position;
        for (let ri = 0; ri < F.ripBase.length; ri++)
          rpp.setY(ri, Math.sin(F.ripBase[ri] * 7 - G.time * 5) * 0.02);
        rpp.needsUpdate = true;
        for (const rg of F.rings) {
          const rd = rg.userData;
          const cyc = (G.time * 0.85 + rd.ph) % 1;
          if (cyc < rd.prev) {
            const a = Math.random() * Math.PI * 2, rr = 0.35 + Math.random() * 0.8;
            rd.lx = Math.cos(a) * rr; rd.lz = Math.sin(a) * rr;
            rd.br = 0.7 + Math.random() * 0.6;
          }
          rd.prev = cyc;
          const rsc = (0.25 + cyc * 0.95) * rd.br;
          rg.scale.set(rsc, rsc, 1);
          rg.position.set(F.cx + rd.lx, 0.63, F.cz + rd.lz);
          rg.material.opacity = (1 - cyc) * 0.5;
        }
        if (fountainGain) {
          const fdist = Math.hypot(playerPos.x - F.cx, playerPos.z - F.cz);
          const ftgt = Math.max(0, 1 - fdist / 10) * 0.22;
          fountainGain.gain.value += (ftgt - fountainGain.gain.value) * Math.min(1, dt * 6);
        }
      } else if (fountainGain) {
        fountainGain.gain.value += (0 - fountainGain.gain.value) * Math.min(1, dt * 6);
      }
      for (const em of embers) {
        const d = em.userData;
        const cyc = (G.time * d.sp + d.ph) % 1;
        em.position.set(d.x + Math.sin(G.time * 2 + d.ph) * 0.3, 0.6 + cyc * 3.2, -12.2 - cyc * 1.8);
        em.material.opacity = 1 - cyc;
        em.material.transparent = true;
      }
      for (const puff of smokes) {
        const d = puff.userData;
        const cyc = (G.time * 0.22 + d.ph) % 1;
        puff.position.set(d.lx + Math.sin(G.time * 0.8 + d.ph * 9) * 0.25 + cyc * 0.5, d.ly + cyc * 2.6, d.lz);
        const sc = 0.5 + cyc * 1.3;
        puff.scale.set(sc, sc * 0.8, sc);
        puff.material.opacity = 0.65 * (1 - cyc);
      }
      for (const n of npcs) {
        if (n.type === "walk" && n.walk) {
          n.wt = (n.wt + dt * n.walk.speed) % 2;
          const tt = n.wt < 1 ? n.wt : 2 - n.wt;
          const wx = n.walk.a[0] + (n.walk.b[0] - n.walk.a[0]) * tt;
          const wz = n.walk.a[1] + (n.walk.b[1] - n.walk.a[1]) * tt;
          const dirS = n.wt < 1 ? 1 : -1;
          n.g.position.set(wx, Math.abs(Math.sin(G.time * 8 + n.ph)) * 0.045, wz);
          n.g.rotation.y = Math.atan2((n.walk.b[0] - n.walk.a[0]) * dirS, (n.walk.b[1] - n.walk.a[1]) * dirS);
        } else {
          n.g.position.y = Math.abs(Math.sin(G.time * 1.7 + n.ph)) * 0.035;
          n.g.rotation.y = n.baseRot + Math.sin(G.time * 0.5 + n.ph) * 0.12;
        }
      }
      for (const sp of zzz) {
        const cyc = (G.time * 0.35 + sp.userData.ph) % 1;
        const vis = Math.max(0, G.sleepBlend - 0.5) * 2;
        if (dragon) sp.position.set(dragon.position.x + 0.55 + cyc * 0.5, 1.15 + cyc * 1.5, dragon.position.z + 0.55);
        const zs = 0.28 + cyc * 0.42;
        sp.scale.set(zs, zs, 1);
        sp.material.opacity = (1 - cyc) * 0.9 * vis;
      }
      if (timerSprite) {
        const secLeft = Math.max(0, Math.floor((G.week.endMs - Date.now()) / 1000));
        if (secLeft !== lastTimerSec) {
          lastTimerSec = secLeft;
          const dd = Math.floor(secLeft / 86400);
          const hh = String(Math.floor((secLeft % 86400) / 3600)).padStart(2, "0");
          const mm = String(Math.floor((secLeft % 3600) / 60)).padStart(2, "0");
          const ss = String(secLeft % 60).padStart(2, "0");
          drawLeagueTimer(`${dd}d ${hh}:${mm}:${ss}`);
        }
        timerSprite.position.y = 3.55 + Math.sin(G.time * 1.4) * 0.07;
      }
      if (winsSprite) {
        const w = G.pulse && typeof G.pulse.league_wins === "number" ? G.pulse.league_wins : 0;
        if (w !== lastWinsDrawn) { lastWinsDrawn = w; drawWins(w); }
        winsSprite.position.y = 4.85 + Math.sin(G.time * 1.4 + 0.9) * 0.08;
        const wp2 = 1 + Math.sin(G.time * 2.6) * 0.015;
        winsSprite.scale.set(3.6 * wp2, 1.2 * wp2, 1);
      }
      if (caveLight) caveLight.intensity = 1.0 + Math.sin(G.time * 7) * 0.2 + Math.sin(G.time * 13.7) * 0.12;
      if (goldBag) {
        goldBag.userData.glow.material.opacity = 0.42 + Math.sin(G.time * 2.6) * 0.2;
        goldBag.rotation.y = Math.sin(G.time * 0.9) * 0.12;
        goldBag.userData.mark.position.y = 1.0 + Math.sin(G.time * 2.2) * 0.09;
      }
      for (const rk in redBagMeshes) {
        const m = redBagMeshes[rk];
        m.userData.glow.material.opacity = 0.3 + Math.sin(G.time * 2.2 + m.position.x) * 0.14;
        m.userData.mark.position.y = 0.92 + Math.sin(G.time * 2.0 + m.position.z) * 0.08;
      }
      if (sparkles) {
        sparkles.rotation.y = G.time * 0.08;
        sparkles.position.y = Math.sin(G.time * 1.2) * 0.15;
      }

      currentPrompt = null; promptText = "";
      let best = 2.4, ringTarget = null;
      for (const node of plotNodes) {
        const d = Math.hypot(playerPos.x - node.x, playerPos.z - node.z);
        if (d < best) {
          const p = node.data();
          if (!p.seed) {
            currentPrompt = { type: "plant", node };
            promptText = node.special ? `Plant ${SEEDS[G.selectedSeed].name} in glowing plot ✨` : `Plant ${SEEDS[G.selectedSeed].name}`;
            ringTarget = node;
          } else if (node.special) {
            const age = G.time - p.plantedAt;
            if (age < 300) {
              promptText = `🌱 ${SEEDS[p.seed].name} sapling — matures in ${Math.ceil(300 - age)}s`;
            } else {
              const yi = SEEDS[p.seed]?.yieldInt || 300;
              const nextIn = Math.max(0, Math.ceil((p.nextYield != null ? p.nextYield : p.plantedAt + 300 + yi) - G.time));
              const lifeLeft = Math.max(0, p.plantedAt + 300 + 86400 - G.time);
              promptText = `🌟 ${SEEDS[p.seed].name} tree — berry in ${nextIn}s · ${Math.floor(lifeLeft / 3600)}h ${Math.floor((lifeLeft % 3600) / 60)}m left`;
            }
            ringTarget = null;
          } else if (node.stage === 2) {
            currentPrompt = { type: "harvest", node };
            promptText = `Harvest ${SEEDS[p.seed].name}!`;
            ringTarget = node;
          } else if (p.regrowAt != null) {
            const left = Math.max(0, Math.ceil(p.regrowAt - G.time));
            promptText = `${SEEDS[p.seed].name} regrowing… next fruit in ${Math.floor(left / 60)}:${String(left % 60).padStart(2, "0")}`;
            ringTarget = null;
          } else {
            promptText = `${SEEDS[p.seed].name} growing… ${Math.max(0, Math.ceil(SEEDS[p.seed].grow - (G.time - p.plantedAt)))}s`;
            ringTarget = null;
          }
          best = d;
        }
      }
      for (const h of hotspots) {
        let hx = h.x, hz = h.z;
        if (h.type === "dragon" && G.dragonState !== "idle") {
          // he's out of the cave — the feed prompt follows him while he
          // prowls; while he's charging or running home he can't be fed
          if (G.dragonState !== "prowl" || !dragon) continue;
          hx = dragon.position.x; hz = dragon.position.z;
        }
        const d = Math.hypot(playerPos.x - hx, playerPos.z - hz);
        if (d < h.r && d < best + 1) {
          currentPrompt = { type: h.type, kind: h.kind, bagIdx: h.bagIdx };
          promptText = h.type === "dragon" && G.dragonState === "prowl"
            ? "Ember is hangry — offer him a berry!"
            : h.type === "dragon" && G.sleepBlend > 0.6 ? "Ember is asleep 💤 — feed him a snack?" : h.label;
          ringTarget = null;
        }
      }
      // Glowlands proximity triggers (prologue nodes, library desk, road sites)
      for (const t of glowTriggers) {
        const d = Math.hypot(playerPos.x - t.x, playerPos.z - t.z);
        if (d < (t.r || 2.2) && d < best + 1) {
          best = d;
          currentPrompt = { type: "glow", glow: t };
          promptText = t.label || t.prompt || "Take a look";
          ringTarget = null;
        }
      }
      if (ringTarget) {
        ring.visible = true;
        ring.position.set(ringTarget.x, 0.14, ringTarget.z);
        const pulse = (1 + Math.sin(G.time * 5) * 0.06) * (ringTarget.special ? 0.55 : 1);
        ring.scale.set(pulse, pulse, 1);
      } else ring.visible = false;

      let camTarget, lookX, lookZ, lookY;
      if (G.splashActive) {
        // Title-splash vantage: high three-quarter view of the player's own
        // garden with a slow lateral drift so the world reads alive behind
        // the menu. Dismissal simply falls through to the home framing and
        // the position lerp performs the fly-in.
        const zoomK = H() > W() ? 1.18 : 1.0;
        const sway = Math.sin(G.time * 0.14) * 1.3;
        camTarget = new THREE.Vector3(
          playerPos.x + 6.5 * zoomK + sway,
          13.2 * zoomK + groundY * 0.5,
          playerPos.z + 14.5 * zoomK
        );
        lookX = playerPos.x - 1.0; lookZ = playerPos.z - 2.0; lookY = groundY + 1.0;
      } else if (G.quizActive && gardener) {
        // cinematic pull-in on Old Eli during his quiz
        const fx = (playerPos.x + gardener.position.x) / 2;
        const fz = (playerPos.z + gardener.position.z) / 2;
        camTarget = new THREE.Vector3(fx + 2.0, 2.8, fz + 4.2);
        lookX = gardener.position.x; lookZ = gardener.position.z; lookY = 1.05;
      } else if (G.introFocus === "cave") {
        // pulled back + aimed at the ground in front of the cave, so Ember
        // lands in the upper band, clear of the (taller) dialogue box
        camTarget = new THREE.Vector3(playerPos.x * 0.3 + 2, 6.6, 0.8);
        lookX = 0; lookZ = -9.0; lookY = 0.1;
      } else if (G.introFocus === "bridge") {
        camTarget = new THREE.Vector3(-6.2, 5.4, 9.2);
        lookX = -13.2; lookZ = 3; lookY = 0.2;
      } else if (G.introFocus === "eli" && gardener) {
        const imx = (playerPos.x + gardener.position.x) / 2;
        const imz = (playerPos.z + gardener.position.z) / 2;
        camTarget = new THREE.Vector3(imx + 1.4, 3.3, imz + 4.6);
        lookX = gardener.position.x; lookZ = gardener.position.z; lookY = 0.45;
      } else if (G.counterActive && counterKeeper) {
        const cmx = (playerPos.x + counterKeeper.x) / 2;
        const cmz = (playerPos.z + counterKeeper.z) / 2;
        camTarget = new THREE.Vector3(cmx + 1.5, 3.3, cmz + 4.4);
        lookX = counterKeeper.x; lookZ = counterKeeper.z; lookY = 1.05;
      } else if (G.marketCueT > 0 && G.map === "HOME") {
        // Berry Market cue: the floating arrow dead-centre, road running
        // off toward the town exit on the right
        camTarget = new THREE.Vector3(10.5, 4.8, 10.2);
        lookX = 13.5; lookZ = 3.4; lookY = 1.1;
      } else if (G.styleActive) {
        // Wardrobe framing: the sheet is a bottom panel covering the lower
        // ~45%, so pull back far enough to fit the WHOLE body (boots included)
        // and aim near the feet, which pushes the character up into the
        // visible band above the panel.
        camTarget = new THREE.Vector3(playerPos.x + 0.4, groundY + 1.38, playerPos.z + 5.10);
        lookX = playerPos.x; lookZ = playerPos.z; lookY = groundY - 0.10;
      } else {
        // Portrait (mobile) pulls the camera back ~22% — the default framing
        // reads too tight on phones.
        const zoomK = H() > W() ? 1.22 : 1.0;
        // pitch lifted a few degrees vs the old (8.2, +1.2) framing so the fogged
        // distance / tree line enters the top of hero shots (aerial perspective read)
        // look target raised (1.75 -> 3.55): tilts the frame up so the horizon,
        // backdrop mountains, and a band of sky enter the top of every shot.
        // With the old 1.75 the top frustum edge sat 9° BELOW horizontal — the
        // backdrop could mathematically never appear on screen.
        camTarget = new THREE.Vector3(playerPos.x, (7.8 + groundY * 0.55) * zoomK, playerPos.z + 9.6 * zoomK);
        lookX = playerPos.x; lookZ = playerPos.z; lookY = groundY + 3.55;
      }
      camera.position.lerp(camTarget, G.splashActive || G.quizActive || G.styleActive || G.counterActive || G.introFocus ? 0.06 : 0.08);
      if (G.shakeT > 0) {
        G.shakeT -= dt;
        lookX += (Math.random() - 0.5) * 0.5;
        lookZ += (Math.random() - 0.5) * 0.5;
      }
      camera.lookAt(lookX, lookY, lookZ);
      sky.position.set(playerPos.x, 0, playerPos.z);
      // follow the player but keep the brief's lower golden-hour sun angle (16,17,9)
      sun.position.set(playerPos.x + 16, 17, playerPos.z + 9);
      sun.target.position.set(playerPos.x, 0, playerPos.z);
      sun.target.updateMatrixWorld();

      // gardener Eli behaviour
      if (gardener) {
        if (gardenerCtl.mode === "approach") {
          const adx = playerPos.x - gardener.position.x, adz = playerPos.z - gardener.position.z;
          const ad = Math.hypot(adx, adz);
          if (ad < 1.9) {
            gardenerCtl.mode = "greet";
            gardener.rotation.y = Math.atan2(adx, adz);
            gardener.position.y = terrainY(gardener.position.x, gardener.position.z);
            playerAngle = Math.atan2(gardener.position.x - playerPos.x, gardener.position.z - playerPos.z);
            player.rotation.y = playerAngle;
            if (!gardenerCtl.announced) {
              gardenerCtl.announced = true;
              if (gardenerCtl.church) G.churchStartPage(0);
              else { applyIntroPage(0); syncHud(); }
            }
          } else {
            gardener.position.x += (adx / ad) * dt * 2.0;
            gardener.position.z += (adz / ad) * dt * 2.0;
            gardener.rotation.y = Math.atan2(adx, adz);
            gardener.position.y = terrainY(gardener.position.x, gardener.position.z) + Math.abs(Math.sin(G.time * 8)) * 0.05;
          }
        } else if (gardenerCtl.mode === "leave") {
          gardenerCtl.t += dt;
          if (gardenerCtl.t > 16) { worldGroup.remove(gardener); gardener = null; G.introLock = false; }
          else {
          const wp = gardenerCtl.leavePath[gardenerCtl.leaveIdx];
          const ldx = wp[0] - gardener.position.x, ldz = wp[1] - gardener.position.z;
          const ld = Math.hypot(ldx, ldz);
          if (ld < 0.7) {
            gardenerCtl.leaveIdx++;
            if (gardenerCtl.leaveIdx >= gardenerCtl.leavePath.length) {
              spawnBurst(gardener.position.x, gardener.position.z, 0xbfe8ff, 10, { glow: true, vy: 2.2, spread: 0.7, y0: 1 });
              SFX.sparkle();
              worldGroup.remove(gardener); gardener = null;
              G.introLock = false; // he's gone — the backyard is yours
            }
          } else {
            gardener.position.x += (ldx / ld) * dt * 2.3;
            gardener.position.z += (ldz / ld) * dt * 2.3;
            gardener.rotation.y = Math.atan2(ldx, ldz);
            gardener.position.y = terrainY(gardener.position.x, gardener.position.z) + Math.abs(Math.sin(G.time * 8)) * 0.05;
          }
          }
        } else if (gardenerCtl.mode === "greet") {
          gardener.position.y = Math.abs(Math.sin(G.time * 2.2)) * 0.04;
        } else if (gardenerCtl.mode === "return") {
          const gdx = gardenerCtl.post[0] - gardener.position.x, gdz = gardenerCtl.post[1] - gardener.position.z;
          const gd = Math.hypot(gdx, gdz);
          if (gd < 0.2) { gardenerCtl.mode = "post"; gardener.rotation.y = gardenerCtl.postRot; }
          else {
            gardener.position.x += (gdx / gd) * dt * 2.2;
            gardener.position.z += (gdz / gd) * dt * 2.2;
            gardener.rotation.y = Math.atan2(gdx, gdz);
            gardener.position.y = Math.abs(Math.sin(G.time * 9)) * 0.05;
          }
        } else if (gardenerCtl.mode === "flee") {
          gardenerCtl.t += dt;
          const fdx = -32 - gardener.position.x, fdz = -18 - gardener.position.z;
          const fd = Math.hypot(fdx, fdz);
          if (fd < 1.2 || gardenerCtl.t > 6) { gardener.visible = false; gardenerCtl.mode = "hidden"; gardenerCtl.t = 0; }
          else {
            gardener.position.x += (fdx / fd) * dt * 5.4;
            gardener.position.z += (fdz / fd) * dt * 5.4;
            gardener.rotation.y = Math.atan2(fdx, fdz);
            gardener.position.y = Math.abs(Math.sin(G.time * 12)) * 0.09;
          }
        } else if (gardenerCtl.mode === "hidden") {
          gardenerCtl.t += dt;
          if (gardenerCtl.t > 5) {
            gardener.visible = true;
            gardener.position.set(gardenerCtl.post[0], 0, gardenerCtl.post[1]);
            gardener.rotation.y = gardenerCtl.postRot;
            gardenerCtl.mode = "post";
          }
        } else {
          gardener.position.y = Math.abs(Math.sin(G.time * 1.5)) * 0.03;
          // Idle banter: wander close while he's just standing at his post and
          // he mutters a dry one-liner. Latched on approach (re-arms once you
          // walk off) and cooled down so he can't natter over himself.
          if (G.eliQuipCd > 0) G.eliQuipCd -= dt;
          if (gardenerCtl.mode === "post" && !G.quizActive && G.churchIntroPage == null
              && !G.introLock && !shopOpenRef.current) {
            const qd = Math.hypot(playerPos.x - gardener.position.x, playerPos.z - gardener.position.z);
            if (qd > 4.6) G.eliQuipNear = false;              // re-arm on the way out
            else if (qd < 2.8 && !G.eliQuipNear && G.eliQuipCd <= 0) {
              G.eliQuipNear = true;
              G.eliQuipCd = 12;
              // shuffle-bag: exhaust all 12 before any repeats
              if (!G.eliQuipBag.length) {
                G.eliQuipBag = ELI_QUIPS.map((_, i2) => i2);
                for (let i2 = G.eliQuipBag.length - 1; i2 > 0; i2--) {
                  const j2 = Math.floor(Math.random() * (i2 + 1));
                  [G.eliQuipBag[i2], G.eliQuipBag[j2]] = [G.eliQuipBag[j2], G.eliQuipBag[i2]];
                }
              }
              const qi = G.eliQuipBag.pop();
              gardener.rotation.y = Math.atan2(playerPos.x - gardener.position.x, playerPos.z - gardener.position.z);
              toast(`🧓 "${ELI_QUIPS[qi]}"`, "info");
              playVoiceFile(`voices/eli-quip-${qi + 1}.mp3`);
            }
          }
        }
      }
      // glowberry burst particles
      for (let ti = throwns.length - 1; ti >= 0; ti--) {
        const tp = throwns[ti];
        tp.t += dt;
        const u = Math.min(1, tp.t / tp.dur);
        tp.m.position.x = tp.x0 + (tp.x1 - tp.x0) * u;
        tp.m.position.z = tp.z0 + (tp.z1 - tp.z0) * u;
        // parabolic lob
        tp.m.position.y = tp.y0 + (tp.y1 - tp.y0) * u + Math.sin(u * Math.PI) * 1.5;
        tp.m.rotation.x += tp.spin * dt;
        tp.m.rotation.y += tp.spin * 0.7 * dt;
        if (u >= 1) {
          worldGroup.remove(tp.m);
          throwns.splice(ti, 1);
          try { tp.onLand && tp.onLand(); } catch (e) {}
        }
      }
      for (let bi = bursts.length - 1; bi >= 0; bi--) {
        const bst = bursts[bi];
        bst.ttl -= dt;
        bst.m.position.x += bst.vx * dt; bst.m.position.y += bst.vy * dt; bst.m.position.z += bst.vz * dt;
        bst.vy -= 4 * dt;
        bst.m.scale.setScalar(Math.max(0.01, bst.ttl));
        if (bst.ttl <= 0) { worldGroup.remove(bst.m); bursts.splice(bi, 1); }
      }
      // rising "+2 🍓" plot floaties
      for (let fi = floaties.length - 1; fi >= 0; fi--) {
        const fl = floaties[fi];
        fl.ttl -= dt;
        fl.age = (fl.age || 0) + dt;
        // overshoot pop: 0 -> 1.18 -> 1.0 over the first ~0.28s
        const k = fl.age < 0.16 ? (fl.age / 0.16) * 1.18 : fl.age < 0.3 ? 1.18 - ((fl.age - 0.16) / 0.14) * 0.18 : 1;
        if (fl.bw) fl.sp.scale.set(fl.bw * k, fl.bh * k, 1);
        fl.sp.position.y += dt * (fl.age < 0.3 ? 0.25 : (fl.slow ? 0.34 : 0.8));
        fl.sp.material.opacity = Math.min(1, fl.ttl / 0.5);
        if (fl.ttl <= 0) {
          worldGroup.remove(fl.sp);
          fl.sp.material.map.dispose(); fl.sp.material.dispose();
          floaties.splice(fi, 1);
        }
      }
      // glow trees: mature at 5 min, then fruit on their tier's interval
      // (glowberry 5m, starberry 2.5m, dawnberry 100s, gloryberry 75s),
      // fade after 24 hours
      for (let ci = 0; ci < G.churchPlots.length; ci++) {
        const cp = G.churchPlots[ci];
        if (!cp.seed) continue;
        const age = G.time - cp.plantedAt;
        const MAT = 300, LIFE = 86400;
        const yi = SEEDS[cp.seed]?.yieldInt || 300;
        if (age >= MAT + LIFE) { expireGlowTree(ci); continue; }
        if (age >= MAT) {
          if (cp.nextYield == null) {
            // Start at the NEXT tick, never at maturity. Every berry a tree
            // dropped before we loaded it was already credited by the server
            // cron; replaying that history here double-counted it into the
            // optimistic header (a day-old gloryberry replayed ~1,150).
            const since = Math.max(0, G.time - (cp.plantedAt + MAT));
            cp.nextYield = cp.plantedAt + MAT + (Math.floor(since / yi) + 1) * yi;
          }
          // a long frame or a map load must not dump a burst of berries either
          let guard = 6;
          while (G.time >= cp.nextYield) {
            if (guard-- <= 0) { cp.nextYield = G.time + yi; break; }
            yieldGlowBerry(ci);
            cp.nextYield += yi;
          }
        }
      }
      // rival gardens keep producing; the week rolls over Sunday night
      for (const rv of G.week.rivals) {
        rv.acc += (rv.rate / 3600) * dt * (0.85 + 0.3 * Math.sin(G.time * 0.01 + rv.rate));
        if (rv.acc >= 1) { rv.berries += Math.floor(rv.acc); rv.acc %= 1; }
      }
      if (Date.now() > G.week.endMs) {
        const standings = [{ name: G.week.myName || "Grace Community Garden", berries: G.week.mine + (G.week.pending || 0) }, ...G.week.rivals]
          .sort((a, b) => b.berries - a.berries);
        toast(`🏆 Week over! ${standings[0].name} wins with ${standings[0].berries} berries!`, "level");
        Object.assign(G.week, computeWeek());
        saveWeek();
      }
      if (G.saveT > 0) { G.saveT -= dt; if (G.saveT <= 0) saveWeek(); }
      if (stateLoaded && G.time - lastStateCheck > 4) {
        lastStateCheck = G.time;
        const sig = stateSig();
        if (sig !== lastStateSig) { lastStateSig = sig; saveState(); }
      }

      hudTick += dt;
      if (hudTick > 0.15) { hudTick = 0; syncHud(); }

      renderer.render(scene, camera);
    }
    animate();

    const onResize = () => {
      camera.aspect = W() / H();
      camera.updateProjectionMatrix();
      renderer.setSize(W(), H());
    };
    window.addEventListener("resize", onResize);
    // Full-resolution switch, called when the title splash is dismissed.
    G.restoreRes = () => {
      renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
      onResize();
    };

    return () => {
      cancelAnimationFrame(raf);
      clearTimeout(introTimer);
      window.removeEventListener("keydown", kd);
      window.removeEventListener("keyup", ku);
      window.removeEventListener("resize", onResize);
      mount.removeEventListener("touchstart", onTouchStart);
      mount.removeEventListener("touchmove", onTouchMove);
      mount.removeEventListener("touchend", onTouchEnd);
      mount.removeEventListener("pointerdown", onTapDown);
      mount.removeEventListener("pointermove", onTapMove);
      mount.removeEventListener("pointerup", onTapUp);
      window.removeEventListener("pointerdown", unlockAudio);
      window.removeEventListener("pointerup", unlockAudio);
      window.removeEventListener("keydown", unlockAudio);
      document.removeEventListener("visibilitychange", onVisFlush);
      window.removeEventListener("pagehide", flushState);
      flushState();
      leaveLiveGarden();
      if (window.__BY_KEEPER) window.__BY_KEEPER.pause();
      if (AC) { try { AC.close(); } catch (e) {} }
      renderer.dispose();
      if (renderer.domElement.parentNode) renderer.domElement.parentNode.removeChild(renderer.domElement);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []); // scene boots once on mount; splash dismissal must NOT rebuild the engine

  const shopOpenRef = useRef(false);
  useEffect(() => { shopOpenRef.current = !started || !!shop || !!quiz || !!mapFx || !!counterTalk || introDlg || bridgeTalk || !!goldBagStep || !!redBag || !!seedGift || churchIntro != null || board; }, [started, shop, quiz, mapFx, counterTalk, introDlg, bridgeTalk, goldBagStep, redBag, seedGift, churchIntro, board]);
  useEffect(() => { const g = gameRef.current; if (g) g.styleActive = shop === "style"; }, [shop]);
  // pre-warm the big painted shop boards so their first open doesn't flash
  useEffect(() => {
    if (!started) return;
    ["rosie-rare-v3.png", "toolworks-v2.png", "market-v2.png", "market-sell-bar.png"]
      .forEach((f) => { const im = new Image(); im.src = "/ui/kit/" + f; });
  }, [started]);
  // Eli talking (home intro, community-garden welcome, or his quiz) quiets the
  // music for as long as the conversation is on screen.
  const eliTalking = introDlg || churchIntro != null || !!quiz || !!counterTalk;
  useEffect(() => {
    const g = gameRef.current;
    if (g && g.duckMusic) g.duckMusic(eliTalking);
  }, [eliTalking]);
  useEffect(() => { const g = gameRef.current; if (g) g.buildActive = buildMode; }, [buildMode]);
  useEffect(() => { if (hud.map !== "HOME" && buildMode) setBuildMode(false); }, [hud.map, buildMode]);

  const randomizeOutfit = () => {
    const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];
    gameRef.current?.setOutfit({
      skin: pick(SKIN_TONES), hair: pick(HAIR_COLORS), hairStyle: pick(HAIR_STYLES).k,
      style: pick(STYLE_OPTS).k, shirt: pick(SHIRT_COLORS), boots: pick(BOOT_COLORS),
      hat: pick(HAT_OPTS).k, accessory: pick(ACC_OPTS).k,
    });
  };

  // Walk away from Eli's challenge with the seed intact — no loss recorded.
  const leaveQuiz = () => {
    if (!quiz) return;
    gameRef.current?.quizLeave(quiz.seedKey);
    setQuiz({ ...quiz, phase: "result", left: true });
  };

  const answerQuiz = (i) => {
    if (!quiz || quiz.phase !== "ask") return;
    const cur = quiz.qs[quiz.idx];

    // Shared resolution path for both server-graded and local quizzes.
    // `right` is the verdict; `correctIdx` back-fills cur.a so the reveal
    // UI highlights the true answer either way.
    const finish = (right, correctIdx) => {
      cur.a = correctIdx;
      const nc = quiz.correct + (right ? 1 : 0);
      const nw = quiz.wrong + (right ? 0 : 1);
      const results = [...quiz.results, right ? "r" : "w"];
      if (right) gameRef.current?.SFX?.correct(); else gameRef.current?.SFX?.wrong();
      // Eli reacts out loud — but NOT on the answer that ends the challenge,
      // or he'd say two things back to back ("Aye, that's it" then "Well
      // studied, child!"). On the deciding answer the verdict line stands alone.
      const decides = nc >= 2 || nw >= 2;
      if (!decides) gameRef.current?.speakQuizVerdict?.(right, quiz.idx);
      setQuiz({ ...quiz, picked: i, phase: "reveal", correct: nc, wrong: nw, results });
      setTimeout(() => {
        // The server requires all 3 answers before an attempt can pass or
        // fail; when the game decides early (2 right / 2 wrong), submit
        // filler answers for the remaining questions — they can't change
        // the outcome (2 correct already passes; 2 wrong already fails).
        const submitFillers = () => {
          let chain = Promise.resolve();
          if (quiz.attemptId) {
            for (let k = quiz.idx + 1; k < 3; k++) {
              chain = chain.then(() => window.YGTEEV_API.answerQuiz(quiz.attemptId, 0).catch(() => {}));
            }
          }
          return chain;
        };
        if (nc >= 2) {
          submitFillers().then(() => {
            gameRef.current?.quizPass(quiz.plotIdx, quiz.seedKey, quiz.attemptId);
          });
          setQuiz({ ...quiz, correct: nc, wrong: nw, results, phase: "result", pass: true });
        } else if (nw >= 2) {
          submitFillers();
          gameRef.current?.quizFail();
          setQuiz({ ...quiz, correct: nc, wrong: nw, results, phase: "result", pass: false });
        } else {
          setQuiz({ ...quiz, correct: nc, wrong: nw, results, idx: quiz.idx + 1, picked: null, phase: "ask" });
        }
      }, 950);
    };

    if (quiz.attemptId && window.YGTEEV_API) {
      window.YGTEEV_API.answerQuiz(quiz.attemptId, i)
        .then((r) => finish(r.correct, r.correct_choice_index))
        .catch(() => finish(false, cur.a)); // network hiccup counts as a miss
    } else {
      finish(i === cur.a, cur.a);
    }
  };
  useEffect(() => {
    if (quiz?.phase === "result") {
      const t = setTimeout(() => setQuiz(null), 1600);
      return () => clearTimeout(t);
    }
  }, [quiz]);

  const G = gameRef.current;
  const seedKeys = Object.keys(SEEDS);
  // chip rows show base seeds + glowberry always; premium glow tiers appear
  // once owned (seven chips would overflow a phone-width tray)
  const pouchSeedKeys = seedKeys.filter((k) => !SEEDS[k].glow || k === "glowberry" || hud.inv.seeds[k] > 0 || hud.selectedSeed === k);
  const basketFruitKeys = seedKeys.filter((k) => !SEEDS[k].glow || k === "glowberry" || hud.inv.fruit[k] > 0);
  const hungerPct = Math.max(0, Math.min(100, hud.hunger));
  const FRUIT_EMOJI = { strawberry: "🍓", blueberry: "🫐", sunfruit: "🍑", glowberry: "✨", starberry: "⭐", dawnberry: "🌅", gloryberry: "👑" };
  const HOME_CROPS = ["strawberry", "blueberry", "sunfruit"];
  const RARE_CROPS = ["glowberry", "starberry", "dawnberry", "gloryberry"];
  const INV_TILE_CROPS = [...HOME_CROPS, ...RARE_CROPS]; // all have tile art now
  const inCommunity = hud.map === "CHURCH";
  const ACTION_ICON = { plant: "🌱", harvest: "🧺", dragon: "🍓", seedshop: "🛒", market: "💰", toolsmith: "⚒️", counter: "💬", bridge: "🌉", goldbag: "💰", redbag: "🎒", glow: "✨" };
  // the painted market grid has six cells (gloryberry has no cell yet)
  const MARKET_KEYS = ["strawberry", "blueberry", "sunfruit"]; // the painted board sells home fruit only
  const marketTotal = seedKeys.reduce((t, k) => t + hud.inv.fruit[k] * SEEDS[k].sell, 0);
  // Berry Market sell selection: fruit key -> qty to sell. Defaults to the
  // full basket when the market opens (one tap still sells everything);
  // steppers let the player hold some fruit back for Ember.
  const [sellQty, setSellQty] = useState({});
  useEffect(() => {
    // Opens EMPTY — the player adds what they want to sell with + / ALL,
    // so nothing is ever sold by a single mis-tap.
    if (shop === "market") setSellQty({});
  }, [shop]);
  const sellSel = (k) => Math.max(0, Math.min(hud.inv.fruit[k], sellQty[k] ?? 0));
  const bumpSell = (k, d) => {
    gameRef.current?.SFX?.click();
    setSellQty((q) => ({ ...q, [k]: Math.max(0, Math.min(hud.inv.fruit[k], (q[k] ?? 0) + d)) }));
  };
  const sellSelCount = seedKeys.reduce((t, k) => t + sellSel(k), 0);
  const sellSelTotal = seedKeys.reduce((t, k) => t + sellSel(k) * SEEDS[k].sell, 0);
  const basketCount = seedKeys.reduce((t, k) => t + hud.inv.fruit[k], 0);
  const sellingEverything = basketCount > 0 && sellSelCount === basketCount;
  const doSell = () => {
    if (sellSelTotal <= 0) return;
    const counts = {};
    seedKeys.forEach((k) => { counts[k] = sellSel(k); });
    gameRef.current?.sellFruit(counts);
    setSellQty((q) => {
      const left = {};
      seedKeys.forEach((k) => { left[k] = Math.max(0, hud.inv.fruit[k] - counts[k]); });
      return left; // whatever remains is selected again — ready for a quick follow-up sale
    });
  };
  // In-game HUD uses the splash kit at the same proportional scale
  // (design units are the 768-wide mockup); syncHud re-renders often enough
  // that reading innerWidth here tracks rotation.
  const HUD_S = Math.min(typeof window !== "undefined" ? window.innerWidth : 430, 560) / 768;
  const fmtHud = (n) => (n >= 10000 ? `${(n / 1000).toFixed(1).replace(/\.0$/, "")}k` : String(n));

  /* ---------- Ornate wood & gold UI ---------- */
  const WOOD = "linear-gradient(180deg, #ffffff 0%, #edf7fd 55%, #d8edfb 100%)";
  const GOLD = "#2f7fc1";
  const GOLD_BRIGHT = "#ffb845";
  const PARCH = "#17497e";
  // True when running inside the iOS app's WKWebView (container adds ?ios=1).
  // The top-left HUD pills shift right to clear the app's close button.
  const EMBEDDED_IOS = (() => { try { return new URLSearchParams(window.location.search).has("ios"); } catch (e) { return false; } })();
  const S = {
    wrap: { position: "fixed", inset: 0, background: "#8fc9ec", fontFamily: "'Trebuchet MS', 'Segoe UI', sans-serif", overflow: "hidden", userSelect: "none", WebkitUserSelect: "none" },
    canvas: { position: "absolute", inset: 0 },
    panel: {
      background: WOOD,
      border: `2px solid ${GOLD}`,
      boxShadow: "inset 0 0 0 2px rgba(255,255,255,0.85), inset 0 -3px 8px rgba(47,127,193,0.16), 0 8px 18px rgba(23,73,126,0.28)",
      borderRadius: 16,
      color: PARCH,
    },
    goldText: { color: "#f2971f", textShadow: "0 1px 0 rgba(255,255,255,0.75)" },
    chip: (active) => ({
      display: "flex", flexDirection: "column", alignItems: "center", minWidth: 54, padding: "6px 8px",
      borderRadius: 9, cursor: "pointer",
      border: active ? `2px solid ${GOLD_BRIGHT}` : "1px solid #a8cfe8",
      background: active
        ? "linear-gradient(180deg, rgba(255,200,94,0.55), rgba(255,255,255,0.95))"
        : "linear-gradient(180deg, #ffffff, #e9f5fc)",
      boxShadow: active ? "0 0 10px rgba(255,184,69,0.55), inset 0 1px 2px rgba(255,255,255,0.85)" : "inset 0 1px 2px rgba(140,180,210,0.35)",
      transition: "all 0.15s",
    }),
    btn: (bg, fg) => ({
      border: "1px solid #155a9c", borderRadius: 9, padding: "7px 14px", fontWeight: 700,
      fontFamily: "inherit", cursor: "pointer", background: bg, color: fg,
      boxShadow: "inset 0 1px 2px rgba(255,255,255,0.75), 0 3px 6px rgba(0,0,0,0.4)",
    }),
  };
  const goldBtnBg = "linear-gradient(180deg, #ffc85e, #f0931c)";

  const dismissSplash = () => {
    ensureAudioKeeper();
    const g = gameRef.current;
    if (g) {
      g.splashActive = false; // camera mode chain falls through to home framing
      try { g.restoreRes && g.restoreRes(); } catch (e) {}
    }
    setStarted(true);
  };
  // X button: hand off to the native app when embedded, else return to the
  // title screen (browser/testing).
  const closeGame = () => {
    if (requestCloseSplash()) return;
    const g = gameRef.current;
    if (g) g.splashActive = true;
    setSplashMounted(true);
    setStarted(false);
  };
  // Inside the iOS WKWebView the app owns the close affordance; return true
  // when the native layer handled it, else the splash falls back to START.
  const requestCloseSplash = () => {
    try {
      if (window.webkit?.messageHandlers?.ygteevClose) {
        window.webkit.messageHandlers.ygteevClose.postMessage("close");
        return true;
      }
    } catch (e) {}
    return false;
  };

  return (
    <div style={S.wrap}>
      <div ref={mountRef} style={S.canvas} />

      {splashMounted && (
        <SplashScreen
          hud={hud}
          onStart={dismissSplash}
          onRequestClose={requestCloseSplash}
          onGone={() => setSplashMounted(false)}
        />
      )}

      {/* free vignette — replaces the removed post-process grade pass */}
      <div style={{ position: "absolute", inset: 0, pointerEvents: "none", background: "radial-gradient(ellipse 130% 115% at 50% 42%, transparent 62%, rgba(18,28,22,0.16) 100%)" }} />

      {rampage && <div style={{ position: "absolute", inset: 0, pointerEvents: "none", boxShadow: "inset 0 0 120px 40px rgba(232,60,40,0.55)", animation: "pulse 0.5s infinite alternate" }} />}

      {/* map transition: fade to black with a location title card */}
      {mapFx && (
        <div style={{
          position: "absolute", inset: 0, zIndex: 50, pointerEvents: "none", background: "#0d2a4a",
          display: "flex", alignItems: "center", justifyContent: "center",
          animation: mapFx.phase === "in" ? "mapIn 0.4s ease-in forwards" : "mapOut 0.62s ease-out forwards",
        }}>
          <div style={{ textAlign: "center" }}>
            <div style={{ fontSize: 30, letterSpacing: 3, color: "#ffb845", fontFamily: "Georgia, serif", textShadow: "0 2px 14px rgba(0,0,0,0.9)" }}>{mapFx.label}</div>
            <div style={{ height: 2, width: 220, margin: "12px auto 0", background: "linear-gradient(90deg, transparent, #ffb845, transparent)" }} />
          </div>
        </div>
      )}

      {/* coins flying to the gold counter */}
      {coinFx.map((c) => (
        <span key={c.id} style={{
          position: "absolute", left: c.sx, top: c.sy, zIndex: 45, fontSize: 22, pointerEvents: "none",
          "--tx": `${74 - c.sx}px`, "--ty": `${32 - c.sy}px`,
          animation: `coinfly 0.72s ${c.d}ms cubic-bezier(0.45, -0.25, 0.6, 1) forwards`,
        }}><GoldCoin size={20} /></span>
      ))}
      <style>{`@keyframes pulse { from { opacity: 0.5 } to { opacity: 1 } } @keyframes slideIn { from { transform: translateY(-8px); opacity: 0 } to { transform: none; opacity: 1 } } @keyframes mapIn { from { opacity: 0 } to { opacity: 1 } } @keyframes mapOut { from { opacity: 1 } to { opacity: 0 } } @keyframes coinfly { 55% { opacity: 1 } to { transform: translate(var(--tx), var(--ty)) scale(0.35); opacity: 0 } } @keyframes btnPulse { 0%,100% { box-shadow: 0 6px 16px rgba(0,0,0,0.5), 0 0 0 0 rgba(255,184,69,0.55) } 50% { box-shadow: 0 6px 16px rgba(0,0,0,0.5), 0 0 0 12px rgba(255,184,69,0) } } @keyframes taskIn { 0% { transform: translate(-50%, -50%) scale(0.55); opacity: 0 } 14% { transform: translate(-50%, -50%) scale(1.1); opacity: 1 } 24% { transform: translate(-50%, -50%) scale(1) } 80% { transform: translate(-50%, -50%) scale(1); opacity: 1 } 100% { transform: translate(-50%, -56%) scale(0.94); opacity: 0 } } @keyframes itemIn { 0% { transform: translate(-50%, -50%) scale(0.4); opacity: 0 } 55% { transform: translate(-50%, -50%) scale(1.09); opacity: 1 } 100% { transform: translate(-50%, -50%) scale(1) } } @keyframes itemFly { to { transform: translate(calc(-50% + var(--ix)), calc(-50% + var(--iy))) scale(0.22); opacity: 0 } } @keyframes rayspin { to { transform: rotate(360deg) } } @keyframes giftPop { 0% { transform: scale(0.4); opacity: 0 } 55% { transform: scale(1.08); opacity: 1 } 100% { transform: scale(1) } }`}</style>

      {/* stats — hidden while the title splash is up (it shows its own) */}
      {/* header — identical layout to the splash: X left, pills centered,
          medallion right (see splash/SplashScreen.jsx top bar) */}
      {started && (
      <div style={{
        position: "absolute", top: "calc(env(safe-area-inset-top, 0px))", left: 0, right: 0,
        // taller than the old pills-only header: the level readout now stacks
        // above the wallets, and the block centres on this box — at 120 it
        // sat ~5px off the top edge
        minHeight: 148 * HUD_S, display: "flex", alignItems: "center",
        padding: `0 ${14 * HUD_S}px`, boxSizing: "border-box", pointerEvents: "none",
      }}>
        {/* gold + XP, centred on the SCREEN (absolute, so the medallion's
            width can't bias the midpoint). The close X was retired from
            both this header and the splash; the players-today plate was
            retired earlier. The League board is still reachable from the
            Gardener's Ledger via the medallion. */}
        <div style={{
          position: "absolute", left: "50%", top: "50%", transform: "translate(-50%,-50%)",
          display: "flex", flexDirection: "column", alignItems: "center", gap: 5 * HUD_S,
          whiteSpace: "nowrap", pointerEvents: "auto",
        }}>
          {/* level readout, centred directly over the wallets */}
          <div style={{ display: "flex", alignItems: "center", gap: 8 * HUD_S }}>
            <span
              style={{
                fontFamily: T_UI.font, fontWeight: 800, fontSize: 27 * HUD_S,
                color: "#f4ffe9", letterSpacing: 0.5,
                textShadow: "0 2px 4px rgba(10,25,10,.85), 0 0 10px rgba(0,0,0,.4)",
              }}
            >
              LV {hud.level}
            </span>
            <LevelBarH gems={hud.gems} width={210 * HUD_S} />
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 10 * HUD_S }}>
          <PlatePill kind="gold" height={66 * HUD_S} value={fmtHud(hud.gold)} />
          <PlatePill kind="xp" height={66 * HUD_S} value={fmtHud(hud.xp)} />
          {/* community garden only: the youth group's live berry tally.
              The row is absolutely centred, so adding a third plate
              re-centres all three automatically. */}
          {hud.map === "CHURCH" && (
            <PlatePill kind="berries" height={66 * HUD_S} value={
              <span style={{ display: "flex", flexDirection: "column", alignItems: "center", lineHeight: 1 }}>
                <span style={{ display: "flex", gap: 2 * HUD_S, marginBottom: 1 * HUD_S }}>
                  {["glowberry", "starberry", "dawnberry", "gloryberry"].map((k) => (
                    <img key={k} src={`/ui/kit/fruit-${k}-sm.png`} alt="" draggable={false}
                         style={{ width: 13 * HUD_S, height: 13 * HUD_S, objectFit: "contain",
                                  filter: "drop-shadow(0 1px 1px rgba(6,26,10,.7))" }} />
                  ))}
                </span>
                <span>{fmtHud(hud.league?.mine ?? 0)}</span>
              </span>
            } />
          )}
          </div>
        </div>
        {/* The avatar stands ON the stone, so this block is taller than the
            disc — it hangs below the pill row rather than sitting inside it,
            which would clip the character's head against the screen edge. */}
        <Medallion
          avatar={hud.avatarPortrait}
          name={window.YGTEEV?.profile?.name}
          size={118 * HUD_S}
          onClick={() => setShop("profile")}
          /* nudged below the row's midline so the hat clears the screen edge.
             The offset is small because the header grew for the level row —
             the midline already moved down 14*S. */
          style={{ position: "absolute", right: 14 * HUD_S, top: "50%", transform: `translateY(calc(-50% + ${2 * HUD_S}px))`, pointerEvents: "auto" }}
        />
      </div>
      )}

      {/* Player level: gem track that slides in on every earn.
          NOTE: no transform on this wrapper — the LEVEL UP! sign inside uses
          position:fixed, and a transformed ancestor would become its
          containing block and knock it off-centre. */}
      {started && (
        <div style={{
          position: "absolute", left: 12, top: 0, bottom: 0,
          display: "flex", alignItems: "center",
          zIndex: 18, pointerEvents: "none",
        }}>
          <LevelBar
            level={hud.level} gems={hud.gems} fx={hud.gemFx}
            onLevelReady={onLevelReady} badgeAt={levelBadgeAt}
            height={Math.min(320, 430 * HUD_S)}
          />
        </div>
      )}

      {/* Read a section of Scripture for XP — offered on level-up, ahead of
          the badge. Not a modal: the world stays playable underneath. */}
      {started && reading && (
        <ReadingPlayer
          data={reading}
          api={window.YGTEEV_API}
          duck={(on) => { try { gameRef.current?.duckMusic?.(on); } catch (e) {} }}
          sfx={{
            click: () => gameRef.current?.SFX?.click?.(),
            right: () => gameRef.current?.SFX?.correct?.(),
            wrong: () => gameRef.current?.SFX?.wrong?.(),
            level: () => gameRef.current?.SFX?.pass?.(),
          }}
          onXp={(total) => gameRef.current?.applyXp?.(total)}
          onPhase={(ph) => {
            const g = gameRef.current;
            if (!g) return;
            // only while the passage is running or the question is open —
            // the offer is skippable and the result is just an acknowledgement
            const locked = ph === "play" || ph === "question";
            if (g.readingLock && !locked) g.readingGraceUntil = (g.time || 0) + 1.2;
            g.readingLock = locked;
          }}
          onDone={endReading}
        />
      )}

      {/* Ember's hunger notice — carved plaque with a gem meter */}
      {started && hud.showHunger && (
        <EmberPlaque
          pct={hungerPct}
          happy={!!hud.emberHappy}
          width={Math.min(370, 520 * HUD_S)}
          style={{
            position: "absolute",
            top: `calc(${96 * HUD_S}px + env(safe-area-inset-top, 0px))`,
            left: "50%", transform: "translateX(-50%)",
            animation: "slideIn 0.3s", pointerEvents: "none", zIndex: 16,
          }}
        />
      )}


      {/* Toasts — suppressed behind the title splash. They stack UNDER Ember's
          hunger plaque when it is out, so a notice is never hidden by it. */}
      <div style={{
        position: "absolute",
        top: `calc(${(hud.showHunger ? 272 : 126) * HUD_S}px + env(safe-area-inset-top, 0px))`,
        left: "50%", transform: "translateX(-50%)",
        display: "flex", flexDirection: "column", gap: 7, alignItems: "center",
        pointerEvents: "none", width: "92%", maxWidth: 430, zIndex: shop ? 31 : 17,
        transition: "top .28s ease",
      }}>
        {started && toasts.map((t) => (
          <div key={t.id} style={{ width: "100%", animation: "slideIn 0.25s" }}>
            <StonePanel edge={17} corner={34}>
              <div style={{
                display: "flex", alignItems: "center", justifyContent: "center", gap: 10,
                fontFamily: T_UI.font, fontSize: 13.5, fontWeight: 700, textAlign: "center",
                lineHeight: 1.35,
                color: t.kind === "danger" ? "#9b2f18"
                  : t.kind === "gold" ? "#8a5a12"
                  : t.kind === "warn" ? "#7a5410"
                  : "#4a3520",
              }}>
                {t.art && (
                  <img src={t.art} alt="" draggable={false}
                       style={{ width: 44, height: 44, objectFit: "contain", flex: "0 0 auto",
                                filter: "drop-shadow(0 2px 3px rgba(30,20,10,.45))" }} />
                )}
                <span>{t.text}</span>
              </div>
            </StonePanel>
          </div>
        ))}
      </div>

      {/* interact prompt */}
      {gardenPick && (
        <div style={{ position: "absolute", inset: 0, background: "rgba(10,7,18,0.62)", display: "flex", alignItems: "center", justifyContent: "center", zIndex: 60, pointerEvents: "auto" }}>
          <div style={{ width: "min(340px, 88vw)", background: "#e9d6a6", border: "6px solid #6b4a2f", borderRadius: 16, padding: "18px 16px", boxShadow: "0 18px 50px rgba(0,0,0,0.5)", textAlign: "center" }}>
            <div style={{ fontSize: 26, marginBottom: 2 }}>🌉</div>
            <div style={{ font: "bold 19px Georgia", color: "#3a2812", marginBottom: 4 }}>Which garden today?</div>
            <div style={{ font: "13px Georgia", color: "#6b4a2f", marginBottom: 14 }}>You belong to more than one youth group — pick whose community garden to visit.</div>
            {gardenPick.opts.map((opt) => (
              <button
                key={opt.id}
                onClick={() => {
                  gameRef.current?.SFX?.click?.();
                  gameRef.current?.enterGarden(opt, gardenPick.ex);
                  setGardenPick(null);
                }}
                style={{ display: "block", width: "100%", margin: "0 0 8px", padding: "12px 14px", background: "#6b4a2f", color: "#f6e8c4", border: "2px solid #3a2812", borderRadius: 10, font: "bold 15px Georgia", cursor: "pointer" }}
              >
                ⛪ {opt.name}
              </button>
            ))}
            <button
              onClick={() => {
                gameRef.current?.cancelGardenPick?.();
                setGardenPick(null);
              }}
              style={{ display: "block", width: "100%", padding: "9px 14px", background: "transparent", color: "#6b4a2f", border: "2px solid #6b4a2f", borderRadius: 10, font: "bold 13px Georgia", cursor: "pointer" }}
            >
              Not now — stay home
            </button>
          </div>
        </div>
      )}
      {/* Growth readout — the timers on a plant you're standing next to:
          sacred-tree maturity, next-berry cadence + tree life left, and the
          home regrow countdown. Gated on !hud.promptType so it only shows
          INFORMATIONAL states; actionable ones ("Plant X", "Harvest X!")
          stay off, since tapping already conveys those. */}
      {hud.prompt && !hud.promptType && started && !shop && !quiz && !buildMode
        && !counterTalk && !introDlg && !bridgeTalk && churchIntro == null && (
        <div
          style={{
            position: "absolute", bottom: "calc(96px + env(safe-area-inset-bottom, 0px))",
            left: "50%", transform: "translateX(-50%)", zIndex: 12,
            maxWidth: "88vw", padding: "7px 16px", borderRadius: 10,
            background: "linear-gradient(180deg, #8a6440, #6b4626 62%, #533618)",
            border: "2px solid #4a2f16",
            boxShadow: "inset 0 2px 0 rgba(255,226,180,.22), 0 3px 6px rgba(30,20,10,.45)",
            fontFamily: T_UI.font, fontWeight: 700, fontSize: 13.5,
            color: T_UI.idleText, textShadow: "0 1px 2px rgba(35,18,4,.75)",
            whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
            pointerEvents: "none", userSelect: "none",
          }}
        >
          {hud.prompt}
        </div>
      )}

      {/* seed selector + expandable pouch tray */}
      {tray && !quiz && shop !== "style" && !buildMode && (
        <div onClick={() => setTray(false)} style={{ position: "absolute", inset: 0, zIndex: 19 }} />
      )}
      {tray && !quiz && shop !== "style" && !buildMode && (
        <div style={{
          position: "absolute", inset: 0, zIndex: 22, display: "flex",
          alignItems: "center", justifyContent: "center", padding: 12,
          animation: "slideIn 0.2s", pointerEvents: "none",
        }}>
          <InventoryBoard
            width={Math.min(360, (typeof window !== "undefined" ? window.innerWidth : 360) * 0.88)}
            style={{ pointerEvents: "auto" }}
            mode={inCommunity ? "community" : "home"}
            seeds={HOME_CROPS.map((k) => ({
              key: k, art: "seed", count: hud.inv.seeds[k],
              selected: hud.activeKind === "seed" && hud.selectedSeed === k,
              onClick: () => { G?.selectSeed(k); setTray(false); },
            }))}
            basket={HOME_CROPS.map((k) => ({
              key: k, art: "basket", count: hud.inv.fruit[k],
              selected: hud.activeKind === "fruit" && hud.selectedFruit === k,
              onClick: () => { G?.selectFruit(k); setTray(false); },
            }))}
            rare={RARE_CROPS.map((k) => ({
              key: k, art: "seed", count: hud.inv.seeds[k],
              selected: hud.activeKind === "seed" && hud.selectedSeed === k,
              onClick: () => { G?.selectSeed(k); setTray(false); },
            }))}
            onLocked={() => {
              gameRef.current?.SFX?.wrong?.();
              setToolNote(inCommunity
                ? { title: "COMMUNITY GARDEN", body: "Only rare seeds take root here — your regular seeds and basket are for the home garden." }
                : { title: "🔒 RARE SEEDS", body: "Rare seeds are reserved for the community garden." });
            }}
          />
        </div>
      )}

      {/* Bottom-right: the ACTIVE ITEM. Shows the equipped seed's inventory
          tile; tapping opens the Home Inventory to pick a different one. */}
      {/* mute toggle — bottom-left, wood chip in the kit language */}
      {started && !quiz && shop !== "style" && !buildMode && !introDlg && (
        <div
          role="button"
          onClick={() => { const m = gameRef.current?.toggleMute?.(); setMuted(!!m); }}
          style={{
            position: "absolute", left: 12, bottom: "calc(12px + env(safe-area-inset-bottom, 0px))",
            width: 54, height: 54, zIndex: 14, cursor: "pointer",
            WebkitTapHighlightColor: "transparent", userSelect: "none",
            display: "flex", alignItems: "center", justifyContent: "center",
            borderRadius: 12,
            background: "linear-gradient(180deg, #8a6440, #6b4626 62%, #533618)",
            border: "2px solid #4a2f16",
            boxShadow: "inset 0 2px 0 rgba(255,226,180,.22), 0 3px 6px rgba(30,20,10,.45)",
            opacity: muted ? 0.82 : 1,
          }}
        >
          <span style={{ fontSize: 26, lineHeight: 1, filter: "drop-shadow(0 1px 2px rgba(20,12,4,.55))" }}>
            {muted ? "\u{1F507}" : "\u{1F50A}"}
          </span>
        </div>
      )}

      {started && !quiz && shop !== "style" && !buildMode && !introDlg && (
        <div
          role="button"
          onClick={() => setTray((t) => !t)}
          style={{
            position: "absolute", right: 12, bottom: "calc(12px + env(safe-area-inset-bottom, 0px))",
            width: 82, height: 82, zIndex: 21, cursor: "pointer",
            WebkitTapHighlightColor: "transparent",
            filter: "drop-shadow(0 5px 10px rgba(25,15,5,.5))",
          }}
        >
          {(() => {
            const isFruit = hud.activeKind === "fruit";
            const key = isFruit ? hud.selectedFruit : hud.selectedSeed;
            const count = isFruit ? hud.inv.fruit[key] : hud.inv.seeds[key];
            // never render a blank placeholder: fall back to a painted tile
            const artKey = INV_TILE_CROPS.includes(key) ? key : "strawberry";
            const art = `/ui/kit/inv-${isFruit ? "basket" : "seed"}-${artKey}.png`;
            return (
              <>
                <img src={art} alt={SEEDS[key].name} draggable={false}
                     style={{ width: "100%", height: "100%", display: "block" }} />
                <div style={{
                  position: "absolute", right: "6%", top: "4%", width: "27%", height: "27%",
                  display: "grid", placeItems: "center", pointerEvents: "none",
                  fontFamily: T_UI.font, fontWeight: 800, fontSize: 15,
                  color: "#f6e4c0", textShadow: "0 1px 2px rgba(30,15,4,.9)",
                }}><CountBadge value={count} /></div>
              </>
            );
          })()}
        </div>
      )}

      {/* The context action button is gone: every interaction is a tap now —
          plots and Ember and the pouches are tapped directly, shop counters
          greet you on approach, and the bridge note fires on proximity. */}

      {lockedSeed && (
        <LockedSeedNotice
          width={Math.min(360, (typeof window !== "undefined" ? window.innerWidth : 360) * 0.92)}
          onClose={() => setLockedSeed(false)}
        />
      )}

      {/* shops */}
      {shop && shop !== "style" && (
        <div onClick={() => setShop(null)} style={{ position: "absolute", inset: 0, background: "rgba(16,58,102,0.5)", display: "flex", alignItems: "center", justifyContent: "center", zIndex: 29 }}>
          <div onClick={(e) => e.stopPropagation()} style={(shop === "profile" || shop === "seeds" || shop === "market" || shop === "tools")
            ? { width: "auto", maxWidth: "93vw", maxHeight: "92vh" }
            : { ...S.panel, background: WOOD_TEX, padding: 22, width: 348, maxWidth: "93vw", position: "relative", maxHeight: "84vh", overflowY: "auto" }}>
            {shop !== "profile" && shop !== "seeds" && shop !== "market" && shop !== "tools" && <Corners />}
            {shop === "seeds" ? (
              <SeedShop
                member={!!hud.youth}
                rows={Object.keys(SEEDS).map((k) => ({
                  kind: SEEDS[k].currency === "gold" ? "gold" : "xp",
                  cost: SEEDS[k].cost,
                  afford: SEEDS[k].currency === "gold" ? hud.gold >= SEEDS[k].cost : hud.xp >= SEEDS[k].cost,
                }))}
                width={Math.min(324, (typeof window !== "undefined" ? window.innerWidth : 360) * 0.82)}
                onClose={() => setShop(null)}
                onExplain={(i, why) => {
                  const k = seedKeys[i];
                  gameRef.current?.SFX?.wrong?.();
                  if (why === "locked") {
                    setToolNote({ title: "🔒 RARE SEEDS", body: "Rare seeds unlock when you join a youth group in the YGTeeV app. Your whole group grows together in the community garden." });
                  } else {
                    const cur = SEEDS[k].currency === "gold" ? "gold" : "XP";
                    setToolNote({ title: "NOT ENOUGH " + cur.toUpperCase(), body: `${SEEDS[k].name} seeds cost ${SEEDS[k].cost} ${cur}. ${cur === "gold" ? "Sell fruit at the Berry Market to earn gold." : "Harvest and sell fruit to earn more XP."}` });
                  }
                }}
                onBuy={(i) => {
                  const k = seedKeys[i];
                  if (!k) return false;
                  const had = G ? G.inv.seeds[k] : 0;
                  G?.openShopBuy(k);
                  const got = G ? G.inv.seeds[k] : 0;
                  if (got > had) {
                    G?.selectSeed(k);
                    setAcquired({ icon: FRUIT_EMOJI[k] || "🌱", name: `${SEEDS[k].name} Seed` });
                    if (acquiredTimer.current) clearTimeout(acquiredTimer.current);
                    acquiredTimer.current = setTimeout(() => setAcquired(null), 1700);
                    return true;
                  }
                  return false;
                }}
              />
            ) : shop === "market" ? (
              <BerryMarket
                width={Math.min(304, (typeof window !== "undefined" ? window.innerWidth : 360) * 0.79)}
                items={MARKET_KEYS.map((k) => ({
                  key: k, have: hud.inv.fruit[k], unit: SEEDS[k].sell, qty: sellSel(k),
                }))}
                total={sellSelTotal}
                everything={sellingEverything}
                onBump={(k, d) => bumpSell(k, d)}
                onAll={(k) => {
                  gameRef.current?.SFX?.click();
                  setSellQty((q) => ({ ...q, [k]: hud.inv.fruit[k] }));
                }}
                onSell={doSell}
                onClose={() => setShop(null)}
              />
            ) : shop === "tools" ? (
              <Toolworks
                width={Math.min(324, (typeof window !== "undefined" ? window.innerWidth : 360) * 0.82)}
                xp={hud.xp}
                items={[
                  { key: "hoe", icon: "⛏️", name: "Garden Hoe", tier: "TOOL",
                    desc: "Unlocks Build Mode at your home garden.",
                    cost: 500, kind: hud.build.hoe ? "owned" : "buy" },
                  { key: "kit", icon: "🧱", name: "Plot Kit", tier: "SUPPLIES",
                    desc: "A brand-new garden bed — buy & place it in Build Mode at home.",
                    cost: hud.build.kitCost, kind: "info" },
                  { key: "deed1", icon: "📜", name: "Fence Deed I", tier: "LAND",
                    desc: "Grows the fence — opens 11 more plot spaces.",
                    cost: 2000, kind: hud.build.fenceTier >= 1 ? "owned" : "buy" },
                  { key: "deed2", icon: "📜", name: "Fence Deed II", tier: "LAND",
                    desc: "The grand garden — 15 more spaces.",
                    cost: 4500, kind: hud.build.fenceTier >= 2 ? "owned" : hud.build.fenceTier < 1 ? "locked" : "buy" },
                ]}
                onBuy={(k) => {
                  const G2 = gameRef.current;
                  const meta = { hoe: ["⛏️", "Garden Hoe"], deed1: ["📜", "Fence Deed I"], deed2: ["📜", "Fence Deed II"] }[k];
                  const ok = k === "hoe" ? G2?.buyHoe() : G2?.buyDeed();
                  if (ok && meta) {
                    setAcquired({ icon: meta[0], name: meta[1] });
                    if (acquiredTimer.current) clearTimeout(acquiredTimer.current);
                    acquiredTimer.current = setTimeout(() => setAcquired(null), 1700);
                  }
                }}
                onExplain={(k) => {
                  const notes = {
                    "kit": { title: "🧱 PLOT KIT", body: "Plot Kits are bought where you place them. Get the Garden Hoe, tap the Build button at your home garden, and set a new bed on any glowing square. Each new bed costs a little more than the last." },
                    "deed2": { title: "🔒 LOCKED", body: "Grimble grows a fence one deed at a time — buy Fence Deed I before Fence Deed II." },
                    "hoe:poor": { title: "NOT ENOUGH XP", body: "The Garden Hoe costs 500 XP. Harvest fruit and sell it at the Berry Market to earn more." },
                    "deed1:poor": { title: "NOT ENOUGH XP", body: "Fence Deed I costs 2000 XP. Harvest fruit and sell it at the Berry Market to earn more." },
                    "deed2:poor": { title: "NOT ENOUGH XP", body: "Fence Deed II costs 4500 XP. Harvest fruit and sell it at the Berry Market to earn more." },
                  };
                  if (notes[k]) setToolNote(notes[k]);
                }}
                onClose={() => setShop(null)}
              />
            ) : (
              <>
                <PlayerProfile
                  width={Math.min(348, (typeof window !== "undefined" ? window.innerWidth : 360) * 0.9)}
                  name={window.YGTEEV?.profile?.name || "Gardener"}
                  avatar={hud.avatarPortrait}
                  level={hud.level}
                  gold={hud.gold}
                  xp={hud.xp}
                  onAction={(k) => {
                    // onboarding only — quiz/shop chatter has its own flow
                    if (k !== "close" && (introDlg || churchIntro != null)) {
                      setLockNote(true);
                      if (lockNoteTimer.current) clearTimeout(lockNoteTimer.current);
                      lockNoteTimer.current = setTimeout(() => setLockNote(false), 2600);
                      return;
                    }
                    // Character Studio is parked — the button stays, wearing a
                    // padlock, so the entry point is still discoverable.
                    if (k === "customize") {
                      gameRef.current?.SFX?.wrong?.();
                      setToolNote({
                        title: "COMING SOON",
                        body: "The Character Studio is being rebuilt. Your gardener keeps the look they have for now.",
                      });
                    }
                    else if (k === "league") { setShop(null); setBoard(true); gameRef.current?.refreshLeague?.(); }
                    else if (k === "replay") { const ok = gameRef.current?.replayIntro(); if (ok) setShop(null); }
                    else if (k === "close") { setLockNote(false); setShop(null); }
                  }}
                  onInfo={() => setAlmanac(true)}
                />
              </>
            )}
            {shop !== "seeds" && shop !== "market" && shop !== "profile" && shop !== "tools" && <button onClick={() => setShop(null)} style={shop === "profile"
              ? { width: "100%", marginTop: 10, border: "1px solid #4a3218", borderRadius: 9, padding: "9px", background: "linear-gradient(180deg,#9a7148,#74522f)", color: "#f7ead1", cursor: "pointer", fontFamily: T_UI.font, fontWeight: 700, textShadow: "0 1px 2px rgba(30,15,4,.7)" }
              : { width: "100%", marginTop: 10, border: `1px solid ${GOLD}`, borderRadius: 9, padding: "8px", background: "transparent", color: PARCH, cursor: "pointer", fontFamily: "inherit" }}>
              Close
            </button>}
          </div>
        </div>
      )}

      {/* build mode entry (needs the hoe) */}
      {started && !quiz && !shop && !buildMode && hud.map === "HOME" && hud.build.hoe && (
        <div
          role="button"
          onClick={() => setBuildMode(true)}
          style={{
            position: "absolute", right: 14, bottom: "calc(96px + env(safe-area-inset-bottom, 0px))",
            width: 54, height: 54, zIndex: 14, cursor: "pointer",
            WebkitTapHighlightColor: "transparent", userSelect: "none",
            display: "flex", alignItems: "center", justifyContent: "center",
            borderRadius: 12,
            background: "linear-gradient(180deg, #8a6440, #6b4626 62%, #533618)",
            border: "2px solid #4a2f16",
            boxShadow: "inset 0 2px 0 rgba(255,226,180,.22), 0 3px 6px rgba(30,20,10,.45)",
          }}
        >
          <span style={{ fontSize: 26, lineHeight: 1, filter: "drop-shadow(0 1px 2px rgba(20,12,4,.55))" }}>🔨</span>
        </div>
      )}

      {/* build mode control bar — carved stone, wood buttons */}
      {buildMode && (
        <div style={{ position: "absolute", left: "50%", transform: "translateX(-50%)", bottom: "calc(14px + env(safe-area-inset-bottom, 0px))", width: "min(520px, 95vw)", zIndex: 24, fontFamily: T_UI.font }}>
          <StonePanel edge={24} corner={50}>
            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 8, flexWrap: "wrap" }}>
              <div style={{ minWidth: 130 }}>
                <b style={{ color: "#7a4a22", fontSize: 14.5, letterSpacing: 1.4, fontWeight: 800 }}>🔨 BUILD MODE</b>
                <div style={{ fontSize: 12.5, color: "#4a3520", fontWeight: 600, marginTop: 2 }}>
                  {hud.build.canPlace ? "Place a plot on the glowing square" : "Walk to a glowing square…"}
                </div>
              </div>
              <div style={{ display: "flex", gap: 7, alignItems: "center" }}>
                <button onClick={() => gameRef.current?.placePlot()} style={{
                  padding: "10px 15px", borderRadius: 10, fontFamily: "inherit", fontWeight: 800, fontSize: 13.5,
                  display: "flex", alignItems: "center", gap: 5, cursor: hud.build.canPlace ? "pointer" : "default",
                  background: hud.build.canPlace ? "linear-gradient(180deg, #8ee07a, #3fa04f 70%, #2d7a3a)" : "rgba(90,60,25,.15)",
                  border: hud.build.canPlace ? "2px solid #1d5a2a" : "2px solid #8d8073",
                  color: hud.build.canPlace ? "#0e2a12" : "#8a7d68",
                  boxShadow: hud.build.canPlace ? "inset 0 2px 0 rgba(255,255,255,.35), 0 3px 6px rgba(30,20,10,.4)" : "none",
                  textShadow: hud.build.canPlace ? "0 1px 0 rgba(190,255,170,.5)" : "none",
                }}>✔ Plot ✦{hud.build.kitCost}</button>
                {hud.build.deedCost && (
                  <button onClick={() => gameRef.current?.buyDeed()} style={{
                    padding: "10px 13px", borderRadius: 10, fontFamily: "inherit", fontWeight: 800, fontSize: 12.5,
                    background: "linear-gradient(180deg, #a8794a, #7d5330 62%, #63401f)",
                    border: "2px solid #4a2f16", color: "#ffe9b8", cursor: "pointer",
                    textShadow: "0 1px 2px rgba(35,18,4,.75)",
                    boxShadow: "inset 0 2px 0 rgba(255,226,180,.25), 0 3px 6px rgba(30,20,10,.4)",
                  }}>🚧 Expand ✦{hud.build.deedCost}</button>
                )}
                <button onClick={() => setBuildMode(false)} style={{
                  padding: "10px 14px", borderRadius: 10, fontFamily: "inherit", fontWeight: 800, fontSize: 13,
                  background: "linear-gradient(180deg, #b6ab99, #968a78 62%, #7b7060)",
                  border: "2px solid #6a6154", color: "#fff", cursor: "pointer",
                  textShadow: "0 1px 2px rgba(35,22,8,.6)",
                  boxShadow: "inset 0 2px 0 rgba(255,255,255,.25), 0 3px 6px rgba(30,20,10,.4)",
                }}>Done</button>
              </div>
            </div>
          </StonePanel>
        </div>
      )}

      {/* wardrobe: a compact bottom sheet — NO scrim, so the style camera's
          slowly-rotating character stays visible and updates live as you pick */}
      {shop === "style" && (
        <div onClick={() => cancelStudio()} style={{ position: "absolute", inset: 0, zIndex: 26, background: "rgba(12,16,10,.5)", backdropFilter: "blur(3px)", WebkitBackdropFilter: "blur(3px)", display: "flex", alignItems: "center", justifyContent: "center", padding: "10px 8px calc(10px + env(safe-area-inset-bottom, 0px))", boxSizing: "border-box" }}>
          <div onClick={(e) => e.stopPropagation()}>
            <CharacterStudio
              width={studioW}
              avatar={studioAvatar}
              outfit={hud.outfit}
              open={studioCat}
              cats={STUDIO_CATS}
              onToggle={(k) => { gameRef.current?.SFX?.click?.(); setStudioCat(k); }}
              onPick={(slot, v) => { gameRef.current?.SFX?.click?.(); gameRef.current?.setOutfit({ [slot]: v }); }}
              onConfirm={() => { gameRef.current?.SFX?.itemGet?.(); setShop("profile"); }}
              onCancel={() => cancelStudio()}
            />
          </div>
        </div>
      )}

      {/* intro objective chip */}
      {seedGift && (() => {
        const R = RARITY[seedGift.key] || { c: "#9ab87a", tier: "Seed" };
        const FRUIT = { strawberry: "🍓", blueberry: "🫐", sunfruit: "🍑", glowberry: "✨", starberry: "⭐", dawnberry: "🌅", gloryberry: "👑" };
        return (
          <div style={{ position: "absolute", inset: 0, zIndex: 36, display: "flex", alignItems: "center", justifyContent: "center", background: "rgba(12,16,10,0.5)", backdropFilter: "blur(3px)", WebkitBackdropFilter: "blur(3px)" }}>
            <div style={{ width: "min(320px, 86vw)", animation: "giftPop 0.4s cubic-bezier(0.3, 1.4, 0.5, 1) forwards", fontFamily: T_UI.font }}>
              <StonePanel edge={26} corner={54}>
                <div style={{ textAlign: "center", position: "relative", padding: "4px 2px 2px" }}>
                  <div style={{ position: "relative" }}>
                    {/* carved title on a small wood plank */}
                    <div style={{ display: "inline-block", padding: "5px 16px 6px", borderRadius: 8, background: "linear-gradient(180deg, #8a6440, #6b4626 62%, #533618)", border: "2px solid #4a2f16", boxShadow: "inset 0 2px 0 rgba(255,226,180,.22), 0 2px 4px rgba(30,20,10,.4)", fontSize: 11, letterSpacing: 3, color: "#ffe9b8", fontWeight: 800, textShadow: "0 1px 2px rgba(35,18,4,.75)", marginBottom: 12 }}>A GIFT FROM ELI</div>
                    {/* seed disc: stone rim, gold collar — rarity glows around it */}
                    <div style={{ width: 84, height: 84, boxSizing: "border-box", margin: "0 auto 10px", borderRadius: "50%", background: "radial-gradient(circle at 35% 30%, #fdf6e4, #d9c6a4)", border: "4px solid #f0c261", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 44, boxShadow: `0 0 22px ${R.c}88, inset 0 3px 5px rgba(255,255,255,.5), inset 0 -4px 6px rgba(90,60,25,.3)` }}>{FRUIT[seedGift.key] || "🌱"}</div>
                    <div style={{ fontSize: 18, fontWeight: 800, color: "#4a3520", textShadow: "0 1px 0 rgba(255,252,242,.7)" }}>{SEEDS[seedGift.key].name} Seed{seedGift.n > 1 ? "s" : ""} ×{seedGift.n}</div>
                    <div style={{ fontSize: 10, letterSpacing: 1.8, fontWeight: 800, color: "#6b5232", textShadow: "0 1px 0 rgba(255,252,242,.6)", marginBottom: 14 }}>{R.tier.toUpperCase()}</div>
                    <div
                      role="button"
                      onClick={() => { gameRef.current?.claimIntroGift(seedGift.page); setSeedGift(null); gameRef.current?.introAdvance(); }}
                      style={{
                        cursor: "pointer", WebkitTapHighlightColor: "transparent", userSelect: "none",
                        padding: "11px 0 12px", borderRadius: 10, fontSize: 15, fontWeight: 800, letterSpacing: 0.5,
                        background: "linear-gradient(180deg, #a8794a, #7d5330 62%, #63401f)",
                        border: "2px solid #f0c261", color: "#ffe9b8",
                        textShadow: "0 1px 2px rgba(35,18,4,.75)",
                        boxShadow: "inset 0 2px 0 rgba(255,226,180,.3), 0 0 14px rgba(247,199,102,.45), 0 3px 6px rgba(30,20,10,.45)",
                      }}
                    >
                      ＋ ADD TO POCKET
                    </div>
                  </div>
                </div>
              </StonePanel>
            </div>
          </div>
        );
      })()}

      {/* task-complete celebration — a beat of reward before Eli speaks again */}
      {introInfo.celebrate && (() => {
        const C = {
          plant:   { icon: "🌱", big: "Perfectly planted!",  sub: "Eli's impressed — keep going!" },
          harvest: { icon: "🍓", big: "Beautiful harvest!",  sub: "That's the gardener's way!" },
          feed:    { icon: "🔥", big: "Ember loved it!",     sub: "Keep him fed and happy!" },
        }[introInfo.celebrate];
        if (!C) return null;
        return (
          <div style={{ position: "absolute", left: "50%", top: "34%", transform: "translate(-50%,-50%)", zIndex: 34, pointerEvents: "none", fontFamily: T_UI.font, textAlign: "center" }}>
          <div style={{ animation: "giftPop 0.45s cubic-bezier(0.3, 1.4, 0.5, 1) both" }}>
            <div style={{ fontSize: 54, lineHeight: 1, filter: "drop-shadow(0 3px 6px rgba(20,12,4,.5))", marginBottom: 8 }}>{C.icon}</div>
            <div style={{
              padding: "12px 26px 13px", borderRadius: 12,
              background: "linear-gradient(180deg, #8a6440, #6b4626 62%, #533618)",
              border: "3px solid #4a2f16",
              boxShadow: "inset 0 2px 0 rgba(255,226,180,.25), 0 0 30px rgba(255,199,102,.5), 0 6px 14px rgba(30,20,10,.5)",
            }}>
              <div style={{ fontSize: 22, fontWeight: 800, color: "#ffe9b8", textShadow: "0 2px 3px rgba(35,18,4,.8)", whiteSpace: "nowrap" }}>{C.big}</div>
              <div style={{ fontSize: 13, fontWeight: 700, color: T_UI.idleText, textShadow: "0 1px 2px rgba(35,18,4,.7)", marginTop: 3 }}>{C.sub}</div>
            </div>
          </div>
          </div>
        );
      })()}

      {/* post-purchase moment: the item pops centre-screen with gold rays */}
      {acquired && (
        <div style={{ position: "absolute", inset: 0, zIndex: 34, pointerEvents: "none", display: "flex", alignItems: "center", justifyContent: "center", fontFamily: T_UI.font }}>
          <div style={{ position: "relative", textAlign: "center", animation: "giftPop 0.45s cubic-bezier(0.3, 1.4, 0.5, 1) both" }}>
            <div style={{ position: "absolute", left: "50%", top: 60, width: 240, height: 240, marginLeft: -120, marginTop: -120, background: "conic-gradient(rgba(240,194,97,.35) 0deg, transparent 24deg, rgba(240,194,97,.35) 48deg, transparent 72deg, rgba(240,194,97,.35) 96deg, transparent 120deg, rgba(240,194,97,.35) 144deg, transparent 168deg, rgba(240,194,97,.35) 192deg, transparent 216deg, rgba(240,194,97,.35) 240deg, transparent 264deg, rgba(240,194,97,.35) 288deg, transparent 312deg, rgba(240,194,97,.35) 336deg, transparent 360deg)", animation: "rayspin 5s linear infinite", borderRadius: "50%" }} />
            <div style={{ position: "relative", width: 110, height: 110, margin: "0 auto 12px", borderRadius: "50%", boxSizing: "border-box", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 54, background: "radial-gradient(circle at 35% 30%, #fdf6e4, #d9c6a4)", border: "5px solid #f0c261", boxShadow: "0 0 34px rgba(255,199,102,.8), inset 0 4px 6px rgba(255,255,255,.5), inset 0 -5px 7px rgba(90,60,25,.3)" }}>{acquired.icon}</div>
            <div style={{ position: "relative", display: "inline-block", padding: "8px 22px 9px", borderRadius: 10, background: "linear-gradient(180deg, #8a6440, #6b4626 62%, #533618)", border: "3px solid #4a2f16", boxShadow: "inset 0 2px 0 rgba(255,226,180,.25), 0 0 24px rgba(255,199,102,.5)" }}>
              <div style={{ fontSize: 12, letterSpacing: 3, fontWeight: 800, color: "#f0c261", textShadow: "0 1px 2px rgba(35,18,4,.7)" }}>ACQUIRED</div>
              <div style={{ fontSize: 20, fontWeight: 800, color: "#ffe9b8", textShadow: "0 2px 3px rgba(35,18,4,.8)", whiteSpace: "nowrap" }}>{acquired.name}</div>
            </div>
          </div>
        </div>
      )}

      {/* toolworks explainers: why locked / what the plot kit is / short on XP */}
      {toolNote && (
        <div onClick={() => setToolNote(null)} style={{ position: "absolute", inset: 0, zIndex: 33, background: "rgba(12,16,10,.45)", display: "flex", alignItems: "center", justifyContent: "center", padding: "16px 10px", boxSizing: "border-box", fontFamily: T_UI.font }}>
          <div onClick={(e) => e.stopPropagation()} style={{ width: "min(320px, 88vw)" }}>
            <StonePanel edge={24} corner={50}>
              <div style={{ textAlign: "center", padding: "2px 2px 4px" }}>
                <div style={{ fontWeight: 800, fontSize: 15, letterSpacing: 1.5, color: "#7a4a22", marginBottom: 8 }}>{toolNote.title}</div>
                <div style={{ fontSize: 14.5, lineHeight: 1.45, color: "#4a3520", fontWeight: 600, marginBottom: 14 }}>{toolNote.body}</div>
                <div role="button" onClick={() => setToolNote(null)} style={{ cursor: "pointer", WebkitTapHighlightColor: "transparent", display: "inline-block", padding: "9px 38px 10px", borderRadius: 10, fontSize: 15, fontWeight: 800, background: "linear-gradient(180deg, #a8794a, #7d5330 62%, #63401f)", border: "2px solid #f0c261", color: "#ffe9b8", textShadow: "0 1px 2px rgba(35,18,4,.75)", boxShadow: "inset 0 2px 0 rgba(255,226,180,.3), 0 3px 6px rgba(30,20,10,.45)" }}>GOT IT</div>
              </div>
            </StonePanel>
          </div>
        </div>
      )}

      {/* Chapel picnic table: what the community garden brings in next 24h */}
      {forecast && (
        <div onClick={() => setForecast(null)} style={{ position: "absolute", inset: 0, zIndex: 33, background: "rgba(12,16,10,.45)", display: "flex", alignItems: "center", justifyContent: "center", padding: "16px 10px", boxSizing: "border-box" }}>
          <div onClick={(e) => e.stopPropagation()}>
            <HarvestForecast
              width={Math.min(335, (typeof window !== "undefined" ? window.innerWidth : 335) * 0.88)}
              total={forecast.total}
              trees={forecast.trees}
              ripening={forecast.ripening}
              rows={forecast.rows}
              onClose={() => setForecast(null)}
            />
          </div>
        </div>
      )}

      {/* Gardener's Almanac — the compact game bible, over the profile menu */}
      {almanac && (
        <div onClick={() => setAlmanac(false)} style={{ position: "absolute", inset: 0, zIndex: 32, background: "rgba(12,16,10,.5)", backdropFilter: "blur(3px)", WebkitBackdropFilter: "blur(3px)", display: "flex", alignItems: "center", justifyContent: "center", padding: "16px 8px", boxSizing: "border-box" }}>
          <div onClick={(e) => e.stopPropagation()}>
            <Almanac
              width={Math.min(345, (typeof window !== "undefined" ? window.innerWidth : 345) * 0.88)}
              crops={["strawberry", "blueberry", "sunfruit"].map((k) => ({
                key: k,
                name: SEEDS[k].name,
                cost: SEEDS[k].cost,
                sell: SEEDS[k].sell,
                gems: (gameRef.current?.HARVEST_GEMS || { strawberry: 1, blueberry: 2, sunfruit: 3 })[k] || 1,
              }))}
              onClose={() => setAlmanac(false)}
            />
          </div>
        </div>
      )}

      {/* Eli lock notice — pinned above the profile menu */}
      {lockNote && (
        <div style={{ position: "absolute", left: "50%", top: "calc(14px + env(safe-area-inset-top, 0px))", transform: "translateX(-50%)", zIndex: 40, pointerEvents: "none", fontFamily: T_UI.font, width: "min(400px, 92vw)" }}>
        <div style={{ animation: "slideIn 0.25s" }}>
          <div style={{
            padding: "11px 18px 12px", textAlign: "center", borderRadius: 11,
            background: "linear-gradient(180deg, #8a6440, #6b4626 62%, #533618)",
            border: "3px solid #4a2f16",
            boxShadow: "inset 0 2px 0 rgba(255,226,180,.25), 0 0 22px rgba(255,199,102,.45), 0 5px 12px rgba(30,20,10,.55)",
            fontSize: 14.5, fontWeight: 800, color: "#ffe9b8", lineHeight: 1.4,
            textShadow: "0 1px 2px rgba(35,18,4,.8)",
          }}>
            Eli deserves your attention. Finish your conversation before exploring further.
          </div>
        </div>
        </div>
      )}

      {taskSplash && (
        <div style={{ position: "absolute", left: "50%", top: "38%", zIndex: 34, pointerEvents: "none", animation: "taskIn 2.0s ease forwards", fontFamily: T_UI.font, width: "max-content", maxWidth: "86vw" }}>
          <div style={{
            padding: "14px 28px 15px", textAlign: "center", borderRadius: 12,
            background: "linear-gradient(180deg, #8a6440, #6b4626 62%, #533618)",
            border: "3px solid #4a2f16",
            boxShadow: "inset 0 2px 0 rgba(255,226,180,.25), 0 0 26px rgba(255,199,102,.5), 0 6px 14px rgba(30,20,10,.5)",
          }}>
            <div style={{ fontSize: 10.5, letterSpacing: 3, color: "#f0c261", fontWeight: 800, marginBottom: 4, textShadow: "0 1px 2px rgba(35,18,4,.7)" }}>ELI'S TASK</div>
            <div style={{ fontSize: 18.5, fontWeight: 800, color: "#ffe9b8", textShadow: "0 2px 3px rgba(35,18,4,.8)", lineHeight: 1.3 }}>{INTRO_TASK_LABEL[taskSplash]}</div>
          </div>
        </div>
      )}
      {introInfo.task && !taskSplash && (
        <div style={{ position: "absolute", top: "calc(12px + env(safe-area-inset-top, 0px))", left: "50%", transform: "translateX(-50%)", zIndex: 15, width: "max-content", maxWidth: "92vw" }}>
          <div style={{
            padding: "9px 16px 10px", display: "flex", alignItems: "center", gap: 12,
            borderRadius: 11, fontFamily: T_UI.font,
            background: "linear-gradient(180deg, #8a6440, #6b4626 62%, #533618)",
            border: "2px solid #4a2f16",
            boxShadow: "inset 0 2px 0 rgba(255,226,180,.22), 0 3px 7px rgba(30,20,10,.5)",
            animation: "btnPulse 1.7s infinite",
          }}>
            <div>
              <div style={{ fontSize: 9.5, letterSpacing: 2, color: "#f0c261", fontWeight: 800, textShadow: "0 1px 2px rgba(35,18,4,.7)" }}>ELI'S TASK</div>
              <div style={{ fontSize: 14, fontWeight: 800, color: "#ffe9b8", textShadow: "0 1px 2px rgba(35,18,4,.75)" }}>{INTRO_TASK_LABEL[introInfo.task]}</div>
            </div>
            <button onClick={introSkip} style={{ background: "none", border: "none", color: "#e8d8b8", opacity: 0.55, fontSize: 11, cursor: "pointer", fontFamily: "inherit", padding: "4px 2px", flex: "0 0 auto", alignSelf: "flex-start" }}>skip ›</button>
          </div>
        </div>
      )}

      {/* Old Eli welcomes the new gardener */}
      {introDlg && (() => { const pg = INTRO_PAGES[introInfo.page]; if (!pg) return null; return (
        <div style={{ position: "absolute", left: "50%", transform: "translateX(-50%)", bottom: 12, width: "min(600px, 95vw)", zIndex: 28 }}>
          <StonePanel edge={26} corner={54}>
            <div style={{ display: "flex", gap: 12, alignItems: "flex-start", textAlign: "left", fontFamily: T_UI.font }}>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <div style={{ color: "#7a4a22", fontWeight: 800, letterSpacing: 1.4, fontSize: 14 }}>OLD GARDENER ELI</div>
                <button onClick={introSkip} style={{ background: "none", border: "none", color: "#7d6444", fontSize: 11, cursor: "pointer", fontFamily: "inherit" }}>skip ›</button>
              </div>
              <div style={{ fontSize: 15.5, lineHeight: 1.38, margin: "6px 2px 11px", color: "#4a3520" }}>"{pg.t}"</div>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <div style={{ display: "flex", gap: 4 }}>
                  {INTRO_PAGES.map((_, i) => (
                    <span key={i} style={{ width: 6, height: 6, borderRadius: "50%", background: i <= introInfo.page ? "#c8781e" : "rgba(90,60,30,0.25)" }} />
                  ))}
                </div>
                <button onClick={introNext} style={{ ...S.btn(goldBtnBg, "#5a3305"), fontSize: 13.5, padding: "8px 22px" }}>
                  {pg.end ? "Let's grow!" : pg.task ? "I'm on it" : "Next ▸"}
                </button>
              </div>
            </div>
            </div>
          </StonePanel>
        </div>
      ); })()}

      {/* Eli's first-visit community-garden welcome */}
      {churchIntro != null && (() => { const pg = CHURCH_INTRO_PAGES[churchIntro]; if (!pg) return null; return (
        <div style={{ position: "absolute", left: "50%", transform: "translateX(-50%)", bottom: "calc(12px + env(safe-area-inset-bottom, 0px))", width: "min(600px, 95vw)", zIndex: 28 }}>
          <StonePanel edge={26} corner={54}>
            <div style={{ display: "flex", gap: 12, alignItems: "flex-start", textAlign: "left", fontFamily: T_UI.font }}>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <div style={{ color: "#7a4a22", fontWeight: 800, letterSpacing: 1.4, fontSize: 14 }}>OLD GARDENER ELI</div>
                <button onClick={() => gameRef.current?.skipChurchIntro()} style={{ background: "none", border: "none", color: "#7d6444", fontSize: 11, cursor: "pointer", fontFamily: "inherit" }}>skip ›</button>
              </div>
              <div style={{ fontSize: 15.5, lineHeight: 1.38, margin: "6px 2px 11px", color: "#4a3520" }}>"{pg.t}"</div>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <div style={{ display: "flex", gap: 4 }}>
                  {CHURCH_INTRO_PAGES.map((_, i) => (
                    <span key={i} style={{ width: 6, height: 6, borderRadius: "50%", background: i <= churchIntro ? "#c8781e" : "rgba(90,60,30,0.25)" }} />
                  ))}
                </div>
                <button onClick={() => gameRef.current?.churchIntroNext()} style={{ ...S.btn(goldBtnBg, "#5a3305"), fontSize: 13.5, padding: "8px 22px" }}>
                  {pg.end ? "Let's grow!" : "Next ▸"}
                </button>
              </div>
            </div>
            </div>
          </StonePanel>
        </div>
      ); })()}

      {/* broken bridge: a note from Eli */}
      {bridgeTalk && (
        <div style={{ position: "absolute", left: "50%", transform: "translateX(-50%)", bottom: 12, width: "min(580px, 95vw)", zIndex: 28 }}>
          <StonePanel edge={26} corner={54}>
            <div style={{ textAlign: "left", fontFamily: T_UI.font }}>
              <div style={{ color: "#7a4a22", fontWeight: 800, letterSpacing: 1.4, fontSize: 14 }}>A NOTE FROM ELI</div>
              <div style={{ fontSize: 15.5, lineHeight: 1.38, margin: "6px 2px 11px", color: "#4a3520" }}>
                "See that wreck? Ember went thundering across it once when his belly got the better of his temper — the old planks never stood a chance. Join a youth group in the YGTeeV app, and they'll send someone out to fix it for you."
              </div>
              <div style={{ display: "flex", justifyContent: "flex-end" }}>
                <button onClick={() => setBridgeTalk(false)} style={{ ...S.btn(goldBtnBg, "#5a3305"), fontSize: 13.5, padding: "8px 22px" }}>OK</button>
              </div>
            </div>
          </StonePanel>
        </div>
      )}

      {/* gold-bag pickup: found card, then the Berry Market flyer */}
      {goldBagStep === "found" && (
        <div style={{ position: "absolute", left: "50%", transform: "translateX(-50%)", bottom: 12, width: "min(520px, 95vw)", zIndex: 28 }}>
          <div style={{ ...S.panel, background: WOOD_TEX, position: "relative", padding: "13px 15px", display: "flex", gap: 12, alignItems: "flex-start", textAlign: "left" }}>
            <Corners />
            <div style={{ width: 52, height: 52, flex: "0 0 52px", borderRadius: "50%", background: "radial-gradient(circle at 35% 30%, #ffe9a8, #c9963c)", border: `1px solid ${GOLD}`, display: "flex", alignItems: "center", justifyContent: "center", fontSize: 26 }}>💰</div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ ...S.goldText, fontWeight: 800, letterSpacing: 1.4, fontSize: 13 }}>YOU FOUND SOMETHING</div>
              <div style={{ fontSize: 13.5, lineHeight: 1.55, margin: "5px 0 10px" }}>
                Found 5 gold coins, a pouch and a flyer.
              </div>
              <button onClick={() => setGoldBagStep("flyer")} style={{ ...S.btn(goldBtnBg, "#5a3305"), fontSize: 13.5, width: "100%" }}>OK</button>
            </div>
          </div>
        </div>
      )}
      {goldBagStep === "flyer" && (
        <div style={{ position: "absolute", inset: 0, zIndex: 28, display: "flex", alignItems: "center", justifyContent: "center", background: "rgba(10,7,18,0.45)" }}>
          <div style={{ width: "min(360px, 88vw)", background: "#ffedc8", border: "3px solid #7a3a10", borderRadius: 6, padding: "20px 18px", textAlign: "center", color: "#7a3a10", boxShadow: "0 14px 40px rgba(0,0,0,0.55)", transform: "rotate(-1.5deg)", fontFamily: "Georgia, serif" }}>
            <div style={{ fontSize: 12, letterSpacing: 3, opacity: 0.75 }}>MEADOW TOWN</div>
            <div style={{ fontSize: 26, fontWeight: 800, letterSpacing: 1, margin: "2px 0 8px" }}>🍓 BERRY MARKET</div>
            <div style={{ borderTop: "2px solid #7a3a10", borderBottom: "2px solid #7a3a10", padding: "10px 4px", margin: "0 6px 10px" }}>
              <div style={{ fontSize: 19, fontWeight: 800, letterSpacing: 0.5 }}>FRUIT SUPPLY RUNNING LOW!</div>
            </div>
            <div style={{ fontSize: 14.5, lineHeight: 1.6, marginBottom: 12 }}>
              Our crates are nearly empty, and hungry customers keep coming.
              We'll pay <b>top dollar</b> for ripened fruit — bring us your
              harvest, gardener!
            </div>
            <div style={{ fontSize: 12, fontStyle: "italic", opacity: 0.8, marginBottom: 14 }}>— Marta, Berry Market counter</div>
            <button onClick={() => { setGoldBagStep(null); gameRef.current?.startMarketCue?.(); }} style={{ ...S.btn(goldBtnBg, "#5a3305"), fontSize: 14, width: "70%", fontFamily: "inherit" }}>OK</button>
          </div>
        </div>
      )}

      {/* daily red bag: one Bible question, one attempt, hidden reward */}
      {redBag && (
        <div style={{ position: "absolute", left: "50%", transform: "translateX(-50%)", bottom: "calc(16px + env(safe-area-inset-bottom, 0px))", width: "min(560px, 94vw)", zIndex: 30 }}>
          <StonePanel edge={26} corner={54}>
            <div style={{ display: "flex", gap: 12, alignItems: "flex-start", textAlign: "left", fontFamily: T_UI.font }}>
            <div style={{ width: 54, height: 54, flex: "0 0 54px", borderRadius: "50%", background: "radial-gradient(circle at 35% 30%, #e88a7a, #8a2a20)", border: "2px solid #8a6a45", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 26, boxShadow: "0 3px 8px rgba(0,0,0,0.45)" }}>🎒</div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <b style={{ color: "#7a4a22", fontSize: 12.5, letterSpacing: 1.5 }}>A HIDDEN RED POUCH</b>
                {redBag.phase === "q" && (
                  <span style={{ fontSize: 10.5, color: "#7d6444", letterSpacing: 1 }}>ONE TRY</span>
                )}
              </div>
              {redBag.phase === "reveal" ? (
                <>
                  <div style={{ fontSize: 14, marginTop: 7, lineHeight: 1.45, color: "#4a3520" }}>
                    {redBag.result?.correct
                      ? redBag.result.reward_kind === "gold"
                        ? <span>✅ <b style={{ color: "#3f8a3a" }}>Right you are!</b> Inside the pouch: <b style={{ color: "#b8791c" }}>{redBag.result.reward_amount} gold</b> 💰</span>
                        : <span>✅ <b style={{ color: "#3f8a3a" }}>Right you are!</b> The pouch glows: <b style={{ color: "#b8791c" }}>+{redBag.result.reward_amount} XP</b> ✨</span>
                      : <span>❌ <b style={{ color: "#b0442c" }}>Not this time…</b> the pouch crumbles away. Tomorrow brings new ones!</span>}
                  </div>
                  <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 6, marginTop: 8 }}>
                    {redBag.options.map((opt, i) => {
                      const isA = i === redBag.result?.correct_idx;
                      const bg = isA ? "linear-gradient(180deg,#7fc96a,#3f8a3a)"
                        : redBag.picked === i ? "linear-gradient(180deg,#d4795c,#a83c26)"
                        : "linear-gradient(180deg,#9a7148,#74522f)";
                      return (
                        <div key={i} style={{
                          padding: "8px 10px", borderRadius: 8, border: "1px solid #4a3218",
                          fontFamily: "inherit", fontSize: 12.5, textAlign: "left",
                          color: "#f7ead1", textShadow: "0 1px 2px rgba(30,15,4,.7)",
                          background: bg, fontWeight: isA ? 800 : 600,
                        }}>{opt}</div>
                      );
                    })}
                  </div>
                  <button onClick={() => setRedBag(null)} style={{ ...S.btn(goldBtnBg, "#5a3305"), fontSize: 13.5, width: "100%", marginTop: 10 }}>OK</button>
                </>
              ) : (
                <>
                  <div style={{ fontSize: 13.5, marginTop: 5, marginBottom: 8, lineHeight: 1.45, color: "#4a3520", fontWeight: 600 }}>
                    {redBag.q}
                  </div>
                  <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 6 }}>
                    {redBag.options.map((opt, i) => (
                      <button key={i} disabled={redBag.busy} onClick={async () => {
                        if (redBag.busy) return;
                        gameRef.current?.SFX?.click();
                        setRedBag({ ...redBag, busy: true, picked: i });
                        try {
                          const r = await window.YGTEEV_API.answerRedBag(redBag.bagIdx, i);
                          if (!r || r.error) { setRedBag(null); return; }
                          gameRef.current?.redBagResolve(redBag.bagIdx, r);
                          setRedBag({ ...redBag, busy: false, picked: i, phase: "reveal", result: r });
                        } catch (e) {
                          setRedBag(null); // dropped connection — bag stays 'opened', tap it again
                        }
                      }} style={{
                        padding: "8px 10px", borderRadius: 8, border: "1px solid #4a3218",
                        cursor: redBag.busy ? "default" : "pointer",
                        fontFamily: "inherit", fontSize: 12.5, textAlign: "left",
                        color: "#f7ead1", textShadow: "0 1px 2px rgba(30,15,4,.7)",
                        background: redBag.picked === i ? "linear-gradient(180deg,#e8c063,#b8862c)" : "linear-gradient(180deg,#9a7148,#74522f)",
                        fontWeight: 600, opacity: redBag.busy && redBag.picked !== i ? 0.6 : 1,
                      }}>{opt}</button>
                    ))}
                  </div>
                </>
              )}
            </div>
            </div>
          </StonePanel>
        </div>
      )}

      {/* Garden League — live board (betting-terminal styling, deliberately
          darker + glassier than the parchment UI so it reads as "live data") */}
      {board && <WeeklyBoardModal hud={hud} onClose={() => setBoard(false)} />}

      {/* shopkeeper counter dialogue */}
      {counterTalk && (() => { const C = COUNTER_CFG[counterTalk.kind]; return (
        <div style={{ position: "absolute", left: "50%", transform: "translateX(-50%)", bottom: 12, width: "min(560px, 95vw)", zIndex: 28 }}>
          <StonePanel edge={26} corner={54}>
            <div style={{ textAlign: "left", fontFamily: T_UI.font }}>
            <div style={{ flex: 1 }}>
              <div style={{ color: "#7a4a22", fontWeight: 800, letterSpacing: 1.2, fontSize: 14 }}>{C.name.toUpperCase()}</div>
              <div style={{ fontSize: 15.5, lineHeight: 1.38, margin: "6px 2px 11px", color: "#4a3520" }}>
                {counterTalk.phase === "ask" ? `"${C.ask}"` : `"${C.bye}"`}
              </div>
              {counterTalk.phase === "ask" && (
                <div style={{ display: "flex", gap: 8 }}>
                  <button onClick={counterYes} style={{ ...S.btn("linear-gradient(180deg,#e8c063,#b8862c)", "#4a2f0c"), border: "1px solid #4a3218", fontSize: 13.5, flex: 1, fontWeight: 800 }}>{C.yes}</button>
                  <button onClick={counterNo} style={{ ...S.btn("linear-gradient(180deg,#9a7148,#74522f)", "#f7ead1"), border: "1px solid #4a3218", fontSize: 13.5, flex: 1 }}>{C.no}</button>
                </div>
              )}
            </div>
            </div>
          </StonePanel>
        </div>
      ); })()}

      {/* Old Gardener Eli — RPG dialogue box */}
      {quiz && (
        <div style={{ position: "absolute", left: "50%", transform: "translateX(-50%)", bottom: 16, width: "min(560px, 94vw)", zIndex: 30 }}>
          <StonePanel edge={26} corner={54}>
            <div style={{ textAlign: "left", fontFamily: T_UI.font }}>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <b style={{ color: "#7a4a22", fontSize: 12.5, letterSpacing: 1.5 }}>OLD GARDENER ELI</b>
                <span style={{ display: "flex", gap: 6 }}>
                  {[0, 1, 2].map((i) => {
                    const r = quiz.results[i];
                    const done = r === "r" || r === "w";
                    return (
                      <span key={i} style={{
                        width: 22, height: 22, borderRadius: "50%", boxSizing: "border-box",
                        display: "grid", placeItems: "center",
                        fontFamily: T_UI.font, fontWeight: 800, fontSize: 12.5, lineHeight: 1,
                        color: done ? "#fff" : "#6f665a",
                        background: r === "r" ? "radial-gradient(circle at 34% 28%, #7fe06a, #3f9a34)"
                          : r === "w" ? "radial-gradient(circle at 34% 28%, #f08a72, #b0382a)"
                          : "radial-gradient(circle at 34% 28%, #cdc4b6, #a79c8b)",
                        border: `2px solid ${r === "r" ? "#2f7a28" : r === "w" ? "#8a291d" : "#8a8073"}`,
                        boxShadow: done
                          ? "inset 0 1px 0 rgba(255,255,255,.45), 0 1px 3px rgba(30,20,10,.4)"
                          : "inset 0 1px 0 rgba(255,255,255,.5), 0 1px 2px rgba(30,20,10,.3)",
                        textShadow: done ? "0 1px 1px rgba(20,10,4,.55)" : "0 1px 0 rgba(255,255,255,.45)",
                      }}>{i + 1}</span>
                    );
                  })}
                </span>
              </div>
              {quiz.phase === "result" ? (
                <div style={{ fontSize: 14, marginTop: 7, lineHeight: 1.45, color: "#4a3520" }}>
                  {quiz.left
                    ? <span>🌿 <b style={{ color: "#7a4a22" }}>"I'll be ready when you are."</b> He tips his hat — your seed is safe.</span>
                    : quiz.pass
                    ? <span>🌱 <b style={{ color: "#3f8a3a" }}>"Well studied, child!"</b> He steps aside so you may plant.</span>
                    : <span>🏃💨 <b style={{ color: "#b0442c" }}>"Study the Word!"</b> He pockets your seed and hurries off…</span>}
                </div>
              ) : quiz.phase === "intro" ? (
                <>
                  <div style={{ fontSize: 13.5, marginTop: 6, lineHeight: 1.5, color: "#4a3520" }}>
                    {quiz.introLine ? `"${quiz.introLine}"` : (
                      <>
                        "Hold there, young gardener! This here is <b>sacred soil</b>. Before ye may plant a rare
                        Glowberry, ye must prove yerself <b style={{ color: "#b8791c" }}>worthy</b> — answer me three questions
                        from the Good Book. Two right, and the soil is yours."
                      </>
                    )}
                  </div>
                  <button
                    onClick={() => { gameRef.current?.SFX?.click(); setQuiz({ ...quiz, phase: "ask" }); }}
                    style={{ marginTop: 10, padding: "8px 22px", borderRadius: 9, border: "1px solid #155a9c", cursor: "pointer", fontFamily: "inherit", fontWeight: 700, fontSize: 13.5, background: "linear-gradient(180deg, #ffb845, #c9963c)", color: "#5a3305", boxShadow: "inset 0 1px 2px rgba(255,255,255,0.75), 0 3px 6px rgba(0,0,0,0.4)" }}
                  >⚜ I'm ready</button>
                  <button
                    onClick={leaveQuiz}
                    style={{ marginTop: 10, marginLeft: 8, padding: "8px 18px", borderRadius: 9, cursor: "pointer", fontFamily: "inherit", fontWeight: 700, fontSize: 13.5, background: "linear-gradient(180deg, #b6ab99, #968a78 62%, #7b7060)", border: "2px solid #6a6154", color: "#fff", textShadow: "0 1px 2px rgba(35,22,8,.6)", boxShadow: "inset 0 2px 0 rgba(255,255,255,.25), 0 3px 6px rgba(30,20,10,.4)" }}
                  >Leave</button>
                </>
              ) : (
                <>
                  <div style={{ fontSize: 13.5, marginTop: 5, marginBottom: 8, lineHeight: 1.45, color: "#4a3520", fontWeight: 600 }}>
                    {quiz.qs[quiz.idx].q}
                  </div>
                  <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 6 }}>
                    {quiz.qs[quiz.idx].o.map((opt, i) => {
                      const isA = i === quiz.qs[quiz.idx].a;
                      const revealed = quiz.phase === "reveal";
                      const bg = revealed && isA ? "linear-gradient(180deg,#7fc96a,#3f8a3a)"
                        : revealed && quiz.picked === i ? "linear-gradient(180deg,#d4795c,#a83c26)"
                        : "linear-gradient(180deg,#9a7148,#74522f)";
                      return (
                        <button key={i} onClick={() => answerQuiz(i)} style={{
                          padding: "8px 10px", borderRadius: 8, border: "1px solid #4a3218", cursor: "pointer",
                          fontFamily: "inherit", fontSize: 12.5, textAlign: "left",
                          color: "#f7ead1", textShadow: "0 1px 2px rgba(30,15,4,.7)",
                          background: bg, fontWeight: revealed && isA ? 800 : 600,
                        }}>{opt}</button>
                      );
                    })}
                  </div>
                  {quiz.phase === "ask" && (
                    <div style={{ textAlign: "right", marginTop: 8 }}>
                      <button
                        onClick={leaveQuiz}
                        style={{ background: "none", border: "none", color: "#7d6444", fontSize: 12.5, fontWeight: 700, cursor: "pointer", fontFamily: "inherit", padding: "2px 2px" }}
                      >Leave · keep my seed ›</button>
                    </div>
                  )}
                </>
              )}
            </div>
            </div>
          </StonePanel>
        </div>
      )}
    </div>
  );
}