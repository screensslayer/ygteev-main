// Site-admin direct upload to the YGTeeV-official For You feed. Mirrors
// pastor-create-mux-upload but inserts a `scope='ygteev_official'`
// feed_posts row (no group_id) and a `scope='global'` videos row. The
// post lands as `status='draft'`; admin uses pastor_publish_feed_post
// (which already accepts admin callers via _can_manage_feed_post) to
// publish once Mux finishes encoding.
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
  console.error(`[admin-create-feed-video-upload] ${stage}:`, detail);
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
  // Site-admin gate
  const { data: isAdmin, error: adminErr } = await supabaseAnon.rpc('is_site_admin', {
    _user_id: user.id
  });
  if (adminErr) return fail('admin-check-failed', 500, adminErr.message);
  if (!isAdmin) return fail('forbidden-not-site-admin', 403, null);
  let body;
  try {
    body = await req.json();
  } catch (e) {
    return fail('bad-json', 400, String(e));
  }
  const title = body.title ? String(body.title).trim() : null;
  const caption = body.caption ? String(body.caption).trim() : null;
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
    title: title ?? 'YGTeeV official',
    scope: 'global',
    group_id: null,
    policy: 'public',
    status: 'uploading',
    views: 0,
    mux_upload_id: muxUploadId,
    created_by: user.id
  }).select('id').single();
  if (vErr || !vRow) return fail('videos-insert-failed', 500, vErr?.message);
  const { data: pRow, error: pErr } = await supabaseService.from('feed_posts').insert({
    post_type: 'video',
    scope: 'ygteev_official',
    group_id: null,
    source_kind: 'ygteev_admin_upload',
    title: title,
    caption: caption,
    video_id: vRow.id,
    status: 'draft',
    created_by: user.id
  }).select('id').single();
  if (pErr || !pRow) return fail('feed_posts-insert-failed', 500, pErr?.message);
  return json({
    upload_url: uploadUrl,
    mux_upload_id: muxUploadId,
    video_id: vRow.id,
    post_id: pRow.id
  });
});
