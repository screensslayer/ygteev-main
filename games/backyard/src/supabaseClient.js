import { createClient } from "@supabase/supabase-js";

// ------------------------------------------------------------------
// Two auth modes, decided once at module init:
//
// EMBEDDED (iOS app with the auth bridge): the NATIVE app owns the only
// Supabase session. It injects window.YGTEEV.auth = { accessToken,
// expiresAt } at document start, mirrors every native refresh into
// window.YGTEEV_AUTH_PUSH({...}), and answers {type:"requestToken"} posts
// on its ygteevAuth message handler. This client is created with the v2
// `accessToken` callback and NO auth state of its own — it can never
// persist or redeem a refresh token. That is the whole fix for the
// refresh-token rotation collision that was revoking whole sessions
// (two refreshers, one token family — see BackyardAuthBridge.swift).
//
// BROWSER (desktop testing, and OLD app builds that still hand tokens
// over in the URL hash): classic supabase-js auth — persisted session,
// self-refresh, dev sign-in form. Old apps keep their legacy behavior
// until they update; nothing regresses.
// ------------------------------------------------------------------

const injected = (typeof window !== "undefined" && window.YGTEEV && window.YGTEEV.auth) || null;

export const EMBEDDED_AUTH = !!(injected && injected.accessToken);

let bridgeToken = EMBEDDED_AUTH ? injected.accessToken : null;
let bridgeExpiresAt = EMBEDDED_AUTH ? (+injected.expiresAt || 0) : 0;

// The current bearer for callers that need the raw token (relay join,
// realtime). null in browser mode — those callers fall back to the session.
export const getAuthToken = () => bridgeToken;

// user id straight from the JWT — in embedded mode supabase.auth.* is
// disabled by design, so the shell reads the `sub` claim itself.
export function jwtSub(token) {
  try {
    const body = token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
    return JSON.parse(atob(body)).sub || null;
  } catch {
    return null;
  }
}

export const supabase = EMBEDDED_AUTH
  ? createClient(
      import.meta.env.VITE_SUPABASE_URL,
      import.meta.env.VITE_SUPABASE_ANON_KEY,
      // accessToken callback = "third-party auth" mode: PostgREST, Realtime
      // and Storage all pull the bearer from here per request, and the
      // internal GoTrue client is replaced with a stub that throws — which
      // is exactly what we want: no second refresher can ever come back.
      { accessToken: async () => bridgeToken }
    )
  : createClient(
      import.meta.env.VITE_SUPABASE_URL,
      import.meta.env.VITE_SUPABASE_ANON_KEY,
      {
        auth: {
          persistSession: true,
          autoRefreshToken: true,
        },
      }
    );

if (EMBEDDED_AUTH) {
  // Push channel: the app calls this on every native refresh and on
  // every return to foreground.
  window.YGTEEV_AUTH_PUSH = (p) => {
    if (!p || !p.accessToken) return;
    bridgeToken = p.accessToken;
    bridgeExpiresAt = +p.expiresAt || 0;
    try { supabase.realtime.setAuth(bridgeToken); } catch { /* not connected yet */ }
  };

  // Pull channel: ask the app for a fresh token. The app refreshes
  // natively if needed and answers via YGTEEV_AUTH_PUSH.
  const requestToken = () => {
    try { window.webkit?.messageHandlers?.ygteevAuth?.postMessage({ type: "requestToken" }); } catch { /* not in the app */ }
  };
  const nearExpiry = () => bridgeExpiresAt > 0 && bridgeExpiresAt - Date.now() / 1000 < 300;

  // Waking from background is the moment the old design used to explode:
  // timers were frozen, the token went stale, and the WebView tried to
  // refresh it itself. Now we just ask the app.
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "visible" && nearExpiry()) requestToken();
  });
  // belt-and-braces watchdog for long foreground sessions — the app pushes
  // proactively, this only catches a missed push
  setInterval(() => { if (nearExpiry()) requestToken(); }, 30000);
}
