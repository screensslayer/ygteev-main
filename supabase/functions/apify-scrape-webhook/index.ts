// v6: fix videos enum values — scope='youthGroup' (camelCase, not 'group'),
// status='processing' (not 'preparing'). Mux body unchanged from v5.
import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from 'jsr:@supabase/supabase-js@2';
const MUX_ASSETS_API = 'https://api.mux.com/video/v1/assets';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS'
};
function json(b, s = 200) {
  return new Response(JSON.stringify(b), {
    status: s,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json'
    }
  });
}
function fail(stage, status, detail) {
  console.error(`[apify-scrape-webhook] ${stage}:`, detail);
  return json({
    error: stage,
    status,
    detail
  }, status);
}
Deno.serve(async (req)=>{
  if (req.method === 'OPTIONS') return new Response(null, {
    headers: corsHeaders
  });
  if (req.method !== 'POST') return fail('method-not-allowed', 405, req.method);
  const apifyToken = Deno.env.get('APIFY_TOKEN');
  if (!apifyToken) return fail('missing-apify-token', 500, null);
  const muxId = Deno.env.get('MUX_TOKEN_ID');
  const muxSecret = Deno.env.get('MUX_TOKEN_SECRET');
  if (!muxId || !muxSecret) return fail('missing-mux-credentials', 500, null);
  const muxAuth = 'Basic ' + btoa(`${muxId}:${muxSecret}`);
  const url = new URL(req.url);
  const jobId = url.searchParams.get('job_id') ?? '';
  if (!jobId) return fail('job_id-query-param-required', 400, null);
  let body;
  try {
    body = await req.json();
  } catch (e) {
    return fail('bad-json', 400, String(e));
  }
  const eventType = String(body.eventType ?? '');
  const resource = body.resource ?? {};
  const runId = String(resource.id ?? '');
  const datasetId = String(resource.defaultDatasetId ?? '');
  const supabase = createClient(Deno.env.get('SUPABASE_URL'), Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'), {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  });
  const { data: job, error: jobErr } = await supabase.from('instagram_scrape_jobs').select('id, source_id').eq('id', jobId).maybeSingle();
  if (jobErr || !job) return fail('job-not-found', 404, jobErr?.message);
  const { data: source, error: srcErr } = await supabase.from('instagram_sources').select('id, group_id, handle').eq('id', job.source_id).maybeSingle();
  if (srcErr || !source) {
    await supabase.from('instagram_scrape_jobs').update({
      status: 'failed',
      finished_at: new Date().toISOString(),
      error_message: 'source-not-found'
    }).eq('id', jobId);
    return fail('source-not-found', 404, srcErr?.message);
  }
  if (eventType && !eventType.endsWith('SUCCEEDED')) {
    await supabase.from('instagram_scrape_jobs').update({
      status: eventType.endsWith('FAILED') ? 'failed' : eventType.endsWith('TIMED_OUT') ? 'timeout' : 'failed',
      finished_at: new Date().toISOString(),
      error_message: `apify event: ${eventType}`,
      apify_dataset_id: datasetId || null,
      apify_run_id: runId || null
    }).eq('id', jobId);
    return json({
      ok: true,
      ignored: eventType
    });
  }
  if (!datasetId) {
    await supabase.from('instagram_scrape_jobs').update({
      status: 'failed',
      finished_at: new Date().toISOString(),
      error_message: 'no-dataset-id-in-webhook'
    }).eq('id', jobId);
    return fail('no-dataset-id', 400, body);
  }
  let items = [];
  try {
    const dsResp = await fetch(`https://api.apify.com/v2/datasets/${datasetId}/items?token=${apifyToken}&format=json&clean=true`);
    if (!dsResp.ok) {
      const t = await dsResp.text();
      await supabase.from('instagram_scrape_jobs').update({
        status: 'failed',
        finished_at: new Date().toISOString(),
        error_message: `dataset-fetch-${dsResp.status}: ${t.slice(0, 300)}`,
        apify_dataset_id: datasetId,
        apify_run_id: runId
      }).eq('id', jobId);
      return fail('dataset-fetch-failed', 502, t);
    }
    items = await dsResp.json();
  } catch (e) {
    await supabase.from('instagram_scrape_jobs').update({
      status: 'failed',
      finished_at: new Date().toISOString(),
      error_message: `dataset-fetch-error: ${e}`
    }).eq('id', jobId);
    return fail('dataset-fetch-error', 502, String(e));
  }
  console.log(`[apify-scrape-webhook] dataset has ${items.length} items`);
  let created = 0;
  const itemReports = [];
  for (const item of items){
    const igType = String(item.type ?? '');
    const videoUrl = String(item.videoUrl ?? '');
    const shortCode = String(item.shortCode ?? item.id ?? '');
    const isVideo = igType === 'Video' || !!videoUrl;
    if (!isVideo || !videoUrl || !shortCode) {
      itemReports.push({
        shortCode: shortCode || '(none)',
        result: 'skipped-not-video',
        detail: `type=${igType}`
      });
      continue;
    }
    const handle = String(item.ownerUsername ?? source.handle);
    const caption = item.caption ? String(item.caption) : null;
    const igPostUrl = String(item.url ?? `https://www.instagram.com/p/${shortCode}/`);
    const { data: dup } = await supabase.from('feed_posts').select('id').eq('source_handle', `@${handle}`).eq('source_post_id', shortCode).maybeSingle();
    if (dup) {
      itemReports.push({
        shortCode,
        result: 'skipped-duplicate'
      });
      continue;
    }
    // Mux Create Asset — basic tier, HLS-only
    const muxBody = {
      input: [
        {
          url: videoUrl
        }
      ],
      playback_policy: [
        'public'
      ],
      video_quality: 'basic'
    };
    let muxResp;
    try {
      muxResp = await fetch(MUX_ASSETS_API, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': muxAuth
        },
        body: JSON.stringify(muxBody)
      });
    } catch (e) {
      itemReports.push({
        shortCode,
        result: 'mux-fetch-threw',
        detail: String(e)
      });
      continue;
    }
    if (!muxResp.ok) {
      const t = await muxResp.text();
      itemReports.push({
        shortCode,
        result: `mux-${muxResp.status}`,
        detail: t.slice(0, 400)
      });
      continue;
    }
    const muxJson = await muxResp.json();
    const muxAssetId = muxJson?.data?.id;
    if (!muxAssetId) {
      itemReports.push({
        shortCode,
        result: 'mux-no-asset-id'
      });
      continue;
    }
    const { data: vRow, error: vErr } = await supabase.from('videos').insert({
      title: item.caption ? String(item.caption).slice(0, 80) : `@${handle}`,
      scope: 'youthGroup',
      group_id: source.group_id,
      policy: 'public',
      status: 'processing',
      views: 0,
      mux_asset_id: muxAssetId,
      created_by: null
    }).select('id').single();
    if (vErr || !vRow) {
      itemReports.push({
        shortCode,
        result: 'videos-insert-failed',
        detail: vErr?.message
      });
      continue;
    }
    const { error: pErr } = await supabase.from('feed_posts').insert({
      post_type: 'video',
      scope: 'group',
      group_id: source.group_id,
      source_kind: 'instagram_scrape',
      source_url: igPostUrl,
      source_handle: `@${handle}`,
      source_post_id: shortCode,
      title: item.caption ? String(item.caption).split('\n')[0].slice(0, 120) : null,
      caption: caption,
      video_id: vRow.id,
      status: 'published',
      published_at: new Date().toISOString()
    });
    if (pErr) {
      itemReports.push({
        shortCode,
        result: 'feed_posts-insert-failed',
        detail: pErr.message
      });
      continue;
    }
    itemReports.push({
      shortCode,
      result: 'created'
    });
    created++;
  }
  await supabase.from('instagram_scrape_jobs').update({
    status: 'succeeded',
    finished_at: new Date().toISOString(),
    new_posts_count: created,
    apify_dataset_id: datasetId,
    apify_run_id: runId,
    error_message: created === 0 ? `0 created of ${items.length}: ${JSON.stringify(itemReports).slice(0, 800)}` : null
  }).eq('id', jobId);
  await supabase.from('instagram_sources').update({
    last_scraped_at: new Date().toISOString()
  }).eq('id', source.id);
  return json({
    ok: true,
    new_posts: created,
    total_items: items.length,
    item_reports: itemReports
  });
});
