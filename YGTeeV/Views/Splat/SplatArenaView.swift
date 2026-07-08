//
//  SplatArenaView.swift
//  YGTeeV
//
//  Full-screen playable surface for the daily Splat melee. Presented
//  as a `.fullScreenCover` from the Plans hero banner.
//
//  Layout (top → bottom):
//    1. Header — close X, "YGTEEV SPLAT / 4-WAY MELEE" title, XP pill
//    2. Live timer row — red dot + "LIVE · HH:MM:SS LEFT"
//    3. Leaderboard — 4 paint-fill rows (`SplatLeaderboardRow`),
//       sorted by score, re-ranking via spring animation. Each row's
//       paint level grows L→R with a wobbling wave edge; bumps + drips
//       fire on score increments.
//    4. Tap zone (`SplatTapZone`) — gooey particle bursts on tap.
//    5. XP wallet bar
//
//  Overlays:
//    • Empty wallet — when `localXp <= 0`, tap zone is locked and a
//      card prompts the user to refill via plans
//    • End-of-round — frozen snapshot of final standings (sticky,
//      can't be re-evaluated false by an external round refresh)
//
//  Network model — UNCHANGED from prior version:
//    • Taps accumulate locally (optimistic team-score bump) and
//      flush to `splat_tap_batch` every 2s, immediately at >= 25
//      pending, or on dismiss / background.
//    • Leaderboard polled every 5s while open (server's 15-min
//      round cadence doesn't need more).
//    • Server's `yourTeamScore` reconciles drift; the user's own
//      team uses MAX(optimistic, server) so the bar never slides
//      backward between flush and refresh.
//

import SwiftUI
import UIKit

// MARK: - Tunables

private enum SplatTune {
    /// How often the local accumulator gets flushed to the server.
    static let flushInterval: TimeInterval = 2.0
    /// Pending-tap threshold that triggers an immediate flush.
    static let flushThreshold: Int = 25
    /// Live-poll interval for the leaderboard while the arena is open.
    /// 5s per the v2 spec — 15-min rounds don't benefit from faster
    /// polling, and we save bandwidth + battery.
    static let leaderboardPollInterval: TimeInterval = 5.0
    /// Cost-per-tap. Matches the server contract.
    static let xpPerTap: Int = 1
    /// How often the particle pruner sweeps dead particles out of
    /// `@State`. Particles render via TimelineView regardless, so
    /// this is purely a memory hygiene step.
    static let particlePruneInterval: TimeInterval = 0.5
}

// MARK: - View

