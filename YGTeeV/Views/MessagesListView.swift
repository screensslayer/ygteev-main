//
//  MessagesListView.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/6/26.
//

import SwiftUI

// MARK: - Message Thread Model
struct MessageThread: Identifiable {
    let id: String
    let kind: ThreadKind
    let name: String
    let subtitle: String
    let time: String
    let unread: Int
    let gradient: GradientInfo?
    let isGroup: Bool
    let memberCount: Int?
    let role: LeaderRole?
    /// Real youth-group logo, pulled from cached memberships. When set,
    /// the thread row renders it in place of the gradient + initials
    /// tile so a group like Lifepointe Students surfaces its brand
    /// across every chat that lives under it.
    let logoUrl: String?

    enum ThreadKind {
        case group
        case smallGroup
        case dm
    }

    /// Tag shown next to a user's name in chat list rows and message
    /// bubbles. Backend sends the lowercase role string ("pastor",
    /// "leader", "parent", "student", "member"). `list_my_threads` now
    /// distinguishes students (any member with a `grade_year`) from
    /// plain adult members so the row pill matches who's actually
    /// talking.
    enum LeaderRole: String {
        case pastor      = "PASTOR"
        case groupLeader = "LEADER"
        case parent      = "PARENT"
        case student     = "STUDENT"
        case member      = "MEMBER"

        var color: Color {
            switch self {
            case .pastor:      return YGColors.violet
            case .groupLeader: return Color(hex: "0066FF")
            case .parent:      return YGColors.lime
            case .student:     return Color(hex: "2B8A3E")          // green — matches grade pill in Members
            case .member:      return YGColors.ink.opacity(0.55)    // muted gray for adult non-parent members
            }
        }

        /// Map a backend role string into the display tag. Returns nil for
        /// unknown values so a future server-side role doesn't crash the
        /// row layout.
        static func from(rawServer raw: String?) -> LeaderRole? {
            switch raw {
            case "pastor":  return .pastor
            case "leader":  return .groupLeader
            case "parent":  return .parent
            case "student": return .student
            case "member":  return .member
            default:        return nil
            }
        }
    }
}

// MARK: - Legacy Chat Message Model (for mock display only)
struct LegacyChatMessage: Identifiable {
    let id = UUID()
    let from: String
    let body: String
    let time: String
    let isMine: Bool
    let role: MessageThread.LeaderRole?
    let isScripture: Bool

    init(from: String, body: String, time: String, isMine: Bool, role: MessageThread.LeaderRole? = nil, isScripture: Bool = false) {
        self.from = from
        self.body = body
        self.time = time
        self.isMine = isMine
        self.role = role
        self.isScripture = isScripture
    }
}

// MARK: - Messages List View
struct MessagesListView: View {
    @State private var selectedThreadId: UUID?
    @State private var showNewMessage = false
    @AppStorage("hasSeenSafetyNotice") private var hasSeenSafetyNotice = false
    @State private var showSafetyNotice = true
    @State private var appearanceManager = AppearanceManager.shared
    @State private var searchText = ""

    private let chatService = ChatService.shared

    // Relative time formatter
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private static func relativeTime(_ date: Date) -> String {
        let seconds = -date.timeIntervalSinceNow
        if seconds < 60 {
            return "now"
        } else if seconds < 3600 {
            return "\(Int(seconds / 60))m"
        } else if seconds < 86400 {
            return "\(Int(seconds / 3600))h"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let days = Int(seconds / 86400)
            if days < 7 {
                return "\(days)d"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                return formatter.string(from: date)
            }
        }
    }

