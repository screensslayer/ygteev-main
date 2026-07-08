//
//  PastorMessagingView.swift
//  YGTeeV
//
//  Pastor / leader-side command center for everything chat-related
//  inside a single youth group: pastor- or leader-authored custom
//  chats, quick links to the standard threads they own (main group,
//  parent chat, small group threads), a moderation queue for flagged
//  messages, and the group-wide DM kill switch.
//
//  Reachable from the dashboard's "Messaging" tile. Wires to the
//  `pastor_messaging_*` + `create/add/remove/update/archive_custom_thread`
//  RPCs on ChatService and re-uses the existing `ChatThreadView` for
//  the actual chat surface — so a tap from the hub and a tap from the
//  global Messages tab land on the identical detail view.
//

import SwiftUI

struct PastorMessagingView: View {
    let groupId: UUID
    let onClose: () -> Void

    @State private var chat = ChatService.shared
    @State private var dashboardService = PastorDashboardService.shared

    @State private var summary: PastorMessagingSummary?
    @State private var loadError: String?

    @State private var showCreateChat = false
    @State private var showFlaggedQueue = false

    // Custom-chat row swipe actions
    @State private var renameTarget: ChatThreadSummary?
    @State private var renameDraft: String = ""
    @State private var archiveTarget: ChatThreadSummary?

    // Thread-detail overlay (same pattern MessagesListView uses)
    @State private var selectedThreadId: UUID?

