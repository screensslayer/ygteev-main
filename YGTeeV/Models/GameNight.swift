//
//  GameNight.swift
//  YGTeeV
//
//  Models backing the home Games tab + immersive play flow. Mirrors
//  the gn_* RPC surface: a room (status-driven state machine), the
//  player roster that flows in over Realtime, the discovery payload
//  the tab shows when there's nothing actively going, and the recent
//  finished-game rows the parent tab lists.
//
//  Decoders are intentionally tolerant — the backend evolves and we'd
//  rather render a partial state than fail to decode a live room.
//

import Foundation

// MARK: - Game catalogue

/// The three game types in v1. Only `.majorityRules` is playable from
/// the iOS client right now; the other two render as "Coming soon" in
/// the Recent list per scope decisions.
enum GameType: String, Codable {
    case majorityRules = "majority_rules"
    case spend15       = "spend_15"
    case chainLink     = "chain_link"

    /// Defensive decoder so an unknown game_type string from the
    /// server doesn't crash the whole discovery payload — falls back
    /// to .majorityRules so the room is at least listable.
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = try c.decode(String.self)
        self = GameType(rawValue: raw) ?? .majorityRules
    }

    var displayName: String {
        switch self {
        case .majorityRules: return "Majority Rules"
        case .spend15:       return "Spend $15"
        case .chainLink:     return "Chain Link Battle"
        }
    }

    var emoji: String {
        switch self {
        case .majorityRules: return "🗳️"
        case .spend15:       return "🛒"
        case .chainLink:     return "🔗"
        }
    }

    /// True iff the iOS client supports this game's play flow today.
    /// `false` games still render in Recent but are tappable to a
    /// "coming soon" affordance only.
    var isPlayable: Bool { self == .majorityRules }
}

// MARK: - Room status (state machine)

/// Mirrors gn_rooms.status. The immersive play flow re-renders off
/// this value as it changes via Realtime, so a stale enum case won't
/// trap the user in a dead screen — unknown statuses degrade to
/// `.lobby` (the safest "waiting" state).
enum GameRoomStatus: String, Codable {
    case lobby
    case inGame   = "in_game"
    case reveal
    case finished

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = try c.decode(String.self)
        self = GameRoomStatus(rawValue: raw) ?? .lobby
    }
}

// MARK: - Question / choice payload

/// Per-question payload carried on `gn_rooms.question_data`. Majority
/// Rules ships two choices labelled A / B; we model that directly so
/// the in-game view can lay them out side-by-side. Other game types
/// will add their own shapes here later.
struct GameQuestion: Decodable, Hashable {
    let prompt: String?
    let choices: [GameChoice]
    let index: Int?
    let total: Int?

    enum CodingKeys: String, CodingKey {
        case prompt, choices
        case index = "question_index"
        case total = "total_questions"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        prompt  = try c.decodeIfPresent(String.self, forKey: .prompt)
        choices = (try? c.decodeIfPresent([GameChoice].self, forKey: .choices)) ?? []
        index   = try c.decodeIfPresent(Int.self, forKey: .index)
        total   = try c.decodeIfPresent(Int.self, forKey: .total)
    }
}

struct GameChoice: Decodable, Hashable, Identifiable {
    /// Server-side stable id ("A"/"B" or a uuid). Used as the value
    /// posted back on submit_answer.
    let id: String
    let label: String
    let emoji: String?

    enum CodingKeys: String, CodingKey {
        case id, label, emoji
        case key
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Some payloads use `id`, some use `key`. Accept either.
        if let direct = try c.decodeIfPresent(String.self, forKey: .id) {
            id = direct
        } else {
            id = (try c.decodeIfPresent(String.self, forKey: .key)) ?? UUID().uuidString
        }
        label = (try c.decodeIfPresent(String.self, forKey: .label)) ?? ""
        emoji = try c.decodeIfPresent(String.self, forKey: .emoji)
    }
}

// MARK: - Reveal payload

/// `gn_rooms.reveal_data` shape. Carries the per-question reveal info
/// while status = reveal, then the final podium when status = finished.
struct GameRevealData: Decodable, Hashable {
    /// Which choice the crowd actually picked (Majority Rules).
    let crowdChoiceId: String?
    /// Whether the caller earned points on this question.
    let myCorrect: Bool?
    /// Points awarded for this question.
    let myPointsDelta: Int?
    /// Final podium (only present when status = finished).
    let podium: [GamePlayerSummary]?
    /// XP delta the server credited the caller at game end.
    let myXpDelta: Int?

