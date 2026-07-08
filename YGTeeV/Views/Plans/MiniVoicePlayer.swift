//
//  MiniVoicePlayer.swift
//  YGTeeV
//
//  Floating "now reading" card. Two-row layout:
//
//    Row 1 — Controls
//      [▶/⏸] [Reading aloud / passage title / progress] [↺] [⚙] [✕]
//      • Play/pause toggles `playback.pauseOrResume()`.
//      • Restart (`gobackward`) wipes the resume offset and plays
//        from the top via the parent's `onRestart` closure.
//      • Gear opens the voice setup sheet.
//      • × stops playback outright; parent animation removes the
//        card as `hasActiveSession` flips false.
//
//    Row 2 — Speed picker
//      0.75x / 1x / 1.25x pills. Tapping one updates
//      `voice.playbackSpeed` (persisted globally) and fires the
//      parent's `onSpeedChanged` so the controller re-speaks at the
//      new rate from the current word boundary.
//

import SwiftUI

struct MiniVoicePlayer: View {
    let playback: VersePlaybackController
    let voice: VoiceService
    let title: String
    let onChangeVoice: () -> Void
    let onRestart: () -> Void
    let onClose: () -> Void
    /// Fires after the user taps a different speed pill — parent
    /// re-applies the rate by calling
    /// `playback.reapplyCurrentSpeed(voice:)`.
    let onSpeedChanged: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            controlsRow
            speedRow
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .padding(.horizontal, 12)
    }

    // MARK: - Row 1: controls + title + progress

    private var controlsRow: some View {
        HStack(spacing: 12) {
            // Play / pause
            Button {
                playback.pauseOrResume()
            } label: {
                Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(YGColors.violet)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(playback.isPlaying ? "Pause reading" : "Resume reading")

            // Label + passage title + progress bar
            VStack(alignment: .leading, spacing: 4) {
                Text("Reading aloud")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .tracking(0.4)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(YGColors.ink)
                    .lineLimit(1)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.2))
                        Capsule()
                            .fill(YGColors.violet)
                            .frame(width: max(2, geo.size.width * playback.progress))
                    }
                }
                .frame(height: 3)
                .animation(.linear(duration: 0.2), value: playback.progress)
            }

            // Restart — wipes resume offset and plays from the top
            Button {
                onRestart()
            } label: {
                Image(systemName: "gobackward")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Restart from beginning")

            // Change voice
            Button {
                onChangeVoice()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Change voice")

            // Stop
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color.gray.opacity(0.15))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop reading")
        }
    }

    // MARK: - Row 2: speed picker

    private var speedRow: some View {
        HStack(spacing: 8) {
            Text("Speed")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            ForEach(VoiceService.PlaybackSpeed.allCases, id: \.self) { speed in
                Button {
                    voice.playbackSpeed = speed
                    onSpeedChanged()
                } label: {
                    Text(speed.label)
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            voice.playbackSpeed == speed
                                ? YGColors.violet
                                : Color.gray.opacity(0.15)
                        )
                        .foregroundStyle(
                            voice.playbackSpeed == speed ? .white : YGColors.ink
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Speed \(speed.label)")
            }
            Spacer()
        }
    }
}
