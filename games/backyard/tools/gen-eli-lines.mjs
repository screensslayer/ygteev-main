// Generate Eli's 20 rotating challenge lines with ElevenLabs.
//
//   ELEVENLABS_API_KEY=... node tools/gen-eli-lines.mjs [--force] [--only 3,7]
//
// The key is read from the environment ONLY — never passed as an argument
// (argv shows up in shell history and `ps`) and never written to disk.
// Lines are read straight out of dragon-garden-quest.jsx so the audio can
// never drift from the text the game renders.
//
// Writes public/voices/eli-quiz-{1..20}.mp3
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '..');
const SRC = path.join(ROOT, 'src/dragon-garden-quest.jsx');
const OUT = path.join(ROOT, 'public/voices');

const VOICE_ID = process.env.ELEVEN_VOICE_ID || '1GGB5d9bJDyyCaUwSGvD'; // YGTeeV old man
const MODEL = 'eleven_multilingual_v2';
// matched to the hand-made clips (stability 50, similarity 75, style 0)
const VOICE_SETTINGS = { stability: 0.5, similarity_boost: 0.75, style: 0, use_speaker_boost: true };

const key = process.env.ELEVENLABS_API_KEY;
if (!key) {
  console.error(`
Missing ELEVENLABS_API_KEY.

Run it like this so the key stays out of your shell history
(note the leading space, and the key never touches this repo):

   ELEVENLABS_API_KEY=xi-... node tools/gen-eli-lines.mjs
`);
  process.exit(1);
}

// ---- pull the 20 lines out of the game source ----
const src = fs.readFileSync(SRC, 'utf8');
const block = src.slice(src.indexOf('const ELI_QUIZ_LINES = ['), src.indexOf('];', src.indexOf('const ELI_QUIZ_LINES = [')));
const lines = [...block.matchAll(/\/\*\s*(\d+)\s*\*\/\s*"((?:[^"\\]|\\.)*)"/g)]
  .map((m) => ({ n: Number(m[1]), text: m[2].replace(/\\"/g, '"') }));
if (lines.length !== 20) {
  console.error(`Expected 20 lines in ELI_QUIZ_LINES, parsed ${lines.length}. Aborting.`);
  process.exit(1);
}

const args = process.argv.slice(2);
const force = args.includes('--force');
const onlyArg = args[args.indexOf('--only') + 1];
const only = args.includes('--only') && onlyArg ? new Set(onlyArg.split(',').map(Number)) : null;

fs.mkdirSync(OUT, { recursive: true });

let made = 0, skipped = 0;
for (const { n, text } of lines) {
  if (only && !only.has(n)) continue;
  const dest = path.join(OUT, `eli-quiz-${n}.mp3`);
  if (fs.existsSync(dest) && !force) { skipped++; continue; }

  const res = await fetch(
    `https://api.elevenlabs.io/v1/text-to-speech/${VOICE_ID}?output_format=mp3_44100_128`,
    {
      method: 'POST',
      headers: { 'xi-api-key': key, 'Content-Type': 'application/json' },
      body: JSON.stringify({ text, model_id: MODEL, voice_settings: VOICE_SETTINGS }),
    },
  );
  if (!res.ok) {
    console.error(`line ${n}: ElevenLabs ${res.status} — ${(await res.text()).slice(0, 300)}`);
    process.exit(1);
  }
  fs.writeFileSync(dest, Buffer.from(await res.arrayBuffer()));
  const kb = (fs.statSync(dest).size / 1024).toFixed(0);
  console.log(`✓ eli-quiz-${n}.mp3  ${kb}kB  "${text.slice(0, 52)}${text.length > 52 ? '…' : ''}"`);
  made++;
  await new Promise((r) => setTimeout(r, 350)); // be gentle with the API
}
console.log(`\ndone — ${made} generated, ${skipped} already present (use --force to redo)`);
