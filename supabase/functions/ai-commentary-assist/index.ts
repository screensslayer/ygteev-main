// v5 — Generates THREE full ~1-minute teen Bible teachings the pastor can pick
// from, instead of short labeled edit suggestions. Response shape:
//   { "suggestions": [ { "body": "..." }, { "body": "..." }, { "body": "..." } ] }
// No more `tag` field on the wire — iOS just renders three card-shaped options.
import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from 'jsr:@supabase/supabase-js@2';
const CLAUDE_API_URL = 'https://api.anthropic.com/v1/messages';
const CLAUDE_MODEL = 'claude-sonnet-4-5';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS'
};
function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json'
    }
  });
}
function fail(stage, status, detail) {
  console.error(`[ai-commentary-assist] ${stage} (status ${status}):`, detail);
  return json({
    error: stage,
    status,
    detail
  }, status);
}
Deno.serve(async (req)=>{
  if (req.method === 'OPTIONS') return new Response(null, {
    headers: corsHeaders
  });
  if (req.method !== 'POST') return fail('method-not-allowed', 405, req.method);
  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader) return fail('no-auth-header', 401, null);
  const supabase = createClient(Deno.env.get('SUPABASE_URL'), Deno.env.get('SUPABASE_ANON_KEY'), {
    global: {
      headers: {
        Authorization: authHeader
      }
    }
  });
  const { data: { user }, error: userErr } = await supabase.auth.getUser();
  if (userErr || !user) return fail('auth-getuser-failed', 401, userErr?.message ?? 'no user');
  const { data: pastorRows, error: pastorErr } = await supabase.from('youth_group_members').select('group_id').eq('user_id', user.id).eq('role', 'pastor').limit(1);
  if (pastorErr) return fail('pastor-lookup-failed', 500, pastorErr.message);
  if (!pastorRows || pastorRows.length === 0) return fail('not-a-pastor', 403, `user ${user.id} has no pastor role`);
  let body;
  try {
    body = await req.json();
  } catch (e) {
    return fail('bad-json-body', 400, String(e));
  }
  const reference = (body.reference ?? '').trim();
  if (!reference) return fail('reference-required', 400, body);
  const planTitle = (body.plan_title ?? '').trim();
  const currentDraft = (body.current_draft ?? '').trim();
  const apiKey = Deno.env.get('CLAUDE_API_KEY') ?? Deno.env.get('ANTHROPIC_API_KEY');
  if (!apiKey) return fail('missing-claude-api-key', 500, 'Set CLAUDE_API_KEY in Supabase → Project Settings → Edge Functions → Secrets');
  const systemPrompt = `You are a seasoned youth pastor writing devotional commentary for a teen Bible-reading app called YGTeeV. The reader is a U.S. teenager (13–18) opening this in their youth group's daily plan.

Your job: produce THREE distinct, complete, ready-to-publish teachings on the supplied passage. Each one is a full one-minute spoken devotional (roughly 150–220 words — long enough to feel substantive, short enough to hold a teen's attention). Each one should be a different angle on the passage so the pastor can pick the one that fits their group:
  • One should center on the THEOLOGY — what this passage reveals about God or the gospel.
  • One should center on REAL-LIFE APPLICATION — a concrete situation a teen faces this week.
  • One should center on STORY / ILLUSTRATION — a vivid analogy, metaphor, or moment that makes the truth land.

Do NOT label which one is which on the wire. Just write them.

Return ONLY a single JSON object, no prose before or after, in this exact shape:

{
  "suggestions": [
    { "body": "...full ~1-minute teaching..." },
    { "body": "...different angle..." },
    { "body": "...third angle..." }
  ]
}

Writing rules:
• Talk TO a teen, not about them. Second person ("you") works well.
• Punchy first sentence — hook them in line one.
• Use plain language. Avoid seminary jargon ("propitiation", "eschatological") unless you immediately unpack it.
• No mid-text bullet points or headers — these are spoken devotionals, not articles. Flowing prose only.
• Quote the passage briefly when it helps; don't reprint long verse blocks.
• If you attribute a quote (e.g. "— C.S. Lewis"), only do so when you're confident it's real. If unsure, write your own original line instead.
• No profanity, no political potshots, no shaming.
• If the pastor supplied a draft, treat it as their starting direction but don't be bound by it.
• Each teaching must stand alone — a pastor should be able to copy one verbatim and use it.`;
  const userMessage = [
    `Passage: ${reference}`,
    planTitle ? `Plan title: ${planTitle}` : null,
    currentDraft ? `Pastor's draft so far:\n"""\n${currentDraft}\n"""` : 'Pastor has no draft yet — write from scratch.'
  ].filter(Boolean).join('\n\n');
  let claudeResp;
  try {
    claudeResp = await fetch(CLAUDE_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01'
      },
      body: JSON.stringify({
        model: CLAUDE_MODEL,
        max_tokens: 2500,
        system: systemPrompt,
        messages: [
          {
            role: 'user',
            content: userMessage
          }
        ]
      })
    });
  } catch (e) {
    return fail('claude-fetch-failed', 502, String(e));
  }
  if (!claudeResp.ok) {
    const errBody = await claudeResp.text();
    return fail('claude-non-200', claudeResp.status, errBody);
  }
  const claudeJson = await claudeResp.json();
  const text = claudeJson?.content?.[0]?.text ?? '';
  const firstBrace = text.indexOf('{');
  const lastBrace = text.lastIndexOf('}');
  if (firstBrace < 0 || lastBrace < 0) return fail('claude-no-json', 502, text.slice(0, 500));
  let parsed;
  try {
    parsed = JSON.parse(text.slice(firstBrace, lastBrace + 1));
  } catch (e) {
    return fail('claude-malformed-json', 502, {
      error: String(e),
      raw: text.slice(0, 500)
    });
  }
  const suggestions = (parsed.suggestions ?? []).filter((s)=>s && typeof s.body === 'string' && s.body.trim().length > 0).slice(0, 3).map((s)=>({
      body: s.body.trim()
    }));
  if (suggestions.length === 0) return fail('claude-no-suggestions', 502, text.slice(0, 500));
  console.log(`[ai-commentary-assist] returning ${suggestions.length} suggestions, avg length: ${Math.round(suggestions.reduce((acc, s)=>acc + s.body.length, 0) / suggestions.length)} chars`);
  return json({
    suggestions
  });
});
