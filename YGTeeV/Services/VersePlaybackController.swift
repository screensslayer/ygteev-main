//
//  VersePlaybackController.swift
//  YGTeeV
//
//  Per-Read-step playback session. Owns the audio state for a single
//  passage and publishes a uniform surface (`isPlaying`,
//  `hasActiveSession`, `progress`, `currentVerseNumber`) so the mini
//  player + verse-highlight UI stay identical regardless of which
//  underlying playback engine is active:
//
//    • Recorded narration (`AVQueuePlayer` streaming per-verse MP3s
//      from Supabase's public `verse-audio` bucket). Preferred path
//      whenever `VerseAudioService.narration(for:)` returns a hit.
//
//    • Device text-to-speech (`AVSpeechSynthesizer`). Fallback for
//      plans / books we haven't recorded yet.
//
//  Both paths respect a saved resume position (character offset for
//  TTS, verse number for narration), publish MPNowPlayingInfoCenter
//  metadata, and hand play/pause/stop to `MPRemoteCommandCenter` so
//  the lock screen and Control Center control playback while
//  backgrounded (paired with `UIBackgroundModes: audio`).
//
//  Audio session: `.playback` + `.spokenAudio` — survives the silent
//  switch and ducks other audio. Activation is lazy (moved out of
//  `init` into each `play(…)` call) so simply opening a plan day no
//  longer stops the user's Apple Music / Spotify playback; the
//  session activates on speaker tap and deactivates
//  (`notifyOthersOnDeactivation`) on stop, so their music resumes.
//
//  Preview mode (`isPreview: true`) — the voice-picker sheet creates
//  a scratch controller to play short samples. That controller must
//  NOT touch the shared audio session, hijack lock-screen remote
//  commands, publish Now Playing, or persist resume offsets. Every
//  side-effecting hook below gates on `isPreview`.
//

import Foundation
import AVFoundation
import MediaPlayer
import UIKit

@MainActor
@Observable
final class VersePlaybackController: NSObject, AVSpeechSynthesizerDelegate {

    // MARK: - Observable state (same shape for both engines)

    private(set) var isPlaying: Bool = false
    private(set) var hasActiveSession: Bool = false
    private(set) var progress: Double = 0
    private(set) var currentVerseNumber: Int? = nil

    /// `true` while a recorded-narration session is active. Callers
    /// (mini player, restart button) use this to route between the
    /// two engines' behaviors without introspecting the mode enum.
    var isNarrated: Bool {
        if case .narration = mode { return true }
        return false
    }

    // MARK: - Preview flag

    /// When `true`, this controller is a scratch instance for voice
    /// previews. It never activates the shared audio session,
    /// registers remote commands, publishes Now Playing, or persists
    /// resume state.
    @ObservationIgnored private let isPreview: Bool

    // MARK: - Mode

    private enum Mode {
        case none
        case tts
        case narration
    }
    @ObservationIgnored private var mode: Mode = .none

    // MARK: - TTS state

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var currentPassage: VersePassage?
    @ObservationIgnored private var currentUtterance: AVSpeechUtterance?
    @ObservationIgnored private var startOffsetInPassage: Int = 0
    @ObservationIgnored private var lastSpokenOffsetInPassage: Int = 0

    // MARK: - Narration state

    @ObservationIgnored private var queuePlayer: AVQueuePlayer?
    @ObservationIgnored private var narrationItems: [VerseAudioItem] = []
    /// Parallel array (same order as `queuePlayer`'s items) so the
    /// currentItem observer can resolve which verse is playing
    /// without wrapping AVPlayerItem in a custom subclass.
    @ObservationIgnored private var narrationPlayerItems: [AVPlayerItem] = []
    @ObservationIgnored private var narrationPassageId: String = ""
    @ObservationIgnored private var narrationTitle: String = ""
    /// Sum of durations of verses BEFORE the current item — used
    /// with `player.currentTime()` to compute total-progress without
    /// waiting on asset loading.
    @ObservationIgnored private var narrationBaseElapsed: Double = 0
    @ObservationIgnored private var narrationTotalDuration: Double = 0
    @ObservationIgnored private var narrationCurrentItemObs: NSKeyValueObservation?
    @ObservationIgnored private var narrationTimeObserver: Any?
    @ObservationIgnored private var narrationEndObserver: NSObjectProtocol?

