// generate-verse-audio — builds pre-recorded narration for a daily-plan
// Read passage and stores it in the verse-audio bucket + verse_audio table.
//
//   POST { reference: "John 1:1-18", force?: boolean }
//   Headers:
//     x-elevenlabs-key  (required — passed per call, never stored)
//     x-bible-key       (required — api.bible key, passed per call)
//     x-voice-id        (optional — defaults to the YGTeeV narrator voice)
//
// Guards:
//   • The reference must appear in some bible_plan_days read part —
//     callers can only generate audio we actually want to exist.
//   • Existing rows are immutable unless force=true.
//
// Text pipeline mirrors the iOS app exactly (BibleAPIService +
// DailyPlanView.currentPassage): fetch the NLT chapter with verse-number
// markers, split on [n], trim, join verses with a single space, and track
// each verse's character range. ElevenLabs' character alignment then maps
// those ranges to start/end seconds so the client can highlight the verse
// being spoken.

import { createClient } from "npm:@supabase/supabase-js@2";

const BIBLE_ID = "d6e14a625393b4da-01"; // NLT — keep in sync with the iOS default
const DEFAULT_VOICE = "NPJ9YKwI4PhhZaBPyKlD";
const ELEVEN_MODEL = "eleven_multilingual_v2";

const BOOK_IDS: Record<string, string> = {
  "genesis": "GEN", "exodus": "EXO", "leviticus": "LEV", "numbers": "NUM",
  "deuteronomy": "DEU", "joshua": "JOS", "judges": "JDG", "ruth": "RUT",
  "1 samuel": "1SA", "2 samuel": "2SA", "1 kings": "1KI", "2 kings": "2KI",
  "1 chronicles": "1CH", "2 chronicles": "2CH", "ezra": "EZR", "nehemiah": "NEH",
  "esther": "EST", "job": "JOB", "psalms": "PSA", "psalm": "PSA",
  "proverbs": "PRO", "ecclesiastes": "ECC", "song of solomon": "SNG",
  "isaiah": "ISA", "jeremiah": "JER", "lamentations": "LAM", "ezekiel": "EZK",
  "daniel": "DAN", "hosea": "HOS", "joel": "JOL", "amos": "AMO",
  "obadiah": "OBA", "jonah": "JON", "micah": "MIC", "nahum": "NAM",
  "habakkuk": "HAB", "zephaniah": "ZEP", "haggai": "HAG", "zechariah": "ZEC",
  "malachi": "MAL", "matthew": "MAT", "mark": "MRK", "luke": "LUK",
  "john": "JHN", "acts": "ACT", "romans": "ROM", "1 corinthians": "1CO",
  "2 corinthians": "2CO", "galatians": "GAL", "ephesians": "EPH",
  "philippians": "PHP", "colossians": "COL", "1 thessalonians": "1TH",
  "2 thessalonians": "2TH", "1 timothy": "1TI", "2 timothy": "2TI",
  "titus": "TIT", "philemon": "PHM", "hebrews": "HEB", "james": "JAS",
  "1 peter": "1PE", "2 peter": "2PE", "1 john": "1JN", "2 john": "2JN",
  "3 john": "3JN", "jude": "JUD", "revelation": "REV",
};

function parseReference(reference: string) {
  const trimmed = reference.trim();
  let leftSide = trimmed, rightSide = "";
  const colon = trimmed.indexOf(":");
  if (colon >= 0) {
    leftSide = trimmed.slice(0, colon).trim();
    rightSide = trimmed.slice(colon + 1).trim();
  }
  const tokens = leftSide.split(/\s+/);
  if (tokens.length < 2) return null;
  const chapter = parseInt(tokens[tokens.length - 1], 10);
  if (!Number.isFinite(chapter)) return null;
  const bookName = tokens.slice(0, -1).join(" ");
  if (!rightSide) return { bookName, chapter, startVerse: 1, endVerse: Number.MAX_SAFE_INTEGER };
  const parts = rightSide.split("-");
  const start = parseInt(parts[0], 10);
  if (!Number.isFinite(start)) return null;
  const end = parts.length > 1 ? (parseInt(parts[1], 10) || start) : start;
  return { bookName, chapter, startVerse: start, endVerse: end };
}

// Same cleanup the iOS app applies before speaking (cleanVerseText).
function cleanVerse(raw: string): string {
  let s = raw.trim();
  if (s.startsWith("[")) {
    const close = s.indexOf("]");
    if (close >= 0) s = s.slice(close + 1).trim();
  }
  const firstSpace = s.search(/\s/);
  if (firstSpace > 0 && /^\d+$/.test(s.slice(0, firstSpace))) {
    s = s.slice(firstSpace + 1);
  }
  return s;
}

