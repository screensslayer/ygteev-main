// The game's only persistence contract: window.storage (async KV).
// Backed by the by_saves table (RLS: own rows only). Keys in play:
//   grace-garden-week · garden-outfit · garden-build · garden-intro ·
//   garden-youthgroup
//
// The game treats a missing key as a throw from get() — preserve that.
export function installStorage(supabase, userId) {
  window.storage = {
    async get(key) {
      const { data, error } = await supabase
        .from("by_saves")
        .select("value")
        .eq("user_id", userId)
        .eq("key", key)
        .maybeSingle();
      if (error || !data) throw new Error(`missing key: ${key}`);
      return { key, value: data.value };
    },
    async set(key, value) {
      await supabase.from("by_saves").upsert({
        user_id: userId,
        key,
        value: String(value),
        updated_at: new Date().toISOString(),
      });
    },
    async delete(key) {
      await supabase
        .from("by_saves")
        .delete()
        .eq("user_id", userId)
        .eq("key", key);
    },
  };
}
