//
//  PastorPlanDayReaderView.swift
//  YGTeeV
//
//  Member-side player for one pastor-plan day. Sequential — one block at
//  a time — matching plan-do.jsx: top bar with day pill, gradient
//  mini-banner, dot-trail progress, block content card, contextual CTA.
//

import SwiftUI
import AVKit

struct PastorPlanDayReaderView: View {
    let planId: UUID
    let dayNumber: Int
    let planTitle: String
    /// True when the member is replaying a day they've already completed.
    /// Suppresses the RPC call on "finish" and re-labels the final CTA
    /// to "Close" — the celebration sheet won't re-trigger.
    var isCompleted: Bool = false
    let onClose: () -> Void
    let onDayCompleted: () -> Void

    @State private var service = PlansService.shared
    @State private var bibleService = BibleAPIService.shared
    @State private var payload: PastorPlanDayPayload?
    @State private var currentIndex: Int = 0
    @State private var completedIndices: Set<Int> = []
    @State private var answersByBlock: [UUID: Int] = [:]   // questionId -> selected
    @State private var versesByReference: [String: [BibleVerse]] = [:]
    @State private var versesLoading: Set<String> = []
    /// Cache of resolved Mux HLS URLs for video blocks that only carry a
    /// `video_id` (not a pre-baked url). Filled on first appear when the
    /// `videos` row reports `status='ready'`.
    @State private var resolvedVideoURLByVideoId: [UUID: String] = [:]
    @State private var isSaving = false
    @State private var celebration: DayCompletionResult?

    private var blocks: [Block] { payload?.blocks ?? [] }
    private var currentBlock: Block? { blocks.indices.contains(currentIndex) ? blocks[currentIndex] : nil }
    private var isLastBlock: Bool { currentIndex == blocks.count - 1 }

    var body: some View {
        ZStack {
            YGColors.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                miniBanner
                progressDots
                content
            }

            VStack {
                Spacer()
                footer
            }

            if isSaving {
                Color.black.opacity(0.15).ignoresSafeArea()
                ProgressView().tint(.white)
                    .padding(20)
                    .background(.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .task(id: "\(planId)-\(dayNumber)") {
            await service.loadDayPayload(planId: planId, dayNumber: dayNumber)
            payload = service.pastorPlanDayPayloads.values
                .first(where: { $0.dayNumber == dayNumber })
        }
        .sheet(item: $celebration) { result in
            CelebrationSheet(result: result, planTitle: planTitle) {
                celebration = nil
                onDayCompleted()
                onClose()
            }
            .presentationDetents([.large])
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(YGColors.ink)
                    .frame(width: 38, height: 38)
                    .background(.white)
                    .clipShape(Circle())
                    .overlay { Circle().strokeBorder(.black.opacity(0.06), lineWidth: 0.5) }
                    .shadow(color: YGColors.ink.opacity(0.04), radius: 2, y: 1)
            }
            .buttonStyle(.plain)

            VStack(spacing: 1) {
                Text("DAY \(dayNumber)")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(YGColors.ink.opacity(0.5))
                Text(planTitle)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(YGColors.ink)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 3) {
                Text("🔥").font(.system(size: 13))
                Text("\(SupabaseManager.shared.currentUser?.streak ?? 0)")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: "FF6B35"))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(hex: "FF6B35").opacity(0.10))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(YGColors.paper.opacity(0.92))
    }

    // MARK: - Mini banner