    // DM toggle — mirrors the load-bearing flip-then-confirm pattern
    // from PastorDashboardView so the wiring stays identical
    // regardless of where the user toggled it.
    @State private var dmsEnabledLocal: Bool = true
    @State private var pendingDmsValue: Bool?
    @State private var dmsToggleError: String?

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 16) {
                    customChatsSection
                    standardThreadsSection
                    if let s = summary, s.flaggedMessages > 0 {
                        moderationSection(count: s.flaggedMessages)
                    }
                    settingsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .background(YGColors.paper.ignoresSafeArea())
            .safeAreaInset(edge: .top, spacing: 0) { header }
            .refreshable {
                await refresh()
            }

            if let threadId = selectedThreadId,
               let summary = chat.threads.first(where: { $0.id == threadId }) {
                let displayThread = Self.convertThread(summary)
                ChatThreadView(thread: displayThread, threadSummary: summary) {
                    selectedThreadId = nil
                }
                .transition(.move(edge: .trailing))
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: selectedThreadId)
        .task {
            await refresh()
        }
        // Mirror PastorDashboardView's load-bearing `initial: true`.
        .onChange(of: dashboardService.dashboard?.oneOnOneDmsEnabled, initial: true) { _, newVal in
            if let newVal { dmsEnabledLocal = newVal }
        }
        .sheet(isPresented: $showCreateChat) {
            CreateCustomChatSheet(groupId: groupId) { newThread in
                Task {
                    await chat.loadThreads()
                    summary = try? await chat.pastorMessagingSummary(groupId: groupId)
                    selectedThreadId = newThread.threadId
                }
            }
        }
        .fullScreenCover(isPresented: $showFlaggedQueue) {
            PastorFlaggedMessagesView(groupId: groupId,
                                      onClose: { showFlaggedQueue = false },
                                      onOpenThread: { threadId in
                showFlaggedQueue = false
                // Wait one tick for the cover to dismiss before
                // pushing the overlay; otherwise the transition gets
                // swallowed.
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    selectedThreadId = threadId
                }
            })
        }
        .alert("Rename chat",
               isPresented: Binding(
                get: { renameTarget != nil },
                set: { if !$0 { renameTarget = nil } }
               )) {
            TextField("Chat name", text: $renameDraft)
            Button("Save") {
                if let target = renameTarget {
                    Task { await commitRename(target: target) }
                }
            }
            Button("Cancel", role: .cancel) { renameTarget = nil }
        }
        .alert(
            "Archive chat?",
            isPresented: Binding(
                get: { archiveTarget != nil },
                set: { if !$0 { archiveTarget = nil } }
            )
        ) {
            Button("Archive", role: .destructive) {
                if let target = archiveTarget {
                    Task { await commitArchive(target: target) }
                }
            }
            Button("Cancel", role: .cancel) { archiveTarget = nil }
        } message: {
            Text("Members won't see this chat anymore. History is kept on the server.")
        }
        .alert(
            (pendingDmsValue ?? true) ? "Turn on 1-on-1 messaging?" : "Turn off 1-on-1 messaging?",
            isPresented: Binding(
                get: { pendingDmsValue != nil },
                set: { if !$0 { pendingDmsValue = nil } }
            )
        ) {
            if let pending = pendingDmsValue {
                Button(pending ? "Turn On" : "Turn Off",
                       role: pending ? nil : .destructive) {
                    Task { await commitDmsChange(pending) }
                }
                Button("Cancel", role: .cancel) {
                    if let server = dashboardService.dashboard?.oneOnOneDmsEnabled {
                        dmsEnabledLocal = server
                    }
                    pendingDmsValue = nil
                }
            }
        } message: {
            Text(pendingDmsValue == true
                 ? "Students and children will be able to privately message you and your leaders again. Previously hidden 1-on-1 chats will reappear."
                 : "Students and children in your group won't be able to privately message you or your leaders. Existing 1-on-1 chats are hidden for everyone (history is kept and returns if you turn it back on). Group and small-group chats stay open.")
        }
        .alert("Couldn't update", isPresented: Binding(
            get: { dmsToggleError != nil },
            set: { if !$0 { dmsToggleError = nil } }
        )) {
            Button("OK", role: .cancel) { dmsToggleError = nil }
        } message: {
            Text(dmsToggleError ?? "")
        }
        .alert("Something went wrong",
               isPresented: Binding(
                get: { loadError != nil },
                set: { if !$0 { loadError = nil } }
               )) {
            Button("OK", role: .cancel) { loadError = nil }
        } message: {
            Text(loadError ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(YGColors.ink)
                    .frame(width: 38, height: 38)
                    .background(.white)
                    .clipShape(Circle())
                    .overlay {
                        Circle().strokeBorder(.black.opacity(0.06), lineWidth: 0.5)
                    }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Messaging")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(YGColors.ink)
                Text(headerSubtitle)
                    .font(.system(size: 12.5))
                    .foregroundStyle(YGColors.ink.opacity(0.6))
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(YGColors.paper)
    }

    private var headerSubtitle: String {
        let activeChats = summary?.activeCustomChats ?? 0
        let flagged = summary?.flaggedMessages ?? 0
        if activeChats == 0 && flagged == 0 { return "Manage chats and moderation" }
        var parts: [String] = []
        if activeChats > 0 {
            parts.append("\(activeChats) active chat\(activeChats == 1 ? "" : "s")")
        }
        if flagged > 0 {
            parts.append("\(flagged) flagged")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Custom chats

    private var customThreads: [ChatThreadSummary] {
        chat.threads
            .filter { $0.kind == .custom
                && $0.groupId == groupId
                && $0.archivedAt == nil }
    }

    private var customChatsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Custom chats")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(YGColors.ink.opacity(0.5))
                    .tracking(0.6)
                    .textCase(.uppercase)
                Spacer()
                Button {
                    showCreateChat = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .heavy))
                        Text("New")
                            .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(YGColors.violet)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            if customThreads.isEmpty {
                emptyCustomChatsCard
            } else {
                VStack(spacing: 8) {
                    ForEach(customThreads) { thread in
                        customChatRow(thread)
                    }
                }
            }
        }
    }

    private var emptyCustomChatsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No custom chats yet")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(YGColors.ink)
            Text("Tap **New** to start a private chat with anyone in your group.")
                .font(.system(size: 12.5))
                .foregroundStyle(YGColors.ink.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.05), lineWidth: 0.5) }
    }

    @ViewBuilder
    private func customChatRow(_ thread: ChatThreadSummary) -> some View {
        let isLinkedEvent = thread.eventId != nil
        Button {
            selectedThreadId = thread.threadId
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [YGColors.violet, Color(hex: "FF3DA5")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing)
                        )
                        .frame(width: 44, height: 44)
                    Image(systemName: isLinkedEvent ? "calendar" : "bubble.left.fill")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(thread.displayTitle)
                        .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(YGColors.ink)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if let count = thread.memberCount {
                            Text("\(count) member\(count == 1 ? "" : "s")")
                                .font(.system(size: 11.5))
                                .foregroundStyle(YGColors.ink.opacity(0.55))
                        }
                        if thread.unreadCount > 0 {
                            Text("·")
                                .foregroundStyle(YGColors.ink.opacity(0.35))
                            Text("\(thread.unreadCount) unread")
                                .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                                .foregroundStyle(YGColors.violet)
                        }
                        if isLinkedEvent {
                            Text("· linked")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(YGColors.ink.opacity(0.45))
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(YGColors.ink.opacity(0.3))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.05), lineWidth: 0.5) }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                renameDraft = thread.title ?? ""
                renameTarget = thread
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button(role: .destructive) {
                archiveTarget = thread
            } label: {
                Label("Archive", systemImage: "archivebox")
            }
        }
    }

    // MARK: - Standard threads

    private var standardThreads: [ChatThreadSummary] {
        chat.threads.filter {
            $0.groupId == groupId
            && ($0.kind == .groupMain
                || $0.kind == .smallGroup
                || $0.kind == .parentChat)
        }
    }

    @ViewBuilder
    private var standardThreadsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Standard threads")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(YGColors.ink.opacity(0.5))
                .tracking(0.6)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            if standardThreads.isEmpty {
                Text("Loading…")
                    .font(.system(size: 12.5))
                    .foregroundStyle(YGColors.ink.opacity(0.45))
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.05), lineWidth: 0.5) }
            } else {
                VStack(spacing: 8) {
                    ForEach(standardThreads) { thread in
                        standardThreadRow(thread)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func standardThreadRow(_ thread: ChatThreadSummary) -> some View {
        Button {
            selectedThreadId = thread.threadId
        } label: {
            HStack(spacing: 12) {
                Image(systemName: iconFor(kind: thread.kind))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(YGColors.violet)
                    .frame(width: 38, height: 38)
                    .background(YGColors.violet.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(thread.displayTitle)
                        .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(YGColors.ink)
                        .lineLimit(1)
                    if thread.unreadCount > 0 {
                        Text("\(thread.unreadCount) unread")
                            .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(YGColors.violet)
                    } else if let sub = thread.displaySubtitle {
                        Text(sub)
                            .font(.system(size: 11.5))
                            .foregroundStyle(YGColors.ink.opacity(0.55))
                            .lineLimit(1)
                    } else {
                        Text(subtitleFallback(for: thread.kind))
                            .font(.system(size: 11.5))
                            .foregroundStyle(YGColors.ink.opacity(0.45))
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(YGColors.ink.opacity(0.3))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.05), lineWidth: 0.5) }
        }
        .buttonStyle(.plain)
    }

    private func iconFor(kind: ThreadKind) -> String {
        switch kind {
        case .groupMain:  return "house.fill"
        case .smallGroup: return "leaf.fill"
        case .parentChat: return "figure.2.and.child.holdinghands"
        default:          return "bubble.left.fill"
        }
    }

    private func subtitleFallback(for kind: ThreadKind) -> String {
        switch kind {
        case .groupMain:  return "Whole-group thread"
        case .smallGroup: return "Small group thread"
        case .parentChat: return "Parents + pastor + leaders"
        default:          return ""
        }
    }

    // MARK: - Moderation

    private func moderationSection(count: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Moderation")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(YGColors.ink.opacity(0.5))
                .tracking(0.6)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            Button {
                showFlaggedQueue = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: "FF6B35"))
                        .frame(width: 38, height: 38)
                        .background(Color(hex: "FF6B35").opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(count) flagged message\(count == 1 ? "" : "s") need\(count == 1 ? "s" : "") review")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(YGColors.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text("Tap to review")
                            .font(.system(size: 11.5))
                            .foregroundStyle(YGColors.ink.opacity(0.55))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(YGColors.ink.opacity(0.3))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Color(hex: "FF6B35").opacity(0.25), lineWidth: 1) }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Settings (DM toggle)

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(YGColors.ink.opacity(0.5))
                .tracking(0.6)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: Binding(
                    get: { dmsEnabledLocal },
                    set: { newValue in
                        // Flip-then-confirm: feedback first, server write
                        // gated behind the alert. Mirrors the dashboard's
                        // load-bearing pattern.
                        dmsEnabledLocal = newValue
                        pendingDmsValue = newValue
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Allow 1-on-1 direct messages")
                            .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(YGColors.ink)
                        Text("Students can privately message you and your leaders. Group & small-group chats stay open either way.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(YGColors.ink.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(YGColors.violet)
            }
            .padding(14)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.05), lineWidth: 0.5) }
        }
    }

    // MARK: - Refresh + mutations

    private func refresh() async {
        // Threads first so the row lists populate, then the summary
        // (which depends on the same underlying tables).
        await chat.loadThreads()
        do {
            summary = try await chat.pastorMessagingSummary(groupId: groupId)
        } catch {
            print("[PastorMessagingView] pastor_messaging_summary failed:", error)
            // Don't surface a blocking error — the lists still work
            // without the summary.
            summary = nil
        }
        await dashboardService.loadDashboard()
    }

    private func commitRename(target: ChatThreadSummary) async {
        let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try await chat.updateCustomThread(threadId: target.threadId, title: trimmed)
            await chat.loadThreads()
        } catch {
            loadError = "Couldn't rename — try again."
            print("[PastorMessagingView] rename failed:", error)
        }
        renameTarget = nil
    }

    private func commitArchive(target: ChatThreadSummary) async {
        do {
            try await chat.archiveCustomThread(threadId: target.threadId)
            await chat.loadThreads()
            summary = try? await chat.pastorMessagingSummary(groupId: groupId)
        } catch {
            loadError = "Couldn't archive — try again."
            print("[PastorMessagingView] archive failed:", error)
        }
        archiveTarget = nil
    }

    private func commitDmsChange(_ newValue: Bool) async {
        defer { pendingDmsValue = nil }
        do {
            try await dashboardService.setGroupDMs(enabled: newValue, groupId: groupId)
            await dashboardService.loadDashboard()
            await chat.loadThreads()
        } catch {
            if let server = dashboardService.dashboard?.oneOnOneDmsEnabled {
                dmsEnabledLocal = server
            }
            dmsToggleError = error.localizedDescription
        }
    }

    // MARK: - Display conversion

    /// Mirrors `MessagesListView.convertThread` so the hub's taps land
    /// on the identical `ChatThreadView` layout the global Messages
    /// tab uses. Duplicated by design — the converter is small and
    /// pulling it out would require an entry in a shared file we don't
    /// otherwise need to introduce yet.
    static func convertThread(_ summary: ChatThreadSummary) -> MessageThread {
        let isGroup = !summary.kind.isDm
        let gradient: GradientInfo? = if isGroup,
                                         let from = summary.groupGradientFrom,
                                         let to = summary.groupGradientTo {
            GradientInfo(startColor: from, endColor: to)
        } else {
            nil
        }
        let role: MessageThread.LeaderRole? =
            MessageThread.LeaderRole.from(rawServer: summary.dmOtherRole)

        let memberCount: Int? = summary.memberCount
            ?? (isGroup ? ChatService.shared.groupStats[summary.groupId]?.members : nil)

        let logoUrl: String? = isGroup
            ? EventsService.shared.myMemberships
                .first(where: { $0.groupId == summary.groupId })?
                .logoUrl
            : nil

        return MessageThread(
            id: summary.id.uuidString,
            kind: isGroup ? (summary.kind == .smallGroup ? .smallGroup : .group) : .dm,
            name: summary.displayTitle,
            subtitle: summary.displaySubtitle ?? "",
            time: "",
            unread: summary.unreadCount,
            gradient: gradient,
            isGroup: isGroup,
            memberCount: memberCount,
            role: role,
            logoUrl: logoUrl
        )
    }
}
