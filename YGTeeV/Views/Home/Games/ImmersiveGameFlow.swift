//
//  ImmersiveGameFlow.swift
//  YGTeeV
//
//  Orchestrator for the Game Night immersive sheet. Picks the right
//  stage view off `service.room.status` and hands it to
//  `ImmersiveGameShell`, which owns ALL layout chrome (background,
//  top ROOM badge, optional score footer, the single 20pt horizontal
//  inset). Dismissal is native: the parent presents this as a
//  `.sheet`, so iOS handles the finger-tracking drag-to-dismiss
//  gesture — there's no in-flow close button.
//

import SwiftUI
import Supabase

struct ImmersiveGameFlow: View {
    /// Cached room context handed in from the tab's discovery
    /// response. Seeds `service.room` immediately so the lobby paints
    /// before the join RPC even returns.
    let active: ActiveGame
    let membership: MyGroupMembership?

    var roomId: UUID { active.roomId }

    @State private var service = GamesService.shared
    @State private var hasJoined = false
    @State private var joinError: GamesJoinError?
    /// Wall-clock anchor used to compute `response_ms` if the server
    /// didn't stamp `gn_rooms.question_started_at` for this room.
    @State private var questionStartedAt: Date = .now

    var body: some View {
        Group {
            if let err = joinError {
                ImmersiveGameShell(
                    roomCode: service.room?.code,
                    myPlayer: service.myPlayer,
                    showFooter: false
                ) {
                    JoinErrorContent(err: err)
                }
            } else if let room = service.room {
                ImmersiveGameShell(
                    roomCode: room.code,
                    myPlayer: service.myPlayer,
                    showFooter: room.status != .lobby
                ) {
                    stage(for: room)
                        .transition(.opacity)
                }
            } else {
                ImmersiveGameShell(
                    roomCode: active.code,
                    myPlayer: nil,
                    showFooter: false
                ) {
                    JoiningStageView(active: active)
                }
            }
        }
        .task {
            if !hasJoined && joinError == nil {
                await join()
            }
        }
        .onDisappear {
            Task { await service.leaveRoom() }
        }
    }

    @ViewBuilder
    private func stage(for room: GameRoom) -> some View {
        switch room.status {
        case .lobby:
            LobbyStageView(room: room,
                           players: service.players,
                           myPlayer: service.myPlayer)
        case .inGame:
            if service.hasSubmittedCurrentQuestion {
                LockedStageView(room: room, myPlayer: service.myPlayer)
            } else {
                InGameStageView(room: room,
                                myPlayer: service.myPlayer,
                                questionStartedAt: questionStartedAt,
                                onSubmit: submit(crowdGuess:myPick:))
                .onAppear { questionStartedAt = .now }
                .onChange(of: room.currentQuestionIndex) { _, _ in
                    questionStartedAt = .now
                }
            }
        case .reveal:
            RevealStageView(room: room, myPlayer: service.myPlayer)
        case .finished:
            FinishedStageView(room: room, players: service.players)
        }
    }

    // MARK: - Networking

    private func join() async {
        joinError = nil
        do {
            try await service.joinRoom(roomId: roomId, seed: active)
            hasJoined = true
            questionStartedAt = .now
        } catch let gErr as GamesJoinError {
            joinError = gErr
            print("[ImmersiveGameFlow] joinRoom failed:", gErr)
        } catch {
            joinError = .unknown(message: error.localizedDescription)
            print("[ImmersiveGameFlow] joinRoom failed:", error)
        }
    }

    private func submit(crowdGuess: String, myPick: String) {
        // Prefer the server-stamped per-question anchor so all
        // players' response_ms are comparable; fall back to the
        // local timestamp only if the column was missing.
        let anchor = service.room?.questionStartedAt ?? questionStartedAt
        let elapsed = Int(Date().timeIntervalSince(anchor) * 1000)
        // Backend reads response->>'guess' and response->>'ownChoice'
        // — these EXACT keys are required, or every answer scores 0.
        let payload: [String: AnyJSON] = [
            "guess":     .string(crowdGuess),
            "ownChoice": .string(myPick)
        ]
        Task {
            do {
                try await service.submitAnswer(
                    roomId: roomId, response: payload, responseMs: elapsed)
            } catch {
                print("[ImmersiveGameFlow] submit failed:", error)
            }
        }
    }
}

// MARK: - Join error content

/// Renders in the shell's content slot when `gn_member_join` raised a
/// recoverable error. Title + body copy mapped per error case. Uses
/// `@Environment(\.dismiss)` so the "Close" button calls the same
/// dismissal API as the user's swipe-down gesture.
private struct JoinErrorContent: View {
    let err: GamesJoinError
    @Environment(\.dismiss) private var dismiss

    private var title: String {
        switch err {
        case .roomUnavailable:  return "This game just ended"
        case .forbidden:        return "You can't join this one"
        case .eliminated:       return "You're out"
        case .notAuthenticated: return "Please sign in"
        case .unknown:          return "Couldn't join the game"
        }
    }

    private var body_: String {
        switch err {
        case .roomUnavailable:  return "It already wrapped up. Catch the next one."
        case .forbidden:        return "Only members of this group can play."
        case .eliminated:       return "You can keep watching on the big screen."
        case .notAuthenticated: return "Your session expired — sign in to play."
        case .unknown(let m):   return m
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(YGColors.yellow)
            Text(title)
                .font(.lilitaOne(size: 22))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(body_)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            Button("Close") { dismiss() }
                .font(.lilitaOne(size: 16))
                .foregroundStyle(YGColors.ink)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(Color.white)
                .clipShape(Capsule())
            Spacer()
        }
    }
}
