//
//  PastorDashboardView.swift
//  YGTeeV
//
//  The pastor's main surface: hero header card with group stats, a
//  pending-requests banner, two prominent stat cards, the tools list,
//  and the most recent activity preview. Wired entirely to the
//  pastor_* RPCs via PastorDashboardService.
//

import SwiftUI

struct PastorDashboardView: View {
    let initialGroupId: UUID
    /// Optional callback for overlay-style presentation (used by ProfileView's
    /// slide-in). In a regular NavigationStack push, leave nil and the
    /// default back button handles it.
    var onDismiss: (() -> Void)? = nil

    @State private var service = PastorDashboardService.shared
    @State private var showMembers = false
    @State private var membersInitialTab: MembersView.Tab = .all
    @State private var showEvents = false
    @State private var showPlans = false
    @State private var showCreateFeedPost = false
    @State private var showGroupQR = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                if let snap = service.dashboard, snap.pendingRequestCount > 0 {
                    requestsBanner(count: snap.pendingRequestCount)
                }
                statsRow
                toolsList
                recentActivitySection
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 120)
        }
        .background(YGColors.paper.ignoresSafeArea())
        .toolbar {
            if let onDismiss {
                ToolbarItem(placement: .topBarLeading) {
                    Button { onDismiss() } label: {
                        Image(systemName: "chevron.left").font(.system(size: 15, weight: .bold))
                    }
                }
            }
        }
        .navigationDestination(isPresented: $showMembers) {
            MembersView(initialTab: membersInitialTab)
        }
        .fullScreenCover(isPresented: $showEvents) {
            if let groupId = service.activeGroupId {
                EventsManagerView(groupId: groupId)
            }
        }
        .fullScreenCover(isPresented: $showPlans) {
            if let groupId = service.activeGroupId {
                NavigationStack {
                    PastorPlansListView(groupId: groupId, onClose: { showPlans = false })
                }
            }
        }
        .sheet(isPresented: $showCreateFeedPost) {
            if let groupId = service.activeGroupId {
                CreateFeedPostSheet(groupId: groupId)
            }
        }
        .fullScreenCover(isPresented: $showGroupQR) {
            if let groupId = service.activeGroupId,
               let snap = service.dashboard {
                // The snapshot doesn't expose church / gradient yet, so
                // pass nil and let the sheet fall back to the dashboard
                // violet → pink palette.
                YouthGroupQRSheet(
                    groupId: groupId,
                    groupName: snap.groupName,
                    churchName: nil,
                    gradientFrom: nil,
                    gradientTo: nil
                )
            }
        }
        .task {
            // Adopt the requested group on entry. Switching groups via the
            // service automatically clears caches, so always set this.
            if service.activeGroupId != initialGroupId {
                service.activeGroupId = initialGroupId
            }
            if service.myGroups.isEmpty { await service.loadMyGroups() }
            await service.refreshDashboard()
        }
        .refreshable {
            await service.refreshDashboard()
        }
    }

    // MARK: - Header card

    private var headerCard: some View {
        let snap = service.dashboard
        return ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 10) {
                Text("PASTOR DASHBOARD")
                    .font(.system(size: 10.5, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.75))
                Text(snap?.groupName ?? "Loading…")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                HStack(spacing: 12) {
                    quickStat(value: snap?.memberCount ?? 0, label: "members")
                    Text("·").foregroundStyle(.white.opacity(0.4))
                    quickStat(value: snap?.smallGroupCount ?? 0, label: "small groups")
                    Text("·").foregroundStyle(.white.opacity(0.4))
                    quickStat(value: snap?.pendingRequestCount ?? 0, label: "requests")
                }
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [YGColors.violet, Color(hex: "FF3DA5")],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: YGColors.violet.opacity(0.4), radius: 12, y: 6)

            // Top-right cluster: QR button + (optional) "N new" pill.
            // Stacked horizontally so both are visible when there are
            // pending requests.
            HStack(spacing: 8) {
                if let count = snap?.pendingRequestCount, count > 0 {
                    HStack(spacing: 5) {
                        Circle().fill(Color(hex: "FFD60A")).frame(width: 6, height: 6)
                        Text("\(count) new")
                            .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(YGColors.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: "FFD60A"))
                    .clipShape(Capsule())
                }

                Button { showGroupQR = true } label: {
                    Image(systemName: "qrcode")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.18))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(12)
        }
    }

    private func quickStat(value: Int, label: String) -> some View {
        HStack(spacing: 4) {
            Text("\(value)").fontWeight(.heavy)
            Text(label)
        }
    }

    // MARK: - Requests banner

    private func requestsBanner(count: Int) -> some View {
        Button {
            membersInitialTab = .requests
            showMembers = true
        } label: {
            HStack(spacing: 12) {
                Text("👤")
                    .font(.system(size: 20))
                    .frame(width: 44, height: 44)
                    .background(Color(hex: "FFD60A").opacity(0.22))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(count) join request\(count == 1 ? "" : "s") waiting")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(YGColors.ink)
                    Text("Tap to review and approve")
                        .font(.system(size: 11.5))
                        .foregroundStyle(YGColors.ink.opacity(0.6))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(YGColors.ink.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color(hex: "FFD60A").opacity(0.4), lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stat cards

    private var statsRow: some View {
        let snap = service.dashboard
        let activeThis = snap?.activeThisWeekPct ?? 0
        let activeLast = snap?.activeLastWeekPct ?? 0
        let xp = snap?.totalGroupXP ?? 0
        let xpDelta = pctDelta(current: snap?.activeThisWeek ?? 0, previous: snap?.activeLastWeek ?? 0)
        return HStack(spacing: 12) {
            statCard(
                dotColor: Color(hex: "B4FF3C"),
                value: "\(activeThis)%",
                title: "Active this week",
                subtitle: "vs \(activeLast)% last wk"
            )
            statCard(
                dotColor: Color(hex: "FFD60A"),
                value: formatXP(xp),
                title: "Group XP earned",
                subtitle: xpDelta.map { "↑ \($0)%" } ?? " "
            )
        }
    }

    private func statCard(dotColor: Color, value: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Circle().fill(dotColor).frame(width: 8, height: 8)
            Text(value)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(YGColors.ink)
                .monospacedDigit()
            Text(title)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(YGColors.ink)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(YGColors.ink.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(.black.opacity(0.05), lineWidth: 0.5) }
    }

    // MARK: - Tools

    private var toolsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tools")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(YGColors.ink)
                .padding(.top, 4)

            toolRow(icon: "calendar", title: "Events", subtitle: "View & manage all events") {
                showEvents = true
            }
            toolRow(icon: "video.fill", title: "Create feed post", subtitle: "Video or photo slideshow for your group") {
                showCreateFeedPost = true
            }
            toolRow(icon: "book.closed", title: "Publish a Bible plan", subtitle: "Custom plan for your group") {
                showPlans = true
            }
            toolRow(icon: "person.3", title: "Manage small groups", subtitle: smallGroupsSubtitle) {
                membersInitialTab = .smallGroups
                showMembers = true
            }
            toolRow(icon: "person.crop.circle.badge.checkmark", title: "Member management", subtitle: memberManagementSubtitle) {
                membersInitialTab = .all
                showMembers = true
            }
        }
    }

    private var smallGroupsSubtitle: String {
        let snap = service.dashboard
        let groups = snap?.smallGroupCount ?? 0
        // Leader total isn't on the snapshot — fall back to "N groups".
        return "\(groups) group\(groups == 1 ? "" : "s")"
    }

    private var memberManagementSubtitle: String {
        let snap = service.dashboard
        let m = snap?.memberCount ?? 0
        let r = snap?.pendingRequestCount ?? 0
        if r > 0 {
            return "\(m) member\(m == 1 ? "" : "s") · \(r) request\(r == 1 ? "" : "s")"
        }
        return "\(m) member\(m == 1 ? "" : "s")"
    }

    private func toolRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(YGColors.violet)
                    .frame(width: 38, height: 38)
                    .background(YGColors.violet.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(YGColors.ink)
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(YGColors.ink.opacity(0.55))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(YGColors.ink.opacity(0.3))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.05), lineWidth: 0.5) }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recent activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent activity")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(YGColors.ink)
                Spacer()
                if !service.recentActivity.isEmpty {
                    Button("See all") { /* future: full feed */ }
                        .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(YGColors.violet)
                }
            }
            .padding(.top, 4)

            if service.recentActivity.isEmpty {
                Text("No activity yet — members will start showing up here as they work through plans.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(YGColors.ink.opacity(0.5))
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.05), lineWidth: 0.5) }
            } else {
                ForEach(service.recentActivity.prefix(5)) { event in
                    activityRow(event)
                }
            }
        }
    }

    private func activityRow(_ event: RecentActivityEvent) -> some View {
        HStack(spacing: 12) {
            Text(initials(for: event.displayName))
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(tintFor(kind: event.kind))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text((event.displayName ?? "Someone") + " " + event.headline)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(YGColors.ink)
                    .lineLimit(2)
                Text(Self.relativeDate.localizedString(for: event.occurredAt, relativeTo: Date()))
                    .font(.system(size: 11))
                    .foregroundStyle(YGColors.ink.opacity(0.55))
            }

            Spacer()

            if event.xpDelta != 0 {
                HStack(spacing: 3) { Text("+\(event.xpDelta) XP") }
                    .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: "B8860B"))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color(hex: "FFD60A").opacity(0.22))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.05), lineWidth: 0.5) }
    }

    private func tintFor(kind: ActivityKind) -> Color {
        switch kind {
        case .planCompleted:   return Color(hex: "FF3DA5")
        case .dayCompleted:    return YGColors.violet
        case .joined:          return Color(hex: "00C6A2")
        case .eventRSVP:       return Color(hex: "0066FF")
        case .attendanceTaken: return Color(hex: "FF6B35")
        case .other:           return YGColors.ink.opacity(0.5)
        }
    }

    // MARK: - Helpers

    private func initials(for name: String?) -> String {
        guard let name, !name.isEmpty else { return "?" }
        return String(name.first!).uppercased()
    }

    private func formatXP(_ xp: Int64) -> String {
        if xp >= 1_000_000 {
            return String(format: "%.1fM", Double(xp) / 1_000_000)
        }
        if xp >= 1_000 {
            return String(format: "%.0fk", Double(xp) / 1_000)
        }
        return "\(xp)"
    }

    private func pctDelta(current: Int, previous: Int) -> Int? {
        guard previous > 0 else { return nil }
        let delta = ((current - previous) * 100) / previous
        guard delta != 0 else { return nil }
        return delta
    }

    private static let relativeDate: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
}
