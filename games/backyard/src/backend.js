// YGTeeV Backyard backend bridge — the game reaches Supabase only through
// window.YGTEEV_API (set in main.jsx before the game mounts). Every method
// throws on error; game-side call sites degrade gracefully.
import { supabase } from "./supabaseClient";

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
      return data ?? []; // [{ group_id, group_name, berries, fund, rank }]
    },

    // Live players: presence + position broadcasts on the private per-group
    // channel by:garden:{gid}. RLS policies on realtime.messages gate both
    // reading and sending to members of that youth group.
    joinGarden(groupId, { me, onSync, onPos, onAct }) {
      const gid = groupId || window.YGTEEV?.profile?.groupId;
      if (!gid || !me?.id) return null;
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
