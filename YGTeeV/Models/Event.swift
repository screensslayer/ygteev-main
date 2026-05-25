//
//  Event.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/8/26.
//

import SwiftUI

// MARK: - Backend-Aligned Event Models

struct GroupEventFull: Identifiable, Decodable, Hashable {
    let id: UUID
    let groupId: UUID
    let title: String
    let description: String?
    let startsAt: Date
    let location: String?
    let coverUrl: String?
    let capacity: Int?
    let visibility: String        // 'public' | 'groupPrivate'
    let rsvpAudience: String      // 'members_only' | 'public'
    /// Best-effort geocoded coordinates of the event's location text.
    /// Both columns are nullable on the server; `public_events_nearby`
    /// falls back to the host group's coords when these are null, so
    /// the event still places on the map.
    let latitude: Double?
    let longitude: Double?
    let createdAt: Date

    var isPast: Bool { startsAt < Date() }

    enum CodingKeys: String, CodingKey {
        case id, title, description, location, capacity, visibility
        case latitude, longitude
        case groupId      = "group_id"
        case startsAt     = "starts_at"
        case coverUrl     = "cover_url"
        case rsvpAudience = "rsvp_audience"
        case createdAt    = "created_at"
    }
}

enum RsvpStatus: String, Codable, Hashable {
    case going
    case maybe
    case declined
    
    var displayName: String {
        switch self {
        case .going: return "Going"
        case .maybe: return "Maybe"
        case .declined: return "Declined"
        }
    }
}

struct EventRsvp: Identifiable, Decodable, Hashable {
    let id: UUID
    let eventId: UUID
    let userId: UUID
    let status: RsvpStatus
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, status
        case eventId   = "event_id"
        case userId    = "user_id"
        case createdAt = "created_at"
    }
}

struct EventMediaItem: Identifiable, Decodable, Hashable {
    let id: UUID
    let eventId: UUID
    let kind: String              // 'photo' | 'video'
    let storagePath: String?
    let videoId: UUID?
    let caption: String?
    let uploadedBy: UUID?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, kind, caption
        case eventId     = "event_id"
        case storagePath = "storage_path"
        case videoId     = "video_id"
        case uploadedBy  = "uploaded_by"
        case createdAt   = "created_at"
    }
}

struct MyGroupMembership: Identifiable, Decodable, Hashable {
    var id: UUID { groupId }
    let groupId: UUID
    let role: String                 // 'pastor' | 'leader' | 'member'
    let name: String
    let logoUrl: String?
    let gradientFrom: String?
    let gradientTo: String?
    let isDefaultYgteev: Bool

    enum CodingKeys: String, CodingKey {
        case groupId         = "group_id"
        case role
        case youth_group
    }
    
    enum YgKeys: String, CodingKey {
        case id, name
        case logoUrl         = "logo_url"
        case gradientFrom    = "gradient_from"
        case gradientTo      = "gradient_to"
        case isDefaultYgteev = "is_default_ygteev"
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        role    = try c.decode(String.self, forKey: .role)
        let yg  = try c.nestedContainer(keyedBy: YgKeys.self, forKey: .youth_group)
        groupId          = try yg.decode(UUID.self, forKey: .id)
        name             = try yg.decode(String.self, forKey: .name)
        logoUrl          = try yg.decodeIfPresent(String.self, forKey: .logoUrl)
        gradientFrom     = try yg.decodeIfPresent(String.self, forKey: .gradientFrom)
        gradientTo       = try yg.decodeIfPresent(String.self, forKey: .gradientTo)
        isDefaultYgteev  = try yg.decode(Bool.self, forKey: .isDefaultYgteev)
    }
}

// MARK: - Legacy Types (for compatibility - will be removed)

struct Event: Identifiable {
    let id: String
    var title: String
    var date: Date
    let time: String
    var location: String
    let groupId: String
    let groupName: String
    /// Optional long-form description. Hydrated from the server row;
    /// sample-data sites can omit it and it stays nil.
    var description: String? = nil
    var rsvpStatus: RSVPStatus?
    var media: [EventMedia]
    /// Default to the most-private setting so any legacy call site that
    /// builds an `Event` directly (sample data, etc.) doesn't
    /// accidentally surface as publicly shareable.
    var visibility: String = "groupPrivate"   // 'public' | 'groupPrivate'
    var rsvpAudience: String = "members_only" // 'members_only' | 'public'
    /// Geocoded lat/lng of the event location. Nil means the
    /// pastor hasn't entered an address yet, the geocode failed, or
    /// the row predates the geocode pass — the server falls back to
    /// the host group's coords in that case.
    var latitude: Double?  = nil
    var longitude: Double? = nil

