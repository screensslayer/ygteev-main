// revenuecat-webhook
//
// Consumes RevenueCat's webhook (https://www.revenuecat.com/docs/integrations/webhooks)
// and writes subscription state into apple_subscriptions. RevenueCat handles
// all Apple receipt verification + the noisy renewal/cancel/refund webhooks
// upstream of us — we just record the resulting entitlement state.
//
// Replaces the prior pair of Edge Functions:
//   - validate-storekit-receipt (iOS used to POST JWS directly to us)
//   - apple-server-notifications (Apple's ASSN V2 used to POST to us)
// Both stay in the repo for archival reference but should not be deployed
// alongside this function.
//
// Auth: RevenueCat sets an "Authorization" header with the shared secret
// configured in the RC dashboard. We compare it to REVENUECAT_WEBHOOK_SECRET
// from the Supabase Vault. No bearer / no JWT — RC's webhooks don't do that.
//
// Idempotency: upsert on apple_subscriptions.original_transaction_id (unique).
// Same event posted twice = same row updated twice = no duplicates.
//
// Non-consumable purchases (child unlock) fire as NON_RENEWING_PURCHASE.
// Phase 1 logs and acks; Phase 2 will write to a families/apple_purchases-
// style table once that flow is fleshed out.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// RevenueCat event types we know how to map to our subscription status enum.
// Anything else we log + 200 OK (don't make RC retry).
const STATUS_MAP: Record<string, string> = {
  INITIAL_PURCHASE: "active",
  RENEWAL: "active",
  UNCANCELLATION: "active",
  PRODUCT_CHANGE: "active",
  // CANCELLATION fires when the user cancels future renewals but the current
  // term is still good. They keep access until expires_at. So: still active.
  CANCELLATION: "active",
  EXPIRATION: "expired",
  BILLING_ISSUE: "in_grace",
  SUBSCRIPTION_PAUSED: "paused",
};

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

Deno.serve(async (req) => {
  // --- 1. Auth ---
  const expected = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");
  if (!expected) {
    console.error("REVENUECAT_WEBHOOK_SECRET not set");
    return json({ ok: false, error: "server_misconfigured" }, 500);
  }
  const incoming = req.headers.get("Authorization");
  if (incoming !== expected) {
    return json({ ok: false, error: "unauthorized" }, 401);
  }

  // --- 2. Parse ---
  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch (_e) {
    return json({ ok: false, error: "bad_json" }, 400);
  }
  // deno-lint-ignore no-explicit-any
  const event = (payload as any).event;
  if (!event || typeof event !== "object") {
    return json({ ok: false, error: "missing_event" }, 400);
  }

  const type = event.type as string | undefined;
  const appUserId = event.app_user_id as string | undefined;
  const productId = event.product_id as string | undefined;
  const txId =
    (event.original_transaction_id as string | undefined) ??
    (event.transaction_id as string | undefined);
  const expiresMs = event.expiration_at_ms as number | undefined;

  // RevenueCat falls back to anonymous IDs ($RCAnonymousID:xxx) when iOS
  // forgot to call Purchases.logIn(appUserID:) before the purchase. We refuse
  // those — they aren't tied to a real user. Log so we can fix the iOS side.
  if (!appUserId || !UUID_RE.test(appUserId)) {
    console.warn("non-UUID app_user_id, skipping:", appUserId, "event:", type);
    return json({ ok: true, skipped: "non_uuid_app_user_id" }, 200);
  }

  // --- 3. Connect ---
  const supa = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  // --- 4. Handle ---
  console.log(
    "RC event:",
    type,
    "user:",
    appUserId,
    "product:",
    productId,
    "tx:",
    txId,
  );

  const subStatus = type ? STATUS_MAP[type] : undefined;

  if (subStatus) {
    if (!txId || !productId) {
      console.warn("subscription event missing tx_id or product_id:", event);
      return json({ ok: true, skipped: "missing_ids" }, 200);
    }
    const expiresAt = expiresMs ? new Date(expiresMs).toISOString() : null;

    const { error } = await supa
      .from("apple_subscriptions")
      .upsert(
        {
          user_id: appUserId,
          original_transaction_id: txId,
          product_id: productId,
          status: subStatus,
          expires_at: expiresAt,
          raw_payload: event,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "original_transaction_id" },
      );

    if (error) {
      console.error("upsert failed:", error);
      return json({ ok: false, error: error.message }, 500);
    }
    return json({ ok: true, applied: type, status: subStatus }, 200);
  }

  if (type === "NON_RENEWING_PURCHASE") {
    // child_unlock and any other non-consumables. Phase 1: log + ack.
    // Phase 2: write to a non-consumable purchases table and grant the
    // child-unlock entitlement on the corresponding family row.
    console.log(
      "NON_RENEWING_PURCHASE received (Phase 2 will persist):",
      event,
    );
    return json({ ok: true, applied: "non_renewing_logged_only" }, 200);
  }

  if (type === "TRANSFER") {
    // A user reattached a subscription to a different RC app_user_id.
    // Easiest correct handling: update the row's user_id to the new owner.
    // RC sends transferred_to/transferred_from in the event payload.
    const newUserId = (event.transferred_to as string | undefined) ?? null;
    if (newUserId && UUID_RE.test(newUserId) && txId) {
      const { error } = await supa
        .from("apple_subscriptions")
        .update({ user_id: newUserId, raw_payload: event })
        .eq("original_transaction_id", txId);
      if (error) {
        console.error("transfer update failed:", error);
        return json({ ok: false, error: error.message }, 500);
      }
      return json({ ok: true, applied: "transfer" }, 200);
    }
    return json({ ok: true, skipped: "transfer_no_new_user" }, 200);
  }

  // Test events, REFUND, SUBSCRIBER_ALIAS, etc. — log + ack.
  console.log("unhandled RC event type:", type);
  return json({ ok: true, skipped: "unhandled_type", type }, 200);
});

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}
