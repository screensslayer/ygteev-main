// Cron-callable: enumerate active instagram_sources, fire one Apify run per
// source, log a row in instagram_scrape_jobs. Apify webhooks back to
// /apify-scrape-webhook?job_id=<id> when each run finishes.
//
// v5: read results_limit from each instagram_sources row instead of a
// hardcoded constant — lets site-admin showcase channels (FGTeeV etc.)
// pull more than the per-group default 25.
import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from 'jsr:@supabase/supabase-js@2';
const APIFY_ACTOR_ID = 'shu8hvrXbJbY3Eb9W';
const DEFAULT_RESULTS_LIMIT = 25;
const INCREMENTAL_OVERLAP_HOURS = 6;
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, x-cron-secret',
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
  console.error(`[trigger-instagram-scrapes] ${stage}:`, detail);
  return json({
    error: stage,
    status,
    detail
  }, status);
}
function formatApifyDate(d) {
  return d.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric'
  });
}
Deno.serve(async (req)=>{
  if (req.method === 'OPTIONS') return new Response(null, {
    headers: corsHeaders
  });
  if (req.method !== 'POST') return fail('method-not-allowed', 405, req.method);
  const cronSecret = Deno.env.get('CRON_SECRET');
  const bearerHeader = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
  const cronSecretHeader = req.headers.get('x-cron-secret');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const authorized = bearerHeader === serviceKey || cronSecret && cronSecretHeader === cronSecret;
  if (!authorized) return fail('unauthorized', 401, null);
  const apifyToken = Deno.env.get('APIFY_TOKEN');
  if (!apifyToken) return fail('missing-apify-token', 500, 'set APIFY_TOKEN secret');
  const supabase = createClient(Deno.env.get('SUPABASE_URL'), serviceKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  });
  // Optional body: { source_ids?: uuid[] } — when provided, only those
  // sources are scraped (used for manual one-off admin triggers).
  let targetIds = null;
  try {
    const body = req.headers.get('content-length') ? await req.json() : null;
    if (body && Array.isArray(body.source_ids) && body.source_ids.length > 0) {
      targetIds = body.source_ids.map((s)=>String(s));
    }
  } catch  {}
  let query = supabase.from('instagram_sources').select('id, group_id, handle, last_scraped_at, results_limit').eq('is_active', true);
  if (targetIds) query = query.in('id', targetIds);
  const { data: sources, error: srcErr } = await query;
  if (srcErr) return fail('sources-query-failed', 500, srcErr.message);
  if (!sources || sources.length === 0) return json({
    kicked: 0,
    message: 'no matching active sources'
  });
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const results = [];
  for (const src of sources){
    const isFirstScrape = src.last_scraped_at == null;
    const resultsLimit = src.results_limit ?? DEFAULT_RESULTS_LIMIT;
    const { data: jobRow, error: jobErr } = await supabase.from('instagram_scrape_jobs').insert({
      source_id: src.id,
      status: 'started'
    }).select('id').single();
    if (jobErr || !jobRow) {
      results.push({
        source_id: src.id,
        handle: src.handle,
        status: 'failed',
        error: 'job-insert-failed'
      });
      continue;
    }
    const webhookUrl = `${supabaseUrl}/functions/v1/apify-scrape-webhook?job_id=${jobRow.id}`;
    const webhooksConfig = [
      {
        eventTypes: [
          'ACTOR.RUN.SUCCEEDED',
          'ACTOR.RUN.FAILED',
          'ACTOR.RUN.TIMED_OUT',
          'ACTOR.RUN.ABORTED'
        ],
        requestUrl: webhookUrl
      }
    ];
    const webhooksParam = btoa(JSON.stringify(webhooksConfig));
    const apifyInput = {
      directUrls: [
        `https://www.instagram.com/${src.handle}/`
      ],
      resultsType: 'posts',
      resultsLimit: resultsLimit
    };
    let mode = `initial-${resultsLimit}`;
    if (!isFirstScrape) {
      const since = new Date(new Date(src.last_scraped_at).getTime() - INCREMENTAL_OVERLAP_HOURS * 3_600_000);
      apifyInput.onlyPostsNewerThan = formatApifyDate(since);
      mode = `incremental-since-${apifyInput.onlyPostsNewerThan}`;
    }
    let runResp;
    try {
      runResp = await fetch(`https://api.apify.com/v2/acts/${APIFY_ACTOR_ID}/runs?webhooks=${webhooksParam}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apifyToken}`
        },
        body: JSON.stringify(apifyInput)
      });
    } catch (e) {
      await supabase.from('instagram_scrape_jobs').update({
        status: 'failed',
        finished_at: new Date().toISOString(),
        error_message: `fetch-failed: ${e}`
      }).eq('id', jobRow.id);
      results.push({
        source_id: src.id,
        handle: src.handle,
        status: 'failed',
        error: String(e)
      });
      continue;
    }
    if (!runResp.ok) {
      const t = await runResp.text();
      await supabase.from('instagram_scrape_jobs').update({
        status: 'failed',
        finished_at: new Date().toISOString(),
        error_message: `apify ${runResp.status}: ${t.slice(0, 500)}`
      }).eq('id', jobRow.id);
      results.push({
        source_id: src.id,
        handle: src.handle,
        status: 'failed',
        error: `apify-${runResp.status}`
      });
      continue;
    }
    const runJson = await runResp.json();
    const apifyRunId = runJson?.data?.id;
    await supabase.from('instagram_scrape_jobs').update({
      apify_run_id: apifyRunId
    }).eq('id', jobRow.id);
    results.push({
      source_id: src.id,
      handle: src.handle,
      status: 'started',
      run_id: apifyRunId,
      mode,
      results_limit: resultsLimit
    });
  }
  return json({
    kicked: results.length,
    results
  });
});
