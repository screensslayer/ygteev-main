// v2: lowercase UUID comparisons (Swift sends uppercase UUIDs, Postgres
// returns lowercase) + verbose logging at each stage so failures are
// debuggable from Supabase Edge Function logs.
import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from 'jsr:@supabase/supabase-js@2';
const MUX_API = 'https://api.mux.com/video/v1/uploads';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS'
};
function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json'
    }
  });
}
function fail(stage, status, detail) {
  console.error(`[pastor-create-plan-video-upload] ${stage}:`, detail);
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
  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader) return fail('no-auth-header', 401, null);
  const supabaseAnon = createClient(Deno.env.get('SUPABASE_URL'), Deno.env.get('SUPABASE_ANON_KEY'), {
    global: {
      headers: {
        Authorization: authHeader
      }
    }
  });
  const { data: { user }, error: userErr } = await supabaseAnon.auth.getUser();
  if (userErr || !user) return fail('auth-getuser-failed', 401, userErr?.message);
  let body;
  try {
    body = await req.json();
  } catch (e) {
    return fail('bad-json', 400, String(e));
  }
  // Normalize all UUIDs to lowercase. Swift's UUID.uuidString uppercases
  // (e.g. "B91B8469-..."), Postgres returns lowercase ("b91b8469-..."),
  // and we compare these later — a strict !== will always fail without
  // the toLowerCase.
  const planId = String(body.plan_id ?? '').trim().toLowerCase();
  const planDayId = String(body.plan_day_id ?? '').trim().toLowerCase();
  const planBlockId = String(body.plan_block_id ?? '').trim().toLowerCase();
  const title = body.title ? String(body.title).trim() : null;
  console.log('[pastor-create-plan-video-upload] body received:', {
    user_id: user.id,
    planId,
    planDayId,
    planBlockId,
    hasTitle: !!title
  });
  if (!planId) return fail('plan_id-required', 400, body);
  if (!planDayId) return fail('plan_day_id-required', 400, body);
  if (!planBlockId) return fail('plan_block_id-required', 400, body);
  const { data: canEdit, error: canErr } = await supabaseAnon.rpc('_pastor_can_edit_plan', {
    _plan_id: planId
  });
  if (canErr) return fail('edit-check-failed', 500, canErr.message);
  if (!canEdit) return fail('forbidden-not-plan-pastor', 403, {
    planId
  });
  const { data: dayRow, error: dayErr } = await supabaseAnon.from('bible_plan_days').select('id, plan_id').eq('id', planDayId).maybeSingle();
  if (dayErr) return fail('day-lookup-failed', 500, dayErr.message);
  if (!dayRow) return fail('day-not-found', 400, {
    planDayId
  });
  // Both sides already lowercased above.
  const dayPlan = String(dayRow.plan_id ?? '').toLowerCase();
  if (dayPlan !== planId) {
    return fail('day-not-in-plan', 400, {
      expected_plan: planId,
      day_belongs_to: dayPlan,
      day_id: planDayId
    });
  }
  const muxId = Deno.env.get('MUX_TOKEN_ID');
  const muxSecret = Deno.env.get('MUX_TOKEN_SECRET');
  if (!muxId || !muxSecret) return fail('missing-mux-credentials', 500, null);
  const muxAuth = 'Basic ' + btoa(`${muxId}:${muxSecret}`);
  let muxResp;
  try {
    muxResp = await fetch(MUX_API, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': muxAuth
      },
      body: JSON.stringify({
        cors_origin: '*',
        new_asset_settings: {
          playback_policy: [
            'public'
          ],
          video_quality: 'basic'
        }
      })
    });
  } catch (e) {
    return fail('mux-fetch-failed', 502, String(e));
  }
  if (!muxResp.ok) {
    const t = await muxResp.text();
    return fail('mux-non-200', muxResp.status, t);
  }
  const muxJson = await muxResp.json();
  const uploadUrl = muxJson?.data?.url;
  const muxUploadId = muxJson?.data?.id;
  if (!uploadUrl || !muxUploadId) return fail('mux-bad-response', 502, muxJson);
  const supabaseService = createClient(Deno.env.get('SUPABASE_URL'), Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'), {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  });
  const { data: vRow, error: vErr } = await supabaseService.from('videos').insert({
    title: title ?? 'Plan video',
    scope: 'plan',
    group_id: null,
    plan_day_id: planDayId,
    plan_block_id: planBlockId,
    policy: 'public',
    status: 'uploading',
    views: 0,
    mux_upload_id: muxUploadId,
    created_by: user.id
  }).select('id').single();
  if (vErr || !vRow) return fail('videos-insert-failed', 500, vErr?.message);
  console.log('[pastor-create-plan-video-upload] ok', {
    video_id: vRow.id,
    mux_upload_id: muxUploadId
  });
  return json({
    upload_url: uploadUrl,
    mux_upload_id: muxUploadId,
    video_id: vRow.id
  });
});
