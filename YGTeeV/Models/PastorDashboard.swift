//
//  PastorDashboard.swift
//  YGTeeV
//
//  Codable shapes for the pastor-side surfaces, matching the RPCs:
//  pastor_dashboard, pastor_recent_activity, pastor_list_join_requests,
//  pastor_list_group_members, pastor_list_small_groups.
//
//  Fields are decoded defensively — schema additions on the server
//  shouldn't crash the UI just because an optional column is missing.
//

import Foundation

// MARK: - Dashboard snapshot

struct PastorDashboardSnapshot: Decodable, Hashable {
    let groupId: UUID
    let groupName: String
    let logoURL: String?
    let memberCount: Int
    let smallGroupCount: Int
    let pendingRequestCount: Int
    let activeThisWeek: Int
    let activeLastWeek: Int
    let activeThisWeekPct: Int
    let activeLastWeekPct: Int
    let totalGroupXP: Int64
    let totalGroupWater: Int64

    enum CodingKeys: String, CodingKey {
        case groupId             = "group_id"
        case groupName           = "group_name"
        case logoURL             = "logo_url"
        case memberCount         = "member_count"
        case smallGroupCount     = "small_group_count"
        case pendingRequestCount = "pending_request_count"
        case activeThisWeek      = "active_this_week"
        case activeLastWeek      = "active_last_week"
        case activeThisWeekPct   = "active_this_week_pct"
        case activeLastWeekPct   = "active_last_week_pct"
        case totalGroupXP        = "total_group_xp"
        case totalGroupWater     = "total_group_water"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.groupId             = try c.decode(UUID.self, forKey: .groupId)
        self.groupName           = (try? c.decode(String.self, forKey: .groupName)) ?? "Youth group"
        self.logoURL             = try? c.decode(String.self, forKey: .logoURL)
        self.memberCount         = (try? c.decode(Int.self, forKey: .memberCount)) ?? 0
        self.smallGroupCount     = (try? c.decode(Int.self, forKey: .smallGroupCount)) ?? 0
        self.pendingRequestCount = (try? c.decode(Int.self, forKey: .pendingRequestCount)) ?? 0
        self.activeThisWeek      = (try? c.decode(Int.self, forKey: .activeThisWeek)) ?? 0
        self.activeLastWeek      = (try? c.decode(Int.self, forKey: .activeLastWeek)) ?? 0
        self.activeThisWeekPct   = (try? c.decode(Int.self, forKey: .activeThisWeekPct)) ?? 0
        self.activeLastWeekPct   = (try? c.decode(Int.self, forKey: .activeLastWeekPct)) ?? 0
        self.totalGroupXP        = (try? c.decode(Int64.self, forKey: .totalGroupXP)) ?? 0
        self.totalGroupWater     = (try? c.decode(Int64.self, forKey: .totalGroupWater)) ?? 0
    }
}

// MARK: - Recent activity event

struct RecentActivityEvent: Decodable, Identifiable, Hashable {
    let eventId: String
    let kind: ActivityKind
    let userId: UUID
    let displayName: String?
    let avatarURL: String?
    let headline: String
    let occurredAt: Date
    let xpDelta: Int

    var id: String { eventId }

    enum CodingKeys: String, CodingKey {
        case eventId      = "event_id"
        case kind
        case userId       = "user_id"
        case displayName  = "display_name"
        case avatarURL    = "avatar_url"
        case headline
        case occurredAt   = "occurred_at"
        case xpDelta      = "xp_delta"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.eventId     = (try? c.decode(String.self, forKey: .eventId)) ?? UUID().uuidString
        let raw          = (try? c.decode(String.self, forKey: .kind)) ?? "other"
        self.kind        = ActivityKind(rawValue: raw) ?? .other
        self.userId      = (try? c.decode(UUID.self, forKey: .userId)) ?? UUID()
        self.displayName = try? c.decode(String.self, forKey: .displayName)
        self.avatarURL   = try? c.decode(String.self, forKey: .avatarURL)
        self.headline    = (try? c.decode(String.self, forKey: .headline)) ?? ""
        self.occurredAt  = (try? c.decode(Date.self, forKey: .occurredAt)) ?? Date()
        self.xpDelta     = (try? c.decode(Int.self, forKey: .xpDelta)) ?? 0
    }
}

/// Closed set the activity feed knows how to render. Unknown kinds map to
/// `.other` so a new server-side event type doesn't break the feed.
enum ActivityKind: String, Hashable {
    case planCompleted    = "plan_completed"
    case dayCompleted     = "day_completed"
    case joined
    case eventRSVP        = "event_rsvp"
    case attendanceTaken  = "attendance_taken"
    case other
}

// MARK: - Join request

struct JoinRequest: Decodable, Identifiable, Hashable {
    let requestId: UUID
    let userId: UUID
    let displayName: String?
    let handle: String?
    let avatarURL: String?
    let email: String?
    let message: String?
    let requestedAt: Date
    /// 6..12 or nil (adult / "not a student").
    let gradeYear: Int?
    /// Server-authoritative; true if any child profile has this user
    /// as `parent_account_id`. Surfaced as a PARENT pill in Members.
    let isParent: Bool

    var id: UUID { requestId }

