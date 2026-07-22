//
//  SuperchargerViews.swift
//  YGTeeV
//
//  Visual components for the "Supercharger" listen-to-earn bonus on
//  the daily plan's Read & Reflect step. Users tap the supercharger
//  pill on a passage card → the passage plays through the existing
//  `VersePlaybackController` (recorded narration on NLT, TTS
//  fallback elsewhere) → progress advances verse-by-verse → on true
//  completion the server awards a fixed 35 XP bonus, once per
//  passage per UTC day.
//
//  This file only holds the presentation pieces:
//    • `SuperchargerPill`      — the idle / charging / earned pill
//      that sits in the passage-card header (replaces the old
//      speaker icon).
//    • `SuperchargerMiniPlayer` — the floating light-glass card at
//      the bottom of the step during a charge.
//    • `SuperchargerConfettiOverlay` — the completion burst.
//    • `SuperchargerXPFlyUp`   — the "+35 XP" bolt that flies up
//      to the header XP counter.
//
//  Backend + playback wiring lives on `ReadStepView` in
//  `DailyPlanView.swift`. Everything here is stateless per-render —
//  parent-owned bindings + callbacks drive all state.
//
//  Reduce Motion: every looping animation is `@Environment(\.\
//  accessibilityReduceMotion)`-gated and swaps to static styling
//  when the user has that setting on.
//

import SwiftUI

// MARK: - Supercharger pill

/// Three-state pill that replaces the small speaker icon in the
/// passage-card header for each Read part. Idle pulses invitingly;
/// charging glows + shakes; earned is a static lime badge.
struct SuperchargerPill: View {
    enum State { case idle, charging, earned }

    let state: State
    /// Only fires when the pill is in `.idle`. Charging + earned
    /// states are non-tappable.
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @SwiftUI.State private var pulsePhase: CGFloat = 0
    @SwiftUI.State private var boltAngle: Double = 0
    @SwiftUI.State private var boltScale: CGFloat = 1

    private static let idleGradient = LinearGradient(
        colors: [Color(hex: "FFD60A"), Color(hex: "FF6B35")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        Button {
            if case .idle = state { onTap() }
        } label: {
            HStack(spacing: 6) {
                icon
                Text(label)
                    .font(.lilitaOne(size: 12))
                    .tracking(state == .idle ? 0.4 : 0.6)
                    .foregroundStyle(state == .earned ? Color(hex: "0A0712") : Color(hex: "0A0712"))
            }
            .padding(.leading, 9)
            .padding(.trailing, 12)
            .padding(.vertical, 7)
            .background(background)
            .clipShape(Capsule())
            .overlay(pulseRing)
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
        }
        .buttonStyle(SuperchargerPillButtonStyle())
        .disabled(state != .idle)
        .accessibilityLabel(accessibilityLabel)
        .onAppear { restartAnimations() }
        .onChange(of: state) { _, _ in restartAnimations() }
    }

    // MARK: - Content per state

    @ViewBuilder
    private var icon: some View {
        switch state {
        case .idle:
            Image(systemName: "bolt.fill")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Color(hex: "0A0712"))
        case .charging:
            Image(systemName: "bolt.fill")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Color(hex: "0A0712"))
                .rotationEffect(.degrees(boltAngle))
                .scaleEffect(boltScale)
        case .earned:
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(Color(hex: "0A0712"))
        }
    }

    private var label: String {
        switch state {
        case .idle: return "+35 XP"
        case .charging: return "CHARGING"
        case .earned: return "EARNED"
        }
    }

    private var accessibilityLabel: String {
        switch state {
        case .idle: return "Supercharge to earn 35 XP by listening"
        case .charging: return "Supercharging — listen to earn 35 XP"
        case .earned: return "35 XP already earned for this passage today"
        }
    }

    @ViewBuilder
    private var background: some View {
        switch state {
        case .idle, .charging:
            Self.idleGradient
        case .earned:
            Color(hex: "B4FF3C")
        }
    }

    @ViewBuilder
    private var pulseRing: some View {
        if state == .idle, !reduceMotion {
            // Radial-halo pulse: a capsule stroke expanding from the
            // pill edge. Matches the spec's box-shadow 0 → 12pt
            // yellow → transparent 1.8s loop, translated into SwiftUI
            // via a scaled+opacity-fading Capsule stroke.
            Capsule()
                .strokeBorder(Color(hex: "FFD60A"), lineWidth: 2)
                .scaleEffect(1 + pulsePhase * 0.22)
                .opacity(1 - Double(pulsePhase))
                .allowsHitTesting(false)
        }
    }

    private var shadowColor: Color {
        switch state {
        case .idle:     return Color(hex: "FF6B35").opacity(0.45)
        case .charging: return Color(hex: "FFD60A").opacity(0.7)
        case .earned:   return Color(hex: "B4FF3C").opacity(0.5)
        }
    }
    private var shadowRadius: CGFloat {
        switch state {
        case .idle:     return 8
        case .charging: return 18
        case .earned:   return 10
        }
    }
    private var shadowY: CGFloat { state == .idle ? 3 : 0 }

    // MARK: - Animation lifecycle

    private func restartAnimations() {
        guard !reduceMotion else {
            pulsePhase = 0
            boltAngle = 0
            boltScale = 1
            return
        }
        switch state {
        case .idle:
            pulsePhase = 0
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                pulsePhase = 1
            }
            boltAngle = 0
            boltScale = 1
        case .charging:
            pulsePhase = 0
            // Bolt shake — ±8° with a scale bump, 0.7s loop.
            boltAngle = 0
            boltScale = 1
            withAnimation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true)) {
                boltAngle = 8
                boltScale = 1.1
            }
        case .earned:
            pulsePhase = 0
            boltAngle = 0
            boltScale = 1
        }
    }
}

