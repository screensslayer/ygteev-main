//
//  SplatTapZone.swift
//  YGTeeV
//
//  The gooey paint-burst tap zone for the Splat arena. Replaces the
//  static "TAP TO SPLAT" rectangle.
//
//  Visual recipe:
//    1. Radial gradient bg (deep purple top → near-black bottom).
//    2. Per-tap, the parent spawns 7–11 short-lived particles with
//       initial upward velocity + horizontal jitter.
//    3. A TimelineView(.animation) drives a SwiftUI `Canvas` that
//       redraws each frame. Inside the canvas we apply, in this
//       order: `alphaThreshold` → `blur`. GraphicsContext applies
//       filters from the top of the stack toward the source, so
//       the actual pipeline is: draws → blur (soft merging) →
//       alphaThreshold (crisp binary edges + team-color fill).
//       That's the canonical "gooey blob" trick.
//    4. Each particle's position is derived from its spawn time +
//       initial velocity + a frame-scaled gravity term. Pure
//       function of time — no per-frame state mutation needed.
//    5. A 0.5s pruning task strips dead particles from the @State
//       array so memory stays flat during a tap-storm.
//
//  Physics constants come straight from the HTML prototype so the
//  feel matches.
//

import SwiftUI

// MARK: - Tunables (visual layer only)

private enum SplatTapZoneTune {
    /// Gravity in px per frame². Frames are normalized to a 60Hz
    /// reference clock — slower devices that render at <60fps
    /// still produce the same physical trajectory because we drive
    /// off elapsed wall-clock time, not frame count.
    static let gravity: Double = 0.32
    /// Lifetime ceiling for a particle, in 60Hz frames.
    static let maxLife: Int = 60
    /// Y-coordinate past which a particle is considered "below the
    /// floor" and discarded.
    static let floorY: Double = 250
    /// Spawn count range per tap.
    static let spawnRange: ClosedRange<Int> = 7...11
    /// Filter radius for the Canvas blur (controls how aggressively
    /// nearby particles merge into one blob).
    static let blurRadius: Double = 6
}

// MARK: - Particle

struct SplatParticle: Identifiable, Equatable {
    let id = UUID()
    let spawnTime: Date
    /// Initial position (in zone-local coordinates).
    let x0: Double
    let y0: Double
    /// Initial velocity.
    let vx: Double
    let vy: Double
    /// Visual radius.
    let r: Double
    /// Frame count before the particle is removed.
    let max: Int

    /// Derived position at the given clock time. Uses ballistic
    /// motion with the per-frame gravity scaled into seconds via
    /// the 60Hz reference rate.
    func position(at now: Date) -> (x: Double, y: Double) {
        let frames = now.timeIntervalSince(spawnTime) * 60.0
        let x = x0 + vx * frames
        let y = y0 + vy * frames + 0.5 * SplatTapZoneTune.gravity * frames * frames
        return (x, y)
    }

    /// 1.0 for the first 70% of the lifetime, then fades to 0.
    func alpha(at now: Date) -> Double {
        let frames = now.timeIntervalSince(spawnTime) * 60.0
        let f = Int(frames)
        let m = max
        let holdUntil = Int(Double(m) * 0.7)
        if f < holdUntil { return 1 }
        if f >= m { return 0 }
        return 1 - Double(f - holdUntil) / max(1, Double(m - holdUntil))
    }

    func isAlive(at now: Date) -> Bool {
        let frames = now.timeIntervalSince(spawnTime) * 60.0
        if Int(frames) > max { return false }
        if position(at: now).y > SplatTapZoneTune.floorY { return false }
        return true
    }
}

// MARK: - Zone view

struct SplatTapZone: View {
    @Binding var particles: [SplatParticle]

    /// User's current team color. Used to tint the gooey goo (the
    /// alphaThreshold filter recolors all the blurred output). Nil
    /// while the server hasn't yet assigned a color (very first
    /// tap of a round) — in that window we skip the threshold so
    /// the original particle hue still shows through.
    let teamColor: SplatTeamColor?

    let onTap: (CGPoint) -> Void
    let isLocked: Bool

    var body: some View {
        ZStack {
            // Bg radial gradient — recipe from the HTML prototype.
            RoundedRectangle(cornerRadius: 18)
                .fill(RadialGradient(
                    colors: [SplatPalette.bgZoneTop, SplatPalette.bgZoneBot],
                    center: UnitPoint(x: 0.5, y: 0.3),
                    startRadius: 0,
                    endRadius: 280
                ))

            // Idle / "tap me" label. Fades way down once paint is
            // visible so it never competes with the bursts.
            Text("TAP TO SPLAT")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .tracking(2.5)
                .foregroundStyle(.white.opacity(particles.isEmpty ? 0.55 : 0.16))
                .animation(.easeInOut(duration: 0.3), value: particles.isEmpty)

            // Particle canvas. Wrapped in TimelineView(.animation)
            // so SwiftUI redraws it at the system's preferred frame
            // cadence — usually 60Hz, automatically 120Hz on ProMotion.
            TimelineView(.animation) { context in
                Canvas { gctx, size in
                    var ctx = gctx
                    // Filter pipeline (applied source → blur → threshold).
                    if let color = teamColor {
                        ctx.addFilter(.alphaThreshold(
                            min: 0.5,
                            color: SplatPalette.light(for: color)
                        ))
                    }
                    ctx.addFilter(.blur(radius: SplatTapZoneTune.blurRadius))

                    let now = context.date
                    for p in particles {
                        guard p.isAlive(at: now) else { continue }
                        let pos = p.position(at: now)
                        // Clip-bounded: don't draw particles that have
                        // drifted off the visible canvas. Saves filter
                        // work during big bursts.
                        guard pos.x > -20, pos.x < size.width + 20,
                              pos.y > -20, pos.y < size.height + 20 else { continue }
                        let rect = CGRect(
                            x: pos.x - p.r,
                            y: pos.y - p.r,
                            width: p.r * 2,
                            height: p.r * 2
                        )
                        // White fill — the alphaThreshold above
                        // recolors the post-blur pixels into the
                        // team color. If teamColor is nil we omit
                        // the threshold and the white shows through
                        // (acceptable transient state).
                        ctx.fill(
                            Path(ellipseIn: rect),
                            with: .color(.white.opacity(p.alpha(at: now)))
                        )
                    }
                }
            }
            .allowsHitTesting(false)
        }
        .frame(height: 230)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded { value in
                    guard !isLocked else { return }
                    onTap(value.location)
                }
        )
    }
}

// MARK: - Spawn helper

extension SplatTapZone {
    /// Builds a burst of 7–11 particles at the tap location. Velocity
    /// ranges match the HTML prototype: upward kick + small lateral
    /// scatter, decaying via gravity. The caller appends these to
    /// the bound particles array.
    static func spawnBurst(at location: CGPoint) -> [SplatParticle] {
        let count = Int.random(in: SplatTapZoneTune.spawnRange)
        let now = Date()
        return (0..<count).map { _ in
            SplatParticle(
                spawnTime: now,
                x0: Double(location.x),
                y0: Double(location.y),
                vx: Double.random(in: -3...3),
                vy: -Double.random(in: 2...7),
                r: Double.random(in: 7...14),
                max: SplatTapZoneTune.maxLife
            )
        }
    }
}
