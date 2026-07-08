//
//  PastorFlaggedMessagesView.swift
//  YGTeeV
//
//  Moderation queue for a youth group, backed by
//  `pastor_moderation_queue`. One row per open `moderation_alerts`
//  entry, with sender + (optional) DM recipient profiles, the
//  thread-kind pill, and — for messages that triggered a pastoral-
//  concern classifier (e.g. mental_health) — a category pill with a
//  confidence percentage and the plain-English `concern_reason`.
//
//  Approve / Reject acknowledge the alert via `pastor_approve_alert`
//  / `pastor_reject_alert`. Both rows disappear on the next fetch.
//  Local filter chips re-filter the cached server result; no refetch
//  on chip change.
//
//  Tapping a card outside the action buttons routes into the parent
//  thread via the same overlay pattern the hub uses.
//

import SwiftUI

struct PastorFlaggedMessagesView: View {
    let groupId: UUID
    let onClose: () -> Void
    /// Tap → bubble the thread id up so the hub can present the
    /// existing ChatThreadView.
    let onOpenThread: (UUID) -> Void

    @State private var chat = ChatService.shared
    @State private var items: [ModerationAlert] = []
    @State private var filter: ModerationFilter = .all
    @State private var isLoading = false
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                filterChips
                contentBody
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 100)
        }
        .background(YGColors.paper.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .task {
            if items.isEmpty { await loadQueue() }
        }
        .refreshable {
            await loadQueue()
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
                    .overlay { Circle().strokeBorder(.black.opacity(0.06), lineWidth: 0.5) }
            }
            Text("Moderation")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(YGColors.ink)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(YGColors.paper)
    }

    // MARK: - Filter chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ModerationFilter.allCases) { f in
                    Button {
                        filter = f
                    } label: {
                        Text(f.label)
                            .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(filter == f ? .white : YGColors.ink.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(filter == f ? YGColors.violet : Color.white)
                            .clipShape(Capsule())
                            .overlay {
                                Capsule()
                                    .strokeBorder(filter == f ? Color.clear : .black.opacity(0.08), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Body branching
    //
    // Empty / error states are mutually exclusive — never render both
    // the "Nothing flagged" reassurance and the "Couldn't load…" red
    // banner at once.

    @ViewBuilder
    private var contentBody: some View {
        if let errorText {
            errorBanner(errorText)
        } else if filteredItems.isEmpty && !isLoading {
            emptyState
                .padding(.top, 40)
        } else {
            VStack(spacing: 12) {
                ForEach(filteredItems) { alert in
                    alertCard(alert)
                }
                if isLoading {
                    ProgressView().padding(.vertical, 16)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 36))
                .foregroundStyle(YGColors.violet.opacity(0.7))
            Text(emptyHeadline)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(YGColors.ink)
            if filter == .all {
                Text("Keep it up.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(YGColors.ink.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// All-filter empty state speaks for the whole group; other
    /// filters speak for the current chip.
    private var emptyHeadline: String {
        if filter == .all && items.isEmpty {
            return "Nothing flagged in your group."
        }
        return "Nothing in this filter."
    }

    private func errorBanner(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color(hex: "D6322F"))
            Text(text)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Color(hex: "D6322F"))
            Spacer()
            Button("Retry") { Task { await loadQueue() } }
                .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: "D6322F"))
        }
        .padding(12)
        .background(Color(hex: "D6322F").opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Card

    /// Card layout: sender header → recipient line (DMs only) → pill
    /// row (status/concern + thread kind) → preview body → optional
    /// concern_reason in italics → timestamp + chevron → action row.
    @ViewBuilder
    private func alertCard(_ alert: ModerationAlert) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            senderHeader(alert)
            if alert.recipientId != nil {
                recipientLine(alert)
            }
            pillRow(alert)
            previewBody(alert)
            if let reason = alert.concernReason?.trimmingCharacters(in: .whitespacesAndNewlines),
               !reason.isEmpty {
                Text(reason)
                    .font(.system(size: 12.5).italic())
                    .foregroundStyle(YGColors.ink.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 6) {
                Text(alert.createdAt.formatted(.relative(presentation: .named)))
                    .font(.system(size: 11))
                    .foregroundStyle(YGColors.ink.opacity(0.5))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(YGColors.ink.opacity(0.25))
            }
            actionRow(alert)
        }
        .padding(12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.06), lineWidth: 0.5) }
        // Tapping the card surface opens the parent thread. Inner
        // Button views (Approve/Reject) consume their own taps, so
        // this gesture only fires for the surrounding chrome.
        .contentShape(Rectangle())
        .onTapGesture {
            onOpenThread(alert.threadId)
        }
    }

    private func senderHeader(_ alert: ModerationAlert) -> some View {
        HStack(alignment: .top, spacing: 10) {
            avatar(url: alert.senderAvatarUrl, fallbackName: alert.senderDisplayName)
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.senderDisplayName)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(YGColors.ink)
                if let email = alert.senderEmail, !email.isEmpty {
                    Text(email)
                        .font(.system(size: 11.5))
                        .foregroundStyle(YGColors.ink.opacity(0.55))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer()
        }
    }

    private func recipientLine(_ alert: ModerationAlert) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.turn.down.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(YGColors.ink.opacity(0.45))
            Text("to \(alert.recipientDisplayName ?? "—")")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(YGColors.ink.opacity(0.7))
            if let role = alert.recipientRole, !role.isEmpty {
                rolePill(role)
            }
            Spacer()
        }
        .padding(.leading, 48) // align with the sender name column
    }

    @ViewBuilder
    private func rolePill(_ role: String) -> some View {
        Text(role.uppercased())
            .font(.system(size: 9, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(roleColor(role))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .tracking(0.4)
    }

    private func roleColor(_ role: String) -> Color {
        switch role.lowercased() {
        case "pastor": return YGColors.violet
        case "leader": return Color(hex: "0066FF")
        case "parent": return YGColors.lime
        default:       return YGColors.ink.opacity(0.55)
        }
    }

    /// Pastoral concerns visually trump status — when present, the
    /// violet category pill replaces the red/amber status pill.
    private func pillRow(_ alert: ModerationAlert) -> some View {
        let hasConcern = (alert.concernCategory?.isEmpty == false)
        return HStack(spacing: 6) {
            if hasConcern {
                concernPill(alert)
            } else {
                statusPill(alert.moderationStatus)
            }
            threadKindPill(alert)
            Spacer()
        }
    }

    @ViewBuilder
    private func concernPill(_ alert: ModerationAlert) -> some View {
        let category = (alert.concernCategory ?? "")
            .replacingOccurrences(of: "_", with: " ")
            .uppercased()
        let pct: String? = alert.concernConfidence.map { "\(Int(($0 * 100).rounded()))%" }
        Text(pct.map { "\(category) \($0)" } ?? category)
            .font(.system(size: 10, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(YGColors.violet)
            .clipShape(Capsule())
            .tracking(0.4)
    }

    @ViewBuilder
    private func statusPill(_ status: String) -> some View {
        let (label, bg): (String, Color) = {
            switch status {
            case "flagged_blocked": return ("BLOCKED", Color(hex: "D6322F"))
            default:                return ("ALLOWED — FLAGGED", Color(hex: "FF6B35"))
            }
        }()
        Text(label)
            .font(.system(size: 10, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(bg)
            .clipShape(Capsule())
            .tracking(0.4)
    }

    @ViewBuilder
    private func threadKindPill(_ alert: ModerationAlert) -> some View {
        let label: String = {
            switch alert.threadKind {
            case "dm_pastor":  return "DM with pastor"
            case "dm_leader":  return "DM with leader"
            case "dm_parent_pastor": return "DM with pastor (parent)"
            case "dm_parent_leader": return "DM with leader (parent)"
            case "group_main": return "Group chat"
            case "parent_chat": return "Parent chat"
            case "small_group":
                if let n = alert.smallGroupName, !n.isEmpty {
                    return "Small group: \(n)"
                }
                return "Small group"
            case "custom":     return "Custom chat"
            default:           return alert.threadKind
            }
        }()
        Text(label)
            .font(.system(size: 10, weight: .heavy))
            .foregroundStyle(YGColors.ink.opacity(0.65))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(YGColors.ink.opacity(0.08))
            .clipShape(Capsule())
    }

    private func previewBody(_ alert: ModerationAlert) -> some View {
        Text(alert.preview)
            .font(.system(size: 13.5))
            .foregroundStyle(YGColors.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color(hex: "FF6B35").opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Avatar

    @ViewBuilder
    private func avatar(url: URL?, fallbackName: String) -> some View {
        if let url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                default:
                    initialsFallback(name: fallbackName)
                }
            }
            .frame(width: 38, height: 38)
            .clipShape(Circle())
        } else {
            initialsFallback(name: fallbackName)
        }
    }

    private func initialsFallback(name: String) -> some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: 14, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 38, height: 38)
            .background(
                LinearGradient(colors: [YGColors.violet, Color(hex: "FF3DA5")],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(Circle())
    }

    // MARK: - Action row
    //
    // Approve label switches to "Mark as reviewed" when the alert
    // carries a pastoral concern — the action is the same RPC, but
    // the verb reads differently when the message wasn't violating
    // anything per se (e.g. self-harm signals).

    private func actionRow(_ alert: ModerationAlert) -> some View {
        let approveLabel = (alert.concernCategory?.isEmpty == false)
            ? "Mark as reviewed"
            : "Approve"
        return HStack(spacing: 8) {
            Button {
                act(alert, .approve)
            } label: {
                Text(approveLabel)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(YGColors.violet)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                act(alert, .reject)
            } label: {
                Text("Reject")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: "D6322F"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(hex: "D6322F").opacity(0.10))
                    .clipShape(Capsule())
                    .overlay {
                        Capsule().strokeBorder(Color(hex: "D6322F").opacity(0.35), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Filtering

    private var filteredItems: [ModerationAlert] {
        switch filter {
        case .all:
            return items
        case .blocked:
            return items.filter { $0.moderationStatus == "flagged_blocked" }
        case .allowed:
            // Allowed-but-not-a-pastoral-concern. Concerns get their
            // own bucket so they don't double-up.
            return items.filter {
                $0.moderationStatus == "flagged_allowed"
                && ($0.concernCategory?.isEmpty ?? true)
            }
        case .pastoralConcerns:
            return items.filter { ($0.concernCategory?.isEmpty ?? true) == false }
        }
    }

    // MARK: - Fetch + actions

    private func loadQueue() async {
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await chat.pastorModerationQueue(groupId: groupId)
            errorText = nil
        } catch {
            print("[PastorFlaggedMessagesView] pastor_moderation_queue failed:", error)
            errorText = "Couldn't load moderation queue."
        }
    }

    private enum ActionKind { case approve, reject }

    /// Optimistic remove + RPC. On failure restores the row and
    /// surfaces an error banner (mutually exclusive with the empty
    /// state per the design rules).
    private func act(_ alert: ModerationAlert, _ action: ActionKind) {
        let backup = items
        items.removeAll { $0.id == alert.id }
        Task {
            do {
                switch action {
                case .approve: try await chat.pastorApproveAlert(alertId: alert.id)
                case .reject:  try await chat.pastorRejectAlert(alertId: alert.id)
                }
                // Soft haptic acknowledgement of the action.
                #if canImport(UIKit)
                await MainActor.run {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                #endif
            } catch {
                print("[PastorFlaggedMessagesView] action \(action) failed:", error)
                await MainActor.run {
                    items = backup
                    errorText = "Couldn't apply that action — try again."
                }
            }
        }
    }
}
