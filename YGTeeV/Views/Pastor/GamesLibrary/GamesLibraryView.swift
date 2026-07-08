//
//  GamesLibraryView.swift
//  YGTeeV
//
//  Pastor-side Games Library hub. Sits behind the dashboard's "Games"
//  tool row and presents:
//    • A big violet→pink "Play Live Game" button that runs the
//      Majority Rules launch RPC pair (gn_pastor_create_game +
//      gn_pastor_start) and confirms with the room code.
//    • Filter chips: age group (single-select including "All ages"),
//      a tag chip strip (derived from loaded games), and a Top / New
//      / A–Z sort segmented control.
//    • A ranked list of GameRow cards driven by `GamesLibraryService`.
//
//  Tapping a row pushes `GameDetailView(slug:)`. The library is
//  intentionally read-only here (no editing) — voting is the only
//  member-driven write.
//

import SwiftUI

struct GamesLibraryView: View {
    let groupId: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var service = GamesLibraryService.shared
    @State private var selectedAge: String? = nil
    @State private var selectedTags: Set<String> = []
    @State private var sort: GamesLibraryService.SortMode = .top
    @State private var pendingSlug: String?
    @State private var launchedCode: String?
    @State private var launchError: String?

    private let ageOptions: [(label: String, slug: String?)] = [
        ("All ages", nil),
        ("Elementary", "elementary"),
        ("Middle", "middle"),
        ("High", "high"),
        ("College", "college")
    ]

    /// Stable, ordered list of tag display labels found in `games`,
    /// used to seed the tag-chip strip. Derived client-side so a
    /// brand-new tag in the catalog shows up the moment its first
    /// game lands.
    private var availableTags: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for game in service.games {
            for tag in game.tags where !seen.contains(tag) {
                seen.insert(tag)
                ordered.append(tag)
            }
        }
        return ordered
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background

