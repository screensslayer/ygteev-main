//
//  OnbColorRevealView.swift
//  YGTeeV
//
//  M13-M14 — the emotional centerpiece of the reimagined onboarding.
//  Full-bleed, no chrome, no back / skip. The whole animation is a
//  single TimelineView(.animation) driving a normalized progress
//  value (0…1) across a fixed 2.6-second duration, with each layer
//  computing its own opacity / scale / translation as piecewise
//  curves of that progress.
//
//  Beat sheet ported one-to-one from the design HTML's Moment 10
//  stage 11b keyframes:
//
//    Progress    Timing     Layer           Behavior
//    ────────────────────────────────────────────────────────────
//    0.00-0.27  0.0-0.7s   TENSION HOLD     "Your color is…" label
//                                            + charge glow pulses +
//                                            avatar rainbow ring
//                                            spinning. Haptic warn.
//    0.27-0.54  0.7-1.4s   THE DROP         Bloom bursts from
//                                            center. Shockwave rings
//                                            outward. Splat blobs
//                                            splash. Heavy haptic.
//    0.54-0.69  1.4-1.8s   REVEAL           Avatar ring floods
//                                            rainbow → team color.
//                                            "GREEN" slams in with
//                                            overshoot.
//    0.69-1.0   1.8-2.6s   STAKE            Tier + copy rise from
//                                            below. Standings slide
//                                            in, team bar animates
//                                            up + glows.
//
//  Once past 2.6s the CTA is fully in and the user can tap to
//  advance. The animation freezes on the final frame — no loop.
//

import SwiftUI
import UIKit

struct OnbColorRevealView: View {
    let state: ReimaginedOnboardingState
    let advance: () -> Void

    /// Fallback when the auth screen hasn't wired `revealedSplatColor`
    /// yet (e.g. running the flow via debug reset). Keeps the reveal
    /// meaningful during dev walkthroughs.
    private var color: SplatTeamColor {
        state.revealedSplatColor ?? .green
    }

    /// The user's initial, drawn on the avatar chip that transitions
    /// from rainbow → team color.
    private var initial: String {
        let name = state.displayName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "?" : String(name.prefix(1)).uppercased()
    }

    /// Total animation length. All keyframe percentages are relative
    /// to this. Design HTML calls out ~2.6s as the target beat.
    private let duration: Double = 2.6

    /// Fixed at first render so the animation can compute elapsed
    /// time via TimelineView without state churn.
    @State private var startDate: Date = .now
    /// Latch so we only fire each haptic once, no matter how many
    /// times the TimelineView ticks past its threshold.
    @State private var didWarnHaptic = false
    @State private var didImpactHaptic = false

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSince(startDate)
            let t = min(max(elapsed / duration, 0), 1.0)

            // Trigger haptics on the same clock the visuals are on so
            // they land in sync. Guarded by the two latches above so
            // extra ticks don't re-fire them.
            _ = fireHaptics(t: t)

            ZStack {
                // Base black — everything else composites on top.
                Color(hex: "0A0712").ignoresSafeArea()

                // Bloom disc — the color flood. Radial gradient in
                // the team color that scales from a point to full-
                // bleed. Starts at t=0.27 (0.7s).
                bloomDisc(t: t)

                // Shockwave ring — expands + fades between t=0.27
                // and t=0.44.
                shockRing(t: t)

                // Splat blobs — organic shards, land ~t=0.30-0.54.
                splatBlobs(t: t)

                // "Your color is…" label — fades in immediately,
                // out at t=0.54.
                topLabel(t: t)

                // Avatar with rainbow → team color ring transition.
                // The initial anchors identity on the reveal.
                avatar(t: t)

                // Team name — slams in at t=0.54 with an overshoot.
                slamText(t: t)

                // Tier line "You're a Sprout 🌱" + body copy — rise
                // from below starting t=0.69.
                identityStack(t: t)

                // Splat standings — slide in from below t=0.77.
                standingsCard(t: t)

                // CTA "Rep the {color} →" — rises last at t=0.85.
                cta(t: t)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
    }

    // MARK: - Layers

