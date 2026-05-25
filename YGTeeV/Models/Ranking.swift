//
//  Ranking.swift
//  YGTeeV
//
//  Codable shapes for the two RPCs that back the home Ranking tab:
//    • ranking_top_users_in_group     → [RankedUser]
//    • ranking_top_groups_in_my_class → [RankedGroup]
//
//  Both decode defensively so a single missing column on the server
//  (e.g. a freshly-created group with no logo yet) doesn't crash the
//  whole leaderboard.
//

import Foundation

struct RankedUser: Identifiable, Decodable, Hashable {
    let rank: Int
    let userId: UUID
    let displayName: String?
    let handle: String?
    let avatarUrl: String?
    /// "pastor" | "leader" | "parent" | "student" | "member" — mapped
    /// into `MessageThread.LeaderRole` for the pill color.
    let role: String?
    let weekXp: Int64
    let isMe: Bool

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case rank
        case userId      = "user_id"
        case displayName = "display_name"
        case handle
        case avatarUrl   = "avatar_url"
        case role
        case weekXp      = "week_xp"
        case isMe        = "is_me"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.rank        = (try? c.decode(Int.self, forKey: .rank)) ?? 0
        self.userId      = try c.decode(UUID.self, forKey: .userId)
        self.displayName = try? c.decode(String.self, forKey: .displayName)
        self.handle      = try? c.decode(String.self, forKey: .handle)
        self.avatarUrl   = try? c.decode(String.self, forKey: .avatarUrl)
        self.role        = try? c.decode(String.self, forKey: .role)
        self.weekXp      = (try? c.decode(Int64.self, forKey: .weekXp)) ?? 0
        self.isMe        = (try? c.decode(Bool.self, forKey: .isMe)) ?? false
    }
}

/// Overall (platform-wide) groups leaderboard — surfaced when the user
/// has the default YGTeeV group selected, since there's no class to
/// compete in. No multiplier or class fields; ranking is by raw
/// `week_xp` and the default group itself is filtered out server-side.
struct RankedGroupOverall: Identifiable, Decodable, Hashable {
    let rank: Int
    let groupId: UUID
    let name: String
    let churchName: String?
    let logoUrl: String?
    let gradientFrom: String?
    let gradientTo: String?
    let activeCount: Int
    let weekXp: Int64
    let isMyGroup: Bool

    var id: UUID { groupId }

    enum CodingKeys: String, CodingKey {
        case rank
        case groupId      = "group_id"
        case name
        case churchName   = "church_name"
        case logoUrl      = "logo_url"
        case gradientFrom = "gradient_from"
        case gradientTo   = "gradient_to"
        case activeCount  = "active_count"
        case weekXp       = "week_xp"
        case isMyGroup    = "is_my_group"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.rank         = (try? c.decode(Int.self, forKey: .rank)) ?? 0
        self.groupId      = try c.decode(UUID.self, forKey: .groupId)
        self.name         = (try? c.decode(String.self, forKey: .name)) ?? "Group"
        self.churchName   = try? c.decode(String.self, forKey: .churchName)
        self.logoUrl      = try? c.decode(String.self, forKey: .logoUrl)
        self.gradientFrom = try? c.decode(String.self, forKey: .gradientFrom)
        self.gradientTo   = try? c.decode(String.self, forKey: .gradientTo)
        self.activeCount  = (try? c.decode(Int.self, forKey: .activeCount)) ?? 0
        self.weekXp       = (try? c.decode(Int64.self, forKey: .weekXp)) ?? 0
        self.isMyGroup    = (try? c.decode(Bool.self, forKey: .isMyGroup)) ?? false
    }
}

