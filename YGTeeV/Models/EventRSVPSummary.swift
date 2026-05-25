//
//  EventRSVPSummary.swift
//  YGTeeV
//
//  Backs the `event_rsvp_summary(_event_id)` RPC. Each event detail
//  screen fetches one of these on appear and re-fetches after the
//  viewer toggles their own RSVP.
//

import Foundation

/// One person who responded to an event. Decoded from the
/// going/maybe/declined arrays inside the summary payload.
struct EventRSVPParticipant: Identifiable, Decodable, Hashable {
    let userId: UUID
    let displayName: String?
    let handle: String?
    let avatarUrl: String?
    let rsvpAt: Date
    /// 'pastor' | 'leader' | 'member' | nil. Optional so older RPC
    /// payloads that don't yet return this column still decode.
    let role: String?
    /// 6..12 or nil for adults / "not a student".
    let gradeYear: Int?

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case userId      = "user_id"
        case displayName = "display_name"
        case handle
        case avatarUrl   = "avatar_url"
        case rsvpAt      = "rsvp_at"
        case role
        case gradeYear   = "grade_year"
    }
}

/// Whole-event view of who's coming, who's not, plus the caller's own
/// status. Defaults to zero/empty so views can render before the RPC
/// resolves.
struct EventRSVPSummary: Decodable, Hashable {
    let goingCount: Int
    let maybeCount: Int
    let declinedCount: Int
    let totalCount: Int
    let going: [EventRSVPParticipant]
    let maybe: [EventRSVPParticipant]
    let declined: [EventRSVPParticipant]
    /// 'going' | 'maybe' | 'declined' | nil (no response yet, or the
    /// caller isn't allowed to RSVP).
    let viewerStatus: String?

    enum CodingKeys: String, CodingKey {
        case goingCount     = "going_count"
        case maybeCount     = "maybe_count"
        case declinedCount  = "declined_count"
        case totalCount     = "total_count"
        case going, maybe, declined
        case viewerStatus   = "viewer_status"
    }

    static let empty = EventRSVPSummary(
        goingCount: 0, maybeCount: 0, declinedCount: 0, totalCount: 0,
        going: [], maybe: [], declined: [],
        viewerStatus: nil
    )
}
