//
//  SplatPalette.swift
//  YGTeeV
//
//  Locked color tokens for the Splat arena visual layer. These match
//  the working HTML prototype's design system — do not improvise new
//  values, swatch swaps, or "close enough" approximations. The whole
//  point of the gooey/wave-edge effect is that the colors carry the
//  energy; one off-hue breaks the feel.
//
//  `light` is the team's foreground paint color (used as the top of
//  the vertical gradient on the paint fill, and as the particle /
//  drip color on tap). `dark` is the deeper shade used at the bottom
//  of that gradient and as the gravity-arc end of each drip.
//
//  Background tokens (`bgPrimary`, `bgRow`, etc.) drive the arena
//  page bg, the leaderboard row chrome, and the tap-zone radial
//  gradient respectively.
//

import SwiftUI

enum SplatPalette {
    // Page chrome
    static let bgPrimary  = Color(hex: "0E0A22")
    static let bgRow      = Color(hex: "1F1840")
    static let bgZoneTop  = Color(hex: "3A1E6B")
    static let bgZoneBot  = Color(hex: "150C2D")

    /// Top-of-gradient paint color for the given team. Also the
    /// color used for tap-burst particles and drip leading edges.
    static func light(for c: SplatTeamColor) -> Color {
        switch c {
        case .orange: return Color(hex: "FFC23C")
        case .blue:   return Color(hex: "3DAEFF")
        case .pink:   return Color(hex: "FF5BD0")
        case .green:  return Color(hex: "8BE04B")
        }
    }

    /// Bottom-of-gradient shade for the team. Provides the "wet
    /// paint pooling" depth on the row fills and the trailing-edge
    /// shade on drips.
    static func dark(for c: SplatTeamColor) -> Color {
        switch c {
        case .orange: return Color(hex: "A86615")
        case .blue:   return Color(hex: "185F90")
        case .pink:   return Color(hex: "8C2A75")
        case .green:  return Color(hex: "4A7820")
        }
    }
}
