//
//  YouthGroup.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/6/26.
//

import SwiftUI
import MapKit

// MARK: - Youth Group Map Pin
struct YouthGroupMapPin: Identifiable, Decodable, Hashable {
    let id: UUID
    let name: String
    let churchName: String
    let description: String
    let address: String?
    let meetingTime: String?
    let logoUrl: String?
    let gradientFrom: String
    let gradientTo: String
    let latitude: Double
    let longitude: Double
    let distanceM: Double
    let memberCount: Int
    let smallGroupCount: Int
    /// Audience type: 'hs' | 'ms' | 'hs_ms' or nil for "all/legacy".
    let groupType: String?
    /// Explicit grade list (6..12), or nil if the group hasn't declared one.
    let grades: [Int]?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var distanceMiles: Double { distanceM / 1609.344 }
    
    var distanceLabel: String {
        distanceMiles < 0.1
            ? "<0.1 mi"
            : String(format: "%.1f mi", distanceMiles)
    }
    
    var initials: String {
        name.split(separator: " ").prefix(2)
            .map { String($0.prefix(1)) }.joined()
    }
    
    var gradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: gradientFrom), Color(hex: gradientTo)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, name
        case churchName       = "church_name"
        case description, address
        case meetingTime      = "meeting_time"
        case logoUrl          = "logo_url"
        case gradientFrom     = "gradient_from"
        case gradientTo       = "gradient_to"
        case latitude, longitude
        case distanceM        = "distance_m"
        case memberCount      = "member_count"
        case smallGroupCount  = "small_group_count"
        case groupType        = "group_type"
        case grades
    }
}

// MARK: - Youth Group Public Profile
struct YouthGroupPublicProfile: Identifiable, Decodable, Hashable {
    let id: UUID
    let name: String
    let churchName: String
    let description: String
    let address: String?
    let meetingTime: String?
    let logoUrl: String?
    let gradientFrom: String
    let gradientTo: String
    let latitude: Double
    let longitude: Double
    let memberCount: Int
    let smallGroupCount: Int
    let leaders: [GroupLeader]
    let upcomingEvents: [GroupEvent]
    // Server-computed flags scoped to the calling user. Source of truth for
    // whether to show the "Request to Join" CTA.
    var viewerIsMember: Bool
    var viewerPendingRequest: Bool
    /// Audience type: 'hs' | 'ms' | 'hs_ms' or nil for "all/legacy".
    let groupType: String?
    /// Explicit grade list (6..12), or nil if the group hasn't declared one.
    let grades: [Int]?

    var gradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: gradientFrom), Color(hex: gradientTo)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    var initials: String {
        name.split(separator: " ").prefix(2)
            .map { String($0.prefix(1)) }.joined()
    }

    enum CodingKeys: String, CodingKey {
        case id, name
        case churchName       = "church_name"
        case description, address
        case meetingTime      = "meeting_time"
        case logoUrl          = "logo_url"
        case gradientFrom     = "gradient_from"
        case gradientTo       = "gradient_to"
        case latitude, longitude
        case memberCount      = "member_count"
        case smallGroupCount  = "small_group_count"
        case leaders
        case upcomingEvents   = "upcoming_events"
        case viewerIsMember       = "viewer_is_member"
        case viewerPendingRequest = "viewer_pending_request"
        case groupType            = "group_type"
        case grades
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                 = try c.decode(UUID.self,    forKey: .id)
        name               = try c.decode(String.self,  forKey: .name)
        churchName         = try c.decode(String.self,  forKey: .churchName)
        description        = try c.decode(String.self,  forKey: .description)
        address            = try c.decodeIfPresent(String.self, forKey: .address)
        meetingTime        = try c.decodeIfPresent(String.self, forKey: .meetingTime)
        logoUrl            = try c.decodeIfPresent(String.self, forKey: .logoUrl)
        gradientFrom       = try c.decode(String.self,  forKey: .gradientFrom)
        gradientTo         = try c.decode(String.self,  forKey: .gradientTo)
        latitude           = try c.decode(Double.self,  forKey: .latitude)
        longitude          = try c.decode(Double.self,  forKey: .longitude)
        memberCount        = try c.decode(Int.self,     forKey: .memberCount)
        smallGroupCount    = try c.decode(Int.self,     forKey: .smallGroupCount)
        leaders            = try c.decode([GroupLeader].self, forKey: .leaders)
        upcomingEvents     = try c.decode([GroupEvent].self,  forKey: .upcomingEvents)
        // Backward-compatible: default to false if the RPC hasn't been redeployed.
        viewerIsMember        = try c.decodeIfPresent(Bool.self, forKey: .viewerIsMember) ?? false
        viewerPendingRequest  = try c.decodeIfPresent(Bool.self, forKey: .viewerPendingRequest) ?? false
        groupType             = try c.decodeIfPresent(String.self, forKey: .groupType)
        grades                = try c.decodeIfPresent([Int].self,  forKey: .grades)
    }
}

