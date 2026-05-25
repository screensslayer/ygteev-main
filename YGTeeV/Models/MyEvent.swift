//
//  MyEvent.swift
//  YGTeeV
//
//  Shapes returned by the `my_event_carousels` RPC — the data behind
//  the "My Events" / "My Past Events" + per-child carousels on the
//  profile screen. Each event row decodes defensively so a missing
//  cover/gradient/description doesn't crash the whole bundle.
//

import Foundation

struct MyEvent: Identifiable, Decodable, Hashable {
    let eventId: UUID
    let title: String
    let description: String?
    let startsAt: Date
    let location: String?
    let coverUrl: String?
    let groupId: UUID
    let groupName: String
    let groupChurchName: String?
    let groupLogoUrl: String?
    let groupGradientFrom: String?
    let groupGradientTo: String?
    let goingCount: Int
    /// "going" | "maybe"
    let myStatus: String
    let isUpcoming: Bool

    var id: UUID { eventId }

    enum CodingKeys: String, CodingKey {
        case eventId           = "event_id"
        case title
        case description
        case startsAt          = "starts_at"
        case location
        case coverUrl          = "cover_url"
        case groupId           = "group_id"
        case groupName         = "group_name"
        case groupChurchName   = "group_church_name"
        case groupLogoUrl      = "group_logo_url"
        case groupGradientFrom = "group_gradient_from"
        case groupGradientTo   = "group_gradient_to"
        case goingCount        = "going_count"
        case myStatus          = "my_status"
        case isUpcoming        = "is_upcoming"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.eventId           = try c.decode(UUID.self, forKey: .eventId)
        self.title             = (try? c.decode(String.self, forKey: .title)) ?? "Event"
        self.description       = try? c.decode(String.self, forKey: .description)
        self.startsAt          = (try? c.decode(Date.self, forKey: .startsAt)) ?? Date()
        self.location          = try? c.decode(String.self, forKey: .location)
        self.coverUrl          = try? c.decode(String.self, forKey: .coverUrl)
        self.groupId           = try c.decode(UUID.self, forKey: .groupId)
        self.groupName         = (try? c.decode(String.self, forKey: .groupName)) ?? "Group"
        self.groupChurchName   = try? c.decode(String.self, forKey: .groupChurchName)
        self.groupLogoUrl      = try? c.decode(String.self, forKey: .groupLogoUrl)
        self.groupGradientFrom = try? c.decode(String.self, forKey: .groupGradientFrom)
        self.groupGradientTo   = try? c.decode(String.self, forKey: .groupGradientTo)
        self.goingCount        = (try? c.decode(Int.self, forKey: .goingCount)) ?? 0
        self.myStatus          = (try? c.decode(String.self, forKey: .myStatus)) ?? "going"
        self.isUpcoming        = (try? c.decode(Bool.self, forKey: .isUpcoming)) ?? false
    }
}

struct MyEventCarousel: Decodable, Hashable {
    let userId: UUID
    let displayName: String
    let avatarUrl: String?
    let upcoming: [MyEvent]
    let past:     [MyEvent]

    enum CodingKeys: String, CodingKey {
        case userId      = "user_id"
        case displayName = "display_name"
        case avatarUrl   = "avatar_url"
        case upcoming
        case past
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.userId      = try c.decode(UUID.self, forKey: .userId)
        self.displayName = (try? c.decode(String.self, forKey: .displayName)) ?? "Member"
        self.avatarUrl   = try? c.decode(String.self, forKey: .avatarUrl)
        self.upcoming    = (try? c.decode([MyEvent].self, forKey: .upcoming)) ?? []
        self.past        = (try? c.decode([MyEvent].self, forKey: .past)) ?? []
    }
}

struct MyEventCarousels: Decodable {
    /// `self` is a Swift keyword — rename in Swift, map back to the
    /// "self" JSON key via CodingKeys.
    let me: MyEventCarousel
    let children: [MyEventCarousel]

    enum CodingKeys: String, CodingKey {
        case me = "self"
        case children
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.me       = try c.decode(MyEventCarousel.self, forKey: .me)
        self.children = (try? c.decode([MyEventCarousel].self, forKey: .children)) ?? []
    }
}
