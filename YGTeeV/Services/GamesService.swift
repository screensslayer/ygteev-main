//
//  GamesService.swift
//  YGTeeV
//
//  Backs the home Games tab + the immersive play flow. Wraps the
//  read-only `gn_*` RPC surface and a Realtime subscription on
//  gn_rooms / gn_players so the UI re-renders straight off
//  `room.status` as the host advances the game. Members are PASSIVE —
//  the only mutation we make is `gn_member_submit_answer`.
//

import Foundation
import Supabase

@MainActor
@Observable
final class GamesService {
    static let shared = GamesService()
    private let client = SupabaseManager.shared.client

    // MARK: - Tab state (discovery)

    /// The single active room for the currently-selected group, or nil
    /// if no game is in lobby / in-progress / reveal right now.
    var activeGame: ActiveGame?

    /// Last N finished games the caller participated in, scoped to the
    /// active group. Used to render the Recent list.
    var recentGames: [RecentGame] = []

    /// The group both lists are scoped to. Lets the tab detect a stale
    /// cache when the user flips the active group in the header.
    var loadedGroupId: UUID?

    var isLoadingDiscovery = false
    var discoveryError: String?

    // MARK: - Immersive play state

    /// Authoritative room state for the room we joined. Driven by the
    /// gn_rooms Realtime subscription after the join RPC returns.
    var room: GameRoom?

    /// Roster for the joined room, kept fresh by the gn_players
    /// Realtime subscription. Order is server-defined.
    var players: [GamePlayer] = []

    /// The caller's own player row inside `players`. Cached for the
    /// in-game footer / has-locked guard so we don't re-scan on every
    /// re-render.
    var myPlayer: GamePlayer?

    /// Local "I have already submitted this question" guard. Flips on
    /// successful submitAnswer and resets when the room's question
    /// index advances (the host moved on).
    var hasSubmittedCurrentQuestion: Bool = false

    /// Surfaced to the play view when a submit fails — the user can
    /// retry without leaving the room.
    var submitError: String?

    // MARK: - Realtime plumbing

    private var roomChannel: RealtimeChannelV2?
    private var playersChannel: RealtimeChannelV2?