    enum CodingKeys: String, CodingKey {
        case requestId   = "request_id"
        case userId      = "user_id"
        case displayName = "display_name"
        case handle
        case avatarURL   = "avatar_url"
        case email, message
        case requestedAt = "requested_at"
        case gradeYear   = "grade_year"
        case isParent    = "is_parent"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.requestId   = try c.decode(UUID.self, forKey: .requestId)
        self.userId      = try c.decode(UUID.self, forKey: .userId)
        self.displayName = try? c.decode(String.self, forKey: .displayName)
        self.handle      = try? c.decode(String.self, forKey: .handle)
        self.avatarURL   = try? c.decode(String.self, forKey: .avatarURL)
        self.email       = try? c.decode(String.self, forKey: .email)
        self.message     = try? c.decode(String.self, forKey: .message)
        self.requestedAt = (try? c.decode(Date.self, forKey: .requestedAt)) ?? Date()
        // Optional + isParent defaults to false so older RPC payloads
        // still decode without breaking the requests tab. We log the
        // raw values so a missing pill is either obviously "RPC didn't
        // return it" (nil/false) or "data isn't populated on the user."
        self.gradeYear   = try? c.decode(Int.self,  forKey: .gradeYear)
        self.isParent    = (try? c.decode(Bool.self, forKey: .isParent)) ?? false
        print("[JoinRequest] decoded:",
              "name=\(displayName ?? email ?? "?")",
              "gradeYear=\(gradeYear.map(String.init) ?? "nil")",
              "isParent=\(isParent)",
              "containsKey(grade_year)=\(c.contains(.gradeYear))",
              "containsKey(is_parent)=\(c.contains(.isParent))")
    }
}

// MARK: - Group member

struct PastorMember: Decodable, Identifiable, Hashable {
    let userId: UUID
    let displayName: String?
    let handle: String?
    let email: String?
    let avatarURL: String?
    let role: MemberRole
    let joinedAt: Date
    let lastOpenedAt: Date?
    let xp: Int
    let water: Int
    let streak: Int
    let isActiveWeek: Bool
    /// 6..12 or nil (adult / "not a student").
    let gradeYear: Int?
    /// True when at least one child has this user as `parent_account_id`.
    let isParent: Bool

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case userId       = "user_id"
        case displayName  = "display_name"
        case handle
        case email
        case avatarURL    = "avatar_url"
        case role
        case joinedAt     = "joined_at"
        case lastOpenedAt = "last_opened_at"
        case xp, water, streak
        case isActiveWeek = "is_active_week"
        case gradeYear    = "grade_year"
        case isParent     = "is_parent"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.userId       = try c.decode(UUID.self, forKey: .userId)
        self.displayName  = try? c.decode(String.self, forKey: .displayName)
        self.handle       = try? c.decode(String.self, forKey: .handle)
        self.email        = try? c.decode(String.self, forKey: .email)
        self.avatarURL    = try? c.decode(String.self, forKey: .avatarURL)
        let raw           = (try? c.decode(String.self, forKey: .role)) ?? "member"
        self.role         = MemberRole(rawValue: raw) ?? .member
        self.joinedAt     = (try? c.decode(Date.self, forKey: .joinedAt)) ?? Date()
        self.lastOpenedAt = try? c.decode(Date.self, forKey: .lastOpenedAt)
        self.xp           = (try? c.decode(Int.self, forKey: .xp)) ?? 0
        self.water        = (try? c.decode(Int.self, forKey: .water)) ?? 0
        self.streak       = (try? c.decode(Int.self, forKey: .streak)) ?? 0
        self.isActiveWeek = (try? c.decode(Bool.self, forKey: .isActiveWeek)) ?? false
        // Same backward-compat pattern as JoinRequest — Optional grade,
        // Bool defaults to false when the RPC omits the column.
        self.gradeYear    = try? c.decode(Int.self,  forKey: .gradeYear)
        self.isParent     = (try? c.decode(Bool.self, forKey: .isParent)) ?? false
    }
}

enum MemberRole: String, Hashable {
    case pastor
    case leader
    case member
    case parent
}

// MARK: - Small group

struct PastorSmallGroup: Decodable, Identifiable, Hashable {
    let smallGroupId: UUID
    let name: String
    let description: String?
    let meetingDay: String?
    let meetingTime: String?
    let memberCount: Int
    let leaderCount: Int
    let leaderNames: [String]
    let createdAt: Date

    var id: UUID { smallGroupId }

    enum CodingKeys: String, CodingKey {
        case smallGroupId = "small_group_id"
        case name, description
        case meetingDay   = "meeting_day"
        case meetingTime  = "meeting_time"
        case memberCount  = "member_count"
        case leaderCount  = "leader_count"
        case leaderNames  = "leader_names"
        case createdAt    = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.smallGroupId = try c.decode(UUID.self, forKey: .smallGroupId)
        self.name         = (try? c.decode(String.self, forKey: .name)) ?? "Small group"
        self.description  = try? c.decode(String.self, forKey: .description)
        self.meetingDay   = try? c.decode(String.self, forKey: .meetingDay)
        self.meetingTime  = try? c.decode(String.self, forKey: .meetingTime)
        self.memberCount  = (try? c.decode(Int.self, forKey: .memberCount)) ?? 0
        self.leaderCount  = (try? c.decode(Int.self, forKey: .leaderCount)) ?? 0
        self.leaderNames  = (try? c.decode([String].self, forKey: .leaderNames)) ?? []
        self.createdAt    = (try? c.decode(Date.self, forKey: .createdAt)) ?? Date()
    }
}
