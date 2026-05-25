//
//  RankingService.swift
//  YGTeeV
//
//  Backs the home Ranking tab. Holds the active group's top-10 users
//  and the top-10 youth groups in that group's lightning class.
//  Cache is invalidated on every `load(groupId:)` so flipping the
//  active group in the home header reloads both lists cleanly.
//

import Foundation
import Supabase

@MainActor
@Observable
final class RankingService {
    static let shared = RankingService()
    private let client = SupabaseManager.shared.client

    /// Top users in the currently-selected group, by this-week XP.
    var users: [RankedUser] = []
    /// Top groups in the selected group's lightning class.
    var groups: [RankedGroup] = []

    /// Platform-wide leaderboards. Populated when the default YGTeeV
    /// group is selected (no class to compete in, so we fall back to
    /// raw weekly XP across every group / every user).
    var groupsOverall: [RankedGroupOverall] = []
    var usersOverall:  [RankedUserOverall]  = []

    /// The groupId both lists are currently scoped to. Used so the view
    /// can detect a stale cache without comparing the array contents.
    var loadedGroupId: UUID?
    var isLoading = false
    var lastError: String?

    private init() {}

    /// Loads both leaderboards in parallel. Safe to call repeatedly —
    /// the @MainActor isolation means concurrent .task calls won't
    /// double-fetch since the second one observes `isLoading`.
    func load(groupId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let usersTask: [RankedUser]  = topUsers(groupId: groupId)
            async let groupsTask: [RankedGroup] = topGroupsInClass(groupId: groupId)
            let (u, g) = try await (usersTask, groupsTask)
            self.users         = u
            self.groups        = g
            self.loadedGroupId = groupId
            self.lastError     = nil
        } catch {
            print("[RankingService] load(groupId:) failed:", error)
            self.lastError = error.localizedDescription
        }
    }

    func topUsers(groupId: UUID, limit: Int = 10) async throws -> [RankedUser] {
        struct P: Encodable {
            let _group_id: String
            let _limit: Int
        }
        return try await client
            .rpc("ranking_top_users_in_group",
                 params: P(_group_id: groupId.uuidString.lowercased(), _limit: limit))
            .execute()
            .value
    }

    func topGroupsInClass(groupId: UUID, limit: Int = 10) async throws -> [RankedGroup] {
        struct P: Encodable {
            let _group_id: String
            let _limit: Int
        }
        return try await client
            .rpc("ranking_top_groups_in_my_class",
                 params: P(_group_id: groupId.uuidString.lowercased(), _limit: limit))
            .execute()
            .value
    }

    // MARK: - Overall (default-group) leaderboards

    /// Loads both platform-wide leaderboards in parallel. Called when
    /// the default YGTeeV group is the active context — there's no
    /// lightning class to compete in, so the home Ranking tab falls back
    /// to raw weekly XP across every group / every user.
    func loadOverall() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let g: [RankedGroupOverall] = topGroupsOverall()
            async let u: [RankedUserOverall]  = topUsersOverall()
            let (gr, us) = try await (g, u)
            self.groupsOverall = gr
            self.usersOverall  = us
            self.lastError     = nil
        } catch {
            print("[RankingService] loadOverall failed:", error)
            self.lastError = error.localizedDescription
        }
    }

    func topGroupsOverall(limit: Int = 10) async throws -> [RankedGroupOverall] {
        struct P: Encodable { let _limit: Int }
        return try await client
            .rpc("ranking_top_groups_overall", params: P(_limit: limit))
            .execute()
            .value
    }

    func topUsersOverall(limit: Int = 10) async throws -> [RankedUserOverall] {
        struct P: Encodable { let _limit: Int }
        return try await client
            .rpc("ranking_top_users_overall", params: P(_limit: limit))
            .execute()
            .value
    }
}
