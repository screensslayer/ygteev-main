import React, { useState } from "react";
import { createRoot } from "react-dom/client";
import { supabase } from "./supabaseClient";
import { installStorage } from "./storage";
import { createApi } from "./backend";

// ------------------------------------------------------------------
// Boot sequence:
//   1. Session — from the iOS WKWebView hash handoff
//      (backyard.ygteev.com/#at=<access>&rt=<refresh>), else a persisted
//      session from a previous visit, else a dev sign-in form.
//   2. Globals the game reads at mount:
//        window.storage       — by_saves adapter
//        window.YGTEEV_MEMBER — real (non-default) youth-group membership
//        window.YGTEEV        — { profile: { id, name, avatarUrl, groupId, groupName } }
//   3. Dynamically import the game AFTER globals are set, then render.
// ------------------------------------------------------------------

// Guard against Vite HMR re-running this module — createRoot must only
// ever be called once per container.
const container = document.getElementById("root");
const root = window.__BY_ROOT ?? (window.__BY_ROOT = createRoot(container));

function parseHashTokens() {
  const h = new URLSearchParams(window.location.hash.replace(/^#/, ""));
  const at = h.get("at");
  const rt = h.get("rt");
  return at && rt ? { access_token: at, refresh_token: rt } : null;
}

async function resolveSession() {
  const tokens = parseHashTokens();
  if (tokens) {
    const { error } = await supabase.auth.setSession(tokens);
    // Scrub tokens from the address bar / history either way.
    history.replaceState(null, "", window.location.pathname + window.location.search);
    if (!error) {
      const { data } = await supabase.auth.getSession();
      if (data.session) return data.session;
    }
  }
  const { data } = await supabase.auth.getSession();
  return data.session ?? null;
}

async function mountGame(session) {
  const userId = session.user.id;
  installStorage(supabase, userId);

  // Membership → bridge state. Fail-closed: any error means "not a member";
  // the game just shows the collapsed bridge, nothing breaks.
  try {
    const { data, error } = await supabase.rpc("by_member_status");
    const status = error ? null : data;
    window.YGTEEV_MEMBER = status?.is_member === true;
    window.YGTEEV = {
      profile: {
        id: userId,
        groupId: status?.group_id ?? null,
        groupName: status?.group_name ?? null,
        // All non-default youth groups — multi-group users pick their
        // garden at the bridge.
        memberships: status?.memberships ?? [],
      },
    };
  } catch {
    window.YGTEEV_MEMBER = false;
    window.YGTEEV = { profile: { id: userId } };
  }

  try {
    const { data: prof } = await supabase
      .from("profiles")
      .select("display_name, avatar_url, xp")
      .eq("id", userId)
      .maybeSingle();
    if (prof) {
      window.YGTEEV.profile.name = prof.display_name;
      window.YGTEEV.profile.avatarUrl = prof.avatar_url;
      window.YGTEEV.profile.xp = prof.xp;
    }
  } catch {
    /* profile is cosmetic — game still runs */
  }

  window.YGTEEV_API = createApi();

  const { default: Game } = await import("./dragon-garden-quest.jsx");
  root.render(<Game />);
}

// Minimal email/password form so the game is testable in a plain browser.
// The production path is the WKWebView token handoff — this form only
// appears when there is no session at all.
function DevSignIn({ onSignedIn }) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState(null);

  const submit = async (e) => {
    e.preventDefault();
    setBusy(true);
    setErr(null);
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    setBusy(false);
    if (error) return setErr(error.message);
    onSignedIn(data.session);
  };

  const box = {
    position: "fixed", inset: 0, display: "flex", alignItems: "center",
    justifyContent: "center", background: "#0A0712",
    fontFamily: "-apple-system, system-ui, sans-serif",
  };
  const card = {
    width: "min(340px, 88vw)", padding: 28, borderRadius: 18,
    background: "#171225", border: "1px solid rgba(255,255,255,.08)",
    display: "flex", flexDirection: "column", gap: 12,
  };
  const input = {
    padding: "12px 14px", borderRadius: 10, border: "1px solid rgba(255,255,255,.14)",
    background: "#0E0A1C", color: "#fff", fontSize: 15, outline: "none",
  };

  return (
    <div style={box}>
      <form style={card} onSubmit={submit}>
        <div style={{ color: "#fff", fontSize: 19, fontWeight: 700 }}>YGTeeV Backyard</div>
        <div style={{ color: "rgba(255,255,255,.55)", fontSize: 13, lineHeight: 1.5 }}>
          Open this from the YGTeeV app — or sign in with your YGTeeV account to test in the browser.
        </div>
        <input style={input} type="email" placeholder="Email" value={email}
               onChange={(e) => setEmail(e.target.value)} autoComplete="username" />
        <input style={input} type="password" placeholder="Password" value={password}
               onChange={(e) => setPassword(e.target.value)} autoComplete="current-password" />
        {err && <div style={{ color: "#ff7a7a", fontSize: 13 }}>{err}</div>}
        <button
          disabled={busy || !email || !password}
          style={{
            padding: "13px 14px", borderRadius: 999, border: "none",
            background: busy ? "#4b3a86" : "#6B2BFF", color: "#fff",
            fontSize: 15, fontWeight: 700, cursor: "pointer",
          }}
        >
          {busy ? "Signing in…" : "Sign in"}
        </button>
      </form>
    </div>
  );
}

(async () => {
  const session = await resolveSession();
  if (session) {
    await mountGame(session);
  } else {
    root.render(<DevSignIn onSignedIn={(s) => mountGame(s)} />);
  }
})();
