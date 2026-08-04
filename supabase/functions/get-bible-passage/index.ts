// get-bible-passage — the canonical Bible-text endpoint (CLAUDE.md).
// POST { reference: "John 1:1-14", translation?: "ESV" } -> { reference,
// translation, text }. ESV comes from Crossway's api.esv.org (requires the
// ESV_API_KEY secret; same license/key as the iOS app). Responses cache in
// bible_cache for 30 days keyed on translation+reference, so Crossway sees
// each passage roughly once a month regardless of player count.
// Verse text is NEVER stored anywhere else or bundled into clients.
// JWT required (default verify_jwt) — called by signed-in app/game clients.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json"
};
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const body = await req.json().catch(() => null);
    const reference = typeof body?.reference === "string" ? body.reference.trim().slice(0, 120) : "";
    const translation = (typeof body?.translation === "string" ? body.translation : "ESV").trim().toUpperCase().slice(0, 12);
    if (!reference) return json({ error: "missing_reference" }, 400);
    if (translation !== "ESV") return json({ error: "translation_unavailable", translation }, 400);
    const cacheKey = `${translation}:${reference.toLowerCase().replace(/\s+/g, " ")}`;
    const admin = createClient(Deno.env.get("SUPABASE_URL"), Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"));
    const { data: hit } = await admin.from("bible_cache")
      .select("reference, translation, passage_text, expires_at")
      .eq("cache_key", cacheKey).gt("expires_at", new Date().toISOString()).maybeSingle();
    if (hit) return json({ reference: hit.reference, translation: hit.translation, text: hit.passage_text, cached: true });
    const ESV_KEY = Deno.env.get("ESV_API_KEY") ?? "";
    if (!ESV_KEY) return json({ error: "translation_unavailable", detail: "esv_key_missing" }, 503);
    const qs = new URLSearchParams({
      q: reference,
      "include-passage-references": "false",
      "include-verse-numbers": "true",
      "include-first-verse-numbers": "true",
      "include-footnotes": "false",
      "include-headings": "false",
      "include-short-copyright": "true",
      "indent-paragraphs": "0",
      "indent-poetry": "false"
    });
    const res = await fetch(`https://api.esv.org/v3/passage/text/?${qs}`, {
      headers: { "Authorization": `Token ${ESV_KEY}` }
    });
    if (!res.ok) {
      console.log("[get-bible-passage] esv error", res.status, await res.text());
      return json({ error: "upstream_failed", status: res.status }, 502);
    }
    const j = await res.json();
    const text = (j?.passages?.[0] ?? "").trim();
    if (!text) return json({ error: "passage_not_found", reference }, 404);
    const canonical = j?.canonical || reference;
    await admin.from("bible_cache").upsert({
      cache_key: cacheKey,
      translation,
      reference: canonical,
      passage_text: text,
      updated_at: new Date().toISOString(),
      expires_at: new Date(Date.now() + 30 * 86400000).toISOString()
    }, { onConflict: "cache_key" });
    return json({ reference: canonical, translation, text, cached: false });
  } catch (e) {
    return json({ error: "unhandled", detail: String(e?.message ?? e) }, 500);
  }
});
function json(payload, status = 200) {
  return new Response(JSON.stringify(payload), { status, headers: cors });
}
