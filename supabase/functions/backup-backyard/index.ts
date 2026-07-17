// backup-backyard — snapshots the Backyard game into the private
// `backups` bucket so a full copy lives on our own backend, independent
// of GitHub/Pages.
//
//   POST {}                → snapshot under backups/backyard/{YYYY-MM-DD}/
//   POST { force: true }   → re-snapshot even if today's already exists
//
// What gets captured:
//   site/  — the LIVE deployed build fetched from backyard.ygteev.com
//            (index.html + every /assets/ chunk it references + dragon-lab)
//   src/   — the source files fetched from the public GitHub repo at main
//
// Idempotent per day. Restore = download the files from the bucket (site/
// is directly re-hostable on any static host).

import { createClient } from "npm:@supabase/supabase-js@2";

const SITE = "https://backyard.ygteev.com";
const RAW = "https://raw.githubusercontent.com/screensslayer/ygteev-main/main/games/backyard";
const SRC_FILES = [
  "index.html", "package.json", "vite.config.js", "README.md",
  "src/dragon-garden-quest.jsx", "src/main.jsx", "src/backend.js",
  "src/storage.js", "src/supabaseClient.js", "src/dragon-sfx.js",
  "public/dragon-lab.html", "public/CNAME",
];

Deno.serve(async (req) => {
  if (req.method !== "POST") return Response.json({ error: "POST only" }, { status: 405 });
  let body: { force?: boolean } = {};
  try { body = await req.json(); } catch { /* empty body is fine */ }

  const service = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const day = new Date().toISOString().slice(0, 10);
  const base = `backyard/${day}`;

  // one snapshot per day unless forced
  const { data: existing } = await service.storage.from("backups").list(`${base}/site`, { limit: 1 });
  if (existing && existing.length && !body.force) {
    return Response.json({ skipped: true, path: base });
  }

  const stored: { path: string; bytes: number }[] = [];
  const put = async (path: string, data: ArrayBuffer, contentType: string) => {
    const { error } = await service.storage.from("backups")
      .upload(`${base}/${path}`, data, { contentType, upsert: true });
    if (error) throw new Error(`upload ${path}: ${error.message}`);
    stored.push({ path, bytes: data.byteLength });
  };
  const fetchOk = async (url: string) => {
    const r = await fetch(url);
    if (!r.ok) throw new Error(`${r.status} ${url}`);
    return r;
  };

  try {
    // ---- live build ----
    const indexRes = await fetchOk(`${SITE}/index.html`);
    const indexHtml = await indexRes.text();
    await put("site/index.html", new TextEncoder().encode(indexHtml).buffer, "text/html");
    const assets = [...new Set(
      [...indexHtml.matchAll(/\/assets\/[A-Za-z0-9_.-]+\.(?:js|css)/g)].map((m) => m[0]),
    )];
    // the game chunk is referenced from inside the index chunk — scan js files for more assets
    const seen = new Set(assets);
    const queue = [...assets];
    while (queue.length) {
      const a = queue.shift()!;
      const r = await fetchOk(`${SITE}${a}`);
      const buf = await r.arrayBuffer();
      await put(`site${a}`, buf, a.endsWith(".css") ? "text/css" : "application/javascript");
      if (a.endsWith(".js")) {
        const text = new TextDecoder().decode(buf);
        for (const m of text.matchAll(/\.\/(dragon-garden-quest-[A-Za-z0-9_-]+\.js)/g)) {
          const rel = `/assets/${m[1]}`;
          if (!seen.has(rel)) { seen.add(rel); queue.push(rel); }
        }
      }
    }
    const labRes = await fetchOk(`${SITE}/dragon-lab.html`);
    await put("site/dragon-lab.html", await labRes.arrayBuffer(), "text/html");

    // ---- source files from the repo ----
    for (const f of SRC_FILES) {
      try {
        const r = await fetchOk(`${RAW}/${f}`);
        await put(`src/${f}`, await r.arrayBuffer(), "text/plain");
      } catch (_e) {
        // optional files (e.g. CNAME) may not exist — record and move on
        stored.push({ path: `src/${f} (MISSING)`, bytes: 0 });
      }
    }
  } catch (e) {
    return Response.json({ error: String(e), stored }, { status: 500 });
  }

  const totalBytes = stored.reduce((s, f) => s + f.bytes, 0);
  return Response.json({
    ok: true,
    path: base,
    files: stored.length,
    total_mb: +(totalBytes / 1048576).toFixed(2),
    manifest: stored.map((f) => f.path),
  });
});
