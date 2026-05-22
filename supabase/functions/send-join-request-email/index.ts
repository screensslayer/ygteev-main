// v2: Split the pastor lookup into two explicit queries instead of
// PostgREST's implicit join syntax, which couldn't resolve the FK
// between youth_group_members and profiles by name.
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
function firstName(full) {
  if (!full) return "there";
  const first = full.trim().split(/\s+/)[0];
  return first || "there";
}
function esc(s) {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}
function buildHtml(args) {
  const p = esc(args.pastorFirst);
  const g = esc(args.groupName);
  const r = esc(args.requesterName);
  const h = esc(args.requesterHandle);
  const e = esc(args.requesterEmail);
  const messageBlock = args.optionalMessage && args.optionalMessage.trim().length > 0 ? `<p style="background:#F5F3FF; border-left:3px solid #6B2BFF; padding:10px 14px; border-radius:6px;"><em>“${esc(args.optionalMessage)}”</em></p>` : "";
  return `<!doctype html>
<html><body style="font-family: -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial, sans-serif; color:#222; line-height:1.55; max-width:560px;">
<p>Hey ${p},</p>

<p><strong>${r}</strong> just requested to join <strong>${g}</strong> on YGTeeV.</p>

<table style="font-size:14px; color:#444; margin: 8px 0 16px 0;">
  <tr><td style="padding:2px 8px 2px 0; color:#888;">Handle</td><td>@${h}</td></tr>
  <tr><td style="padding:2px 8px 2px 0; color:#888;">Email</td><td>${e}</td></tr>
</table>

${messageBlock}

<p><a href="${DASHBOARD_URL}" style="display:inline-block; background:#6B2BFF; color:#fff; text-decoration:none; padding:12px 18px; border-radius:10px; font-weight:600;">Review the request</a></p>

<p style="font-size:13px; color:#777;">You'll see the full member profile and can approve or deny from the Requests tab in your dashboard.</p>

<p>— Jim<br/><small style="color:#666">Founder, YGTeeV</small></p>
</body></html>`;
}
function buildText(args) {
  const messageBlock = args.optionalMessage && args.optionalMessage.trim().length > 0 ? `\n\n"${args.optionalMessage}"\n\n` : "\n\n";
  return `Hey ${args.pastorFirst},\n\n${args.requesterName} just requested to join ${args.groupName} on YGTeeV.\n\nHandle: @${args.requesterHandle}\nEmail: ${args.requesterEmail}${messageBlock}Review the request: ${DASHBOARD_URL}\n\nYou'll see the full member profile and can approve or deny from the Requests tab in your dashboard.\n\n— Jim\nFounder, YGTeeV`;
}
Deno.serve(async (req)=>{
  if (req.method === "OPTIONS") return new Response("ok", {
    headers: cors
  });
  try {
    const body = await req.json().catch(()=>null);
    const requestId = body?.request_id;
    if (!requestId) return json({
      error: "missing_request_id"
    }, 400);
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
    const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const RESEND_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
    if (!RESEND_KEY) return json({
      error: "resend_api_key_missing"
    }, 500);
    const admin = createClient(SUPABASE_URL, SERVICE);
    const { data: jr, error: jrErr } = await admin.from("youth_group_join_requests").select("id, group_id, user_id, status, message, requested_at").eq("id", requestId).maybeSingle();
    if (jrErr) return json({
      error: "request_lookup_failed",
      detail: jrErr.message
    }, 500);
    if (!jr) return json({
      error: "request_not_found"
    }, 404);
    if (jr.status !== "pending") {
      return json({
        ok: true,
        skipped: true,
        reason: `status_is_${jr.status}`
      });
    }
    const { data: yg } = await admin.from("youth_groups").select("id, name, church_name").eq("id", jr.group_id).maybeSingle();
    if (!yg) return json({
      error: "group_not_found"
    }, 404);
    const { data: requester } = await admin.from("profiles").select("id, display_name, handle, email").eq("id", jr.user_id).maybeSingle();
    if (!requester) return json({
      error: "requester_not_found"
    }, 404);
    // Two-step lookup: pastor user_ids, then their profiles.
    const { data: pastorMemberships, error: pmErr } = await admin.from("youth_group_members").select("user_id").eq("group_id", jr.group_id).eq("role", "pastor");
    if (pmErr) return json({
      error: "pastor_lookup_failed",
      detail: pmErr.message
    }, 500);
    const pastorIds = (pastorMemberships ?? []).map((r)=>r.user_id);
    if (pastorIds.length === 0) {
      return json({
        ok: true,
        sends: [],
        note: "no_pastors_for_group"
      });
    }
    const { data: pastorProfiles, error: ppErr } = await admin.from("profiles").select("id, display_name, email").in("id", pastorIds);
    if (ppErr) return json({
      error: "pastor_profile_lookup_failed",
      detail: ppErr.message
    }, 500);
    const sends = [];
    for (const profile of pastorProfiles ?? []){
      const pastorEmail = profile?.email ?? null;
      if (!pastorEmail) {
        sends.push({
          to: "(unknown)",
          ok: false,
          error: "pastor_has_no_email"
        });
        continue;
      }
      const args = {
        pastorFirst: firstName(profile?.display_name),
        groupName: yg.name ?? "your group",
        requesterName: requester.display_name ?? requester.handle ?? "Someone",
        requesterHandle: requester.handle ?? "",
        requesterEmail: requester.email ?? "(no email on file)",
        optionalMessage: jr.message ?? null
      };
      const subject = `${args.requesterName} wants to join ${args.groupName}`;
      const html = buildHtml(args);
      const text = buildText(args);
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
      if (resendRes.ok) {
        sends.push({
          to: pastorEmail,
          ok: true,
          message_id: resendJson?.id
        });
      } else {
        console.log("[join-request-email] Resend error", resendRes.status, resendJson);
        sends.push({
          to: pastorEmail,
          ok: false,
          error: resendJson
        });
      }
    }
    return json({
      ok: true,
      request_id: requestId,
      sends
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