    // Convert ChatThreadSummary to MessageThread for display
    private func convertThread(_ summary: ChatThreadSummary) -> MessageThread {
        let isGroup = !summary.kind.isDm
        let gradient: GradientInfo? = if isGroup,
                                         let from = summary.groupGradientFrom,
                                         let to = summary.groupGradientTo {
            GradientInfo(startColor: from, endColor: to)
        } else {
            nil
        }

        let role: MessageThread.LeaderRole? = MessageThread.LeaderRole.from(rawServer: summary.dmOtherRole)

        let memberCount: Int? = if isGroup {
            chatService.groupStats[summary.groupId]?.members
        } else {
            nil
        }

        // Pull the youth-group logo from cached memberships so every
        // group/small-group/parent-chat thread under that group shows
        // the same brand image. Falls through to nil → existing
        // gradient+initials avatar when no logo is on file.
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
            time: summary.lastMessageAt.map { Self.relativeTime($0) } ?? "",
            unread: summary.unreadCount,
            gradient: gradient,
            isGroup: isGroup,
            memberCount: memberCount,
            role: role,
            logoUrl: logoUrl
        )
    }

    // Filter threads by search text, then layer in our two-tier sort:
    // 1) Group threads stay pinned at the top in the RPC's order
    //    (`list_my_threads` already returns them first, sorted by recency
    //    within tier — that order is the source of truth).
    // 2) DMs below the groups, sorted unread-first, then most recent.
    //    A reply that lands while an older DM still has unreads will
    //    push the unread one above it.
    private var filteredThreads: [ChatThreadSummary] {
        let base: [ChatThreadSummary]
        if searchText.isEmpty {
            base = chatService.threads
        } else {
            base = chatService.threads.filter { thread in
                thread.displayTitle.localizedCaseInsensitiveContains(searchText) ||
                (thread.displaySubtitle?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        let groups = base.filter { !$0.kind.isDm }
        let dms = base.filter { $0.kind.isDm }.sorted { lhs, rhs in
            let lUnread = lhs.unreadCount > 0
            let rUnread = rhs.unreadCount > 0
            if lUnread != rUnread { return lUnread && !rUnread }
            // Treat a missing lastMessageAt as the distant past so silent
            // threads always sink to the bottom of their tier.
            let lDate = lhs.lastMessageAt ?? .distantPast
            let rDate = rhs.lastMessageAt ?? .distantPast
            return lDate > rDate
        }
        return groups + dms
    }

    var body: some View {
        let _ = print("🟣 MessagesListView body: selectedThreadId = \(selectedThreadId?.uuidString ?? "nil"), threads.count = \(chatService.threads.count)")

        ZStack {
            // Always show threads list in background
            threadsList

            // Overlay chat when selected
            if let threadId = selectedThreadId {
                let _ = print("🟣 MessagesListView: selectedThreadId exists: \(threadId)")
                if let summary = chatService.threads.first(where: { $0.id == threadId }) {
                    let _ = print("🟣 MessagesListView: Found matching summary, creating ChatThreadView")
                    let displayThread = convertThread(summary)
                    ChatThreadView(thread: displayThread, threadSummary: summary) {
                        print("🟣 ChatThreadView onBack called")
                        selectedThreadId = nil
                    }
                    .transition(.move(edge: .trailing))
                    .zIndex(1)
                } else {
                    let _ = print("❌ MessagesListView: NO matching summary found for threadId: \(threadId)")
                    let _ = print("❌ Available thread IDs: \(chatService.threads.map { $0.id.uuidString })")
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: selectedThreadId)
        .task {
            print("🔵 MessagesListView .task starting")
            await chatService.loadThreads()
            print("🔵 MessagesListView .task completed, threads.count = \(chatService.threads.count)")
        }
        .refreshable {
            await chatService.loadThreads()
        }
    }

    var threadsList: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                HStack(alignment: .bottom) {
                    Text("Messages")
                        .font(.lilitaOne(size: 34))
                        .foregroundStyle(ThemeColors.primaryText(isDark: appearanceManager.isDarkMode))
                        .tracking(-1)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 8)

                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundStyle(ThemeColors.secondaryText(isDark: appearanceManager.isDarkMode))

                    TextField("Search messages", text: $searchText)
                        .font(.system(size: 15))
                        .foregroundStyle(ThemeColors.primaryText(isDark: appearanceManager.isDarkMode))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(ThemeColors.cardBackground(isDark: appearanceManager.isDarkMode))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(ThemeColors.border(isDark: appearanceManager.isDarkMode), lineWidth: 0.5)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Safety notice
                if !hasSeenSafetyNotice && showSafetyNotice {
                    HStack(spacing: 10) {
                        Text("🛡️")
                            .font(.system(size: 18))

                        Text("**Safe by default.** You can DM your pastor and group leaders only. Members chat in groups.")
                            .font(.system(size: 12.5))
                            .foregroundStyle(ThemeColors.secondaryText(isDark: appearanceManager.isDarkMode))
                            .lineSpacing(3)

                        Spacer()

                        Button {
                            withAnimation {
                                showSafetyNotice = false
                                hasSeenSafetyNotice = true
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(ThemeColors.tertiaryText(isDark: appearanceManager.isDarkMode))
                                .frame(width: 24, height: 24)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(ThemeColors.secondaryBackground(isDark: appearanceManager.isDarkMode))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(YGColors.violet.opacity(0.2), lineWidth: 0.5)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                }

                // Thread list
                VStack(spacing: 0) {
                    ForEach(filteredThreads) { summary in
                        let displayThread = convertThread(summary)
                        ThreadRow(thread: displayThread) {
                            print("🟣 ThreadRow tapped: summary.id = \(summary.id), summary.threadId = \(summary.threadId)")
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedThreadId = summary.id
                                print("🟣 Set selectedThreadId to: \(summary.id)")
                            }
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
        }
        .background(ThemeColors.background(isDark: appearanceManager.isDarkMode))
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - Thread Row
struct ThreadRow: View {
    let thread: MessageThread
    let onTap: () -> Void
    @State private var appearanceManager = AppearanceManager.shared

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon — group threads with a logo render the brand
                // image; small groups stay on the 🌿 emoji; everything
                // else uses the gradient + initials fallback so older
                // logo-less groups don't regress.
                if thread.isGroup {
                    GroupAvatar(logoUrl: thread.logoUrl, size: 50, cornerRadius: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(thread.gradient?.gradient ?? LinearGradient(
                                    colors: [.gray],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))

                            if thread.kind == .smallGroup {
                                Text("🌿").font(.system(size: 24))
                            } else {
                                Text(thread.name.split(separator: " ").prefix(2).map { String($0.prefix(1)) }.joined())
                                    .font(.lilitaOne(size: 18))
                                    .foregroundStyle(.white)
                                    .tracking(-0.5)
                            }
                        }
                    }
                    .frame(width: 50, height: 50)
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 3)
                } else {
                    YGAvatar(name: thread.name, size: 50)
                }

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(thread.name)
                            .font(.lilitaOne(size: 16))
                            .tracking(-0.3)
                            .foregroundStyle(ThemeColors.primaryText(isDark: appearanceManager.isDarkMode))
                            .lineLimit(1)

                        if let role = thread.role {
                            Text(role.rawValue)
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(role.color)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .tracking(0.4)
                        }

                        if let memberCount = thread.memberCount {
                            Text("· \(memberCount)")
                                .font(.system(size: 11))
                                .foregroundStyle(ThemeColors.tertiaryText(isDark: appearanceManager.isDarkMode))
                        }
                    }

                    Text(thread.subtitle)
                        .font(.system(size: 13.5))
                        .foregroundStyle(ThemeColors.secondaryText(isDark: appearanceManager.isDarkMode))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                // Time and badge
                VStack(alignment: .trailing, spacing: 4) {
                    Text(thread.time)
                        .font(.system(size: 11.5))
                        .foregroundStyle(ThemeColors.tertiaryText(isDark: appearanceManager.isDarkMode))

                    if thread.unread > 0 {
                        Text("\(thread.unread)")
                            .font(.lilitaOne(size: 11.5))
                            .foregroundStyle(.white)
                            .frame(minWidth: 20)
                            .frame(height: 20)
                            .padding(.horizontal, 6)
                            .background(YGColors.violet)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chat Thread View
struct ChatThreadView: View {
    let thread: MessageThread
    let threadSummary: ChatThreadSummary
    let onBack: () -> Void

    @State private var messageText = ""
    @State private var keyboardHeight: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    @FocusState private var isTextFieldFocused: Bool
    @State private var appearanceManager = AppearanceManager.shared
    @State private var isSending = false
    @State private var sendError: String?
    @State private var isLoadingMore = false
    @State private var hasMoreMessages = true

    private let pageSize = 50

    private let chatService = ChatService.shared
    private var threadId: UUID { threadSummary.threadId }
    private var groupId: UUID { threadSummary.groupId }
    private var currentUserId: UUID? {
        guard let userId = SupabaseManager.shared.currentUser?.id else { return nil }
        return UUID(uuidString: userId)
    }

    init(thread: MessageThread, threadSummary: ChatThreadSummary, onBack: @escaping () -> Void) {
        self.thread = thread
        self.threadSummary = threadSummary
        self.onBack = onBack
        print("🟣 ChatThreadView INIT - threadId: \(threadSummary.threadId)")
    }

    var isGroup: Bool {
        !threadSummary.kind.isDm
    }

    var isDmWithLeader: Bool {
        guard threadSummary.kind.isDm, let role = threadSummary.dmOtherRole else { return false }
        return role == "pastor" || role == "leader"
    }

    var messages: [ChatMessageWithSender] {
        chatService.messagesByThread[threadId] ?? []
    }

    var groupStats: (members: Int, active: Int)? {
        chatService.groupStats[groupId]
    }

    // Get role for a user in the current group
    func roleFor(userId: UUID) -> MessageThread.LeaderRole? {
        guard let roles = chatService.rolesByGroup[groupId],
              let roleStr = roles[userId] else { return nil }
        return MessageThread.LeaderRole.from(rawServer: roleStr)
    }

    // Convert backend messages to display format with day separators
    struct MessageSection: Identifiable {
        let id = UUID()
        let dayLabel: String?
        let messages: [DisplayMessage]
    }

    struct DisplayMessage: Identifiable {
        let id: UUID
        let from: String
        let body: String
        let time: String
        let isMine: Bool
        let role: MessageThread.LeaderRole?
        let isFlagged: Bool
        let avatarUrl: String?
        let senderId: UUID
    }

    var messageSections: [MessageSection] {
        var sections: [MessageSection] = []
        var currentDay: Date?
        var currentMessages: [DisplayMessage] = []

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mma"

        for msgWithSender in messages {
            let msg = msgWithSender.message
            let msgDay = Calendar.current.startOfDay(for: msg.createdAt)

            // Check if we need a new section
            if currentDay != msgDay {
                if !currentMessages.isEmpty {
                    sections.append(MessageSection(dayLabel: dayLabel(for: currentDay!), messages: currentMessages))
                    currentMessages = []
                }
                currentDay = msgDay
            }

            let isMine = msg.senderId == currentUserId
            let role = isMine ? nil : roleFor(userId: msg.senderId)
            let isFlagged = msg.moderationStatus == .flagged_allowed || msg.moderationStatus == .flagged_blocked

            currentMessages.append(DisplayMessage(
                id: msg.id,
                from: msgWithSender.senderDisplayName,
                body: msg.body,
                time: timeFormatter.string(from: msg.createdAt),
                isMine: isMine,
                role: role,
                isFlagged: isFlagged,
                avatarUrl: msgWithSender.senderAvatarUrl,
                senderId: msg.senderId
            ))
        }

        if !currentMessages.isEmpty, let day = currentDay {
            sections.append(MessageSection(dayLabel: dayLabel(for: day), messages: currentMessages))
        }

        return sections
    }

    func dayLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "TODAY"
        } else if Calendar.current.isDateInYesterday(date) {
            return "YESTERDAY"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d"
            return formatter.string(from: date).uppercased()
        }
    }

    func loadOlderMessages() async {
        guard hasMoreMessages, !isLoadingMore else { return }
        let currentCount = messages.count
        guard currentCount > 0 else { return }

        isLoadingMore = true
        let fetched = await chatService.loadMessages(threadId: threadId, limit: pageSize, offset: currentCount)
        hasMoreMessages = fetched >= pageSize
        isLoadingMore = false
    }

    /// Dismiss the chat view, resigning the keyboard first so it doesn't
    /// stay up over the messages-list view underneath.
    func dismissChat() {
        isTextFieldFocused = false
        onBack()
    }

    func sendMessage() async {
        let body = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, !isSending else { return }

        isSending = true
        sendError = nil
        messageText = "" // Clear immediately for better UX

        // Optimistic insert so the user sees their message right away.
        // The realtime subscription will replace this with the server's row
        // once it arrives (matched by sender + body + nearby timestamp).
        if let uid = currentUserId {
            let displayName = chatService.profileCache[uid]?.name
                ?? SupabaseManager.shared.currentUser?.displayName
                ?? "You"
            chatService.addMessageOptimistically(
                threadId: threadId,
                body: body,
                senderId: uid,
                senderName: displayName
            )
        }

        do {
            let result = try await chatService.send(threadId: threadId, body: body)
            if result.blocked {
                sendError = result.reason ?? "Message blocked by moderation"
                messageText = body // Restore message if blocked
                // Drop the optimistic entry; refresh from server.
                await chatService.loadMessages(threadId: threadId)
            }
        } catch {
            sendError = "Failed to send message"
            messageText = body // Restore message on error
            await chatService.loadMessages(threadId: threadId)
        }

        isSending = false
    }

    var body: some View {
        let _ = print("🟣 ChatThreadView body rendering - messages count: \(messages.count)")
        return VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Button(action: dismissChat) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(YGColors.ink)
                        .frame(width: 38, height: 38)
                }

                // Thread icon
                if isGroup {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11)
                            .fill(thread.gradient?.gradient ?? LinearGradient(colors: [.gray], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 38, height: 38)

                        if thread.kind == .smallGroup {
                            Text("🌿")
                                .font(.system(size: 18))
                        } else {
                            Text(thread.name.split(separator: " ").prefix(2).map { String($0.prefix(1)) }.joined())
                                .font(.lilitaOne(size: 14))
                                .foregroundStyle(.white)
                        }
                    }
                } else {
                    YGAvatar(name: thread.name, size: 38)
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(thread.name)
                            .font(.lilitaOne(size: 15.5))
                            .tracking(-0.3)
                            .foregroundStyle(ThemeColors.primaryText(isDark: appearanceManager.isDarkMode))
                            .lineLimit(1)

                        if let role = thread.role {
                            Text(role.rawValue)
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(role.color)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }

                    Text(isGroup ? (groupStats.map { "\($0.members) members · \($0.active) active" } ?? "\(thread.memberCount ?? 0) members") : "Online")
                        .font(.system(size: 11.5))
                        .foregroundStyle(ThemeColors.secondaryText(isDark: appearanceManager.isDarkMode))
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 60)
            .padding(.bottom, 12)
            .background(
                ThemeColors.background(isDark: appearanceManager.isDarkMode).opacity(0.85)
                    .background(.ultraThinMaterial)
            )
            .overlay(alignment: .bottom) {
                Divider()
                    .background(ThemeColors.divider(isDark: appearanceManager.isDarkMode))
            }

            // Messages
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if messages.isEmpty {
                            Text("No messages yet")
                                .font(.system(size: 14))
                                .foregroundStyle(ThemeColors.tertiaryText(isDark: appearanceManager.isDarkMode))
                                .padding(.top, 40)
                        } else {
                            // Top sentinel: triggers loading older messages when scrolled into view
                            Color.clear
                                .frame(height: 1)
                                .onAppear {
                                    Task { await loadOlderMessages() }
                                }

                            if isLoadingMore {
                                ProgressView()
                                    .padding(.vertical, 8)
                            }

                            ForEach(messageSections) { section in
                                if let dayLabel = section.dayLabel {
                                    Text(dayLabel)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(ThemeColors.tertiaryText(isDark: appearanceManager.isDarkMode))
                                        .tracking(1)
                                        .padding(.top, 14)
                                        .padding(.bottom, 4)
                                }

                                ForEach(Array(section.messages.enumerated()), id: \.offset) { index, message in
                                    LiveMessageBubble(
                                        message: message,
                                        showAvatar: !message.isMine && (index == 0 || section.messages[index - 1].senderId != message.senderId),
                                        isDarkMode: appearanceManager.isDarkMode,
                                        hideFlaggedTag: isDmWithLeader
                                    )
                                    .id(message.id)
                                }
                            }
                        }

                        if let error = sendError {
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundStyle(.red)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.red.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .padding(.top, 8)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 6)
                }
                .frame(maxHeight: .infinity)
                .defaultScrollAnchor(.bottom)
                .background(ThemeColors.background(isDark: appearanceManager.isDarkMode))
                .onChange(of: messages.count) { _, _ in
                    withAnimation {
                        scrollProxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onChange(of: isTextFieldFocused) { _, isFocused in
                    if isFocused {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation {
                                scrollProxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                    }
                }
            }

            // Composer
            HStack(spacing: 8) {
                TextField("Message \(isGroup ? (thread.kind == .smallGroup ? "#small-group" : "#main") : thread.name.split(separator: " ").first ?? "")...", text: $messageText)
                    .font(.system(size: 15))
                    .foregroundStyle(ThemeColors.primaryText(isDark: appearanceManager.isDarkMode))
                    .focused($isTextFieldFocused)

                Button {
                    Task {
                        await sendMessage()
                    }
                } label: {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [YGColors.violet, YGColors.pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .shadow(color: YGColors.violet.opacity(0.3), radius: 10, y: 4)
                        .overlay {
                            if isSending {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white)
                            }
                        }
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(ThemeColors.secondaryBackground(isDark: appearanceManager.isDarkMode))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(ThemeColors.border(isDark: appearanceManager.isDarkMode), lineWidth: 1)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, keyboardHeight > 0 ? 8 : 100)
            .background(ThemeColors.background(isDark: appearanceManager.isDarkMode))
            .overlay(alignment: .top) {
                Divider()
                    .opacity(0.06)
            }
        }
        .background(YGColors.paper)
        .ignoresSafeArea(edges: .top)
        .offset(x: dragOffset)
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    // Only respond to horizontal drags (more horizontal than vertical) starting from leading edge
                    let isHorizontalDrag = abs(value.translation.width) > abs(value.translation.height) * 2
                    let startedFromLeadingEdge = value.startLocation.x < 40
                    if isHorizontalDrag && startedFromLeadingEdge && value.translation.width > 0 {
                        dragOffset = value.translation.width
                    }
                }
                .onEnded { value in
                    let velocity = value.predictedEndTranslation.width - value.translation.width

                    if value.translation.width > 120 || velocity > 100 {
                        // Dismiss keyboard immediately so it doesn't get stuck
                        // on the messages list after this view goes away.
                        isTextFieldFocused = false
                        // Dismiss with smooth animation
                        withAnimation(.easeOut(duration: 0.25)) {
                            dragOffset = UIScreen.main.bounds.width
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            onBack()
                            dragOffset = 0
                        }
                    } else {
                        // Spring back
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            isTextFieldFocused = false
        }
        .task {
            print("🔵 ChatThreadView .task started for threadId: \(threadId)")
            print("🔵 isGroup: \(isGroup), groupId: \(groupId)")

            // Load messages, roles, and stats
            let fetched = await chatService.loadMessages(threadId: threadId, limit: pageSize, offset: 0)
            hasMoreMessages = fetched >= pageSize

            if isGroup {
                await chatService.loadRolesForGroup(groupId)
                await chatService.loadGroupStats(groupId)
            }

            // Subscribe to realtime updates
            await chatService.subscribe(threadId: threadId)

            // Mark thread as read
            Task {
                try? await chatService.markRead(threadId: threadId)
            }

            print("🔵 ChatThreadView .task completed")
        }
        .onDisappear {
            // Unsubscribe from realtime
            Task {
                await chatService.unsubscribe(threadId: threadId)
            }
        }
        .onAppear {
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    withAnimation(.easeOut(duration: 0.25)) {
                        keyboardHeight = keyboardFrame.height
                    }
                }
            }

            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    keyboardHeight = 0
                }
            }
        }
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: LegacyChatMessage
    let showAvatar: Bool
    let isDarkMode: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isMine {
                Spacer()
            }

            if !message.isMine {
                VStack {
                    if showAvatar {
                        YGAvatar(name: message.from, size: 32)
                    } else {
                        Color.clear
                            .frame(width: 32, height: 32)
                    }
                }
            }

            VStack(alignment: message.isMine ? .trailing : .leading, spacing: 3) {
                if !message.isMine && showAvatar {
                    HStack(spacing: 6) {
                        Text(message.from)
                            .font(.lilitaOne(size: 11.5))
                            .foregroundStyle(ThemeColors.secondaryText(isDark: isDarkMode))

                        if let role = message.role {
                            Text(role.rawValue)
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(role.color)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                .tracking(0.3)
                        }
                    }
                    .padding(.leading, 8)
                }

                if message.isScripture {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\"Be strong and courageous.\"")
                            .font(.system(size: 16, design: .serif))
                            .italic()
                            .foregroundStyle(.white)

                        Text("JOSHUA 1:9 · NLT")
                            .font(.lilitaOne(size: 11))
                            .foregroundStyle(.white.opacity(0.9))
                            .tracking(0.5)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [YGColors.violet, YGColors.pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [YGColors.violet, YGColors.pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 18, height: 18)
                            .offset(x: 0, y: 9)
                    }
                    .shadow(color: YGColors.violet.opacity(0.3), radius: 12, y: 4)
                } else {
                    Text(message.body)
                        .font(.system(size: 14.5))
                        .foregroundStyle(message.isMine ? .white : ThemeColors.primaryText(isDark: isDarkMode))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(
                            message.isMine ?
                            LinearGradient(
                                colors: [YGColors.violet, YGColors.pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(colors: [ThemeColors.cardBackground(isDark: isDarkMode)], startPoint: .top, endPoint: .bottom)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(alignment: .bottomLeading) {
                            if !message.isMine {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(LinearGradient(colors: [ThemeColors.cardBackground(isDark: isDarkMode)], startPoint: .top, endPoint: .bottom))
                                    .frame(width: 18, height: 18)
                                    .offset(x: -9, y: 9)
                            }
                        }
                        .overlay {
                            if !message.isMine {
                                RoundedRectangle(cornerRadius: 18)
                                    .strokeBorder(ThemeColors.border(isDark: isDarkMode), lineWidth: 0.5)
                            }
                        }
                        .shadow(color: message.isMine ? YGColors.violet.opacity(0.25) : .clear, radius: 8, y: 2)
                }

                Text(message.time)
                    .font(.system(size: 10.5))
                    .foregroundStyle(ThemeColors.tertiaryText(isDark: isDarkMode))
                    .padding(.horizontal, message.isMine ? 4 : 8)
            }
            .frame(maxWidth: 280, alignment: message.isMine ? .trailing : .leading)
        }
    }
}

// MARK: - Live Message Bubble (for backend messages)
struct LiveMessageBubble: View {
    let message: ChatThreadView.DisplayMessage
    let showAvatar: Bool
    let isDarkMode: Bool
    var hideFlaggedTag: Bool = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isMine {
                Spacer(minLength: 0)
            }

            VStack(alignment: message.isMine ? .trailing : .leading, spacing: 3) {
                if !message.isMine && showAvatar {
                    HStack(spacing: 6) {
                        Text(message.from)
                            .font(.lilitaOne(size: 11.5))
                            .foregroundStyle(ThemeColors.secondaryText(isDark: isDarkMode))

                        if let role = message.role {
                            Text(role.rawValue)
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(role.color)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }

                VStack(alignment: message.isMine ? .trailing : .leading, spacing: 4) {
                    Text(message.body)
                        .font(.system(size: 14.5))
                        .foregroundStyle(message.isMine ? .white : ThemeColors.primaryText(isDark: isDarkMode))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(
                            message.isMine ?
                            LinearGradient(
                                colors: [YGColors.violet, YGColors.pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(colors: [ThemeColors.cardBackground(isDark: isDarkMode)], startPoint: .top, endPoint: .bottom)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(alignment: .bottomLeading) {
                            if !message.isMine {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(LinearGradient(colors: [ThemeColors.cardBackground(isDark: isDarkMode)], startPoint: .top, endPoint: .bottom))
                                    .frame(width: 18, height: 18)
                                    .offset(x: -9, y: 9)
                            }
                        }
                        .overlay {
                            if !message.isMine {
                                RoundedRectangle(cornerRadius: 18)
                                    .strokeBorder(ThemeColors.border(isDark: isDarkMode), lineWidth: 0.5)
                            }
                        }
                        .shadow(color: message.isMine ? YGColors.violet.opacity(0.25) : .clear, radius: 8, y: 2)

                    if message.isFlagged && !hideFlaggedTag {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9))
                            Text("Flagged by moderation")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }

                Text(message.time)
                    .font(.system(size: 10.5))
                    .foregroundStyle(ThemeColors.tertiaryText(isDark: isDarkMode))
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: 280, alignment: message.isMine ? .trailing : .leading)

            if !message.isMine {
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Typing Indicator
struct TypingIndicator: View {
    @State private var animating = false
    let isDarkMode: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            YGAvatar(name: "Eli J.", size: 28)

            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(ThemeColors.tertiaryText(isDark: isDarkMode))
                        .frame(width: 6, height: 6)
                        .offset(y: animating ? -3 : 0)
                        .animation(
                            .easeInOut(duration: 1.2)
                            .repeatForever()
                            .delay(Double(index) * 0.15),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(ThemeColors.cardBackground(isDark: isDarkMode))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(ThemeColors.cardBackground(isDark: isDarkMode))
                    .frame(width: 18, height: 18)
                    .offset(x: -9, y: 9)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(ThemeColors.border(isDark: isDarkMode), lineWidth: 0.5)
            }

            Spacer()
        }
        .onAppear {
            animating = true
        }
    }
}

#Preview("Messages List") {
    MessagesListView()
}

#Preview("Chat Thread") {
    ChatThreadView(
        thread: MessageThread(
            id: "gc-main",
            kind: .group,
            name: "Grace City Youth",
            subtitle: "Pastor Jordan: Pumped for tonight 🔥",
            time: "2m",
            unread: 3,
            gradient: GradientInfo(startColor: "6B2BFF", endColor: "FF3DA5"),
            isGroup: true,
            memberCount: 184,
            role: nil,
            logoUrl: nil
        ),
        threadSummary: ChatThreadSummary(
            threadId: UUID(uuidString: "gc-main") ?? UUID(),
            kind: .groupMain,
            groupId: UUID(),
            groupName: "Grace City Youth",
            groupGradientFrom: "6B2BFF",
            groupGradientTo: "FF3DA5",
            smallGroupId: nil,
            smallGroupName: nil,
            dmOtherUserId: nil,
            dmOtherDisplay: nil,
            dmOtherAvatarUrl: nil,
            dmOtherRole: nil,
            lastMessageBody: "Pumped for tonight 🔥",
            lastMessageSender: "Pastor Jordan",
            lastMessageAt: Date(),
            unreadCount: 3
        ),
        onBack: {}
    )
}
