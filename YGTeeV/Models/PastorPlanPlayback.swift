//
//  PastorPlanPlayback.swift
//  YGTeeV
//
//  Member-side playback models for pastor-published plans. Mirrors:
//    • get_my_youth_group_plans(_filter)
//    • get_my_plan_day_progress(_plan_id)
//    • complete_pastor_plan_day(_plan_id, _day_number, _answers)
//

import Foundation

// MARK: - YouthGroupPlanRow

/// A pastor-published plan a member can see in the "From [Group]" section.
struct YouthGroupPlanRow: Decodable, Identifiable, Hashable {
    let planId: UUID
    let title: String
    let groupId: UUID
    let groupName: String
    let daysTotal: Int
    let daysCompleted: Int
    let isCompleted: Bool
    let completedAt: Date?
    let gradientIndex: Int
    let headerKind: String
    let headerImageURL: String?
    let xpReward: Int
    let waterReward: Int
    let visibility: String
    let publishedAt: Date?

    var id: UUID { planId }

    enum CodingKeys: String, CodingKey {
        case planId         = "plan_id"
        case title
        case groupId        = "group_id"
        case groupName      = "group_name"
        case daysTotal      = "days_total"
        case daysCompleted  = "days_completed"
        case isCompleted    = "is_completed"
        case completedAt    = "completed_at"
        case gradientIndex  = "gradient_index"
        case headerKind     = "header_kind"
        case headerImageURL = "header_image_url"
        case xpReward       = "xp_reward"
        case waterReward    = "water_reward"
        case visibility
        case publishedAt    = "published_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.planId         = try c.decode(UUID.self, forKey: .planId)
        self.title          = (try? c.decode(String.self, forKey: .title)) ?? "Untitled plan"
        self.groupId        = (try? c.decode(UUID.self, forKey: .groupId)) ?? UUID()
        self.groupName      = (try? c.decode(String.self, forKey: .groupName)) ?? ""
        self.daysTotal      = (try? c.decode(Int.self,    forKey: .daysTotal)) ?? 0
        self.daysCompleted  = (try? c.decode(Int.self,    forKey: .daysCompleted)) ?? 0
        self.isCompleted    = (try? c.decode(Bool.self,   forKey: .isCompleted)) ?? false
        self.completedAt    = try? c.decode(Date.self,   forKey: .completedAt)
        self.gradientIndex  = (try? c.decode(Int.self,    forKey: .gradientIndex)) ?? 0
        self.headerKind     = (try? c.decode(String.self, forKey: .headerKind)) ?? "gradient"
        self.headerImageURL = try? c.decode(String.self, forKey: .headerImageURL)
        self.xpReward       = (try? c.decode(Int.self,    forKey: .xpReward)) ?? 0
        self.waterReward    = (try? c.decode(Int.self,    forKey: .waterReward)) ?? 0
        self.visibility     = (try? c.decode(String.self, forKey: .visibility)) ?? "private"
        self.publishedAt    = try? c.decode(Date.self,   forKey: .publishedAt)
    }
}

// MARK: - PlanDayProgress

struct PlanDayProgress: Decodable, Identifiable, Hashable {
    let dayId: UUID
    let dayNumber: Int
    let title: String
    let scriptureReference: String
    let blockCount: Int
    let isCompleted: Bool
    let completedAt: Date?
    let stepXpEarned: Int
    let stepWaterEarned: Int

    var id: UUID { dayId }

    enum CodingKeys: String, CodingKey {
        case dayId              = "day_id"
        case dayNumber          = "day_number"
        case title
        case scriptureReference = "scripture_reference"
        case blockCount         = "block_count"
        case isCompleted        = "is_completed"
        case completedAt        = "completed_at"
        case stepXpEarned       = "step_xp_earned"
        case stepWaterEarned    = "step_water_earned"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.dayId              = try c.decode(UUID.self, forKey: .dayId)
        self.dayNumber          = (try? c.decode(Int.self, forKey: .dayNumber)) ?? 1
        self.title              = (try? c.decode(String.self, forKey: .title)) ?? "Day"
        self.scriptureReference = (try? c.decode(String.self, forKey: .scriptureReference)) ?? ""
        self.blockCount         = (try? c.decode(Int.self, forKey: .blockCount)) ?? 0
        self.isCompleted        = (try? c.decode(Bool.self, forKey: .isCompleted)) ?? false
        self.completedAt        = try? c.decode(Date.self, forKey: .completedAt)
        self.stepXpEarned       = (try? c.decode(Int.self, forKey: .stepXpEarned)) ?? 0
        self.stepWaterEarned    = (try? c.decode(Int.self, forKey: .stepWaterEarned)) ?? 0
    }
}

// MARK: - Day-complete RPC payloads

struct DayAnswerPayload: Encodable {
    let block_id: String
    let selected_index: Int
}

struct DayCompletionResult: Decodable {
    let alreadyCompleted: Bool
    let dayId: UUID
    let dayXp: Int
    let dayWater: Int
    let correctCount: Int
    let dailyBonusXp: Int
    let dailyBonusWater: Int
    let milestoneHit: Int?
    let milestoneXp: Int
    let milestoneWater: Int
    let planCompleted: Bool
    let planCompletionXp: Int
    let planCompletionWater: Int
    let newStreak: Int
    let totalXpAwarded: Int
    let totalWaterAwarded: Int

    enum CodingKeys: String, CodingKey {
        case alreadyCompleted    = "already_completed"
        case dayId               = "day_id"
        case dayXp               = "day_xp"
        case dayWater            = "day_water"
        case correctCount        = "correct_count"
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

// MARK: - Day blocks (read from bible_plan_days.sections.blocks)

/// Lightweight playback view of a day's authored blocks. Server stores them
/// at `bible_plan_days.sections.blocks` as a jsonb array. Decoded directly
/// from that array — discriminator is the `type` field (matches BlockKind).
struct PastorPlanDayPayload: Decodable, Hashable {
    let id: UUID
    let dayNumber: Int
    let title: String
    let scriptureReference: String
    let blocks: [Block]

    enum CodingKeys: String, CodingKey {
        case id
        case dayNumber          = "day_number"
        case title
        case scriptureReference = "scripture_reference"
        case sections
    }

    private enum SectionsKeys: String, CodingKey { case blocks }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id                 = try c.decode(UUID.self, forKey: .id)
        self.dayNumber          = (try? c.decode(Int.self, forKey: .dayNumber)) ?? 1
        self.title              = (try? c.decode(String.self, forKey: .title)) ?? "Day"
        self.scriptureReference = (try? c.decode(String.self, forKey: .scriptureReference)) ?? ""

        // sections is a nested object: { "blocks": [...] }
        if let sectionsContainer = try? c.nestedContainer(keyedBy: SectionsKeys.self, forKey: .sections),
           let blocks = try? sectionsContainer.decode([Block].self, forKey: .blocks) {
            self.blocks = blocks
        } else {
            self.blocks = []
        }
    }
}
