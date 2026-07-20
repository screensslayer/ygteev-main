// Sends the RSVP confirmation email via Resend. Sender presents as the
// youth group (not YGTeeV) so the friend feels like the church group
// is talking to them, not an app. Called by public-rsvp-event after a
// successful insert. Auth is via service-role bearer or CRON_SECRET so
// no JWT is required.
import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
const APP_STORE_URL = 'https://apps.apple.com/us/app/ygteev/id6773066416';
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
  console.error(`[send-event-rsvp-email] ${stage}:`, detail);
  return json({
    error: stage,
    status,
    detail
  }, status);
}
function escapeHtml(s) {
  return s.replace(/[&<>"']/g, (c)=>({
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      '\'': '&#39;'
    })[c]);
}
Deno.serve(async (req)=>{
  if (req.method === 'OPTIONS') return new Response(null, {
    headers: corsHeaders
  });
  if (req.method !== 'POST') return fail('method-not-allowed', 405, req.method);
  // Service-role bearer or CRON_SECRET
  const cronSecret = Deno.env.get('CRON_SECRET');
  const bearerHeader = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
  const cronSecretHeader = req.headers.get('x-cron-secret');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const authorized = bearerHeader === serviceKey || cronSecret && cronSecretHeader === cronSecret;
  if (!authorized) return fail('unauthorized', 401, null);
  let body;
  try {
    body = await req.json();
  } catch (e) {
    return fail('bad-json', 400, String(e));
  }
  const to = String(body.to ?? '').trim();
  const groupName = String(body.group_name ?? '').trim() || 'Your youth group';
  const churchName = String(body.church_name ?? '').trim() || groupName;
  const eventTitle = String(body.event_title ?? '').trim() || 'an upcoming event';
  const startsAt = body.starts_at ? new Date(body.starts_at) : null;
  const location = String(body.location ?? '').trim();
  const description = String(body.description ?? '').trim();
  const eventUrl = String(body.event_url ?? '').trim();
  const gradient_from = String(body.gradient_from ?? '#6B2BFF');
  const gradient_to = String(body.gradient_to ?? '#FF3DA5');
  if (!to || !eventTitle) return fail('missing-required-fields', 400, body);
  const resendKey = Deno.env.get('RESEND_API_KEY');
  if (!resendKey) return fail('missing-resend-key', 500, null);
  const dateStr = startsAt ? startsAt.toLocaleString('en-US', {
    weekday: 'long',
    month: 'long',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    timeZoneName: 'short'
  }) : '';
  const senderName = groupName;
  const senderEmail = 'events@ygteev.com';
  const subject = `You're going to ${eventTitle}!`;
  const html = `
<!doctype html>
<html><body style="margin:0;padding:0;background:#f6f4fb;font-family:-apple-system,system-ui,Segoe UI,sans-serif;color:#0A0712;">
  <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="padding:32px 16px;">
    <tr><td align="center">
      <table role="presentation" cellpadding="0" cellspacing="0" width="560" style="background:#fff;border-radius:24px;overflow:hidden;">
        <tr><td style="background:linear-gradient(135deg,${escapeHtml(gradient_from)},${escapeHtml(gradient_to)});padding:36px 28px;color:#fff;">
          <div style="font-size:11px;letter-spacing:2px;opacity:.85;text-transform:uppercase;font-weight:700;">${escapeHtml(churchName)}</div>
          <h1 style="margin:8px 0 0;font-size:28px;line-height:1.15;font-weight:900;">You're going to<br>${escapeHtml(eventTitle)}!</h1>
        </td></tr>
        <tr><td style="padding:28px;">
          <p style="margin:0 0 18px;font-size:16px;line-height:1.5;">Thanks for RSVPing! Here are the details so you don't forget.</p>
          <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="background:#f6f4fb;border-radius:14px;padding:18px;">
            ${dateStr ? `<tr><td style="padding:6px 0;font-weight:700;">When</td><td style="padding:6px 0;text-align:right;">${escapeHtml(dateStr)}</td></tr>` : ''}
            ${location ? `<tr><td style="padding:6px 0;font-weight:700;">Where</td><td style="padding:6px 0;text-align:right;">${escapeHtml(location)}</td></tr>` : ''}
          </table>
          ${description ? `<p style="margin:18px 0 0;font-size:15px;line-height:1.5;color:#3a3550;">${escapeHtml(description)}</p>` : ''}
          <div style="margin:28px 0 8px;padding:18px;background:#f6f4fb;border-radius:14px;">
            <div style="font-weight:800;font-size:14px;margin-bottom:6px;">Get the app so you're set</div>
            <p style="margin:0 0 12px;font-size:13.5px;color:#3a3550;line-height:1.5;">${escapeHtml(groupName)} runs on the YGTeeV app — daily Bible reading, group chat, garden, the whole deal. Sign in with this same email (${escapeHtml(to)}) and you'll join us automatically.</p>
            <a href="${escapeHtml(APP_STORE_URL)}" style="display:inline-block;padding:12px 18px;background:#0A0712;color:#fff;text-decoration:none;border-radius:999px;font-weight:800;font-size:14px;">Download YGTeeV</a>
          </div>
          ${eventUrl ? `<p style="margin:24px 0 0;font-size:12.5px;color:#6f6885;">Need to change or cancel? Use your invite link: <a href="${escapeHtml(eventUrl)}" style="color:#6B2BFF;">${escapeHtml(eventUrl)}</a></p>` : ''}
          <p style="margin:18px 0 0;font-size:12.5px;color:#6f6885;">See you there,<br><b>${escapeHtml(groupName)}</b></p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body></html>`;
  const resp = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${resendKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      from: `${senderName} <${senderEmail}>`,
      to: [
        to
      ],
      subject,
      html,
      reply_to: senderEmail
    })
  });
  if (!resp.ok) {
    const t = await resp.text();
    return fail('resend-non-200', resp.status, t);
  }
  return json({
    ok: true
  });
});