// MARK: - Group Leader
struct GroupLeader: Identifiable, Decodable, Hashable {
    let id: UUID
    let displayName: String?
    let avatarUrl: String?
    let role: String   // "pastor" | "leader"

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarUrl   = "avatar_url"
        case role
    }
}

// MARK: - Group Event
struct GroupEvent: Identifiable, Decodable, Hashable {
    let id: UUID
    let title: String
    let startsAt: Date
    let location: String?
    let coverUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, title
        case startsAt = "starts_at"
        case location
        case coverUrl = "cover_url"
    }
}

// MARK: - Youth Group Join Request
struct YouthGroupJoinRequest: Identifiable, Decodable, Hashable {
    let id: UUID
    let groupId: UUID
    let userId: UUID
    let status: String
    let message: String?
    let requestedAt: Date
    let decidedAt: Date?
    let decidedBy: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case groupId    = "group_id"
        case userId     = "user_id"
        case status, message
        case requestedAt = "requested_at"
        case decidedAt  = "decided_at"
        case decidedBy  = "decided_by"
    }
}

// MARK: - Legacy Types (for HomeFeedView compatibility)
// TODO: Refactor HomeFeedView to use YouthGroupMapPin/YouthGroupPublicProfile
struct YouthGroup: Identifiable, Hashable {
    let id: String
    let name: String
    let churchName: String
    let description: String
    let memberCount: Int
    let smallGroupCount: Int
    let meetingTime: String
    let distance: String
    let gradient: GradientInfo
    let location: GroupLocation
    let leaders: [LegacyGroupLeader]
    let upcomingEvents: [LegacyGroupEvent]
    
    var initials: String {
        name.split(separator: " ")
            .prefix(2)
            .map { String($0.prefix(1)) }
            .joined()
    }
}

struct GradientInfo: Codable, Hashable {
    let startColor: String
    let endColor: String
    
    var gradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: startColor), Color(hex: endColor)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct GroupLocation: Hashable {
    let latitude: Double
    let longitude: Double
    let address: String?
}

struct LegacyGroupLeader: Identifiable, Hashable {
    let id: String
    let name: String
    let role: String
}

struct LegacyGroupEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let date: Date
    let time: String
    let location: String
}

// MARK: - Group Audience helpers

/// Audience labels + eligibility for the new `group_type` / `grades`
/// columns. Keeps the map-card chip copy in sync with the server-side
/// gate in `request_to_join_group`.
enum GroupAudience {
    /// Display label for the chip on map cards. Prefers grades when set
    /// (e.g. "6th–8th grade"); falls back to `group_type` ("Middle School");
    /// falls back again to a generic "All students" label.
    static func label(groupType: String?, grades: [Int]?) -> String {
        if let grades, !grades.isEmpty {
            let sorted = grades.sorted()
            let lo = sorted.first!
            let hi = sorted.last!
            if lo == hi { return "\(ordinal(lo)) grade" }
            return "\(ordinal(lo))–\(ordinal(hi)) grade"
        }
        switch groupType {
        case "ms":    return "Middle School"
        case "hs":    return "High School"
        case "hs_ms": return "Middle + High School"
        default:      return "All students"
        }
    }

    /// What to render on the disabled join button when the viewer's
    /// grade falls outside the group's accepted range.
    static func ineligibleCTA(groupType: String?, grades: [Int]?) -> String {
        if let grades, !grades.isEmpty {
            let hasMS = grades.contains(where: { $0 <= 8 })
            let hasHS = grades.contains(where: { $0 >= 9 })
            if hasMS && hasHS { return "Available to Middle + High School students" }
            if hasHS          { return "Available to High School students" }
            if hasMS          { return "Available to Middle School students" }
        }
        switch groupType {
        case "hs":    return "Available to High School students"
        case "ms":    return "Available to Middle School students"
        case "hs_ms": return "Available to Middle + High School students"
        default:      return "Not available for your grade"
        }
    }

    /// Mirrors the server's rule in `request_to_join_group`:
    ///   - groups without declared `grades` accept anyone
    ///   - viewers without a `grade_year` (adults / not a student) pass
    static func viewerIsEligible(viewerGradeYear: Int?, groupGrades: [Int]?) -> Bool {
        guard let groupGrades, !groupGrades.isEmpty else { return true }
        guard let grade = viewerGradeYear else { return true }
        return groupGrades.contains(grade)
    }

    private static func ordinal(_ n: Int) -> String {
        let suffix: String
        switch n % 100 {
        case 11, 12, 13: suffix = "th"
        default:
            switch n % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }
}
