//
//  VoiceSetupSheet.swift
//  YGTeeV
//
//  One-time (per-user) sheet that runs when the speaker icon in the
//  Read & Reflect section is first tapped. Two branches keyed off
//  whether any Enhanced or Premium English voice is currently
//  installed on the device:
//
//    • Empty state (`available.isEmpty`)
//        Walks the user through Settings → Accessibility → Spoken
//        Content → Voices with numbered steps, plus an "Open
//        Settings" CTA and a "Skip — use default voice" escape
//        hatch. When they return from Settings, the sheet's
//        `.onChange(of: scenePhase)` hook republishes the catalog so
//        the freshly-installed voice appears without dismissing.
//
//    • Installed state
//        Lists every Enhanced/Premium voice with a Preview button
//        (reads a short John 1:1-2 sample) + a single radio-style
//        selection. Confirm locks in the choice and fires the
//        caller's `onConfirm` so the actual passage starts playing
//        the moment the sheet dismisses.
//

import SwiftUI
import AVFoundation

struct VoiceSetupSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) var scenePhase
    @ObservedObject var voice: VoiceService

    /// Fires after the user confirms a voice. Parent uses this to
    /// kick off playback of the currently-visible passage so the
    /// experience flows: tap speaker → setup → playback. No second
    /// tap needed.
    let onConfirm: (AVSpeechSynthesisVoice) -> Void

    /// Radio-style selection. Seeded from the user's saved choice on
    /// appear so they can confirm-as-is without re-selecting.
    @State private var selectedID: String?
    /// Dedicated preview controller — separate from the parent's
    /// playback controller so previewing a voice doesn't compete
    /// with the actual reading session.
    @StateObject private var previewController = VersePlaybackController()

    /// Only Enhanced + Premium voices are eligible — Default ones
    /// sound robotic and aren't worth presenting.
    private var available: [AVSpeechSynthesisVoice] {
        voice.availableEnglishVoices().filter { $0.quality != .default }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if available.isEmpty {
                        emptyState
                    } else {
                        installedState
                    }
                }
                .padding(20)
            }
            .navigationTitle("Reading voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                // Returning from iOS Settings — voice catalog may
                // have grown. Force a UI tick so the empty state
                // flips to the installed state automatically.
                voice.objectWillChange.send()
            }
        }
        .onDisappear { previewController.stop() }
    }

    // MARK: - Empty state (no premium voice installed)

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 36))
                .foregroundStyle(YGColors.violet)

            Text("Set up your reading voice")
                .font(.title2.weight(.semibold))

            Text("YGTeeV uses your iPhone's built-in voice to read scripture aloud. The default voice sounds robotic — but Apple offers free higher-quality voices you can download from Settings.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Quick steps in Settings")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(YGColors.violet)
                stepRow(1, "Tap Accessibility")
                stepRow(2, "Tap Spoken Content")
                stepRow(3, "Tap Voices → English")
                stepRow(4, "Tap any voice marked Premium or Enhanced to download")
                stepRow(5, "Come back here when it finishes")
            }
            .padding(14)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                voice.openVoiceSettings()
            } label: {
                HStack {
                    Image(systemName: "arrow.up.right.square")
                    Text("Open iPhone Settings")
                }
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(YGColors.violet)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                // Escape hatch — locks in whatever the system has.
                // Marks setup complete so we don't nag every tap.
                // `selectedVoiceIdentifier` stays nil under the hood
                // if the fallback chain returns nil, which sends
                // `resolvedVoice` to the system default.
                let fallback = voice.bestAvailableVoice()
                    ?? AVSpeechSynthesisVoice(language: "en-US")
                if let v = fallback {
                    voice.confirmVoice(v)
                    onConfirm(v)
                }
                dismiss()
            } label: {
                Text("Skip — use default voice")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
    }

    // MARK: - Installed state (at least one premium / enhanced voice)

    private var installedState: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose your voice")
                .font(.title2.weight(.semibold))

            Text("Tap Preview to hear each voice read a sample. Pick the one you want for Bible reading.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(available, id: \.identifier) { v in
                    voiceRow(v)
                }
            }

            Button {
                voice.openVoiceSettings()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                    Text("Download more voices in Settings")
                }
                .font(.system(size: 14))
                .foregroundStyle(YGColors.violet)
            }
            .padding(.top, 4)

            Button {
                if let id = selectedID,
                   let v = AVSpeechSynthesisVoice(identifier: id) {
                    voice.confirmVoice(v)
                    onConfirm(v)
                    dismiss()
                }
            } label: {
                Text("Confirm and start reading")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(selectedID == nil ? Color.gray.opacity(0.3) : YGColors.violet)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(selectedID == nil)
        }
        .onAppear {
            if selectedID == nil {
                selectedID = voice.selectedVoiceIdentifier
                    ?? voice.bestAvailableVoice()?.identifier
            }
        }
    }

    // MARK: - Row + helpers

    private func voiceRow(_ v: AVSpeechSynthesisVoice) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(selectedID == v.identifier
                              ? YGColors.violet
                              : Color.gray.opacity(0.2))
                if selectedID == v.identifier {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(v.name)
                    .font(.system(size: 15, weight: .semibold))
                HStack(spacing: 6) {
                    Text(qualityLabel(v.quality))
                    Text("·")
                    Text(v.language)
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                previewController.play(
                    text: "In the beginning the Word already existed. The Word was with God, and the Word was God.",
                    voice: v
                )
            } label: {
                Text("Preview")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.15))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture { selectedID = v.identifier }
        .padding(.vertical, 6)
    }

    private func qualityLabel(_ q: AVSpeechSynthesisVoiceQuality) -> String {
        switch q {
        case .premium:  return "Premium"
        case .enhanced: return "Enhanced"
        default:        return "Default"
        }
    }

    private func stepRow(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(n)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(YGColors.violet)
                .clipShape(Circle())
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.primary)
        }
    }
}
