import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
const FROM_NAME = "Jim @ YGTeeV";
const FROM_ADDR = Deno.env.get("YGTEEV_BILLING_FROM_EMAIL") ?? "jim@ygteev.com";
const BILLING_URL = Deno.env.get("YGTEEV_BILLING_URL") ?? "https://ygteev.com/billing";
Deno.serve(async (_req)=>{
  try {
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
    const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const STRIPE_KEY = Deno.env.get("STRIPE_SECRET_KEY") ?? "";
    const RESEND_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
    if (!STRIPE_KEY) return json({
      error: "stripe_not_configured"
    }, 500);
    const admin = createClient(SUPABASE_URL, SERVICE);
    const { data: subs, error: subErr } = await admin.from("stripe_subscriptions").select("*").in("status", [
      "trialing",
      "active",
      "past_due"
    ]);
    if (subErr) return json({
      error: "db_error",
      detail: subErr.message
    }, 500);
    const { data: tiers } = await admin.from("subscription_tiers").select("id, display_order, name, range_label, max_active, price_cents, currency, stripe_price_id, is_contact_only, active").eq("active", true).order("display_order");
    if (!tiers || tiers.length === 0) return json({
      error: "no_tiers"
    }, 500);
    const tierById = Object.fromEntries(tiers.map((t)=>[
        t.id,
        t
      ]));
    const results = [];
    for (const sub of subs ?? []){
      const result = {
        sub_id: sub.id,
        stripe_subscription_id: sub.stripe_subscription_id,
        pastor: sub.pastor_user_id,
        current_tier_id: sub.tier_id
      };
      try {
        // Skip honeymoon: don't right-size trialing subs.
        if (sub.status === "trialing") {
          await admin.from("stripe_subscriptions").update({
            last_synced_at: new Date().toISOString()
          }).eq("id", sub.id);
          result.action = "skipped_trial";
          results.push(result);
          continue;
        }
        const { data: count } = await admin.rpc("pastor_active_user_count", {
          _pastor_user_id: sub.pastor_user_id
        });
        const activeCount = count ?? 0;
        result.active_count = activeCount;
        const { data: target } = await admin.rpc("target_tier_for_count", {
          _count: activeCount
        });
        const targetId = target ?? sub.tier_id;
        result.target_tier_id = targetId;
        const currentTier = tierById[sub.tier_id];
        const targetTier = tierById[targetId];
        if (!currentTier || !targetTier) {
          result.action = "skipped_unknown_tier";
          results.push(result);
          continue;
        }
        // 1. Apply pending downgrade whose effective_at has passed
        if (sub.pending_tier_id && sub.pending_effective_at && new Date(sub.pending_effective_at).getTime() <= Date.now()) {
          const pendingTier = tierById[sub.pending_tier_id];
          if (pendingTier?.stripe_price_id) {
            const stripeSub = await stripeApi("GET", `/v1/subscriptions/${sub.stripe_subscription_id}`, null, STRIPE_KEY);
            const itemId = stripeSub?.items?.data?.[0]?.id;
            if (itemId) {
              const params = new URLSearchParams();
              params.append("items[0][id]", itemId);
              params.append("items[0][price]", pendingTier.stripe_price_id);
              params.append("proration_behavior", "none");
              const updated = await stripeApi("POST", `/v1/subscriptions/${sub.stripe_subscription_id}`, params, STRIPE_KEY);
              if (updated?.error) throw new Error(`stripe.update: ${JSON.stringify(updated.error)}`);
              await admin.from("stripe_subscriptions").update({
                tier_id: sub.pending_tier_id,
                stripe_price_id: pendingTier.stripe_price_id,
                pending_tier_id: null,
                pending_effective_at: null,
                last_synced_at: new Date().toISOString()
              }).eq("id", sub.id);
              await sendDowngradeApplied(admin, sub, currentTier, pendingTier, RESEND_KEY);
              result.action = "applied_pending_downgrade";
              results.push(result);
              continue;
            }
          }
        }
        // 2. No change
        if (targetId === sub.tier_id) {
          const patch = {
            last_synced_at: new Date().toISOString()
          };
          if (sub.pending_tier_id) {
            patch.pending_tier_id = null;
            patch.pending_effective_at = null;
            result.action = "cleared_stale_pending_downgrade";
          } else {
            result.action = "no_change";
          }
          await admin.from("stripe_subscriptions").update(patch).eq("id", sub.id);
          results.push(result);
          continue;
        }
        // 3. Contact-only threshold — flag, alert founder
        if (targetTier.is_contact_only) {
          await admin.from("stripe_subscriptions").update({
            last_synced_at: new Date().toISOString()
          }).eq("id", sub.id);
          await sendContactThresholdFounderAlert(admin, sub, activeCount, RESEND_KEY);
          result.action = "crossed_contact_us_threshold";
          results.push(result);
          continue;
        }
        // 4. Upgrade — immediate, prorated
        if (targetTier.display_order > currentTier.display_order) {
          if (!targetTier.stripe_price_id) {
            result.action = "upgrade_skipped_no_price_id";
            results.push(result);
            continue;
          }
          const stripeSub = await stripeApi("GET", `/v1/subscriptions/${sub.stripe_subscription_id}`, null, STRIPE_KEY);
          const itemId = stripeSub?.items?.data?.[0]?.id;
          if (!itemId) throw new Error("no_subscription_item_id");
          const params = new URLSearchParams();
          params.append("items[0][id]", itemId);
          params.append("items[0][price]", targetTier.stripe_price_id);
          params.append("proration_behavior", "create_prorations");
          const updated = await stripeApi("POST", `/v1/subscriptions/${sub.stripe_subscription_id}`, params, STRIPE_KEY);
          if (updated?.error) throw new Error(`stripe.update: ${JSON.stringify(updated.error)}`);
          await admin.from("stripe_subscriptions").update({
            tier_id: targetId,
            stripe_price_id: targetTier.stripe_price_id,
            pending_tier_id: null,
            pending_effective_at: null,
            last_synced_at: new Date().toISOString()
          }).eq("id", sub.id);
          await sendUpgradeEmail(admin, sub, currentTier, targetTier, activeCount, RESEND_KEY);
          result.action = "upgraded_immediately";
          results.push(result);
          continue;
        }
        // 5. Downgrade — queue for current_period_end
        if (targetTier.display_order < currentTier.display_order) {
          if (sub.pending_tier_id === targetId) {
            await admin.from("stripe_subscriptions").update({
              last_synced_at: new Date().toISOString()
            }).eq("id", sub.id);
            result.action = "downgrade_already_queued";
            results.push(result);
            continue;
          }
          await admin.from("stripe_subscriptions").update({
            pending_tier_id: targetId,
            pending_effective_at: sub.current_period_end,
            last_synced_at: new Date().toISOString()
          }).eq("id", sub.id);
          await sendDowngradeScheduled(admin, sub, currentTier, targetTier, sub.current_period_end, RESEND_KEY);
          result.action = "downgrade_scheduled";
          result.effective_at = sub.current_period_end;
          results.push(result);
          continue;
        }
      } catch (err) {
        result.error = String(err?.message ?? err);
        await admin.from("stripe_subscriptions").update({
          last_synced_at: new Date().toISOString()
        }).eq("id", sub.id);
        results.push(result);
      }
    }
    return json({
      ok: true,
      processed: results.length,
      results
    });
  } catch (e) {
    return json({
      error: "unhandled",
      detail: String(e?.message ?? e)
    }, 500);
  }
});
// ---------- Email helpers ----------
async function getPastorContext(admin, sub) {
  // Email from auth.users
  const { data: userRow } = await admin.from("profiles").select("email, display_name").eq("id", sub.pastor_user_id).maybeSingle();
  if (!userRow?.email) return null;
  const firstName = (userRow.display_name ?? userRow.email).split(/\s+/)[0];
  let churchName = "your church";
  const { data: yg } = await admin.from("youth_groups").select("church_name, name").eq("id", sub.group_id).maybeSingle();
  if (yg) churchName = yg.church_name ?? yg.name ?? churchName;
  return {
    email: userRow.email,
    firstName,
    churchName
  };
}
async function sendUpgradeEmail(admin, sub, oldTier, newTier, activeCount, resendKey) {
  if (!resendKey) return;
  const ctx = await getPastorContext(admin, sub);
  if (!ctx) return;
  const newPrice = (newTier.price_cents / 100).toFixed(0);
  const subject = `You're on ${newTier.name} now — ${ctx.churchName} grew past ${oldTier.max_active}`;
  const html = `<!doctype html><html><body style="font-family:-apple-system,Segoe UI,Helvetica,Arial,sans-serif;color:#222;line-height:1.55;max-width:560px">
<p>Hey ${ctx.firstName},</p>
<p>Quick heads-up — <b>${ctx.churchName}</b> just grew past the <b>${oldTier.name}</b> ceiling (${oldTier.range_label} active students). We've auto-bumped you to <b>${newTier.name}</b> (${newTier.range_label} students, $${newPrice}/mo).</p>
<p>You currently have <b>${activeCount} active students</b>. Your next invoice will be prorated for the rest of this billing cycle, then it settles at $${newPrice}/mo going forward.</p>
<p>This is exactly how YGTeeV billing is meant to work — you only pay for the size you actually have, and we adjust automatically as you grow.</p>
<p><a href="${BILLING_URL}">Manage your billing →</a></p>
<p>— Jim<br/><small style="color:#666">Founder, YGTeeV</small></p></body></html>`;
  const text = `Hey ${ctx.firstName},\n\n${ctx.churchName} just grew past the ${oldTier.name} ceiling (${oldTier.range_label} students). We've auto-bumped you to ${newTier.name} (${newTier.range_label}, $${newPrice}/mo).\n\nYou currently have ${activeCount} active students. Your next invoice will be prorated, then settles at $${newPrice}/mo.\n\nThis is how YGTeeV billing works — pay for the size you actually have, adjust as you grow.\n\nManage billing: ${BILLING_URL}\n\n— Jim\nFounder, YGTeeV`;
  await sendResend(resendKey, ctx.email, subject, html, text);
}
async function sendDowngradeScheduled(admin, sub, current, next, effectiveIso, resendKey) {
  if (!resendKey) return;
  const ctx = await getPastorContext(admin, sub);
  if (!ctx) return;
  const newPrice = (next.price_cents / 100).toFixed(0);
  const eff = new Date(effectiveIso).toLocaleDateString("en-US", {
    month: "long",
    day: "numeric"
  });
  const subject = `Your YGTeeV plan adjusts on ${eff}`;
  const html = `<!doctype html><html><body style="font-family:-apple-system,Segoe UI,Helvetica,Arial,sans-serif;color:#222;line-height:1.55;max-width:560px">
<p>Hey ${ctx.firstName},</p>
<p>Heads up — <b>${ctx.churchName}</b>'s active student count dropped below the <b>${current.name}</b> floor. To keep your bill aligned, we've scheduled a switch to <b>${next.name}</b> (${next.range_label} students, $${newPrice}/mo) on <b>${eff}</b>.</p>
<p>If your active count grows back over <b>${current.range_label.split('—')[0]}</b> students before then, we'll cancel this automatically — no action needed.</p>
<p>This is part of how YGTeeV billing works: you only pay for the size you actually have, and we adjust as you grow or shrink.</p>
<p><a href="${BILLING_URL}">Manage your billing →</a></p>
<p>— Jim<br/><small style="color:#666">Founder, YGTeeV</small></p></body></html>`;
  const text = `Hey ${ctx.firstName},\n\n${ctx.churchName}'s active student count dropped below the ${current.name} floor. We've scheduled a switch to ${next.name} (${next.range_label}, $${newPrice}/mo) on ${eff}.\n\nIf your active count grows back before then, we'll cancel this automatically.\n\nManage billing: ${BILLING_URL}\n\n— Jim\nFounder, YGTeeV`;
  await sendResend(resendKey, ctx.email, subject, html, text);
}
async function sendDowngradeApplied(admin, sub, old, current, resendKey) {
  if (!resendKey) return;
  const ctx = await getPastorContext(admin, sub);
  if (!ctx) return;
  const newPrice = (current.price_cents / 100).toFixed(0);
  const subject = `Welcome to ${current.name} — your plan adjusted`;
  const html = `<!doctype html><html><body style="font-family:-apple-system,Segoe UI,Helvetica,Arial,sans-serif;color:#222;line-height:1.55;max-width:560px">
<p>Hey ${ctx.firstName},</p>
<p>Your billing period rolled over and your plan adjusted from <b>${old.name}</b> to <b>${current.name}</b> ($${newPrice}/mo). Your next invoice will be at the new rate.</p>
<p>If your group grows again, we'll auto-upgrade you back up.</p>
<p><a href="${BILLING_URL}">Manage your billing →</a></p>
<p>— Jim<br/><small style="color:#666">Founder, YGTeeV</small></p></body></html>`;
  const text = `Hey ${ctx.firstName},\n\nYour billing period rolled over and your plan adjusted from ${old.name} to ${current.name} ($${newPrice}/mo). Next invoice at the new rate.\n\nIf your group grows again, we'll auto-upgrade.\n\nManage billing: ${BILLING_URL}\n\n— Jim`;
  await sendResend(resendKey, ctx.email, subject, html, text);
}
async function sendContactThresholdFounderAlert(admin, sub, activeCount, resendKey) {
  if (!resendKey) return;
  const ctx = await getPastorContext(admin, sub);
  if (!ctx) return;
  const FOUNDER = Deno.env.get("YGTEEV_FOUNDER_EMAIL") ?? "jim@ygteev.com";
  const subject = `🚀 ${ctx.churchName} crossed 500 active students`;
  const body = `Pastor ${ctx.firstName} (${ctx.email}) at ${ctx.churchName} now has ${activeCount} active students — past the YGTeeV 5 ceiling.\n\nTime for an enterprise conversation. Their subscription is still on whatever tier they were last on; no auto-action was taken.`;
  await sendResend(resendKey, FOUNDER, subject, `<pre>${body}</pre>`, body);
}
async function sendResend(resendKey, to, subject, html, text) {
  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${resendKey}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        from: `${FROM_NAME} <${FROM_ADDR}>`,
        to: [
          to
        ],
        subject,
        html,
        text
      })
    });
    if (!res.ok) console.log("[sync-pastor-billing] resend failed", res.status, await res.text());
  } catch (e) {
    console.log("[sync-pastor-billing] resend threw", String(e?.message ?? e));
  }
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
function json(payload, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      "Content-Type": "application/json"
    }
  });
}
