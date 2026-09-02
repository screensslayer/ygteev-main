// YGTeeV Backyard backend bridge — the game reaches Supabase only through
// window.YGTEEV_API (set in main.jsx before the game mounts). Every method
// throws on error; game-side call sites degrade gracefully.
import { supabase, getAuthToken } from "./supabaseClient";

// Dedicated live-position relay (relay/ in this repo, deployed on Fly).
// Empty string disables it and every garden falls back to Supabase Realtime.
const RELAY_URL = "wss://ygteev-relay.fly.dev";

export function createApi() {
  return {
    // Atomic wallet spend against profiles.xp (server checks balance).
    async spendXp(amount, itemKey) {
      const { data, error } = await supabase.rpc("by_spend_xp", {
        _amount: amount,
        _item_key: itemKey,
      });
      if (error) throw error;
      return data; // { remaining_xp, item_key, xp_spent }
    },

    // 3 questions from the user's completed-plan pool (fallback: basic pool).
    // correct_index is never in this payload — grading is server-side.
    async startQuiz() {
      const { data, error } = await supabase.rpc("by_start_quiz");
      if (error) throw error;
      return { attemptId: data.attempt_id, questions: data.questions };
    },

    async answerQuiz(attemptId, choiceIdx) {
      const { data, error } = await supabase.rpc("by_answer_quiz", {
        _attempt_id: attemptId,
        _choice_idx: choiceIdx,
      });
      if (error) throw error;
      return data; // { correct, correct_choice_index, question_idx, done, passed }
    },

    // Requires a passed, unconsumed attempt from the last 15 minutes.
    async plantRare(attemptId, plotIdx, seedKey, goldBoost = 0, groupId = null) {
      const params = {
        _attempt_id: attemptId,
        _plot_idx: plotIdx,
        _seed_key: seedKey,
        _gold_boost: goldBoost,
      };
      if (groupId) params._group_id = groupId;
      const { data, error } = await supabase.rpc("by_plant_rare", params);
      if (error) throw error;
      return data; // { plot_id, plot_idx, seed_key, planted_at, matures_at, expires_at }
    },

    async getPlots(groupId = null) {
      const { data, error } = await supabase.rpc(
        "by_get_plots",
        groupId ? { _group_id: groupId } : {}
      );
      if (error) throw error;
      return data ?? [];
    },

    async getLeague() {
      const { data, error } = await supabase.rpc("by_get_league");
      if (error) throw error;
      // [{ group_id, group_name, berries, fund, rank, active_count, multiplier, adjusted }]
      // multiplier/adjusted are precomputed server-side by the berry cron
      return data ?? [];
    },

    // Same shape as getLeague, but summed across every recorded week — the
    // leaderboard DISPLAY is all-time for now, while the weekly tables keep
    // collecting underneath (payouts, funds and the in-garden bulletin are
    // still weekly).
    async getLeagueAllTime() {
      const { data, error } = await supabase.rpc("by_get_league_alltime");
      if (error) throw error;
      return data ?? [];
    },

    // Splash-screen player board — ALL-TIME: ranks by player level (gems as
    // the tiebreak) straight from the garden saves.
    async getSplashPlayers() {
      const { data, error } = await supabase.rpc("by_splash_players");
      if (error) throw error;
      return data ?? { rows: [], me: null };
    },

    async getPulse(groupId) {
      const { data, error } = await supabase.rpc("by_garden_pulse", groupId ? { _gid: groupId } : {});
      if (error) throw error;
      // { players_today, group_players_today, trees_alive, trees_today, top_planters }
      return data ?? {};
    },

    // Cloudtop challenge: the caller's group's live challenge (or null),
    // with per-participant progress toward the goal town. Server-computed;
    // the chest latches open server-side the moment the goal is met.
    async getChallenge() {
      const { data, error } = await supabase.rpc("by_get_challenge");
      if (error) throw error;
      return data?.challenge ?? null;
    },

    // Daily red bags: 3 hidden question-pouches per player per UTC day.
    // First call of the day creates them server-side (spot = index into the
    // client's 12-spot hiding pool). Question level (ms/hs) and rewards are
    // decided by the server — nothing to cheat client-side.
    async getRedBags() {
      const { data, error } = await supabase.rpc("by_get_red_bags");
      if (error) throw error;
      return data ?? []; // [{ bag_idx, status: hidden|opened|correct|wrong, spot }]
    },

    async openRedBag(bagIdx) {
      const { data, error } = await supabase.rpc("by_open_red_bag", { _bag_idx: bagIdx });
      if (error) throw error;
      return data; // { q, options } | { error: no_bag|already_answered }
    },

    // One attempt, no retry. Gold is applied client-side into the garden
    // save; XP is granted server-side (total_xp = new profiles.xp).
    async answerRedBag(bagIdx, answerIdx) {
      const { data, error } = await supabase.rpc("by_answer_red_bag", {
        _bag_idx: bagIdx,
        _answer_idx: answerIdx,
      });
      if (error) throw error;
      return data; // { correct, correct_idx, reward_kind, reward_amount, total_xp } | { error }
    },

    // ---- Read-to-earn-XP mini player -------------------------------
    // The next unread section of the current book, its ESV verses (text +
    // narration) and the gem strip for the whole book. section === null once
    // the book is finished — the offer simply stops appearing.
    async nextReading() {
      const { data, error } = await supabase.rpc("by_next_reading");
      if (error) throw error;
      for (const v of data?.section?.verses ?? []) {
        v.url = supabase.storage.from("verse-audio").getPublicUrl(v.path).data.publicUrl;
      }
      return data ?? null;
    },

    // Bank the verses listened to so far. Sends an ABSOLUTE position rather
    // than an increment, so it is safe to call on every verse, to call twice,
    // and to lose — the next call covers anything dropped. That is why the
    // player fires these without awaiting.
    async creditVerses(sectionId, versesDone) {
      const { data, error } = await supabase.rpc("by_credit_verses", {
        _section_id: sectionId,
        _verses_done: versesDone,
      });
      if (error) throw error;
      return data; // { verses_done, total_verses, awarded, read_xp, xp }
    },

    // Audio played through. Tops the reading XP up to the full award (0 if
    // the per-verse credits already covered it) and returns the question —
    // never its answer.
    async finishReading(sectionId) {
      const { data, error } = await supabase.rpc("by_finish_reading", { _section_id: sectionId });
      if (error) throw error;
      return data; // { awarded, xp, already, question: { prompt, choices, answer_xp } }
    },

    // ---- Season 1: the town Bible at the Meadow Town library ----------
    // Next unread chapter of the season (John -> Genesis -> Colossians ->
    // selected Psalms). section null + audio_pending while the next
    // chapter's narration is still being recorded.
    async townReading() {
      const { data, error } = await supabase.rpc("by_town_reading");
      if (error) throw error;
      for (const v of data?.section?.verses ?? []) {
        v.url = supabase.storage.from("verse-audio").getPublicUrl(v.path).data.publicUrl;
      }
      return data ?? null;
    },

    // Chapter finished at the lectern. No quiz on this track - the reward is
    // a light: { lights, total } is the town's new bulb count.
    async townFinishReading(sectionId) {
      const { data, error } = await supabase.rpc("by_town_finish_reading", { _section_id: sectionId });
      if (error) throw error;
      return data; // { awarded, xp, already, lights, total, title }
    },

    // Cheap read for map load: how many strand bulbs burn tonight?
    async townProgress() {
      const { data, error } = await supabase.rpc("by_town_progress");
      if (error) throw error;
      return data ?? { done: 0, total: 0 };
    },

    // One shot per section; correct answers credit once.
    async answerReading(sectionId, choiceIdx) {
      const { data, error } = await supabase.rpc("by_answer_reading", {
        _section_id: sectionId,
        _choice_idx: choiceIdx,
      });
      if (error) throw error;
      return data; // { correct, correct_choice_index, awarded, xp, already }
    },

    // Live players. Two transports behind one facade:
    //
    //  1. RELAY (default): dedicated WebSocket relay on Fly. Supabase
    //     Realtime bills per message DELIVERED and position broadcasts grow
    //     N² with garden size; the relay snapshot-ticks at 10 Hz (linear)
    //     for a flat ~$2/mo. Auth: the relay verifies our Supabase JWT and
    //     garden membership on join — see relay/README.md.
    //  2. SUPABASE (fallback): presence + broadcasts on the private channel
    //     by:garden:{gid}, RLS-gated. Used automatically when the relay is
    //     unreachable or refuses the join, so live avatars degrade
    //     gracefully instead of vanishing on relay outages.
    joinGarden(groupId, { me, onSync, onPos, onAct }) {
      const gid = groupId || window.YGTEEV?.profile?.groupId;
      if (!gid || !me?.id) return null;

      const supabaseJoin = () => {
        // private channel needs the user JWT on the socket — bridge token in
        // the app (embedded mode), session token in the browser
        const tok = getAuthToken();
        if (tok) supabase.realtime.setAuth(tok); else supabase.realtime.setAuth();
        const ch = supabase.channel("by:garden:" + gid, {
          config: { private: true, broadcast: { self: false }, presence: { key: me.id } },
        });
        ch.on("presence", { event: "sync" }, () => { if (onSync) onSync(ch.presenceState()); });
        ch.on("broadcast", { event: "pos" }, ({ payload }) => { if (onPos) onPos(payload); });
        ch.on("broadcast", { event: "act" }, ({ payload }) => { if (onAct) onAct(payload); });
        ch.subscribe((status) => {
          if (status === "SUBSCRIBED") ch.track(me);
        });
        return {
          sendPos: (p) => ch.send({ type: "broadcast", event: "pos", payload: p }),
          sendAct: (p) => ch.send({ type: "broadcast", event: "act", payload: p }),
          leave: () => supabase.removeChannel(ch),
        };
      };

      if (!RELAY_URL) return supabaseJoin();

      // Relay transport with a swappable impl: the facade the game holds is
      // stable; internally we connect async, retry twice on drops, and swap
      // to the Supabase path if the relay stays unreachable.
      let impl = { sendPos: () => {}, sendAct: () => {}, leave: () => {} };
      let closed = false, attempts = 0;

      const useFallback = () => {
        if (closed) return;
        const h = supabaseJoin();
        if (h) impl = h;
      };

      const connect = async () => {
        if (closed) return;
        let token = null;
        try { token = getAuthToken() || (await supabase.auth.getSession()).data.session?.access_token; } catch (e) {}
        if (closed) return;
        if (!token) return useFallback();
        let ws;
        try { ws = new WebSocket(RELAY_URL); } catch (e) { return useFallback(); }
        let acked = false;
        const ackTimer = setTimeout(() => { if (!acked) { try { ws.close(); } catch (e) {} } }, 6000);
        ws.onopen = () => ws.send(JSON.stringify({ t: "join", gid, token, me }));
        ws.onmessage = (ev) => {
          let m;
          try { m = JSON.parse(ev.data); } catch (e) { return; }
          if (m.t === "ack") {
            acked = true;
            attempts = 0;
            clearTimeout(ackTimer);
            impl = {
              sendPos: (p) => { if (ws.readyState === 1) ws.send(JSON.stringify({ t: "pos", ...p })); },
              sendAct: (p) => { if (ws.readyState === 1) ws.send(JSON.stringify({ t: "act", ...p })); },
              leave: () => { try { ws.close(1000); } catch (e) {} },
            };
          } else if (m.t === "roster") {
            const state = {};
            for (const pl of m.players) state[pl.id] = [pl.meta];
            if (onSync) onSync(state);
          } else if (m.t === "snap") {
            if (onPos) for (const p of m.p) onPos(p);
          } else if (m.t === "act") {
            if (onAct) onAct(m);
          } else if (m.t === "err") {
            attempts = 99; // relay said no (unauthorized/full) — don't retry it
          }
        };
        ws.onclose = () => {
          clearTimeout(ackTimer);
          impl = { sendPos: () => {}, sendAct: () => {}, leave: () => {} };
          if (closed) return;
          attempts++;
          if (attempts >= 3) return useFallback();
          setTimeout(connect, attempts * 1500);
        };
        ws.onerror = () => {};
      };
      connect();

      return {
        sendPos: (p) => impl.sendPos(p),
        sendAct: (p) => impl.sendAct(p),
        leave: () => { closed = true; impl.leave(); },
      };
    },

    // Realtime: fire onChange whenever the given group's plots change.
    // Returns the channel so the caller can unsubscribe when switching gardens.
    subscribePlots(groupId, onChange) {
      const gid = groupId || window.YGTEEV?.profile?.groupId;
      if (!gid) return null;
      return supabase
        .channel("by-plots-" + gid)
        .on(
          "postgres_changes",
          { event: "*", schema: "public", table: "by_plots", filter: "group_id=eq." + gid },
          onChange
        )
        .subscribe();
    },
  };
}
