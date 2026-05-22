// v3: also reconcile rows that have a mux_upload_id but no mux_asset_id
// yet (the video.upload.asset_created event was missed). Resolves the
// asset_id via Mux Uploads API, then falls into the same asset-status
// flow as before.
import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from 'jsr:@supabase/supabase-js@2';
const MUX_UPLOADS_API = 'https://api.mux.com/video/v1/uploads';
const MUX_ASSETS_API = 'https://api.mux.com/video/v1/assets';
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
  console.error(`[mux-reconcile-pending] ${stage}:`, detail);
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
  const cronSecret = Deno.env.get('CRON_SECRET');
  const provided = req.headers.get('x-cron-secret') ?? '';
  if (cronSecret && provided !== cronSecret) return fail('unauthorized', 401, null);
  const muxId = Deno.env.get('MUX_TOKEN_ID');
  const muxSecret = Deno.env.get('MUX_TOKEN_SECRET');
  if (!muxId || !muxSecret) return fail('missing-mux-credentials', 500, null);
  const muxAuth = 'Basic ' + btoa(`${muxId}:${muxSecret}`);
  const supabase = createClient(Deno.env.get('SUPABASE_URL'), Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'), {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  });
  // Anything still uploading / processing — resolve upload→asset first if
  // needed, then check asset status.
  const { data: pending, error } = await supabase.from('videos').select('id, mux_upload_id, mux_asset_id, status').in('status', [
    'processing',
    'uploading'
  ]);
  if (error) return fail('query-pending-failed', 500, error.message);
  if (!pending || pending.length === 0) return json({
    scanned: 0
  });
  const reports = [];
  for (const row of pending){
    let assetId = row.mux_asset_id ?? null;
    // Step 1: if no asset yet, look up the upload to find the asset_id.
    if (!assetId && row.mux_upload_id) {
      const upResp = await fetch(`${MUX_UPLOADS_API}/${row.mux_upload_id}`, {
        headers: {
          'Authorization': muxAuth
        }
      });
      if (!upResp.ok) {
        reports.push({
          video_id: row.id,
          mux_upload_id: row.mux_upload_id,
          result: `upload-mux-${upResp.status}`
        });
        continue;
      }
      const upJson = await upResp.json();
      assetId = upJson?.data?.asset_id ?? null;
      const upStatus = upJson?.data?.status ?? '';
      if (!assetId) {
        // Upload still being ingested by Mux — leave it for next sweep.
        reports.push({
          video_id: row.id,
          result: `upload-status-${upStatus}`
        });
        continue;
      }
      // Persist the asset_id link immediately so subsequent sweeps skip
      // the uploads lookup.
      await supabase.from('videos').update({
        mux_asset_id: assetId
      }).eq('id', row.id);
    }
    if (!assetId) {
      reports.push({
        video_id: row.id,
        result: 'no-asset-and-no-upload'
      });
      continue;
    }
    // Step 2: check the asset's encoding status.
    const aResp = await fetch(`${MUX_ASSETS_API}/${assetId}`, {
      headers: {
        'Authorization': muxAuth
      }
    });
    if (!aResp.ok) {
      reports.push({
        video_id: row.id,
        mux_asset_id: assetId,
        result: `asset-mux-${aResp.status}`
      });
      continue;
    }
    const aJson = await aResp.json();
    const muxStatus = aJson?.data?.status ?? '';
    if (muxStatus === 'ready') {
      const publicPb = (aJson.data.playback_ids ?? []).find((p)=>p.policy === 'public');
      const playbackId = publicPb?.id ?? aJson.data.playback_ids?.[0]?.id ?? null;
      await supabase.from('videos').update({
        status: 'ready',
        mux_playback_id: playbackId,
        duration_sec: aJson.data.duration ?? null,
        aspect_ratio: aJson.data.aspect_ratio ?? null
      }).eq('id', row.id);
      reports.push({
        video_id: row.id,
        result: 'ready',
        playback_id: playbackId
      });
    } else if (muxStatus === 'errored') {
      await supabase.from('videos').update({
        status: 'errored'
      }).eq('id', row.id);
      reports.push({
        video_id: row.id,
        result: 'errored'
      });
    } else {
      reports.push({
        video_id: row.id,
        result: `asset-status-${muxStatus}`
      });
    }
  }
  return json({
    scanned: pending.length,
    reports
  });
});
