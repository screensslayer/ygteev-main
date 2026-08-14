// Re-record Old Eli's onboarding narration.
//
//   SUPABASE_ANON=... node tools/gen-intro-lines.mjs [--force] [--only 5]
//
// The nine lines are read straight out of INTRO_PAGES in the game source, so
// the audio can never drift from the text the game renders. Rendering happens
// in the `gen-eli-voice` edge function — the ElevenLabs key stays in Supabase
// and never touches this repo or your shell history. That function is a 410
// stub between recordings; redeploy it from tools/eli-voice.ts first.
//
// Writes public/voices/intro-{1..9}.mp3 and bumps VOICE_V in the game source
// so no browser can serve a stale take of a line we just re-recorded.
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '..');
const SRC = path.join(ROOT, 'src/dragon-garden-quest.jsx');
const OUT = path.join(ROOT, 'public/voices');

const FN = 'https://tkesywmshaicjmywbovn.supabase.co/functions/v1/gen-eli-voice';
const VOICE_ID = process.env.ELEVEN_VOICE_ID || '1GGB5d9bJDyyCaUwSGvD'; // Old Eli
const BATCH = 3;

const anon = process.env.SUPABASE_ANON;
if (!anon) {
  console.error('Missing SUPABASE_ANON (the project anon key) — needed to call the edge function.');
  process.exit(1);
}

// ---- pull the pages out of the game source ----
const src = fs.readFileSync(SRC, 'utf8');
const start = src.indexOf('const INTRO_PAGES = [');
const block = src.slice(start, src.indexOf('\n];', start));
const lines = [...block.matchAll(/\{\s*t:\s*"((?:[^"\\]|\\.)*)"/g)]
  .map((m, i) => ({ n: i + 1, text: m[1].replace(/\\"/g, '"') }));
if (lines.length !== 9) {
  console.error(`Expected 9 INTRO_PAGES, parsed ${lines.length}. Aborting.`);
  process.exit(1);
}

const args = process.argv.slice(2);
const force = args.includes('--force');
const onlyArg = args[args.indexOf('--only') + 1];
const only = args.includes('--only') && onlyArg ? new Set(onlyArg.split(',').map(Number)) : null;

fs.mkdirSync(OUT, { recursive: true });

const todo = lines.filter(({ n }) => {
  if (only && !only.has(n)) return false;
  if (!force && fs.existsSync(path.join(OUT, `intro-${n}.mp3`))) return false;
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
      voiceId: VOICE_ID,
      lines: batch.map(({ n, text }) => ({ name: `intro-${n}`, text })),
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
    const line = batch.find((b) => `intro-${b.n}` === c.name);
    console.log(`✓ ${c.name}.mp3  ${(c.bytes / 1024).toFixed(0)}kB  "${line.text.slice(0, 52)}${line.text.length > 52 ? '…' : ''}"`);
  }
}
// Clips reuse their filenames, so a cached copy of the OLD take would win
// forever. Bump the shared cache-buster here rather than trusting anyone to
// remember it — a silently stale line is very hard to notice.
const bumped = src.replace(
  /^const VOICE_V = (\d+);$/m,
  (_, v) => `const VOICE_V = ${Number(v) + 1};`,
);
if (bumped === src) {
  console.warn('\n⚠  could not find `const VOICE_V = <n>;` — bump it by hand or browsers may serve the old clips');
} else {
  fs.writeFileSync(SRC, bumped);
  console.log(`\nVOICE_V → ${bumped.match(/^const VOICE_V = (\d+);$/m)[1]} (cache-buster bumped)`);
}

console.log(`done — ${todo.length} clip(s) written to public/voices`);
