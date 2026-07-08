//
//  VersePlaybackController.swift
//  YGTeeV
//
//  Per-Read-step playback session. Takes a `VersePassage`, plays it
//  through `AVSpeechSynthesizer`, and publishes live state to the
//  mini player + verse-highlight UI:
//
//    • `isPlaying`            — actively producing audio
//    • `hasActiveSession`     — passage loaded (play OR pause)
//    • `progress`             — 0…1 character-driven
//    • `currentVerseNumber`   — verse the synthesizer is on RIGHT NOW
//
//  Beyond v1's plain text playback this version handles:
//    • Resume from a saved character offset (via `VoiceService`)
//    • Mid-session speed change (re-speak from current word boundary)
//    • `MPNowPlayingInfoCenter` + remote-command center so the
//      lock-screen and Control Center can show the passage title
//      and accept play / pause / stop while the app is backgrounded
//      (paired with `UIBackgroundModes: audio` in Info.plist)
//
//  Audio session: `.playback` + `.spokenAudio` — survives the silent
//  switch and ducks other audio appropriately.
//

import Foundation
import AVFoundation
import MediaPlayer
import UIKit

@MainActor
@Observable
final class VersePlaybackController: NSObject, AVSpeechSynthesizerDelegate {

    // MARK: - Observable state

    private(set) var isPlaying: Bool = false
    private(set) var hasActiveSession: Bool = false
    private(set) var progress: Double = 0
    private(set) var currentVerseNumber: Int? = nil

    // MARK: - Internals

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var currentPassage: VersePassage?
    /// Character offset (within the passage's full text) where this
    /// utterance actually started speaking. Zero on a fresh play,
    /// >0 when resuming. Required to translate utterance-local
    /// `willSpeak` ranges back into passage-global coordinates so
    /// the verseMap lookup stays correct after a resume.
    @ObservationIgnored private var startOffsetInPassage: Int = 0
    /// Latest passage-global offset the synthesizer has spoken up
    /// to. Saved as the resume position when the session ends.
    @ObservationIgnored private var lastSpokenOffsetInPassage: Int = 0
    @ObservationIgnored private let voiceService = VoiceService.shared

    override init() {
        super.init()
        synthesizer.delegate = self
        try? AVAudioSession.sharedInstance().setCategory(
            .playback,
            mode: .spokenAudio,
            options: []
        )
        try? AVAudioSession.sharedInstance().setActive(true)
        registerRemoteCommands()
    }

    // MARK: - Public controls

    /// Start (or resume) reading the passage. If a resume offset is
    /// saved for this passage's identifier, picks up there. Use
    /// `clearResumeAndPlay` to force a fresh start.
    func play(_ passage: VersePassage, voice: AVSpeechSynthesisVoice?) {
        // `clearResume: false` because we're about to LOAD a passage
        // — not abandon one. The active-session tear-down here is
        // purely to release the prior utterance.
        stop(clearResume: false)
        currentPassage = passage

        let resumeOffset = voiceService.resumeOffset(for: passage.identifier) ?? 0
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

        synthesizer.speak(utterance)
        isPlaying = true
        hasActiveSession = true
        progress = passage.text.isEmpty
            ? 0
            : Double(startOffsetInPassage) / Double(passage.text.count)

        updateNowPlaying(rate: 1.0)
    }

    /// Forget the saved resume offset and play from the top. Wired
    /// to the restart button in the mini player.
    func clearResumeAndPlay(_ passage: VersePassage, voice: AVSpeechSynthesisVoice?) {
        voiceService.clearResumeOffset(for: passage.identifier)
        play(passage, voice: voice)
    }

    /// User-facing stop. Saves the current offset as a resume point
    /// (unless we're within 5% of the end — treat as finished).
    func stop() {
        stop(clearResume: false)
    }

    func pauseOrResume() {
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
            isPlaying = true
            updateNowPlaying(rate: 1.0)
        } else if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .word)
            isPlaying = false
            updateNowPlaying(rate: 0.0)
        }
    }

    /// AVSpeech can't change rate mid-utterance, so apply the new
    /// speed by saving the current offset and restarting at the
    /// next word boundary. Caller is the mini-player speed picker.
    func reapplyCurrentSpeed(voice: AVSpeechSynthesisVoice?) {
        guard let passage = currentPassage else { return }
        voiceService.saveResumeOffset(lastSpokenOffsetInPassage, for: passage.identifier)
        play(passage, voice: voice)
    }

    // MARK: - Internal stop

    private func stop(clearResume: Bool) {
        if let passage = currentPassage {
            if clearResume {
                voiceService.clearResumeOffset(for: passage.identifier)
            } else if isPlaying || synthesizer.isPaused {
                let offset = lastSpokenOffsetInPassage
                let totalLen = max(1, passage.text.count)
                let nearEnd = Double(offset) / Double(totalLen) > 0.95
                if offset > 0 && !nearEnd {
                    voiceService.saveResumeOffset(offset, for: passage.identifier)
                } else {
                    voiceService.clearResumeOffset(for: passage.identifier)
                }
            }
        }
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isPlaying = false
        hasActiveSession = false
        progress = 0
        currentVerseNumber = nil
        currentPassage = nil
        startOffsetInPassage = 0
        lastSpokenOffsetInPassage = 0
        clearNowPlaying()
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
            guard let passage = self.currentPassage else { return }
            // Translate utterance-local offset → passage-global
            // offset so the verseMap lookup is accurate after a
            // resume (where `startOffsetInPassage` is non-zero).
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
            if let id = self.currentPassage?.identifier {
                self.voiceService.clearResumeOffset(for: id)
            }
            self.isPlaying = false
            self.hasActiveSession = false
            self.progress = 1.0
            self.currentVerseNumber = nil
            self.currentPassage = nil
            self.clearNowPlaying()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didCancel utterance: AVSpeechUtterance) {
        // didCancel fires from `.stopSpeaking(at:)` — state is
        // already torn down by `stop(clearResume:)`. Nothing to do.
    }

    // MARK: - MPNowPlayingInfoCenter

    private func updateNowPlaying(rate: Double) {
        guard let p = currentPassage else { clearNowPlaying(); return }

        // Crude duration estimate so the lock-screen progress bar
        // shows movement. ~12 chars/sec at neutral rate (0.5),
        // scaled by the current speed.
        let speedMul = voiceService.playbackSpeed.rawValue / 0.5
        let estDuration = Double(p.text.count) / max(1.0, 12.0 * speedMul)
        let elapsed = progress * estDuration

        var info: [String: Any] = [
            MPMediaItemPropertyTitle:                     p.title,
            MPMediaItemPropertyArtist:                    "YGTeeV",
            MPMediaItemPropertyPlaybackDuration:          estDuration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime:  elapsed,
            MPNowPlayingInfoPropertyPlaybackRate:         rate
        ]
        if let artwork = nowPlayingArtwork() {
            info[MPMediaItemPropertyArtwork] = artwork
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func clearNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func nowPlayingArtwork() -> MPMediaItemArtwork? {
        // Reuses the brand mark already in Assets.xcassets.
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
                if self.synthesizer.isPaused { self.pauseOrResume() }
            }
            return .success
        }

        c.pauseCommand.removeTarget(nil)
        c.pauseCommand.isEnabled = true
        c.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in
                if self.synthesizer.isSpeaking { self.pauseOrResume() }
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
