// River — the Meadow Town librarian. 20, keeps the last lit room in town,
// and has been waiting a long time for someone brave enough to stay.
//
// SINGLE SOURCE OF TRUTH for her voice: tools/gen-river-lines.mjs renders
// exactly these strings through ElevenLabs (voice tnVKC6NjwhdRxoQIfKue), and
// the library cutscene displays exactly these strings. Edit here, re-run the
// generator, bump VOICE_V.
//
// `id` is the mp3 basename (public/voices/river-<id>.mp3).

export const RIVER_VOICE_ID = "tnVKC6NjwhdRxoQIfKue";

export const RIVER_LINES = [
  { id: 1, key: "stop",
    text: "Wait — stop right there! You shouldn't be here. It isn't safe. Please — you have to go." },
  { id: 2, key: "why1",
    text: "The Gloomlings. They crept in one night, and the dark came with them. They've been here ever since." },
  { id: 3, key: "why2",
    text: "It's not just us. Every town in the valley has gone dark. Nobody knows how to drive them out. Nobody's even tried in years." },
  { id: 4, key: "lantern",
    text: "Here — take my lantern. They can't stand its glow. Keep it close, and they won't dare come near you on the road." },
  { id: 5, key: "gohome",
    text: "Now please. Go home while you still can." },
  { id: 6, key: "stolen",
    text: "The night they came, they stole every light in town — right off the strings. Every single bulb. Nobody knows how to get them back." },
  { id: 7, key: "bible",
    text: "That old book? It's a Bible. This town used to be very close to Jesus, a long, long time ago. Since the Glooms came... nobody goes to church anymore." },
  { id: 8, key: "tryread",
    text: "Read a chapter? I... I suppose no one has ever tried that. Go on — it's already open." },
  { id: 9, key: "amazed",
    text: "That's — that's impossible! That's one of OUR lights! One of the lights that used to hang over the square! Do you think you can attach the light outside, up on the strings?" },
  { id: 10, key: "keepgoing",
    text: "Every chapter brings another light home. The town gets a little braver every time you read." },
  { id: 11, key: "another",
    text: "Wow — there's another one! Do you think... do you think you could actually save our town by reading these chapters?" },
];
