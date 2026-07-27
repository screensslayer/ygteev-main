// Parent-only endpoint: create a managed under-13 child account + pairing
// token the parent's device displays as QR. Kid scans on their own device,
// hits redeem-child-pairing-token, gets a session, stays signed in via the
// standard Supabase refresh-token loop.
//
// Two invocation modes:
//
//   1. Parent-first (legacy) — parent taps "Add a kid" in the app and
//      types the child's name / dob / grade themselves. The parent's
//      device then hands the resulting pairing token to the kid to
//      redeem on a separate device.
//
//   2. Kid-first via signup handoff — the reimagined under-13
//      onboarding. The KID device (anonymous) creates a
//      `child_signup_handoffs` row with their name / dob / grade,
//      shows a QR encoding the row's nonce. Parent scans, is routed
//      into the app, and calls this endpoint with the nonce set.
//      When `signup_handoff_nonce` is present we pull demographics
//      SERVER-SIDE from the handoff row (client body values for
//      those fields are ignored), mint the child, and stamp the
//      resulting `child_user_id`, `pairing_token`, `numeric_code`,
//      `redeemed_at` back onto the handoff row so the kid's device
//      can poll for the token and finish the redeem.
//
// Requires parent has profiles.age_verified_at set (paid $0.99 / dev bypass)
// in both modes.
//
// Request body:
//   {
//     "family_id":            "<uuid>",
//     "first_name":           "Ezra",           // ignored if nonce set
//     "last_name":            "Kim",             // ignored if nonce set
//     "date_of_birth":        "2014-08-12",      // ignored if nonce set
//     "grade_year":           5,                  // ignored if nonce set
//     "avatar_url":           null,               // optional
//     "signup_handoff_nonce": "A3F72C81"          // optional — kid-first mode
//   }
//
// Response:
//   {
//     "child_user_id": "<uuid>",
//     "display_name":  "Ezra Kim",
//     "pairing_token": "<32 hex>",
//     "numeric_code":  "58271940",
//     "expires_at":    "<iso>"
//   }
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
  console.error(`[create-child-account] ${stage}:`, detail);
  return json({
    error: stage,
    status,
    detail
  }, status);
}
function randomHex(bytes) {
  const buf = new Uint8Array(bytes);
  crypto.getRandomValues(buf);
  return Array.from(buf, (b)=>b.toString(16).padStart(2, '0')).join('');
}
function randomNumeric(digits) {
  let s = '';
  const buf = new Uint8Array(digits);
  crypto.getRandomValues(buf);
  for(let i = 0; i < digits; i++)s += (buf[i] % 10).toString();
  return s;
}
Deno.serve(async (req)=>{
  if (req.method === 'OPTIONS') return new Response(null, {
    headers: corsHeaders
  });
  if (req.method !== 'POST') return fail('method-not-allowed', 405, req.method);
  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader) return fail('no-auth-header', 401, null);
  // Caller client (for auth.getUser + RLS-respecting reads)
  const supabaseAnon = createClient(Deno.env.get('SUPABASE_URL'), Deno.env.get('SUPABASE_ANON_KEY'), {
    global: {
      headers: {
        Authorization: authHeader
      }
    }
  });
  const { data: { user }, error: userErr } = await supabaseAnon.auth.getUser();
  if (userErr || !user) return fail('auth-getuser-failed', 401, userErr?.message ?? 'no user');
  // 1. Parse + validate input
  let body;
  try {
    body = await req.json();
  } catch (e) {
    return fail('bad-json', 400, String(e));
  }
  const familyId = String(body.family_id ?? '').trim();
  const avatarUrl = body.avatar_url ? String(body.avatar_url) : null;
  const handoffNonceRaw = body.signup_handoff_nonce ?? null;
  const handoffNonce = handoffNonceRaw != null
    ? String(handoffNonceRaw).trim().toUpperCase()
    : null;

  if (!familyId) return fail('family_id-required', 400, body);

  // Resolved fields — client-supplied by default, overridden by the
  // handoff row when signup_handoff_nonce is set.
  let firstName = String(body.first_name ?? '').trim();
  let lastName  = String(body.last_name  ?? '').trim();
  let dobStr    = String(body.date_of_birth ?? '').trim();
  let gradeYear = body.grade_year != null ? Number(body.grade_year) : null;
  let handoffRowId: string | null = null;

  // 1a. Kid-first mode: load the handoff row via service role and use
  //     its demographics as the source of truth. Fall through into
  //     the normal validation with those values below.
  if (handoffNonce) {
    const supabaseService_early = createClient(Deno.env.get('SUPABASE_URL'), Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'), {
      auth: { autoRefreshToken: false, persistSession: false }
    });
    const { data: handoffRow, error: handoffErr } = await supabaseService_early
      .from('child_signup_handoffs')
      .select('id, expires_at, redeemed_at, display_name, grade_year, date_of_birth')
      .eq('nonce', handoffNonce)
      .maybeSingle();
    if (handoffErr) return fail('handoff-lookup-failed', 500, handoffErr.message);
    if (!handoffRow) return fail('handoff-not-found', 404, handoffNonce);
    if (handoffRow.redeemed_at) return fail('handoff-already-redeemed', 409, handoffNonce);
    if (new Date(handoffRow.expires_at) < new Date()) {
      return fail('handoff-expired', 410, handoffNonce);
    }

    // display_name from the handoff is a single field. Use it as
    // firstName (no lastName split); it's already what the kid
    // chose to be called in-app.
    firstName = String(handoffRow.display_name ?? '').trim();
    lastName  = '';
    dobStr    = handoffRow.date_of_birth
      ? String(handoffRow.date_of_birth).slice(0, 10)
      : '';
    gradeYear = handoffRow.grade_year != null ? Number(handoffRow.grade_year) : null;
    handoffRowId = handoffRow.id;
  }

  if (!firstName) return fail('first_name-required', 400, body);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(dobStr)) return fail('date_of_birth-invalid', 400, body);
  const dob = new Date(dobStr);
  if (isNaN(+dob)) return fail('date_of_birth-unparseable', 400, body);
  if (gradeYear != null && (gradeYear < 1 || gradeYear > 20 || !Number.isInteger(gradeYear))) {
    return fail('grade_year-out-of-range', 400, gradeYear);
  }
  // 2. Caller must be a parent of this family + age-verified
  const { data: parentRow, error: parentErr } = await supabaseAnon.from('profiles').select('age_verified_at').eq('id', user.id).single();
  if (parentErr || !parentRow) return fail('profile-lookup-failed', 500, parentErr?.message);
  if (!parentRow.age_verified_at) return fail('age-verification-required', 403, 'pay $0.99 first');
  const { data: fmRow, error: fmErr } = await supabaseAnon.from('family_members').select('role').eq('family_id', familyId).eq('user_id', user.id).maybeSingle();
  if (fmErr) return fail('family-check-failed', 500, fmErr.message);
  if (!fmRow || fmRow.role !== 'parent') return fail('not-parent-of-family', 403, fmRow);
  // 3. Service-role client to do admin operations
  const supabaseService = createClient(Deno.env.get('SUPABASE_URL'), Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'), {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  });
  // 4. Create the child auth user with a synthetic email + random password.
  //    Synthetic email = child_<uuid>@managed.ygteev.local (never used).
  const childUuid = crypto.randomUUID();
  const syntheticEmail = `child_${childUuid}@managed.ygteev.local`;
  const password = randomHex(24);
  const { data: created, error: createErr } = await supabaseService.auth.admin.createUser({
    email: syntheticEmail,
    password,
    email_confirm: true,
    user_metadata: {
      managed_child: true,
      parent_account_id: user.id,
      first_name: firstName,
      last_name: lastName || null
    }
  });
  if (createErr || !created.user) return fail('admin-createuser-failed', 500, createErr?.message);
  const childUserId = created.user.id;
  // 5. Populate the profile row that the existing handle_new_user trigger
  //    inserted. We update the rest of the columns via service role.
  const displayName = [
    firstName,
    lastName
  ].filter(Boolean).join(' ').trim() || firstName;
  const { error: profErr } = await supabaseService.from('profiles').update({
    display_name: displayName,
    avatar_url: avatarUrl,
    date_of_birth: dobStr,
    grade_year: gradeYear,
    parent_account_id: user.id,
    is_managed_child: true,
    updated_at: new Date().toISOString()
  }).eq('id', childUserId);
  if (profErr) {
    // Best-effort cleanup if profile update fails
    await supabaseService.auth.admin.deleteUser(childUserId).catch(()=>{});
    return fail('child-profile-update-failed', 500, profErr.message);
  }
  // 6. Add child to the family
  const { error: fmInsErr } = await supabaseService.from('family_members').insert({
    family_id: familyId,
    user_id: childUserId,
    role: 'child'
  });
  if (fmInsErr) {
    await supabaseService.auth.admin.deleteUser(childUserId).catch(()=>{});
    return fail('family-member-insert-failed', 500, fmInsErr.message);
  }
  // 7. Pairing token (32-char hex) + 8-digit fallback numeric code
  const pairingToken = randomHex(16); // 32 hex chars
  const numericCode = randomNumeric(8);
  const { data: tokenRow, error: tokErr } = await supabaseService.from('child_pairing_tokens').insert({
    child_user_id: childUserId,
    token: pairingToken,
    numeric_code: numericCode,
    created_by: user.id
  }).select('expires_at').single();
  if (tokErr || !tokenRow) return fail('token-insert-failed', 500, tokErr?.message);

  // 8. If this was a kid-first (handoff) call, stamp the handoff row
  //    so the waiting kid device can poll and see the resulting
  //    pairing token. Best-effort — the pairing token was minted
  //    successfully, so a failed stamp here should not roll back
  //    the child account. Log and continue.
  if (handoffRowId) {
    const { error: handoffUpdErr } = await supabaseService.from('child_signup_handoffs').update({
      child_user_id: childUserId,
      pairing_token: pairingToken,
      numeric_code: numericCode,
      redeemed_at: new Date().toISOString()
    }).eq('id', handoffRowId);
    if (handoffUpdErr) {
      console.error('[create-child-account] handoff-stamp-failed:', handoffUpdErr.message);
    }
  }

  return json({
    child_user_id: childUserId,
    display_name: displayName,
    pairing_token: pairingToken,
    numeric_code: numericCode,
    expires_at: tokenRow.expires_at
  });
});
