//
//  EventsService.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/11/26.
//

import SwiftUI
import PhotosUI
import Supabase

@Observable
final class EventsService {
    static let shared = EventsService()
    private let client = SupabaseManager.shared.client

    var myMemberships: [MyGroupMembership] = []
    var eventsByGroup: [UUID: [GroupEventFull]] = [:]
    var myRsvps: [UUID: RsvpStatus] = [:]        // eventId -> my status
    var mediaByEvent: [UUID: [EventMediaItem]] = [:]
    var signedUrlByPath: [String: URL] = [:]     // cache, refresh on demand

    /// Bundle backing the profile-screen "My Events" + per-child
    /// carousels. Populated by `loadMyEventCarousels()`.
    var myCarousels: MyEventCarousels?

    // MARK: - A) Memberships for the home top-bar
    
    func loadMyMemberships() async throws {
        guard let uid = SupabaseManager.shared.currentUser?.id else { return }
        let rows: [MyGroupMembership] = try await client
            .from("youth_group_members")
            .select("""
              group_id, role,
              youth_group:youth_groups (
                id, name, logo_url, gradient_from, gradient_to, is_default_ygteev
              )
            """)
            .eq("user_id", value: uid.lowercased())
            .execute().value

        // Sort: default YGTeeV first, then alpha.
        self.myMemberships = rows.sorted { a, b in
            if a.isDefaultYgteev != b.isDefaultYgteev { return a.isDefaultYgteev }
            return a.name < b.name
        }
    }

    // MARK: - B) Events for a group
    
    func loadGroupEvents(groupId: UUID, upcoming: Bool) async throws {
        let nowIso = ISO8601DateFormatter().string(from: Date())
        var q = client.from("events")
            .select("id, group_id, title, description, starts_at, location, cover_url, capacity, visibility, rsvp_audience, created_at")
            .eq("group_id", value: groupId.uuidString.lowercased())
        q = upcoming
          ? q.gte("starts_at", value: nowIso)
          : q.lt("starts_at",  value: nowIso)
        let events: [GroupEventFull] = try await q
            .order("starts_at", ascending: upcoming)
            .execute().value
        self.eventsByGroup[groupId] = events
        try await refreshMyRsvps(for: events.map(\.id))
    }

    // MARK: - C) Current user's RSVPs for a batch of events
    
    func refreshMyRsvps(for eventIds: [UUID]) async throws {
        guard let uid = SupabaseManager.shared.currentUser?.id, !eventIds.isEmpty else { return }
        let rows: [EventRsvp] = try await client
            .from("event_rsvps")
            .select("id, event_id, user_id, status, created_at")
            .in("event_id", values: eventIds.map { $0.uuidString.lowercased() })
            .eq("user_id", value: uid.lowercased())
            .execute().value
        for r in rows { myRsvps[r.eventId] = r.status }
    }

    // MARK: - D) Set / clear an RSVP
    
    func setRsvp(eventId: UUID, status: RsvpStatus) async throws {
        guard let uid = SupabaseManager.shared.currentUser?.id else { throw URLError(.userAuthenticationRequired) }
        struct Payload: Encodable {
            let event_id: String
            let user_id: String
            let status: String
        }
        let payload = Payload(
            event_id: eventId.uuidString.lowercased(),
            user_id:  uid.lowercased(),
            status:   status.rawValue
        )
        _ = try await client.from("event_rsvps")
            .upsert(payload, onConflict: "event_id,user_id")
            .execute()
        await MainActor.run { myRsvps[eventId] = status }
    }

    func clearRsvp(eventId: UUID) async throws {
        guard let uid = SupabaseManager.shared.currentUser?.id else { return }
        _ = try await client.from("event_rsvps")
            .delete()
            .eq("event_id", value: eventId.uuidString.lowercased())
            .eq("user_id",  value: uid.lowercased())
            .execute()
        _ = await MainActor.run { myRsvps.removeValue(forKey: eventId) }
    }

    // MARK: - E) Event media (read)
    
    func loadEventMedia(eventId: UUID) async throws {
        let items: [EventMediaItem] = try await client
            .from("event_media")
            .select("id, event_id, kind, storage_path, video_id, caption, uploaded_by, created_at")
            .eq("event_id", value: eventId.uuidString.lowercased())
            .order("created_at", ascending: false)
            .execute().value
        mediaByEvent[eventId] = items
    }

    func signedUrl(for storagePath: String) async throws -> URL {
        if let cached = signedUrlByPath[storagePath] { return cached }
        let url = try await client.storage
            .from("event-media")
            .createSignedURL(path: storagePath, expiresIn: 3600)
        signedUrlByPath[storagePath] = url
        return url
    }

    // MARK: - F) Event media (upload — pastor/leader/admin)
    