async function sha256Hex(text: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return Response.json({ error: "POST only" }, { status: 405 });
  }
  const elevenKey = req.headers.get("x-elevenlabs-key");
  const bibleKey = req.headers.get("x-bible-key");
  if (!elevenKey || !bibleKey) {
    return Response.json({ error: "missing x-elevenlabs-key / x-bible-key" }, { status: 401 });
  }
  const voiceId = req.headers.get("x-voice-id") || DEFAULT_VOICE;

  let body: { reference?: string; force?: boolean };
  try { body = await req.json(); } catch { return Response.json({ error: "bad json" }, { status: 400 }); }
  const reference = (body.reference || "").trim();
  if (!reference) return Response.json({ error: "missing reference" }, { status: 400 });

  const service = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Guard: only references that actually appear in a plan's read parts.
  const { data: days, error: daysErr } = await service
    .from("bible_plan_days")
    .select("sections");
  if (daysErr) return Response.json({ error: daysErr.message }, { status: 500 });
  const known = new Set<string>();
  for (const d of days ?? []) {
    const parts = d.sections?.read?.parts ?? [];
    for (const p of parts) if (p?.verses) known.add(String(p.verses).trim());
  }
  if (!known.has(reference)) {
    return Response.json({ error: "reference not used by any plan" }, { status: 403 });
  }

  // Skip work if already generated (idempotent batch runs).
  const { data: existing } = await service
    .from("verse_audio")
    .select("id, storage_path, duration_seconds")
    .eq("reference", reference).eq("bible_id", BIBLE_ID).eq("voice_id", voiceId)
    .maybeSingle();
  if (existing && !body.force) {
    return Response.json({ skipped: true, reference, ...existing });
  }

  // ---- 1. Fetch + parse the passage text (mirrors BibleAPIService) ----
  const parsed = parseReference(reference);
  if (!parsed) return Response.json({ error: "unparseable reference" }, { status: 400 });
  const bookId = BOOK_IDS[parsed.bookName.toLowerCase()];
  if (!bookId) return Response.json({ error: "unknown book" }, { status: 400 });

  const chapterUrl = `https://rest.api.bible/v1/bibles/${BIBLE_ID}/chapters/${bookId}.${parsed.chapter}?content-type=text&include-verse-numbers=true`;
  const chapterRes = await fetch(chapterUrl, { headers: { "api-key": bibleKey, "Accept": "application/json" } });
  if (!chapterRes.ok) {
    return Response.json({ error: `bible api ${chapterRes.status}` }, { status: 502 });
  }
  const chapterJson = await chapterRes.json();
  const content: string = chapterJson?.data?.content ?? "";

  const verseRe = /\[(\d+)\]\s+([\s\S]+?)(?=\[\d+\]|$)/g;
  const verses: { n: number; text: string }[] = [];
  for (const m of content.matchAll(verseRe)) {
    const n = parseInt(m[1], 10);
    if (n >= parsed.startVerse && n <= parsed.endVerse) {
      const text = cleanVerse(m[2]);
      if (text) verses.push({ n, text });
    }
  }
  if (!verses.length) return Response.json({ error: "no verses parsed" }, { status: 422 });

  // Join exactly like the iOS passage builder: verse text + single space.
  let fullText = "";
  const ranges: { v: number; start: number; end: number }[] = [];
  for (const v of verses) {
    const start = fullText.length;
    fullText += v.text;
    ranges.push({ v: v.n, start, end: fullText.length });
    fullText += " ";
  }
  fullText = fullText.trimEnd();

  // ---- 2. ElevenLabs synthesis with character alignment ----
  const ttsRes = await fetch(
    `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}/with-timestamps?output_format=mp3_44100_128`,
    {
      method: "POST",
      headers: { "xi-api-key": elevenKey, "Content-Type": "application/json" },
      body: JSON.stringify({
        text: fullText,
        model_id: ELEVEN_MODEL,
        voice_settings: { stability: 0.5, similarity_boost: 0.75 },
      }),
    },
  );
  if (!ttsRes.ok) {
    const detail = await ttsRes.text().catch(() => "");
    return Response.json({ error: `elevenlabs ${ttsRes.status}`, detail: detail.slice(0, 500) }, { status: 502 });
  }
  const tts = await ttsRes.json();
  const audioB64: string = tts.audio_base64;
  const starts: number[] = tts.alignment?.character_start_times_seconds ?? [];
  const ends: number[] = tts.alignment?.character_end_times_seconds ?? [];
  if (!audioB64) return Response.json({ error: "no audio in elevenlabs response" }, { status: 502 });

  const timings = ranges.map((r) => ({
    v: r.v,
    s: starts[Math.min(r.start, starts.length - 1)] ?? 0,
    e: ends[Math.min(r.end - 1, ends.length - 1)] ?? 0,
  }));
  const duration = ends.length ? ends[ends.length - 1] : null;

  // ---- 3. Upload + record ----
  const bin = Uint8Array.from(atob(audioB64), (c) => c.charCodeAt(0));
  const slug = reference.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
  const path = `${BIBLE_ID}/${voiceId}/${slug}.mp3`;

  const { error: upErr } = await service.storage
    .from("verse-audio")
    .upload(path, bin, { contentType: "audio/mpeg", upsert: !!body.force || !!existing });
  if (upErr) return Response.json({ error: `upload: ${upErr.message}` }, { status: 500 });

  const row = {
    reference,
    bible_id: BIBLE_ID,
    voice_id: voiceId,
    storage_path: path,
    duration_seconds: duration,
    verse_timings: timings,
    char_count: fullText.length,
    text_sha256: await sha256Hex(fullText),
  };
  const { error: rowErr } = await service
    .from("verse_audio")
    .upsert(row, { onConflict: "reference,bible_id,voice_id" });
  if (rowErr) return Response.json({ error: `db: ${rowErr.message}` }, { status: 500 });

  return Response.json({
    ok: true, reference, storage_path: path,
    duration_seconds: duration, verses: verses.length, chars: fullText.length,
  });
});
