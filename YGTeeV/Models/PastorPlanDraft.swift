//
//  PastorPlanDraft.swift
//  YGTeeV
//
//  Client-side types for the pastor "Publish a Bible plan" flow.
//

import Foundation
import SwiftUI

enum HeaderKind: String, Codable, Hashable {
    case gradient
    case photo
}

/// Who can see a published plan.
/// - `private`: only members of the pastor's youth group (default)
/// - `public`:  anyone on YGTeeV
enum PlanVisibility: String, Codable, Hashable, CaseIterable {
    case `private`
    case `public`

    var label: String {
        switch self {
        case .private: return "Private"
        case .public:  return "Public"
        }
    }
}

/// One youth group the caller pastors. Backed by the `pastor_my_groups()` RPC.
struct PastorGroup: Identifiable, Decodable, Hashable {
    let id: UUID
    let name: String
    let memberCount: Int
    /// Optional so older `pastor_my_groups()` payloads that don't yet
    /// return `address` still decode. Once the RPC is updated, this
    /// just starts populating.
    let address: String?

    enum CodingKeys: String, CodingKey {
        case id          = "group_id"
        case name
        case memberCount = "member_count"
        case address
    }
}

// MARK: - Header gradient palette

/// 5-entry gradient palette matching pastor-plan-create.jsx (HEADER_GRADS).
/// We store only the index 0..4 server-side; this drives rendering.
enum PlanHeaderGradient {
    static let palette: [(start: Color, end: Color)] = [
        (Color(hex: "6B2BFF"), Color(hex: "FF3DA5")),
        (Color(hex: "0066FF"), Color(hex: "00E0FF")),
        (Color(hex: "FF6B35"), Color(hex: "FFD60A")),
        (Color(hex: "B4FF3C"), Color(hex: "2B8A3E")),
        (Color(hex: "FFD60A"), Color(hex: "FF3DA5"))
    ]

