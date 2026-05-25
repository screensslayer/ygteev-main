//
//  BiblePlan.swift
//  YGTeeV
//
//  Models for Supabase-backed Bible plans.
//

import Foundation
import SwiftUI

enum PlanCategory: String, Codable, Hashable {
    case book_study, thematic, devotional, group_plan
}

enum PlanStatus: String, Codable, Hashable {
    case draft, published, archived
}

enum PlanStep: String, Codable, Hashable, CaseIterable {
    // `give` is intentionally absent — the iOS flow no longer
    // surfaces a Give step. The server-side enum still defines it
    // (we don't drop enum values), so any historical
    // `bible_plan_step_progress` rows from older builds stay valid.
    case read, study, apply, memorize, pray
}

struct BiblePlan: Identifiable, Decodable, Hashable {
    let id: UUID
    let title: String
    let slug: String
    let description: String?
    let category: PlanCategory
    let status: PlanStatus
    let daysTotal: Int
    let gradientFrom: String
    let gradientTo: String
    let recommendedOrder: Int?
    let isFreeEntry: Bool
    let xpReward: Int
    let waterReward: Int

    enum CodingKeys: String, CodingKey {
        case id, title, slug, description, category, status
        case daysTotal       = "days_total"
        case gradientFrom    = "gradient_from"
        case gradientTo      = "gradient_to"
        case recommendedOrder = "recommended_order"
        case isFreeEntry     = "is_free_entry"
        case xpReward        = "xp_reward"
        case waterReward     = "water_reward"
        case gradientIdx     = "gradient_idx"
    }

    /// Defensive decode: pastor-published plans don't always set the full
    /// canonical field set (slug, category, gradient_from/to, xp_reward,
    /// etc.). Defaulting missing fields keeps them visible in the
    /// member-facing plan list instead of silently dropping them.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id          = try c.decode(UUID.self, forKey: .id)
        self.title       = (try? c.decode(String.self, forKey: .title)) ?? "Untitled plan"
        self.slug        = (try? c.decode(String.self, forKey: .slug)) ?? self.id.uuidString.lowercased()
        self.description = try? c.decode(String.self, forKey: .description)
        self.category    = (try? c.decode(String.self, forKey: .category))
                              .flatMap(PlanCategory.init(rawValue:)) ?? .thematic
        self.status      = (try? c.decode(String.self, forKey: .status))
                              .flatMap(PlanStatus.init(rawValue:)) ?? .draft
        self.daysTotal   = (try? c.decode(Int.self, forKey: .daysTotal)) ?? 0

        // Gradient: prefer explicit hex columns; fall back to the indexed
        // pastor palette so pastor plans render with their chosen gradient.
        let g = BiblePlan.fallbackGradient(
            from: try? c.decode(String.self, forKey: .gradientFrom),
            to:   try? c.decode(String.self, forKey: .gradientTo),
            idx:  try? c.decode(Int.self,    forKey: .gradientIdx)
        )
        self.gradientFrom = g.from
        self.gradientTo   = g.to

        self.recommendedOrder = try? c.decode(Int.self, forKey: .recommendedOrder)
        self.isFreeEntry  = (try? c.decode(Bool.self, forKey: .isFreeEntry)) ?? false
        self.xpReward     = (try? c.decode(Int.self,  forKey: .xpReward)) ?? max(self.daysTotal * 500, 0)
        self.waterReward  = (try? c.decode(Int.self,  forKey: .waterReward)) ?? max(self.daysTotal * 4, 0)
    }

    private static let pastorGradientHexes: [(String, String)] = [
        ("6B2BFF", "FF3DA5"),
        ("0066FF", "00E0FF"),
        ("FF6B35", "FFD60A"),
        ("B4FF3C", "2B8A3E"),
        ("FFD60A", "FF3DA5"),
    ]

    private static func fallbackGradient(from: String?, to: String?, idx: Int?) -> (from: String, to: String) {
        if let from, let to { return (from, to) }
        if let idx, (0..<pastorGradientHexes.count).contains(idx) {
            return pastorGradientHexes[idx]
        }
        return pastorGradientHexes[0]
    }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: gradientFrom), Color(hex: gradientTo)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    var requiresPro: Bool { !isFreeEntry }
}

struct PlanDayFull: Identifiable, Decodable, Hashable {
    let id: UUID
    let planId: UUID
    let dayNumber: Int
    let title: String
    let scriptureReference: String
    let reflection: String?
    let sections: PlanSections

    enum CodingKeys: String, CodingKey {
        case id, title, reflection, sections
        case planId             = "plan_id"
        case dayNumber          = "day_number"
        case scriptureReference = "scripture_reference"
    }
}

struct PlanSections: Decodable, Hashable {
    let read:     ReadSection
    let study:    StudySection
    let apply:    ApplySection
    // `give` is dropped from the iOS flow. Older plan-day JSON may
    // still include a `"give": {...}` key — Swift's synthesized
    // Decodable ignores unknown keys, so no migration is needed.
    let memorize: MemorizeSection
    let pray:     PraySection
}

struct ReadSection: Decodable, Hashable {
    let parts: [ReadPart]
}

struct ReadPart: Decodable, Hashable {
    let verses: String
    let question: String
    let options: [String]
    let correctIndex: Int
    enum CodingKeys: String, CodingKey {
        case verses, question, options
        case correctIndex = "correct_index"
    }
}

