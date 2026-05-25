//
//  YouthGroupService.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/11/26.
//

import Foundation
import Supabase

@Observable
final class YouthGroupService {
    static let shared = YouthGroupService()
    private let client = SupabaseManager.shared.client

    var nearbyPins: [YouthGroupMapPin] = []
    var isLoadingPins = false
    var loadError: String?

    /// Public events surfaced under the groups carousel on the map.
    /// Pivoted off the same lat/lng as `nearbyPins` so both lists are
    /// aligned to one map center.
    var publicEvents: [PublicEventNearby] = []

    func loadNearby(lat: Double, lng: Double, meters: Double = 40234) async {
        isLoadingPins = true
        loadError = nil
        defer { isLoadingPins = false }
        
        do {
            let pins: [YouthGroupMapPin] = try await client
                .rpc("youth_groups_near", params: [
                    "_lat": lat,
                    "_lng": lng,
                    "_meters": meters
                ])
                .execute()
                .value
            self.nearbyPins = pins
            for p in pins {
                print("[youth_groups_near] \(p.name) logoUrl=\(p.logoUrl ?? "<nil>")")
            }
        } catch {
            self.loadError = error.localizedDescription
            print("❌ Error loading nearby groups: \(error)")
        }
    }

    func loadPublicProfile(groupId: UUID) async throws -> YouthGroupPublicProfile {
        let rows: [YouthGroupPublicProfile] = try await client
            .rpc("youth_group_public_profile", params: [
                "_group_id": groupId.uuidString
            ])
            .execute()
            .value
        
        guard let first = rows.first else {
            throw NSError(
                domain: "YouthGroupService",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Group not found or not public"]
            )
        }
        return first
    }

    func requestToJoin(groupId: UUID, message: String? = nil) async throws -> YouthGroupJoinRequest {
        struct RequestParams: Encodable {
            let groupId: String
            let message: String?

            enum CodingKeys: String, CodingKey {
                case groupId = "_group_id"
                case message = "_message"
            }
        }

        let params = RequestParams(groupId: groupId.uuidString, message: message)

        let req: YouthGroupJoinRequest = try await client
            .rpc("request_to_join_group", params: params)
            .execute()
            .value

        return req
    }

    // MARK: - Public events (map carousel)

    /// Loads public events visible to anyone within `radiusM` of the
    /// supplied coordinates. The `is_my_group_event` flag still arrives
    /// on each row (we may surface a "Your group" pill on those cards
    /// later) but no longer filters anything out — the carousel shows
    /// every public event in range.
    func loadPublicEvents(lat: Double, lng: Double, radiusM: Int = 50000) async {
        struct P: Encodable {
            let _lat: Double
            let _lng: Double
            let _radius_m: Int
            let _limit: Int
        }
        do {
            let rows: [PublicEventNearby] = try await client
                .rpc("public_events_nearby",
                     params: P(_lat: lat, _lng: lng, _radius_m: radiusM, _limit: 20))
                .execute()
                .value
            self.publicEvents = rows
        } catch {
            print("[YouthGroupService] loadPublicEvents failed:", error)
            self.publicEvents = []
        }
    }

    /// RSVPs the signed-in user to a public event without requiring
    /// them to join the host group. Returns the new server-side
    /// `going_count` so the sheet can update its live count.
    @discardableResult
    func rsvpPublicEvent(_ eventId: UUID, status: String = "going") async throws -> Int {
        struct P: Encodable {
            let _event_id: String
            let _status: String
        }
        struct R: Decodable { let going_count: Int }
        let resp: R = try await client
            .rpc("rsvp_public_event",
                 params: P(_event_id: eventId.uuidString.lowercased(),
                           _status: status))
            .execute()
            .value
        return resp.going_count
    }

    /// Drop the caller's membership row in `youth_group_members`. RLS lets
    /// users delete their own row; the default YGTeeV group should never
    /// be passed here — UI filters it out.
    func leaveYouthGroup(groupId: UUID) async throws {
        guard let uid = SupabaseManager.shared.currentUser?.id else {
            throw NSError(domain: "YouthGroupService", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }
        _ = try await client
            .from("youth_group_members")
            .delete()
            .eq("group_id", value: groupId.uuidString.lowercased())
            .eq("user_id", value: uid.lowercased())
            .execute()
    }
}