struct SplatArenaView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    private let splatService = SplatService.shared

    /// Optimistic per-color score state. Seeded from the leaderboard
    /// on first render. Server reconciles drift on every poll +
    /// after every flush.
    @State private var optimisticScores: [SplatTeamColor: Int] = [:]

    /// Per-team "last bumped" timestamps. Drives the spring scale
    /// + amplitude spike on the row. Set when the user taps (own
    /// team) and when the server poll shows a team's score grew.
    @State private var bumpedAt: [SplatTeamColor: Date] = [:]

    /// Taps the user has registered locally but not yet flushed.
    @State private var pendingTaps: Int = 0

    /// Wallet — counts down locally as taps fire; reconciled
    /// against `remainingXp` on every batch response.
    @State private var localXp: Int = 0
    @State private var startXp: Int = 0

    /// Live particle list. Append-only here; the SplatTapZone reads
    /// via @Binding and the prune task drops dead entries.
    @State private var particles: [SplatParticle] = []

    /// Background loops. All owned by the view so teardown can
    /// cancel them cleanly.
    @State private var pollTask: Task<Void, Never>?
    @State private var flushTask: Task<Void, Never>?
    @State private var pruneTask: Task<Void, Never>?

    /// Sticky round-over flag — once true, never flips back.
    @State private var isRoundOver: Bool = false
    @State private var finalizedRoundId: UUID?
    @State private var finalRows: [SplatTeamRow] = []
    @State private var finalMyColor: SplatTeamColor?

    private let hapticTap = UIImpactFeedbackGenerator(style: .soft)

    var body: some View {
        ZStack {
            SplatPalette.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top chrome panel
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 16)
                        .padding(.top, 6)

                    timerRow
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    leaderboardSection
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, 14)
                }

                tapZoneSection
                    .padding(.horizontal, 12)
                    .padding(.top, 12)

                Spacer(minLength: 0)

                walletBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 18)
                    .padding(.top, 12)
            }

            if localXp <= 0 && !isRoundOver {
                emptyWalletOverlay
                    .transition(.opacity.combined(with: .scale))
            }
            if isRoundOver {
                endOfRoundOverlay
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .task { await onFirstAppear() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { Task { await flushNow() } }
        }
        .onDisappear { teardown() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Button {
                Task {
                    await flushNow()
                    dismiss()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(.white.opacity(0.12)))
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text("YGTEEV SPLAT")
                    .font(.lilitaOne(size: 16))
                    .tracking(1.0)
                    .foregroundStyle(.white)
                Text("4-WAY MELEE")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(YGColors.xp)
                Text("\(max(0, localXp))")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Capsule().fill(.white.opacity(0.12)))
        }
    }

    // MARK: - Live timer row

    private var timerRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .modifier(PulseModifier())

            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(liveTimerText(at: context.date))
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .onChange(of: context.date) { _, _ in
                        evaluateRoundOver()
                    }
            }

            Spacer()
        }
    }

    private func liveTimerText(at date: Date) -> String {
        guard let endsAt = splatService.currentRound?.roundEndsAt else {
            return "LOADING…"
        }
        let interval = max(0, endsAt.timeIntervalSince(date))
        let total = Int(interval)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "LIVE · %02d:%02d:%02d LEFT", h, m, s)
    }

    // MARK: - Leaderboard (paint fills)

    /// One TimelineView for the whole rank stack so every row gets
    /// the same `phase` and re-renders together. The .spring animation
    /// applies to row order — when scores cause a re-rank, rows
    /// slide into their new positions instead of jump-cutting.
    private var leaderboardSection: some View {
        TimelineView(.animation) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
            let rows = orderedRows
            let total = rows.reduce(0) { $0 + $1.score }
            let myColor = splatService.currentRound?.yourColor

            VStack(spacing: 8) {
                ForEach(rows) { row in
                    SplatLeaderboardRow(
                        team: row,
                        isYou: row.color == myColor,
                        totalScore: total,
                        phase: phase,
                        bumpedAt: bumpedAt[row.color]
                    )
                }
            }
            .animation(
                .spring(response: 0.4, dampingFraction: 0.7),
                value: rows.map(\.color)
            )
        }
    }

    /// Merge optimistic + server scores into a re-ranked list keyed
    /// by team color (so ForEach diffing is by identity, not by
    /// position).
    private var orderedRows: [SplatTeamRow] {
        let serverByColor = Dictionary(
            uniqueKeysWithValues: splatService.leaderboard.map { ($0.color, $0) }
        )
        let merged: [SplatTeamRow] = SplatTeamColor.allCases.map { color in
            let server = serverByColor[color]
            let optimistic = optimisticScores[color] ?? server?.score ?? 0
            return SplatTeamRow(
                color: color,
                score: optimistic,
                pct: server?.pct ?? 0,
                rank: server?.rank ?? 0
            )
        }
        let sorted = merged.sorted { $0.score > $1.score }
        // Recompute pct over the displayed (optimistic-merged)
        // totals so the row label and the paint fill agree visually
        // — server's pct is from its snapshot, which may lag.
        let total = sorted.reduce(0) { $0 + $1.score }
        return sorted.enumerated().map { idx, r in
            let pct = total > 0 ? (Double(r.score) / Double(total)) * 100 : 0
            return SplatTeamRow(color: r.color, score: r.score, pct: pct, rank: idx + 1)
        }
    }

    // MARK: - Tap zone

    private var tapZoneSection: some View {
        SplatTapZone(
            particles: $particles,
            teamColor: splatService.currentRound?.yourColor,
            onTap: { location in
                registerTap(at: location)
            },
            isLocked: isRoundOver || localXp <= 0
        )
    }

    // MARK: - Wallet bar

    private var walletBar: some View {
        let denom = max(startXp, 1)
        let frac = max(0, min(1, Double(localXp) / Double(denom)))
        return HStack(spacing: 10) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(YGColors.xp)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12))
                    Capsule()
                        .fill(YGColors.xp)
                        .frame(width: geo.size.width * frac)
                        .animation(.easeOut(duration: 0.25), value: localXp)
                }
            }
            .frame(height: 8)
            Text("\(max(0, localXp))")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }

    // MARK: - Empty wallet overlay

    private var emptyWalletOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "bolt.slash.fill")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(YGColors.xp)
                Text("OUT OF XP")
                    .font(.lilitaOne(size: 22))
                    .tracking(1.2)
                    .foregroundStyle(.white)
                Text("Read a plan to refill your wallet and jump back in.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Button {
                    Task {
                        await flushNow()
                        dismiss()
                    }
                } label: {
                    Text("Refill")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(YGColors.ink)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(.white))
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 28)
            .background(RoundedRectangle(cornerRadius: 24).fill(.black.opacity(0.6)))
            .overlay(
                RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.12), lineWidth: 1)
            )
        }
    }

    // MARK: - End-of-round overlay

    private var endOfRoundOverlay: some View {
        let rows = finalRows.isEmpty ? orderedRows : finalRows
        let winner = rows.first
        let myColor = finalMyColor ?? splatService.currentRound?.yourColor
        let total = rows.reduce(0) { $0 + $1.score }
        let didWin = myColor != nil && myColor == winner?.color
        return ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 14) {
                Text(didWin ? "YOU WON" : "ROUND OVER")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.65))

                if let winner {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(SplatPalette.light(for: winner.color))
                            .frame(width: 18, height: 18)
                        Text("\(winner.color.teamName.uppercased()) WINS")
                            .font(.lilitaOne(size: 26))
                            .tracking(1.0)
                            .foregroundStyle(.white)
                    }
                }

                // Frozen final standings — same row component as the
                // live board, just with bumpedAt = nil so nothing
                // animates.
                TimelineView(.animation) { context in
                    let phase = context.date.timeIntervalSinceReferenceDate
                    VStack(spacing: 8) {
                        ForEach(rows) { row in
                            SplatLeaderboardRow(
                                team: row,
                                isYou: row.color == myColor,
                                totalScore: total,
                                phase: phase,
                                bumpedAt: nil
                            )
                        }
                    }
                }

                Button {
                    dismiss()
                } label: {
                    Text("Close")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(YGColors.ink)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(.white))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding(.vertical, 22)
            .padding(.horizontal, 22)
            .frame(maxWidth: 360)
            .background(RoundedRectangle(cornerRadius: 24).fill(.black.opacity(0.6)))
            .overlay(
                RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.12), lineWidth: 1)
            )
            .padding(.horizontal, 28)
        }
    }

    // MARK: - Lifecycle

    private func onFirstAppear() async {
        hapticTap.prepare()
        await splatService.refreshCurrentRound()
        await splatService.refreshLeaderboard()
        seedFromServer()
        startPollLoop()
        startFlushLoop()
        startPruneLoop()
        evaluateRoundOver()
    }

    private func seedFromServer() {
        var byColor: [SplatTeamColor: Int] = [:]
        for row in splatService.leaderboard {
            byColor[row.color] = row.score
        }
        for c in SplatTeamColor.allCases where byColor[c] == nil {
            byColor[c] = 0
        }
        self.optimisticScores = byColor

        let xp = splatService.currentRound?.yourXp ?? 0
        self.localXp = xp
        if self.startXp <= 0 { self.startXp = max(xp, 1) }
    }

    private func startPollLoop() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(
                    nanoseconds: UInt64(SplatTune.leaderboardPollInterval * 1_000_000_000)
                )
                guard !Task.isCancelled else { return }
                await splatService.refreshLeaderboard()
                reconcileLeaderboard()
            }
        }
    }

    private func startFlushLoop() {
        flushTask?.cancel()
        flushTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(
                    nanoseconds: UInt64(SplatTune.flushInterval * 1_000_000_000)
                )
                guard !Task.isCancelled else { return }
                await flushNow()
            }
        }
    }

    private func startPruneLoop() {
        pruneTask?.cancel()
        pruneTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(
                    nanoseconds: UInt64(SplatTune.particlePruneInterval * 1_000_000_000)
                )
                guard !Task.isCancelled else { return }
                let now = Date()
                particles.removeAll { !$0.isAlive(at: now) }
            }
        }
    }

    private func teardown() {
        pollTask?.cancel()
        flushTask?.cancel()
        pruneTask?.cancel()
        pollTask = nil
        flushTask = nil
        pruneTask = nil
        Task { await flushNow() }
    }

    private func evaluateRoundOver() {
        guard !isRoundOver else { return }
        guard let round = splatService.currentRound else { return }
        guard Date() >= round.roundEndsAt else { return }

        finalRows = orderedRows
        finalizedRoundId = round.roundId
        finalMyColor = round.yourColor

        pollTask?.cancel()
        flushTask?.cancel()
        pollTask = nil
        flushTask = nil

        Task { await flushNow() }

        withAnimation(.easeOut(duration: 0.25)) { isRoundOver = true }
    }

    // MARK: - Tap registration

    private func registerTap(at location: CGPoint) {
        hapticTap.impactOccurred()

        if let mine = splatService.currentRound?.yourColor {
            optimisticScores[mine, default: 0] += 1
            bumpedAt[mine] = Date()
        }

        localXp = max(0, localXp - SplatTune.xpPerTap)
        pendingTaps += 1

        // Spawn the gooey burst at the tap location.
        let newBurst = SplatTapZone.spawnBurst(at: location)
        particles.append(contentsOf: newBurst)

        if pendingTaps >= SplatTune.flushThreshold {
            Task { await flushNow() }
        }
    }

    // MARK: - Flush

    private func flushNow() async {
        let toSend = pendingTaps
        guard toSend > 0 else { return }
        pendingTaps = 0
        do {
            let result = try await splatService.sendTaps(toSend)
            optimisticScores[result.yourColor] = result.yourTeamScore
            localXp = result.remainingXp
        } catch {
            pendingTaps += toSend
            print("[SplatArenaView] flushNow failed:", error)
        }
    }

    /// Apply the latest leaderboard snapshot on top of optimistic
    /// state. For each non-self team where the server score is
    /// higher than our cached optimistic, set `bumpedAt` so the row
    /// visually springs as it catches up.
    private func reconcileLeaderboard() {
        let mine = splatService.currentRound?.yourColor
        for row in splatService.leaderboard {
            if row.color == mine {
                optimisticScores[row.color] = max(optimisticScores[row.color] ?? 0, row.score)
            } else {
                let prev = optimisticScores[row.color] ?? 0
                if row.score > prev {
                    bumpedAt[row.color] = Date()
                }
                optimisticScores[row.color] = row.score
            }
        }
    }
}

// MARK: - Pulse modifier (LIVE dot)

private struct PulseModifier: ViewModifier {
    @State private var pulse = false
    func body(content: Content) -> some View {
        content
            .opacity(pulse ? 0.4 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
    }
}

#Preview {
    SplatArenaView()
}
