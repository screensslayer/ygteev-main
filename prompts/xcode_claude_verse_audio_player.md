# xcode-claude prompt — Recorded verse narration replaces device TTS in daily plans

## What we're doing

The daily plans' Read step currently reads scripture aloud with
`AVSpeechSynthesizer` using a voice the user picks from their phone
(VoiceSetupSheet / VoiceService / VersePlaybackController). We now have
**our own recorded narration** (ElevenLabs, one MP3 per verse) stored in
Supabase for the entire Book of John plan. Switch playback to stream
those recordings, keeping the mini player and the verse-highlight UX
exactly as they are. Device TTS stays only as a fallback for plans we
haven't recorded yet.

## Backend contract (already live in prod)

**Table `verse_audio`** (anon/user SELECT allowed via PostgREST):

| column | type | notes |
|---|---|---|
| bible_id | text | `d6e14a625393b4da-01` (NLT — same as BibleAPIService default) |
| voice_id | text | `NPJ9YKwI4PhhZaBPyKlD` (our narrator) |
| book_id | text | api.bible book id, e.g. `JHN` |
| chapter | int | |
| verse | int | |
| storage_path | text | e.g. `d6e14a625393b4da-01/NPJ9YKwI4PhhZaBPyKlD/JHN/14/6.mp3` |
| duration_seconds | double | |

**Audio URL** (public bucket, no auth):
`https://tkesywmshaicjmywbovn.supabase.co/storage/v1/object/public/verse-audio/{storage_path}`

**Coverage:** all of John referenced by the John plan (786 verses,
chapters 1–7, 9–15, 17–21). NLT omits John 5:4 (textual variant) — the
verse list from api.bible omits it too, so counts always line up.
Other books/plans have no rows yet → fall back to device TTS.

## 1. New service: `Services/VerseAudioService.swift`

```swift
struct VerseAudioItem {
    let verse: Int
    let url: URL
    let duration: Double
}
```

- `func narration(for reference: String) async -> [VerseAudioItem]?`
- Parse the reference with the same logic as
  `BibleAPIService.parse(reference:)` + `bookId(forName:)` (expose or
  duplicate those helpers) → book_id / chapter / verse range.
- Query via SupabaseManager:
  `verse_audio` where `bible_id == NLT && voice_id == narrator &&
  book_id == X && chapter == Y && verse >= a && verse <= b`,
  ordered by verse.
- Return `nil` if zero rows (→ caller falls back to TTS). If rows exist
  but some verses in the range are missing, still return what we have —
  the queue just skips missing verses (only realistic case is NLT verse
  omissions, where the displayed verse list is missing them too).
- Cache per reference in-memory (same pattern as
  `BibleAPIService.versesByReference`).

## 2. `VersePlaybackController` — add a recorded-narration path

Keep the published surface IDENTICAL so `MiniVoicePlayer` and the
verse-highlight in `DailyPlanView` need no changes:
`isPlaying`, `hasActiveSession`, `progress`, `currentVerseNumber`.

New API:

```swift
func play(items: [VerseAudioItem], passageId: String, title: String)
```

- Build an `AVQueuePlayer` with one `AVPlayerItem` per verse (in order).
- `currentVerseNumber` = the verse of the currently playing item
  (observe `currentItem` changes; keep a parallel [AVPlayerItem: Int]
  map or iterate by index).
- `progress` = (summed durations of finished verses + current item
  elapsed) / total duration. Use the `duration` values from the table —
  don't wait on asset loading. Drive updates with
  `addPeriodicTimeObserver` (0.25s).
- Speed pills now map to REAL rates: `player.rate = 0.75 / 1.0 / 1.25`
  (apply on change while playing; store the preference in the existing
  `VoiceService.playbackSpeed` so persistence keeps working — labels are
  already right).
- Pause/resume = `player.pause()` / `player.play()` (set rate back to
  the selected speed on resume, since `play()` resets rate to 1.0).
- Resume-position: store the VERSE NUMBER (not character offset) per
  `passageId` in a new UserDefaults key (`ygteev.audioResumeVerse`,
  `[String: Int]`). On play, if a saved verse exists, start the queue
  from that verse's item. Clear on completion (same near-end rule: if
  the user stops during the final verse, treat as finished).
