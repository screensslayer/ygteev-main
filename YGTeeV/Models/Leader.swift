//
//  Leader.swift
//  YGTeeV
//
//  Models powering the small-group-leader surface (members, attendance).
//

import Foundation

// MARK: - Attendance

struct AttendanceEvent: Identifiable, Decodable, Hashable {
    let id: UUID
    let smallGroupId: UUID
    let title: String
    let occurredAt: Date
    let notes: String?
    let createdBy: UUID?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, notes
        case smallGroupId = "small_group_id"
        case occurredAt   = "occurred_at"
        case createdBy    = "created_by"
        case createdAt    = "created_at"
        case updatedAt    = "updated_at"
    }
}

struct AttendanceRecord: Identifiable, Decodable, Hashable {
    let id: UUID
    let eventId: UUID
    let userId: UUID
    let present: Bool
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id, present, notes
        case eventId = "event_id"
        case userId  = "user_id"
    }
}

struct AttendanceEventSummary: Identifiable, Decodable, Hashable {
    var id: UUID { eventId }
    let eventId: UUID
    let smallGroupId: UUID
    let title: String
    let occurredAt: Date
    let rosterTotal: Int
    let presentCount: Int
    let absentCount: Int

    enum CodingKeys: String, CodingKey {
        case eventId      = "event_id"
        case smallGroupId = "small_group_id"
        case title
        case occurredAt   = "occurred_at"
        case rosterTotal  = "roster_total"
        case presentCount = "present_count"
        case absentCount  = "absent_count"
    }
}

/// Per-student row used by the take-roll UI. Holds the leader's in-flight
/// answer (`present` nil = un-marked) before it's saved.
struct AttendanceRosterRow: Identifiable, Hashable {
    var id: UUID { userId }
    let userId: UUID
    let displayName: String
    let avatarUrl: String?
    var present: Bool?
}

// MARK: - Small group surface

struct LeaderSmallGroup: Identifiable, Decodable, Hashable {
    let id: UUID
    let youthGroupId: UUID
    let name: String
    let description: String?
    let meetingDay: String?
    let meetingTime: String?
    /// Embedded parent-group fields (currently just logo URL) so the small-group
    /// card can render the youth-group logo without a second fetch.
    let youthGroup: YouthGroupRef?

    struct YouthGroupRef: Decodable, Hashable {
        let logoUrl: String?
        enum CodingKeys: String, CodingKey { case logoUrl = "logo_url" }
    }

    /// Convenience accessor for the parent youth group's logo URL.
    var youthGroupLogoUrl: String? { youthGroup?.logoUrl }

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case youthGroupId = "youth_group_id"
        case meetingDay   = "meeting_day"
        case meetingTime  = "meeting_time"
        case youthGroup   = "youth_group"
    }
}

struct SmallGroupMemberRow: Identifiable, Decodable, Hashable {
    let id: UUID
    let userId: UUID
    let role: String
    let displayName: String?
    let email: String?
    let avatarUrl: String?
    let bio: String?
    let lastOpenedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, role, email, bio
        case userId       = "user_id"
        case displayName  = "display_name"
        case avatarUrl    = "avatar_url"
        case lastOpenedAt = "last_opened_at"
    }
}
