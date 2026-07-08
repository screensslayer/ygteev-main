//
//  GamesLibraryService.swift
//  YGTeeV
//
//  Pastor-side Games Library: a votable catalog of youth-group games
//  (browse / vote / open detail) plus the entry point to create + start
//  a live Majority Rules room for the pastor's group.
//
//  This is intentionally SEPARATE from `GamesService`. That service
//  owns the *live play* surface (gn_member_* RPCs + Realtime). This
//  one is a thin client over the read/write `gl_*` RPC family and the
//  two pastor-side `gn_pastor_*` RPCs used to spin a room up.
//
//  Server contracts (defined in Supabase):
//    gl_list_games(p_age_group text=nil, p_tag_slugs text[]=nil,
//                  p_sort text='top', p_limit int=200, p_offset int=0)
//      → rows of GameListItem
//    gl_get_game(p_slug text) → jsonb (GameDetail)
//    gl_vote(p_game uuid, p_value int2) → jsonb (VoteResponse)
//      Toggle semantics: re-casting the same value clears the vote.
//    gn_pastor_create_game(p_group uuid, p_game text,
//                          p_settings jsonb='{}',
//                          p_scheduled_start_at timestamptz=nil,
//                          p_mode text='solo')
//      → { room_id, code, host_token }
//    gn_pastor_start(p_room uuid) → gn_rooms row
//
//  emoji / accent_color are NULL for every catalog row right now —
//  see `theme(for:)` for the slug-derived fallback.
//

import Foundation
import Supabase
import SwiftUI

@MainActor
@Observable
final class GamesLibraryService {
    static let shared = GamesLibraryService()
    private let client = SupabaseManager.shared.client

    // MARK: - Browse state

    var games: [GameListItem] = []
    var isLoading = false
    var lastError: String?

    /// Last filter applied. Used by the UI to keep chip + sort state in
    /// sync with what's actually in `games`, and to re-run the same
    /// query on pull-to-refresh.
    var currentAgeGroup: String?
    var currentTagSlugs: [String]?
    var currentSort: SortMode = .top

    // MARK: - Launch state

    var isLaunching = false
    var lastLaunchedCode: String?

    private init() {}

    // MARK: - Sort modes

    enum SortMode: String, CaseIterable, Identifiable {
        case top
        case new
        case az

        var id: String { rawValue }
        var label: String {
            switch self {
            case .top: return "Top"
            case .new: return "New"
            case .az:  return "A–Z"
            }
        }
    }

    // MARK: - Load list

    func loadGames(ageGroup: String? = nil,
                   tagSlugs: [String]? = nil,
                   sort: SortMode = .top) async {
        isLoading = true
        lastError = nil
        currentAgeGroup = ageGroup
        currentTagSlugs = tagSlugs
        currentSort = sort
        defer { isLoading = false }

        struct P: Encodable {
            let p_age_group: String?
            let p_tag_slugs: [String]?
            let p_sort: String
            let p_limit: Int
            let p_offset: Int
        }

        do {
            let rows: [GameListItem] = try await client
                .rpc("gl_list_games",
                     params: P(
                        p_age_group: ageGroup,
                        p_tag_slugs: tagSlugs,
                        p_sort: sort.rawValue,
                        p_limit: 200,
                        p_offset: 0
                     ))
                .execute()
                .value
            self.games = rows
        } catch {
            self.lastError = error.localizedDescription
            print("[GamesLibrary] loadGames error:", error)
        }
    }

    // MARK: - Detail fetch

    func getGame(slug: String) async throws -> GameDetail {
        struct P: Encodable { let p_slug: String }
        let detail: GameDetail = try await client
            .rpc("gl_get_game", params: P(p_slug: slug))
            .execute()
            .value
        return detail
    }

    // MARK: - Vote

    /// Casts (or toggles) a vote. Optimistically updates the list row
    /// in place using the server's authoritative counts on return, so
    /// the UI never shows a stale score after a tap.
    func vote(gameId: UUID, value: Int) async {
        struct P: Encodable {
            let p_game: String
            let p_value: Int
        }
        do {
            let resp: VoteResponse = try await client
                .rpc("gl_vote",
                     params: P(p_game: gameId.uuidString.lowercased(),
                               p_value: value))
                .execute()
                .value
            applyVote(resp)
        } catch {
            print("[GamesLibrary] vote error:", error)
        }
    }

