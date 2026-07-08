//
//  LobbyStageView.swift
//  YGTeeV
//
//  Stage shown while `room.status == .lobby`. Pure content — the
//  shell handles the close X, the ROOM badge, and the safe area.
//  When the room has a future `scheduled_start_at`, the headline is
//  the big countdown clock; otherwise the lobby degrades to a
//  "Waiting for the host to start…" hint.
//

import SwiftUI

struct LobbyStageView: View {
    let room: GameRoom
    let players: [GamePlayer]
    let myPlayer: GamePlayer?

    private var handle: String {
        SupabaseManager.shared.currentUser?.handle
            ?? SupabaseManager.shared.currentUser?.displayName
            ?? "You"
    }

    private var avatarUrl: String? {
        SupabaseManager.shared.currentUser?.avatarUrl
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)

            headerBlock
                .padding(.bottom, 22)

            if let scheduledStartAt = room.scheduledStartAt {
                CountdownClock(target: scheduledStartAt)
                    .padding(.bottom, 26)
            } else {
                youAreInChip.padding(.bottom, 18)
                YGAvatar(name: handle, size: 96, showRing: true, imageURL: avatarUrl)
                    .padding(.bottom, 24)
            }

            rosterBlock

            Spacer(minLength: 16)

            waitingHint
                .padding(.bottom, 16)
        }
    }

    // MARK: - Building blocks

    private var headerBlock: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(colors: [YGColors.violet, YGColors.pink],
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing))
                    .frame(width: 60, height: 60)
                    .shadow(color: YGColors.violet.opacity(0.5), radius: 14, y: 8)
                Text(room.gameType.emoji)
                    .font(.system(size: 30))
            }
            Text(room.gameType.displayName.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(YGColors.violetSoft)
            Text("\(players.count) player\(players.count == 1 ? "" : "s") in the lobby")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var youAreInChip: some View {
        HStack(spacing: 7) {
            PulseDot(color: Color(hex: "34D399"), size: 8)
            Text("You're in!")
                .font(.lilitaOne(size: 14))
                .foregroundStyle(Color(hex: "34D399"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(Color(hex: "34D399").opacity(0.16))
        .overlay(
            Capsule().strokeBorder(Color(hex: "34D399").opacity(0.45), lineWidth: 1)
        )
        .clipShape(Capsule())
    }

    private var rosterBlock: some View {
        let shown = Array(players.prefix(12))
        let extra = max(0, players.count - shown.count)
        return LazyVGrid(columns: Array(repeating: GridItem(.fixed(40), spacing: 8), count: 6),
                         spacing: 8) {
            ForEach(shown) { p in
                YGAvatar(name: p.nickname ?? "?",
                         size: 40,
                         imageURL: p.avatarUrl)
            }
            if extra > 0 {
                Text("+\(extra)")
                    .font(.lilitaOne(size: 14))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.08))
                    .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1))
                    .clipShape(Circle())
            }
        }
        .frame(maxWidth: 300)
    }

    private var waitingHint: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<3) { _ in
                    PulseDot(color: YGColors.violetSoft, size: 7)
                }
            }
            Text(room.scheduledStartAt != nil
                 ? "Game starts when the timer hits zero…"
                 : "Waiting for the host to start…")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
        }
    }
}
