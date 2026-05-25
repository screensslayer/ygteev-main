//
//  PlanDayBuilderView.swift
//  YGTeeV
//
//  Screens 2 / 3 / 4 of the pastor flow — empty, filled, and drag states
//  for editing one day's block list. Auto-saves on every mutation.
//

import SwiftUI
import UniformTypeIdentifiers

struct PlanDayBuilderView: View {
    @Binding var draft: BiblePlanDraft
    @State var currentDay: Int
    /// Bubbled up from the overview's publish action — pops the entire
    /// builder/overview chain back to the plans list.
    var onPublished: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var service = PastorPlanService.shared

    @State private var dayTitle: String = ""
    @State private var scriptureRef: String = ""
    @State private var blocks: [Block] = []
    @State private var draggedBlockID: UUID?
    @State private var showEditCommentary: Block?
    @State private var showEditQuestion: Block?
    @State private var showEditReading: Block?
    @State private var showEditPrayer: Block?
    @State private var showEditVideo: Block?
    @State private var blockPendingDelete: Block?
    @State private var showOverview = false

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                dayTabs
                miniHeader
                if let err = service.lastAutosaveError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 13))
                        Text("Autosave failed: \(err)")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .lineLimit(2)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }
                if blocks.isEmpty {
                    ScrollView {
                        emptyState
                    }
                    .scrollDismissesKeyboard(.interactively)
                } else {
                    filledStateList
                        .scrollDismissesKeyboard(.interactively)
                }
            }

            footer
        }
        .background(YGColors.paper.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text("STEP 2 OF 3")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(YGColors.ink.opacity(0.5))
                    Text("Build day \(currentDay)")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(YGColors.ink)
                }
            }
        }
        .sheet(item: $showEditCommentary) { block in
            if case let .commentary(id, title, body) = block {
                CommentaryEditorView(
                    blockId: id,
                    initialTitle: title,
                    initialBody: body,
                    scriptureRef: scriptureRef,
                    planTitle: draft.title
                ) { newTitle, newBody in
                    replaceBlock(id: id, with: .commentary(id: id, title: newTitle, body: newBody))
                }
            }
        }
        .sheet(item: $showEditQuestion) { block in
            if case let .question(id, prompt, options, correct) = block {
                QuestionEditorView(
                    blockId: id,
                    initialPrompt: prompt,
                    initialOptions: options,
                    initialCorrect: correct
                ) { newPrompt, newOptions, newCorrect in
                    replaceBlock(id: id, with: .question(id: id, prompt: newPrompt, options: newOptions, correctIndex: newCorrect))
                }
            }
        }
        .sheet(item: $showEditReading) { block in
            if case let .reading(id, verses) = block {
                BibleReferencePickerSheet(initialReference: verses) { newRef in
                    replaceBlock(id: id, with: .reading(id: id, verses: newRef))
                    // Also seed the day's scripture ref the first time the
                    // pastor picks one, so the AI assist has something to
                    // work with and the day card shows the reference.
                    if scriptureRef.isEmpty {
                        scriptureRef = newRef
                        persistDay()
                    }
                }
            }
        }
        .sheet(item: $showEditPrayer) { block in
            if case let .prayer(id, title, body, dur) = block {
                PrayerEditorView(
                    blockId: id,
                    initialTitle: title,
                    initialBody: body,
                    initialDurationMinutes: dur
                ) { newTitle, newBody, newDur in
                    replaceBlock(id: id, with: .prayer(id: id, title: newTitle, body: newBody, durationMinutes: newDur))
                }
            }
        }
        .sheet(item: $showEditVideo) { block in
            if case let .video(id, title, url, dur, videoId) = block {
                VideoEditorView(
                    planId: draft.id,
                    dayNumber: currentDay,
                    blockId: id,
                    initialTitle: title,
                    initialURL: url,
                    initialDurationSeconds: dur,
                    initialVideoId: videoId
                ) { newTitle, newURL, newDur, newVideoId in
                    replaceBlock(
                        id: id,
                        with: .video(
                            id: id,
                            title: newTitle,
                            url: newURL,
                            durationSeconds: newDur,
                            videoId: newVideoId
                        )
                    )
                }
            }
        }
        .navigationDestination(isPresented: $showOverview) {
            PlanOverviewView(
                draft: $draft,
                onSelectDay: { day in currentDay = day },
                onPublished: onPublished
            )
        }
        .confirmationDialog(
            "Delete this block?",
            isPresented: Binding(
                get: { blockPendingDelete != nil },
                set: { if !$0 { blockPendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: blockPendingDelete
        ) { block in
            Button("Delete \(block.kind.label.lowercased())", role: .destructive) {
                deleteBlock(block)
            }
            Button("Cancel", role: .cancel) {
                blockPendingDelete = nil
            }
        } message: { _ in
            Text("This block and its content will be removed from this day. This can't be undone.")
        }
        .onAppear { Task { await loadFromServer() } }
        .onChange(of: currentDay) { oldDay, _ in
            Task {
                // Commit any pending save on the day we're leaving so the
                // 500ms debounce doesn't lose work when the pastor swaps
                // tabs faster than that.
                await service.flushPending(forDay: oldDay)
                await loadFromServer()
            }
        }
        .onDisappear {
            // View is being popped — make sure any in-flight debounced save
            // for this day actually commits to the server.
            let day = currentDay
            Task { await service.flushPending(forDay: day) }
        }
    }

    // MARK: - Day tabs

    private var dayTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(1...draft.totalDays, id: \.self) { n in
                    let on = n == currentDay
                    let done = n < currentDay
                    Button { currentDay = n } label: {
                        HStack(spacing: 5) {
                            if done {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .heavy))
                            }
                            Text("Day \(n)")
                                .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                        }
                        .foregroundStyle(on ? .white : (done ? Color(hex: "2B8A3E") : YGColors.ink.opacity(0.6)))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(on ? YGColors.ink : (done ? Color(hex: "B4FF3C").opacity(0.18) : .white.opacity(0.8)))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var miniHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(draft.title.uppercased()) · DAY \(currentDay) OF \(draft.totalDays)")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.85))
                Text(blocks.isEmpty ? "Building today's order" : (dayTitle.isEmpty ? "Day \(currentDay)" : dayTitle))
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .center, spacing: 2) {
                Text("REWARD")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.8))
                HStack(spacing: 6) {
                    HStack(spacing: 3) { Text("⚡"); Text("\(500 + blocks.filter { if case .question = $0 { return true } else { return false } }.count * 50)") }
                    Text("·").opacity(0.4)
                    HStack(spacing: 3) { Text("💧"); Text("4") }
                }
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.22))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(PlanHeaderGradient.gradient(at: draft.gradientIndex))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: YGColors.ink.opacity(0.18), radius: 10, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("📝").font(.system(size: 42))
                Text("This day is empty.")
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundStyle(YGColors.ink)
                Text("Tap a block below to add it.")
                    .font(.system(size: 13))
                    .foregroundStyle(YGColors.ink.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
            .background(Color.white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(YGColors.ink.opacity(0.15), style: .init(lineWidth: 1.5, dash: [6, 6]))
            }

            Text("BLOCK LIBRARY — TAP TO ADD")
                .font(.system(size: 11, weight: .heavy))
                .tracking(1)
                .foregroundStyle(YGColors.ink.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(BlockKind.allCases, id: \.self) { kind in
                    libraryTile(kind: kind)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 210)
    }

    private func libraryTile(kind: BlockKind) -> some View {
        Button { addEmptyBlock(of: kind) } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(kind.icon)
                    .font(.system(size: 20))
                    .frame(width: 38, height: 38)
                    .background(kind.tint)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Text(kind.label)
                    .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(YGColors.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.06), lineWidth: 0.5) }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filled state (List for native swipe-to-delete + drag-reorder)

    private var filledStateList: some View {
        List {
            Section {
                ForEach(blocks) { block in
                    BlockRowView(block: block, isDragging: draggedBlockID == block.id) {
                        open(block: block)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            blockPendingDelete = block
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .onDrag {
                        draggedBlockID = block.id
                        return NSItemProvider(object: block.id.uuidString as NSString)
                    }
                    .onDrop(of: [.text],
                            delegate: BlockDropDelegate(
                                target: block,
                                blocks: $blocks,
                                draggedID: $draggedBlockID,
                                onChange: persistDay
                            ))
                }
            }

            Section {
                Button { showLibrary = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("Add another block")
                            .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(YGColors.ink.opacity(0.65))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(YGColors.ink.opacity(0.18),
                                          style: .init(lineWidth: 1.5, dash: [6, 6]))
                    }
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                summaryCard
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 210, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(YGColors.paper)
        .confirmationDialog("Add a block",
                            isPresented: $showLibrary,
                            titleVisibility: .visible) {
            ForEach(BlockKind.allCases, id: \.self) { kind in
                Button("\(kind.icon)  \(kind.label)") { addEmptyBlock(of: kind) }
            }
        }
    }

    @State private var showLibrary = false

    private var summaryCard: some View {
        let questionCount = blocks.reduce(0) { acc, b in
            if case .question = b { return acc + 1 }
            return acc
        }
        let xp = 500 + questionCount * 50
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("DAY \(currentDay) REWARD")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.55))
                HStack(spacing: 14) {
                    HStack(spacing: 5) { Text("⚡"); Text("\(xp)") }
                        .foregroundStyle(Color(hex: "FFD60A"))
                    HStack(spacing: 5) { Text("💧"); Text("4") }
                        .foregroundStyle(Color(hex: "3DAEFF"))
                }
                .font(.system(size: 22, weight: .black, design: .rounded))
                Text("500 base \(questionCount > 0 ? "· +\(50 * questionCount) for \(questionCount) question\(questionCount == 1 ? "" : "s")" : "")")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            Text("\(blocks.count) block\(blocks.count == 1 ? "" : "s")")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.white.opacity(0.10))
                .clipShape(Capsule())
        }
        .padding(14)
        .background(YGColors.ink)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                showOverview = true
            } label: {
                Text("Preview")
                    .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(YGColors.ink)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(.black.opacity(0.08), lineWidth: 0.5) }
            }
            .buttonStyle(.plain)

            Button {
                if currentDay < draft.totalDays {
                    currentDay += 1
                } else {
                    showOverview = true
                }
            } label: {
                Text(currentDay < draft.totalDays ? "Go to day \(currentDay + 1) →" : "Review plan →")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        LinearGradient(colors: [YGColors.violet, Color(hex: "FF3DA5")],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: YGColors.violet.opacity(0.5), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 90)
        .background(
            LinearGradient(
                colors: [YGColors.paper.opacity(0), YGColors.paper.opacity(0.95)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 170, alignment: .bottom)
        )
    }

    // MARK: - Behaviors

    /// Source of truth on day re-entry is the server, not local memory.
    /// Falls back to the in-memory cache only when the server has no row
    /// yet for this day (i.e. the pastor hasn't authored it).
    private func loadFromServer() async {
        if let row = await service.loadDay(planId: draft.id, dayNumber: currentDay) {
            blocks = row.blocks
            dayTitle = row.title.isEmpty ? "Day \(currentDay)" : row.title
            scriptureRef = row.scriptureRef
        } else if let cached = service.blocksByDay[currentDay] {
            blocks = cached
            if dayTitle.isEmpty { dayTitle = "Day \(currentDay)" }
        } else {
            blocks = []
            dayTitle = "Day \(currentDay)"
            scriptureRef = ""
        }
    }

    private func addEmptyBlock(of kind: BlockKind) {
        let new: Block
        switch kind {
        case .reading:    new = .reading(verses: "")
        case .commentary: new = .commentary(title: "Commentary", body: "")
        case .video:      new = .video(title: "Video", url: "", durationSeconds: nil)
        case .question:   new = .question(prompt: "", options: ["", "", ""], correctIndex: 0)
        case .prayer:     new = .prayer(title: "Prayer", body: "", durationMinutes: 2)
        }
        blocks.append(new)
        persistDay()
        // Auto-open the editor for every block kind — pastors should never
        // see an empty placeholder block they can't fill in.
        switch new {
        case .reading:    showEditReading = new
        case .commentary: showEditCommentary = new
        case .question:   showEditQuestion = new
        case .prayer:     showEditPrayer = new
        case .video:      showEditVideo = new
        }
    }

    private func replaceBlock(id: UUID, with newBlock: Block) {
        if let idx = blocks.firstIndex(where: { $0.id == id }) {
            blocks[idx] = newBlock
            persistDay()
        }
    }

    private func deleteBlock(_ block: Block) {
        guard let idx = blocks.firstIndex(where: { $0.id == block.id }) else {
            blockPendingDelete = nil
            return
        }
        blocks.remove(at: idx)
        blockPendingDelete = nil
        persistDay()
    }

    private func open(block: Block) {
        switch block {
        case .reading:    showEditReading = block
        case .commentary: showEditCommentary = block
        case .question:   showEditQuestion = block
        case .prayer:     showEditPrayer = block
        case .video:      showEditVideo = block
        }
    }

    private func persistDay() {
        print("[PlanDayBuilderView.persistDay] day=\(currentDay) plan=\(draft.id.uuidString.lowercased()) blocks=\(blocks.count)")
        service.updateBlocks(
            forDay: currentDay,
            blocks: blocks,
            in: draft,
            dayTitle: dayTitle.isEmpty ? "Day \(currentDay)" : dayTitle,
            scriptureRef: scriptureRef
        )
    }
}

