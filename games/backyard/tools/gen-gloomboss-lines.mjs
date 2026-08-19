// Record the Gloom Boss's chapel-guard barks.
//
//   SUPABASE_ANON=... node tools/gen-gloomboss-lines.mjs [--force] [--only 3,4]
//
// Lines are imported from src/glowlands/data/gloomboss-lines.js — the exact
// strings the cutscene renders — so audio can never drift from the text.
// Rendering happens in the `gen-eli-voice` edge function (the ElevenLabs key
// stays in Supabase); deploy it from tools/eli-voice.ts first, and put the
// 410 stub back afterwards — a live generator quietly spends credits.
//
// Writes public/voices/gloomboss-{1..10}.mp3 and bumps VOICE_V in the game
// source so no browser serves a stale take.
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { GLOOMBOSS_LINES, GLOOMBOSS_VOICE_ID } from '../src/glowlands/data/gloomboss-lines.js';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '..');
const SRC = path.join(ROOT, 'src/dragon-garden-quest.jsx');
const OUT = path.join(ROOT, 'public/voices');

const FN = 'https://tkesywmshaicjmywbovn.supabase.co/functions/v1/gen-eli-voice';
const BATCH = 3;

const anon = process.env.SUPABASE_ANON;
if (!anon) {
  console.error('Missing SUPABASE_ANON (the project anon key) — needed to call the edge function.');
  process.exit(1);
}

const args = process.argv.slice(2);
const force = args.includes('--force');
const onlyArg = args[args.indexOf('--only') + 1];
const only = args.includes('--only') && onlyArg ? new Set(onlyArg.split(',').map(Number)) : null;

fs.mkdirSync(OUT, { recursive: true });

const todo = GLOOMBOSS_LINES.filter(({ id }) => {
  if (only && !only.has(id)) return false;
  if (!force && fs.existsSync(path.join(OUT, `gloomboss-${id}.mp3`))) return false;
  return true;
});
if (!todo.length) {
  console.log('nothing to do (use --force to re-render existing clips)');
  process.exit(0);
}

for (let i = 0; i < todo.length; i += BATCH) {
  const batch = todo.slice(i, i + BATCH);
  const res = await fetch(FN, {
    method: 'POST',
    headers: { Authorization: `Bearer ${anon}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      voiceId: GLOOMBOSS_VOICE_ID,
      lines: batch.map(({ id, text }) => ({ name: `gloomboss-${id}`, text })),
    }),
  });
  const json = await res.json();
  if (!res.ok || !json.clips) {
    console.error(`batch ${i / BATCH + 1} failed:`, JSON.stringify(json).slice(0, 400));
    process.exit(1);
  }
  for (const c of json.clips) {
    const dest = path.join(OUT, `${c.name}.mp3`);
    fs.writeFileSync(dest, Buffer.from(c.b64, 'base64'));
    const line = batch.find((b) => `gloomboss-${b.id}` === c.name);
    console.log(`✓ ${c.name}.mp3  ${(c.bytes / 1024).toFixed(0)}kB  "${line.text.slice(0, 52)}${line.text.length > 52 ? '…' : ''}"`);
  }
}

// stale-take protection: any regenerated line must bust the voice cache
const src = fs.readFileSync(SRC, 'utf8');
const bumped = src.replace(/^const VOICE_V = (\d+);$/m, (_, v) => `const VOICE_V = ${Number(v) + 1};`);
if (bumped === src) {
  console.warn('\n⚠  could not find `const VOICE_V = <n>;` — bump it by hand or browsers may serve the old clips');
} else {
  fs.writeFileSync(SRC, bumped);
  console.log('VOICE_V bumped');
}
