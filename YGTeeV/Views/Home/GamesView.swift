//
//  GamesView.swift
//  YGTeeV
//
//  Home > Games tab. Sits between Events and Ranking. Surfaces the
//  active room for the currently-selected youth group (lobby / live)
//  plus a list of the caller's recent finished games. Tapping Join
//  presents the immersive play flow as a full-screen cover, which
//  takes over until the room is finished or the user backs out.
//
//  Scope note: only Majority Rules is actually playable from the iOS
//  client today. Other game types still appear in the Recent list (or
//  in the hero card if the host launches one), but their join button
//  resolves to "Coming soon" instead of presenting the play flow.
//

import SwiftUI

// MARK: - Tab entry point

struct GamesView: View {
    let selectedGroupId: UUID?
    let membership: MyGroupMembership?

    @State private var service = GamesService.shared
    @State private var immersiveRoomId: UUID?
    @State private var showComingSoon = false

    var body: some View {
        ZStack {
            YGColors.ink.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    heroSection
                    recentSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 120)
                .padding(.bottom, 120)
            }
        }
        .task(id: selectedGroupId) {
            guard let gid = selectedGroupId else { return }
            await service.loadDiscovery(groupId: gid)
        }
        .fullScreenCover(item: $immersiveRoomId) { roomId in
            ImmersiveGameFlow(roomId: roomId, membership: membership) {
                immersiveRoomId = nil
                // Re-fetch discovery so the tab reflects the room
                // moving from active → recent, and any XP awarded
                // shows up in the user's totals.
                Task {
                    if let gid = selectedGroupId {
                        await service.loadDiscovery(groupId: gid)
                    }
                    try? await SupabaseManager.shared.refreshCurrentUser()
                }
            }
        }
        .alert("Coming soon",
               isPresented: $showComingSoon) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This game type isn't playable from your phone yet. Watch the big screen!")
        }
    }

    // MARK: - Hero section (three states)

    @ViewBuilder
    private var heroSection: some View {
        if let active = service.activeGame {
            if active.status == .lobby {
                StartingSoonHeroCard(active: active) {
                    open(active: active)
                }
            } else {
                LiveNowHeroCard(active: active) {
                    open(active: active)
                }
            }
        } else {
            NoGameHeroCard(groupName: membership?.name)
        }
    }

    private func open(active: ActiveGame) {
        guard active.gameType.isPlayable else {
            showComingSoon = true
            return
        }
        immersiveRoomId = active.roomId
    }

    // MARK: - Recent section

    @ViewBuilder
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent games")
                .font(.lilitaOne(size: 19))
                .tracking(-0.4)
                .foregroundStyle(.white)

            if service.isLoadingDiscovery && service.recentGames.isEmpty {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else if service.recentGames.isEmpty {
                Text("No games yet — when your group plays one, it'll show up here.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 10) {
                    ForEach(service.recentGames) { game in
                        RecentGameRow(game: game)
                    }
                }
            }
        }
    }
}

// MARK: - Hero cards

/// "No game right now" — pure invite to wait. Matches the violet→pink
/// gradient of the active variants so the tab feels alive even when
/// the group isn't actively playing.
private struct NoGameHeroCard: View {
    let groupName: String?

    var body: some View {
        ZStack(alignment: .topLeading) {
            heroBackground

            VStack(alignment: .leading, spacing: 8) {
                Text("🎮 GAME NIGHT")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(.white.opacity(0.85))

                Text("No game right now")
                    .font(.lilitaOne(size: 30))
                    .tracking(-1)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(groupName.map { "When \($0) starts one, you'll see it here." }
                     ?? "Join a youth group to play with them on game night.")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .shadow(color: YGColors.violet.opacity(0.4), radius: 20, y: 16)
    }
}

/// "Starting soon" — lobby state. Shows the live countdown to start,
/// a small avatar stack of players in the lobby, and a primary Join
/// button. Spec'd to look identical to the React `GamesTabSoon`.
private struct StartingSoonHeroCard: View {
    let active: ActiveGame
    let onJoin: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            heroBackground

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text(active.gameType.emoji)
                        .font(.system(size: 15))
                    Text("STARTS SOON · \((active.groupName ?? "GAME NIGHT").uppercased())")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .tracking(1.8)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }

                Text(active.gameType.displayName)
                    .font(.lilitaOne(size: 32))
                    .tracking(-1)
                    .foregroundStyle(.white)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                countdownPanel
                    .padding(.bottom, 16)

                Button(action: onJoin) {
                    Text("Join the lobby →")
                        .font(.lilitaOne(size: 18))
                        .foregroundStyle(YGColors.ink)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .shadow(color: YGColors.violet.opacity(0.4), radius: 20, y: 16)
    }

    private var countdownPanel: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("STARTS IN")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.7))
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Text(fmtClock(secondsUntil(active.startsAt, now: ctx.date)))
                        .font(.lilitaOne(size: 46))
                        .tracking(-1)
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                LobbyAvatarStack(count: active.playerCount)
                Text("in the lobby")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.22))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func secondsUntil(_ start: Date?, now: Date) -> Int {
        guard let start else { return 0 }
        return max(0, Int(start.timeIntervalSince(now)))
    }

    private func fmtClock(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }
}