    /// Bloom disc that floods the screen in the team color.
    /// Scales from a point at t=0.27 to full-bleed by t=0.54, then
    /// holds. Behind everything except the base black.
    private func bloomDisc(t: Double) -> some View {
        let scale = piecewise(t, [
            (0.0, 0.0), (0.27, 0.0), (0.54, 1.0), (1.0, 1.0)
        ])
        let opacity = piecewise(t, [
            (0.0, 0.0), (0.27, 0.4), (0.44, 1.0), (1.0, 1.0)
        ])
        return Circle()
            .fill(
                RadialGradient(
                    colors: [
                        SplatPalette.light(for: color),
                        Color(red: SplatPalette.light(for: color).components.r * 0.55,
                              green: SplatPalette.light(for: color).components.g * 0.55,
                              blue: SplatPalette.light(for: color).components.b * 0.55),
                        SplatPalette.dark(for: color),
                        Color(hex: "0A0712")
                    ],
                    center: UnitPoint(x: 0.5, y: 0.35),
                    startRadius: 0,
                    endRadius: 600
                )
            )
            .frame(width: 1200, height: 1200)
            .scaleEffect(scale)
            .opacity(opacity)
    }

    /// Shockwave ring — thin bright ring bursting outward at splat
    /// moment. One-shot: expands + fades between t=0.27 and t=0.44.
    private func shockRing(t: Double) -> some View {
        let opacity = piecewise(t, [
            (0.0, 0.0), (0.27, 0.0), (0.30, 0.9), (0.44, 0.0), (1.0, 0.0)
        ])
        let scale = piecewise(t, [
            (0.0, 0.2), (0.27, 0.2), (0.44, 2.6), (1.0, 2.6)
        ])
        return Circle()
            .stroke(SplatPalette.tint(for: color), lineWidth: 3.5)
            .frame(width: 220, height: 220)
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(y: -60)
    }

    /// Five splat blobs arranged around the reveal zone. They fire
    /// with a rotation offset each so they feel hand-thrown.
    private func splatBlobs(t: Double) -> some View {
        let scale = piecewise(t, [
            (0.0, 0.0), (0.27, 0.0), (0.40, 1.2), (0.54, 1.0), (1.0, 1.0)
        ])
        let opacity = piecewise(t, [
            (0.0, 0.0), (0.27, 0.0), (0.40, 0.95), (0.54, 0.82), (1.0, 0.82)
        ])
        return ZStack {
            splatBlob(offset: CGSize(width: -130, height: -240), size: 60, rotate: -12)
            splatBlob(offset: CGSize(width:  140, height: -180), size: 44, rotate:   8)
            splatBlob(offset: CGSize(width: -160, height:  200), size: 34, rotate:   0)
            splatBlob(offset: CGSize(width:  120, height:  240), size: 38, rotate:  20)
            splatBlob(offset: CGSize(width:  180, height:  -60), size: 24, rotate: -30)
        }
        .scaleEffect(scale)
        .opacity(opacity)
    }

