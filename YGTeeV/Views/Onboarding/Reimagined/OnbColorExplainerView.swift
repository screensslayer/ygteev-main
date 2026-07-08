//
//  OnbColorExplainerView.swift
//  YGTeeV
//
//  M12 — pre-reveal card. Sets the stakes before the color drop:
//  random, for life, ride or die. Hands the user the trigger
//  ("Reveal my color") so *they* pull it and own the outcome — a
//  reveal only hits if the stakes are set first.
//
//  Beat sheet from design HTML Moment 10 stage 11a:
//    • Dark bg with a lime radial glow from the bottom.
//    • Overline "ONE THING LEFT" in lime green.
//    • Title "The color picks you." — "you" italic.
//    • A slowly spinning rainbow conic ring wraps a black disc with a
//      big "?" glyph. This is what turns into the team-color ring
//      after the reveal.
//    • Four color dots (Blue / Pink / Green / Orange) with labels.
//    • Body copy about the mechanic.
//    • Three chips: 🎲 Random / ♾️ For life / 🚫 No undo.
//    • Violet→pink CTA "✦ Reveal my color".
//    • Footer "Ready? There's no take-backs."
//

import SwiftUI

struct OnbColorExplainerView: View {
    let state: ReimaginedOnboardingState
    let advance: () -> Void

    /// Drives the continuous slow spin of the rainbow ring. Anchored
    /// to a fixed date so re-renders don't reset the angle.
    @State private var startDate: Date = .now

    var body: some View {
        ZStack {
            // Deep-ink base + radial lime glow rising from below.
            // Matches the design HTML's:
            //   radial-gradient(ellipse at 50% 118%,
            //     rgba(139,224,75,.28), transparent 60%),
            //   #0A0712
            Color(hex: "0A0712").ignoresSafeArea()

            RadialGradient(
                colors: [YGColors.lime.opacity(0.28), .clear],
                center: UnitPoint(x: 0.5, y: 1.18),
                startRadius: 0,
                endRadius: 500
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Overline + title
                VStack(spacing: 10) {
                    Text("ONE THING LEFT")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(2.0)
                        .foregroundStyle(YGColors.lime)

                    // "The color picks you." — the "you" is italic
                    // per the design mock. Text interpolation with an
                    // inner italic Text preserves the mixed weight
                    // without falling back to Text `+` concatenation.
                    Text("The color\npicks \(Text("you.").italic())")
                        .font(.lilitaOne(size: 32))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 50)

                // Mystery wheel — rainbow conic ring around a dark
                // disc with a big "?" glyph.
                TimelineView(.animation) { context in
                    let elapsed = context.date.timeIntervalSince(startDate)
                    // 3.2 s per full rotation, matching the CSS
                    // `animation: yg-spin 3.2s linear infinite`.
                    let angle = Angle.degrees((elapsed / 3.2) * 360.0)

                    ZStack {
                        Circle()
                            .fill(
                                AngularGradient(
                                    colors: [
                                        Color(hex: "3DAEFF"),
                                        Color(hex: "FF5BD0"),
                                        Color(hex: "FFC23C"),
                                        Color(hex: "8BE04B"),
                                        Color(hex: "3DAEFF")
                                    ],
                                    center: .center
                                )
                            )
                            .frame(width: 160, height: 160)
                            .rotationEffect(angle)
                            .shadow(color: YGColors.lime.opacity(0.35), radius: 20)

                        // Dark inner disc + gradient "?" glyph.
                        Circle()
                            .fill(Color(hex: "0A0712"))
                            .frame(width: 136, height: 136)

                        Text("?")
                            .font(.lilitaOne(size: 68))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, YGColors.lime],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
                .frame(width: 160, height: 160)
                .padding(.top, 24)

                // Four team dots
                HStack(spacing: 18) {
                    teamDot(color: Color(hex: "3DAEFF"), label: "Blue")
                    teamDot(color: Color(hex: "FF5BD0"), label: "Pink")
                    teamDot(color: Color(hex: "8BE04B"), label: "Green")
                    teamDot(color: Color(hex: "FFC23C"), label: "Orange")
                }
                .padding(.top, 20)

                // Body copy about the mechanic.
                Text("You'll be \(Text("randomly dropped").fontWeight(.heavy)) onto one of four Splat teams. Assigned once, at random — and it's \(Text("yours for life").fontWeight(.heavy)). Ride or die. Every verse you read pours XP into your team's score.")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 26)
                    .padding(.top, 18)

                // Three chips
                HStack(spacing: 8) {
                    chip("🎲", "Random")
                    chip("♾️", "For life")
                    chip("🚫", "No undo")
                }
                .padding(.top, 18)

                Spacer(minLength: 0)

                // Primary CTA — violet→pink gradient pill.
                Button(action: advance) {
                    Text("✦ Reveal my color")
                        .font(.lilitaOne(size: 18))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(YGColors.violetPinkGradient)
                        .clipShape(Capsule())
                        .shadow(color: YGColors.violet.opacity(0.45), radius: 24, y: 12)
                }
                .padding(.horizontal, 22)

                Text("Ready? There's no take-backs.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 11)
                    .padding(.bottom, 34)
            }
        }
        .statusBarHidden(true)
    }

    // MARK: - Small pieces

    private func teamDot(color: Color, label: String) -> some View {
        VStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 26, height: 26)
                .shadow(color: color.opacity(0.5), radius: 8)
            Text(label)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private func chip(_ emoji: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(emoji).font(.system(size: 11))
            Text(label)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.08))
        .overlay(
            Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 0.5)
        )
        .clipShape(Capsule())
    }
}