/// Squish-press effect for the pill — matches the mockup's press
/// scale (0.96) with a springy curve.
private struct SuperchargerPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.18, dampingFraction: 0.55),
                       value: configuration.isPressed)
    }
}

// MARK: - Mini player

/// Floating light-glass control shown at the bottom of Read &
/// Reflect while a supercharge session is active. Never presented
/// modally — the parent conditionally renders it inside its own
/// bottom-aligned overlay.
struct SuperchargerMiniPlayer: View {
    let reference: String
    let isPaused: Bool
    /// 0…1. Verse-based (versesCompleted / totalVerses), not time.
    let progress: Double
    let xpReward: Int
    /// The current playback speed pill — bound so tapping updates
    /// the parent's shared `VoiceService.playbackSpeed`.
    @Binding var speed: VoiceService.PlaybackSpeed
    /// Set briefly after `complete_listen_reward` responds with
    /// `awarded: true`. The mini player swaps its label for a
    /// success flash before the parent dismisses it.
    let justCompleted: Bool

    let onTogglePause: () -> Void
    let onSpeedChanged: () -> Void
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @SwiftUI.State private var stripePhase: CGFloat = 0
    @SwiftUI.State private var shimmerPhase: CGFloat = 0

    private var earnedXp: Int {
        min(xpReward, max(0, Int(floor(progress * Double(xpReward)))))
    }

    private var hypeText: String {
        if justCompleted {
            return "+\(xpReward) XP earned! 🔥"
        }
        if isPaused {
            return "Paused — your charge is waiting…"
        }
        if progress < 0.25 {
            return "Charging up… keep listening ⚡"
        } else if progress < 0.5 {
            return "XP is flowing — don't stop now!"
        } else if progress < 0.75 {
            return "Halfway! The charge is building…"
        } else {
            return "Almost there — full \(xpReward) XP incoming!"
        }
    }

    private var hypeColor: Color {
        if justCompleted { return Color(hex: "2B8A3E") }
        if isPaused      { return Color(hex: "0A0712").opacity(0.5) }
        if progress >= 0.75 { return Color(hex: "E0491F") }
        return Color(hex: "FF6B35")
    }

