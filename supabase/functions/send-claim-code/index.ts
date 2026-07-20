// send-claim-code — emails a 6-digit verification code to an inbox at
// the church's website domain so a pastor without a branded email can
// still officially claim their group (pastor onboarding v2).
//
//   POST { group_id, send_to }   send_to must be an address @church_domain
//
// Guards: caller must be the group's pastor; group must be pending
// verification; max 3 codes per group per hour. The code is stored as
// sha256(code || row_id) in claim_verifications and checked by the
// verify_claim_code(group_id, code) RPC, which flips the group public
// and links the discovered_youth_groups row on success.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json",
};
const FROM_NAME = "Jim @ YGTeeV";
const FROM_ADDRESS = Deno.env.get("YGTEEV_LEAD_FROM_EMAIL") ?? "jim@ygteev.com";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) return json({ error: "unauthorized" }, 401);
    const body = await req.json().catch(() => null);
    const groupId = body?.group_id;
    const sendTo = String(body?.send_to ?? "").trim().toLowerCase();
    if (!groupId || !sendTo) return json({ error: "missing_required_fields" }, 400);

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const userClient = createClient(SUPABASE_URL, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: authErr } = await userClient.auth.getUser();
    if (authErr || !userData?.user) return json({ error: "unauthorized" }, 401);
    const user = userData.user;

    const admin = createClient(SUPABASE_URL, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { data: group } = await admin.from("youth_groups")
      .select("id, name, church_name, church_domain, verification_status, created_by")
      .eq("id", groupId).maybeSingle();
    if (!group) return json({ error: "group_not_found" }, 404);
    if (group.verification_status !== "pending") return json({ error: "already_verified" }, 400);

    const { data: membership } = await admin.from("youth_group_members")
      .select("role").eq("group_id", groupId).eq("user_id", user.id).maybeSingle();
    const isPastor = group.created_by === user.id || membership?.role === "pastor";
    if (!isPastor) return json({ error: "not_the_pastor" }, 403);

    const domain = (group.church_domain ?? "").toLowerCase();
    if (!domain) return json({ error: "no_church_domain", detail: "request manual review instead" }, 400);
    if (!sendTo.endsWith("@" + domain)) {
      return json({ error: "address_not_at_church_domain", church_domain: domain }, 400);
    }

    // rate limit: 3 sends per group per hour
    const { count } = await admin.from("claim_verifications")
      .select("id", { count: "exact", head: true })
      .eq("group_id", groupId)
      .gte("created_at", new Date(Date.now() - 3600_000).toISOString());
    if ((count ?? 0) >= 3) return json({ error: "rate_limited", retry_after_minutes: 60 }, 429);

    const code = String(Math.floor(100000 + Math.random() * 900000));
    const { data: row, error: insErr } = await admin.from("claim_verifications")
      .insert({ group_id: groupId, user_id: user.id, sent_to: sendTo, code_hash: "pending" })
      .select("id").single();
    if (insErr || !row) return json({ error: "insert_failed", detail: insErr?.message }, 500);
    const hashBuf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(code + row.id));
    const hash = [...new Uint8Array(hashBuf)].map((b) => b.toString(16).padStart(2, "0")).join("");
    await admin.from("claim_verifications").update({ code_hash: hash }).eq("id", row.id);

    const RESEND_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
    if (!RESEND_KEY) return json({ error: "email_not_configured" }, 500);
    const emailRes = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { "Authorization": `Bearer ${RESEND_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        from: `${FROM_NAME} <${FROM_ADDRESS}>`,
        to: [sendTo],
        subject: `${code} — verify ${group.name} on YGTeeV`,
        html: `
          <div style="font-family:-apple-system,system-ui,sans-serif;max-width:440px;margin:0 auto;padding:24px">
            <h2 style="margin:0 0 8px">Verify your youth group</h2>
            <p style="color:#555;line-height:1.5">Someone (hopefully your youth pastor) is claiming
            <b>${group.name}</b> at <b>${group.church_name}</b> on YGTeeV. Enter this code to confirm:</p>
            <p style="font-size:34px;font-weight:800;letter-spacing:8px;text-align:center;
              background:#f4f1ff;border-radius:12px;padding:18px 0;margin:18px 0">${code}</p>
            <p style="color:#888;font-size:13px">The code expires in 30 minutes. If this wasn't you,
            you can ignore this email — nothing happens without the code.</p>
          </div>`,
      }),
    });
    if (!emailRes.ok) {
      return json({ error: "email_send_failed", detail: await emailRes.text() }, 502);
    }
    return json({ ok: true, sent_to: sendTo, expires_in_minutes: 30 });
  } catch (e) {
    return json({ error: "unhandled", detail: String((e as Error)?.message ?? e) }, 500);
  }
});

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), { status, headers: cors });
}
