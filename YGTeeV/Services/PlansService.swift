//
//  PlansService.swift
//  YGTeeV
//
//  In-memory cache of Bible-plan data backed by Supabase RPCs.
//

import Foundation
import Supabase

@Observable
final class PlansService {
    static let shared = PlansService()
    private let client = SupabaseManager.shared.client

    var publishedPlans: [BiblePlan] = []
    var daysByPlan: [UUID: [PlanDayFull]] = [:]
    var progressByPlan: [UUID: [UserPlanProgress]] = [:]
    var continueCard: ContinueCard?
    var isLoadingPlans = false

    private static let continueCacheKey = "PlansService.continueCardCache.v1"

    init() {
        // Seed the in-memory continue card from disk so the Plans tab
        // renders the last-known "Continue" state immediately on cold
        // start — no Start-card flash while the RPC is in flight.
        if let data = UserDefaults.standard.data(forKey: Self.continueCacheKey),
           let cached = try? JSONDecoder().decode(ContinueCard.self, from: data) {
            self.continueCard = cached
        }
    }

    // MARK: - Pastor-plan playback (member side)

    /// Cached membership flag — does the user belong to ANY youth group
    /// (default YGTeeV group counts as a group too in the RPC).
    var inAnyYouthGroup: Bool = false
    /// Plans visible to the member in the "From [Group]" section, keyed by
    /// the toggle filter ("available" / "completed").
    var youthGroupPlans: [String: [YouthGroupPlanRow]] = [:]
    /// Per-plan day progress, hydrated on row expand.
    var pastorPlanDays: [UUID: [PlanDayProgress]] = [:]
    /// Per-day block payload, hydrated when the day reader opens.
    var pastorPlanDayPayloads: [UUID: PastorPlanDayPayload] = [:]

    func checkInAnyYouthGroup() async {
        do {
            let value: Bool = try await client
                .rpc("am_i_in_any_youth_group")
                .execute()
                .value
            await MainActor.run { self.inAnyYouthGroup = value }
        } catch {
            print("[PlansService] am_i_in_any_youth_group failed:", error)
        }
    }

    func loadYouthGroupPlans(filter: String) async {
        struct Params: Encodable { let _filter: String }
        do {
            let rows: [YouthGroupPlanRow] = try await client
                .rpc("get_my_youth_group_plans",
                     params: Params(_filter: filter))
                .execute()
                .value
            await MainActor.run { self.youthGroupPlans[filter] = rows }
        } catch {
            print("[PlansService] get_my_youth_group_plans(\(filter)) failed:", error)
        }
    }

    func loadPlanDayProgress(planId: UUID) async {
        struct Params: Encodable { let _plan_id: String }
        do {
            let rows: [PlanDayProgress] = try await client
                .rpc("get_my_plan_day_progress",
                     params: Params(_plan_id: planId.uuidString.lowercased()))
                .execute()
                .value
            await MainActor.run { self.pastorPlanDays[planId] = rows }
        } catch {
            print("[PlansService] get_my_plan_day_progress failed:", error)
        }
    }

    /// Fetch a single day's blocks from `bible_plan_days` for playback.
    func loadDayPayload(planId: UUID, dayNumber: Int) async {
        do {
            let row: PastorPlanDayPayload = try await client
                .from("bible_plan_days")
                .select("id, day_number, title, scripture_reference, sections")
                .eq("plan_id", value: planId.uuidString.lowercased())
                .eq("day_number", value: dayNumber)
                .single()
                .execute()
                .value
            await MainActor.run { self.pastorPlanDayPayloads[row.id] = row }
        } catch {
            print("[PlansService] loadDayPayload failed:", error)
        }
    }

    func completePastorPlanDay(planId: UUID,
                               dayNumber: Int,
                               answers: [DayAnswerPayload]) async throws -> DayCompletionResult {
        struct Params: Encodable {
            let _plan_id: String
            let _day_number: Int
            let _answers: [DayAnswerPayload]
        }
        let result: DayCompletionResult = try await client
            .rpc("complete_pastor_plan_day",
                 params: Params(
                    _plan_id: planId.uuidString.lowercased(),
                    _day_number: dayNumber,
                    _answers: answers))
            .execute()
            .value

        // Optimistic patch: same model as `completeStep` — apply the
        // server-reported totals to local currentUser so the profile
        // level bar advances the moment the reward screen lands.
        if !result.alreadyCompleted {
            await MainActor.run {
                guard var user = SupabaseManager.shared.currentUser else { return }
                user.xp         += result.totalXpAwarded
                user.lifetimeXP += Int64(result.totalXpAwarded)
                user.water      += result.totalWaterAwarded
                user.streak      = result.newStreak
                SupabaseManager.shared.currentUser = user
            }
            // Reconciliation refetch handles milestone grants, streak
            // rolls, and any multi-device drift.
            Task { try? await SupabaseManager.shared.refreshCurrentUser() }
        }
        return result
    }

    // MARK: Plans list (catalog)

