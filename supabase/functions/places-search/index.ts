// places-search — server-side proxy for Google Places so the pastor
// onboarding frontend needs no Google key of its own. Reuses the
// backend's GOOGLE_MAPS_API_KEY secret and the same Places API (New)
// endpoints discover-city already uses with this key.
//
//   POST { op: "search",  q, near? }   church text search biased to near;
//                                      results include website + domain
//   POST { op: "details", place_id }   name/address/geo/website/domain
//   POST { op: "geocode", q }          city or ZIP -> { lat, lng, label }
//
// Auth: signed-in users only (screen 2 comes after account creation).
// `near` may be "lat,lng", a ZIP, or a city string — geocoded as needed.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json",
};
const FIELDS = "places.id,places.displayName,places.formattedAddress,places.location,places.websiteUri";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) return json({ error: "unauthorized" }, 401);
    const userClient = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData } = await userClient.auth.getUser();
    if (!userData?.user) return json({ error: "unauthorized" }, 401);

    const KEY = Deno.env.get("GOOGLE_MAPS_API_KEY") ?? "";
    if (!KEY) return json({ error: "maps_not_configured" }, 500);
    const body = await req.json().catch(() => null);
    const op = body?.op;

    if (op === "geocode") {
      const q = String(body?.q ?? "").trim();
      if (!q) return json({ error: "missing_q" }, 400);
      const loc = await geocode(q, KEY);
      return loc ? json(loc) : json({ error: "geocode_failed" }, 404);
    }

    if (op === "details") {
      const pid = String(body?.place_id ?? "").trim();
      if (!pid) return json({ error: "missing_place_id" }, 400);
      const res = await fetch(`https://places.googleapis.com/v1/places/${encodeURIComponent(pid)}`, {
        headers: { "X-Goog-Api-Key": KEY, "X-Goog-FieldMask": "id,displayName,formattedAddress,location,websiteUri" },
      });
      if (!res.ok) return json({ error: "details_failed", status: res.status, detail: (await res.text()).slice(0, 300) }, 502);
      const p = await res.json();
      return json(placeOut(p, null));
    }

    if (op === "search") {
      const q = String(body?.q ?? "").trim();
      if (q.length < 2) return json({ results: [] });
      let bias: { lat: number; lng: number } | null = null;
      const near = String(body?.near ?? "").trim();
      if (/^-?\d+\.?\d*,-?\d+\.?\d*$/.test(near)) {
        const [lat, lng] = near.split(",").map(Number);
        bias = { lat, lng };
      } else if (near) {
        bias = await geocode(near, KEY);
      }
      const reqBody: Record<string, unknown> = {
        textQuery: /church|chapel|ministr|fellowship|temple|cathedral/i.test(q) ? q : q + " church",
        includedType: "church",
        maxResultCount: 6,
      };
      if (bias) {
        reqBody.locationBias = { circle: { center: { latitude: bias.lat, longitude: bias.lng }, radius: 50000 } };
      }
      const res = await fetch("https://places.googleapis.com/v1/places:searchText", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-Goog-Api-Key": KEY, "X-Goog-FieldMask": FIELDS },
        body: JSON.stringify(reqBody),
      });
      if (!res.ok) return json({ error: "search_failed", status: res.status, detail: (await res.text()).slice(0, 300) }, 502);
      const data = await res.json();
      const results = (data?.places ?? []).map((p: Record<string, unknown>) => placeOut(p, bias));
      return json({ results });
    }

    return json({ error: "unknown_op" }, 400);
  } catch (e) {
    return json({ error: "unhandled", detail: String((e as Error)?.message ?? e) }, 500);
  }
});

function placeOut(p: Record<string, unknown>, bias: { lat: number; lng: number } | null) {
  const loc = p.location as { latitude?: number; longitude?: number } | undefined;
  const lat = loc?.latitude ?? null, lng = loc?.longitude ?? null;
  const website = (p.websiteUri as string) ?? null;
  return {
    place_id: p.id,
    name: (p.displayName as { text?: string })?.text ?? "Unknown",
    address: (p.formattedAddress as string) ?? null,
    lat, lng,
    website,
    domain: domainOf(website),
    distance_mi: bias && lat != null && lng != null ? +haversineMi(bias.lat, bias.lng, lat, lng).toFixed(1) : null,
  };
}
async function geocode(q: string, key: string) {
  const r = await (await fetch(
    `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(q)}&key=${key}`,
  )).json();
  const g = r?.results?.[0];
  if (!g) return null;
  return {
    lat: g.geometry?.location?.lat,
    lng: g.geometry?.location?.lng,
    label: (g.address_components ?? []).find((c: { types: string[] }) => c.types.includes("locality"))?.short_name
      ?? g.formatted_address,
  };
}
function domainOf(website?: string | null) {
  if (!website) return null;
  try {
    const h = new URL(website).hostname.toLowerCase().replace(/^www\./, "");
    const parts = h.split(".");
    return parts.length > 2 ? parts.slice(-2).join(".") : h;
  } catch { return null; }
}
function haversineMi(a: number, b: number, c: number, d: number) {
  const R = 3958.8, dLat = (c - a) * Math.PI / 180, dLng = (d - b) * Math.PI / 180;
  const s = Math.sin(dLat / 2) ** 2 + Math.cos(a * Math.PI / 180) * Math.cos(c * Math.PI / 180) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(s));
}
function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), { status, headers: cors });
}
