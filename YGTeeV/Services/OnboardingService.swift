//
//  OnboardingService.swift
//  YGTeeV
//
//  Thin RPC layer for the reimagined 20-moment first-run experience.
//  All backend endpoints referenced here are deployed on staging + prod:
//
//    get_groups_near_me(_lat, _lng)              → [NearbyGroup]
//    record_onboarding_answer(_qnum, _idx)       → OnboardingAnswerResult
//    complete_onboarding()                       → { xp_awarded, total_xp, already_completed }
//    submit_feedback(_source, _rating, _emoji, _comment) → uuid
//    boost_discovered_youth_group(p_target_id, p_target_kind)
//
//  Plus a couple of PostgREST table reads:
//    from("onboarding_questions").select(...)    for the 5 seeded prompts
//    from("profiles").update(...)                for the mid-flow profile patch
//    from("youth_group_join_requests").insert(...) for the real-group join
//
//  This service holds no view state — the coordinator hands data in and
//  reads results back. The `questions` cache is the only piece of live
//  state, populated once via `loadQuestions()` and read from the quick-
//  check + day-1 sneak peek screens.
//

import Foundation
import Supabase

@MainActor
@Observable
final class OnboardingService {
    static let shared = OnboardingService()
    @ObservationIgnored private let client = SupabaseManager.shared.client

    /// The 5 seeded onboarding questions. Loaded once on the quick-check
    /// screen's `.task`. Text is server-owned so copy edits ship without
    /// an app release.
    private(set) var questions: [OnboardingQuestion] = []

    private init() {}

    // MARK: - Question catalog

    func loadQuestions() async throws {
        struct Row: Decodable {
            let id: UUID
            let questionNumber: Int
            let category: String
            let prompt: String
            let choices: [String]
            let correctChoiceIndex: Int
            let explanation: String?
            let xpReward: Int

            enum CodingKeys: String, CodingKey {
                case id, category, prompt, choices, explanation
                case questionNumber     = "question_number"
                case correctChoiceIndex = "correct_choice_index"
                case xpReward           = "xp_reward"
            }
        }
        let rows: [Row] = try await client
            .from("onboarding_questions")
            .select("id, question_number, category, prompt, choices, correct_choice_index, explanation, xp_reward")
            .order("question_number", ascending: true)
            .execute().value
        questions = rows.map {
            OnboardingQuestion(
                id: $0.id,
                questionNumber: $0.questionNumber,
                category: $0.category,
                prompt: $0.prompt,
                choices: $0.choices,
                correctChoiceIndex: $0.correctChoiceIndex,
                explanation: $0.explanation,
                xpReward: $0.xpReward
            )
        }
    }

    // MARK: - Groups near me

    func groupsNearMe(lat: Double, lng: Double) async throws -> [NearbyGroup] {
        struct Params: Encodable {
            let _lat: Double
            let _lng: Double
        }
        return try await client
            .rpc("get_groups_near_me", params: Params(_lat: lat, _lng: lng))
            .execute().value
    }

    // MARK: - Trivia answers

    /// Idempotent — the RPC returns `already_answered: true` and 0 XP if
    /// the same question is re-submitted, so we can safely re-play the
    /// screen after an app kill without double-awarding.
    func recordAnswer(questionNumber: Int, selectedIndex: Int) async throws -> OnboardingAnswerResult {
        struct Params: Encodable {
            let _question_number: Int
            let _selected_choice_index: Int
        }
        return try await client
            .rpc("record_onboarding_answer",
                 params: Params(_question_number: questionNumber, _selected_choice_index: selectedIndex))
            .execute().value
    }

    // MARK: - Complete onboarding (welcome bonus)

    struct CompleteResult: Decodable {
        let alreadyCompleted: Bool
        let xpAwarded: Int
        let totalXp: Int
        enum CodingKeys: String, CodingKey {
            case alreadyCompleted = "already_completed"
            case xpAwarded        = "xp_awarded"
            case totalXp          = "total_xp"
        }
    }

    /// Idempotent — subsequent calls return `already_completed: true`
    /// with 0 XP. Grants the 3000 XP welcome bonus on first call and
    /// stamps `profiles.onboarding_completed_at`.
    func completeOnboarding() async throws -> CompleteResult {
        struct Empty: Encodable {}
        return try await client
            .rpc("complete_onboarding", params: Empty())
            .execute().value
    }

    // MARK: - Feedback

    /// `submit_feedback` returns a UUID (the inserted row id). We don't
    /// use it — decode into a permissive shape.
    func submitFeedback(source: String, rating: Int?, emoji: String?, comment: String?) async throws {
        struct Params: Encodable {
            let _source: String
            let _rating: Int?
            let _emoji: String?
            let _comment: String?
        }
        struct IgnoredResponse: Decodable {}
        _ = try? await client
            .rpc("submit_feedback",
                 params: Params(_source: source, _rating: rating, _emoji: emoji, _comment: comment))
            .execute()
    }

    // MARK: - Profile patches during onboarding

    /// Persists the display name + grade + birth-year picked during
    /// onboarding. Called after auth completes but before the color
    /// reveal so the profile row is fully hydrated when the arena or
    /// leaderboards read it.
    func updateProfileBasics(displayName: String, gradeYear: Int?, birthYear: Int) async throws {
        guard let uidString = SupabaseManager.shared.currentUser?.id,
              let uid = UUID(uuidString: uidString) else { return }
        struct Update: Encodable {
            let display_name: String
            let grade_year: Int?
            let date_of_birth: String
        }
        _ = try await client
            .from("profiles")
            .update(Update(
                display_name: displayName,
                grade_year: gradeYear,
                date_of_birth: "\(birthYear)-01-01"
            ))
            .eq("id", value: uid.uuidString.lowercased())
            .execute()
    }

    // MARK: - Group join

    /// - **Default YGTeeV group** — the signup trigger already auto-
    ///   joins, nothing to do here.
    /// - **Real group** — insert into `youth_group_join_requests`.
    ///   Pastor approval flow governs when the user actually joins.
    /// - **Discovered group** — treat the pick as a boost so the group
    ///   gets a signal that a real person wants it activated.
    func joinGroup(_ group: NearbyGroup) async throws {
        if group.isDefault { return }
        guard let uidString = SupabaseManager.shared.currentUser?.id,
              let uid = UUID(uuidString: uidString) else { return }

        switch group.kind {
        case "real":
            struct Row: Encodable {
                let user_id: String
                let group_id: String
            }
            _ = try await client
                .from("youth_group_join_requests")
                .insert(Row(
                    user_id: uid.uuidString.lowercased(),
                    group_id: group.id.uuidString.lowercased()
                ))
                .execute()

        case "discovered":
            struct Params: Encodable {
                let p_target_id: String
                let p_target_kind: String
            }
            _ = try await client
                .rpc("boost_discovered_youth_group",
                     params: Params(
                        p_target_id: group.id.uuidString.lowercased(),
                        p_target_kind: "discovered"
                     ))
                .execute()

        default:
            break
        }
    }
}

// MARK: - Question model

struct OnboardingQuestion: Identifiable, Equatable, Hashable {
    let id: UUID
    let questionNumber: Int
    let category: String
    let prompt: String
    let choices: [String]
    let correctChoiceIndex: Int
    let explanation: String?
    let xpReward: Int
}
