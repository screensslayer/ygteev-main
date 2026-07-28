// Pastor onboarding drip — 5 emails over the ~9 days after signup.
// Same voice/envelope as send-pastor-welcome-email (Jim @ YGTeeV, Resend).
//
// Modes:
//   { group_id, email_no, test_to }  -> reroute one email to an allowlisted
//                                       internal address (no logging).
//   { group_id, email_no }           -> send that email to the group's pastor,
//                                       logged in pastor_onboarding_emails
//                                       (unique group_id+email_no = never twice).
//   { dispatch: true }               -> daily cron entry point: for every real
//                                       group created in the last 45 days, send
//                                       the lowest unsent email whose day
//                                       threshold has passed (max 1/group/run).
//
// Schedule (days since group creation): 1, 3, 5, 7, 9.
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
const APP_STORE_URL = "https://apps.apple.com/us/app/ygteev/id6773066416";
const TEST_RECIPIENTS = [
  "jimjacob10@gmail.com",
  "jim@ygteev.com"
];
const SCHEDULE = {
  1: 1,
  2: 3,
  3: 5,
  4: 7,
  5: 9
};
const BTN = 'display:inline-block; background:#6B2BFF; color:#fff; text-decoration:none; padding:12px 18px; border-radius:10px; font-weight:600;';
function wrap(inner) {
  return `<!doctype html>
<html><body style="font-family: -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial, sans-serif; color:#222; line-height:1.55; max-width:560px;">
${inner}
</body></html>`;
}
const EMAILS = {
  1: {
    subject: "First move: read John 1, then go plant something",
    html: wrap(`<p>Hey there,</p>
<p>We are pumped to have your youth group live on the YGTeeV map. Over the next week and a half I'll send you a short series &mdash; launching to your students and families, how messaging and moderation work, building your own Bible plans, and running events. Nothing long. One useful thing per email.</p>
<p>Today there are just two moves, and they take ten minutes total:</p>
<p><strong>1. Get the app and log in with your registered email.</strong> That email is what unlocks your pastor permissions &mdash; accepting member requests, creating events, moderation alerts, the whole control room.</p>
<p><a href="${APP_STORE_URL}" style="${BTN}">Download YGTeeV</a></p>
<p><strong>2. Play it before you preach it.</strong> Complete Day 1 of the John plan (it's John 1 &mdash; five minutes), then walk into the Backyard with the XP you just earned. Buy a seed in the town market, plant your first garden, sell some fruit, peek at the rare seeds. Then visit your youth group's community garden &mdash; that's the one your students grow together. Every day of reading they complete feeds it, and the group's Glowberries each week are how you win the weekly challenge.</p>
<p>You can't hype what you haven't played. Go read, go plant, and you'll get exactly why students keep coming back.</p>
<p>Jim<br/><small style="color:#666">Founder, YGTeeV</small></p>`),
    text: `Hey there,

We are pumped to have your youth group live on the YGTeeV map. Over the next week and a half I'll send you a short series -- launching to your students and families, how messaging and moderation work, building your own Bible plans, and running events. Nothing long. One useful thing per email.

Today there are just two moves, and they take ten minutes total:

1. Get the app and log in with your registered email. That email is what unlocks your pastor permissions -- accepting member requests, creating events, moderation alerts, the whole control room.

Download YGTeeV: ${APP_STORE_URL}

2. Play it before you preach it. Complete Day 1 of the John plan (it's John 1 -- five minutes), then walk into the Backyard with the XP you just earned. Buy a seed in the town market, plant your first garden, sell some fruit, peek at the rare seeds. Then visit your youth group's community garden -- that's the one your students grow together. Every day of reading they complete feeds it, and the group's Glowberries each week are how you win the weekly challenge.

You can't hype what you haven't played. Go read, go plant, and you'll get exactly why students keep coming back.

Jim
Founder, YGTeeV`
  },
  2: {
    subject: "How messaging works (and what moderation catches)",
    html: wrap(`<p>Hey there,</p>
<p>Messaging is the part parents will ask you about, so here's the whole model in one email.</p>
<p><strong>There are two kinds of messaging: group chats and 1-1 DMs.</strong></p>
<p>Your youth group automatically gets a <strong>Main Group Chat</strong> (you, your leaders, your students) and a <strong>Parent Group Chat</strong> (you, your leaders, and parents). Every small group you create gets its own chat with its leader and students. Events can spin up a chat for everyone who RSVP'd yes. And as the pastor, you can create custom group chats with whoever you choose.</p>
<p><strong>There is no student-to-student messaging. Period.</strong> It doesn't exist on the platform, so there's no setting to get wrong.</p>
<p>1-1 DMs are off until you turn them on &mdash; and even then, they only connect a student to you or to their small group leader. Parents can switch 1-1 messaging off for their own child at any time.</p>
<p><strong>Now the important part: moderation.</strong></p>
<p>Every message on YGTeeV &mdash; from every person, leaders and pastors included &mdash; is screened by AI before it's delivered. In group chats, that means bullying, sexual content, slurs, and threats get <strong>held before anyone ever sees them</strong>. Nothing is silently deleted: the held message comes to you with one-tap review and release, so a human adult always makes the final call.</p>
<p>In 1-1 DMs, the screening also listens for the quiet stuff &mdash; self-harm language, crisis signals &mdash; and flags it straight to you. A student who's hurting and types it into a DM at midnight is never actually alone in that conversation.</p>
<p>That's the system. You'll probably never need most of it. That's the point.</p>
<p>Jim</p>`),
    text: `Hey there,

Messaging is the part parents will ask you about, so here's the whole model in one email.

There are two kinds of messaging: group chats and 1-1 DMs.

Your youth group automatically gets a Main Group Chat (you, your leaders, your students) and a Parent Group Chat (you, your leaders, and parents). Every small group you create gets its own chat with its leader and students. Events can spin up a chat for everyone who RSVP'd yes. And as the pastor, you can create custom group chats with whoever you choose.

There is no student-to-student messaging. Period. It doesn't exist on the platform, so there's no setting to get wrong.

1-1 DMs are off until you turn them on -- and even then, they only connect a student to you or to their small group leader. Parents can switch 1-1 messaging off for their own child at any time.

Now the important part: moderation.

Every message on YGTeeV -- from every person, leaders and pastors included -- is screened by AI before it's delivered. In group chats, that means bullying, sexual content, slurs, and threats get held before anyone ever sees them. Nothing is silently deleted: the held message comes to you with one-tap review and release, so a human adult always makes the final call.

In 1-1 DMs, the screening also listens for the quiet stuff -- self-harm language, crisis signals -- and flags it straight to you. A student who's hurting and types it into a DM at midnight is never actually alone in that conversation.

That's the system. You'll probably never need most of it. That's the point.

Jim`
  },
  3: {
    subject: "The launch play: one challenge, one QR code",
    html: wrap(`<p>Hey there,</p>
<p>Time to put this in front of your students. The launches that work best don't start with "download this app" &mdash; they start with a challenge.</p>
<p><strong>Pick a number and throw down.</strong> Something like: <em>50 students finish the entire John plan in 30 days.</em> (Use 50, 100, or 200 depending on your size &mdash; it should feel just barely possible.) If they crush it, throw a party to celebrate. Students literally watch the progress stack up in the community garden every week, so the challenge sells itself after week one.</p>
<p><strong>Getting everyone in takes one slide.</strong> Open the app, go to <strong>Me</strong>, and tap the QR code at the top right. Print it or throw it on the screen &mdash; students and parents scan it and they're in instantly. (Anyone who misses it can also download the app, tap "join a group," and send you a request to approve.)</p>
<p><strong>Don't skip the parents.</strong> Invite them to download the app too &mdash; they get the parent chat, their student's event RSVPs, and updates without you sending a single group text. Parents who can see what's happening become your loudest supporters.</p>
<p>Challenge. QR code. Parents. That's the whole launch.</p>
<p>Jim</p>`),
    text: `Hey there,

Time to put this in front of your students. The launches that work best don't start with "download this app" -- they start with a challenge.

Pick a number and throw down. Something like: 50 students finish the entire John plan in 30 days. (Use 50, 100, or 200 depending on your size -- it should feel just barely possible.) If they crush it, throw a party to celebrate. Students literally watch the progress stack up in the community garden every week, so the challenge sells itself after week one.

Getting everyone in takes one slide. Open the app, go to Me, and tap the QR code at the top right. Print it or throw it on the screen -- students and parents scan it and they're in instantly. (Anyone who misses it can also download the app, tap "join a group," and send you a request to approve.)

Don't skip the parents. Invite them to download the app too -- they get the parent chat, their student's event RSVPs, and updates without you sending a single group text. Parents who can see what's happening become your loudest supporters.

Challenge. QR code. Parents. That's the whole launch.

Jim`
  },
  4: {
    subject: "Build a Bible plan that matches your sermon series",
    html: wrap(`<p>Hey there,</p>
<p>The built-in plans are the on-ramp. The real magic is when Sunday's message becomes Monday's plan.</p>
<p>On the <strong>Me</strong> page, open your Pastor Dashboard and tap <strong>Bible Plans</strong>. That's the plan builder: name your plan, choose how many days it runs, and then build each day from blocks &mdash;</p>
<ul>
<li>Bible reading</li>
<li>Commentary (yours, in your voice)</li>
<li>Video</li>
<li>Multiple choice questions</li>
<li>Prayer prompt</li>
</ul>
<p>Mix them however you want. A day can be a reading and one question; it can be a video, a passage, and a prayer. The plans that hit hardest are the ones that ride alongside whatever series you're preaching &mdash; your students spend the week inside the same passage you opened on Sunday.</p>
<p>When you publish, the plan shows up on every student's Play page immediately, and it earns XP and grows their garden just like everything else.</p>
<p>Build one this week, even a short three-day one. Your students notice fast when the plan sounds like <em>you</em>.</p>
<p>Jim</p>`),
    text: `Hey there,

The built-in plans are the on-ramp. The real magic is when Sunday's message becomes Monday's plan.

On the Me page, open your Pastor Dashboard and tap Bible Plans. That's the plan builder: name your plan, choose how many days it runs, and then build each day from blocks --

  - Bible reading
  - Commentary (yours, in your voice)
  - Video
  - Multiple choice questions
  - Prayer prompt

Mix them however you want. A day can be a reading and one question; it can be a video, a passage, and a prayer. The plans that hit hardest are the ones that ride alongside whatever series you're preaching -- your students spend the week inside the same passage you opened on Sunday.

When you publish, the plan shows up on every student's Play page immediately, and it earns XP and grows their garden just like everything else.

Build one this week, even a short three-day one. Your students notice fast when the plan sounds like you.

Jim`
  },
  5: {
    subject: "Events your students will actually RSVP to",
    html: wrap(`<p>Hey there,</p>
<p>Last one in the series, and it might be the most underrated feature you have: a full event and RSVP system, included in your plan.</p>
<p>When you create an event, you get the kind of invite experience people expect in 2026 &mdash; clean invite, one-tap RSVP, and a guest list that builds itself. No spreadsheet, no "comment below if you're coming."</p>
<p>A few switches worth knowing when you create one:</p>
<ul>
<li><strong>Event group chat</strong> &mdash; spin up a chat just for the people who said yes. Perfect for "we leave at 6, bring a hoodie."</li>
<li><strong>Public or members-only</strong> &mdash; make a worship night visible to the whole community, or keep the leaders' retreat private.</li>
<li><strong>Invite a friend</strong> &mdash; students share a link, and their friends can RSVP from it. Your students become the invitation.</li>
</ul>
<p>Then the part nobody else does: after the event, post the photos and videos straight to it. They stay with the event forever &mdash; everyone who attended keeps the memory in their pocket, and every album quietly makes the next invite easier to say yes to.</p>
<p>Worship night, retreat, lock-in, donut run. Create one this week and let the RSVPs roll in.</p>
<p>That's the series. You know where everything lives now &mdash; and I'm one reply away whenever something's confusing or missing.</p>
<p>Jim</p>`),
    text: `Hey there,

Last one in the series, and it might be the most underrated feature you have: a full event and RSVP system, included in your plan.

When you create an event, you get the kind of invite experience people expect in 2026 -- clean invite, one-tap RSVP, and a guest list that builds itself. No spreadsheet, no "comment below if you're coming."

A few switches worth knowing when you create one:

  - Event group chat -- spin up a chat just for the people who said yes. Perfect for "we leave at 6, bring a hoodie."
  - Public or members-only -- make a worship night visible to the whole community, or keep the leaders' retreat private.
  - Invite a friend -- students share a link, and their friends can RSVP from it. Your students become the invitation.

Then the part nobody else does: after the event, post the photos and videos straight to it. They stay with the event forever -- everyone who attended keeps the memory in their pocket, and every album quietly makes the next invite easier to say yes to.

Worship night, retreat, lock-in, donut run. Create one this week and let the RSVPs roll in.

That's the series. You know where everything lives now -- and I'm one reply away whenever something's confusing or missing.

Jim`
  }
};
async function sendEmail(to, emailNo) {
  const RESEND_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
  if (!RESEND_KEY) return { ok: false, error: "resend_api_key_missing" };
  const tpl = EMAILS[emailNo];
  if (!tpl) return { ok: false, error: "unknown_email_no" };
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${RESEND_KEY}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      from: `${FROM_NAME} <${FROM_ADDRESS}>`,
      to: [to],
      reply_to: REPLY_TO,
      subject: tpl.subject,
      html: tpl.html,
      text: tpl.text
    })
  });
  const j = await res.json().catch(() => ({}));
  if (!res.ok) {
    console.log("[pastor-onboarding] Resend error", res.status, j);
    return { ok: false, error: "resend_failed", detail: j };
  }
  return { ok: true, message_id: j?.id ?? null };
}
async function pastorEmailForGroup(admin, groupId) {
  const { data: membership } = await admin.from("youth_group_members").select("user_id").eq("group_id", groupId).eq("role", "pastor").limit(1).maybeSingle();
  if (!membership?.user_id) return null;
  const { data: profile } = await admin.from("profiles").select("email").eq("id", membership.user_id).maybeSingle();
  return profile?.email ?? null;
}
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", {
    headers: cors
  });
  try {
    const body = await req.json().catch(() => null);
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
    const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const admin = createClient(SUPABASE_URL, SERVICE);
    // ── dispatch mode (daily cron) ──
    if (body?.dispatch === true) {
      const { data: groups } = await admin.from("youth_groups").select("id, created_at").eq("is_default_ygteev", false).gte("created_at", new Date(Date.now() - 45 * 86400000).toISOString());
      const results = [];
      for (const g of groups ?? []) {
        const days = Math.floor((Date.now() - new Date(g.created_at).getTime()) / 86400000);
        const { data: sent } = await admin.from("pastor_onboarding_emails").select("email_no").eq("group_id", g.id);
        const sentNos = new Set((sent ?? []).map((r) => r.email_no));
        let due = null;
        for (const no of [1, 2, 3, 4, 5]) {
          if (!sentNos.has(no) && days >= SCHEDULE[no]) {
            due = no;
            break;
          }
        }
        if (!due) continue;
        // claim the slot first — unique(group_id,email_no) makes this race-safe
        const { data: claimed } = await admin.from("pastor_onboarding_emails").insert({
          group_id: g.id,
          email_no: due
        }).select("id").maybeSingle();
        if (!claimed) continue; // already sent by a concurrent run
        const to = await pastorEmailForGroup(admin, g.id);
        if (!to) {
          console.log("[pastor-onboarding] no pastor email for group", g.id);
          continue;
        }
        const r = await sendEmail(to, due);
        results.push({ group_id: g.id, email_no: due, ...r });
        if (!r.ok) {
          // release the claim so tomorrow's run retries
          await admin.from("pastor_onboarding_emails").delete().eq("id", claimed.id);
        }
      }
      return json({ ok: true, dispatched: results });
    }
    // ── single-send / test mode ──
    const groupId = body?.group_id;
    const emailNo = Number(body?.email_no);
    if (!groupId || !EMAILS[emailNo]) return json({
      error: "missing_group_id_or_email_no"
    }, 400);
    const testTo = typeof body?.test_to === "string" && TEST_RECIPIENTS.includes(body.test_to.toLowerCase()) ? body.test_to.toLowerCase() : null;
    if (testTo) {
      const r = await sendEmail(testTo, emailNo);
      return json({ ...r, to: testTo, email_no: emailNo, test: true }, r.ok ? 200 : 502);
    }
    const to = await pastorEmailForGroup(admin, groupId);
    if (!to) return json({
      error: "pastor_email_not_found"
    }, 404);
    const { data: claimed } = await admin.from("pastor_onboarding_emails").insert({
      group_id: groupId,
      email_no: emailNo
    }).select("id").maybeSingle();
    if (!claimed) return json({
      ok: true,
      already_sent: true,
      email_no: emailNo
    });
    const r = await sendEmail(to, emailNo);
    if (!r.ok) {
      await admin.from("pastor_onboarding_emails").delete().eq("id", claimed.id);
      return json(r, 502);
    }
    return json({ ...r, to, email_no: emailNo });
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
