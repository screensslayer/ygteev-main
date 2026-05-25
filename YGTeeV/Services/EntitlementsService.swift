//
//  EntitlementsService.swift
//  YGTeeV
//
//  Created by Claude Code on 5/8/26.
//

import Foundation
import Supabase

// MARK: - Entitlements Model
struct Entitlements: Codable, Equatable {
    var isPro: Bool
    var isSiteAdmin: Bool
    var isPastor: Bool
    var isParent: Bool
    var canCreateEvents: Bool
    var canCreatePlans: Bool
    var canRunYouthGroup: Bool

    enum CodingKeys: String, CodingKey {
        case isPro = "is_pro"
        case isSiteAdmin = "is_site_admin"
        case isPastor = "is_pastor"
        case isParent = "is_parent"
        case canCreateEvents = "can_create_events"
        case canCreatePlans = "can_create_plans"
        case canRunYouthGroup = "can_run_youth_group"
    }

    /// Default entitlements - all false
    static let none = Entitlements(
        isPro: false,
        isSiteAdmin: false,
        isPastor: false,
        isParent: false,
        canCreateEvents: false,
        canCreatePlans: false,
        canRunYouthGroup: false
    )
}

// MARK: - Entitlements Service
@MainActor
@Observable
class EntitlementsService {
    static let shared = EntitlementsService()

    // MARK: - Published State
    private(set) var entitlements: Entitlements = .none
    private(set) var isLoading = false
    private(set) var lastRefreshDate: Date?

    // MARK: - Heartbeat Debouncing
    private var lastHeartbeatDate: Date?
    private let heartbeatDebounceInterval: TimeInterval = 5 * 60 // 5 minutes

    // MARK: - Dependencies
    private var supabaseClient: SupabaseClient {
        SupabaseManager.shared.client
    }

    private init() {}

    // MARK: - Public API

    /// Refresh entitlements from server
    /// Call this after: auth restore, coming to foreground, subscription changes, youth group changes
    func refresh() async {
        guard SupabaseManager.shared.isAuthenticated else {
            // User not authenticated - reset to default
            entitlements = .none
            lastRefreshDate = nil
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Call get_my_entitlements RPC
            let response: [Entitlements] = try await supabaseClient
                .rpc("get_my_entitlements")
                .execute()
                .value

            // The RPC returns one row
            if let newEntitlements = response.first {
                entitlements = newEntitlements
                lastRefreshDate = Date()
                print("✅ Entitlements refreshed: isPro=\(newEntitlements.isPro), isPastor=\(newEntitlements.isPastor)")
            } else {
                // No row returned - this shouldn't happen for authenticated users
                print("⚠️ get_my_entitlements returned no rows")
                entitlements = .none
            }
        } catch {
            print("❌ Error refreshing entitlements: \(error)")
            // TODO: Log to Sentry when available
            // Keep existing entitlements on error rather than resetting
        }
    }

    /// Send heartbeat to server (debounced to once per 5 minutes)
    /// This keeps youth-group members' Pro status alive
    func heartbeat() async {
        guard SupabaseManager.shared.isAuthenticated else {
            return
        }

        // Check debounce
        if let lastHeartbeat = lastHeartbeatDate {
            let elapsed = Date().timeIntervalSince(lastHeartbeat)
            if elapsed < heartbeatDebounceInterval {
                print("⏭️ Heartbeat skipped (last beat \(Int(elapsed))s ago, debounce: \(Int(heartbeatDebounceInterval))s)")
                return
            }
        }

        do {
            // Call heartbeat RPC (returns void)
            try await supabaseClient
                .rpc("heartbeat")
                .execute()

            lastHeartbeatDate = Date()
            print("💓 Heartbeat sent")
        } catch {
            print("❌ Heartbeat error: \(error)")
            // TODO: Log to Sentry when available
            // Fire-and-forget - don't surface to UI
        }
    }

    /// Reset entitlements (call on sign-out)
    func reset() {
        entitlements = .none
        lastRefreshDate = nil
        lastHeartbeatDate = nil
        print("🔄 Entitlements reset")
    }

    /// Force immediate heartbeat (bypass debounce)
    /// Only use this for testing or critical situations
    func forceHeartbeat() async {
        lastHeartbeatDate = nil
        await heartbeat()
    }

    // MARK: - Convenience Methods

    /// Call after subscription purchase/renewal/restore
    /// Immediately refreshes entitlements without waiting for next foreground
    func refreshAfterSubscriptionChange() async {
        print("🔄 Refreshing entitlements after subscription change")
        await refresh()
    }

    /// Call after joining or leaving a youth group
    /// Immediately refreshes entitlements as youth group membership affects Pro status
    func refreshAfterYouthGroupChange() async {
        print("🔄 Refreshing entitlements after youth group change")
        await refresh()
    }
}
