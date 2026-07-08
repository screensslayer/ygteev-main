//
//  DiscoveredMapPin.swift
//  YGTeeV
//
//  Map pin for "discovered" placeholder youth groups (rows in
//  `discovered_youth_groups` that haven't been claimed yet).
//
//  Two visual branches:
//    • `pin.logoUrl != nil` — render the scraped logo as a clean
//      circular avatar pin. No pie chrome; the logo IS the identity.
//    • `pin.logoUrl == nil`  — render the 6-section `BoostPiePin`.
//      Each filled wedge = 10 boosts; every 60 boosts the pin levels
//      up + the heat-ramp color advances. L1 (blue) → L7 (magenta).
//
//  Both branches get the small violet "+" badge in the corner — the
//  unclaimed signal — and both grow size with `state.level` so a
//  high-boost placeholder reads larger on the map regardless of
//  which branch renders it.
//
//  All level/section math is pure client derivation from
//  `pin.boostCount`. No backend state for tier.
//

import SwiftUI

// MARK: - Tier types
//
// Top-level so callers (and previews / tests) can pull a state /
// palette swatch without instantiating a view.

struct PieState: Equatable {
    let level: Int          // 1...7
    let filledSections: Int // 0...6
}

struct PieTier {
    let core: Color
    let rim: Color
}

// MARK: - Pin entry point

struct DiscoveredMapPin: View {
    let pin: DiscoveredYouthGroup

    /// Pin diameter grows with the boost-derived level. 44pt at L1,
    /// 68pt at L7 — same scale for both the pie branch and the
    /// logo-avatar branch so they read at a consistent visual weight
    /// across the map.
    private var state: PieState {
        BoostPiePin.pieState(boostCount: pin.boostCount)
    }
    private var scaledDiameter: CGFloat {
        44 + CGFloat(state.level - 1) * 4
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            innerPin
                .frame(width: scaledDiameter, height: scaledDiameter)

            plusBadge
                .offset(x: 5, y: -5)
        }
    }

    @ViewBuilder
    private var innerPin: some View {
        if let url = pin.logoUrl {
            logoAvatarPin(url: url)
        } else {
            BoostPiePin(boostCount: pin.boostCount)
        }
    }

    /// Branch for placeholders that already carry a scraped logo —
    /// the logo is the identity, no pie chrome needed. Drop shadow +
    /// white ring so it reads as a pin against the basemap.
    private func logoAvatarPin(url: URL) -> some View {
        CachedRemoteImage(url: url) {
            // Solid fallback in the same dark slate the empty pie
            // uses, so the placeholder skeleton matches the pie's
            // visual language while the image loads.
            Circle().fill(BoostPiePin.pieEmptyFill)
        }
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
        .shadow(color: .black.opacity(0.35), radius: 5, y: 2)
    }

    /// Unclaimed signal. Sits half on / half off the top-right of
    /// the pin regardless of which inner branch renders.
    private var plusBadge: some View {
        ZStack {
            Circle().fill(YGColors.violet)
            Image(systemName: "plus")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 16, height: 16)
        .overlay(Circle().strokeBorder(.white, lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
    }
}

// MARK: - BoostPiePin
//
// 6-wedge pie that fills clockwise from 12 o'clock as boosts come
// in. One wedge per 10 boosts. At 60, all 6 wedges are full, the
// level advances, and the next wedge that lights up uses the next
// tier's color. After level 7 (the max) the pie stays full + the
// color is locked at magenta — boost growth from there is purely
// off the pin via `scaledDiameter`.

struct BoostPiePin: View {
    let boostCount: Int

    // MARK: Palette (frozen)
    //
    // Single source of truth for the heat-ramp colors. Other surfaces
    // (detail sheet, etc.) can read these without re-declaring.

    static let pieEmptyFill = Color(hex: "1F1840")

    static let pieTiers: [PieTier] = [
        .init(core: Color(hex: "3DAEFF"), rim: Color(hex: "185F90")), // L1 blue
        .init(core: Color(hex: "1FD4C7"), rim: Color(hex: "0A7770")), // L2 teal
        .init(core: Color(hex: "8BE04B"), rim: Color(hex: "4A7820")), // L3 green
        .init(core: Color(hex: "FFC23C"), rim: Color(hex: "A86615")), // L4 amber
        .init(core: Color(hex: "FF8A4C"), rim: Color(hex: "A8431C")), // L5 orange
        .init(core: Color(hex: "FF4F1F"), rim: Color(hex: "931E0A")), // L6 red
        .init(core: Color(hex: "C71F8B"), rim: Color(hex: "65114A"))  // L7 magenta
    ]

    /// Pure derivation: which tier the pin is on + how many of its
    /// 6 wedges are lit.
    ///
    /// Reference points (from the spec): 0→L1·0, 10→L1·1, 50→L1·5,
    /// 60→L2·0, 359→L6·5, 360→L7·0, 420→L7·6, 1000→L7·6.
    static func pieState(boostCount: Int) -> PieState {
        let safe = max(0, boostCount)
        let advances = min(6, safe / 60)
        let level = 1 + advances
        let sections: Int = {
            if level < 7 {
                return (safe % 60) / 10
            }
            // L7 fills its own 6 wedges over boosts 360...420, then
            // stays pinned for any further growth.
            return min(6, (safe - 360) / 10)
        }()
        return PieState(level: level, filledSections: sections)
    }

    private var state: PieState { Self.pieState(boostCount: boostCount) }
    private var tier: PieTier { Self.pieTiers[state.level - 1] }

    var body: some View {
        GeometryReader { geo in
            // Spoke height = radius. Pulled from the actual rendered
            // size so the dividers reach the edge regardless of the
            // parent's `scaledDiameter`.
            let radius = min(geo.size.width, geo.size.height) / 2
            ZStack {
                // Empty disc + tier rim
                Circle()
                    .fill(Self.pieEmptyFill)
                    .overlay(Circle().strokeBorder(tier.rim, lineWidth: 2))

                // Lit wedges (clockwise from 12 o'clock)
                ForEach(0..<state.filledSections, id: \.self) { i in
                    WedgeShape(index: i)
                        .fill(tier.core)
                        .transition(.scale.combined(with: .opacity))
                }

                // Spoke dividers — six 1pt black bars at 60° offsets
                // to keep wedge edges crisp against the lit core
                // color. Drawn after the wedges so they sit on top.
                ForEach(0..<6, id: \.self) { i in
                    Rectangle()
                        .fill(Color.black.opacity(0.18))
                        .frame(width: 1, height: radius)
                        .offset(y: -radius / 2)
                        .rotationEffect(.degrees(Double(i) * 60))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: state.filledSections)
        .animation(.easeInOut(duration: 0.5), value: state.level)
    }
}

// MARK: - Wedge

/// One slice of the 6-wedge pie. `index` 0 = 12 o'clock, advancing
/// clockwise. The shape is closed (center + arc + back to center)
/// so SwiftUI can fill it with a solid color.
private struct WedgeShape: Shape {
    let index: Int
    let total: Int = 6

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let deg = 360.0 / Double(total)
        let start = -90.0 + Double(index) * deg
        var p = Path()
        p.move(to: center)
        p.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(start),
            endAngle: .degrees(start + deg),
            clockwise: false
        )
        p.closeSubpath()
        return p
    }
}
