// The five refugees of the Old Trail — fled Cinder Hollow, fed once each.
//
// SINGLE SOURCE OF TRUTH for their voices: tools/gen-refugee-lines.mjs
// renders exactly these strings through ElevenLabs (per-refugee voiceId),
// and the in-game encounters display exactly these strings. Edit here,
// re-run the generator, VOICE_V bumps itself.
//
// Audio: public/voices/refugee-{n}-ask.mp3 / refugee-{n}-thanks.mp3
// (n = 1-based position on the trail, south to north).
//
// `ask` plays when they walk up to the passing player (once, persisted);
// `thanks` plays the moment they're fed.

export const TRAIL_REFUGEES = [
  { n: 1, name: "Marta", voiceId: "1BfrkuYXmEwp8AWqSLWk",
    x: -3.6, z: 19.4, rot: 1.9, opts: { shirt: 0x8a5a6a, hair: 0x3a2a1a }, camp: true,
    ask: "Oh — traveler! Please, wait. We fled Cinder Hollow when the smoke came… we haven't eaten in two days.",
    thanks: "Bless you, gardener. The Gloom took our whole town — the mill, the square, everything. But you… you give me hope." },
  { n: 2, name: "Old Ferd", voiceId: "B52raBK48m23qWYbwchQ",
    x: 3.4, z: 9.2, rot: -2.2, opts: { shirt: 0x54628a, beard: true, cane: true }, cart: true,
    ask: "Hold there, young one. My cart wheel snapped on the flight out. Could you spare a bite for an old miller?",
    thanks: "Ahh, strength at last. Listen well — that brute you chased out of Meadow Town? He went NORTH. To our town." },
  { n: 3, name: "Bram", voiceId: "USEQXnsXRJlw2k9LUzG4",
    x: -4.2, z: -0.6, rot: 1.4, opts: { shirt: 0x6a7a4a },
    ask: "You there… do you have anything to eat? We walked two days without stopping. Two days.",
    thanks: "Thank you. Truly. The gate ahead is sealed — the Gloom holds Cinder Hollow tight. Be careful, friend." },
  { n: 4, name: "Sela", voiceId: "bICR68fw9p7rUiAEAgn6",
    x: 2.6, z: -9.8, rot: -1.6, opts: { shirt: 0x7a5a8a, hair: 0x1a1a22 },
    ask: "Wait — is it true? Meadow Town shines again? We saw a light over the hills three nights ago…",
    thanks: "So it IS true. Then maybe… maybe our town isn't lost either. Maybe YOU are what the light meant." },
  { n: 5, name: "Pip", voiceId: "ktrGUw7rURIQyMrQZqCu",
    x: -2.4, z: -17.6, rot: 0.6, opts: { shirt: 0xc9705a }, kid: true,
    ask: "Hey! Hey mister! My brother Thomas stayed behind — in the library! He never believes anything, but he's all alone…",
    thanks: "When you meet Thomas — tell him Pip sent you! He'll say you're lying. He ALWAYS says that. But keep telling him!" },
];
