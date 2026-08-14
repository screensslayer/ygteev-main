// Source of the (retired) `gen-esv-verse-audio` Supabase edge function.
//
// It records Bible verses in ESV so the in-game read-along captions match
// the narration word-for-word. James is already done (108 verses). To record
// another book: deploy this as `gen-esv-verse-audio`, POST each section,
// then replace it with the 410 stub again — every call spends ElevenLabs
// credits, so it must not sit live.
//
//   POST { reference: "James 1:1-18", max?: 12, force?: false }
//     -> { generated: [...], skipped, remaining }
//   Call repeatedly until remaining is 0 (edge functions have a wall-clock cap).
//
// The existing verse_audio rows are NLT (bible_id d6e14a625393b4da-01) and
// drive the iOS daily plans — those are NEVER touched. ESV rows are written
// under bible_id 'ESV' with the exact narrated text in verse_text.
import { createClient } from "npm:@supabase/supabase-js@2";

const BIBLE_ID = "ESV";
const DEFAULT_VOICE = "NPJ9YKwI4PhhZaBPyKlD";
const ELEVEN_MODEL = "eleven_multilingual_v2";
const BUCKET = "verse-audio";

const BOOK_IDS: Record<string, string> = {
  "james": "JAS", "john": "JHN", "romans": "ROM", "ephesians": "EPH",
  "galatians": "GAL", "philippians": "PHP", "hebrews": "HEB",
  "1 peter": "1PE", "proverbs": "PRO", "acts": "ACT",
};

function parseRef(ref: string) {
  const m = ref.trim().match(/^(.+?)\s+(\d+):(\d+)(?:-(\d+))?$/);
  if (!m) return null;
  const book = BOOK_IDS[m[1].trim().toLowerCase()];
  if (!book) return null;
  return { book, chapter: +m[2], from: +m[3], to: m[4] ? +m[4] : +m[3] };
}

// ESV returns the passage with [n] verse markers; split it back into verses
// so each recording is exactly one verse and sections can share files.
function splitVerses(raw: string): Record<number, string> {
  const body = raw.replace(/\s*\(ESV\)\s*$/, "").trim();
  const out: Record<number, string> = {};
  const parts = body.split(/\[(\d+)\]/).filter((p) => p !== "");
  for (let i = 0; i + 1 < parts.length; i += 2) {
    const n = parseInt(parts[i], 10);
    if (!isNaN(n)) out[n] = parts[i + 1].replace(/\s+/g, " ").trim();
  }
  return out;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return Response.json({ error: "POST only" }, { status: 405 });

  const esvKey = (Deno.env.get("ESV_API_KEY") ?? "").trim();
  const elevenKey = (Deno.env.get("ELEVENLABS_API_KEY") ?? "").trim();
  if (!esvKey) return Response.json({ error: "ESV_API_KEY missing" }, { status: 401 });
  if (!elevenKey) return Response.json({ error: "ELEVENLABS_API_KEY missing" }, { status: 401 });

  let body: Record<string, unknown> = {};
  try { body = await req.json(); } catch { /* defaults */ }

  const ref = String(body.reference ?? "");
  const parsed = parseRef(ref);
  if (!parsed) return Response.json({ error: `unparseable reference: ${ref}` }, { status: 400 });
  const max = Math.max(1, Math.min(20, Number(body.max ?? 12)));
  const force = body.force === true;
  const voiceId = String(body.voiceId ?? DEFAULT_VOICE);

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const esvRes = await fetch(
    "https://api.esv.org/v3/passage/text/?" + new URLSearchParams({
      q: ref,
      "include-headings": "false",
      "include-footnotes": "false",
      "include-verse-numbers": "true",
      "include-short-copyright": "false",
      "include-passage-references": "false",
      "indent-paragraphs": "0",
    }),
    { headers: { Authorization: `Token ${esvKey}` } },
  );
  if (!esvRes.ok) {
    return Response.json(
      { error: `esv ${esvRes.status}`, detail: (await esvRes.text()).slice(0, 300) },
      { status: 502 },
    );
  }
  const esvJson = await esvRes.json();
  const verses = splitVerses((esvJson.passages ?? []).join("\n"));

  const { data: existing } = await supabase
    .from("verse_audio")
    .select("verse")
    .eq("bible_id", BIBLE_ID).eq("voice_id", voiceId)
    .eq("book_id", parsed.book).eq("chapter", parsed.chapter)
    .gte("verse", parsed.from).lte("verse", parsed.to);
  const have = new Set((existing ?? []).map((r: { verse: number }) => r.verse));

  const todo: number[] = [];
  for (let v = parsed.from; v <= parsed.to; v++) {
    if (!verses[v]) continue;
    if (have.has(v) && !force) continue;
    todo.push(v);
  }

  const generated: string[] = [];
  for (const v of todo.slice(0, max)) {
    const text = verses[v];
    const tts = await fetch(
      `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}?output_format=mp3_44100_128`,
      {
        method: "POST",
        headers: { "xi-api-key": elevenKey, "Content-Type": "application/json" },
        body: JSON.stringify({
          text,
          model_id: ELEVEN_MODEL,
          voice_settings: { stability: 0.5, similarity_boost: 0.75, style: 0, use_speaker_boost: true },
        }),
      },
    );
    if (!tts.ok) {
      return Response.json({
        error: `elevenlabs ${tts.status} on verse ${v}`,
        detail: (await tts.text()).slice(0, 300), generated,
      }, { status: 502 });
    }
    const bytes = new Uint8Array(await tts.arrayBuffer());
    const path = `${BIBLE_ID}/${voiceId}/${parsed.book}/${parsed.chapter}/${v}.mp3`;
    const up = await supabase.storage.from(BUCKET).upload(path, bytes, {
      contentType: "audio/mpeg", upsert: true,
    });
    if (up.error) {
      return Response.json({ error: `upload: ${up.error.message}`, generated }, { status: 500 });
    }

    // 128kbps -> bytes/16000 is seconds; close enough to schedule captions,
    // and the client refines it from the real media duration on playback.
    const dur = +(bytes.length / 16000).toFixed(2);
    const { error: dbErr } = await supabase.from("verse_audio").upsert({
      bible_id: BIBLE_ID, voice_id: voiceId, book_id: parsed.book,
      chapter: parsed.chapter, verse: v, storage_path: path,
      duration_seconds: dur, char_count: text.length, verse_text: text,
    }, { onConflict: "bible_id,voice_id,book_id,chapter,verse" });
    if (dbErr) return Response.json({ error: `db: ${dbErr.message}`, generated }, { status: 500 });

    generated.push(`${parsed.book} ${parsed.chapter}:${v}`);
  }

  return Response.json({
    generated,
    skipped: (parsed.to - parsed.from + 1) - todo.length,
    remaining: Math.max(0, todo.length - generated.length),
  });
});
