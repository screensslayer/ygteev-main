//
//  VoiceService.swift
//  YGTeeV
//
//  On-device text-to-speech voice catalog + per-user preference. Owns
//  no playback state — that lives in `VersePlaybackController`. This
//  service is purely a "which voice should we use" oracle:
//
//    • Enumerate every English `AVSpeechSynthesisVoice` installed on
//      the device, sorted Premium → Enhanced → Default.
//    • Track which one the user picked in the one-time setup sheet.
//    • Persist their selection to UserDefaults so the choice survives
//      cold launches (voices are per-device installs, so the
//      identifier doesn't make sense to sync server-side).
//    • Open iOS Settings via the public `openSettingsURLString` API
//      so the user can download Premium / Enhanced voices from
//      Accessibility → Spoken Content → Voices. Private deep links
//      into Accessibility get App-Store-rejected and break between
//      iOS versions — the in-sheet 5-step guide does that walk.
//

import Foundation
import AVFoundation
import UIKit

@MainActor
final class VoiceService: ObservableObject {
    static let shared = VoiceService()

    // MARK: - Persistence keys

    private let userDefaultsKey = "ygteev.selectedVoiceIdentifier"
    private let didSeeSetupKey  = "ygteev.didSeeVoiceSetup"

    /// The identifier the user picked inside YGTeeV's setup sheet —
    /// NOT necessarily iOS's system default. `nil` until the user
    /// completes (or skips) the one-time setup flow.
    @Published private(set) var selectedVoiceIdentifier: String? {
        didSet {
            UserDefaults.standard.set(selectedVoiceIdentifier, forKey: userDefaultsKey)
        }
    }

    /// True once the user has either picked a voice or explicitly
    /// chosen to skip. Drives whether the speaker-icon tap auto-
    /// presents the setup sheet vs. plays immediately.
    var didCompleteSetup: Bool {
        get { UserDefaults.standard.bool(forKey: didSeeSetupKey) }
        set { UserDefaults.standard.set(newValue, forKey: didSeeSetupKey) }
    }

    private init() {
        selectedVoiceIdentifier = UserDefaults.standard.string(forKey: userDefaultsKey)
    }

    // MARK: - Catalog

    /// Every English voice currently installed on this device, sorted
    /// by quality (Premium → Enhanced → Default), then alpha. Re-read
    /// every time we need it — voices may be downloaded between
    /// renders, and SwiftUI re-evaluates body when the sheet returns
    /// from background.
    func availableEnglishVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted { lhs, rhs in
                if lhs.quality != rhs.quality {
                    return lhs.quality.rawValue > rhs.quality.rawValue
                }
                return lhs.name < rhs.name
            }
    }

    /// True if at least one Enhanced or Premium voice is installed —
    /// drives the "empty state" vs "choose your voice" branch in
    /// `VoiceSetupSheet`.
    var hasHighQualityVoiceInstalled: Bool {
        availableEnglishVoices().contains { $0.quality != .default }
    }

    /// Best voice currently available on the device. Premium beats
    /// Enhanced beats Default. Used as the auto-promote target when
    /// the user has never explicitly picked.
    func bestAvailableVoice() -> AVSpeechSynthesisVoice? {
        availableEnglishVoices().first
    }

    /// What the playback controller should actually use, with a
    /// graceful fallback chain: user selection → best available →
    /// the system's default en-US voice → nil (never expect).
    var resolvedVoice: AVSpeechSynthesisVoice? {
        if let id = selectedVoiceIdentifier,
           let v = AVSpeechSynthesisVoice(identifier: id) {
            return v
        }
        return bestAvailableVoice() ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    // MARK: - Mutations

    /// Lock in the user's choice from the setup sheet AND flag setup
    /// as complete so we don't re-prompt on every tap.
    func confirmVoice(_ voice: AVSpeechSynthesisVoice) {
        selectedVoiceIdentifier = voice.identifier
        didCompleteSetup = true
    }

    /// Wipes both selection + setup-complete flag. Use sparingly — the
    /// gear button in the mini player re-opens the sheet without
    /// resetting state (so the previous selection stays highlighted).
    func resetSetup() {
        selectedVoiceIdentifier = nil
        didCompleteSetup = false
    }

    // MARK: - Settings deep-link

    /// Opens iOS Settings to YGTeeV's app row. App-Store-safe; the
    /// in-sheet 5-step guide tells the user the few extra taps to
    /// reach Accessibility → Spoken Content → Voices. Trying to deep-
    /// link straight into Accessibility uses private URL schemes
    /// that get the app rejected.
    func openVoiceSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
