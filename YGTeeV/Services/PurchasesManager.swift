//
//  PurchasesManager.swift
//  YGTeeV
//
//  Thin wrapper around RevenueCat's Swift SDK.
//
//  RC eats Apple's server-side webhooks for us and fires its own webhook
//  at our backend (which writes to `apple_subscriptions`). On the client
//  side we just need to: configure the SDK on launch, load the "default"
//  Offering, call Purchases.logIn after Supabase auth, and run
//  Purchases.shared.purchase from the paywall.
//
//  Staging RC app has no products configured. The xcconfig pipes an
//  EMPTY REVENUECAT_API_KEY for staging — when we see that we skip
//  Purchases.configure() entirely and flag `isAvailable = false` so the
//  paywall UI can swap to a "Purchases unavailable in staging" stub
//  instead of crashing or showing a fake price.
//

import Foundation
import RevenueCat

@MainActor
@Observable
final class PurchasesManager {
    static let shared = PurchasesManager()

    /// True when REVENUECAT_API_KEY was non-empty at launch and
    /// Purchases.configure() ran. Staging builds end up false.
    private(set) var isAvailable: Bool = false

    /// The 5 monthly-sub packages from the "default" offering, sorted
    /// cheapest → most expensive. Drives the price slider.
    private(set) var subscriptionPackages: [Package] = []

    /// True while we're hitting RC for offerings. Paywall CTA disables.
    private(set) var isLoading: Bool = false

    /// Last user-presentable error from load/purchase. Cleared on success.
    var lastError: String?

    private init() {
        let key = (Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String) ?? ""
        guard !key.isEmpty else {
            // Staging path — leave isAvailable = false and bail. All
            // public methods become safe no-ops below.
            #if DEBUG
            print("[PurchasesManager] REVENUECAT_API_KEY is empty — RC disabled (staging build).")
            #endif
            return
        }

        Purchases.configure(withAPIKey: key)
        isAvailable = true
        #if DEBUG
        print("[PurchasesManager] RC configured.")
        #endif

        Task { await loadOfferings() }
    }

    // MARK: - Offerings

    func loadOfferings() async {
        guard isAvailable else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let offerings = try await Purchases.shared.offerings()
            guard let current = offerings.current else {
                lastError = "No current offering configured in RevenueCat."
                subscriptionPackages = []
                return
            }
            // Sort by storeProduct.price ascending so subscriptionPackages[0]
            // is the cheapest tier. The 5 product IDs end in .099 / .199 /
            // .299 / .399 / .499, so this lines up with the slider stops.
            subscriptionPackages = current.availablePackages.sorted { lhs, rhs in
                lhs.storeProduct.price < rhs.storeProduct.price
            }
            lastError = nil
            #if DEBUG
            print("[PurchasesManager] loaded \(subscriptionPackages.count) packages: " +
                  subscriptionPackages.map { $0.storeProduct.localizedPriceString }.joined(separator: ", "))
            #endif
        } catch {
            lastError = "Couldn't load offerings: \(error.localizedDescription)"
            print("[PurchasesManager] offerings error: \(error)")
        }
    }

    // MARK: - Auth bridging
    //
    // Our backend webhook resolves RC's `app_user_id` to a Supabase
    // auth.users row by UUID. Anything that isn't a UUID gets dropped on
    // the floor, so we always log the user in with `fetchedUser.id`
    // (which IS the auth.users.id) right after Supabase auth completes.

    func logIn(userId: String) async {
        guard isAvailable else { return }
        do {
            _ = try await Purchases.shared.logIn(userId)
            #if DEBUG
            print("[PurchasesManager] logIn ok: \(userId)")
            #endif
        } catch {
            print("[PurchasesManager] logIn failed: \(error)")
        }
    }

    func logOut() async {
        guard isAvailable else { return }
        do {
            _ = try await Purchases.shared.logOut()
            #if DEBUG
            print("[PurchasesManager] logOut ok")
            #endif
        } catch {
            // logOut throws if you're already anonymous — fine to swallow.
            print("[PurchasesManager] logOut: \(error)")
        }
    }

    // MARK: - Purchase

    /// Purchases the given package. Returns `true` once the "pro"
    /// entitlement is active on the resulting CustomerInfo. Caller is
    /// expected to dismiss the paywall and let EntitlementsService.refresh()
    /// reconcile the server-side state.
    @discardableResult
    func purchase(_ package: Package) async throws -> Bool {
        guard isAvailable else { return false }

        let result = try await Purchases.shared.purchase(package: package)
        if result.userCancelled {
            return false
        }

        let isPro = result.customerInfo.entitlements["pro"]?.isActive == true

        // RC's webhook to our backend may land before this call returns,
        // but ordering isn't guaranteed. Refresh entitlements so the
        // UI's source of truth (our RPC) catches up — if the webhook is
        // late, the next foreground heartbeat refresh will pick it up.
        await EntitlementsService.shared.refresh()

        if !isPro {
            lastError = "Purchase completed but the Pro entitlement isn't active yet."
        } else {
            lastError = nil
        }
        return isPro
    }
}
