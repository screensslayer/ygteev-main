// One-shot diagnostic: fetch an Apify dataset's items and summarize them.
// Caller passes dataset_id in the query string. Gated by CRON_SECRET so we
// don't leak scraped content publicly.
//
//   GET /functions/v1/debug-inspect-apify-dataset?dataset_id=XXX
//     header x-cron-secret: <CRON_SECRET>
import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
Deno.serve(async (req)=>{
  const url = new URL(req.url);
  const datasetId = url.searchParams.get('dataset_id');
  if (!datasetId) return new Response('dataset_id required', {
    status: 400
  });
  const cronSecret = Deno.env.get('CRON_SECRET');
  const provided = req.headers.get('x-cron-secret') ?? '';
  if (cronSecret && provided !== cronSecret) return new Response('unauthorized', {
    status: 401
  });
  const apifyToken = Deno.env.get('APIFY_TOKEN');
  if (!apifyToken) return new Response('missing APIFY_TOKEN', {
    status: 500
  });
  const resp = await fetch(`https://api.apify.com/v2/datasets/${datasetId}/items?token=${apifyToken}&format=json&clean=true`);
  if (!resp.ok) {
    return new Response(`apify ${resp.status}: ${await resp.text()}`, {
      status: 502
    });
  }
  const items = await resp.json();
  const summary = {
    total_items: items.length,
    // Per-item: just enough to diagnose
    items_summary: items.slice(0, 30).map((it)=>({
        type: it.type ?? null,
        productType: it.productType ?? null,
        isVideo: !!it.videoUrl,
        hasShortCode: !!it.shortCode,
        shortCode: it.shortCode ?? it.id ?? null,
        ownerUsername: it.ownerUsername ?? null,
        captionPreview: it.caption ? String(it.caption).slice(0, 60) : null,
        childPostsCount: Array.isArray(it.childPosts) ? it.childPosts.length : 0,
        hasMediaUrl: !!it.displayUrl,
        topLevelKeys: Object.keys(it).slice(0, 20)
      }))
  };
  return new Response(JSON.stringify(summary, null, 2), {
    headers: {
      'Content-Type': 'application/json'
    }
  });
});
