//
//  GameDetailView.swift
//  YGTeeV
//
//  Pastor-side detail screen for a single library game. Pushed from
//  `GamesLibraryView` via NavigationStack. Layout mirrors the
//  games.jsx mock:
//    • 280pt gradient hero with a large rotated emoji and a tag pill.
//    • Heavy title + summary blurb.
//    • 2×2 meta grid (Duration / Group Size / Ages / Materials).
//    • "How to play" body, with paragraph breaks preserved if the
//      `instructions` field is multi-paragraph.
//    • Sticky bottom "Play this with the group" button that runs the
//      SAME launch flow as the hub (gn_pastor_create_game +
//      gn_pastor_start) and shows the room-code confirmation.
//
//  The detail view fetches via `gl_get_game(slug)` — it doesn't reuse
//  the list cache because list rows only carry summary fields. The
//  vote rail is omitted on detail; voting happens from the list.
//

import SwiftUI

struct GameDetailView: View {
    let slug: String
    let groupId: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var service = GamesLibraryService.shared
    @State private var detail: GameDetail?
    @State private var loadError: String?
    @State private var launchedCode: String?
    @State private var launchError: String?

    private var theme: GameTheme {
        service.theme(emoji: detail?.emoji,
                      accentColor: detail?.accentColor,
                      slug: slug)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero
                    metaGrid
                    divider
                    instructionsSection
                    Spacer(minLength: 120)
                }
            }
            .background(Color(hex: "0C0916").ignoresSafeArea())
            .ignoresSafeArea(edges: .top)

            stickyLaunchBar
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) {
            backButton
        }
        .task { await load() }
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

    // MARK: - Sections

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            theme.gradient
                .ignoresSafeArea(edges: .top)

            Text(theme.emoji)
                .font(.system(size: 190))
                .rotationEffect(.degrees(-8))
                .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
                .offset(x: 90, y: 38)
                .opacity(0.9)

            LinearGradient(
                colors: [Color.black.opacity(0.15), Color.clear, Color.black.opacity(0.45)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 10) {
                if let tag = detail?.tags.first {
                    HStack(spacing: 6) {
                        Circle().fill(Color.white).frame(width: 6, height: 6)
                        Text(tag.uppercased())
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .tracking(1.4)
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial.opacity(0.5))
                    .background(Color.black.opacity(0.3))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
                }

                Text(detail?.name ?? " ")
                    .font(.lilitaOne(size: 40))
                    .tracking(-1)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 18, y: 2)
                    .lineLimit(2)

                if let summary = detail?.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                        .lineSpacing(2)
                        .frame(maxWidth: 300, alignment: .leading)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .frame(height: 320)
        .clipped()
    }

    private var metaGrid: some View {
        let cols = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
        return LazyVGrid(columns: cols, alignment: .leading, spacing: 18) {
            metaCell(icon: "clock", label: "DURATION", value: durationValue)
            metaCell(icon: "person.3", label: "GROUP SIZE", value: groupValue)
            metaCell(icon: "birthday.cake", label: "AGES", value: agesValue)
            metaCell(icon: "basket", label: "MATERIALS", value: materialsValue)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
            .padding(.horizontal, 18)
            .padding(.top, 14)
    }

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How to play")
                .font(.lilitaOne(size: 28))
                .tracking(-0.6)
                .foregroundStyle(.white)
                .padding(.top, 14)

            if let body = detail?.instructions, !body.isEmpty {
                ForEach(Array(paragraphs(in: body).enumerated()), id: \.offset) { _, para in
                    Text(para)
                        .font(.system(size: 15.5))
                        .lineSpacing(4)
                        .foregroundStyle(.white.opacity(0.85))
                }
            } else if loadError != nil {
                Text(loadError ?? "")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.red)
            } else {
                // Skeleton while loading
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 12)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
    }

    private var stickyLaunchBar: some View {
        VStack {
            Button(action: launch) {
                HStack(spacing: 10) {
                    if service.isLaunching {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16, weight: .heavy))
                    }
                    Text("Play this with the group")
                        .font(.system(size: 16.5, weight: .black, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "6B2BFF"), Color(hex: "FF3DA5")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: Color(hex: "6B2BFF").opacity(0.45), radius: 18, y: 10)
            }
            .buttonStyle(.plain)
            .disabled(service.isLaunching)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .background(
            LinearGradient(
                colors: [Color(hex: "0C0916").opacity(0), Color(hex: "0C0916")],
                startPoint: .top,
                endPoint: .center
            )
        )
    }

    private var backButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial.opacity(0.5))
                .background(Color.black.opacity(0.4))
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
        }
        .padding(.leading, 16)
        .padding(.top, 60)
    }

    // MARK: - Helpers

    private func metaCell(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                Text(label)
                    .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.45))
            }
            Text(value)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var durationValue: String {
        guard let d = detail else { return "—" }
        if let mn = d.minMinutes, let mx = d.maxMinutes { return "\(mn)–\(mx) min" }
        if let mn = d.minMinutes { return "\(mn)+ min" }
        return "—"
    }

    private var groupValue: String {
        guard let d = detail else { return "—" }
        if let mn = d.minPlayers, let mx = d.maxPlayers { return "\(mn)–\(mx)" }
        if let mn = d.minPlayers { return "\(mn)+" }
        return "—"
    }

    private var agesValue: String {
        guard let d = detail else { return "—" }
        if let mn = d.minAge, let mx = d.maxAge { return "\(mn)–\(mx)" }
        if let mn = d.minAge { return "\(mn)+" }
        return "—"
    }

    private var materialsValue: String {
        let m = detail?.materials?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return m.isEmpty ? "None needed" : m
    }

    /// Split instructions on blank lines so multi-paragraph bodies
    /// render with whitespace between them. Single-paragraph bodies
    /// fall through as one block.
    private func paragraphs(in body: String) -> [String] {
        body
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func load() async {
        loadError = nil
        do {
            self.detail = try await service.getGame(slug: slug)
        } catch {
            self.loadError = error.localizedDescription
        }
    }

    private func launch() {
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
