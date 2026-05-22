// Mux Video webhook receiver. Listens for the asset-lifecycle events we care
// about and updates public.videos accordingly.
//
// Events handled:
//   video.asset.ready           → status='ready', mux_playback_id, duration, aspect_ratio
//   video.asset.errored         → status='errored'
//   video.upload.asset_created  → link mux_asset_id onto the videos row created by
//                                  pastor-create-mux-upload (matched by mux_upload_id)
//
// Configure in Mux Dashboard → Settings → Webhooks:
//   URL: https://tkesywmshaicjmywbovn.supabase.co/functions/v1/mux-webhook
//   Events: all Video events (or at minimum the three above)
//
// Optional: set MUX_WEBHOOK_SIGNING_SECRET to verify Mux's signature header.
// Without it the webhook still works but skips signature verification.
import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from 'jsr:@supabase/supabase-js@2';
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
async function verifyMuxSignature(rawBody, header, secret) {
  if (!header) return false;
  // Mux-Signature: t=<unix_ts>,v1=<hex_hmac>
  const parts = Object.fromEntries(header.split(',').map((p)=>p.trim().split('=')));
  const ts = parts.t;
  const sig = parts.v1;
  if (!ts || !sig) return false;
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey('raw', enc.encode(secret), {
    name: 'HMAC',
    hash: 'SHA-256'
  }, false, [
    'sign'
  ]);
  const buf = await crypto.subtle.sign('HMAC', key, enc.encode(`${ts}.${rawBody}`));
  const hex = Array.from(new Uint8Array(buf)).map((b)=>b.toString(16).padStart(2, '0')).join('');
  // Constant-time-ish compare
  if (hex.length !== sig.length) return false;
  let same = 0;
  for(let i = 0; i < hex.length; i++)same |= hex.charCodeAt(i) ^ sig.charCodeAt(i);
  return same === 0;
}
Deno.serve(async (req)=>{
  if (req.method === 'OPTIONS') return new Response(null, {
    headers: corsHeaders
  });
  if (req.method !== 'POST') return json({
    error: 'method-not-allowed'
  }, 405);
  const rawBody = await req.text();
  const secret = Deno.env.get('MUX_WEBHOOK_SIGNING_SECRET') ?? Deno.env.get('MUX_WEBHOOK_SECRET');
  if (secret) {
    const ok = await verifyMuxSignature(rawBody, req.headers.get('mux-signature'), secret);
    if (!ok) {
      console.error('[mux-webhook] signature-verification-failed');
      return json({
        error: 'invalid-signature'
      }, 401);
    }
  }
  let body;
  try {
    body = JSON.parse(rawBody);
  } catch (e) {
    return json({
      error: 'bad-json',
      detail: String(e)
    }, 400);
  }
  const type = body?.type ?? '';
  const data = body?.data ?? {};
  console.log(`[mux-webhook] received: ${type}, asset_id=${data?.id ?? '(none)'}`);
  const supabase = createClient(Deno.env.get('SUPABASE_URL'), Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'), {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  });
  if (type === 'video.asset.ready') {
    const assetId = String(data?.id ?? '');
    if (!assetId) return json({
      error: 'no-asset-id'
    }, 400);
    const publicPlayback = (data?.playback_ids ?? []).find((p)=>p.policy === 'public');
    const playbackId = publicPlayback?.id ?? data?.playback_ids?.[0]?.id ?? null;
    const { data: updated, error } = await supabase.from('videos').update({
      status: 'ready',
      mux_playback_id: playbackId,
      duration_sec: data?.duration ?? null,
      aspect_ratio: data?.aspect_ratio ?? null
    }).eq('mux_asset_id', assetId).select('id').maybeSingle();
    if (error) {
      console.error('[mux-webhook] update-ready-failed', error);
      return json({
        error: error.message
      }, 500);
    }
    return json({
      ok: true,
      event: type,
      updated_video: updated?.id ?? null
    });
  }
  if (type === 'video.asset.errored') {
    const assetId = String(data?.id ?? '');
    if (!assetId) return json({
      error: 'no-asset-id'
    }, 400);
    const { error } = await supabase.from('videos').update({
      status: 'errored'
    }).eq('mux_asset_id', assetId);
    if (error) return json({
      error: error.message
    }, 500);
    return json({
      ok: true,
      event: type
    });
  }
  if (type === 'video.upload.asset_created') {
    // Direct-upload flow: link mux_asset_id onto the videos row that was created
    // with mux_upload_id by pastor-create-mux-upload.
    const uploadId = String(data?.id ?? '');
    const assetId = String(data?.asset_id ?? '');
    if (uploadId && assetId) {
      const { error } = await supabase.from('videos').update({
        mux_asset_id: assetId
      }).eq('mux_upload_id', uploadId);
      if (error) return json({
        error: error.message
      }, 500);
    }
    return json({
      ok: true,
      event: type
    });
  }
  // Other events: just ack so Mux doesn't retry.
  return json({
    ok: true,
    ignored: type
  });
});
