// v14: Bumped STRICT_THRESHOLD from 0.15 to 0.25. The pastoral-concern
// classifier (added in v13) now catches the soft signals that 0.15 was
// over-firing on, so the policy threshold can focus on real harassment
// / hate / violence again. Comment-only change is the threshold line.
//
// v13: Added pastoral-concern classifier as an ADDITIVE step.
//
// Flow:
//   1. OpenAI Moderation API (unchanged from v12)
//   2. Decide status: clean | flagged_allowed | flagged_blocked
//      (also unchanged)
//   3. NEW: If status === 'clean', run gpt-4o-mini with a YGTeeV
//      pastoral-concern prompt. If it returns a concern with
//      confidence >= 0.6, insert a soft alert row into
//      moderation_alerts (status=flagged_allowed, concern_category
//      populated). The message itself stays 'clean' and visible.
//
// Best-effort: any classifier failure (no key, timeout, bad JSON)
// is logged and silently ignored. The message still ships.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json"
};
const STRICT_THRESHOLD = 0.25; // v14: 0.15 → 0.25, paired with pastoral classifier.
const WATCHED_CATEGORIES = [
  "harassment",
  "harassment/threatening",
  "hate",
  "hate/threatening",
  "violence",
  "violence/graphic",
  "sexual",
  "sexual/minors",
  "self-harm",
  "self-harm/intent",
  "self-harm/instructions"
];
// Pastoral concern classifier config
const PASTORAL_CONFIDENCE_THRESHOLD = 0.6;
const PASTORAL_VALID_CATEGORIES = new Set([
  "identity_question",
  "temptation_struggle",
  "mental_health",
  "self_harm_signal",
  "relationship_distress",
  "faith_doubt",
  "none"
]);
const PASTORAL_SYSTEM_PROMPT = `You are helping a youth pastor identify teen messages that warrant a caring follow-up conversation. The teens use a chat app to talk with their pastor, small-group leader, parents, and each other.

Classify the user's message into EXACTLY ONE category:

- identity_question: Teen is questioning sexual orientation, gender identity, or core sense of self. Examples: "I think I'm gay", "I don't feel like a girl anymore", "I'm attracted to guys".
- temptation_struggle: Teen confesses an internal struggle with lust, porn, substance use, gambling, eating, etc. Examples: "I'm struggling with lust", "I can't stop watching porn", "I've been drinking again".
- mental_health: Sadness, depression, hopelessness, anxiety, burnout, low self-worth — not graphic self-harm. Examples: "I'm in a dark place", "I feel hopeless", "nothing matters anymore", "I'm so tired of everything".
- self_harm_signal: Direct or oblique reference to self-harm or suicidal thoughts. Examples: "I want to kill myself", "sometimes I think about hurting myself", "what if I just stopped existing". Even subtle.
- relationship_distress: Family conflict, abuse hints, broken friendships, romantic breakups with significant emotional weight. Examples: "my dad hits me", "my parents hate me", "my boyfriend cheated on me and I can't take it".
- faith_doubt: Genuine doubt about God, theology, or church — beyond casual questions. Examples: "I don't think God is real anymore", "why does God let bad things happen", "I don't believe in any of this".
- none: Normal teen conversation. Greetings, plans, jokes, mild venting, schoolwork chat, etc.

Be conservative. "none" is the right answer most of the time. Only flag if a thoughtful pastor would genuinely want to know so they can reach out.

Return STRICT JSON with these keys exactly:
{
  "category": one of the above,
  "confidence": 0.0 to 1.0,
  "reason": brief 1-sentence explanation of why
}`;
async function classifyPastoralConcern(text, apiKey) {
  if (!apiKey) return null;
  try {
    const res = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content: PASTORAL_SYSTEM_PROMPT
          },
          {
            role: "user",
            content: text
          }
        ],
        response_format: {
          type: "json_object"
        },
        temperature: 0.1,
        max_tokens: 200
      })
    });
    if (!res.ok) {
      console.log("[pastoral] non-ok", res.status, await res.text());
      return null;
    }
    const j = await res.json();
    const content = j?.choices?.[0]?.message?.content;
    if (!content) return null;
    const parsed = JSON.parse(content);
    const category = String(parsed?.category ?? "none");
    const confidence = Number(parsed?.confidence ?? 0);
    const reason = String(parsed?.reason ?? "");
    if (!PASTORAL_VALID_CATEGORIES.has(category)) return null;
    if (!Number.isFinite(confidence)) return null;
    return {
      category,
      confidence,
      reason
    };
  } catch (e) {
    console.log("[pastoral] threw", String(e));
    return null;
  }
}
Deno.serve(async (req)=>{
  if (req.method === "OPTIONS") return new Response("ok", {
    headers: corsHeaders
  });
  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) return json({
      error: "unauthorized"
    }, 401);
    const reqBody = await req.json().catch(()=>null);
    const threadId = reqBody?.thread_id;
    const text = reqBody?.body;
    if (!threadId || typeof text !== "string" || text.trim().length === 0 || text.length > 4000) {
      return json({
        error: "invalid_payload"
      }, 400);
    }
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
    const ANON = Deno.env.get("SUPABASE_ANON_KEY");
    const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const OPENAI = Deno.env.get("OPENAI_API_KEY") ?? "";
    console.log("[mod] in", {
      threadId,
      textLen: text.length,
      hasKey: OPENAI.length > 0
    });
    const userClient = createClient(SUPABASE_URL, ANON, {
      global: {
        headers: {
          Authorization: authHeader
        }
      }
    });
    const { data: userData, error: userErr } = await userClient.auth.getUser();
    if (userErr || !userData?.user) return json({
      error: "unauthorized"
    }, 401);
    const userId = userData.user.id;
    const admin = createClient(SUPABASE_URL, SERVICE);
    const { data: sub } = await admin.from("thread_subscribers").select("id").eq("thread_id", threadId).eq("user_id", userId).maybeSingle();
    if (!sub) return json({
      error: "not_a_subscriber"
    }, 403);
    const { data: thread } = await admin.from("chat_threads").select("id, group_id, moderation_policy").eq("id", threadId).maybeSingle();
    if (!thread) return json({
      error: "thread_not_found"
    }, 404);
    // --- OpenAI Moderation (unchanged from v12) ---
    let flagged = false;
    let flaggedCategories = [];
    let categoryScores = {};
    let modError = null;
    if (!OPENAI) {
      modError = "no_api_key";
    } else {
      try {
        const modRes = await fetch("https://api.openai.com/v1/moderations", {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${OPENAI}`,
            "Content-Type": "application/json"
          },
          body: JSON.stringify({
            model: "omni-moderation-latest",
            input: text
          })
        });
        const modJson = await modRes.json().catch(()=>null);
        console.log("[mod] openai", {
          status: modRes.status,
          ok: modRes.ok,
          body: modJson
        });
        if (modRes.ok && modJson) {
          const r = modJson?.results?.[0];
          flagged = !!r?.flagged;
          if (r?.categories) {
            flaggedCategories = Object.entries(r.categories).filter(([, v])=>v === true).map(([k])=>k);
          }
          if (r?.category_scores) {
            categoryScores = r.category_scores;
          }
          for (const cat of WATCHED_CATEGORIES){
            const score = categoryScores[cat] ?? 0;
            if (score >= STRICT_THRESHOLD && !flaggedCategories.includes(cat)) {
              flaggedCategories.push(cat);
              flagged = true;
            }
          }
        } else {
          modError = `openai status ${modRes.status}`;
        }
      } catch (e) {
        modError = String(e?.message ?? e);
      }
    }
    console.log("[mod] decision", {
      flagged,
      flaggedCategories,
      policy: thread.moderation_policy,
      modError
    });
    let status = "clean";
    if (flagged) {
      status = thread.moderation_policy === "block" ? "flagged_blocked" : "flagged_allowed";
    }
    const persistedCategories = flagged ? {
      flagged: flaggedCategories,
      scores: categoryScores,
      modError
    } : {
      scores: categoryScores,
      modError
    };
    let insertedMessage = null;
    if (status !== "flagged_blocked") {
      const { data, error } = await admin.from("messages").insert({
        thread_id: threadId,
        sender_id: userId,
        body: text,
        moderation_status: status,
        moderation_categories: persistedCategories
      }).select().single();
      if (error) return json({
        error: error.message
      }, 500);
      insertedMessage = data;
      await admin.from("chat_threads").update({
        last_message_at: data.created_at
      }).eq("id", threadId);
    }
    // --- Alert path: OpenAI flag (unchanged) ---
    if (flagged) {
      await admin.from("moderation_alerts").insert({
        thread_id: threadId,
        message_id: insertedMessage?.id ?? null,
        group_id: thread.group_id,
        sender_id: userId,
        status,
        categories: persistedCategories,
        preview: text.slice(0, 300)
      });
    }
    // --- NEW: Pastoral concern classifier ---
    // Only run on messages OpenAI marked clean. If OpenAI already
    // flagged it, the pastor sees it via the policy alert above; no
    // need to spend a second LLM call.
    if (status === "clean" && insertedMessage) {
      const concern = await classifyPastoralConcern(text, OPENAI);
      if (concern && concern.category !== "none" && concern.confidence >= PASTORAL_CONFIDENCE_THRESHOLD) {
        console.log("[pastoral] flagged", concern);
        await admin.from("moderation_alerts").insert({
          thread_id: threadId,
          message_id: insertedMessage.id,
          group_id: thread.group_id,
          sender_id: userId,
          status: "flagged_allowed",
          categories: {
            pastoral: true
          },
          preview: text.slice(0, 300),
          concern_category: concern.category,
          concern_confidence: concern.confidence,
          concern_reason: concern.reason
        });
      }
    }
    if (status === "flagged_blocked") {
      return json({
        blocked: true,
        reason: "Your message was blocked for safety reasons.",
        categories: flaggedCategories,
        scores: categoryScores
      });
    }
    return json({
      blocked: false,
      flagged,
      modError,
      message: insertedMessage
    });
  } catch (e) {
    return json({
      error: String(e?.message ?? e)
    }, 500);
  }
});
function json(payload, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: corsHeaders
  });
}