                ScrollView {
                    VStack(spacing: 18) {
                        playLiveCard
                        filtersStrip
                        ranked
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 60)
                }
                .refreshable { await reload() }
            }
            .navigationTitle("Games")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .task {
                if service.games.isEmpty {
                    await reload()
                }
            }
            .alert("Room is live 🎉",
                   isPresented: Binding(
                    get: { launchedCode != nil },
                    set: { if !$0 { launchedCode = nil } }
                   ),
                   presenting: launchedCode) { _ in
                Button("OK", role: .cancel) { launchedCode = nil }
            } message: { code in
                Text("Room \(code) is live — members can join from their Games tab.")
            }
            .alert("Couldn't start game",
                   isPresented: Binding(
                    get: { launchError != nil },
                    set: { if !$0 { launchError = nil } }
                   ),
                   presenting: launchError) { _ in
                Button("OK", role: .cancel) { launchError = nil }
            } message: { msg in
                Text(msg)
            }
        }
    }

    // MARK: - Sections

    private var background: some View {
        LinearGradient(
            colors: [Color(hex: "0C0916"), Color(hex: "1A0D3D")],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var playLiveCard: some View {
        Button(action: launchLive) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.22))
                    Image(systemName: "play.fill")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(.white)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Play Live Game")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Start Majority Rules for your group right now.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                if service.isLaunching {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(18)
            .background(
                LinearGradient(
                    colors: [Color(hex: "6B2BFF"), Color(hex: "FF3DA5")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color(hex: "6B2BFF").opacity(0.35), radius: 16, y: 10)
        }
        .buttonStyle(.plain)
        .disabled(service.isLaunching)
    }

    private var filtersStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ageOptions, id: \.label) { opt in
                        chip(label: opt.label,
                             isOn: selectedAge == opt.slug) {
                            selectedAge = opt.slug
                            Task { await reload() }
                        }
                    }
                }
                .padding(.horizontal, 2)
            }

            if !availableTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(availableTags, id: \.self) { tag in
                            chip(label: tag,
                                 isOn: selectedTags.contains(tag),
                                 tone: .tag) {
                                if selectedTags.contains(tag) {
                                    selectedTags.remove(tag)
                                } else {
                                    selectedTags.insert(tag)
                                }
                                Task { await reload() }
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }

            HStack(spacing: 8) {
                Text("SORT")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.45))
                ForEach(GamesLibraryService.SortMode.allCases) { mode in
                    chip(label: mode.label, isOn: sort == mode, tone: .sort) {
                        sort = mode
                        Task { await reload() }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 2)
        }
    }

    private enum ChipTone { case age, tag, sort }
    private func chip(label: String,
                      isOn: Bool,
                      tone: ChipTone = .age,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                .foregroundStyle(isOn ? .white : .white.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Group {
                        if isOn {
                            LinearGradient(
                                colors: [Color(hex: "6B2BFF"), Color(hex: "FF3DA5")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        } else {
                            Color.white.opacity(0.07)
                        }
                    }
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(
                        isOn ? Color.clear : Color.white.opacity(0.14),
                        lineWidth: 0.5
                    )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label), \(tone == .age ? "age filter" : tone == .tag ? "tag filter" : "sort option")")
    }

    @ViewBuilder
    private var ranked: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Group favorites")
                .font(.system(size: 19, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Spacer(minLength: 0)
            Text(sort == .az ? "A–Z" : (sort == .new ? "Newest" : "Ranked by votes"))
                .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(.top, 8)

        if service.isLoading && service.games.isEmpty {
            ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.vertical, 40)
        } else if service.games.isEmpty {
            Text("No games match those filters.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else {
            VStack(spacing: 10) {
                ForEach(Array(service.games.enumerated()), id: \.element.id) { idx, game in
                    NavigationLink {
                        GameDetailView(slug: game.slug, groupId: groupId)
                    } label: {
                        GameRow(game: game,
                                rank: idx + 1,
                                theme: service.theme(emoji: game.emoji,
                                                     accentColor: game.accentColor,
                                                     slug: game.slug),
                                onUp: { vote(game: game, value: 1) },
                                onDown: { vote(game: game, value: -1) })
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Actions

    private func reload() async {
        let tags = selectedTags.isEmpty ? nil : Array(selectedTags)
        await service.loadGames(ageGroup: selectedAge,
                                tagSlugs: tags,
                                sort: sort)
    }

    private func vote(game: GameListItem, value: Int) {
        let nextMy: Int = (game.myVote ?? 0) == value ? 0 : value
        service.applyOptimisticVote(gameId: game.id, nextMyVote: nextMy)
        Task { await service.vote(gameId: game.id, value: value) }
    }

    private func launchLive() {
        launchError = nil
        Task {
            do {
                let code = try await service.launchMajorityRules(groupId: groupId)
                launchedCode = code
            } catch {
                launchError = error.localizedDescription
            }
        }
    }
}

// MARK: - Row

struct GameRow: View {
    let game: GameListItem
    let rank: Int
    let theme: GameTheme
    let onUp: () -> Void
    let onDown: () -> Void

    private var medalColor: Color? {
        switch rank {
        case 1: return Color(hex: "FFB800")
        case 2: return Color(hex: "9AA3B2")
        case 3: return Color(hex: "CD7F4B")
        default: return nil
        }
    }

    private var footerLine: String {
        var parts: [String] = []
        if let firstTag = game.tags.first { parts.append(firstTag) }
        if let mn = game.minMinutes, let mx = game.maxMinutes {
            parts.append("\(mn)–\(mx) min")
        } else if let mn = game.minMinutes {
            parts.append("\(mn)+ min")
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 0) {
            voteRail
            content
        }
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    private var voteRail: some View {
        VStack(spacing: 2) {
            Button(action: onUp) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(game.myVote == 1 ? Color(hex: "FF3DA5") : .white.opacity(0.45))
                    .frame(width: 30, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("\(game.score)")
                .font(.system(size: 13.5, weight: .black, design: .rounded))
                .foregroundStyle(
                    game.myVote == 1 ? Color(hex: "FF3DA5")
                    : game.myVote == -1 ? Color(hex: "0066FF")
                    : .white
                )

            Button(action: onDown) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(game.myVote == -1 ? Color(hex: "0066FF") : .white.opacity(0.45))
                    .frame(width: 30, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: 46)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.03))
    }

    private var content: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(theme.gradient)
                Text(theme.emoji)
                    .font(.system(size: 26))
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)

                rankBadge
                    .offset(x: -22, y: -22)
            }
            .frame(width: 52, height: 52)
            .padding(.leading, 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(game.name)
                    .font(.system(size: 15.5, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(game.summary)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
                if !footerLine.isEmpty {
                    HStack(spacing: 6) {
                        Circle().fill(theme.accent).frame(width: 5, height: 5)
                        Text(footerLine)
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .tracking(0.4)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(.white.opacity(0.35))
                .padding(.trailing, 12)
        }
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var rankBadge: some View {
        ZStack {
            if let color = medalColor {
                Circle().fill(color)
                Text("\(rank)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            } else {
                Circle().fill(Color(hex: "1A0D3D"))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
                Text("\(rank)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(width: 22, height: 22)
        .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
    }
}