    func loadPublishedPlans() async {
        do {
            await MainActor.run { self.isLoadingPlans = true }
            defer { Task { @MainActor in self.isLoadingPlans = false } }

            let rows: [BiblePlan] = try await client
                .from("bible_plans")
                .select("*")
                .eq("status", value: "published")
                .eq("scope", value: "global")        // exclude pastor-authored plans
                .order("recommended_order", ascending: true, nullsFirst: false)
                .order("created_at", ascending: false)
                .execute().value
            await MainActor.run { self.publishedPlans = rows }
            print("[PlansService] loadPublishedPlans loaded \(rows.count) plan(s)")
        } catch {
            print("[PlansService] loadPublishedPlans failed:", error)
        }
    }

    // MARK: Days for a plan

    func loadDays(planId: UUID) async {
        print("[PlansService] loadDays starting for plan=\(planId.uuidString.lowercased())")
        do {
            let rows: [PlanDayFull] = try await client
                .from("bible_plan_days")
                .select("id, plan_id, day_number, title, scripture_reference, reflection, sections")
                .eq("plan_id", value: planId.uuidString.lowercased())
                .order("day_number", ascending: true)
                .execute().value
            await MainActor.run { self.daysByPlan[planId] = rows }
            print("[PlansService] loadDays loaded \(rows.count) row(s) for plan=\(planId.uuidString.lowercased())")
        } catch {
            // Park an empty array on failure so the UI's `.contains(where:)`
            // gate doesn't re-fire the request in a tight loop. Verbose log
            // so Decodable failures surface their full key-path.
            await MainActor.run { self.daysByPlan[planId] = [] }
            print("[PlansService] loadDays FAILED for plan=\(planId.uuidString.lowercased()):", error)
        }
    }

    // MARK: User progress for a plan

    func loadProgress(planId: UUID) async {
        struct Params: Encodable {
            let _plan_id: String
        }
        do {
            let rows: [UserPlanProgress] = try await client
                .rpc("get_user_plan_progress",
                     params: Params(_plan_id: planId.uuidString.lowercased()))
                .execute().value
            await MainActor.run { self.progressByPlan[planId] = rows }
        } catch {
            print("[PlansService] loadProgress:", error)
        }
    }

    // MARK: Continue card

    func loadContinueCard() async {
        do {
            let rows: [ContinueCard] = try await client
                .rpc("get_continue_card")
                .execute().value
            await MainActor.run {
                self.continueCard = rows.first
                Self.persistContinueCard(rows.first)
            }
            print("[PlansService] loadContinueCard → \(rows.count) row(s); first plan: \(rows.first?.planTitle ?? "—")")
        } catch {
            // 0 rows is fine — user hasn't started any plan. Surface the
            // error in the console so a decode mismatch isn't invisible.
            // Don't wipe the cache on transient failure — keep showing the
            // last-known card so a flaky network doesn't downgrade the UI.
            print("[PlansService] loadContinueCard failed:", error)
        }
    }

    private static func persistContinueCard(_ card: ContinueCard?) {
        if let card, let data = try? JSONEncoder().encode(card) {
            UserDefaults.standard.set(data, forKey: continueCacheKey)
        } else {
            UserDefaults.standard.removeObject(forKey: continueCacheKey)
        }
    }

    // MARK: Complete a step

    func completeStep(
        planId: UUID,
        dayId: UUID,
        step: PlanStep,
        answers: [String: AnyJSON]
    ) async throws -> StepCompletionResult {
        struct Params: Encodable {
            let _plan_id: String
            let _day_id: String
            let _step: String
            let _answers: [String: AnyJSON]
        }
        let resp: StepCompletionResult = try await client
            .rpc("complete_plan_step",
                 params: Params(
                    _plan_id: planId.uuidString.lowercased(),
                    _day_id: dayId.uuidString.lowercased(),
                    _step: step.rawValue,
                    _answers: answers
                 ))
            .execute().value

        // Optimistic patch: bump local currentUser so the level bar +
        // XP totals tick up the moment the reward screen lands, no
        // round-trip required. Skip if the step was already completed
        // (server returns zeros in that case, but a stale already_done
        // call shouldn't double-count either).
        if !resp.alreadyCompleted {
            await MainActor.run {
                guard var user = SupabaseManager.shared.currentUser else { return }
                user.xp         += resp.totalXpAwarded
                user.lifetimeXP += Int64(resp.totalXpAwarded)
                user.water      += resp.totalWaterAwarded
                if let ns = resp.newStreak { user.streak = ns }
                SupabaseManager.shared.currentUser = user
            }
            // Fire-and-forget authoritative refetch so multi-device
            // edits, milestone grants, or any side effect we didn't
            // model lands shortly after the optimistic update.
            Task { try? await SupabaseManager.shared.refreshCurrentUser() }
        }

        // Refresh in-memory progress for this plan.
        Task { await self.loadProgress(planId: planId) }

        // If day completed, the continue card needs to move to the next day.
        if resp.dayNowComplete {
            Task { await self.loadContinueCard() }
        }

        return resp
    }

    func reset() {
        publishedPlans = []
        daysByPlan = [:]
        progressByPlan = [:]
        continueCard = nil
    }

    /// Single source of truth for paywall checks.
    /// Site admins always pass; free-entry plans are open to everyone; the rest require Pro.
    static func canViewerStart(_ plan: BiblePlan) -> Bool {
        let ent = EntitlementsService.shared.entitlements
        return ent.isSiteAdmin || plan.isFreeEntry || ent.isPro
    }
}