// MARK: - Block row

private struct BlockRowView: View {
    let block: Block
    let isDragging: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(block.kind.tint)
                    .frame(width: 28)
                    .overlay {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(YGColors.ink.opacity(0.4))
                    }
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        HStack(spacing: 4) {
                            Text(block.kind.icon).font(.system(size: 11))
                            Text(block.kind.label.uppercased())
                                .font(.system(size: 10.5, weight: .heavy))
                                .tracking(0.4)
                        }
                        .foregroundStyle(block.kind.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(block.kind.tint)
                        .clipShape(Capsule())
                        Spacer()
                        if case .question = block {
                            HStack(spacing: 3) { Text("⚡"); Text("+50 XP") }
                                .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                                .foregroundStyle(YGColors.ink)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color(hex: "FFD60A"))
                                .clipShape(Capsule())
                        }
                    }
                    Text(primaryText)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(YGColors.ink)
                        .lineLimit(1)
                    if let s = secondaryText {
                        Text(s)
                            .font(.system(size: 12.5))
                            .foregroundStyle(YGColors.ink.opacity(0.55))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isDragging ? block.kind.accent : .black.opacity(0.06),
                                  lineWidth: isDragging ? 1.5 : 0.5)
            }
            .shadow(color: YGColors.ink.opacity(isDragging ? 0.25 : 0.04),
                    radius: isDragging ? 12 : 2, y: isDragging ? 8 : 1)
            .scaleEffect(isDragging ? 1.02 : 1.0)
            .rotationEffect(.degrees(isDragging ? -1 : 0))
        }
        .buttonStyle(.plain)
    }

    private var primaryText: String {
        switch block {
        case .reading(_, let verses): return verses.isEmpty ? "Add verse reference" : verses
        case .commentary(_, let title, _): return title.isEmpty ? "Untitled commentary" : title
        case .video(_, let title, _, _, _): return title.isEmpty ? "Untitled video" : title
        case .question(_, let prompt, _, _): return prompt.isEmpty ? "Add question" : prompt
        case .prayer(_, let title, _, _): return title.isEmpty ? "Prayer" : title
        }
    }

    private var secondaryText: String? {
        switch block {
        case .reading: return "Bible reading"
        case .commentary(_, _, let body): return body.isEmpty ? "Tap to write commentary" : String(body.prefix(80))
        case .video(_, _, let url, _, let vid):
            if !url.isEmpty { return url }
            return vid != nil ? "Video uploaded" : "Upload or paste a URL"
        case .question(_, _, let options, _): return "\(options.count) options"
        case .prayer(_, _, _, let dur):
            if let dur { return "\(dur)-minute prayer" }
            return "Prayer prompt"
        }
    }
}

// MARK: - Drop delegate

private struct BlockDropDelegate: DropDelegate {
    let target: Block
    @Binding var blocks: [Block]
    @Binding var draggedID: UUID?
    let onChange: () -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedID,
              draggedID != target.id,
              let from = blocks.firstIndex(where: { $0.id == draggedID }),
              let to = blocks.firstIndex(where: { $0.id == target.id })
        else { return }
        if blocks[to].id != draggedID {
            withAnimation(.easeInOut(duration: 0.18)) {
                blocks.move(fromOffsets: IndexSet(integer: from),
                            toOffset: to > from ? to + 1 : to)
            }
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedID = nil
        onChange()
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
