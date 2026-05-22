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
const SIGNUP_URL = "https://ygteev.com/youthgroups";
function firstName(full) {
  if (!full) return "there";
  const first = full.trim().split(/\s+/)[0];
  return first || "there";
}
function esc(s) {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}
function buildHtml(pastorName, churchName) {
  const p = esc(firstName(pastorName));
  const c = esc(churchName);
  return `<!doctype html>
<html><body style="font-family: -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial, sans-serif; color:#222; line-height:1.55; max-width:560px;">
<p>Hey ${p},</p>

<p>One of your students just put ${c} on YGTeeV — we're an app for teens that turns daily Bible reading into a game with their youth group. They asked us to reach out so you could claim your group on the platform.</p>

<p>Quick context on what students do: read a daily plan, earn XP and water, grow a little pixel garden, and chat with their pastor / leaders / small group. We moderate every message with OpenAI so the chat stays safe by default.</p>

<p>The reason I'm emailing is the pastor side. We built a real dashboard for the people running the youth group:</p>

<ul>
  <li>Full roster + small group management</li>
  <li>Chat threads (main, small group, 1:1 with each kid) with flagged-message alerts straight to you</li>
  <li>Event creation with RSVPs and post-event photo galleries</li>
  <li>Reading streak + plan-completion analytics so you actually know who's engaging</li>
  <li>Public profile on the YGTeeV map so new students in your area can find your group</li>
</ul>

<p>It's <strong>$29/mo</strong> to get started and takes about 10 minutes to set up. You can sign up here: <a href="${SIGNUP_URL}">${SIGNUP_URL.replace("https://", "")}</a></p>

<p>If it's not a fit, just hit reply and I'll take you off the list — no follow-ups. But if you want a quick walkthrough first, hit reply and I'll personally get you started.</p>

<p>Hope to have ${c} on the map soon,<br/>
Jim<br/>
<small style="color:#666">Founder, YGTeeV</small></p>
</body></html>`;
}
function buildText(pastorName, churchName) {
  const p = firstName(pastorName);
  return `Hey ${p},

One of your students just put ${churchName} on YGTeeV — we're an app for teens that turns daily Bible reading into a game with their youth group. They asked us to reach out so you could claim your group on the platform.

Quick context on what students do: read a daily plan, earn XP and water, grow a little pixel garden, and chat with their pastor / leaders / small group. We moderate every message with OpenAI so the chat stays safe by default.

The reason I'm emailing is the pastor side. We built a real dashboard for the people running the youth group:
  • Full roster + small group management
  • Chat threads (main, small group, 1:1 with each kid) with flagged-message alerts straight to you
  • Event creation with RSVPs and post-event photo galleries
  • Reading streak + plan-completion analytics so you actually know who's engaging
  • Public profile on the YGTeeV map so new students in your area can find your group

It's $29/mo to get started and takes about 10 minutes to set up. You can sign up here: ${SIGNUP_URL}

If it's not a fit, just hit reply and I'll take you off the list — no follow-ups. But if you want a quick walkthrough first, hit reply and I'll personally get you started.

Hope to have ${churchName} on the map soon,
Jim
Founder, YGTeeV`;
}
Deno.serve(async (req)=>{
  if (req.method === "OPTIONS") return new Response("ok", {
    headers: cors
  });
  try {
    const body = await req.json().catch(()=>null);
    const submissionId = body?.submission_id;
    if (!submissionId) return json({
      error: "missing_submission_id"
    }, 400);
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
    const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const RESEND_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
    if (!RESEND_KEY) {
      console.log("[lead-email] RESEND_API_KEY missing");
      return json({
        error: "resend_api_key_missing"
      }, 500);
    }
    const admin = createClient(SUPABASE_URL, SERVICE);
    const { data: sub, error: subErr } = await admin.from("youth_group_submissions").select("id, church_name, pastor_name, pastor_email, lead_stage, emailed_at").eq("id", submissionId).maybeSingle();
    if (subErr) return json({
      error: "db_error",
      detail: subErr.message
    }, 500);
    if (!sub) return json({
      error: "submission_not_found"
    }, 404);
    if (sub.emailed_at) {
      return json({
        ok: true,
        already_emailed: true
      });
    }
    const html = buildHtml(sub.pastor_name, sub.church_name);
    const text = buildText(sub.pastor_name, sub.church_name);
    const subject = `A student in your group asked us to reach out`;
    const resendRes = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        from: `${FROM_NAME} <${FROM_ADDRESS}>`,
        to: [
          sub.pastor_email
        ],
        reply_to: REPLY_TO,
        subject,
        html,
        text
      })
    });
    const resendJson = await resendRes.json().catch(()=>({}));
    if (!resendRes.ok) {
      console.log("[lead-email] Resend error", resendRes.status, resendJson);
      return json({
        error: "resend_failed",
        status: resendRes.status,
        detail: resendJson
      }, 502);
    }
    const messageId = resendJson?.id;
    await admin.from("youth_group_submissions").update({
      lead_stage: "emailed",
      emailed_at: new Date().toISOString(),
      email_provider_id: messageId ?? null
    }).eq("id", submissionId);
    return json({
      ok: true,
      message_id: messageId ?? null
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
