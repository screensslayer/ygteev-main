// The Gloom Boss — the crater-headed brute guarding the Meadow Town chapel.
//
// SINGLE SOURCE OF TRUTH for his voice: tools/gen-gloomboss-lines.mjs renders
// exactly these strings through ElevenLabs (voice YOq2y2Up4RgXP2HyXjE5), and
// the in-town bark bubbles display exactly these strings. Edit here, re-run
// the generator, VOICE_V bumps itself.
//
// `id` is the mp3 basename (public/voices/gloomboss-<id>.mp3).
// `lantern: true` lines are preferred when the player is carrying River's
// lantern — he hates the thing.

export const GLOOMBOSS_VOICE_ID = "YOq2y2Up4RgXP2HyXjE5";

export const GLOOMBOSS_LINES = [
  { id: 1, text: "Move along, little gardener. This door is CLOSED." },
  { id: 2, text: "Get that lantern away from me! Foul little flame!", lantern: true },
  { id: 3, text: "The lights belong to the Gloom now. Every. Last. One." },
  { id: 4, text: "Go back to your garden, before I lose my temper." },
  { id: 5, text: "Read all you want. You will never light them all.", lantern: true },
  { id: 6, text: "The old book cannot save this town. Nothing can." },
  // fired once, the moment the second light lands on the strings
  { id: 7, text: "What do you think you're doing?! You're wasting your time, little gardener. You will NEVER get rid of us!", taunt2: true },
  // the liberation: fired the instant the 84th light lands, as the flash builds
  { id: 8, text: "AHHHH! What's going on?! The light— NO! Fall back! EVERYONE OUT!", finale: true },
];