    func uploadEventPhoto(
        eventId: UUID, groupId: UUID, image: UIImage, caption: String? = nil
    ) async throws -> EventMediaItem {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw NSError(domain: "EventsService", code: 1)
        }
        let path = "\(groupId.uuidString.lowercased())/\(eventId.uuidString.lowercased())/photo-\(Int(Date().timeIntervalSince1970)).jpg"
        try await client.storage
            .from("event-media")
            .upload(path, data: data, options: .init(contentType: "image/jpeg"))

        struct Insert: Encodable {
            let event_id: String
            let kind: String
            let storage_path: String
            let caption: String?
            let uploaded_by: String
        }
        let row: EventMediaItem = try await client.from("event_media")
            .insert(Insert(
                event_id: eventId.uuidString.lowercased(),
                kind: "photo",
                storage_path: path,
                caption: caption,
                uploaded_by: SupabaseManager.shared.currentUser?.id.lowercased() ?? ""
            ))
            .select()
            .single()
            .execute().value

        var arr = mediaByEvent[eventId] ?? []
        arr.insert(row, at: 0)
        mediaByEvent[eventId] = arr
        return row
    }

    // MARK: - G) Capability check (uses cached memberships)

    func canManageGroup(_ groupId: UUID) -> Bool {
        if EntitlementsService.shared.entitlements.isSiteAdmin { return true }
        return myMemberships.contains { $0.groupId == groupId && ($0.role == "pastor" || $0.role == "leader") }
    }

    // MARK: - H) RSVPs (event detail screen)

    /// Returns a populated `EventRSVPSummary` for the event, or the
    /// `.empty` sentinel when the RPC returns no row (shouldn't happen
    /// under normal RLS, but keeps the UI safe).
    func fetchRSVPSummary(eventId: UUID) async throws -> EventRSVPSummary {
        struct Params: Encodable { let _event_id: UUID }
        let rows: [EventRSVPSummary] = try await client
            .rpc("event_rsvp_summary",
                 params: Params(_event_id: eventId))
            .execute()
            .value
        return rows.first ?? .empty
    }

    /// Member-side action: upserts the caller's RSVP for an event and
    /// returns the fresh summary so the caller can reflect the new
    /// counts without an extra round-trip.
    @discardableResult
    func setMyRSVP(eventId: UUID, status: String) async throws -> EventRSVPSummary {
        struct Row: Encodable {
            let event_id: UUID
            let user_id: UUID
            let status: String
        }
        guard let uid = currentUserUUID() else {
            throw NSError(domain: "EventsService", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Not signed in."])
        }
        _ = try await client
            .from("event_rsvps")
            .upsert(
                Row(event_id: eventId, user_id: uid, status: status),
                onConflict: "event_id,user_id"
            )
            .execute()
        return try await fetchRSVPSummary(eventId: eventId)
    }

    /// Drops the caller's RSVP entirely. Used when the user taps the
    /// same status button twice — "Going → Going" toggles back to
    /// "no response".
    @discardableResult
    func clearMyRSVP(eventId: UUID) async throws -> EventRSVPSummary {
        guard let uid = currentUserUUID() else {
            throw NSError(domain: "EventsService", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Not signed in."])
        }
        _ = try await client
            .from("event_rsvps")
            .delete()
            .eq("event_id", value: eventId.uuidString.lowercased())
            .eq("user_id",  value: uid.uuidString.lowercased())
            .execute()
        return try await fetchRSVPSummary(eventId: eventId)
    }

    // MARK: - Profile carousels

    /// Pull the user's own upcoming/past events + per-child versions
    /// for the profile screen. Backed by the `my_event_carousels`
    /// RPC (no params, uses auth.uid()).
    func loadMyEventCarousels() async {
        do {
            let result: MyEventCarousels = try await client
                .rpc("my_event_carousels")
                .execute()
                .value
            self.myCarousels = result
        } catch {
            print("[EventsService] loadMyEventCarousels failed:", error)
            self.myCarousels = nil
        }
    }

    /// Change (or withdraw) the caller's RSVP from a profile-side
    /// detail sheet. Reuses the existing upsert / delete plumbing,
    /// then refreshes the carousels bundle and returns the latest
    /// going count for the affected event so the sheet can update
    /// its live counter.
    @discardableResult
    func updateMyRSVP(_ eventId: UUID, status: String) async throws -> Int {
        let summary: EventRSVPSummary
        if status == "withdraw" {
            summary = try await clearMyRSVP(eventId: eventId)
        } else {
            summary = try await setMyRSVP(eventId: eventId, status: status)
        }
        await loadMyEventCarousels()
        return summary.goingCount
    }

    private func currentUserUUID() -> UUID? {
        guard let raw = SupabaseManager.shared.currentUser?.id else { return nil }
        return UUID(uuidString: raw)
    }
}
