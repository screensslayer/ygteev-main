// Source of the (retired) `gen-eli-voice` Supabase edge function.
//
// Renders game dialogue with ElevenLabs and hands the mp3s straight back as
// base64, so clips can be written into this repo (public/voices/*.mp3)
// without the API key ever leaving Supabase.
//
//   POST { voiceId, lines: [{ name, text }, ...] }
//     -> { clips: [{ name, bytes, b64 }] }
//
// Keep batches small (3-4 lines); the response carries the audio inline.
// Deploy under the name `gen-eli-voice`, run tools/gen-intro-lines.mjs, then
// replace it with the 410 stub again — every call spends ElevenLabs credits,
// so it must not sit live.
const MODEL = "eleven_multilingual_v2";
// matched to the hand-made Eli clips (stability 50, similarity 75, style 0)
const SETTINGS = { stability: 0.5, similarity_boost: 0.75, style: 0, use_speaker_boost: true };

function toB64(bytes: Uint8Array): string {
  let s = "";
  const CH = 0x8000; // chunked so a long clip cannot blow the arg limit
  for (let i = 0; i < bytes.length; i += CH) {
    s += String.fromCharCode(...bytes.subarray(i, i + CH));
  }
  return btoa(s);
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return Response.json({ error: "POST only" }, { status: 405 });

  const key = (Deno.env.get("ELEVENLABS_API_KEY") ?? "").trim();
  if (!key) return Response.json({ error: "ELEVENLABS_API_KEY missing" }, { status: 401 });

  let body: Record<string, unknown> = {};
  try { body = await req.json(); } catch { /* defaults */ }

  const voiceId = String(body.voiceId ?? "");
  const lines = Array.isArray(body.lines) ? body.lines : [];
  if (!voiceId) return Response.json({ error: "voiceId required" }, { status: 400 });
  if (!lines.length) return Response.json({ error: "lines required" }, { status: 400 });
  if (lines.length > 5) return Response.json({ error: "max 5 lines per call" }, { status: 400 });

  const clips: Array<{ name: string; bytes: number; b64: string }> = [];
  for (const l of lines) {
    const name = String((l as Record<string, unknown>).name ?? "");
    const text = String((l as Record<string, unknown>).text ?? "");
    if (!text) {
      return Response.json({ error: `empty text for ${name}`, clips: clips.map((c) => c.name) }, { status: 400 });
    }

    const res = await fetch(
      `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}?output_format=mp3_44100_128`,
      {
        method: "POST",
        headers: { "xi-api-key": key, "Content-Type": "application/json" },
        body: JSON.stringify({ text, model_id: MODEL, voice_settings: SETTINGS }),
      },
    );
    if (!res.ok) {
      return Response.json({
        error: `elevenlabs ${res.status} on ${name}`,
        detail: (await res.text()).slice(0, 300),
        clips: clips.map((c) => c.name),
      }, { status: 502 });
    }
    const bytes = new Uint8Array(await res.arrayBuffer());
    clips.push({ name, bytes: bytes.length, b64: toB64(bytes) });
  }

  return Response.json({ clips });
});
