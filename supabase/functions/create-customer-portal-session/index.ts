import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json"
};
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
    const returnUrl = body?.return_url;
    if (!returnUrl) return json({
      error: "missing_return_url"
    }, 400);
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
    // Pastor's active subscription → their stripe_customer_id
    const { data: sub } = await admin.from("stripe_subscriptions").select("stripe_customer_id, status").eq("pastor_user_id", user.id).in("status", [
      "trialing",
      "active",
      "past_due"
    ]).maybeSingle();
    if (!sub) return json({
      error: "no_active_subscription"
    }, 404);
    if (!sub.stripe_customer_id) return json({
      error: "customer_id_missing"
    }, 500);
    const params = new URLSearchParams();
    params.append("customer", sub.stripe_customer_id);
    params.append("return_url", returnUrl);
    const session = await stripeApi("POST", "/v1/billing_portal/sessions", params, STRIPE_KEY);
    if (session?.error) {
      return json({
        error: "stripe_portal_error",
        detail: session.error
      }, 502);
    }
    return json({
      url: session.url
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