    var body: some View {
        VStack(spacing: 10) {
            topRow
            progressBar
            bottomRow
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.88))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.6), lineWidth: 0.5)
        )
        .shadow(color: Color(hex: "140E28").opacity(0.35), radius: 14, y: 12)
        .padding(.horizontal, 14)
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        ))
        .onAppear { startAnimations() }
    }

    // MARK: - Rows

    private var topRow: some View {
        HStack(spacing: 12) {
            Button(action: onTogglePause) {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Color(hex: "0A0712"))
                    .frame(width: 46, height: 46)
                    .background(
                        Circle().fill(
                            isPaused
                            ? AnyShapeStyle(Color(hex: "0A0712").opacity(0.12))
                            : AnyShapeStyle(LinearGradient(
                                colors: [Color(hex: "FFD60A"), Color(hex: "FF6B35")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                        )
                    )
                    .shadow(color: Color(hex: "FF6B35").opacity(0.4), radius: isPaused ? 0 : 6, y: 4)
            }
            .buttonStyle(SuperchargerPillButtonStyle())
            .accessibilityLabel(isPaused ? "Resume supercharge" : "Pause supercharge")

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(Color(hex: "FF6B35"))
                    Text(isPaused ? "SUPERCHARGE PAUSED" : "SUPERCHARGED · EARNING XP")
                        .font(.lilitaOne(size: 10))
                        .tracking(1.2)
                        .foregroundStyle(Color(hex: "FF6B35"))
                        .lineLimit(1)
                }
                Text(reference)
                    .font(.lilitaOne(size: 16))
                    .foregroundStyle(Color(hex: "0A0712"))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 0) {
                HStack(spacing: 0) {
                    Text("\(earnedXp)")
                        .font(.lilitaOne(size: 19))
                        .foregroundStyle(Color(hex: "FF6B35"))
                    Text("/\(xpReward) XP")
                        .font(.lilitaOne(size: 12))
                        .foregroundStyle(Color(hex: "0A0712").opacity(0.45))
                }
            }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Color(hex: "0A0712").opacity(0.55))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color(hex: "0A0712").opacity(0.06)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Forfeit supercharge")
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let filledWidth = max(12, totalWidth * CGFloat(min(1, max(0, progress))))
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(Color(hex: "0A0712").opacity(0.08))

                // Fill
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color(hex: "FFD60A"), Color(hex: "FF6B35")],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                    // Candy stripes (spec: 45°, 28pt period, 0.8s
                    // sweep). SwiftUI can't do CSS-style background-
                    // position animations directly, so we mask a
                    // static striped rectangle with the capsule and
                    // shift its horizontal offset.
                    if !reduceMotion {
                        stripedOverlay
                            .mask(Capsule())
                    }
                    // Shimmer sweep (1.4s loop). A translucent white
                    // gradient panel sweeping across the fill.
                    if !reduceMotion {
                        LinearGradient(
                            colors: [
                                .white.opacity(0),
                                .white.opacity(0.85),
                                .white.opacity(0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: filledWidth * 0.35)
                        .offset(x: (shimmerPhase - 0.2) * filledWidth)
                        .mask(Capsule())
                    }
                }
                .frame(width: filledWidth)

                // Riding thumb — 22pt circle with mini bolt, sits on
                // the leading edge of the fill.
                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(Color(hex: "FF6B35"))
                    )
                    .overlay(Circle().strokeBorder(Color(hex: "FF6B35"), lineWidth: 2))
                    .shadow(color: Color(hex: "FF6B35").opacity(0.5), radius: 4, y: 2)
                    .offset(x: max(0, filledWidth - 22))
            }
            .animation(.linear(duration: 0.12), value: progress)
        }
        .frame(height: 22)
    }

    private var stripedOverlay: some View {
        // Fixed-position stripes; animation shifts the phase.
        Rectangle()
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.35), location: 0),
                        .init(color: .white.opacity(0.35), location: 0.25),
                        .init(color: .clear,               location: 0.25),
                        .init(color: .clear,               location: 0.50),
                        .init(color: .white.opacity(0.35), location: 0.50),
                        .init(color: .white.opacity(0.35), location: 0.75),
                        .init(color: .clear,               location: 0.75),
                        .init(color: .clear,               location: 1.0),
                    ],
                    startPoint: UnitPoint(x: 0, y: 1),
                    endPoint:   UnitPoint(x: 1, y: 0)
                )
            )
            .offset(x: stripePhase * 28)
    }

    private var bottomRow: some View {
        HStack {
            Text(hypeText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(hypeColor)
                .lineLimit(1)
                .layoutPriority(1)

            Spacer(minLength: 8)

            HStack(spacing: 5) {
                ForEach(VoiceService.PlaybackSpeed.allCases, id: \.self) { s in
                    speedChip(s)
                }
            }
        }
    }

    private func speedChip(_ s: VoiceService.PlaybackSpeed) -> some View {
        let selected = speed == s
        return Button {
            speed = s
            onSpeedChanged()
        } label: {
            Text(s.label)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(selected ? Color.white : Color(hex: "0A0712").opacity(0.6))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(selected
                                   ? YGColors.violet
                                   : Color(hex: "0A0712").opacity(0.06))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Speed \(s.label)\(selected ? ", selected" : "")")
    }

    // MARK: - Animation

    private func startAnimations() {
        guard !reduceMotion else { return }
        stripePhase = 0
        shimmerPhase = 0
        withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
            stripePhase = 1
        }
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) {
            shimmerPhase = 1.4
        }
    }
}

