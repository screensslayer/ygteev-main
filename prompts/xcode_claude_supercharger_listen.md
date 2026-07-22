# Xcode-Claude prompt — "Supercharger" listen-to-earn XP (Read & Reflect)

> Paste everything below the line into xcode-claude, and **attach the design
> file** `Supercharged Listen.dc.html` (Claude Design mockup) — it is the
> source of truth for colors, spacing, copy, and animation timing.
>
> Human note: the backend is already live on prod + staging — the two RPCs
> below exist and are tested. No backend work in this prompt.

---

Implement the "Supercharger" listen-to-earn feature in the daily plan
**Read & Reflect** view (not the full Bible reader). The attached HTML
mockup is the visual spec. Core loop: tap the supercharger pill on a
passage card → the passage plays aloud → XP accrues with progress → on
completion the server awards **35 XP** once per passage per day.

## Use the EXISTING audio stack — not raw TTS

The mockup says "TTS playback", but our app has recorded narration:
`VersePlaybackController` / `VerseAudioService` (NLT recorded audio via
AVQueuePlayer, with device-TTS fallback per verse, and real playback
rates). The Supercharger drives THAT player. Progress is verse-based:
`progress = versesCompleted / totalVerses` (advance on the player's
per-verse progression; in the TTS fallback path use
AVSpeechSynthesizer utterance boundaries). A supercharge session always
starts from verse 1 of the passage and tracks its own progress — ignore
any resume-by-verse position for this mode.

## Backend contract (already deployed — call, don't create)

- `rpc complete_listen_reward(_reference: String)` — call ONLY when
  playback truly reaches the end. `_reference` must be the EXACT part
  reference string from the plan day's read part (e.g. "John 6:1-21" as
  stored in `sections.read.parts[].verses`). Returns:
  - `{awarded: true, xp: 35, total_xp: N}` → run the completion
    celebration and set the header XP counter to `total_xp`.
  - `{awarded: false, already_earned: true}` → set the pill to EARNED
    silently (no confetti).
  - `{awarded: false, error: "daily_cap" | "unknown_reference"}` → set
    EARNED-less idle state back, log, no user-facing error.
- `rpc get_listen_rewards_today()` → `[{reference}]` — call when the
  Read & Reflect view loads; passages in the list render the EARNED
  pill. This is the persistence (per passage, resets daily, UTC) — no
  local storage needed.
- Existing read-part XP (`complete_plan_step`) is unchanged; the
  supercharge 35 XP is additive.

## UI spec (match the attached HTML exactly)

1. **Supercharger pill** replaces the speaker icon in each passage
   card's header (one per read part, each earns separately):
   - Idle: bolt icon + "+35 XP", 135° gradient #FFD60A→#FF6B35, content
     ink #0A0712, radius 999, padding 7/12/7/9. Repeating pulse ring:
     box-shadow 0→12pt rgba(255,214,10,0.55)→transparent, 1.8s ease-out
     loop. Press: scale 0.96, springy curve (0.2,0.7,0.3,1.4).
   - Charging: same gradient, label "CHARGING", pulsing glow shadow
     (yellow 14→24pt + orange 30→48pt, 1.2s ease-in-out loop), bolt
     wiggles ±8° with scale 1.1, 0.7s loop.
   - Earned: #B4FF3C fill, ink checkmark + "EARNED", lime glow shadow;
     not tappable.
2. **Mini player** — floating light-glass card above the tab bar
   (rgba(255,255,255,0.88), blur 24 + saturation, radius 22, 0.5pt white
   border, shadow 0 12 28 rgba(20,14,40,0.35)), springy fade-up entrance:
   - 46pt pause/play circle: gradient when playing, rgba(10,7,18,0.12)
     when paused.
   - Eyebrow: small orange bolt + "SUPERCHARGED · EARNING XP" (10pt, 800,
     letter-spacing 1.2, #FF6B35); when paused: "SUPERCHARGE PAUSED".
     Passage reference below (display font, 16pt, 800).
   - Right-aligned live counter: `floor(progress × 35)` in 19pt 900
     #FF6B35 + "/35 XP" in 12pt 800 at 45% ink.
   - Progress bar: 12pt track rgba(10,7,18,0.08), gradient fill
     #FFD60A→#FF6B35 (min width 12pt) with TWO continuous animations —
     45° white candy stripes (28pt period, 0.8s loop) and a white
     shimmer sweep (1.4s loop) — plus a 22pt white circle with orange
     border and mini bolt riding the leading edge.
   - Encouragement line (12pt, 700) under the bar, escalating:
     <25% "Charging up… keep listening ⚡" (#FF6B35) · <50% "XP is
     flowing — don't stop now!" · <75% "Halfway! The charge is
     building…" · ≥75% "Almost there — full 35 XP incoming!" (#E0491F) ·
     paused "Paused — your charge is waiting…" (50% ink).
   - Speed chips 0.75x / 1x / 1.25x — selected chip #6B2BFF fill with
     white text, others rgba(10,7,18,0.06) with 60% ink. Speed sets the
     playback rate (narration rate / TTS rate).
   - Close (×, 30pt circle) **forfeits**: stop playback, dismiss the
     player, reset progress to 0, pill returns to idle. No XP.
3. **Verse tracking** in the passage card while charging: current verse
   gets soft-yellow background rgba(255,214,10,0.10) and #FFD60A verse
   number; completed verses dim to 55% white with #B4FF3C numbers;
   0.4s transitions. Auto-scroll gently to keep the active verse
   visible.
4. **Completion**: when the last verse finishes → call the RPC → on
   `awarded`: header XP counter ticks up (animate count), confetti burst
   (26 pieces, colors #FFD60A #FF6B35 #B4FF3C #6B2BFF #FF3DA5 #00E0FF,
   fall + rotate, ~1.6–2.8s staggered), a "+35 XP" bolt label flies up
   and fades near the header counter (~2s), pill becomes EARNED, mini
   player shows "+35 XP earned! 🔥" (#2B8A3E) briefly then dismisses.
5. No unlock popup — the charge starts immediately on tap. Leaving the
   view mid-charge = forfeit (stop cleanly, no crash). Only one active
   charge at a time; starting a charge on another passage forfeits the
   first.

Fonts: Bricolage Grotesque (the app's display font) for labels/numbers,
system for body. Respect Reduce Motion: replace looping
pulse/wiggle/stripes with static styling when enabled.

## Test before calling it done

- Full charge of a 1-part day and each part of a 3-part day (each part
  awards 35 independently; header total matches server `total_xp`).
- Kill the app mid-charge, reopen: pill idle, no partial XP.
- Complete the same passage twice in one day: second attempt's pill
  should already be EARNED on view load (from
  `get_listen_rewards_today`).
- Speed 1.25x full listen still awards; pausing mid-way and resuming
  continues progress.
- TTS-fallback passage (non-NLT translation selected, if ESV shipped)
  still tracks verse progress and awards.
- VoiceOver: pill announces state ("Supercharge, earn 35 XP", "Charging",
  "Earned").
