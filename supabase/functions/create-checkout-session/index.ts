// v7: Accept an optional `promo_code` in the request body. Looks the
// code up in `pastor_signup_promos`; if valid (active, not expired,
// under max_uses), uses its `trial_days` for the Stripe Checkout
// Session and increments the use count. Falls back to the default
// trial when no code is provided or the code is invalid.
//
// Promo code is stashed on the Stripe subscription metadata so the
// `stripe-webhook` (and any future reconciliation) can attribute
// signups to a campaign.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json"
};
// v8 (2026-07-20): default trial extended 14 -> 90 days — every pastor
// gets 3 months free. Promo codes can still override via trial_days.
const DEFAULT_TRIAL_DAYS = 90;
Deno.serve(async (req)=>{
  if (req.method === "OPTIONS") return new Response("ok", {
    headers: cors
  });
  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) return json({
      error: "unauthorized"
    }, 401);
    const body = await req.json().catch(()=>null);
    const draftId = body?.draft_id;
    const tierId = body?.tier_id;
    const successUrl = body?.success_url;
    const cancelUrl = body?.cancel_url;
    const rawPromo = body?.promo_code;
    const promoCode = rawPromo ? String(rawPromo).trim().toLowerCase() : null;
    if (!draftId || !tierId || !successUrl || !cancelUrl) {
      return json({
        error: "missing_required_fields"
      }, 400);
    }
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
    const ANON = Deno.env.get("SUPABASE_ANON_KEY");
    const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const STRIPE_KEY = Deno.env.get("STRIPE_SECRET_KEY") ?? "";
    if (!STRIPE_KEY) return json({
      error: "stripe_not_configured"
    }, 500);
    const userClient = createClient(SUPABASE_URL, ANON, {
      global: {
        headers: {
          Authorization: authHeader
        }
      }
    });
    const { data: userData, error: authErr } = await userClient.auth.getUser();
    if (authErr || !userData?.user) return json({
      error: "unauthorized"
    }, 401);
    const user = userData.user;
    const admin = createClient(SUPABASE_URL, SERVICE);
    const { data: draft } = await admin.from("pastor_signup_drafts").select("id, user_id, email, first_name, last_name").eq("id", draftId).maybeSingle();
    if (!draft) return json({
      error: "draft_not_found"
    }, 404);
    if (draft.user_id !== user.id) return json({
      error: "not_authorized"
    }, 403);
    const { data: tier } = await admin.from("subscription_tiers").select("id, name, stripe_price_id, price_cents, currency").eq("id", tierId).maybeSingle();
    if (!tier) return json({
      error: "tier_not_found"
    }, 404);
    if (!tier.stripe_price_id) {
      return json({
        error: "tier_not_provisioned_in_stripe",
        tier_id: tierId
      }, 500);
    }
    // Resolve trial length from promo code, if any. Silent fallback to
    // the default — never error out the signup just because a code is
    // invalid; the user shouldn't be blocked from paying us.
    let trialDays = DEFAULT_TRIAL_DAYS;
    let resolvedPromoCode = null;
    if (promoCode) {
      const { data: promo } = await admin.from("pastor_signup_promos").select("id, code, trial_days, active, expires_at, max_uses, uses_count").eq("code", promoCode).maybeSingle();
      if (promo && promo.active === true && (promo.expires_at == null || new Date(promo.expires_at) > new Date()) && (promo.max_uses == null || (promo.uses_count ?? 0) < promo.max_uses)) {
        trialDays = promo.trial_days;
        resolvedPromoCode = promo.code;
      }
    }
    const email = user.email ?? draft.email ?? "";
    const name = `${draft.first_name ?? ""} ${draft.last_name ?? ""}`.trim();
    // Find existing Stripe customer by email
    let customerId = null;
    try {
      const searchRes = await stripeApi("GET", `/v1/customers/search?query=${encodeURIComponent(`email:"${email}"`)}`, null, STRIPE_KEY);
      if (searchRes?.data?.length) customerId = searchRes.data[0].id;
    } catch (_e) {}
    if (!customerId) {
      const create = await stripeApi("POST", "/v1/customers", new URLSearchParams({
        email,
        name,
        "metadata[supabase_user_id]": user.id,
        "metadata[draft_id]": draftId
      }), STRIPE_KEY);
      if (create?.error) return json({
        error: "stripe_customer_create_failed",
        detail: create.error
      }, 502);
      customerId = create.id;
    }
    const params = new URLSearchParams();
    params.append("mode", "subscription");
    params.append("customer", customerId);
    params.append("line_items[0][price]", tier.stripe_price_id);
    params.append("line_items[0][quantity]", "1");
    params.append("subscription_data[trial_period_days]", String(trialDays));
    params.append("subscription_data[metadata][supabase_user_id]", user.id);
    params.append("subscription_data[metadata][draft_id]", draftId);
    params.append("subscription_data[metadata][tier_id]", tierId);
    if (resolvedPromoCode) {
      params.append("subscription_data[metadata][promo_code]", resolvedPromoCode);
      params.append("metadata[promo_code]", resolvedPromoCode);
    }
    params.append("payment_method_collection", "always");
    params.append("success_url", successUrl);
    params.append("cancel_url", cancelUrl);
    params.append("metadata[supabase_user_id]", user.id);
    params.append("metadata[draft_id]", draftId);
    params.append("metadata[tier_id]", tierId);
    params.append("allow_promotion_codes", "true");
    const session = await stripeApi("POST", "/v1/checkout/sessions", params, STRIPE_KEY);
    if (session?.error) {
      return json({
        error: "stripe_session_create_failed",
        detail: session.error
      }, 502);
    }
    // Bump uses_count for the promo. We do this fire-and-forget after
    // the Checkout Session is created — the user has already left for
    // Stripe. If this fails we just under-count analytics, no harm.
    if (resolvedPromoCode) {
      try {
        await admin.rpc("increment_pastor_signup_promo_uses", {
          _code: resolvedPromoCode
        });
      } catch (e) {
        console.warn("[create-checkout-session] promo bump failed:", e);
      }
    }
    await admin.from("pastor_signup_drafts").update({
      stage: "checkout",
      tier_id: tierId
    }).eq("id", draftId);
    return json({
      url: session.url,
      session_id: session.id,
      trial_days: trialDays,
      promo_code: resolvedPromoCode
    });
  } catch (e) {
    return json({
      error: "unhandled",
      detail: String(e?.message ?? e)
    }, 500);
  }
});
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
function json(payload, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: cors
  });
}
