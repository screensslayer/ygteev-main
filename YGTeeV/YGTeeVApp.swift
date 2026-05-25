//
//  YGTeeVApp.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/6/26.
//

import SwiftUI
import UIKit

@main
struct YGTeeVApp: App {
    @State private var appState = AppState()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    init() {
        FontLoader.loadFonts()

        // Darken placeholder text app-wide. SwiftUI TextField wraps
        // UITextField, so swizzling the placeholder setters reaches every
        // text field in the project without per-call changes.
        UITextField.ygEnablePlaceholderTinting()

        // Touch the PurchasesManager singleton at launch so its init()
        // runs — that's what calls Purchases.configure() (prod) or no-ops
        // for staging. Must happen before any view tries to read
        // `subscriptionPackages`, hence App.init rather than an .onAppear.
        _ = PurchasesManager.shared

        // MARK: - DEV: Reset onboarding (comment out after testing)
        // UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
    }

    var body: some Scene {
        WindowGroup {
            RootView(hasCompletedOnboarding: $hasCompletedOnboarding)
                .environment(appState)
        }
    }
}

struct RootView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var supabaseManager = SupabaseManager.shared
    @State private var entitlementsService = EntitlementsService.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if supabaseManager.isCheckingSession {
                // Stay on the splash while the session-restore RPC is in
                // flight. The image matches the OS launch screen so the
                // hand-off is invisible.
                SplashView()
            } else if supabaseManager.isAuthenticated && hasCompletedOnboarding {
                MainTabView()
                    .environment(entitlementsService)
            } else {
                // Two cases land here:
                //   1) unauthenticated cold start, OR
                //   2) just-signed-up mid-onboarding — the user is now
                //      authenticated but customizing / paywall / done
                //      haven't run yet, AND the post-signup profile
                //      patch hasn't finished.
                // Both render the coordinator so the flow keeps running.
                OnboardingCoordinatorView {
                    hasCompletedOnboarding = true
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && supabaseManager.isAuthenticated {
                // App became active - heartbeat then refresh entitlements
                Task {
                    await entitlementsService.heartbeat()
                    await entitlementsService.refresh()
                }
            } else if newPhase == .background || newPhase == .inactive {
                // Don't strand any in-flight pastor-plan autosaves when the
                // app is suspended or being killed.
                Task { await PastorPlanService.shared.flushAllPending() }
            }
        }
    }
}

// MARK: - Splash View

/// Continues the OS-level launch screen image until session restore
/// finishes. Renders the same `LaunchSplash` asset so the hand-off from
/// the launch screen to SwiftUI is visually seamless.
struct SplashView: View {
    var body: some View {
        Image("LaunchSplash")
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "1A0D3D"))
    }
}

// MARK: - App State
@Observable
class AppState {
    // Note: joinedGroups will come from backend via youth_group_members query
    // For now, HomeFeedView uses the default YGTeeV group only
    var user: User = User.sample
    var gardenItems: [GardenItem] = []
    
    struct User {
        let id: String
        let name: String
        var xp: Int
        let level: Int
        let streak: Int
        var water: Int
        
        static let sample = User(
            id: "user1",
            name: "You",
            xp: 7640,
            level: 13,
            streak: 12,
            water: 100
        )
    }
}

// MARK: - Garden Item Model
struct GardenItem: Identifiable {
    let id = UUID()
    var type: String // species id from store (oak, cherry, wheat, etc.)
    var stage: Int // 1-10 depending on species
    var watersUntilNext: Int
    var position: CGPoint
    var isInBloom: Bool = false // true when plant reaches final stage

    var currentStage: PixelTree.PlantStage {
        PixelTree.PlantStage(rawValue: stage) ?? .stage1
    }

    var displayName: String {
        "\(type.capitalized) Tree"
    }

    // Max stages per species
    var maxStages: Int {
        switch type {
        case "lavender", "wheat", "sunflower", "tulip": return 4
        case "mustard", "rose", "cherry", "olive", "fig": return 7
        case "oak", "pine": return 10
        default: return 7
        }
    }

    var totalWatersInStage: Int {
        // Water requirement = next stage number
        // Stage 1 → 2 requires 2 waters
        // Stage 2 → 3 requires 3 waters
        // Stage 3 → 4 requires 4 waters, etc.
        return stage + 1
    }

    var watersCompleted: Int {
        totalWatersInStage - watersUntilNext
    }

    var progress: Double {
        guard totalWatersInStage > 0 else { return 1.0 }
        return Double(watersCompleted) / Double(totalWatersInStage)
    }
}