    private var miniBanner: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(planTitle.uppercased()) · DAY \(dayNumber)")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.85))
                Text(currentBlockTitle)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .center, spacing: 2) {
                Text("REWARD")
                    .font(.system(size: 9.5, weight: .heavy))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.8))
                HStack(spacing: 5) {
                    HStack(spacing: 2) { Text("⚡"); Text("\(planBaseXP())") }
                    Text("·").opacity(0.4)
                    HStack(spacing: 2) { Text("💧"); Text("4") }
                }
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.22))
            .clipShape(RoundedRectangle(cornerRadius: 11))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            LinearGradient(colors: [YGColors.violet, Color(hex: "FF3DA5")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: YGColors.violet.opacity(0.35), radius: 12, y: 6)
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private var currentBlockTitle: String {
        guard let block = currentBlock else { return payload?.title ?? "Day \(dayNumber)" }
        switch block {
        case .reading(_, let verses):     return verses.isEmpty ? "Bible reading" : verses
        case .commentary(_, let t, _):    return t.isEmpty ? "Commentary" : t
        case .video(_, let t, _, _, _):   return t.isEmpty ? "Video" : t
        case .question:                   return "Question"
        case .prayer(_, let t, _, _):     return t.isEmpty ? "Prayer" : t
        }
    }

    private func planBaseXP() -> Int {
        let questionCount = blocks.reduce(0) { acc, b in
            if case .question = b { return acc + 1 } else { return acc }
        }
        return 500 + questionCount * 50
    }

    // MARK: - Progress dots

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(blocks.count, 1), id: \.self) { i in
                let done = completedIndices.contains(i)
                let active = i == currentIndex
                Rectangle()
                    .fill(done ? Color(hex: "B4FF3C")
                          : active ? YGColors.ink
                          : YGColors.ink.opacity(0.12))
                    .frame(height: 5)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .shadow(color: done ? Color(hex: "B4FF3C").opacity(0.5) : .clear,
                            radius: 4, y: 0)
            }
            Text("\(completedIndices.count)/\(max(blocks.count, 1))")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(YGColors.ink.opacity(0.6))
                .frame(minWidth: 36, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Body content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let block = currentBlock {
                    blockTypePill(for: block)
                    blockBody(block)
                } else {
                    ProgressView().padding(.top, 60)
                }
            }
            .padding(16)
            .padding(.bottom, 140)
        }
    }

    @ViewBuilder
    private func blockTypePill(for block: Block) -> some View {
        let (label, emoji, accent, tint) = pillStyle(for: block)
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Text(emoji).font(.system(size: 12))
                Text(label)
                    .font(.system(size: 10.5, weight: .heavy))
                    .tracking(0.7)
            }
            .foregroundStyle(accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(tint)
            .clipShape(Capsule())

            Spacer()

            Text("Block \(currentIndex + 1) of \(blocks.count)")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(YGColors.ink.opacity(0.5))
        }
    }

    private func pillStyle(for block: Block) -> (String, String, Color, Color) {
        switch block {
        case .reading:    return ("BIBLE READING", "📖", Color(hex: "1A1330"), Color(hex: "F0EDF8"))
        case .commentary: return ("COMMENTARY",    "✍️", Color(hex: "0066FF"), Color(hex: "E6F0FF"))
        case .video:      return ("VIDEO",         "🎥", Color(hex: "FF3DA5"), Color(hex: "FFE5F2"))
        case .question:   return ("QUESTION",      "❓", Color(hex: "B8860B"), Color(hex: "FFF6CC"))
        case .prayer:     return ("PRAYER",        "🙏", Color(hex: "6B2BFF"), Color(hex: "EFE6FF"))
        }
    }

    @ViewBuilder
    private func blockBody(_ block: Block) -> some View {
        switch block {
        case .reading(_, let verses):
            readingBlock(verses: verses)
        case .commentary(_, let title, let body):
            commentaryBlock(title: title, body: body)
        case .video(_, let title, let url, let dur, let videoId):
            videoBlock(title: title, url: url, durationSeconds: dur, videoId: videoId)
        case .question(let id, let prompt, let options, _):
            questionBlock(id: id, prompt: prompt, options: options)
        case .prayer(_, let title, let body, let dur):
            prayerBlock(title: title, body: body, durationMinutes: dur)
        }
    }

    // MARK: - Block bodies

    private func readingBlock(verses: String) -> some View {
        let cached  = versesByReference[verses]
        let loading = versesLoading.contains(verses)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verses.isEmpty ? "Bible reading" : verses)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(YGColors.ink)
                    Text("NLT · take your time")
                        .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                        .tracking(0.4)
                        .foregroundStyle(YGColors.ink.opacity(0.55))
                }
                Spacer()
            }
            .padding(.bottom, 12)

            Divider().padding(.vertical, 4)

            if let cached, !cached.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(cached) { verse in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(verse.number)")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(YGColors.violet)
                                .frame(minWidth: 18, alignment: .trailing)
                            Text(verse.text)
                                .font(.system(size: 16, design: .serif))
                                .foregroundStyle(YGColors.ink.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 8)
            } else if loading {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Fetching from Bible API…")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(YGColors.ink.opacity(0.55))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(YGColors.violet)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 18)
                    Text("Couldn't load this passage. Open your Bible and read it manually, then tap **I've read this**.")
                        .font(.system(size: 13, design: .serif))
                        .foregroundStyle(YGColors.ink.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "clock")
                Text("Take your time")
            }
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .foregroundStyle(YGColors.ink.opacity(0.5))
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: YGColors.ink.opacity(0.04), radius: 4, y: 2)
        .task(id: verses) {
            await loadVerses(for: verses)
        }
    }

    private func loadVerses(for reference: String) async {
        let trimmed = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              versesByReference[trimmed] == nil,
              !versesLoading.contains(trimmed) else { return }

        versesLoading.insert(trimmed)
        defer { versesLoading.remove(trimmed) }
        do {
            let fetched = try await bibleService.versesForReference(trimmed)
            versesByReference[trimmed] = fetched
        } catch {
            print("[PastorPlanDayReader] verses fetch failed:", error)
        }
    }

    private func commentaryBlock(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(YGColors.ink)
                    .multilineTextAlignment(.leading)
            }
            Text(body)
                .font(.system(size: 16, design: .serif))
                .foregroundStyle(YGColors.ink.opacity(0.82))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: YGColors.ink.opacity(0.04), radius: 4, y: 2)
    }

    private func videoBlock(title: String, url: String, durationSeconds: Int?, videoId: UUID?) -> some View {
        // Prefer the inline url. If it's empty, fall back to the
        // cache that gets populated when we resolve `videos.mux_playback_id`
        // for a video_id-only block on appear.
        let resolved = !url.isEmpty
            ? url
            : (videoId.flatMap { resolvedVideoURLByVideoId[$0] } ?? "")

        return VStack(alignment: .leading, spacing: 12) {
            if let videoURL = URL(string: resolved), !resolved.isEmpty {
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .aspectRatio(9.0/16.0, contentMode: .fit)
                    .frame(maxHeight: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: YGColors.ink.opacity(0.3), radius: 12, y: 6)
            } else if videoId != nil {
                // We have a video_id but Mux hasn't finished encoding
                // (or the server hasn't returned the playback id yet).
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Video is still processing…")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(YGColors.ink.opacity(0.55))
                }
                .frame(maxWidth: .infinity, minHeight: 200)
                .background(YGColors.ink.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                Text("Video URL missing")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .background(YGColors.ink.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundStyle(YGColors.ink)
            }
            if let durationSeconds {
                Text("Duration: \(formatDuration(durationSeconds))")
                    .font(.system(size: 12))
                    .foregroundStyle(YGColors.ink.opacity(0.55))
            }
        }
        .task(id: videoId) {
            guard let vid = videoId,
                  url.isEmpty,
                  resolvedVideoURLByVideoId[vid] == nil else { return }
            if let row = try? await PastorPlanService.shared.fetchPlanVideo(id: vid),
               row.status == "ready",
               let pid = row.muxPlaybackId, !pid.isEmpty {
                resolvedVideoURLByVideoId[vid] = "https://stream.mux.com/\(pid).m3u8"
            }
        }
    }

    private func questionBlock(id: UUID, prompt: String, options: [String]) -> some View {
        let selected = answersByBlock[id]
        return VStack(alignment: .leading, spacing: 12) {
            // XP banner
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(YGColors.ink)
                    .frame(width: 28, height: 28)
                    .background(Color(hex: "FFD60A"))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                Text("**Earn +50 XP** for the right answer.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(YGColors.ink.opacity(0.78))
                Spacer()
            }
            .padding(10)
            .background(Color(hex: "FFD60A").opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Color(hex: "FFD60A").opacity(0.5), lineWidth: 0.5) }

            Text(prompt)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(YGColors.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(Array(options.enumerated()), id: \.offset) { idx, option in
                    Button { answersByBlock[id] = idx } label: {
                        HStack(spacing: 12) {
                            Text(letter(idx))
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(YGColors.ink)
                                .frame(width: 28, height: 28)
                                .background(.white)
                                .clipShape(Circle())
                                .overlay { Circle().strokeBorder(.black.opacity(0.12), lineWidth: 1.2) }
                            Text(option)
                                .font(.system(size: 14.5))
                                .foregroundStyle(YGColors.ink)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(14)
                        .background(selected == idx ? Color(hex: "B4FF3C") : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(selected == idx ? Color(hex: "8FD92A") : .black.opacity(0.06),
                                              lineWidth: selected == idx ? 1.5 : 0.5)
                        }
                        .shadow(color: selected == idx ? Color(hex: "8FD92A").opacity(0.45) : YGColors.ink.opacity(0.04),
                                radius: selected == idx ? 10 : 2, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func prayerBlock(title: String, body: String, durationMinutes: Int?) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("A PRAYER FOR TODAY")
                    .font(.system(size: 10.5, weight: .heavy))
                    .tracking(1.4)
                    .foregroundStyle(YGColors.violet)
                if !title.isEmpty {
                    Text(title)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(YGColors.ink)
                        .multilineTextAlignment(.leading)
                }
                Text(body)
                    .font(.system(size: 16, design: .serif))
                    .foregroundStyle(YGColors.ink.opacity(0.80))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [Color(hex: "EFE6FF"), Color(hex: "FAF8FF")],
                               startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(YGColors.violet.opacity(0.18), lineWidth: 0.5)
            }

            if let dur = durationMinutes {
                HStack(spacing: 12) {
                    Image(systemName: "timer")
                        .font(.system(size: 18))
                        .foregroundStyle(YGColors.violet)
                        .frame(width: 38, height: 38)
                        .background(YGColors.violet.opacity(0.10))
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Breathe & pray")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(YGColors.ink)
                        Text("\(dur) minute\(dur == 1 ? "" : "s") · take it slow")
                            .font(.system(size: 12))
                            .foregroundStyle(YGColors.ink.opacity(0.55))
                    }
                    Spacer()
                }
                .padding(14)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(.black.opacity(0.05), lineWidth: 0.5) }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if currentIndex > 0 {
                    backButton
                }
                footerButton
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 26)
        }
        .padding(.top, 14)
        .background(
            LinearGradient(
                colors: [YGColors.paper.opacity(0), YGColors.paper.opacity(0.96)],
                startPoint: .top, endPoint: .bottom)
            .frame(height: 130, alignment: .bottom)
        )
    }

    private var backButton: some View {
        Button {
            goBack()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(YGColors.ink)
                .frame(width: 52, height: 52)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.black.opacity(0.08), lineWidth: 0.5)
                }
                .shadow(color: YGColors.ink.opacity(0.06), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
    }

    @ViewBuilder
    private var footerButton: some View {
        let label = footerLabel
        let canProceed = canAdvance
        let isFinish = isLastBlock

        Button {
            if isFinish {
                if isCompleted {
                    // Replay — already credited server-side. Just exit.
                    onClose()
                } else {
                    Task { await finishDay() }
                }
            } else {
                advance()
            }
        } label: {
            HStack {
                Text(label)
                    .font(.system(size: 15.5, weight: .black, design: .rounded))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .heavy))
            }
            .foregroundStyle(canProceed ? .white : YGColors.ink.opacity(0.4))
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                Group {
                    if canProceed {
                        footerButtonAccent
                    } else {
                        AnyView(YGColors.ink.opacity(0.08))
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: canProceed ? YGColors.violet.opacity(0.4) : .clear, radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(!canProceed || isSaving)
    }

    private var footerLabel: String {
        guard let block = currentBlock else { return "Continue" }
        // Replay path: only the last block changes label — to "Close".
        if isLastBlock && isCompleted { return "Close" }
        switch block {
        case .reading:    return "I've read this"
        case .commentary: return "Continue"
        case .video:      return "Continue"
        case .question:
            if case let .question(id, _, _, _) = block, answersByBlock[id] == nil {
                return "Pick an answer"
            }
            return "Continue"
        case .prayer:     return isLastBlock ? "Finish day \(dayNumber)" : "Continue"
        }
    }

    private var canAdvance: Bool {
        guard let block = currentBlock else { return false }
        if case let .question(id, _, _, _) = block {
            return answersByBlock[id] != nil
        }
        return true
    }

    /// Per-block accent gradient for the CTA button.
    private var footerButtonAccent: AnyView {
        guard let block = currentBlock else {
            return AnyView(LinearGradient(colors: [YGColors.violet, Color(hex: "FF3DA5")],
                                          startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        switch block {
        case .reading:
            return AnyView(YGColors.ink)
        case .commentary:
            return AnyView(LinearGradient(colors: [Color(hex: "2D7BFF"), Color(hex: "0066FF")],
                                          startPoint: .topLeading, endPoint: .bottomTrailing))
        case .video:
            return AnyView(LinearGradient(colors: [Color(hex: "FF3DA5"), Color(hex: "FF6B35")],
                                          startPoint: .topLeading, endPoint: .bottomTrailing))
        case .question:
            return AnyView(LinearGradient(colors: [Color(hex: "8FD92A"), Color(hex: "2B8A3E")],
                                          startPoint: .topLeading, endPoint: .bottomTrailing))
        case .prayer:
            return AnyView(LinearGradient(colors: [YGColors.violet, Color(hex: "FF3DA5")],
                                          startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }

    // MARK: - Navigation

    private func advance() {
        withAnimation(.smooth(duration: 0.25)) {
            completedIndices.insert(currentIndex)
            if currentIndex < blocks.count - 1 {
                currentIndex += 1
            }
        }
    }

    private func goBack() {
        guard currentIndex > 0 else { return }
        withAnimation(.smooth(duration: 0.25)) {
            // Drop the "completed" flag for the block we're leaving — the
            // user will need to advance past it again. Their answer state
            // for question blocks stays intact so they don't have to
            // re-pick when stepping forward.
            completedIndices.remove(currentIndex - 1)
            currentIndex -= 1
        }
    }

    private func finishDay() async {
        guard !blocks.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }

        // Mark the final block done.
        completedIndices.insert(currentIndex)

        // Build answer payload from all question blocks the user answered.
        let answers: [DayAnswerPayload] = blocks.compactMap { block in
            guard case .question(let id, _, _, _) = block,
                  let selected = answersByBlock[id] else { return nil }
            return DayAnswerPayload(
                block_id: id.uuidString.lowercased(),
                selected_index: selected
            )
        }

        do {
            let result = try await service.completePastorPlanDay(
                planId: planId, dayNumber: dayNumber, answers: answers
            )
            // Refresh the local profile so the Plans top bar's XP/water/
            // streak chips reflect the new totals. Server is the source
            // of truth — re-fetch instead of delta-applying client-side.
            await SupabaseManager.shared.checkSession()

            if result.alreadyCompleted {
                onDayCompleted()
                onClose()
            } else {
                celebration = result
            }
        } catch {
            print("[PastorPlanDayReader] complete failed:", error)
        }
    }

    // MARK: - Helpers

    private func letter(_ i: Int) -> String {
        guard let scalar = UnicodeScalar(65 + i) else { return "?" }
        return String(Character(scalar))
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

extension DayCompletionResult: Identifiable {
    var id: UUID { dayId }
}

// MARK: - Celebration sheet

struct CelebrationSheet: View {
    let result: DayCompletionResult
    let planTitle: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1A0F35"), Color(hex: "0A0712")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer(minLength: 30)

                Text("🏆")
                    .font(.system(size: 80))
                    .padding(20)
                    .background(
                        LinearGradient(colors: [Color(hex: "FFD60A"), Color(hex: "FF6B35")],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                    .shadow(color: Color(hex: "FF6B35").opacity(0.5), radius: 24, y: 10)

                VStack(spacing: 8) {
                    Text(result.planCompleted ? "PLAN COMPLETE" : "DAY COMPLETE")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(2)
                        .foregroundStyle(Color(hex: "B4FF3C"))
                    Text(result.planCompleted ? "You finished \(planTitle)!" : "You earned it.")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                HStack(spacing: 10) {
                    rewardCard(
                        emoji: "⚡",
                        value: "+\(result.totalXpAwarded)",
                        label: "XP earned",
                        sub: "\(500) base · +\(result.totalXpAwarded - 500) bonus",
                        color: Color(hex: "FFD60A")
                    )
                    rewardCard(
                        emoji: "💧",
                        value: "+\(result.totalWaterAwarded)",
                        label: "Water drops",
                        sub: "Sapling grows tonight 🌱",
                        color: Color(hex: "3DAEFF")
                    )
                }
                .padding(.horizontal, 24)

                if let milestone = result.milestoneHit, milestone > 0 {
                    HStack(spacing: 10) {
                        Text("🔥").font(.system(size: 20))
                        Text("\(result.newStreak)-day streak! +\(result.milestoneXp) XP")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.15), lineWidth: 0.5) }
                    .padding(.horizontal, 24)
                }

                Spacer()

                Button(action: onDismiss) {
                    HStack {
                        Text(result.planCompleted ? "🌳 See my garden" : "Done")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .heavy))
                    }
                    .foregroundStyle(YGColors.ink)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .white.opacity(0.4), radius: 16, y: 6)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 26)
            }
        }
    }

    private func rewardCard(emoji: String, value: String, label: String, sub: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(emoji)
                .font(.system(size: 22))
                .frame(width: 36, height: 36)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: color.opacity(0.4), radius: 8, y: 4)

            Text(value)
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()

            Text(label.uppercased())
                .font(.system(size: 10.5, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(.white.opacity(0.65))

            Text(sub)
                .font(.system(size: 10.5, weight: .heavy))
                .foregroundStyle(color.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            LinearGradient(
                colors: [color.opacity(0.18), color.opacity(0.06)],
                startPoint: .top, endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(color.opacity(0.5), lineWidth: 1)
        }
    }
}
