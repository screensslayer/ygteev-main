//
//  ReimaginedOnboardingState.swift
//  YGTeeV
//
//  State model for the 20-moment reimagined onboarding flow. Lives
//  alongside the OLD `OnboardingState` so both flows can run in
//  parallel — the cutover to the new flow happens in Phase 6.
//
//  All screens read + write through a single instance owned by
//  `OnboardingRootView`. Nothing here is persisted; the flow either
//  finishes and hands its data off to the profile / RPCs, or the
//  user quits mid-flow and re-runs from the start (which is safe
//  because the trivia + welcome-bonus RPCs are idempotent).
//
//  Naming: prefixed `Reimagined*` so it can't collide with the
//  legacy `OnboardingState` type currently in production.
//

import Foundation
import CoreLocation

@MainActor
@Observable
final class ReimaginedOnboardingState {
    // MARK: - Router step
    //
    // Each screen mounts against exactly one case. The router lives
    // in `OnboardingRootView` and consults `isUnder13` after M6
    // (birthDoubleCheck) to route the COPPA branch.

    var step: ReimaginedOnbStep = .splash

    // MARK: - M2 — source branch
    //
    // Recorded for local UX flavoring only; not sent to the backend.

    var source: SignupSource? = nil
    enum SignupSource: String, Hashable, Codable {
        case friend
        case atGroup
        case foundIt
    }

    // MARK: - M3 — group picker

    var currentLocation: CLLocationCoordinate2D? = nil
    var nearbyGroups: [NearbyGroup] = []
    var selectedGroup: NearbyGroup? = nil

    // MARK: - M4-M5 — demographics

    var gradeYear: Int? = nil       // 6–12, nil = "not a student"
    var birthYear: Int? = nil       // e.g. 2013

    /// Under-13 derived from `birthYear`. Router branches off this
    /// after the birth-year double-check screen.
    var isUnder13: Bool {
        guard let year = birthYear else { return false }
        let currentYear = Calendar.current.component(.year, from: Date())
        return (currentYear - year) < 13
    }

    // MARK: - M7-M9 — parent pairing (under-13 only)

    var pairingToken: String? = nil
    var pairingNumericCode: String? = nil
    var parentAcceptedAt: Date? = nil

    // MARK: - M10 — name + avatar

    var displayName: String = ""
    var avatarColorIndex: Int = 0

    // MARK: - M12-M14 — color reveal (read from profile after signup)

    var revealedSplatColor: SplatTeamColor? = nil

    // MARK: - M15-M17 — trivia

    var questionResults: [Int: OnboardingAnswerResult] = [:]
    var totalTriviaXp: Int = 0

    // MARK: - M18 — welcome bonus

    var welcomeBonusAwarded: Int = 0
    var totalXpAfterWelcome: Int = 0

    // MARK: - M20 — feedback (all optional)

    var feedbackRating: Int? = nil
    var feedbackEmoji: String? = nil
    var feedbackComment: String = ""
}

// MARK: - Step enum

enum ReimaginedOnbStep: Int, CaseIterable, Hashable {
    case splash          // M1
    case sourceBranch    // M2
    case groupPicker     // M3
    case gradeYear       // M4
    case birthYear       // M5
    case birthDoubleCheck // M6
    case parentPair      // M7-M9 (only under-13, order-swapped after auth)
    case nameAvatar      // M10
    case authChoice      // M11 — Supabase signup fires here
    case colorReveal     // M12-M14
    case quickCheck      // M15 — Qs 1-2
    case day1SneakPeek   // M16-M17 — Qs 3-5
    case day1Complete    // M18 — calls complete_onboarding for +3000 XP
    case notifPermission // M19
    case feedback        // M20
    case done            // dismiss the coordinator
}

// MARK: - NearbyGroup
//
// Wire model for `get_groups_near_me`. Merged real + discovered
// groups with a `kind` discriminator + the default YGTeeV group
// pinned at the top by the RPC.

struct NearbyGroup: Identifiable, Decodable, Hashable {
    let id: UUID
    let kind: String              // "real" | "discovered"
    let name: String
    let churchName: String?
    let description: String?
    let logoUrl: String?
    let city: String?
    let state: String?
    let distanceMiles: Double?
    let memberCount: Int?
    let boostCount: Int
    let isDefault: Bool

    enum CodingKeys: String, CodingKey {
        case id, kind, name, description
        case churchName    = "church_name"
        case logoUrl       = "logo_url"
        case city, state
        case distanceMiles = "distance_miles"
        case memberCount   = "member_count"
        case boostCount    = "boost_count"
        case isDefault     = "is_default"
    }
}

// MARK: - OnboardingAnswerResult
//
// Wire model for `record_onboarding_answer`. `already_answered`
// signals an idempotent no-op (e.g. user killed the app mid-flow
// and re-ran onboarding — same answers give 0 XP the second time).

struct OnboardingAnswerResult: Decodable, Hashable {
    let alreadyAnswered: Bool
    let correct: Bool
    let correctChoiceIndex: Int
    let xpAwarded: Int
    let explanation: String?

    enum CodingKeys: String, CodingKey {
        case alreadyAnswered    = "already_answered"
        case correct
        case correctChoiceIndex = "correct_choice_index"
        case xpAwarded          = "xp_awarded"
        case explanation
    }
}