    enum CodingKeys: String, CodingKey {
        case crowdChoiceId  = "crowd_choice_id"
        case myCorrect      = "my_correct"
        case myPointsDelta  = "my_points_delta"
        case podium
        case myXpDelta      = "my_xp_delta"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        crowdChoiceId = try c.decodeIfPresent(String.self, forKey: .crowdChoiceId)
        myCorrect     = try c.decodeIfPresent(Bool.self, forKey: .myCorrect)
        myPointsDelta = try c.decodeIfPresent(Int.self, forKey: .myPointsDelta)
        podium        = try c.decodeIfPresent([GamePlayerSummary].self, forKey: .podium)
        myXpDelta     = try c.decodeIfPresent(Int.self, forKey: .myXpDelta)
    }
}

// MARK: - GameRoom

/// Single source of truth for the live room. Driven by initial fetch
/// (`gn_member_active_game` / `gn_member_join`) and kept fresh by a
/// Realtime subscription on `gn_rooms` filtered by id.
struct GameRoom: Decodable, Identifiable, Hashable {
    let id: UUID
    let groupId: UUID?
    let code: String?
    let gameType: GameType
    let status: GameRoomStatus
    let currentQuestionIndex: Int?
    let totalQuestions: Int?
    let questionData: GameQuestion?
    let revealData: GameRevealData?
    let startsAt: Date?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case groupId               = "group_id"
        case code
        case gameType              = "game_type"
        case status
        case currentQuestionIndex  = "current_question_index"
        case totalQuestions        = "total_questions"
        case questionData          = "question_data"
        case revealData            = "reveal_data"
        case startsAt              = "starts_at"
        case createdAt             = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                   = try c.decode(UUID.self, forKey: .id)
        groupId              = try c.decodeIfPresent(UUID.self, forKey: .groupId)
        code                 = try c.decodeIfPresent(String.self, forKey: .code)
        gameType             = (try? c.decodeIfPresent(GameType.self, forKey: .gameType)) ?? .majorityRules
        status               = (try? c.decodeIfPresent(GameRoomStatus.self, forKey: .status)) ?? .lobby
        currentQuestionIndex = try c.decodeIfPresent(Int.self, forKey: .currentQuestionIndex)
        totalQuestions       = try c.decodeIfPresent(Int.self, forKey: .totalQuestions)
        questionData         = try c.decodeIfPresent(GameQuestion.self, forKey: .questionData)
        revealData           = try c.decodeIfPresent(GameRevealData.self, forKey: .revealData)
        startsAt             = try c.decodeIfPresent(Date.self, forKey: .startsAt)
        createdAt            = try c.decodeIfPresent(Date.self, forKey: .createdAt)
    }
}

// MARK: - GamePlayer

/// Single roster entry in the live room. Updated via Realtime as
/// players join, lock answers, and have scores reconciled at reveal.
struct GamePlayer: Decodable, Identifiable, Hashable {
    let id: UUID
    let roomId: UUID
    let userId: UUID?
    let nickname: String?
    let avatarUrl: String?
    let score: Int
    let placement: Int?
    let locked: Bool
    let joinedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case roomId    = "room_id"
        case userId    = "user_id"
        case nickname
        case avatarUrl = "avatar_url"
        case score
        case placement
        case locked
        case joinedAt  = "joined_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(UUID.self, forKey: .id)
        roomId    = try c.decode(UUID.self, forKey: .roomId)
        userId    = try c.decodeIfPresent(UUID.self, forKey: .userId)
        nickname  = try c.decodeIfPresent(String.self, forKey: .nickname)
        avatarUrl = try c.decodeIfPresent(String.self, forKey: .avatarUrl)
        score     = try c.decodeIfPresent(Int.self, forKey: .score) ?? 0
        placement = try c.decodeIfPresent(Int.self, forKey: .placement)
        locked    = try c.decodeIfPresent(Bool.self, forKey: .locked) ?? false
        joinedAt  = try c.decodeIfPresent(Date.self, forKey: .joinedAt)
    }
}