    private func splatBlob(offset: CGSize, size: CGFloat, rotate: Double) -> some View {
        Circle()
            .fill(SplatPalette.tint(for: color))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotate))
            .offset(offset)
    }

    /// "Your color is…" pre-drop label. In from t=0.04, out at 0.54.
    private func topLabel(t: Double) -> some View {
        let opacity = piecewise(t, [
            (0.0, 0.0), (0.04, 0.0), (0.10, 0.9), (0.44, 0.9), (0.54, 0.0), (1.0, 0.0)
        ])
        return Text("YOUR COLOR IS…")
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .tracking(2.0)
            .foregroundStyle(.white)
            .opacity(opacity)
            .offset(y: -280)
    }

    /// Avatar with a rainbow conic ring that floods to solid team
    /// color between t=0.54 and t=0.69. The initial anchors the
    /// user's identity to the color.
    private func avatar(t: Double) -> some View {
        let chargeOpacity = piecewise(t, [
            (0.0, 0.0), (0.04, 0.55), (0.20, 1.0), (0.27, 0.55), (0.30, 0.0), (1.0, 0.0)
        ])
        let chargeScale = piecewise(t, [
            (0.0, 1.0), (0.20, 1.22), (0.27, 1.0), (1.0, 1.0)
        ])
        // Ring flood — the rainbow ring gets covered by a team-color
        // fill starting at t=0.54.
        let ringFloodOpacity = piecewise(t, [
            (0.0, 0.0), (0.54, 0.0), (0.62, 1.0), (1.0, 1.0)
        ])
        // Whole avatar scale — small bounce at reveal.
        let avatarScale = piecewise(t, [
            (0.0, 0.9), (0.20, 1.0), (0.54, 1.0), (0.60, 1.1), (0.65, 1.0), (1.0, 1.0)
        ])

        return ZStack {
            // Charge glow pulsing before the drop.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [SplatPalette.tint(for: color).opacity(0.6), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 130
                    )
                )
                .frame(width: 220, height: 220)
                .scaleEffect(chargeScale)
                .opacity(chargeOpacity)

            // Outer rainbow ring — visible throughout, gets painted
            // over by the team-color ring after the drop.
            Circle()
                .fill(YGColors.rainbowRingGradient)
                .frame(width: 150, height: 150)

            // Team-color ring — fades in over the rainbow at reveal.
            Circle()
                .fill(SplatPalette.light(for: color))
                .frame(width: 150, height: 150)
                .opacity(ringFloodOpacity)

            // White collar between ring and initial disc.
            Circle()
                .fill(.white)
                .frame(width: 120, height: 120)

            // Initial disc — the user's letter on a violet→pink
            // brand gradient (team-neutral, matching the design HTML
            // which keeps the identity chip a brand color even after
            // the ring flips to the team hue).
            Circle()
                .fill(YGColors.violetPinkGradient)
                .frame(width: 108, height: 108)

            Text(initial)
                .font(.lilitaOne(size: 54))
                .foregroundStyle(.white)
        }
        .scaleEffect(avatarScale)
        .offset(y: -140)
    }

    /// Team-name slam text with vertical tint-to-light gradient.
    /// Enters at t=0.54 blurred + oversized, snaps to 0.9→1.05→1.
    private func slamText(t: Double) -> some View {
        let opacity = piecewise(t, [
            (0.0, 0.0), (0.54, 0.0), (0.60, 1.0), (1.0, 1.0)
        ])
        let scale = piecewise(t, [
            (0.0, 2.6), (0.54, 2.6), (0.60, 0.9), (0.65, 1.06), (0.69, 1.0), (1.0, 1.0)
        ])
        let blur = piecewise(t, [
            (0.0, 12.0), (0.54, 12.0), (0.60, 0.0), (1.0, 0.0)
        ])
        return Text(color.teamName.uppercased())
            .font(.lilitaOne(size: 82))
            .tracking(-2.5)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        SplatPalette.tint(for: color),
                        SplatPalette.light(for: color)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: SplatPalette.light(for: color).opacity(0.5),
                    radius: 30, y: 6)
            .scaleEffect(scale)
            .opacity(opacity)
            .blur(radius: blur)
            .offset(y: 20)
    }

    /// "You're a Sprout 🌱" tier line + body copy — rise from below
    /// after the slam settles.
    private func identityStack(t: Double) -> some View {
        let opacity = piecewise(t, [
            (0.0, 0.0), (0.69, 0.0), (0.80, 1.0), (1.0, 1.0)
        ])
        let translateY = piecewise(t, [
            (0.0, 20.0), (0.69, 20.0), (0.80, 0.0), (1.0, 0.0)
        ])
        return VStack(spacing: 12) {
            Text("You're a \(Text("Sprout").fontWeight(.heavy)) 🌱")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            Text("Every YGTeeV reader reps one of four teams — for life. \(color.teamName.capitalized)'s your family now.")
                .font(.system(size: 13.5))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .opacity(opacity)
        .offset(y: 120 + translateY)
    }

    /// Splat standings mini-chart — slides in and the user's team
    /// bar animates height + glow to "have a stake" already.
    private func standingsCard(t: Double) -> some View {
        let opacity = piecewise(t, [
            (0.0, 0.0), (0.77, 0.0), (0.88, 1.0), (1.0, 1.0)
        ])
        let translateY = piecewise(t, [
            (0.0, 30.0), (0.77, 30.0), (0.88, 0.0), (1.0, 0.0)
        ])
        // Team-bar heights, matching the design HTML's mock: 30 / 38
        // / 22 / 26 px. The user's team gets the tallest bar (38),
        // remapped based on which color they landed on.
        let heights = barHeights(for: color)

        return VStack(spacing: 0) {
            HStack {
                Text("SPLAT STANDINGS")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
                Text("THIS WEEK")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(.bottom, 10)

            HStack(alignment: .bottom, spacing: 7) {
                bar(team: .blue,   height: heights.blue,   t: t)
                bar(team: .pink,   height: heights.pink,   t: t)
                bar(team: .green,  height: heights.green,  t: t)
                bar(team: .orange, height: heights.orange, t: t)
            }
            .frame(height: 60)
        }
        .padding(14)
        .background(Color(hex: "0A0712").opacity(0.4))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
        )
        .background(.ultraThinMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: 18))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal, 22)
        .opacity(opacity)
        .offset(y: 260 + translateY)
    }

    private func bar(team: SplatTeamColor, height: CGFloat, t: Double) -> some View {
        // Bars grow up from t=0.77 → 0.95. The user's team gets an
        // extra glow.
        let barScale = piecewise(t, [
            (0.0, 0.0), (0.77, 0.0), (0.95, 1.0), (1.0, 1.0)
        ])
        let isMe = team == color
        return VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 5)
                .fill(SplatPalette.light(for: team))
                .frame(height: height)
                .opacity(isMe ? 1.0 : 0.85)
                .shadow(
                    color: isMe ? SplatPalette.light(for: team).opacity(0.7) : .clear,
                    radius: isMe ? 12 : 0
                )
                .scaleEffect(x: 1, y: barScale, anchor: .bottom)
            Text(team.teamName.capitalized)
                .font(.system(size: 9, weight: isMe ? .heavy : .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(isMe ? 1.0 : 0.7))
        }
        .frame(maxWidth: .infinity)
    }

    /// "Rep the {color} →" CTA — rises last, at t=0.85.
    private func cta(t: Double) -> some View {
        let opacity = piecewise(t, [
            (0.0, 0.0), (0.85, 0.0), (0.96, 1.0), (1.0, 1.0)
        ])
        let translateY = piecewise(t, [
            (0.0, 20.0), (0.85, 20.0), (0.96, 0.0), (1.0, 0.0)
        ])

        return VStack {
            Spacer()
            Button(action: advance) {
                Text("Rep the \(color.teamName.lowercased()) →")
                    .font(.lilitaOne(size: 20))
                    .foregroundStyle(Color(hex: "0A0712"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [
                                SplatPalette.tint(for: color),
                                SplatPalette.light(for: color)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: SplatPalette.light(for: color).opacity(0.5),
                            radius: 20, y: 8)
            }
            .disabled(opacity < 0.9)
            .padding(.horizontal, 24)
            .padding(.bottom, 60)
            .opacity(opacity)
            .offset(y: translateY)
        }
    }

    // MARK: - Haptics
    //
    // Fired inline from the TimelineView body once per threshold —
    // the latches prevent extra fires as the clock ticks past. The
    // warning buzz precedes the drop; the heavy impact punctuates
    // the paint burst itself.

    private func fireHaptics(t: Double) -> Bool {
        if !didWarnHaptic && t >= 0.02 {
            DispatchQueue.main.async {
                didWarnHaptic = true
                let gen = UINotificationFeedbackGenerator()
                gen.prepare()
                gen.notificationOccurred(.warning)
            }
        }
        if !didImpactHaptic && t >= 0.28 {
            DispatchQueue.main.async {
                didImpactHaptic = true
                let gen = UIImpactFeedbackGenerator(style: .heavy)
                gen.prepare()
                gen.impactOccurred()
            }
        }
        return true
    }

    // MARK: - Piecewise interpolation

    /// Linear interpolation across a set of `(progress, value)`
    /// keyframes. `progress` values must be sorted ascending; `t`
    /// must be in [0, 1]. Returns the interpolated value.
    private func piecewise(_ t: Double, _ stops: [(Double, Double)]) -> Double {
        guard let first = stops.first else { return 0 }
        if t <= first.0 { return first.1 }
        for i in 1..<stops.count {
            let (p0, v0) = stops[i - 1]
            let (p1, v1) = stops[i]
            if t <= p1 {
                let frac = (t - p0) / max(0.0001, p1 - p0)
                return v0 + (v1 - v0) * frac
            }
        }
        return stops.last?.1 ?? 0
    }

    /// Overload with CGFloat return so callers can pass sizes.
    private func piecewise(_ t: Double, _ stops: [(Double, Double)]) -> CGFloat {
        let v: Double = piecewise(t, stops)
        return CGFloat(v)
    }

    // MARK: - Standings heights

    /// Bar heights per team. The user's team always gets the tallest
    /// bar so the reveal instantly gives them a stake.
    private func barHeights(for winner: SplatTeamColor)
        -> (blue: CGFloat, pink: CGFloat, green: CGFloat, orange: CGFloat)
    {
        switch winner {
        case .blue:   return (blue: 44, pink: 26, green: 34, orange: 22)
        case .pink:   return (blue: 30, pink: 44, green: 26, orange: 36)
        case .green:  return (blue: 30, pink: 22, green: 44, orange: 26)
        case .orange: return (blue: 28, pink: 34, green: 22, orange: 44)
        }
    }
}

// MARK: - Color component extraction
//
// SwiftUI doesn't expose sRGB channels off `Color` directly, so we
// pull them via a UIColor bridge. Used only for the bloom disc's
// midpoint darkening stop.

private extension Color {
    struct RGB { let r: Double; let g: Double; let b: Double }
    var components: RGB {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return RGB(r: Double(r), g: Double(g), b: Double(b))
    }
}
