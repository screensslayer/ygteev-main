//
//  LeaderService.swift
//  YGTeeV
//
//  Backs the small-group-leader profile surface. Loads the leader's groups,
//  their rosters, attendance history, and writes attendance via RPC.
//

import Foundation
import Supabase

@Observable
final class LeaderService {
    static let shared = LeaderService()
    private let client = SupabaseManager.shared.client

    var myLeaderGroups: [LeaderSmallGroup] = []
    var membersByGroup: [UUID: [SmallGroupMemberRow]] = [:]
    var eventsByGroup: [UUID: [AttendanceEventSummary]] = [:]
    var recordsByEvent: [UUID: [AttendanceRecord]] = [:]

    private init() {}

    // MARK: - My groups

    func loadMyLeaderGroups() async {
        guard let uid = SupabaseManager.shared.currentUser?.id else {
            print("[LeaderService] loadMyLeaderGroups: no current user")
            return
        }
        print("[LeaderService] loadMyLeaderGroups for uid: \(uid.lowercased())")
        struct Row: Decodable {
            let small_group: LeaderSmallGroup
            let role: String
        }
        do {
            let rows: [Row] = try await client
                .from("small_group_members")
                .select("role, small_group:small_groups(id, youth_group_id, name, description, meeting_day, meeting_time, youth_group:youth_groups(logo_url))")
                .eq("user_id", value: uid.lowercased())
                .eq("role", value: "leader")
                .execute().value
            print("[LeaderService] loadMyLeaderGroups returned \(rows.count) row(s):",
                  rows.map { ($0.small_group.id.uuidString, $0.small_group.name) })
            await MainActor.run { self.myLeaderGroups = rows.map(\.small_group) }
        } catch {
            print("[LeaderService] ❌ loadMyLeaderGroups error:", error)
        }
    }

    // MARK: - Members

    func loadMembers(smallGroupId: UUID) async {
        print("[LeaderService] loadMembers for sg=\(smallGroupId.uuidString.lowercased())")
        struct Row: Decodable {
            let id: UUID
            let role: String
            let user_id: UUID
            // Make optional so a missing embed doesn't kill the entire decode.
            let profile: P?
            struct P: Decodable {
                let display_name: String?
                let email: String?
                let avatar_url: String?
                let bio: String?
                let last_opened_at: Date?
            }
        }
        do {
            let rows: [Row] = try await client
                .from("small_group_members")
                .select("id, role, user_id, profile:profiles!user_id(display_name, email, avatar_url, bio, last_opened_at)")
                .eq("small_group_id", value: smallGroupId.uuidString.lowercased())
                .order("role")
                .execute().value
            print("[LeaderService] loadMembers raw rows: \(rows.count)")
            for r in rows {
                print("  - role=\(r.role) user=\(r.user_id) name=\(r.profile?.display_name ?? "<nil>")")
            }
            let mapped = rows.map {
                SmallGroupMemberRow(
                    id: $0.id,
                    userId: $0.user_id,
                    role: $0.role,
                    displayName: $0.profile?.display_name,
                    email: $0.profile?.email,
                    avatarUrl: $0.profile?.avatar_url,
                    bio: $0.profile?.bio,
                    lastOpenedAt: $0.profile?.last_opened_at
                )
            }
            await MainActor.run {
                self.membersByGroup[smallGroupId] = mapped
                print("[LeaderService] membersByGroup[\(smallGroupId.uuidString.lowercased())] now has \(mapped.count)")
            }
        } catch {
            print("[LeaderService] ❌ loadMembers error:", error)
        }
    }

    // MARK: - Attendance history

    func loadAttendanceHistory(smallGroupId: UUID) async {
        do {
            let rows: [AttendanceEventSummary] = try await client
                .from("attendance_event_summary")
                .select("event_id, small_group_id, title, occurred_at, roster_total, present_count, absent_count")
                .eq("small_group_id", value: smallGroupId.uuidString.lowercased())
                .order("occurred_at", ascending: false)
                .limit(50)
                .execute().value
            await MainActor.run { self.eventsByGroup[smallGroupId] = rows }
        } catch {
            print("[LeaderService] loadAttendanceHistory:", error)
        }
    }

    func loadAttendanceRecords(eventId: UUID) async {
        do {
            let rows: [AttendanceRecord] = try await client
                .from("attendance_records")
                .select("*")
                .eq("event_id", value: eventId.uuidString.lowercased())
                .execute().value
            await MainActor.run { self.recordsByEvent[eventId] = rows }
        } catch {
            print("[LeaderService] loadAttendanceRecords:", error)
        }
    }

    // MARK: - Mutations

    func createAttendanceEvent(smallGroupId: UUID, title: String, occurredAt: Date) async throws -> AttendanceEvent {
        struct Insert: Encodable {
            let small_group_id: String
            let title: String
            let occurred_at: String
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        return try await client
            .from("attendance_events")
            .insert(Insert(
                small_group_id: smallGroupId.uuidString.lowercased(),
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                occurred_at: iso.string(from: occurredAt)
            ))
            .select()
            .single()
            .execute()
            .value
    }

    @discardableResult
    func saveAttendance(eventId: UUID, roster: [AttendanceRosterRow]) async throws -> Int {
        struct Params: Encodable {
            let _event_id: String
            let _records: [AnyJSON]
        }
        let rows: [AnyJSON] = roster.compactMap { r in
            guard let p = r.present else { return nil }
            return .object([
                "user_id": .string(r.userId.uuidString.lowercased()),
                "present": .bool(p),
                "notes":   .null,
            ])
        }
        let written: Int = try await client.rpc(
            "save_attendance",
            params: Params(_event_id: eventId.uuidString.lowercased(), _records: rows)
        ).execute().value
        return written
    }

    func updateSmallGroup(id: UUID,
                          name: String,
                          description: String?,
                          meetingDay: String?,
                          meetingTime: String?) async throws {
        struct Patch: Encodable {
            let name: String
            let description: String?
            let meeting_day: String?
            let meeting_time: String?
        }
        _ = try await client
            .from("small_groups")
            .update(Patch(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description,
                meeting_day: meetingDay,
                meeting_time: meetingTime
            ))
            .eq("id", value: id.uuidString.lowercased())
            .execute()
    }

    // MARK: - Reset

    func reset() {
        myLeaderGroups = []
        membersByGroup = [:]
        eventsByGroup = [:]
        recordsByEvent = [:]
    }
}