/// "Live now" — game is in_game / reveal. Question N of M + jump-in
/// button. Mirrors React `GamesTabLive`.
private struct LiveNowHeroCard: View {
    let active: ActiveGame
    let onJoin: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            heroBackground

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    livePill
                    Text((active.groupName ?? "GAME NIGHT").uppercased())
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }
                Text(active.gameType.displayName)
                    .font(.lilitaOne(size: 32))
                    .tracking(-1)
                    .foregroundStyle(.white)
                    .padding(.top, 10)
                    .padding(.bottom, 14)

                statusPanel
                    .padding(.bottom, 16)

                Button(action: onJoin) {
                    Text("Jump in →")
                        .font(.lilitaOne(size: 18))
                        .foregroundStyle(YGColors.ink)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .shadow(color: YGColors.violet.opacity(0.45), radius: 20, y: 16)
    }

    private var livePill: some View {
        HStack(spacing: 6) {
            PulseDot(color: .white, size: 7)
            Text("LIVE")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .tracking(0.5)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color(hex: "FB7185"))
        .clipShape(Capsule())
        .shadow(color: Color(hex: "FB7185").opacity(0.7), radius: 6)
    }

    private var statusPanel: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                if let q = active.currentQuestionIndex, let total = active.totalQuestions {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("Question \(q + 1)")
                            .font(.lilitaOne(size: 22))
                            .foregroundStyle(.white)
                        Text("of \(total)")
                            .font(.lilitaOne(size: 22))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                } else {
                    Text(active.status == .reveal ? "Revealing…" : "In progress")
                        .font(.lilitaOne(size: 22))
                        .foregroundStyle(.white)
                }
                Text("Jump in — you can still score")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.8))
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                LobbyAvatarStack(count: active.playerCount)
                Text("\(active.playerCount) playing")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.22))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

/// Shared violet→pink gradient + radial glow orb used by all three
/// hero variants. Extracted so a future visual tweak only happens in
/// one place.
@ViewBuilder
private var heroBackground: some View {
    ZStack(alignment: .topTrailing) {
        LinearGradient(
            colors: [YGColors.violet, YGColors.pink],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        Circle()
            .fill(RadialGradient(
                colors: [.white.opacity(0.25), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 80
            ))
            .frame(width: 170, height: 170)
            .offset(x: 30, y: -40)
    }
}

// MARK: - Recent game row

private struct RecentGameRow: View {
    let game: RecentGame

    private var accent: Color {
        switch game.gameType {
        case .majorityRules: return Color(hex: "FF3DA5")
        case .spend15:       return Color(hex: "34D399")
        case .chainLink:     return Color(hex: "38BDF8")
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if let place = game.myPlacement, place > 0 {
            parts.append("You placed #\(place)")
        }
        if let xp = game.myXpDelta, xp != 0 {
            let sign = xp > 0 ? "+" : ""
            parts.append("\(sign)\(xp) XP")
        }
        if parts.isEmpty, game.playerCount > 0 {
            parts.append("\(game.playerCount) played")
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 13)
                    .fill(accent.opacity(0.13))
                RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(accent.opacity(0.33), lineWidth: 1)
                Text(game.gameType.emoji)
                    .font(.system(size: 24))
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(game.gameType.displayName)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - Shared bits

/// Stacked avatar bubbles used in the hero card's "X in the lobby"
/// readout. Renders up to 4 placeholder bubbles plus a "+N" badge so
/// we don't need server-fetched per-player avatars for the discovery
/// payload — those come in once the user joins.
private struct LobbyAvatarStack: View {
    let count: Int
    private let emojis = ["🦊", "🐧", "🦄", "🦉"]

    var body: some View {
        let shown = min(emojis.count, max(0, count))
        let extra = max(0, count - shown)
        HStack(spacing: -9) {
            ForEach(0..<shown, id: \.self) { i in
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [YGColors.violet, YGColors.pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    Circle().strokeBorder(.white.opacity(0.9), lineWidth: 2)
                    Text(emojis[i])
                        .font(.system(size: 15))
                }
                .frame(width: 30, height: 30)
                .zIndex(Double(shown - i))
            }
            if extra > 0 {
                Text("+\(extra)")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.leading, 17)
            }
        }
    }
}

/// Single pulsing dot — used for the "LIVE" pill and the "you're in"
/// chip. Animation runs in-place via `.symbolEffect`-style scale to
/// avoid an explicit @State for each instance.
struct PulseDot: View {
    let color: Color
    let size: CGFloat
    @State private var on = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .scaleEffect(on ? 1.25 : 1.0)
            .opacity(on ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                       value: on)
            .onAppear { on = true }
    }
}

// MARK: - UUID Identifiable shim
// SwiftUI's `.fullScreenCover(item:)` needs Identifiable. UUID isn't
// Identifiable by default in the standard library.

extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}
