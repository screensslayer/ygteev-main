// YGTeeV Backyard backend bridge — the game reaches Supabase only through
// window.YGTEEV_API (set in main.jsx before the game mounts). Every method
// throws on error; game-side call sites degrade gracefully.
import { supabase } from "./supabaseClient";

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

    // Splash-screen single-player weekly board. Interim metric = rare trees
    // planted this UTC week; swaps to "levels" when those ship.
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
        supabase.realtime.setAuth(); // private channel needs the user JWT on the socket
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
        try { token = (await supabase.auth.getSession()).data.session?.access_token; } catch (e) {}
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