/// Lightweight player projection used in podium / leaderboard
/// payloads. Same shape as GamePlayer but score is the ONLY required
/// numeric and id is optional (final boards sometimes carry only
/// nickname + score).
struct GamePlayerSummary: Decodable, Hashable, Identifiable {
    let id: String
    let nickname: String?
    let avatarUrl: String?
    let score: Int
    let placement: Int?
    let isMe: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case nickname
        case avatarUrl = "avatar_url"
        case score
        case placement
        case isMe = "is_me"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try? c.decodeIfPresent(String.self, forKey: .id) {
            id = s
        } else {
            id = UUID().uuidString
        }
        nickname  = try c.decodeIfPresent(String.self, forKey: .nickname)
        avatarUrl = try c.decodeIfPresent(String.self, forKey: .avatarUrl)
        score     = try c.decodeIfPresent(Int.self, forKey: .score) ?? 0
        placement = try c.decodeIfPresent(Int.self, forKey: .placement)
        isMe      = try c.decodeIfPresent(Bool.self, forKey: .isMe) ?? false
    }
}

// MARK: - Discovery: active game

/// Response shape for `gn_member_active_game(p_group)`. The RPC returns
/// at most one row describing the group's currently-active room
/// (lobby / in_game / reveal). Carries enough context for the hero
/// card to render without an extra round trip to gn_rooms.
struct ActiveGame: Decodable, Identifiable, Hashable {
    var id: UUID { roomId }
    let roomId: UUID
    let groupId: UUID?
    let groupName: String?
    let groupLogoUrl: String?
    let code: String?
    let gameType: GameType
    let status: GameRoomStatus
    let playerCount: Int
    let currentQuestionIndex: Int?
    let totalQuestions: Int?
    /// When status == .lobby, the server-stamped scheduled start.
    /// Used to render the countdown clock on the hero card.
    let startsAt: Date?

    enum CodingKeys: String, CodingKey {
        case roomId               = "room_id"
        case groupId              = "group_id"
        case groupName            = "group_name"
        case groupLogoUrl         = "group_logo_url"
        case code
        case gameType             = "game_type"
        case status
        case playerCount          = "player_count"
        case currentQuestionIndex = "current_question_index"
        case totalQuestions       = "total_questions"
        case startsAt             = "starts_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        roomId               = try c.decode(UUID.self, forKey: .roomId)
        groupId              = try c.decodeIfPresent(UUID.self, forKey: .groupId)
        groupName            = try c.decodeIfPresent(String.self, forKey: .groupName)
        groupLogoUrl         = try c.decodeIfPresent(String.self, forKey: .groupLogoUrl)
        code                 = try c.decodeIfPresent(String.self, forKey: .code)
        gameType             = (try? c.decodeIfPresent(GameType.self, forKey: .gameType)) ?? .majorityRules
        status               = (try? c.decodeIfPresent(GameRoomStatus.self, forKey: .status)) ?? .lobby
        playerCount          = try c.decodeIfPresent(Int.self, forKey: .playerCount) ?? 0
        currentQuestionIndex = try c.decodeIfPresent(Int.self, forKey: .currentQuestionIndex)
        totalQuestions       = try c.decodeIfPresent(Int.self, forKey: .totalQuestions)
        startsAt             = try c.decodeIfPresent(Date.self, forKey: .startsAt)
    }
}

// MARK: - Discovery: recent games

/// Response shape for `gn_member_recent_games(p_group, p_limit)`. One
/// row per finished game the caller participated in.
struct RecentGame: Decodable, Identifiable, Hashable {
    var id: UUID { roomId }
    let roomId: UUID
    let gameType: GameType
    let endedAt: Date?
    let myPlacement: Int?
    let myXpDelta: Int?
    let playerCount: Int

    enum CodingKeys: String, CodingKey {
        case roomId      = "room_id"
        case gameType    = "game_type"
        case endedAt     = "ended_at"
        case myPlacement = "my_placement"
        case myXpDelta   = "my_xp_delta"
        case playerCount = "player_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        roomId       = try c.decode(UUID.self, forKey: .roomId)
        gameType     = (try? c.decodeIfPresent(GameType.self, forKey: .gameType)) ?? .majorityRules
        endedAt      = try c.decodeIfPresent(Date.self, forKey: .endedAt)
        myPlacement  = try c.decodeIfPresent(Int.self, forKey: .myPlacement)
        myXpDelta    = try c.decodeIfPresent(Int.self, forKey: .myXpDelta)
        playerCount  = try c.decodeIfPresent(Int.self, forKey: .playerCount) ?? 0
    }
}