    /// Optimistically apply a vote BEFORE the RPC completes so the
    /// pencil-tap feels instant. Caller passes the new my_vote we're
    /// hoping to land. The server's later response (via `vote(...)`)
    /// will overwrite this with the canonical totals.
    func applyOptimisticVote(gameId: UUID, nextMyVote: Int) {
        guard let idx = games.firstIndex(where: { $0.id == gameId }) else { return }
        var g = games[idx]
        let prev = g.myVote ?? 0
        let delta = nextMyVote - prev
        if delta > 0 { g = g.bumpingUp(by: delta) }
        else if delta < 0 { g = g.bumpingDown(by: -delta) }
        g = g.withMyVote(nextMyVote)
        games[idx] = g
    }

    private func applyVote(_ resp: VoteResponse) {
        guard let idx = games.firstIndex(where: { $0.id == resp.gameId }) else { return }
        games[idx] = games[idx].applying(resp)
    }

    // MARK: - Live launch (Majority Rules)

    /// Creates + starts a Majority Rules room owned by this group.
    /// Returns the human-readable room code so the caller can show it
    /// in a confirmation. Existing Home > Games tab discovery + the
    /// Realtime subscription on `gn_rooms` will surface this room for
    /// members automatically — there's no client-side broadcast here.
    func launchMajorityRules(groupId: UUID) async throws -> String {
        isLaunching = true
        defer { isLaunching = false }

        struct CreateP: Encodable {
            let p_group: String
            let p_game: String
            let p_mode: String
        }
        let createRows: [CreateGameRow] = try await client
            .rpc("gn_pastor_create_game",
                 params: CreateP(
                    p_group: groupId.uuidString.lowercased(),
                    p_game: "majority_rules",
                    p_mode: "solo"
                 ))
            .execute()
            .value
        guard let created = createRows.first else {
            throw NSError(domain: "GamesLibraryService", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Create returned no rows."])
        }

        struct StartP: Encodable { let p_room: String }
        _ = try await client
            .rpc("gn_pastor_start",
                 params: StartP(p_room: created.roomId.uuidString.lowercased()))
            .execute()

        self.lastLaunchedCode = created.code
        return created.code
    }

    // MARK: - Theme fallback

    /// Resolves the (emoji, accent, gradient) triple a card / hero
    /// should render. Honors server values when present and falls back
    /// to a slug-derived palette entry so the UI looks complete before
    /// the CMS fills `emoji` / `accent_color` in.
    func theme(emoji: String?, accentColor: String?, slug: String) -> GameTheme {
        let fallback = GamesLibraryService.paletteEntry(for: slug)
        let resolvedEmoji = emoji ?? fallback.emoji
        let resolvedAccent: Color = {
            if let hex = accentColor, !hex.isEmpty { return Color(hex: hex) }
            return Color(hex: fallback.primary)
        }()
        let secondary = Color(hex: fallback.secondary)
        return GameTheme(
            emoji: resolvedEmoji,
            accent: resolvedAccent,
            gradient: LinearGradient(
                colors: [resolvedAccent, secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    // Stable, in-process palette mapping. Stable because `slug.utf8`
    // hashing is content-based (NOT Swift's randomized `hashValue`).
    private struct PaletteEntry {
        let emoji: String
        let primary: String
        let secondary: String
    }

    private static let palette: [PaletteEntry] = [
        PaletteEntry(emoji: "🎯", primary: "FF6B35", secondary: "FF3DA5"),
        PaletteEntry(emoji: "🎲", primary: "6B2BFF", secondary: "00E0FF"),
        PaletteEntry(emoji: "🎨", primary: "B4FF3C", secondary: "2B8A3E"),
        PaletteEntry(emoji: "🎮", primary: "0066FF", secondary: "00E0FF"),
        PaletteEntry(emoji: "🏆", primary: "FFD60A", secondary: "FF6B35"),
        PaletteEntry(emoji: "🎪", primary: "FF3DA5", secondary: "6B2BFF"),
        PaletteEntry(emoji: "🎭", primary: "3D0FB8", secondary: "6B2BFF"),
        PaletteEntry(emoji: "🌟", primary: "FFD60A", secondary: "B4FF3C")
    ]

    private static func paletteEntry(for slug: String) -> PaletteEntry {
        let sum = slug.utf8.reduce(0) { $0 &+ Int($1) }
        let idx = abs(sum) % palette.count
        return palette[idx]
    }
}

// MARK: - Models

struct GameListItem: Decodable, Identifiable, Hashable {
    let id: UUID
    let slug: String
    let name: String
    let summary: String
    let materials: String?
    let minAge: Int?
    let maxAge: Int?
    let minPlayers: Int?
    let maxPlayers: Int?
    let minMinutes: Int?
    let maxMinutes: Int?
    let ageGroups: [String]
    let tags: [String]
    let emoji: String?
    let accentColor: String?
    let upvotes: Int
    let downvotes: Int
    let score: Int
    let myVote: Int?

    enum CodingKeys: String, CodingKey {
        case id, slug, name, summary, materials
        case minAge = "min_age"
        case maxAge = "max_age"
        case minPlayers = "min_players"
        case maxPlayers = "max_players"
        case minMinutes = "min_minutes"
        case maxMinutes = "max_minutes"
        case ageGroups = "age_groups"
        case tags
        case emoji
        case accentColor = "accent_color"
        case upvotes, downvotes, score
        case myVote = "my_vote"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(UUID.self, forKey: .id)
        slug        = try c.decode(String.self, forKey: .slug)
        name        = try c.decode(String.self, forKey: .name)
        summary     = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        materials   = try c.decodeIfPresent(String.self, forKey: .materials)
        minAge      = try c.decodeIfPresent(Int.self, forKey: .minAge)
        maxAge      = try c.decodeIfPresent(Int.self, forKey: .maxAge)
        minPlayers  = try c.decodeIfPresent(Int.self, forKey: .minPlayers)
        maxPlayers  = try c.decodeIfPresent(Int.self, forKey: .maxPlayers)
        minMinutes  = try c.decodeIfPresent(Int.self, forKey: .minMinutes)
        maxMinutes  = try c.decodeIfPresent(Int.self, forKey: .maxMinutes)
        ageGroups   = try c.decodeIfPresent([String].self, forKey: .ageGroups) ?? []
        tags        = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        emoji       = try c.decodeIfPresent(String.self, forKey: .emoji)
        accentColor = try c.decodeIfPresent(String.self, forKey: .accentColor)
        upvotes     = try c.decodeIfPresent(Int.self, forKey: .upvotes) ?? 0
        downvotes   = try c.decodeIfPresent(Int.self, forKey: .downvotes) ?? 0
        score       = try c.decodeIfPresent(Int.self, forKey: .score) ?? 0
        myVote      = try c.decodeIfPresent(Int.self, forKey: .myVote) ?? 0
    }

    /// Returns a copy with the vote response applied — authoritative
    /// counts from the server replace local optimistic values.
    func applying(_ resp: VoteResponse) -> GameListItem {
        var copy = self
        copy._setVoteFields(upvotes: resp.upvotes,
                            downvotes: resp.downvotes,
                            score: resp.score,
                            myVote: resp.myVote)
        return copy
    }

    func withMyVote(_ v: Int) -> GameListItem {
        var copy = self
        copy._setVoteFields(upvotes: upvotes, downvotes: downvotes, score: score, myVote: v)
        return copy
    }

    func bumpingUp(by n: Int) -> GameListItem {
        var copy = self
        copy._setVoteFields(upvotes: upvotes + n,
                            downvotes: downvotes,
                            score: score + n,
                            myVote: myVote)
        return copy
    }

    func bumpingDown(by n: Int) -> GameListItem {
        var copy = self
        copy._setVoteFields(upvotes: upvotes,
                            downvotes: downvotes + n,
                            score: score - n,
                            myVote: myVote)
        return copy
    }

    // Mutating helper kept private — all `let` fields require a copy
    // dance to update, which we hide behind the builder-style methods
    // above so callers can't accidentally produce an inconsistent row.
    private mutating func _setVoteFields(upvotes: Int, downvotes: Int, score: Int, myVote: Int?) {
        self = GameListItem(id: id, slug: slug, name: name, summary: summary,
                            materials: materials,
                            minAge: minAge, maxAge: maxAge,
                            minPlayers: minPlayers, maxPlayers: maxPlayers,
                            minMinutes: minMinutes, maxMinutes: maxMinutes,
                            ageGroups: ageGroups, tags: tags,
                            emoji: emoji, accentColor: accentColor,
                            upvotes: upvotes, downvotes: downvotes,
                            score: score, myVote: myVote)
    }

    // Designated memberwise initializer used by `_setVoteFields`. Not
    // public because we don't want callers constructing rows by hand —
    // they always come from the server.
    fileprivate init(id: UUID, slug: String, name: String, summary: String,
                     materials: String?,
                     minAge: Int?, maxAge: Int?,
                     minPlayers: Int?, maxPlayers: Int?,
                     minMinutes: Int?, maxMinutes: Int?,
                     ageGroups: [String], tags: [String],
                     emoji: String?, accentColor: String?,
                     upvotes: Int, downvotes: Int,
                     score: Int, myVote: Int?) {
        self.id = id
        self.slug = slug
        self.name = name
        self.summary = summary
        self.materials = materials
        self.minAge = minAge
        self.maxAge = maxAge
        self.minPlayers = minPlayers
        self.maxPlayers = maxPlayers
        self.minMinutes = minMinutes
        self.maxMinutes = maxMinutes
        self.ageGroups = ageGroups
        self.tags = tags
        self.emoji = emoji
        self.accentColor = accentColor
        self.upvotes = upvotes
        self.downvotes = downvotes
        self.score = score
        self.myVote = myVote
    }
}

struct GameDetail: Decodable, Identifiable, Hashable {
    let id: UUID
    let slug: String
    let name: String
    let summary: String
    let materials: String?
    let instructions: String
    let minAge: Int?
    let maxAge: Int?
    let minPlayers: Int?
    let maxPlayers: Int?
    let minMinutes: Int?
    let maxMinutes: Int?
    let ageGroups: [String]
    let ageBuckets: [String]
    let groupSizeBuckets: [String]
    let durationBuckets: [String]
    let tags: [String]
    let emoji: String?
    let accentColor: String?
    let upvotes: Int
    let downvotes: Int
    let score: Int
    let myVote: Int?
    let sourceUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, slug, name, summary, materials, instructions
        case minAge = "min_age"
        case maxAge = "max_age"
        case minPlayers = "min_players"
        case maxPlayers = "max_players"
        case minMinutes = "min_minutes"
        case maxMinutes = "max_minutes"
        case ageGroups = "age_groups"
        case ageBuckets = "age_buckets"
        case groupSizeBuckets = "group_size_buckets"
        case durationBuckets = "duration_buckets"
        case tags
        case emoji
        case accentColor = "accent_color"
        case upvotes, downvotes, score
        case myVote = "my_vote"
        case sourceUrl = "source_url"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decode(UUID.self, forKey: .id)
        slug             = try c.decode(String.self, forKey: .slug)
        name             = try c.decode(String.self, forKey: .name)
        summary          = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        materials        = try c.decodeIfPresent(String.self, forKey: .materials)
        instructions     = try c.decodeIfPresent(String.self, forKey: .instructions) ?? ""
        minAge           = try c.decodeIfPresent(Int.self, forKey: .minAge)
        maxAge           = try c.decodeIfPresent(Int.self, forKey: .maxAge)
        minPlayers       = try c.decodeIfPresent(Int.self, forKey: .minPlayers)
        maxPlayers       = try c.decodeIfPresent(Int.self, forKey: .maxPlayers)
        minMinutes       = try c.decodeIfPresent(Int.self, forKey: .minMinutes)
        maxMinutes       = try c.decodeIfPresent(Int.self, forKey: .maxMinutes)
        ageGroups        = try c.decodeIfPresent([String].self, forKey: .ageGroups) ?? []
        ageBuckets       = try c.decodeIfPresent([String].self, forKey: .ageBuckets) ?? []
        groupSizeBuckets = try c.decodeIfPresent([String].self, forKey: .groupSizeBuckets) ?? []
        durationBuckets  = try c.decodeIfPresent([String].self, forKey: .durationBuckets) ?? []
        tags             = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        emoji            = try c.decodeIfPresent(String.self, forKey: .emoji)
        accentColor      = try c.decodeIfPresent(String.self, forKey: .accentColor)
        upvotes          = try c.decodeIfPresent(Int.self, forKey: .upvotes) ?? 0
        downvotes        = try c.decodeIfPresent(Int.self, forKey: .downvotes) ?? 0
        score            = try c.decodeIfPresent(Int.self, forKey: .score) ?? 0
        myVote           = try c.decodeIfPresent(Int.self, forKey: .myVote) ?? 0
        sourceUrl        = try c.decodeIfPresent(String.self, forKey: .sourceUrl)
    }
}

struct VoteResponse: Decodable, Hashable {
    let gameId: UUID
    let upvotes: Int
    let downvotes: Int
    let score: Int
    let myVote: Int?

    enum CodingKeys: String, CodingKey {
        case gameId = "game_id"
        case upvotes, downvotes, score
        case myVote = "my_vote"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gameId    = try c.decode(UUID.self, forKey: .gameId)
        upvotes   = try c.decodeIfPresent(Int.self, forKey: .upvotes) ?? 0
        downvotes = try c.decodeIfPresent(Int.self, forKey: .downvotes) ?? 0
        score     = try c.decodeIfPresent(Int.self, forKey: .score) ?? 0
        myVote    = try c.decodeIfPresent(Int.self, forKey: .myVote) ?? 0
    }
}

private struct CreateGameRow: Decodable {
    let roomId: UUID
    let code: String
    let hostToken: UUID

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case code
        case hostToken = "host_token"
    }
}

// MARK: - Theme

struct GameTheme {
    let emoji: String
    let accent: Color
    let gradient: LinearGradient
}