// MARK: - Confetti + XP fly-up

/// Full-screen confetti burst shown briefly on award. 26 pieces,
/// staggered fall + rotation.
struct SuperchargerConfettiOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let colors: [Color] = [
        Color(hex: "FFD60A"),
        Color(hex: "FF6B35"),
        Color(hex: "B4FF3C"),
        Color(hex: "6B2BFF"),
        Color(hex: "FF3DA5"),
        Color(hex: "00E0FF"),
    ]

    var body: some View {
        // Static two-line "🎉" fallback for Reduce Motion — no burst.
        if reduceMotion {
            EmptyView()
        } else {
            GeometryReader { geo in
                ZStack {
                    ForEach(0..<26, id: \.self) { i in
                        ConfettiPiece(
                            index: i,
                            width: geo.size.width,
                            height: geo.size.height,
                            color: Self.colors[i % Self.colors.count]
                        )
                    }
                }
            }
            .allowsHitTesting(false)
            .ignoresSafeArea()
        }
    }
}

private struct ConfettiPiece: View {
    let index: Int
    let width: CGFloat
    let height: CGFloat
    let color: Color

    @State private var y: CGFloat = -60
    @State private var rot: Double = 0

    private var startX: CGFloat {
        // Deterministic-but-varied per index.
        let base = CGFloat((index * 37 + 11) % 100) / 100
        return base * width
    }
    private var duration: Double {
        1.6 + Double(index % 6) * 0.2 // 1.6…2.8
    }
    private var delay: Double {
        Double(index % 8) * 0.06
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 8, height: 13)
            .rotationEffect(.degrees(rot))
            .position(x: startX, y: y)
            .onAppear {
                y = -30
                rot = 0
                withAnimation(.linear(duration: duration).delay(delay)) {
                    y = height + 60
                    rot = 720
                }
            }
    }
}

/// Bright "+35 XP" bolt that flies up toward the header XP counter
/// after a successful award. Placed by the caller inside an overlay.
struct SuperchargerXPFlyUp: View {
    let amount: Int

    @State private var opacity: Double = 0
    @State private var offsetY: CGFloat = 0
    @State private var scale: CGFloat = 0.7

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(Color(hex: "FFD60A"))
            Text("+\(amount) XP")
                .font(.lilitaOne(size: 26))
                .foregroundStyle(Color(hex: "FFD60A"))
                .shadow(color: Color(hex: "FFD60A").opacity(0.7), radius: 12)
        }
        .opacity(opacity)
        .scaleEffect(scale)
        .offset(y: offsetY)
        .onAppear {
            // Peek in, then float up and fade.
            withAnimation(.easeOut(duration: 0.3)) {
                opacity = 1
                offsetY = -10
                scale = 1.15
            }
            withAnimation(.easeIn(duration: 1.7).delay(0.3)) {
                opacity = 0
                offsetY = -120
                scale = 0.9
            }
        }
    }
}
