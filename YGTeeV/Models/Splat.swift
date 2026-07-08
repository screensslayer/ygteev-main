//
//  Splat.swift
//  YGTeeV
//
//  Wire models for the daily YGTeeV Splat melee. The backend exposes
//  three SECURITY DEFINER RPCs:
//
//    splat_current_round()  -> { round_id, round_starts_at, round_ends_at,
//                                your_color, your_xp }
//    splat_leaderboard()    -> [{ color, score, pct, rank }]
//    splat_record_taps(_n)  -> { taps_recorded, xp_spent, remaining_xp,
//                                your_color, your_team_score }
//
//  We never compute round timing, color, or scores client-side — the
//  server is the source of truth. The local UI only reads what these
//  payloads return and renders.
//

import SwiftUI

// MARK: - Team colors

/// The four melee teams. Locked palette — kept in lock-step with the
/// server's `splat_team_color` enum so that decoding a row never falls
/// through to a default. Add a case here only after adding it to the
/// DB enum first.
enum SplatTeamColor: String, Codable, Hashable, CaseIterable, Identifiable {
    case blue
    case pink
    case green
    case orange

    var id: String { rawValue }

    /// Display swatch. Hex values match the Splat design tokens
    /// (`brand.css`) so the iOS arena reads identically to the web
    /// prototypes in `/Downloads/Splat`.
    var color: Color {
        switch self {
        case .blue:   return Color(hex: "3DAEFF")
        case .pink:   return Color(hex: "FF5BD0")
        case .green:  return Color(hex: "8BE04B")
        case .orange: return Color(hex: "FFC23C")
        }
    }

    /// Human-facing team label rendered in the leaderboard rows + the
    /// end-of-round overlay. Capitalised at the call site as needed.
    var teamName: String {
        switch self {
        case .blue:   return "Blue"
        case .pink:   return "Pink"
        case .green:  return "Green"
        case .orange: return "Orange"
        }
    }
}

// MARK: - Current round

/// Snapshot of the active round + the caller's wallet position within
/// it. `yourColor` is nil until the user takes their first tap of the
/// round (server assigns it at first-tap time). `yourXp` mirrors
/// `profiles.xp` at fetch time — we re-read it after every batched
/// flush so the wallet bar stays truthful.
struct SplatCurrentRound: Decodable, Hashable {
    let roundId: UUID
    let roundStartsAt: Date
    let roundEndsAt: Date
    let yourColor: SplatTeamColor?
    let yourXp: Int?

    enum CodingKeys: String, CodingKey {
        case roundId       = "round_id"
        case roundStartsAt = "round_starts_at"
        case roundEndsAt   = "round_ends_at"
        case yourColor     = "your_color"
        case yourXp        = "your_xp"
    }
}

// MARK: - Leaderboard

/// One row of the live leaderboard. `pct` is already normalised
/// server-side (0…1) — multiply for percent-display. `rank` starts at
/// 1 (highest score). Identified by color so SwiftUI diffing is stable
/// across re-orders.
struct SplatTeamRow: Decodable, Identifiable, Hashable {
    let color: SplatTeamColor
    let score: Int
    let pct: Double
    let rank: Int

    var id: SplatTeamColor { color }
}

// MARK: - Tap result

/// Echoed back by `splat_record_taps(_n)`. `tapsRecorded` may be less
/// than what the client sent if the wallet ran dry partway through —
/// the client reconciles its optimistic state against this value.
/// `yourTeamScore` is the authoritative per-team score post-flush, so
/// the segmented bar can correct any drift from the simulated local
/// bump.
struct SplatTapResult: Decodable, Hashable {
    let tapsRecorded: Int
    let xpSpent: Int
    let remainingXp: Int
    let yourColor: SplatTeamColor
    let yourTeamScore: Int

    enum CodingKeys: String, CodingKey {
        case tapsRecorded   = "taps_recorded"
        case xpSpent        = "xp_spent"
        case remainingXp    = "remaining_xp"
        case yourColor      = "your_color"
        case yourTeamScore  = "your_team_score"
    }
}