struct StudySection: Decodable, Hashable {
    let commentary: String
    let question: String
    let options: [String]
    let correctIndex: Int
    enum CodingKeys: String, CodingKey {
        case commentary, question, options
        case correctIndex = "correct_index"
    }
}

struct ApplySection: Decodable, Hashable {
    let challenges: [String]
}

struct MemorizeSection: Decodable, Hashable {
    let verseText: String
    let verseReference: String
    enum CodingKeys: String, CodingKey {
        case verseText      = "verse_text"
        case verseReference = "verse_reference"
    }
}

struct PraySection: Decodable, Hashable {
    let prayerText: String
    enum CodingKeys: String, CodingKey { case prayerText = "prayer_text" }
}

struct UserPlanProgress: Identifiable, Decodable, Hashable {
    var id: UUID { dayId }
    let dayId: UUID
    let dayNumber: Int
    let title: String
    let scriptureReference: String
    let reflection: String?
    let dayComplete: Bool
    let stepsCompleted: [String]
    let dayXpEarned: Int
    let dayCompletedAt: Date?

    var stepsDone: Set<PlanStep> {
        Set(stepsCompleted.compactMap { PlanStep(rawValue: $0) })
    }

    enum CodingKeys: String, CodingKey {
        case dayId              = "day_id"
        case dayNumber          = "day_number"
        case title
        case scriptureReference = "scripture_reference"
        case reflection
        case dayComplete        = "day_complete"
        case stepsCompleted     = "steps_completed"
        case dayXpEarned        = "day_xp_earned"
        case dayCompletedAt     = "day_completed_at"
    }
}

struct ContinueCard: Codable, Hashable {
    let planId: UUID
    let planTitle: String
    let planSlug: String
    let planGradientFrom: String
    let planGradientTo: String
    let daysTotal: Int
    let dayId: UUID
    let dayNumber: Int
    let dayTitle: String
    let scriptureReference: String
    let stepsCompleted: [String]
    let isResume: Bool

    enum CodingKeys: String, CodingKey {
        case daysTotal          = "days_total"
        case planId             = "plan_id"
        case planTitle          = "plan_title"
        case planSlug           = "plan_slug"
        case planGradientFrom   = "plan_gradient_from"
        case planGradientTo     = "plan_gradient_to"
        case dayId              = "day_id"
        case dayNumber          = "day_number"
        case dayTitle           = "day_title"
        case scriptureReference = "scripture_reference"
        case stepsCompleted     = "steps_completed"
        case isResume           = "is_resume"
    }

    /// Defensive decode — the `get_continue_card` RPC can omit fields like
    /// plan_slug / plan_gradient_* when the in-progress plan is missing
    /// those columns (older rows). Don't drop the whole row over that.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.planId             = try c.decode(UUID.self, forKey: .planId)
        self.dayId              = try c.decode(UUID.self, forKey: .dayId)
        self.planTitle          = (try? c.decode(String.self, forKey: .planTitle)) ?? "Plan"
        self.planSlug           = (try? c.decode(String.self, forKey: .planSlug)) ?? planId.uuidString.lowercased()
        self.planGradientFrom   = (try? c.decode(String.self, forKey: .planGradientFrom)) ?? "6B2BFF"
        self.planGradientTo     = (try? c.decode(String.self, forKey: .planGradientTo)) ?? "FF3DA5"
        self.daysTotal          = (try? c.decode(Int.self,    forKey: .daysTotal)) ?? 0
        self.dayNumber          = (try? c.decode(Int.self,    forKey: .dayNumber)) ?? 1
        self.dayTitle           = (try? c.decode(String.self, forKey: .dayTitle)) ?? "Day \(dayNumber)"
        self.scriptureReference = (try? c.decode(String.self, forKey: .scriptureReference)) ?? ""
        self.stepsCompleted     = (try? c.decode([String].self, forKey: .stepsCompleted)) ?? []
        self.isResume           = (try? c.decode(Bool.self,   forKey: .isResume)) ?? false
    }
}

struct StepCompletionResult: Decodable {
    let alreadyCompleted: Bool
    let step: String
    let stepXp: Int
    let stepWater: Int
    let stepsDone: Int
    let dayNowComplete: Bool
    let dailyBonusXp: Int
    let dailyBonusWater: Int
    let milestoneHit: Int?
    let milestoneXp: Int
    let milestoneWater: Int
    let planCompleted: Bool
    let planCompletionXp: Int
    let planCompletionWater: Int
    let newStreak: Int?
    /// `var` so iOS can overlay the locally-accumulated day total
    /// when the server's `complete_plan_step` RPC undercounts step XP
    /// in the final response. See `DailyPlanView.submit`.
    var totalXpAwarded: Int
    var totalWaterAwarded: Int

    enum CodingKeys: String, CodingKey {
        case alreadyCompleted    = "already_completed"
        case step
        case stepXp              = "step_xp"
        case stepWater           = "step_water"
        case stepsDone           = "steps_done"
        case dayNowComplete      = "day_now_complete"
        case dailyBonusXp        = "daily_bonus_xp"
        case dailyBonusWater     = "daily_bonus_water"
        case milestoneHit        = "milestone_hit"
        case milestoneXp         = "milestone_xp"
        case milestoneWater      = "milestone_water"
        case planCompleted       = "plan_completed"
        case planCompletionXp    = "plan_completion_xp"
        case planCompletionWater = "plan_completion_water"
        case newStreak           = "new_streak"
        case totalXpAwarded      = "total_xp_awarded"
        case totalWaterAwarded   = "total_water_awarded"
    }
}