    static func gradient(at index: Int) -> LinearGradient {
        let safe = max(0, min(palette.count - 1, index))
        let (s, e) = palette[safe]
        return LinearGradient(colors: [s, e], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Block

/// One unit of a plan day. Encodes/decodes as
/// `{"type": "reading", ...}` with a discriminator on `type` to match
/// the backend's `jsonb` block array contract.
enum Block: Identifiable, Hashable {
    case reading(id: UUID = UUID(),
                 verses: String)
    case commentary(id: UUID = UUID(),
                    title: String,
                    body: String)
    case video(id: UUID = UUID(),
               title: String,
               url: String,
               durationSeconds: Int?,
               videoId: UUID? = nil)
    case question(id: UUID = UUID(),
                  prompt: String,
                  options: [String],
                  correctIndex: Int)
    case prayer(id: UUID = UUID(),
                title: String,
                body: String,
                durationMinutes: Int?)

    var id: UUID {
        switch self {
        case .reading(let id, _),
             .commentary(let id, _, _),
             .video(let id, _, _, _, _),
             .question(let id, _, _, _),
             .prayer(let id, _, _, _):
            return id
        }
    }

    /// Lightweight discriminator without unwrapping associated values.
    var kind: BlockKind {
        switch self {
        case .reading:    return .reading
        case .commentary: return .commentary
        case .video:      return .video
        case .question:   return .question
        case .prayer:     return .prayer
        }
    }

    /// "Has any non-empty content" — used by the status pill on screen 7
    /// to distinguish Ready from Draft.
    var hasContent: Bool {
        switch self {
        case .reading(_, let v):
            return !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .commentary(_, let t, let b):
            return !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !b.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .video(_, let t, let url, _, let vid):
            // Has content if a title is set AND we have either a pasted
            // URL OR a Mux video_id (the latter resolves to a URL on
            // playback once Mux finishes encoding).
            return !t.isEmpty && (!url.isEmpty || vid != nil)
        case .question(_, let p, let opts, let correct):
            return !p.isEmpty
                && opts.count >= 2
                && opts.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                && (0..<opts.count).contains(correct)
        case .prayer(_, let t, let b, _):
            return !t.isEmpty && !b.isEmpty
        }
    }
}

enum BlockKind: String, Codable, CaseIterable, Hashable {
    case reading, commentary, video, question, prayer

    var label: String {
        switch self {
        case .reading:    return "Bible reading"
        case .commentary: return "Commentary"
        case .video:      return "Video"
        case .question:   return "Question (MCQ)"
        case .prayer:     return "Prayer prompt"
        }
    }

    var icon: String {
        switch self {
        case .reading:    return "📖"
        case .commentary: return "✍️"
        case .video:      return "🎥"
        case .question:   return "❓"
        case .prayer:     return "🙏"
        }
    }

    var accent: Color {
        switch self {
        case .reading:    return Color(hex: "1A1330")
        case .commentary: return Color(hex: "0066FF")
        case .video:      return Color(hex: "FF3DA5")
        case .question:   return Color(hex: "B8860B")
        case .prayer:     return Color(hex: "6B2BFF")
        }
    }

    var tint: Color {
        switch self {
        case .reading:    return Color(hex: "F0EDF8")
        case .commentary: return Color(hex: "E6F0FF")
        case .video:      return Color(hex: "FFE5F2")
        case .question:   return Color(hex: "FFF6CC")
        case .prayer:     return Color(hex: "EFE6FF")
        }
    }
}

extension Block: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, type
        // reading
        case verses
        // commentary / prayer
        case title, body
        // video
        case url
        case duration_seconds
        case video_id
        // question
        case prompt, options, correct_index
        // prayer
        case duration_minutes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let typeRaw = try c.decode(String.self, forKey: .type)
        guard let kind = BlockKind(rawValue: typeRaw) else {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: c,
                debugDescription: "Unknown block type: \(typeRaw)"
            )
        }
        let id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()

        switch kind {
        case .reading:
            let verses = try c.decode(String.self, forKey: .verses)
            self = .reading(id: id, verses: verses)
        case .commentary:
            let title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
            let body  = try c.decodeIfPresent(String.self, forKey: .body)  ?? ""
            self = .commentary(id: id, title: title, body: body)
        case .video:
            let title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
            let url   = try c.decodeIfPresent(String.self, forKey: .url)   ?? ""
            let dur   = try c.decodeIfPresent(Int.self,    forKey: .duration_seconds)
            let vid   = try c.decodeIfPresent(UUID.self,   forKey: .video_id)
            self = .video(id: id, title: title, url: url, durationSeconds: dur, videoId: vid)
        case .question:
            let prompt = try c.decode(String.self,   forKey: .prompt)
            let opts   = try c.decode([String].self, forKey: .options)
            let correct = try c.decode(Int.self,     forKey: .correct_index)
            self = .question(id: id, prompt: prompt, options: opts, correctIndex: correct)
        case .prayer:
            let title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
            let body  = try c.decodeIfPresent(String.self, forKey: .body)  ?? ""
            let dur   = try c.decodeIfPresent(Int.self,    forKey: .duration_minutes)
            self = .prayer(id: id, title: title, body: body, durationMinutes: dur)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(kind.rawValue, forKey: .type)
        try c.encode(id, forKey: .id)
        switch self {
        case .reading(_, let verses):
            try c.encode(verses, forKey: .verses)
        case .commentary(_, let title, let body):
            try c.encode(title, forKey: .title)
            try c.encode(body,  forKey: .body)
        case .video(_, let title, let url, let dur, let videoId):
            try c.encode(title, forKey: .title)
            try c.encode(url,   forKey: .url)
            try c.encodeIfPresent(dur,     forKey: .duration_seconds)
            try c.encodeIfPresent(videoId, forKey: .video_id)
        case .question(_, let prompt, let options, let correct):
            try c.encode(prompt,  forKey: .prompt)
            try c.encode(options, forKey: .options)
            try c.encode(correct, forKey: .correct_index)
        case .prayer(_, let title, let body, let dur):
            try c.encode(title, forKey: .title)
            try c.encode(body,  forKey: .body)
            try c.encodeIfPresent(dur, forKey: .duration_minutes)
        }
    }
}

// MARK: - Day & draft

struct PlanDay: Identifiable, Hashable {
    let id: UUID
    var planId: UUID
    var dayNumber: Int
    var title: String
    var scriptureRef: String
    var blocks: [Block]

    var questionCount: Int {
        blocks.reduce(0) { acc, b in
            if case .question = b { return acc + 1 }
            return acc
        }
    }

    var dailyXP: Int   { 500 + (questionCount * 50) }
    var dailyWater: Int { 4 }

    var status: DayStatus {
        if blocks.isEmpty { return .empty }
        if blocks.allSatisfy(\.hasContent) { return .ready }
        return .draft
    }
}

enum DayStatus {
    case ready, draft, empty

    var label: String {
        switch self {
        case .ready: return "Ready"
        case .draft: return "Draft"
        case .empty: return "Empty"
        }
    }

    var color: Color {
        switch self {
        case .ready: return Color(hex: "2B8A3E")
        case .draft: return Color(hex: "B8860B")
        case .empty: return Color(hex: "0A0712").opacity(0.5)
        }
    }