- Now Playing / remote commands: reuse the existing
  MPNowPlayingInfoCenter plumbing — durations and elapsed are real now
  (drop the ~12 chars/sec estimate for this path).
- On queue end (`AVPlayerItemDidPlayToEndTime` of the last item):
  same teardown as the synthesizer `didFinish` (progress 1, session
  false, clear resume).
- Keep the existing `play(_ passage:voice:)` synthesizer path untouched
  for the fallback.

### Fix these three bugs while you're in this file (found in review)

1. **Lazy audio session**: move
   `AVAudioSession.setCategory(.playback, mode: .spokenAudio)` +
   `setActive(true)` OUT of `init` and into the start of both `play`
   methods. In `stop()`, call
   `setActive(false, options: .notifyOthersOnDeactivation)` so the
   user's music resumes. Today, merely opening a plan day kills
   Spotify because the controller activates the session on view
   construction.
2. **Remote-command hijack**: `registerRemoteCommands()` runs in `init`
   and `removeTarget(nil)`s — so the preview controller created by
   `VoiceSetupSheet` steals the lock-screen controls from the real
   session. Add an `isPreview: Bool = false` init parameter: preview
   controllers skip remote-command registration, Now Playing updates,
   AND audio-session activation. `VoiceSetupSheet` passes
   `isPreview: true`.
3. **Preview resume pollution**: previews save resume offsets into
   UserDefaults when the sheet closes mid-sample. Preview controllers
   should never save resume state (gate on `isPreview`).

## 3. `DailyPlanView` (ReadStepView) — route the speaker tap

Replace `handleSpeakerTap()`'s play branch:

```swift
guard let passage = currentPassage() else { return }
Task {
    if let items = await VerseAudioService.shared.narration(for: section.parts[currentPart].verses) {
        playback.play(items: items, passageId: passage.identifier, title: section.parts[currentPart].verses)
    } else if !voice.didCompleteSetup {
        showVoiceSetup = true          // TTS fallback still needs setup
    } else {
        playback.play(passage, voice: voice.resolvedVoice)
    }
}
```

- **No setup sheet when narration exists** — there's nothing to choose;
  it's our recorded narrator. First tap just plays.
- The verse-highlight code reads `playback.currentVerseNumber` — no
  changes needed.
- Restart button: for the narration path, clear the saved resume verse
  and replay the queue from the top (mirror `clearResumeAndPlay`).

## 4. `MiniVoicePlayer` — hide the voice gear for narration

Add a `let showsVoiceButton: Bool` input. DailyPlanView passes
`false` when the active session is recorded narration (expose
`playback.isNarrated` or similar), `true` for the TTS fallback. The
speed pills work for both paths.

## What NOT to do

- Don't delete VoiceService / VoiceSetupSheet / the synthesizer path —
  they're the live fallback for every plan besides John until we record
  more books.
- Don't download files up-front or add a caching layer — AVPlayer
  streams from the public CDN URLs fine; verse files are ~50–150 KB.
- Don't gate the audio behind auth — the bucket is deliberately public.
- Don't build your own reference parser — reuse BibleAPIService's.
- Don't change the mini player layout or the highlight visuals.

## Test plan

1. John plan, any day → Read step → tap speaker. Narrated audio starts
   immediately (no voice-setup sheet), the verse highlight follows verse
   by verse, and the mini player's progress bar advances smoothly.
2. Speed pills: 0.75x/1x/1.25x audibly change pace mid-verse and persist
   across sessions.
3. Stop mid-passage (×), reopen, tap speaker → resumes at the verse you
   left, not the beginning. Restart button → starts from verse 1.
4. Lock the phone during playback → lock screen shows the passage title
   with real duration; play/pause/stop work; audio continues in
   background.
5. Silent switch on → narration still plays (.playback category).
6. Open a plan day WITHOUT tapping the speaker while music plays in
   Apple Music/Spotify → the music does NOT stop (lazy session fix).
   Tap the speaker → music pauses, narration plays; stop → music
   resumes.
7. A non-John plan (any pastor plan with a Read step, or a future plan)
   → speaker falls back to the device-voice flow exactly as today,
   including the setup sheet on first use.
8. Voice previews in the setup sheet (fallback path) no longer break
   lock-screen controls for a later real session.
