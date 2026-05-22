// Pastor welcome email. Fired from stripe-webhook on
// checkout.session.completed after finalize_pastor_signup creates the
// youth_groups row. Body: { group_id: uuid }. The function looks up
// everything else (church name, pastor first name, trial end date)
// from the DB so the webhook only needs to hand off a single id.
//
// Tone matches send-lead-welcome-email (the cold outreach one) so the
// pastor's first two touches from us feel like the same person wrote
// them, not a marketing pipeline.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json"
};
const FROM_NAME = "Jim @ YGTeeV";
const FROM_ADDRESS = Deno.env.get("YGTEEV_LEAD_FROM_EMAIL") ?? "jim@ygteev.com";
const REPLY_TO = Deno.env.get("YGTEEV_LEAD_REPLY_TO") ?? FROM_ADDRESS;
const DASHBOARD_URL = "https://pastors.ygteev.com/sign-in";
const APP_STORE_URL = "https://apps.apple.com/app/ygteev/id0000000000";
function firstName(full) {
  if (!full) return "there";
  const first = full.trim().split(/\s+/)[0];
  return first || "there";
}
function esc(s) {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}
function fmtDate(iso) {
  if (!iso) return "the end of your trial";
  const d = new Date(iso);
  return d.toLocaleDateString("en-US", {
    weekday: "long",
    month: "long",
    day: "numeric",
    year: "numeric"
  });
}
function buildHtml(args) {
  const p = esc(args.pastorFirst);
  const g = esc(args.groupName);
  const c = esc(args.churchName);
  const billOn = esc(args.firstBillOn);
  const td = args.trialDays;
  return `<!doctype html>
<html><body style="font-family: -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial, sans-serif; color:#222; line-height:1.55; max-width:560px;">
<p>Hey ${p},</p>

<p>Welcome to YGTeeV — <strong>${g}</strong> is officially set up. I'm genuinely glad to have ${c} on the platform.</p>

<p style="background:#F5F3FF; border-left:3px solid #6B2BFF; padding:10px 14px; border-radius:6px;">
  Your <strong>${td}-day free trial</strong> is active. First charge: <strong>${billOn}</strong>. You can cancel any time before then and won't be charged.
</p>

<p>Three things to do in the next 10 minutes to make this real for your students:</p>

<ol>
  <li><strong>Set up your small groups + assign leaders.</strong> Open the dashboard → <em>Small Groups</em>. Add a group per night/grade and invite your leaders by email — they'll get their own dashboard with chat + roster scoped to their kids only.</li>
  <li><strong>Share your group QR code at your next meeting.</strong> The dashboard has a QR specific to ${g}. Students download the app, scan it, and they're in.</li>
  <li><strong>Create your first event.</strong> Pick something on the calendar (worship night, retreat, donut party). Students RSVP in-app, and if you make it public you also get a shareable invite link so kids can bring friends.</li>
</ol>

<p><a href="${DASHBOARD_URL}" style="display:inline-block; background:#6B2BFF; color:#fff; text-decoration:none; padding:12px 18px; border-radius:10px; font-weight:600;">Open Your Dashboard</a></p>

<p>If you haven't already, grab the iOS app yourself so you can see exactly what your students see: <a href="${APP_STORE_URL}">Download YGTeeV</a></p>

<p>One ask: if something feels off in the first week — confusing UI, a feature you wish existed, a workflow that's missing — hit reply. I read every email and we move fast on pastor feedback. We built this for you specifically.</p>

<p>Excited to see ${c} on the map.<br/>
Jim<br/>
<small style="color:#666">Founder, YGTeeV</small></p>
</body></html>`;
}
function buildText(args) {
  return `Hey ${args.pastorFirst},

Welcome to YGTeeV — ${args.groupName} is officially set up. I'm genuinely glad to have ${args.churchName} on the platform.

Your ${args.trialDays}-day free trial is active. First charge: ${args.firstBillOn}. You can cancel any time before then and won't be charged.

Three things to do in the next 10 minutes:

  1. Set up your small groups + assign leaders. Dashboard → Small Groups. Add a group per night/grade and invite your leaders by email.

  2. Share your group QR code at your next meeting. The dashboard has a QR specific to ${args.groupName}. Students download the app, scan it, and they're in.

  3. Create your first event. Pick something on the calendar (worship night, retreat, donut party). Students RSVP in-app, and if you make it public you also get a shareable invite link.

Open your dashboard: ${DASHBOARD_URL}

If you haven't already, grab the iOS app yourself: ${APP_STORE_URL}

One ask: if something feels off in the first week — confusing UI, a feature you wish existed, a workflow that's missing — hit reply. I read every email and we move fast on pastor feedback.

Excited to see ${args.churchName} on the map.
Jim
Founder, YGTeeV`;
}
Deno.serve(async (req)=>{
  if (req.method === "OPTIONS") return new Response("ok", {
    headers: cors
  });
  try {
    const body = await req.json().catch(()=>null);
    const groupId = body?.group_id;
    if (!groupId) return json({
      error: "missing_group_id"
    }, 400);
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
    const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const RESEND_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
    if (!RESEND_KEY) return json({
      error: "resend_api_key_missing"
    }, 500);
    const admin = createClient(SUPABASE_URL, SERVICE);
    // Group
    const { data: yg, error: ygErr } = await admin.from("youth_groups").select("id, name, church_name").eq("id", groupId).maybeSingle();
    if (ygErr) return json({
      error: "group_lookup_failed",
      detail: ygErr.message
    }, 500);
    if (!yg) return json({
      error: "group_not_found",
      group_id: groupId
    }, 404);
    // Pastor (membership role='pastor')
    const { data: membership } = await admin.from("youth_group_members").select("user_id").eq("group_id", groupId).eq("role", "pastor").limit(1).maybeSingle();
    let pastorEmail = null;
    let pastorFirstName = "there";
    if (membership?.user_id) {
      const { data: profile } = await admin.from("profiles").select("id, email, display_name").eq("id", membership.user_id).maybeSingle();
      pastorEmail = profile?.email ?? null;
      pastorFirstName = firstName(profile?.display_name);
    }
    // Subscription for trial end
    const { data: subRow } = await admin.from("stripe_subscriptions").select("trial_end, current_period_end, status").eq("group_id", groupId).order("created_at", {
      ascending: false
    }).limit(1).maybeSingle();
    const trialEndIso = subRow?.trial_end ?? subRow?.current_period_end ?? null;
    const firstBillOn = fmtDate(trialEndIso);
    // Compute trial_days from trial_end (approximate). If we can't, default to 14.
    let trialDays = 14;
    if (trialEndIso) {
      const days = Math.round((new Date(trialEndIso).getTime() - Date.now()) / (1000 * 60 * 60 * 24));
      if (days > 0 && days <= 365) trialDays = days;
    }
    if (!pastorEmail) {
      return json({
        error: "pastor_email_not_found",
        group_id: groupId
      }, 404);
    }
    const args = {
      pastorFirst: pastorFirstName,
      groupName: yg.name ?? "your group",
      churchName: yg.church_name ?? yg.name ?? "your church",
      trialDays,
      firstBillOn
    };
    const html = buildHtml(args);
    const text = buildText(args);
    const subject = `Welcome to YGTeeV — let’s get ${args.churchName} set up`;
    const resendRes = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        from: `${FROM_NAME} <${FROM_ADDRESS}>`,
        to: [
          pastorEmail
        ],
        reply_to: REPLY_TO,
        subject,
        html,
        text
      })
    });
    const resendJson = await resendRes.json().catch(()=>({}));
    if (!resendRes.ok) {
      console.log("[pastor-welcome] Resend error", resendRes.status, resendJson);
      return json({
        error: "resend_failed",
        status: resendRes.status,
        detail: resendJson
      }, 502);
    }
    return json({
      ok: true,
      message_id: resendJson?.id ?? null,
      to: pastorEmail
    });
  } catch (e) {
    return json({
      error: "unhandled",
      detail: String(e?.message ?? e)
    }, 500);
  }
});
function json(payload, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: cors
  });
}
