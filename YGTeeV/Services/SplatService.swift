//
//  SplatService.swift
//  YGTeeV
//
//  Holds the live state for the daily YGTeeV Splat melee — the
//  currently active round, the leaderboard snapshot, and the call
//  surface the arena view uses to record taps.
//
//  Server contract (Supabase, public schema):
//
//    splat_current_round()                          → table(...)
//    splat_team_leaderboard(p_round_id uuid)        → table(...)
//    splat_tap_batch(p_round_id uuid, p_count int)  → jsonb
//    splat_finalize_and_advance()                   (cron only — ignore)
//
//  Note PostgREST is strict about parameter names: the deployed
//  signatures use `p_<name>`, NOT `_<name>`.
//

import SwiftUI
import Supabase

@MainActor
@Observable
final class SplatService {
    static let shared = SplatService()
    private let client = SupabaseManager.shared.client

    /// Latest snapshot from `splat_current_round()`. `nil` while the
    /// first fetch is in flight, or if the call failed (UI surfaces a
    /// "Loading…" state in that window).
    var currentRound: SplatCurrentRound?

    /// Latest leaderboard rows sorted by `rank` ascending. Replaced
    /// wholesale on every refresh — never patched in place — so SwiftUI
    /// diffing has a clean before/after to animate against.
    var leaderboard: [SplatTeamRow] = []

    private init() {}

    // MARK: - Round

    /// Pulls the current round and persists it onto `currentRound`.
    /// Silent on failure — the hero countdown falls back to "Loading…"
    /// rather than throwing; transient network errors during a poll
    /// shouldn't tear the UI.
    ///
    /// `splat_current_round()` is declared `RETURNS TABLE(...)` so the
    /// PostgREST response is a JSON array of 0 or 1 rows — decode as
    /// an array and take `.first`.
    func refreshCurrentRound() async {
        do {
            let rows: [SplatCurrentRound] = try await client
                .rpc("splat_current_round")
                .execute()
                .value
            self.currentRound = rows.first
        } catch {
            print("[SplatService] splat_current_round failed:", error)
        }
    }

    // MARK: - Leaderboard

    /// Pulls the 4-row leaderboard snapshot for the active round.
    /// Sorted by rank just in case the RPC's ORDER BY ever drifts.
    /// No-op while we don't yet have a round id (e.g. arena opened
    /// before the first `refreshCurrentRound()` completed).
    func refreshLeaderboard() async {
        guard let roundId = currentRound?.roundId else { return }
        struct Params: Encodable { let p_round_id: String }
        do {
            let rows: [SplatTeamRow] = try await client
                .rpc("splat_team_leaderboard",
                     params: Params(p_round_id: roundId.uuidString.lowercased()))
                .execute()
                .value
            self.leaderboard = rows.sorted { $0.rank < $1.rank }
        } catch {
            print("[SplatService] splat_team_leaderboard failed:", error)
        }
    }

    // MARK: - Taps

    /// Submits a batch of taps and returns the server-authoritative
    /// result. The arena view calls this every 2s, after 25+ pending
    /// taps, or on dismiss/backgrounding — never per tap. The caller
    /// reconciles its optimistic per-team scoreboard with
    /// `yourTeamScore` from this response.
    ///
    /// `splat_tap_batch` returns `jsonb` (a single object), so we
    /// decode the response directly as `SplatTapResult` rather than
    /// as an array.
    ///
    /// Throws on transport errors so the arena can re-queue the batch
    /// (don't drop pending taps on the floor — the user already paid
    /// the perceived cost of every visible berry burst).
    @discardableResult
    func sendTaps(_ count: Int) async throws -> SplatTapResult {
        guard let roundId = currentRound?.roundId else {
            throw NSError(domain: "SplatService", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "No active Splat round."])
        }
        struct Params: Encodable {
            let p_round_id: String
            let p_count: Int
        }
        let row: SplatTapResult = try await client
            .rpc("splat_tap_batch",
                 params: Params(
                    p_round_id: roundId.uuidString.lowercased(),
                    p_count: count
                 ))
            .execute()
            .value
        // The RPC also returned a fresh remaining XP — patch
        // `currentRound.yourXp` so observers (the wallet bar) tick
        // down without a second round-trip. Keep the round id /
        // timestamps untouched.
        if let r = currentRound {
            self.currentRound = SplatCurrentRound(
                roundId: r.roundId,
                roundStartsAt: r.roundStartsAt,
                roundEndsAt: r.roundEndsAt,
                yourColor: row.yourColor,
                yourXp: row.remainingXp
            )
        }
        return row
    }
}
