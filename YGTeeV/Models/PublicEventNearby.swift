//
//  PublicEventNearby.swift
//  YGTeeV
//
//  Row returned by `public_events_nearby` — drives the "Public events
//  nearby" carousel beneath the groups carousel on the map. Decodes
//  defensively so a row with a missing cover / gradient / description
//  still renders without crashing the whole list.
//

import Foundation

struct PublicEventNearby: Identifiable, Decodable, Hashable {
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
    let distanceM: Double
    /// True when the event belongs to a youth group the caller is
    /// already a member of. The carousel filters these out on the
    /// client so the map list stays discovery-only.
    let isMyGroupEvent: Bool

    var id: UUID { eventId }

    enum CodingKeys: String, CodingKey {
        case eventId            = "event_id"
        case title
        case description
        case startsAt           = "starts_at"
        case location
        case coverUrl           = "cover_url"
        case groupId            = "group_id"
        case groupName          = "group_name"
        case groupChurchName    = "group_church_name"
        case groupLogoUrl       = "group_logo_url"
        case groupGradientFrom  = "group_gradient_from"
        case groupGradientTo    = "group_gradient_to"
        case goingCount         = "going_count"
        case distanceM          = "distance_m"
        case isMyGroupEvent     = "is_my_group_event"
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
        self.distanceM         = (try? c.decode(Double.self, forKey: .distanceM)) ?? 0
        self.isMyGroupEvent    = (try? c.decode(Bool.self, forKey: .isMyGroupEvent)) ?? false
    }

    /// Miles, one decimal, e.g. "8.4 mi". The RPC returns meters.
    var distanceLabel: String {
        let mi = distanceM / 1609.34
        return String(format: "%.1f mi", mi)
    }
}