    /// True only when both the event itself and its RSVP audience are
    /// public — the gate for the "Invite a friend" share button.
    var isPublicRsvp: Bool {
        visibility == "public" && rsvpAudience == "public"
    }

    var isPast: Bool {
        date < Date()
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }
}

extension Event {
    /// Root of the public RSVP page that lives on the Lovable web app.
    /// Every iOS share-sheet URL is built from this — keep it as the
    /// single source of truth so future domain moves are one-line
    /// updates instead of grep-and-edit hunts.
    static let publicEventBaseURL = "https://ygteev.com/events"

    /// Adapt the server-side `GroupEventFull` into the sample `Event` shape
    /// that the existing pastor UI renders. Time is formatted client-side
    /// from `startsAt`.
    init(from full: GroupEventFull) {
        let tf = DateFormatter()
        tf.dateFormat = "h:mm a"
        self.id           = full.id.uuidString
        self.title        = full.title
        self.date         = full.startsAt
        self.time         = tf.string(from: full.startsAt)
        self.location     = full.location ?? ""
        self.groupId      = full.groupId.uuidString.lowercased()
        self.groupName    = ""
        self.description  = full.description
        self.rsvpStatus   = nil
        self.media        = []
        self.visibility   = full.visibility
        self.rsvpAudience = full.rsvpAudience
        self.latitude     = full.latitude
        self.longitude    = full.longitude
    }
}

enum RSVPStatus: String, Codable {
    case yes
    case maybe
    case no
    
    var displayName: String {
        switch self {
        case .yes: return "Yes"
        case .maybe: return "Maybe"
        case .no: return "No"
        }
    }
}

struct EventMedia: Identifiable {
    let id: String
    let type: MediaType
    let url: String
    let thumbnailUrl: String?
    
    enum MediaType {
        case photo
        case video
    }
}

// MARK: - Sample Data (legacy)
extension Event {
    static let sampleEvents: [Event] = [
        Event(
            id: "1",
            title: "Wednesday Night Worship",
            date: Calendar.current.date(byAdding: .day, value: 7, to: Date())!,
            time: "7:00 PM",
            location: "Main Sanctuary",
            groupId: "group1",
            groupName: "Youth Group",
            rsvpStatus: nil,
            media: []
        ),
        Event(
            id: "2",
            title: "Youth Game Night",
            date: Calendar.current.date(byAdding: .day, value: 14, to: Date())!,
            time: "6:30 PM",
            location: "Youth Center",
            groupId: "group1",
            groupName: "Youth Group",
            rsvpStatus: .maybe,
            media: []
        ),
        Event(
            id: "3",
            title: "Summer Camp 2026",
            date: Calendar.current.date(byAdding: .month, value: 2, to: Date())!,
            time: "9:00 AM",
            location: "Pine Ridge Retreat Center",
            groupId: "group1",
            groupName: "Youth Group",
            rsvpStatus: nil,
            media: []
        ),
        Event(
            id: "4",
            title: "Easter Celebration",
            date: Calendar.current.date(byAdding: .day, value: -30, to: Date())!,
            time: "10:00 AM",
            location: "Main Sanctuary",
            groupId: "group1",
            groupName: "Youth Group",
            rsvpStatus: .yes,
            media: [
                EventMedia(id: "m1", type: .photo, url: "photo1", thumbnailUrl: nil),
                EventMedia(id: "m2", type: .photo, url: "photo2", thumbnailUrl: nil),
                EventMedia(id: "m3", type: .video, url: "video1", thumbnailUrl: "video1_thumb")
            ]
        ),
        Event(
            id: "5",
            title: "Super Bowl Watch Party",
            date: Calendar.current.date(byAdding: .day, value: -60, to: Date())!,
            time: "5:00 PM",
            location: "Youth Center",
            groupId: "group1",
            groupName: "Youth Group",
            rsvpStatus: .yes,
            media: [
                EventMedia(id: "m4", type: .photo, url: "photo3", thumbnailUrl: nil),
                EventMedia(id: "m5", type: .photo, url: "photo4", thumbnailUrl: nil)
            ]
        )
    ]
}
