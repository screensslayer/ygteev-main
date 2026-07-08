//
//  SplatPaintComponents.swift
//  YGTeeV
//
//  The "paint physics" visual layer for the Splat leaderboard.
//  Replaces the flat horizontal share bar — each team's row now
//  carries its own paint level that grows L→R with a sinusoidal
//  wave edge and spring-bumps when the team scores. The
//  `current_streak` field from the leaderboard RPC drives a small
//  flame badge for teams that have won 2+ consecutive rounds.
//
//  Pieces in this file:
//    • PaintFillShape       — custom Shape, animatable fill/phase/amp
//    • SplatLeaderboardRow  — composes bg + paint fill + content
//
//  All physics + animation is driven by a single TimelineView(.animation)
//  in the parent (SplatArenaView), which feeds `phase` to each row
//  at ~60fps. Bumps are short-lived (~0.38s) and computed locally
//  from a `bumpedAt: Date?` per row.
//

import SwiftUI

// MARK: - PaintFillShape
//
// Draws a left-anchored rectangle whose RIGHT edge is a vertical
// sine wave. As `fillPct` grows the wave rides further right.
// `phase` is a continuously incrementing value (any monotonic
// number works — caller pipes in elapsed seconds from a
// TimelineView). `amplitude` controls how big the wobble is —
// caller spikes it during a bump to add kinetic feel.
//
// `seed` makes each row's wave offset different so the four rows
// don't visibly oscillate in sync.

struct PaintFillShape: Shape {
    var fillPct: Double
    var phase: Double
    var amplitude: Double
    var seed: Double

    // Lets SwiftUI tween fillPct + phase + amplitude via .animation.
    // Phase is also externally driven each frame, so the tween is
    // mostly a safety net for fillPct changes.
    var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { .init(fillPct, .init(phase, amplitude)) }
        set {
            fillPct = newValue.first
            phase = newValue.second.first
            amplitude = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let baseX = CGFloat(fillPct) * w
        let segs = 16
        p.move(to: .init(x: 0, y: 0))
        for i in 0...segs {
            let y = CGFloat(i) / CGFloat(segs) * h
            let t = Double(i) / Double(segs)
            // Two stacked sines at slightly different frequencies +
            // a seed offset — same recipe the HTML prototype used.
            let a = sin(phase + t * 5.2 + seed) * amplitude
            let b = sin(phase * 1.4 + t * 3.1 + seed * 1.7) * (amplitude * 0.5)
            let dx = fillPct > 0 ? CGFloat(a + b) : 0
            p.addLine(to: .init(x: baseX + dx, y: y))
        }
        p.addLine(to: .init(x: 0, y: h))
        p.closeSubpath()
        return p
    }
}

// MARK: - Row

struct SplatLeaderboardRow: View {
    let team: SplatTeamRow
    let isYou: Bool
    let totalScore: Int
    let phase: Double
    let bumpedAt: Date?

    private var fillPct: Double {
        totalScore > 0 ? Double(team.score) / Double(totalScore) : 0
    }

    /// 1 → 0 over the bump's 0.38s lifetime. Clamps at 0 once past.
    private var bumpProgress: Double {
        guard let t = bumpedAt else { return 0 }
        let dt = Date().timeIntervalSince(t)
        return dt < 0.38 ? max(0, 1 - dt / 0.38) : 0
    }

    /// Wave amplitude — 4pt at rest, briefly spiked during a bump.
    /// The `cos(bumpProgress * 8)` gives the spike a wiggle decay so
    /// it feels alive rather than just "step up, step down".
    private var amplitude: Double {
        let base = fillPct > 0 ? 4.0 : 0
        let boost = bumpProgress * (5.0 * cos(bumpProgress * 8))
        return base + boost
    }

    private var seed: Double {
        Double(abs(team.color.rawValue.hashValue) % 100) * 0.07
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Row chrome — solid bg so the bumped row stays legible
            // against the page bg below.
            RoundedRectangle(cornerRadius: 14)
                .fill(SplatPalette.bgRow)

            // Paint fill. Vertical gradient (light → dark) + a
            // light blur for soft pixel edges. Re-clipped to the
            // row's rounded rect so the blur doesn't bleed into
            // neighboring rows.
            PaintFillShape(
                fillPct: fillPct,
                phase: phase,
                amplitude: amplitude,
                seed: seed
            )
            .fill(LinearGradient(
                colors: [
                    SplatPalette.light(for: team.color),
                    SplatPalette.dark(for: team.color)
                ],
                startPoint: .top,
                endPoint: .bottom
            ))
            .blur(radius: 2.4)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Text content over the paint.
            HStack(spacing: 9) {
                Text("\(team.rank)")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .frame(width: 16, alignment: .leading)

                Circle()
                    .fill(SplatPalette.light(for: team.color))
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))

                Text(team.color.teamName)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                if isYou {
                    Text("YOU")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(SplatPalette.bgPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.white))
                }

                // Streak badge — only at >= 2 consecutive wins. The
                // flame gradient is intentionally NOT a team color:
                // streak is a universal "this team is hot" tag and
                // should read identically regardless of which color
                // is streaking.
                if team.currentStreak >= 2 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text("\(team.currentStreak)")
                            .font(.system(size: 11, weight: .semibold))
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [Color(hex: "FF8A4C"), Color(hex: "FF4F1F")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    )
                    .foregroundStyle(.white)
                    .shadow(color: Color(hex: "FF4F1F").opacity(0.45), radius: 4, y: 1)
                    .accessibilityLabel("\(team.currentStreak) round win streak")
                    .transition(.scale.combined(with: .opacity))
                }

                Spacer()

                Text("\(team.score)")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                Text(String(format: "%.1f%%", team.pct))
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .monospacedDigit()
                    .frame(width: 50, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            // Spring the streak badge's appear/disappear so the
            // moment a team hits 2-in-a-row is visible kinetic
            // feedback rather than a hard pop.
            .animation(
                .spring(response: 0.4, dampingFraction: 0.6),
                value: team.currentStreak >= 2
            )
        }
        .frame(height: 54)
        .scaleEffect(1.0 + bumpProgress * 0.015)
        .offset(y: -bumpProgress * 3)
    }
}
