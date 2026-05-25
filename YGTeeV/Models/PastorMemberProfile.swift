//
//  PastorMemberProfile.swift
//  YGTeeV
//
//  Codable shape for `pastor_member_profile(_group_id, _user_id)` — the
//  single RPC the pastor member-detail sheet pulls from. All nested
//  payloads decode defensively so a missing column on the server
//  surfaces as a quiet "no data" instead of a crash.
//

import Foundation

struct PastorMemberProfile: Decodable, Hashable {
    let userId: UUID
    let displayName: String?
    let handle: String?
    let email: String?
    let avatarUrl: String?
    /// "pastor" | "leader" | "member" | "parent" — kept as a String so a
    /// future server-side role doesn't trip a Swift enum decode.
    let role: String
    let gradeYear: Int?
    let isParent: Bool
    let linkedChildNames: [String]
    let joinedAt: Date?
    let lastOpenedAt: Date?
    let xp: Int
    let water: Int
    let streak: Int
    let lifetimeXp: Int64
    let level: Int
    let smallGroup: SmallGroupInfo?
    let attendance90d: Attendance
    let events: [EventRSVPRef]

    struct SmallGroupInfo: Decodable, Hashable {
        let id: UUID
        let name: String
        let role: String              // "member" | "leader"
        let joinedAt: Date?
        let leaderName: String?

        enum CodingKeys: String, CodingKey {
            case id, name, role
            case joinedAt   = "joined_at"
            case leaderName = "leader_name"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.id         = try c.decode(UUID.self, forKey: .id)
            self.name       = (try? c.decode(String.self, forKey: .name)) ?? "Small group"
            self.role       = (try? c.decode(String.self, forKey: .role)) ?? "member"
            self.joinedAt   = try? c.decode(Date.self, forKey: .joinedAt)
            self.leaderName = try? c.decode(String.self, forKey: .leaderName)
        }
    }

    struct Attendance: Decodable, Hashable {
        let attended: Int
        let total: Int
        let ratePct: Int
        let events: [Meeting]

        enum CodingKeys: String, CodingKey {
            case attended, total
            case ratePct = "rate_pct"
            case events
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.attended = (try? c.decode(Int.self, forKey: .attended)) ?? 0
            self.total    = (try? c.decode(Int.self, forKey: .total)) ?? 0
            self.ratePct  = (try? c.decode(Int.self, forKey: .ratePct)) ?? 0
            self.events   = (try? c.decode([Meeting].self, forKey: .events)) ?? []
        }

        static let empty = Attendance(attended: 0, total: 0, ratePct: 0, events: [])

        private init(attended: Int, total: Int, ratePct: Int, events: [Meeting]) {
            self.attended = attended
            self.total = total
            self.ratePct = ratePct
            self.events = events
        }

        struct Meeting: Decodable, Hashable, Identifiable {
            let eventId: UUID
            let title: String
            let occurredAt: Date
            let present: Bool
            let smallGroupName: String?
            var id: UUID { eventId }

            enum CodingKeys: String, CodingKey {
                case eventId        = "event_id"
                case title
                case occurredAt     = "occurred_at"
                case present
                case smallGroupName = "small_group_name"
            }

            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                self.eventId        = try c.decode(UUID.self, forKey: .eventId)
                self.title          = (try? c.decode(String.self, forKey: .title)) ?? "Meeting"
                self.occurredAt     = (try? c.decode(Date.self, forKey: .occurredAt)) ?? Date()
                self.present        = (try? c.decode(Bool.self, forKey: .present)) ?? false
                self.smallGroupName = try? c.decode(String.self, forKey: .smallGroupName)
            }
        }
    }

    struct EventRSVPRef: Decodable, Hashable, Identifiable {
        let eventId: UUID
        let title: String
        let startsAt: Date
        let location: String?
        let status: String            // "going" | "maybe" | "declined"
        let rsvpedAt: Date?
        var id: UUID { eventId }

        enum CodingKeys: String, CodingKey {
            case eventId  = "event_id"
            case title
            case startsAt = "starts_at"
            case location, status
            case rsvpedAt = "rsvped_at"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.eventId  = try c.decode(UUID.self, forKey: .eventId)
            self.title    = (try? c.decode(String.self, forKey: .title)) ?? "Event"
            self.startsAt = (try? c.decode(Date.self, forKey: .startsAt)) ?? Date()
            self.location = try? c.decode(String.self, forKey: .location)
            self.status   = (try? c.decode(String.self, forKey: .status)) ?? "going"
            self.rsvpedAt = try? c.decode(Date.self, forKey: .rsvpedAt)
        }
    }

    enum CodingKeys: String, CodingKey {
        case userId            = "user_id"
        case displayName       = "display_name"
        case handle, email
        case avatarUrl         = "avatar_url"
        case role
        case gradeYear         = "grade_year"
        case isParent          = "is_parent"
        case linkedChildNames  = "linked_child_names"
        case joinedAt          = "joined_at"
        case lastOpenedAt      = "last_opened_at"
        case xp, water, streak
        case lifetimeXp        = "lifetime_xp"
        case level
        case smallGroup        = "small_group"
        case attendance90d     = "attendance_90d"
        case events
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.userId            = try c.decode(UUID.self, forKey: .userId)
        self.displayName       = try? c.decode(String.self, forKey: .displayName)
        self.handle            = try? c.decode(String.self, forKey: .handle)
        self.email             = try? c.decode(String.self, forKey: .email)
        self.avatarUrl         = try? c.decode(String.self, forKey: .avatarUrl)
        self.role              = (try? c.decode(String.self, forKey: .role)) ?? "member"
        self.gradeYear         = try? c.decode(Int.self, forKey: .gradeYear)
        self.isParent          = (try? c.decode(Bool.self, forKey: .isParent)) ?? false
        self.linkedChildNames  = (try? c.decode([String].self, forKey: .linkedChildNames)) ?? []
        self.joinedAt          = try? c.decode(Date.self, forKey: .joinedAt)
        self.lastOpenedAt      = try? c.decode(Date.self, forKey: .lastOpenedAt)
        self.xp                = (try? c.decode(Int.self, forKey: .xp)) ?? 0
        self.water             = (try? c.decode(Int.self, forKey: .water)) ?? 0
        self.streak            = (try? c.decode(Int.self, forKey: .streak)) ?? 0
        self.lifetimeXp        = (try? c.decode(Int64.self, forKey: .lifetimeXp)) ?? 0
        self.level             = (try? c.decode(Int.self, forKey: .level)) ?? 1
        self.smallGroup        = try? c.decode(SmallGroupInfo.self, forKey: .smallGroup)
        self.attendance90d     = (try? c.decode(Attendance.self, forKey: .attendance90d)) ?? .empty
        self.events            = (try? c.decode([EventRSVPRef].self, forKey: .events)) ?? []
    }
}