    // MARK: - Shared

    @ObservationIgnored private let voiceService = VoiceService.shared

    init(isPreview: Bool = false) {
        self.isPreview = isPreview
        super.init()
        synthesizer.delegate = self
        // Remote commands + audio session activation moved into
        // `play(…)` — see the file header comment. Preview
        // controllers skip remote-command registration entirely.
        if !isPreview {
            registerRemoteCommands()
        }
    }

    // MARK: - TTS entry points

    /// Start (or resume) synthesizer playback of `passage`. If a
    /// character-offset resume is saved for this passage id it picks
    /// up there. `clearResumeAndPlay` forces a fresh start.
    func play(_ passage: VersePassage, voice: AVSpeechSynthesisVoice?) {
        activateSessionForPlaybackIfNeeded()

        // Wipe any active narration session so state doesn't leak
        // between engines.
        teardownNarration()

        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }

        mode = .tts
        currentPassage = passage
        currentVerseNumber = nil

        let resumeOffset = isPreview ? 0 : (voiceService.resumeOffset(for: passage.identifier) ?? 0)
        startOffsetInPassage = min(resumeOffset, passage.text.count)
        lastSpokenOffsetInPassage = startOffsetInPassage

        let textToSpeak: String
        if startOffsetInPassage > 0, startOffsetInPassage < passage.text.count {
            let start = passage.text.index(passage.text.startIndex, offsetBy: startOffsetInPassage)
            textToSpeak = String(passage.text[start...])
        } else {
            textToSpeak = passage.text
            startOffsetInPassage = 0
        }

        let utterance = AVSpeechUtterance(string: textToSpeak)
        if let v = voice { utterance.voice = v }
        utterance.rate = Float(voiceService.playbackSpeed.rawValue)
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.2

        currentUtterance = utterance
        synthesizer.speak(utterance)
        isPlaying = true
        hasActiveSession = true
        progress = passage.text.isEmpty
            ? 0
            : Double(startOffsetInPassage) / Double(passage.text.count)

