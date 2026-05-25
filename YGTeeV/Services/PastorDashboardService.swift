//
//  PastorDashboardService.swift
//  YGTeeV
//
//  Backs the pastor dashboard, members view, and recent activity feed.
//  Holds the active group id plus cached payloads keyed implicitly off
//  the active group — flipping `activeGroupId` clears caches.
//

import Foundation
import SwiftUI
import Supabase

@MainActor
@Observable
final class PastorDashboardService {
    static let shared = PastorDashboardService()
    private let client = SupabaseManager.shared.client

    /// Currently-selected pastor group. UI mutates this directly when the
    /// pastor switches via the "My Youth Groups" cards row.
    var activeGroupId: UUID? {
        didSet { if oldValue != activeGroupId { clearCaches() } }
    }

    // Cached payloads (per active group).
    var dashboard: PastorDashboardSnapshot?
    var recentActivity: [RecentActivityEvent] = []
    var joinRequests: [JoinRequest] = []
    var allMembers: [PastorMember] = []
    var leaders: [PastorMember] = []
    var smallGroups: [PastorSmallGroup] = []

    /// All youth groups the caller pastors. Reused by both the dashboard
    /// header switcher and the plan-setup group picker.
    var myGroups: [PastorGroup] = []

    /// Last surfaced error message, kept light so a single banner can
    /// expose problems without per-call wiring.
    var lastError: String?

    private init() {}

    // MARK: - My groups

    func loadMyGroups() async {
        do {
            let groups: [PastorGroup] = try await client
                .rpc("pastor_my_groups")
                .execute()
                .value
            myGroups = groups
            if activeGroupId == nil, let first = groups.first {
                activeGroupId = first.id
            }
        } catch {
            print("[PastorDashboardService] pastor_my_groups failed:", error)
            lastError = error.localizedDescription
        }
    }

    // MARK: - Dashboard snapshot

    func loadDashboard() async {
        guard let groupId = activeGroupId else { return }
        struct Params: Encodable { let _group_id: String }
        do {
            let snap: PastorDashboardSnapshot = try await client
                .rpc("pastor_dashboard",
                     params: Params(_group_id: groupId.uuidString.lowercased()))
                .single()
                .execute()
                .value
            dashboard = snap
        } catch {
            print("[PastorDashboardService] pastor_dashboard failed:", error)
            lastError = error.localizedDescription
        }
    }

    // MARK: - Recent activity

    func loadRecentActivity(limit: Int = 20) async {
        guard let groupId = activeGroupId else { return }
        struct Params: Encodable {
            let _group_id: String
            let _limit: Int
        }
        do {
            let rows: [RecentActivityEvent] = try await client
                .rpc("pastor_recent_activity",
                     params: Params(_group_id: groupId.uuidString.lowercased(),
                                    _limit: limit))
                .execute()
                .value
            recentActivity = rows
        } catch {
            print("[PastorDashboardService] pastor_recent_activity failed:", error)
            lastError = error.localizedDescription
        }
    }

    // MARK: - Join requests

    func loadJoinRequests() async {
        guard let groupId = activeGroupId else { return }
        struct Params: Encodable { let _group_id: String }
        do {
            let rows: [JoinRequest] = try await client
                .rpc("pastor_list_join_requests",
                     params: Params(_group_id: groupId.uuidString.lowercased()))
                .execute()
                .value
            joinRequests = rows
        } catch {
            print("[PastorDashboardService] pastor_list_join_requests failed:", error)
            lastError = error.localizedDescription
        }
    }

    func approveJoinRequest(_ requestId: UUID) async {
        struct Params: Encodable { let _request_id: String }
        // Optimistic: remove from local list before the round-trip.
        joinRequests.removeAll { $0.requestId == requestId }
        do {
            _ = try await client
                .rpc("pastor_approve_join_request",
                     params: Params(_request_id: requestId.uuidString.lowercased()))
                .execute()
            // Refresh dependent surfaces so the new member appears + counts update.
            await loadDashboard()
            await loadAllMembers()
        } catch {
            print("[PastorDashboardService] approve failed:", error)
            lastError = error.localizedDescription
            // Roll back by re-fetching the request list.
            await loadJoinRequests()
        }
    }

