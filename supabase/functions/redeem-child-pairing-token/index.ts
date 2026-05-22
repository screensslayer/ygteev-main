// Kid's device (fresh install, not signed in) hits this endpoint with the
// pairing token (from QR) or numeric code. We exchange it for a Supabase
// session and return { access_token, refresh_token, user } so the iOS app
// can call supabase.auth.setSession(...) and stay signed in long-term.
//
// No JWT required (verify_jwt: false) — the bearer here IS the token itself.
//
// Request body:
//   { "token": "<32 hex>" }   // or { "numeric_code": "58271940" }
//
// Response:
//   {
//     "access_token": "...",
//     "refresh_token": "...",
//     "expires_at": <unix>,
//     "user": { "id": "<uuid>", "display_name": "Ezra Kim", ... }
//   }
//
// Tokens are single-use; redeemed_at is stamped on success.
import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from 'jsr:@supabase/supabase-js@2';
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
  console.error(`[redeem-child-pairing-token] ${stage}:`, detail);
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
  let body;
  try {
    body = await req.json();
  } catch (e) {
    return fail('bad-json', 400, String(e));
  }
  const tokenRaw = body.token ? String(body.token).trim() : '';
  const numericRaw = body.numeric_code ? String(body.numeric_code).trim() : '';
  if (!tokenRaw && !numericRaw) return fail('token-or-code-required', 400, null);
  const supabaseService = createClient(Deno.env.get('SUPABASE_URL'), Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'), {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  });
  // 1. Look up the unredeemed, unexpired pairing row
  const query = supabaseService.from('child_pairing_tokens').select('id, child_user_id, token, numeric_code, expires_at, redeemed_at').is('redeemed_at', null).gt('expires_at', new Date().toISOString());
  const lookup = tokenRaw ? query.eq('token', tokenRaw) : query.eq('numeric_code', numericRaw);
  const { data: pairing, error: pairErr } = await lookup.maybeSingle();
  if (pairErr) return fail('token-lookup-failed', 500, pairErr.message);
  if (!pairing) return fail('invalid-or-expired-token', 401, null);
  // 2. Fetch the child's synthetic email (needed for generateLink)
  const { data: childUser, error: childErr } = await supabaseService.auth.admin.getUserById(pairing.child_user_id);
  if (childErr || !childUser.user) return fail('child-user-not-found', 500, childErr?.message);
  const email = childUser.user.email;
  // 3. Generate a magiclink — its `properties.action_link` contains the tokens
  const { data: link, error: linkErr } = await supabaseService.auth.admin.generateLink({
    type: 'magiclink',
    email
  });
  if (linkErr || !link.properties?.action_link) {
    return fail('generate-link-failed', 500, linkErr?.message);
  }
  // The magiclink URL embeds access_token + refresh_token as fragment params.
  // We parse them out and hand them back to the iOS app directly.
  const actionUrl = new URL(link.properties.action_link);
  const hash = actionUrl.hash.startsWith('#') ? actionUrl.hash.slice(1) : actionUrl.hash;
  const params = new URLSearchParams(hash);
  const accessToken = params.get('access_token');
  const refreshToken = params.get('refresh_token');
  const expiresAt = params.get('expires_at');
  if (!accessToken || !refreshToken) {
    return fail('session-tokens-missing', 500, {
      action_link: link.properties.action_link,
      has_hash: !!hash
    });
  }
  // 4. Mark the pairing token redeemed (one-time use)
  const userAgent = req.headers.get('user-agent') ?? null;
  await supabaseService.from('child_pairing_tokens').update({
    redeemed_at: new Date().toISOString(),
    redeemed_from_user_agent: userAgent
  }).eq('id', pairing.id);
  // 5. Fetch profile for a nicer response
  const { data: profile } = await supabaseService.from('profiles').select('id, display_name, avatar_url, parent_account_id, date_of_birth, grade_year').eq('id', pairing.child_user_id).single();
  return json({
    access_token: accessToken,
    refresh_token: refreshToken,
    expires_at: expiresAt ? Number(expiresAt) : null,
    user: profile
  });
});
