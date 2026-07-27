// v8: Meta Conversions API — after a successful trial checkout, send a
// server-side StartTrial event (hashed email + _fbp/_fbc passed through
// checkout metadata by the registration site); every PAID invoice sends
// a Purchase event with the real amount. No-ops silently when
// META_CAPI_ACCESS_TOKEN isn't set; never fails the webhook.
// v7: welcome email after finalize (fire-and-forget).
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
const META_PIXEL_ID = Deno.env.get("META_PIXEL_ID") ?? "770329684625319";
const META_TOKEN = Deno.env.get("META_CAPI_ACCESS_TOKEN") ?? "";
Deno.serve(async (req)=>{
  if (req.method !== "POST") return new Response("method not allowed", {
    status: 405
  });
  const signature = req.headers.get("stripe-signature");
  if (!signature) return new Response("missing signature", {
    status: 400
  });
  const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
  const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const WEBHOOK_SECRET = Deno.env.get("STRIPE_WEBHOOK_SECRET") ?? "";
  const STRIPE_KEY = Deno.env.get("STRIPE_SECRET_KEY") ?? "";
  if (!WEBHOOK_SECRET) return new Response("webhook_secret_missing", {
    status: 500
  });
  const rawBody = await req.text();
  if (!await verifyStripeSignature(rawBody, signature, WEBHOOK_SECRET)) {
    return new Response("invalid signature", {
      status: 400
    });
  }
  let event;
  try {
    event = JSON.parse(rawBody);
  } catch  {
    return new Response("bad json", {
      status: 400
    });
  }
  const admin = createClient(SUPABASE_URL, SERVICE);
  const { data: existing } = await admin.from("stripe_events").select("id, processed_at").eq("id", event.id).maybeSingle();
  if (existing?.processed_at) {
    return ok({
      already_processed: true
    });
  }
  await admin.from("stripe_events").upsert({
    id: event.id,
    type: event.type,
    payload: event
  }, {
    onConflict: "id"
  });
  try {
    await handleEvent(event, admin, STRIPE_KEY);
    await admin.from("stripe_events").update({
      processed_at: new Date().toISOString(),
      error_message: null
    }).eq("id", event.id);
    return ok({
      ok: true
    });
  } catch (err) {
    const msg = String(err?.message ?? err);
    console.log("[stripe-webhook] handler error", event.type, msg);
    await admin.from("stripe_events").update({
      error_message: msg
    }).eq("id", event.id);
    return new Response(JSON.stringify({
      error: msg
    }), {
      status: 500,
      headers: {
        "Content-Type": "application/json"
      }
    });
  }
});
async function handleEvent(event, admin, stripeKey) {
  switch(event.type){
    case "checkout.session.completed":
      {
        const session = event.data.object;
        const draftId = session.metadata?.draft_id;
        const tierId = session.metadata?.tier_id;
        const userId = session.metadata?.supabase_user_id;
        const subId = session.subscription;
        const customerId = session.customer;
        if (!draftId || !subId || !customerId) {
          console.log("[stripe-webhook] checkout.session.completed missing required metadata");
          return;
        }
        const sub = await stripeApi("GET", `/v1/subscriptions/${subId}`, null, stripeKey);
        if (sub?.error) throw new Error(`fetch subscription failed: ${JSON.stringify(sub.error)}`);
        const { data: groupId, error: rpcErr } = await admin.rpc("finalize_pastor_signup", {
          _draft_id: draftId
        });
        if (rpcErr) throw new Error(`finalize_pastor_signup failed: ${rpcErr.message}`);
        await admin.from("youth_groups").update({
          stripe_customer_id: customerId
        }).eq("id", groupId);
        await admin.from("stripe_subscriptions").upsert({
          group_id: groupId,
          pastor_user_id: userId ?? null,
          draft_id: draftId,
          stripe_customer_id: customerId,
          stripe_subscription_id: subId,
          stripe_price_id: sub.items?.data?.[0]?.price?.id ?? null,
          tier_id: tierId ?? null,
          status: sub.status,
          trial_end: tsToIso(sub.trial_end),
          current_period_start: tsToIso(sub.current_period_start),
          current_period_end: tsToIso(sub.current_period_end),
          cancel_at_period_end: sub.cancel_at_period_end ?? false,
          canceled_at: tsToIso(sub.canceled_at),
          raw_payload: sub
        }, {
          onConflict: "stripe_subscription_id"
        });
        // Meta CAPI: the ad-attributable conversion moment.
        await sendMetaEvent({
          event_name: "StartTrial",
          event_id: `${event.id}`,
          event_source_url: session.metadata?.fb_source_url || "https://pastors.ygteev.com/youth-group-registration",
          email: session.customer_details?.email ?? session.customer_email ?? null,
          fbp: session.metadata?.fb_fbp ?? null,
          fbc: session.metadata?.fb_fbc ?? null,
          custom_data: {
            currency: (session.currency ?? "usd").toLowerCase(),
            value: 0,
            content_name: tierId ?? "pastor_plan",
            predicted_ltv: (session.amount_total ?? 0) / 100
          }
        });
        // Fire-and-forget welcome email. Don't block the webhook on the
        // email response — Resend can flake and signup is already done.
        try {
          const SUPABASE_URL_LOCAL = Deno.env.get("SUPABASE_URL");
          const SERVICE_LOCAL = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
          const emailResp = await fetch(`${SUPABASE_URL_LOCAL}/functions/v1/send-pastor-welcome-email`, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "Authorization": `Bearer ${SERVICE_LOCAL}`
            },
            body: JSON.stringify({
              group_id: groupId
            })
          });
          if (!emailResp.ok) {
            console.log("[stripe-webhook] welcome email failed", emailResp.status, await emailResp.text());
          }
        } catch (e) {
          console.log("[stripe-webhook] welcome email threw", String(e));
        }
        break;
      }
    case "customer.subscription.created":
    case "customer.subscription.updated":
    case "customer.subscription.deleted":
      {
        const sub = event.data.object;
        const newStatus = event.type === "customer.subscription.deleted" ? "canceled" : sub.status;
        const { data: existing } = await admin.from("stripe_subscriptions").select("id").eq("stripe_subscription_id", sub.id).maybeSingle();
        if (!existing) {
          return;
        }
        await admin.from("stripe_subscriptions").update({
          status: newStatus,
          stripe_price_id: sub.items?.data?.[0]?.price?.id ?? null,
          trial_end: tsToIso(sub.trial_end),
          current_period_start: tsToIso(sub.current_period_start),
          current_period_end: tsToIso(sub.current_period_end),
          cancel_at_period_end: sub.cancel_at_period_end ?? false,
          canceled_at: tsToIso(sub.canceled_at),
          raw_payload: sub
        }).eq("stripe_subscription_id", sub.id);
        break;
      }
    case "invoice.payment_failed":
      {
        const inv = event.data.object;
        if (inv.subscription) {
          await admin.from("stripe_subscriptions").update({
            status: "past_due"
          }).eq("stripe_subscription_id", inv.subscription);
        }
        break;
      }
    case "invoice.payment_succeeded":
      {
        const inv = event.data.object;
        if (inv.subscription) {
          const sub = await stripeApi("GET", `/v1/subscriptions/${inv.subscription}`, null, stripeKey);
          if (!sub?.error) {
            await admin.from("stripe_subscriptions").update({
              status: sub.status,
              current_period_start: tsToIso(sub.current_period_start),
              current_period_end: tsToIso(sub.current_period_end),
              raw_payload: sub
            }).eq("stripe_subscription_id", inv.subscription);
          }
          // Meta CAPI: real revenue — every paid invoice is a Purchase.
          if ((inv.amount_paid ?? 0) > 0) {
            await sendMetaEvent({
              event_name: "Purchase",
              event_id: `${event.id}`,
              event_source_url: "https://pastors.ygteev.com",
              email: inv.customer_email ?? null,
              fbp: sub?.metadata?.fb_fbp ?? null,
              fbc: sub?.metadata?.fb_fbc ?? null,
              custom_data: {
                currency: (inv.currency ?? "usd").toLowerCase(),
                value: inv.amount_paid / 100,
                content_name: sub?.metadata?.tier_id ?? "pastor_plan"
              }
            });
          }
        }
        break;
      }
    default:
      break;
  }
}
/* ── Meta Conversions API (server events, deduped by event_id) ── */
async function sendMetaEvent({ event_name, event_id, event_source_url, email, fbp, fbc, custom_data }) {
  if (!META_TOKEN) return; // not configured yet — silently skip
  try {
    const user_data = {};
    if (email) user_data.em = [await sha256(email.trim().toLowerCase())];
    if (fbp) user_data.fbp = fbp;
    if (fbc) user_data.fbc = fbc;
    if (!user_data.em && !user_data.fbp && !user_data.fbc) return; // nothing to match on
    const payload = {
      data: [{
        event_name,
        event_time: Math.floor(Date.now() / 1000),
        event_id,
        action_source: "website",
        event_source_url,
        user_data,
        custom_data
      }]
    };
    const res = await fetch(`https://graph.facebook.com/v21.0/${META_PIXEL_ID}/events?access_token=${META_TOKEN}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify(payload)
    });
    if (!res.ok) {
      console.log("[stripe-webhook] meta capi failed", res.status, await res.text());
    } else {
      console.log("[stripe-webhook] meta capi sent", event_name, event_id);
    }
  } catch (e) {
    console.log("[stripe-webhook] meta capi threw", String(e));
  }
}
async function sha256(s) {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return Array.from(new Uint8Array(buf)).map((b)=>b.toString(16).padStart(2, "0")).join("");
}
async function stripeApi(method, path, body, key) {
  const res = await fetch(`https://api.stripe.com${path}`, {
    method,
    headers: {
      "Authorization": `Bearer ${key}`,
      "Content-Type": "application/x-www-form-urlencoded"
    },
    body: body ?? undefined
  });
  return res.json();
}
function tsToIso(ts) {
  if (!ts) return null;
  return new Date(ts * 1000).toISOString();
}
function ok(payload) {
  return new Response(JSON.stringify(payload), {
    status: 200,
    headers: {
      "Content-Type": "application/json"
    }
  });
}
async function verifyStripeSignature(payload, header, secret) {
  const parts = header.split(",").map((s)=>s.trim().split("="));
  let timestamp = null;
  const v1Sigs = [];
  for (const [k, v] of parts){
    if (k === "t") timestamp = v;
    if (k === "v1") v1Sigs.push(v);
  }
  if (!timestamp || v1Sigs.length === 0) return false;
  const nowSec = Math.floor(Date.now() / 1000);
  if (Math.abs(nowSec - parseInt(timestamp, 10)) > 300) return false;
  const enc = new TextEncoder();
  const signedPayload = enc.encode(`${timestamp}.${payload}`);
  const key = await crypto.subtle.importKey("raw", enc.encode(secret), {
    name: "HMAC",
    hash: "SHA-256"
  }, false, [
    "sign"
  ]);
  const sig = await crypto.subtle.sign("HMAC", key, signedPayload);
  const computed = Array.from(new Uint8Array(sig)).map((b)=>b.toString(16).padStart(2, "0")).join("");
  return v1Sigs.some((s)=>timingSafeEq(s, computed));
}
function timingSafeEq(a, b) {
  if (a.length !== b.length) return false;
  let r = 0;
  for(let i = 0; i < a.length; i++)r |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return r === 0;
}