/// Overall (platform-wide) users leaderboard — surfaced when the user
/// has the default YGTeeV group selected. Each row carries the user's
/// primary group so the UI can show "@LuckyLantern · Lifepointe" since
/// group context is otherwise lost in the global list.
struct RankedUserOverall: Identifiable, Decodable, Hashable {
    let rank: Int
    let userId: UUID
    let displayName: String?
    let handle: String?
    let avatarUrl: String?
    let groupId: UUID?
    let groupName: String?
    let weekXp: Int64
    let isMe: Bool

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case rank
        case userId      = "user_id"
        case displayName = "display_name"
        case handle
        case avatarUrl   = "avatar_url"
        case groupId     = "group_id"
        case groupName   = "group_name"
        case weekXp      = "week_xp"
        case isMe        = "is_me"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.rank        = (try? c.decode(Int.self, forKey: .rank)) ?? 0
        self.userId      = try c.decode(UUID.self, forKey: .userId)
        self.displayName = try? c.decode(String.self, forKey: .displayName)
        self.handle      = try? c.decode(String.self, forKey: .handle)
        self.avatarUrl   = try? c.decode(String.self, forKey: .avatarUrl)
        self.groupId     = try? c.decode(UUID.self, forKey: .groupId)
        self.groupName   = try? c.decode(String.self, forKey: .groupName)
        self.weekXp      = (try? c.decode(Int64.self, forKey: .weekXp)) ?? 0
        self.isMe        = (try? c.decode(Bool.self, forKey: .isMe)) ?? false
    }
}

struct RankedGroup: Identifiable, Decodable, Hashable {
    let rank: Int
    let groupId: UUID
    let name: String
    let churchName: String?
    let logoUrl: String?
    let gradientFrom: String?
    let gradientTo: String?
    /// Lowercase class id from the server: "bolts" | "volts" | "surge"
    /// | "storm" | "thunder" | "legends".
    let className: String
    /// Capitalized label, ready to render: "Bolts" | "Volts" | …
    let classLabel: String
    let activeCount: Int
    let maxActiveInClass: Int
    /// Handicap multiplier returned by the server, capped at 3.00. Never
    /// recompute client-side — tie-breakers depend on this exact value.
    let multiplier: Double
    let weekXp: Int64
    let adjustedXp: Int64
    let isMyGroup: Bool

    var id: UUID { groupId }

    enum CodingKeys: String, CodingKey {
        case rank
        case groupId           = "group_id"
        case name
        case churchName        = "church_name"
        case logoUrl           = "logo_url"
        case gradientFrom      = "gradient_from"
        case gradientTo        = "gradient_to"
        case className         = "class"
        case classLabel        = "class_label"
        case activeCount       = "active_count"
        case maxActiveInClass  = "max_active_in_class"
        case multiplier
        case weekXp            = "week_xp"
        case adjustedXp        = "adjusted_xp"
        case isMyGroup         = "is_my_group"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.rank             = (try? c.decode(Int.self, forKey: .rank)) ?? 0
        self.groupId          = try c.decode(UUID.self, forKey: .groupId)
        self.name             = (try? c.decode(String.self, forKey: .name)) ?? "Group"
        self.churchName       = try? c.decode(String.self, forKey: .churchName)
        self.logoUrl          = try? c.decode(String.self, forKey: .logoUrl)
        self.gradientFrom     = try? c.decode(String.self, forKey: .gradientFrom)
        self.gradientTo       = try? c.decode(String.self, forKey: .gradientTo)
        self.className        = (try? c.decode(String.self, forKey: .className)) ?? "bolts"
        self.classLabel       = (try? c.decode(String.self, forKey: .classLabel))
                                ?? (self.className.prefix(1).uppercased() + self.className.dropFirst())
        self.activeCount      = (try? c.decode(Int.self, forKey: .activeCount)) ?? 0
        self.maxActiveInClass = (try? c.decode(Int.self, forKey: .maxActiveInClass)) ?? 0
        self.multiplier       = (try? c.decode(Double.self, forKey: .multiplier)) ?? 1.0
        self.weekXp           = (try? c.decode(Int64.self, forKey: .weekXp)) ?? 0
        self.adjustedXp       = (try? c.decode(Int64.self, forKey: .adjustedXp)) ?? 0
        self.isMyGroup        = (try? c.decode(Bool.self, forKey: .isMyGroup)) ?? false
    }
}
