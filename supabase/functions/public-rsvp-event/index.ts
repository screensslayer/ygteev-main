// v4: Public event URL moved from events.ygteev.com to ygteev.com/events.
// The fallback default below now produces the new URL pattern; the env
// var override is still respected if PUBLIC_EVENT_BASE_URL is set in
// the Supabase dashboard.
//
// v3: CORS preflight now allows `apikey` and `x-client-info` headers
// so supabase.functions.invoke from the browser actually delivers the
// POST after the OPTIONS preflight. Without these, the preflight
// returned 200 but the browser silently blocked the real POST.
import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from 'jsr:@supabase/supabase-js@2';
const PUBLIC_BASE_URL = Deno.env.get('PUBLIC_EVENT_BASE_URL') ?? 'https://ygteev.com/events';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
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
  console.error(`[public-rsvp-event] ${stage}:`, detail);
  return json({
    error: stage,
    status,
    detail
  }, status);
}
function isValidEmail(e) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e);
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
  const eventId = String(body.event_id ?? '').trim().toLowerCase();
  const email = String(body.email ?? '').trim().toLowerCase();
  const displayName = body.display_name ? String(body.display_name).trim() : null;
  const gradeYear = body.grade_year == null ? null : Number(body.grade_year);
  const status = String(body.status ?? 'going');
  const inviterId = body.inviter_user_id ? String(body.inviter_user_id).toLowerCase() : null;
  if (!eventId) return fail('event_id-required', 400, body);
  if (!email || !isValidEmail(email)) return fail('valid-email-required', 400, body);
  if (gradeYear != null && (gradeYear < 6 || gradeYear > 12)) {
    return fail('grade_year-out-of-range', 400, {
      gradeYear
    });
  }
  if (![
    'going',
    'maybe',
    'declined'
  ].includes(status)) {
    return fail('status-invalid', 400, {
      status
    });
  }
  const supabase = createClient(Deno.env.get('SUPABASE_URL'), Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'), {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  });
  const { data: ev, error: evErr } = await supabase.from('events').select('id, group_id, title, description, starts_at, location, cover_url, visibility, rsvp_audience').eq('id', eventId).maybeSingle();
  if (evErr) return fail('event-lookup-failed', 500, evErr.message);
  if (!ev) return fail('event-not-found', 404, {
    eventId
  });
  if (ev.visibility !== 'public' || ev.rsvp_audience !== 'public') {
    return fail('event-not-public', 403, {
      message: 'This event is members-only. Download YGTeeV and join the group to RSVP.'
    });
  }
  const { data: yg, error: ygErr } = await supabase.from('youth_groups').select('id, name, church_name, logo_url, gradient_from, gradient_to').eq('id', ev.group_id).maybeSingle();
  if (ygErr) return fail('group-lookup-failed', 500, ygErr.message);
  const { data: existingProfile } = await supabase.from('profiles').select('id').ilike('email', email).maybeSingle();
  const { data: extRow, error: upErr } = await supabase.from('event_external_rsvps').upsert({
    event_id: eventId,
    email: email,
    display_name: displayName,
    grade_year: gradeYear,
    status,
    inviter_user_id: inviterId,
    source: 'invite_link',
    converted_to_user_id: existingProfile?.id ?? null,
    converted_at: existingProfile ? new Date().toISOString() : null
  }, {
    onConflict: 'event_id,email'
  }).select('id').single();
  if (upErr) return fail('external-rsvp-upsert-failed', 500, upErr.message);
  if (existingProfile?.id) {
    await supabase.from('event_rsvps').upsert({
      event_id: eventId,
      user_id: existingProfile.id,
      status
    }, {
      onConflict: 'event_id,user_id'
    });
  }
  try {
    const emailResp = await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/send-event-rsvp-email`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`
      },
      body: JSON.stringify({
        to: email,
        group_name: yg?.name ?? 'Your youth group',
        church_name: yg?.church_name ?? yg?.name ?? '',
        event_title: ev.title,
        starts_at: ev.starts_at,
        location: ev.location,
        description: ev.description,
        event_url: `${PUBLIC_BASE_URL}/${eventId}`,
        gradient_from: yg?.gradient_from,
        gradient_to: yg?.gradient_to
      })
    });
    if (!emailResp.ok) {
      console.warn('[public-rsvp-event] email fire-and-forget failed:', emailResp.status, await emailResp.text());
    }
  } catch (e) {
    console.warn('[public-rsvp-event] email send threw:', e);
  }
  const [{ count: inside }, { count: outside }] = await Promise.all([
    supabase.from('event_rsvps').select('*', {
      count: 'exact',
      head: true
    }).eq('event_id', eventId).eq('status', 'going'),
    supabase.from('event_external_rsvps').select('*', {
      count: 'exact',
      head: true
    }).eq('event_id', eventId).eq('status', 'going').is('converted_to_user_id', null)
  ]);
  return json({
    ok: true,
    external_rsvp_id: extRow?.id,
    going_count: (inside ?? 0) + (outside ?? 0)
  });
});
