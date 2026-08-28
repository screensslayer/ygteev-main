// Record the trail refugees' spoken lines (ask + thanks, per-refugee voice).
//
//   SUPABASE_ANON=... node tools/gen-refugee-lines.mjs [--force] [--only 2,5]
//
// Lines and voice IDs come from src/glowlands/data/refugee-lines.js — the
// exact strings the encounters render. Rendering happens in the
// `gen-eli-voice` edge function (ElevenLabs key stays in Supabase); deploy
// it from tools/eli-voice.ts first, and put the 410 stub back afterwards.
//
// Writes public/voices/refugee-{n}-{ask|thanks}.mp3 and bumps VOICE_V.
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { TRAIL_REFUGEES } from '../src/glowlands/data/refugee-lines.js';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '..');
const SRC = path.join(ROOT, 'src/dragon-garden-quest.jsx');
const OUT = path.join(ROOT, 'public/voices');
const FN = 'https://tkesywmshaicjmywbovn.supabase.co/functions/v1/gen-eli-voice';

const anon = process.env.SUPABASE_ANON;
if (!anon) { console.error('Missing SUPABASE_ANON'); process.exit(1); }

const args = process.argv.slice(2);
const force = args.includes('--force');
const onlyArg = args[args.indexOf('--only') + 1];
const only = args.includes('--only') && onlyArg ? new Set(onlyArg.split(',').map(Number)) : null;

fs.mkdirSync(OUT, { recursive: true });
let made = 0;
for (const R of TRAIL_REFUGEES) {
  if (only && !only.has(R.n)) continue;
  const lines = [];
  for (const kind of ['ask', 'thanks']) {
    const dest = path.join(OUT, `refugee-${R.n}-${kind}.mp3`);
    if (fs.existsSync(dest) && !force) continue;
    lines.push({ name: `refugee-${R.n}-${kind}`, text: R[kind] });
  }
  if (!lines.length) { console.log(`= ${R.name}: already recorded`); continue; }
  const res = await fetch(FN, {
    method: 'POST',
    headers: { Authorization: `Bearer ${anon}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ voiceId: R.voiceId, lines }),
  });
  const json = await res.json();
  if (!res.ok || json.error) {
    console.error(`!! ${R.name}: ${json.error || res.status}`, json.detail || '');
    process.exit(2);
  }
  for (const clip of json.clips) {
    fs.writeFileSync(path.join(OUT, `${clip.name}.mp3`), Buffer.from(clip.b64, 'base64'));
    console.log(`✓ ${clip.name}.mp3  ${Math.round(clip.bytes / 1024)}kB`);
    made++;
  }
}
if (made > 0) {
  let src = fs.readFileSync(SRC, 'utf8');
  src = src.replace(/const VOICE_V = (\d+);/, (m, v) => `const VOICE_V = ${Number(v) + 1};`);
  fs.writeFileSync(SRC, src);
  console.log('VOICE_V bumped');
}
console.log(`done — ${made} clip(s).`);