    /// Custom decoder that handles both fractional-second and plain
    /// ISO8601 timestamps coming off Realtime payloads. Mirrors the
    /// decoder SupabaseClient uses for regular RPC reads so a row
    /// coming in over the websocket parses identically to one coming
    /// off PostgREST.
    private static let realtimeDecoder: JSONDecoder = {
        let d = JSONDecoder()
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let s = try c.decode(String.self)
            if let date = withFractional.date(from: s) { return date }
            if let date = plain.date(from: s) { return date }
            throw DecodingError.dataCorruptedError(
                in: c, debugDescription: "Unparseable date: \(s)")
        }
        return d
    }()

    private init() {}

    // MARK: - Discovery

    /// Loads both the active game and recent games for the given group
    /// in parallel. Safe to call repeatedly — the .task in GamesView
    /// keys on the group id so flipping groups triggers a fresh load.
    func loadDiscovery(groupId: UUID) async {
        isLoadingDiscovery = true
        defer { isLoadingDiscovery = false }
        do {
            async let active: ActiveGame?  = fetchActiveGame(groupId: groupId)
            async let recent: [RecentGame] = fetchRecentGames(groupId: groupId)
            let (a, r) = try await (active, recent)
            self.activeGame     = a
            self.recentGames    = r
            self.loadedGroupId  = groupId
            self.discoveryError = nil
        } catch {
            print("[GamesService] loadDiscovery error:", error)
            self.discoveryError = error.localizedDescription
        }
    }

    /// `gn_member_active_game(p_group)` — returns the single active
    /// room or null. SETOF-style RPCs decode as `[Row]`, so we take
    /// the first element when present.
    func fetchActiveGame(groupId: UUID) async throws -> ActiveGame? {
        struct P: Encodable { let p_group: String }
        let rows: [ActiveGame] = try await client
            .rpc("gn_member_active_game",
                 params: P(p_group: groupId.uuidString.lowercased()))
            .execute()
            .value
        return rows.first
    }

    func fetchRecentGames(groupId: UUID, limit: Int = 10) async throws -> [RecentGame] {
        struct P: Encodable {
            let p_group: String
            let p_limit: Int
        }
        return try await client
            .rpc("gn_member_recent_games",
                 params: P(p_group: groupId.uuidString.lowercased(), p_limit: limit))
            .execute()
            .value
    }

    // MARK: - Join + initial room hydration

    /// `gn_member_join(p_room)` — server inserts (or upserts) a
    /// gn_players row for the caller and returns the live room. We use
    /// the returned room to seed local state instantly so the play
    /// view doesn't paint a spinner before the Realtime channel
    /// catches up.
    @discardableResult
    func joinRoom(roomId: UUID) async throws -> GameRoom {
        struct P: Encodable { let p_room: String }
        struct JoinResult: Decodable {
            let room: GameRoom?
            let players: [GamePlayer]?
            let me: GamePlayer?

            init(from decoder: Decoder) throws {
                // Two shapes are accepted: a top-level GameRoom (when
                // the RPC was simplified) OR a wrapper object with
                // room/players/me. Single-value-container fallback
                // covers the simple case.
                if let single = try? decoder.singleValueContainer(),
                   let single2 = try? single.decode(GameRoom.self) {
                    room = single2
                    players = nil
                    me = nil
                    return
                }
                let c = try decoder.container(keyedBy: CodingKeys.self)
                room    = try c.decodeIfPresent(GameRoom.self, forKey: .room)
                players = try c.decodeIfPresent([GamePlayer].self, forKey: .players)
                me      = try c.decodeIfPresent(GamePlayer.self, forKey: .me)
            }

            enum CodingKeys: String, CodingKey { case room, players, me }
        }

        // Hard-clear any prior in-game state — flipping rooms must not
        // leak the previous roster or "I already locked" flag through.
        await teardownRealtime()
        self.players = []
        self.myPlayer = nil
        self.hasSubmittedCurrentQuestion = false
        self.submitError = nil

        let result: JoinResult = try await client
            .rpc("gn_member_join",
                 params: P(p_room: roomId.uuidString.lowercased()))
            .execute()
            .value

        guard let r = result.room else {
            throw NSError(domain: "GamesService", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Join returned no room"])
        }
        self.room    = r
        self.players = result.players ?? []
        self.myPlayer = result.me ?? findMyPlayer(in: self.players)

        // After hydration, attach Realtime so any host advance reaches
        // us. Failure to subscribe doesn't fail the join itself — the
        // user is in the room either way.
        await subscribeRealtime(roomId: r.id)

        // Belt-and-suspenders: fetch the current players list from the
        // table in case the RPC didn't echo it back. Cheap one-shot.
        if (result.players ?? []).isEmpty {
            await refreshPlayers(roomId: r.id)
        }
        return r
    }

    /// Walks the local roster for the row whose user_id matches the
    /// current Supabase user. Used to derive `myPlayer` when the join
    /// RPC didn't echo `me` directly.
    private func findMyPlayer(in players: [GamePlayer]) -> GamePlayer? {
        guard let meId = SupabaseManager.shared.currentUser?.id,
              let meUUID = UUID(uuidString: meId)
        else { return nil }
        return players.first { $0.userId == meUUID }
    }

    /// Re-fetches the full players list from `gn_players` filtered to
    /// this room. Called as a fallback after join and after the user
    /// pulls to refresh — the Realtime subscription handles the steady
    /// state.
    func refreshPlayers(roomId: UUID) async {
        do {
            let rows: [GamePlayer] = try await client
                .from("gn_players")
                .select()
                .eq("room_id", value: roomId.uuidString.lowercased())
                .execute()
                .value
            self.players = rows
            self.myPlayer = findMyPlayer(in: rows)
        } catch {
            print("[GamesService] refreshPlayers error:", error)
        }
    }

    // MARK: - Submit answer

    /// `gn_member_submit_answer(p_room, p_response, p_response_ms)` —
    /// player-side mutation. `response` is the game-specific payload;
    /// for Majority Rules it carries both the crowd guess and the
    /// caller's own pick.
    func submitAnswer(roomId: UUID,
                      response: [String: AnyJSON],
                      responseMs: Int) async throws {
        struct P: Encodable {
            let p_room: String
            let p_response: [String: AnyJSON]
            let p_response_ms: Int
        }
        submitError = nil
        do {
            try await client
                .rpc("gn_member_submit_answer",
                     params: P(p_room: roomId.uuidString.lowercased(),
                               p_response: response,
                               p_response_ms: responseMs))
                .execute()
            hasSubmittedCurrentQuestion = true
        } catch {
            submitError = error.localizedDescription
            throw error
        }
    }

    // MARK: - Leaving the room

    /// Tears down the Realtime subscriptions and clears in-game state.
    /// Call this from `.onDisappear` of the immersive cover so a back-
    /// out doesn't leak a websocket subscription or stale room state.
    func leaveRoom() async {
        await teardownRealtime()
        self.room = nil
        self.players = []
        self.myPlayer = nil
        self.hasSubmittedCurrentQuestion = false
        self.submitError = nil
    }

    // MARK: - Realtime: gn_rooms + gn_players

    private func subscribeRealtime(roomId: UUID) async {
        let roomFilter = "id=eq.\(roomId.uuidString.lowercased())"
        let playerFilter = "room_id=eq.\(roomId.uuidString.lowercased())"

        // gn_rooms — UPDATE only (insert handled by join, delete by leave)
        let rChan = client.channel("gn_room-\(roomId.uuidString)")
        let roomUpdates = rChan.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "gn_rooms",
            filter: roomFilter
        )
        Task { [weak self] in
            for await change in roomUpdates {
                guard let self else { return }
                if let r = try? Self.decode(GameRoom.self, from: change.record) {
                    await self.applyRoomUpdate(r)
                }
            }
        }
        await rChan.subscribe()
        self.roomChannel = rChan

        // gn_players — INSERT (newcomers), UPDATE (score / locked), DELETE (left)
        let pChan = client.channel("gn_players-\(roomId.uuidString)")
        let pInserts = pChan.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "gn_players",
            filter: playerFilter
        )
        let pUpdates = pChan.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "gn_players",
            filter: playerFilter
        )
        let pDeletes = pChan.postgresChange(
            DeleteAction.self,
            schema: "public",
            table: "gn_players",
            filter: playerFilter
        )
        Task { [weak self] in
            for await change in pInserts {
                guard let self else { return }
                if let p = try? Self.decode(GamePlayer.self, from: change.record) {
                    await self.upsertPlayer(p)
                }
            }
        }
        Task { [weak self] in
            for await change in pUpdates {
                guard let self else { return }
                if let p = try? Self.decode(GamePlayer.self, from: change.record) {
                    await self.upsertPlayer(p)
                }
            }
        }
        Task { [weak self] in
            for await change in pDeletes {
                guard let self else { return }
                // DeleteAction carries `oldRecord` with the prior row.
                // We only need the id to drop the row from local state.
                if let idStr = change.oldRecord["id"]?.stringValue,
                   let id = UUID(uuidString: idStr) {
                    await self.removePlayer(id: id)
                }
            }
        }
        await pChan.subscribe()
        self.playersChannel = pChan
    }

    private func teardownRealtime() async {
        if let c = roomChannel    { await c.unsubscribe(); roomChannel = nil }
        if let c = playersChannel { await c.unsubscribe(); playersChannel = nil }
    }

    // MARK: - Realtime: apply

    private func applyRoomUpdate(_ next: GameRoom) {
        let prev = self.room
        self.room = next

        // If the question index advanced (or the status moved into a
        // new in_game cycle), clear the local "already submitted"
        // flag so the new question is interactive again.
        let prevQ = prev?.currentQuestionIndex ?? -1
        let nextQ = next.currentQuestionIndex ?? -1
        let statusChanged = prev?.status != next.status
        if nextQ != prevQ || (statusChanged && next.status == .inGame) {
            self.hasSubmittedCurrentQuestion = false
            self.submitError = nil
        }
    }

    private func upsertPlayer(_ p: GamePlayer) {
        if let idx = players.firstIndex(where: { $0.id == p.id }) {
            players[idx] = p
        } else {
            players.append(p)
        }
        if let meId = SupabaseManager.shared.currentUser?.id,
           let meUUID = UUID(uuidString: meId),
           p.userId == meUUID {
            myPlayer = p
        }
    }

    private func removePlayer(id: UUID) {
        players.removeAll { $0.id == id }
        if myPlayer?.id == id { myPlayer = nil }
    }

    // MARK: - Realtime row decoding

    /// Decodes a Realtime change `record` ([String: AnyJSON]) into a
    /// strongly-typed model. Re-encodes through JSONEncoder so we can
    /// drive a single decoder with the project's ISO8601 strategy.
    private static func decode<T: Decodable>(_ type: T.Type,
                                             from record: [String: AnyJSON]) throws -> T {
        let data = try JSONEncoder().encode(record)
        return try realtimeDecoder.decode(T.self, from: data)
    }

    // MARK: - Reset

    func reset() {
        activeGame = nil
        recentGames = []
        loadedGroupId = nil
        room = nil
        players = []
        myPlayer = nil
        hasSubmittedCurrentQuestion = false
        submitError = nil
        Task { await teardownRealtime() }
    }
}

// MARK: - AnyJSON convenience

private extension AnyJSON {
    /// Convenience accessor for a string scalar without forcing a full
    /// decode. Mirrors the pattern used by ChatService's delete handler.
    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }
}
