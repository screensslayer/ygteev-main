// One-shot reconciler. For cases where Apify finished a run but never
// posted the webhook back (or we missed it), look up the run's dataset_id
// from Apify and synthesize the webhook payload ourselves, then post it
// to apify-scrape-webhook so it can ingest the dataset.
//
// Body: { job_id: uuid, run_id: string }
import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
Deno.serve(async (req)=>{
  if (req.method !== 'POST') return new Response('method', {
    status: 405
  });
  const apifyToken = Deno.env.get('APIFY_TOKEN');
  if (!apifyToken) return new Response(JSON.stringify({
    error: 'no_apify_token'
  }), {
    status: 500
  });
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  let body;
  try {
    body = await req.json();
  } catch  {
    return new Response(JSON.stringify({
      error: 'bad_json'
    }), {
      status: 400
    });
  }
  const jobId = String(body.job_id ?? '');
  const runId = String(body.run_id ?? '');
  if (!jobId || !runId) return new Response(JSON.stringify({
    error: 'job_id_and_run_id_required'
  }), {
    status: 400
  });
  // 1. Look up the Apify run to find its dataset_id
  const runResp = await fetch(`https://api.apify.com/v2/actor-runs/${runId}?token=${apifyToken}`);
  if (!runResp.ok) {
    return new Response(JSON.stringify({
      error: 'apify_lookup_failed',
      status: runResp.status,
      detail: await runResp.text()
    }), {
      status: 502
    });
  }
  const runJson = await runResp.json();
  const datasetId = runJson?.data?.defaultDatasetId;
  const runStatus = runJson?.data?.status;
  if (!datasetId) {
    return new Response(JSON.stringify({
      error: 'no_dataset_id',
      run_status: runStatus,
      run: runJson?.data
    }), {
      status: 502
    });
  }
  // 2. Synthesize the webhook payload and POST to apify-scrape-webhook
  const synthetic = {
    eventType: 'ACTOR.RUN.SUCCEEDED',
    resource: {
      id: runId,
      status: runStatus ?? 'SUCCEEDED',
      defaultDatasetId: datasetId
    }
  };
  const ingestResp = await fetch(`${supabaseUrl}/functions/v1/apify-scrape-webhook?job_id=${encodeURIComponent(jobId)}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(synthetic)
  });
  const ingestText = await ingestResp.text();
  let ingestParsed = ingestText;
  try {
    ingestParsed = JSON.parse(ingestText);
  } catch  {}
  return new Response(JSON.stringify({
    ok: ingestResp.ok,
    run_status: runStatus,
    dataset_id: datasetId,
    ingest_status: ingestResp.status,
    ingest_result: ingestParsed
  }), {
    status: ingestResp.ok ? 200 : 502,
    headers: {
      'Content-Type': 'application/json'
    }
  });
});