    var tint: Color {
        switch self {
        case .ready: return Color(hex: "B4FF3C").opacity(0.18)
        case .draft: return Color(hex: "FFD60A").opacity(0.20)
        case .empty: return Color(hex: "0A0712").opacity(0.06)
        }
    }
}

/// Row returned by the `pastor_list_my_plans()` RPC. Includes counts and
/// totals computed server-side. Fields are optional/defaulted so a column
/// rename doesn't crash the whole list.
struct PastorPlanSummary: Identifiable, Decodable, Hashable {
    let id: UUID
    let groupId: UUID?
    let groupName: String?
    /// Extra youth groups this same plan is also assigned to. Primary
    /// group still lives in `groupId`; this is the additional set.
    let additionalGroupIds: [UUID]
    let title: String
    let status: String  // "draft" | "published" | "archived"
    let visibility: PlanVisibility
    let daysTotal: Int
    let readyDayCount: Int
    let totalBlocks: Int
    let xpReward: Int
    let waterReward: Int
    let startedCount: Int
    let completedCount: Int
    let gradientIdx: Int?
    let headerKind: HeaderKind?
    let headerImageURL: String?
    let createdAt: Date?
    let updatedAt: Date?
    let publishedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id                = "plan_id"
        case groupId           = "group_id"
        case groupName         = "group_name"
        case additionalGroupIds = "additional_group_ids"
        case title, status, visibility
        case daysTotal         = "days_total"
        case readyDayCount     = "ready_day_count"
        case totalBlocks       = "total_blocks"
        case xpReward          = "xp_reward"
        case waterReward       = "water_reward"
        case startedCount      = "started_count"
        case completedCount    = "completed_count"
        case gradientIdx       = "gradient_index"
        case headerKind        = "header_kind"
        case headerImageURL    = "header_image_url"
        case createdAt         = "created_at"
        case updatedAt         = "updated_at"
        case publishedAt       = "published_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id              = try c.decode(UUID.self, forKey: .id)
        self.groupId         = try? c.decode(UUID.self,   forKey: .groupId)
        self.groupName       = try? c.decode(String.self, forKey: .groupName)
        // Legacy rows or older RPC versions: default to empty array so
        // the multi-group UI still works without redeployment.
        self.additionalGroupIds = (try? c.decode([UUID].self, forKey: .additionalGroupIds)) ?? []
        self.title           = (try? c.decode(String.self, forKey: .title)) ?? "Untitled plan"
        self.status          = (try? c.decode(String.self, forKey: .status)) ?? "draft"
        self.visibility      = (try? c.decode(String.self, forKey: .visibility))
                                  .flatMap(PlanVisibility.init(rawValue:)) ?? .private
        self.daysTotal       = (try? c.decode(Int.self,    forKey: .daysTotal)) ?? 0
        self.readyDayCount   = (try? c.decode(Int.self,    forKey: .readyDayCount)) ?? 0
        self.totalBlocks     = (try? c.decode(Int.self,    forKey: .totalBlocks)) ?? 0
        self.xpReward        = (try? c.decode(Int.self,    forKey: .xpReward)) ?? 0
        self.waterReward     = (try? c.decode(Int.self,    forKey: .waterReward)) ?? 0
        self.startedCount    = (try? c.decode(Int.self,    forKey: .startedCount)) ?? 0
        self.completedCount  = (try? c.decode(Int.self,    forKey: .completedCount)) ?? 0
        self.gradientIdx     = try? c.decode(Int.self,     forKey: .gradientIdx)
        self.headerKind      = (try? c.decode(String.self, forKey: .headerKind)).flatMap(HeaderKind.init(rawValue:))
        self.headerImageURL  = try? c.decode(String.self,  forKey: .headerImageURL)
        self.createdAt       = try? c.decode(Date.self,    forKey: .createdAt)
        self.updatedAt       = try? c.decode(Date.self,    forKey: .updatedAt)
        self.publishedAt     = try? c.decode(Date.self,    forKey: .publishedAt)
    }

    /// Promote to a full editable draft for the overview/builder views.
    var asDraft: BiblePlanDraft {
        BiblePlanDraft(
            id: id,
            groupId: groupId ?? UUID(),  // RPC provides it; fallback only if missing
            additionalGroupIds: additionalGroupIds,
            title: title,
            totalDays: max(daysTotal, 1),
            headerKind: headerKind ?? .gradient,
            headerImageURL: headerImageURL,
            gradientIndex: gradientIdx ?? 0,
            status: status,
            visibility: visibility,
            days: []
        )
    }
}

struct BiblePlanDraft: Identifiable, Hashable {
    let id: UUID
    var groupId: UUID
    /// Additional youth groups this same plan is visible/startable in.
    /// `groupId` stays the canonical primary; this list is the extras.
    var additionalGroupIds: [UUID] = []
    var title: String
    var totalDays: Int
    var headerKind: HeaderKind
    var headerImageURL: String?
    var gradientIndex: Int
    var status: String              // 'draft' | 'published' | 'archived'
    var visibility: PlanVisibility = .private
    var days: [PlanDay]             // not always populated; lazy-loaded per day

    var totalQuestions: Int { days.reduce(0) { $0 + $1.questionCount } }
    var totalBlocks: Int    { days.reduce(0) { $0 + $1.blocks.count } }
    var totalXP: Int        { totalDays * 500 + totalQuestions * 50 }
    var totalWater: Int     { totalDays * 4 }
}
