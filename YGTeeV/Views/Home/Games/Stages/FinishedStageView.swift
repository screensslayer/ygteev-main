//
//  FinishedStageView.swift
//  YGTeeV
//
//  Stage shown when `room.status == .finished`. Trophy hero, XP
//  delta pill, and a Top-5 leaderboard. Pure content; the shell
//  owns the chrome + footer.
//

import SwiftUI

struct FinishedStageView: View {
    let room: GameRoom
    let players: [GamePlayer]

    /// Final leaderboard — prefer the server-provided podium when
    /// present, otherwise sort the live roster by score.
    private var leaderboard: [GamePlayerSummary] {
        if let podium = room.revealData?.podium, !podium.isEmpty {
            return Array(podium.prefix(5))
        }
        let myId = SupabaseManager.shared.currentUser?.id
        return players
            .sorted { $0.score > $1.score }
            .prefix(5)
            .enumerated()
            .map { (idx, p) in
                let isMe: Bool = {
                    guard let myId, let uid = p.userId else { return false }
                    return uid.uuidString.lowercased() == myId.lowercased()
                }()
                return synthesizedSummary(p, placement: idx + 1, isMe: isMe)
            }
    }

    private var myPlacement: Int {
        leaderboard.first(where: { $0.isMe })?.placement
            ?? room.revealData?.podium?.first(where: { $0.isMe })?.placement
            ?? 0
    }

    private var trophy: String {
        switch myPlacement {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "🎉"
        }
    }

    private var xpDelta: Int {
        room.revealData?.myXpDelta ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 8) {
                    Text(trophy).font(.system(size: 72))
                    Text(myPlacement > 0 ? "You placed #\(myPlacement)" : "Good game!")
                        .font(.lilitaOne(size: 36))
                        .tracking(-1.2)
                        .foregroundStyle(.white)
                    Text("Top of the pack — well played 👏")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.6))

                    if xpDelta > 0 {
                        xpPill.padding(.top, 4)
                    }
                }

                leaderboardCard.padding(.top, 6)
            }
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Building blocks

    private var xpPill: some View {
        HStack(spacing: 7) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 14))
                .foregroundStyle(YGColors.yellow)
            Text("+\(xpDelta) XP added to your account")
                .font(.lilitaOne(size: 15))
                .foregroundStyle(YGColors.yellow)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(YGColors.yellow.opacity(0.16))
        .overlay(
            Capsule().strokeBorder(YGColors.yellow.opacity(0.45), lineWidth: 1)
        )
        .clipShape(Capsule())
    }

    private var leaderboardCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FINAL · TOP \(leaderboard.count)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.5))

            VStack(spacing: 8) {
                ForEach(Array(leaderboard.enumerated()), id: \.element.id) { idx, row in
                    leaderboardRow(row, rank: row.placement ?? (idx + 1))
                }
            }
        }
    }

    private func leaderboardRow(_ row: GamePlayerSummary, rank: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.lilitaOne(size: 16))
                .foregroundStyle(rank == 1 ? YGColors.yellow : Color.white.opacity(0.55))
                .frame(width: 22)

            YGAvatar(name: row.nickname ?? "?", size: 36, imageURL: row.avatarUrl)

            HStack(spacing: 6) {
                Text(row.nickname ?? "—")
                    .font(.lilitaOne(size: 17))
                    .foregroundStyle(.white)
                if row.isMe {
                    Text("· you")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            Spacer()
            Text(row.score.formatted())
                .font(.lilitaOne(size: 18))
                .foregroundStyle(YGColors.yellow)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(rowBackground(for: row, rank: rank))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(rowBorder(for: row, rank: rank),
                              lineWidth: row.isMe ? 1.5 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func rowBackground(for row: GamePlayerSummary, rank: Int) -> some View {
        if row.isMe {
            LinearGradient(colors: [YGColors.violet.opacity(0.35),
                                    YGColors.pink.opacity(0.2)],
                           startPoint: .leading,
                           endPoint: .trailing)
        } else if rank == 1 {
            YGColors.yellow.opacity(0.1)
        } else {
            Color.white.opacity(0.05)
        }
    }

    private func rowBorder(for row: GamePlayerSummary, rank: Int) -> Color {
        if row.isMe { return YGColors.violetSoft.opacity(0.6) }
        if rank == 1 { return YGColors.yellow.opacity(0.35) }
        return .white.opacity(0.08)
    }

    /// Turns a live `GamePlayer` into a podium-style summary when the
    /// server didn't ship `reveal_data.podium`. Keeps the leaderboard
    /// renderer in one shape regardless of which source it came from.
    private func synthesizedSummary(_ p: GamePlayer,
                                    placement: Int,
                                    isMe: Bool) -> GamePlayerSummary {
        struct Box: Encodable {
            let id: String
            let nickname: String?
            let avatar_url: String?
            let score: Int
            let placement: Int
            let is_me: Bool
        }
        let data = try! JSONEncoder().encode(Box(
            id: p.id.uuidString,
            nickname: p.nickname,
            avatar_url: p.avatarUrl,
            score: p.score,
            placement: placement,
            is_me: isMe
        ))
        return (try? JSONDecoder().decode(GamePlayerSummary.self, from: data))
            ?? GamePlayerSummary.empty
    }
}

extension GamePlayerSummary {
    /// Empty fallback used when the synthesized-summary decode fails.
    /// Never seen in practice; defined so the call site can stay
    /// total without optionals.
    static var empty: GamePlayerSummary {
        let data = "{}".data(using: .utf8)!
        return try! JSONDecoder().decode(GamePlayerSummary.self, from: data)
    }
}