        updateNowPlaying(rate: 1.0)
    }

    /// Forget any saved TTS resume offset and play from the top.
    func clearResumeAndPlay(_ passage: VersePassage, voice: AVSpeechSynthesisVoice?) {
        if !isPreview {
            voiceService.clearResumeOffset(for: passage.identifier)
        }
        play(passage, voice: voice)
    }

    // MARK: - Narration entry points

    /// Start (or resume) recorded-narration playback. Each item is
    /// queued as a separate `AVPlayerItem` so we can highlight the
    /// current verse via `currentItem` observation.
    func play(items: [VerseAudioItem], passageId: String, title: String) {
        guard !items.isEmpty else { return }
        activateSessionForPlaybackIfNeeded()

        // Wipe any active TTS session so state doesn't leak between
        // engines.
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        currentPassage = nil
        currentUtterance = nil
        startOffsetInPassage = 0
        lastSpokenOffsetInPassage = 0

        teardownNarration()

        mode = .narration
        narrationItems = items
        narrationPassageId = passageId
        narrationTitle = title
        narrationTotalDuration = items.reduce(0) { $0 + $1.duration }

        // Resume from the saved verse if we have one AND it's still
        // in the item list. Otherwise start from the top.
        let resumeVerse = isPreview ? nil : voiceService.audioResumeVerse(for: passageId)
        let startIndex: Int = {
            if let v = resumeVerse, let idx = items.firstIndex(where: { $0.verse == v }) {
                return idx
            }
            return 0
        }()

        narrationBaseElapsed = items.prefix(startIndex).reduce(0) { $0 + $1.duration }

        let playerItems = items[startIndex...].map { AVPlayerItem(url: $0.url) }
        narrationPlayerItems = playerItems
        let player = AVQueuePlayer(items: playerItems)
        player.actionAtItemEnd = .advance
        queuePlayer = player

        // Observe currentItem changes so `currentVerseNumber` +
        // `narrationBaseElapsed` update as the queue advances.
        narrationCurrentItemObs = player.observe(\.currentItem, options: [.initial, .new]) { [weak self] p, _ in
            Task { @MainActor in self?.narrationCurrentItemChanged(player: p) }
        }

        // Periodic time observer drives the progress bar.
        narrationTimeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.narrationTick() }
        }

        // The default AVQueuePlayer notification is per-item; we
        // want to detect END-OF-QUEUE, so listen on the LAST item.
        if let last = playerItems.last {
            narrationEndObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: last,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.narrationDidFinishAll() }
            }
        }

        currentVerseNumber = items[startIndex].verse
        hasActiveSession = true
        isPlaying = true
        applyNarrationRate()
        player.play()
        updateNowPlaying(rate: Double(voiceService.playbackSpeed.narrationRate))
    }

    /// Forget any saved narration resume verse and play from the top.
    func clearNarrationResumeAndPlay() {
        guard case .narration = mode else { return }
        if !isPreview {
            voiceService.clearAudioResumeVerse(for: narrationPassageId)
        }
        let items = narrationItems
        let passageId = narrationPassageId
        let title = narrationTitle
        play(items: items, passageId: passageId, title: title)
    }

    // MARK: - Shared controls

    /// User-facing stop. Saves resume state on the appropriate path
    /// (unless within 5% of the end — treat as finished) and deactivates
    /// the shared audio session so the user's music resumes.
    func stop() {
        stop(clearResume: false)
    }

    func pauseOrResume() {
        switch mode {
        case .tts:
            if synthesizer.isPaused {
                synthesizer.continueSpeaking()
                isPlaying = true
                updateNowPlaying(rate: 1.0)
            } else if synthesizer.isSpeaking {
                synthesizer.pauseSpeaking(at: .word)
                isPlaying = false
                updateNowPlaying(rate: 0.0)
            }
        case .narration:
            guard let player = queuePlayer else { return }
            if isPlaying {
                player.pause()
                isPlaying = false
                updateNowPlaying(rate: 0.0)
            } else {
                // `.play()` on AVQueuePlayer resets rate to 1.0, so
                // re-apply the user's chosen speed afterward.
                player.play()
                applyNarrationRate()
                isPlaying = true
                updateNowPlaying(rate: Double(voiceService.playbackSpeed.narrationRate))
            }
        case .none:
            break
        }
    }

    /// Re-apply the currently-selected speed to whichever engine is
    /// active. AVSpeech can't change rate mid-utterance, so the TTS
    /// path saves + replays from the current word boundary; the
    /// narration path just sets `player.rate`.
    func reapplyCurrentSpeed(voice: AVSpeechSynthesisVoice?) {
        switch mode {
        case .tts:
            guard let passage = currentPassage else { return }
            if !isPreview {
                voiceService.saveResumeOffset(lastSpokenOffsetInPassage, for: passage.identifier)
            }
            play(passage, voice: voice)
        case .narration:
            applyNarrationRate()
            updateNowPlaying(rate: Double(voiceService.playbackSpeed.narrationRate))
        case .none:
            break
        }
    }

    // MARK: - Internal stop

    private func stop(clearResume: Bool) {
        switch mode {
        case .tts:
            if let passage = currentPassage {
                if clearResume {
                    if !isPreview { voiceService.clearResumeOffset(for: passage.identifier) }
                } else if isPlaying || synthesizer.isPaused {
                    let offset = lastSpokenOffsetInPassage
                    let totalLen = max(1, passage.text.count)
                    let nearEnd = Double(offset) / Double(totalLen) > 0.95
                    if !isPreview {
                        if offset > 0 && !nearEnd {
                            voiceService.saveResumeOffset(offset, for: passage.identifier)
                        } else {
                            voiceService.clearResumeOffset(for: passage.identifier)
                        }
                    }
                }
            }
            if synthesizer.isSpeaking || synthesizer.isPaused {
                synthesizer.stopSpeaking(at: .immediate)
            }
        case .narration:
            if clearResume {
                if !isPreview { voiceService.clearAudioResumeVerse(for: narrationPassageId) }
            } else if let verse = currentVerseNumber, let lastVerse = narrationItems.last?.verse {
                // Save unless we're within one verse of the end —
                // matches the TTS path's "near end = finished" rule.
                let nearEnd = verse >= lastVerse
                if !isPreview {
                    if !nearEnd {
                        voiceService.saveAudioResumeVerse(verse, for: narrationPassageId)
                    } else {
                        voiceService.clearAudioResumeVerse(for: narrationPassageId)
                    }
                }
            }
            teardownNarration()
        case .none:
            break
        }

        mode = .none
        isPlaying = false
        hasActiveSession = false
        progress = 0
        currentVerseNumber = nil
        currentPassage = nil
        currentUtterance = nil
        startOffsetInPassage = 0
        lastSpokenOffsetInPassage = 0
        clearNowPlaying()

        // Hand audio focus back so background music (Spotify, Apple
        // Music, etc.) resumes. Preview never activated the session
        // in the first place, so skip.
        if !isPreview {
            try? AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        }
    }

    // MARK: - Audio session

    private func activateSessionForPlaybackIfNeeded() {
        guard !isPreview else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .spokenAudio,
                options: []
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[VersePlaybackController] audio session activate failed:", error)
        }
    }

    // MARK: - Narration helpers

    private func applyNarrationRate() {
        guard let player = queuePlayer else { return }
        player.rate = voiceService.playbackSpeed.narrationRate
    }

    /// Rebuild `narrationBaseElapsed` + `currentVerseNumber` when the
    /// queue advances to the next item.
    private func narrationCurrentItemChanged(player: AVQueuePlayer) {
        guard let current = player.currentItem,
              let idx = narrationPlayerItems.firstIndex(of: current) else {
            return
        }
        narrationBaseElapsed = narrationItems.prefix(idx).reduce(0) { $0 + $1.duration }
        currentVerseNumber = narrationItems[idx].verse
        updateNowPlaying(rate: isPlaying ? Double(voiceService.playbackSpeed.narrationRate) : 0.0)
    }

    /// Periodic tick — updates `progress` from real elapsed time.
    private func narrationTick() {
        guard let player = queuePlayer else { return }
        let itemElapsed = CMTimeGetSeconds(player.currentTime())
        let sanitizedElapsed = itemElapsed.isFinite ? max(0, itemElapsed) : 0
        let totalElapsed = narrationBaseElapsed + sanitizedElapsed
        if narrationTotalDuration > 0 {
            progress = min(1.0, totalElapsed / narrationTotalDuration)
        }
    }

    private func narrationDidFinishAll() {
        if !isPreview {
            voiceService.clearAudioResumeVerse(for: narrationPassageId)
        }
        teardownNarration()
        mode = .none
        isPlaying = false
        hasActiveSession = false
        progress = 1.0
        currentVerseNumber = nil
        clearNowPlaying()
        if !isPreview {
            try? AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        }
    }

    /// Detach observers and drop the queue player. Safe to call
    /// multiple times.
    private func teardownNarration() {
        if let obs = narrationTimeObserver, let player = queuePlayer {
            player.removeTimeObserver(obs)
        }
        narrationTimeObserver = nil
        narrationCurrentItemObs?.invalidate()
        narrationCurrentItemObs = nil
        if let end = narrationEndObserver {
            NotificationCenter.default.removeObserver(end)
        }
        narrationEndObserver = nil
        queuePlayer?.pause()
        queuePlayer?.removeAllItems()
        queuePlayer = nil
        narrationPlayerItems = []
        narrationItems = []
        narrationPassageId = ""
        narrationTitle = ""
        narrationBaseElapsed = 0
        narrationTotalDuration = 0
    }

    // MARK: - AVSpeechSynthesizerDelegate
    //
    // All three callbacks are `nonisolated` — AVFoundation calls
    // them on whatever queue it pleases. Each hops back to the main
    // actor to mutate published state.

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       willSpeakRangeOfSpeechString characterRange: NSRange,
                                       utterance: AVSpeechUtterance) {
        let endCharInUtterance = characterRange.location + characterRange.length
        Task { @MainActor in
            guard utterance === self.currentUtterance else { return }
            guard let passage = self.currentPassage else { return }
            let endCharInPassage = self.startOffsetInPassage + endCharInUtterance
            self.lastSpokenOffsetInPassage = endCharInPassage
            let total = passage.text.count
            self.progress = total > 0
                ? min(1.0, Double(endCharInPassage) / Double(total))
                : 0
            self.currentVerseNumber = passage.verseMap.first {
                endCharInPassage > $0.startOffset && endCharInPassage <= $0.endOffset
            }?.verseNumber
            self.updateNowPlaying(rate: 1.0)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard utterance === self.currentUtterance else { return }
            if let id = self.currentPassage?.identifier, !self.isPreview {
                self.voiceService.clearResumeOffset(for: id)
            }
            self.mode = .none
            self.isPlaying = false
            self.hasActiveSession = false
            self.progress = 1.0
            self.currentVerseNumber = nil
            self.currentPassage = nil
            self.currentUtterance = nil
            self.clearNowPlaying()
            if !self.isPreview {
                try? AVAudioSession.sharedInstance().setActive(
                    false,
                    options: .notifyOthersOnDeactivation
                )
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didCancel utterance: AVSpeechUtterance) {
        // didCancel fires from `.stopSpeaking(at:)` — state is
        // already torn down by the caller (`stop()` or a new `play`).
    }

    // MARK: - MPNowPlayingInfoCenter

    private func updateNowPlaying(rate: Double) {
        guard !isPreview else { return }

        let title: String
        let duration: Double
        let elapsed: Double

        switch mode {
        case .tts:
            guard let p = currentPassage else { clearNowPlaying(); return }
            title = p.title
            let speedMul = voiceService.playbackSpeed.rawValue / 0.5
            duration = Double(p.text.count) / max(1.0, 12.0 * speedMul)
            elapsed = progress * duration
        case .narration:
            title = narrationTitle
            duration = narrationTotalDuration
            elapsed = progress * duration
        case .none:
            clearNowPlaying()
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle:                     title,
            MPMediaItemPropertyArtist:                    "YGTeeV",
            MPMediaItemPropertyPlaybackDuration:          duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime:  elapsed,
            MPNowPlayingInfoPropertyPlaybackRate:         rate
        ]
        if let artwork = nowPlayingArtwork() {
            info[MPMediaItemPropertyArtwork] = artwork
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func clearNowPlaying() {
        guard !isPreview else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func nowPlayingArtwork() -> MPMediaItemArtwork? {
        guard let img = UIImage(named: "ygteev-logo") else { return nil }
        return MPMediaItemArtwork(boundsSize: img.size) { _ in img }
    }

    // MARK: - Remote command center (lock screen + Control Center)

    private func registerRemoteCommands() {
        let c = MPRemoteCommandCenter.shared()

        c.playCommand.removeTarget(nil)
        c.playCommand.isEnabled = true
        c.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in
                switch self.mode {
                case .tts:
                    if self.synthesizer.isPaused { self.pauseOrResume() }
                case .narration:
                    if !self.isPlaying { self.pauseOrResume() }
                case .none:
                    break
                }
            }
            return .success
        }

        c.pauseCommand.removeTarget(nil)
        c.pauseCommand.isEnabled = true
        c.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in
                switch self.mode {
                case .tts:
                    if self.synthesizer.isSpeaking { self.pauseOrResume() }
                case .narration:
                    if self.isPlaying { self.pauseOrResume() }
                case .none:
                    break
                }
            }
            return .success
        }

        c.togglePlayPauseCommand.removeTarget(nil)
        c.togglePlayPauseCommand.isEnabled = true
        c.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in self.pauseOrResume() }
            return .success
        }

        c.stopCommand.removeTarget(nil)
        c.stopCommand.isEnabled = true
        c.stopCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in self.stop() }
            return .success
        }
    }
}

// MARK: - PlaybackSpeed → narration rate

private extension VoiceService.PlaybackSpeed {
    /// AVSpeech uses 0.4/0.5/0.6 (perceived 0.75x/1x/1.25x). AVPlayer
    /// uses literal rate multipliers, so the narration path needs
    /// the true 0.75/1.0/1.25 values.
    var narrationRate: Float {
        switch self {
        case .slow:   return 0.75
        case .normal: return 1.0
        case .fast:   return 1.25
        }
    }
}