    func denyJoinRequest(_ requestId: UUID) async {
        struct Params: Encodable { let _request_id: String }
        joinRequests.removeAll { $0.requestId == requestId }
        do {
            _ = try await client
                .rpc("pastor_deny_join_request",
                     params: Params(_request_id: requestId.uuidString.lowercased()))
                .execute()
            await loadDashboard()
        } catch {
            print("[PastorDashboardService] deny failed:", error)
            lastError = error.localizedDescription
            await loadJoinRequests()
        }
    }

    // MARK: - Members

    func loadAllMembers() async {
        await loadMembers(roleFilter: "all", activeOnly: false, target: \.allMembers)
    }

    func loadLeaders() async {
        await loadMembers(roleFilter: "leader", activeOnly: false, target: \.leaders)
    }

    private func loadMembers(roleFilter: String,
                             activeOnly: Bool,
                             target: ReferenceWritableKeyPath<PastorDashboardService, [PastorMember]>) async {
        guard let groupId = activeGroupId else { return }
        struct Params: Encodable {
            let _group_id: String
            let _role_filter: String
            let _active_only: Bool
        }
        do {
            let rows: [PastorMember] = try await client
                .rpc("pastor_list_group_members",
                     params: Params(
                        _group_id: groupId.uuidString.lowercased(),
                        _role_filter: roleFilter,
                        _active_only: activeOnly))
                .execute()
                .value
            self[keyPath: target] = rows
        } catch {
            print("[PastorDashboardService] pastor_list_group_members (\(roleFilter)) failed:", error)
            lastError = error.localizedDescription
        }
    }

    // MARK: - Small groups

    func loadSmallGroups() async {
        guard let groupId = activeGroupId else { return }
        struct Params: Encodable { let _group_id: String }
        do {
            let rows: [PastorSmallGroup] = try await client
                .rpc("pastor_list_small_groups",
                     params: Params(_group_id: groupId.uuidString.lowercased()))
                .execute()
                .value
            smallGroups = rows
        } catch {
            print("[PastorDashboardService] pastor_list_small_groups failed:", error)
            lastError = error.localizedDescription
        }
    }

    // MARK: - Member detail (sheet)

    /// Pulls the per-member profile sheet payload in a single round-trip.
    /// RPC raises forbidden (42501) if the caller isn't the pastor of the
    /// group; we let that bubble so the sheet can surface an error.
    func fetchMemberProfile(groupId: UUID, userId: UUID) async throws -> PastorMemberProfile {
        struct Params: Encodable {
            let _group_id: String
            let _user_id: String
        }
        let profile: PastorMemberProfile = try await client
            .rpc("pastor_member_profile",
                 params: Params(
                    _group_id: groupId.uuidString.lowercased(),
                    _user_id:  userId.uuidString.lowercased()))
            .execute()
            .value
        return profile
    }

    /// Remove the user from the youth group. RLS permits pastors of this
    /// group; cascade deletes their small-group membership and chat
    /// subscriptions via existing FK + delete triggers.
    func removeFromGroup(groupId: UUID, userId: UUID) async throws {
        _ = try await client
            .from("youth_group_members")
            .delete()
            .eq("group_id", value: groupId.uuidString.lowercased())
            .eq("user_id",  value: userId.uuidString.lowercased())
            .execute()
    }

    /// Remove the user from a single small group while leaving their
    /// youth-group membership in place.
    func removeFromSmallGroup(smallGroupId: UUID, userId: UUID) async throws {
        _ = try await client
            .from("small_group_members")
            .delete()
            .eq("small_group_id", value: smallGroupId.uuidString.lowercased())
            .eq("user_id",        value: userId.uuidString.lowercased())
            .execute()
    }

    // MARK: - Coordinated refresh

    /// Full dashboard refresh — header + activity + request count.
    func refreshDashboard() async {
        async let a: Void = loadDashboard()
        async let b: Void = loadRecentActivity()
        async let c: Void = loadJoinRequests()
        _ = await (a, b, c)
    }

    // MARK: - Lifecycle

    private func clearCaches() {
        dashboard = nil
        recentActivity = []
        joinRequests = []
        allMembers = []
        leaders = []
        smallGroups = []
    }
}
