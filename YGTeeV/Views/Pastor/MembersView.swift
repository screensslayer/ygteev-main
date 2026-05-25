//
//  MembersView.swift
//  YGTeeV
//
//  Pastor "Members" surface — four tabs:
//    • Requests   — pending join requests with approve/deny
//    • All        — everyone in the group with role + active dot
//    • Leaders    — same RPC filtered to role="leader"
//    • Small Grps — sub-groups inside this youth group
//

import SwiftUI

struct MembersView: View {
    enum Tab: Hashable, CaseIterable {
        case requests, all, leaders, smallGroups

        var label: String {
            switch self {
            case .requests:    return "Requests"
            case .all:         return "All"
            case .leaders:     return "Leaders"
            case .smallGroups: return "Small Groups"
            }
        }
    }

    var initialTab: Tab = .all

    @Environment(\.dismiss) private var dismiss
    @State private var service = PastorDashboardService.shared
    @State private var selectedTab: Tab = .all
    @State private var showCreateSmallGroup = false
    /// Toggled by the magnifying-glass toolbar button. When true the
    /// search field renders just under the tab bar and filters the
    /// active list client-side.
    @State private var showSearchBar: Bool = false
    @State private var searchQuery: String = ""
    /// Drives the slide-in member detail sheet. Carries the row tapped
    /// so the sheet can issue `pastor_member_profile`.
    @State private var selectedMember: PastorMember?
    @State private var selectedRequest: JoinRequest?

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            if showSearchBar { searchField }
            Divider().opacity(0.4)
            tabContent
        }
        .background(YGColors.paper.ignoresSafeArea())
        .navigationTitle("Members")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showSearchBar.toggle()
                        if !showSearchBar { searchQuery = "" }
                    }
                } label: {
                    Image(systemName: showSearchBar ? "xmark" : "magnifyingglass")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(YGColors.ink)
                }
            }
        }
        .task {
            selectedTab = initialTab
            await loadFor(selectedTab)
        }
        .onChange(of: selectedTab) { _, newTab in
            Task { await loadFor(newTab) }
        }
        .sheet(item: $selectedMember) { row in
            if let gid = service.activeGroupId {
                PastorMemberDetailView(groupId: gid, userId: row.userId)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(item: $selectedRequest) { req in
            if let gid = service.activeGroupId {
                PastorMemberDetailView(groupId: gid, userId: req.userId)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(YGColors.ink.opacity(0.4))
            TextField("Search by name, @handle, or email", text: $searchQuery)
                .font(.system(size: 14))
                .foregroundStyle(YGColors.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.search)
            if !searchQuery.isEmpty {
                Button { searchQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(YGColors.ink.opacity(0.35))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.black.opacity(0.06), lineWidth: 0.5)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    /// Case-insensitive contains match against name, handle, and email.
    /// Returns the input unchanged when the query is empty so the rest
    /// of the view can treat this as a pass-through.
    private func filteredMembers(_ rows: [PastorMember]) -> [PastorMember] {
        let q = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return rows }
        return rows.filter { m in
            (m.displayName?.lowercased().contains(q) ?? false)
            || (m.email?.lowercased().contains(q) ?? false)
            || (m.handle?.lowercased().contains(q) ?? false)
        }
    }

    private func filteredRequests(_ rows: [JoinRequest]) -> [JoinRequest] {
        let q = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return rows }
        return rows.filter { r in
            (r.displayName?.lowercased().contains(q) ?? false)
            || (r.email?.lowercased().contains(q) ?? false)
            || (r.handle?.lowercased().contains(q) ?? false)
        }
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    tabPill(tab)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(YGColors.paper)
    }

    private func tabPill(_ tab: Tab) -> some View {
        let selected = tab == selectedTab
        let count: Int? = {
            switch tab {
            case .requests: return service.joinRequests.count
            case .all:      return service.dashboard?.memberCount
            case .leaders:  return service.leaders.count
            case .smallGroups: return nil
            }
        }()
        return Button { selectedTab = tab } label: {
            HStack(spacing: 6) {
                Text(tab.label)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(YGColors.ink)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(selected ? Color(hex: "FFD60A") : YGColors.ink.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(selected ? .white : YGColors.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(selected ? YGColors.ink : .white)
            .clipShape(Capsule())
            .overlay {
                Capsule().strokeBorder(selected ? .clear : YGColors.ink.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .requests:    requestsList
        case .all:         membersList(rows: filteredMembers(service.allMembers))
        case .leaders:     membersList(rows: filteredMembers(service.leaders))
        case .smallGroups: smallGroupsList
        }
    }

    // MARK: - Requests

    private var requestsList: some View {
        ScrollView {
            VStack(spacing: 8) {
                let visible = filteredRequests(service.joinRequests)
                if visible.isEmpty {
                    emptyState(emoji: "✉️",
                               title: searchQuery.isEmpty ? "No pending requests" : "No matches",
                               message: searchQuery.isEmpty
                                ? "When teens ask to join, they'll show up here."
                                : "Try a different search.")
                } else {
                    ForEach(visible) { req in
                        Button { selectedRequest = req } label: {
                            requestRow(req)
                        }
                        .buttonStyle(.plain)
                    }
                    Text("+ approving sends a notification")
                        .font(.system(size: 11.5))
                        .foregroundStyle(YGColors.ink.opacity(0.5))
                        .padding(.top, 4)
                }
            }
            .padding(16)
        }
        .refreshable { await service.loadJoinRequests() }
    }

    private func requestRow(_ req: JoinRequest) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(req.displayName ?? req.email ?? "Unknown")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(YGColors.ink)
                    .lineLimit(1)
                Text("Asked: " + Self.relativeDate.localizedString(for: req.requestedAt, relativeTo: Date())
                     + (req.message.map { " · \($0)" } ?? ""))
                    .font(.system(size: 11.5))
                    .foregroundStyle(YGColors.ink.opacity(0.55))
                    .lineLimit(2)
                // Requesters aren't members yet — no role pill, but
                // PARENT + grade still tell the pastor at a glance who
                // they're approving.
                memberPills(role: nil, gradeYear: req.gradeYear, isParent: req.isParent)
            }

            Spacer()

            Button {
                Task { await service.denyJoinRequest(req.requestId) }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Color(hex: "FF3DA5"))
                    .frame(width: 32, height: 32)
                    .background(Color(hex: "FF3DA5").opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Button {
                Task { await service.approveJoinRequest(req.requestId) }
            } label: {
                Text("Approve")
                    .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(colors: [YGColors.violet, Color(hex: "FF3DA5")],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.05), lineWidth: 0.5) }
    }

    // MARK: - Members (all / leaders)

    private func membersList(rows: [PastorMember]) -> some View {
        ScrollView {
            VStack(spacing: 8) {
                if rows.isEmpty {
                    emptyState(emoji: "👥",
                               title: searchQuery.isEmpty ? "No members yet" : "No matches",
                               message: searchQuery.isEmpty
                                ? "Members will appear once they join the group."
                                : "Try a different search.")
                } else {
                    ForEach(rows) { member in
                        Button { selectedMember = member } label: {
                            memberRow(member)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .refreshable {
            await selectedTab == .leaders ? service.loadLeaders() : service.loadAllMembers()
        }
    }

    private func memberRow(_ m: PastorMember) -> some View {
        HStack(spacing: 12) {
            avatar(name: m.displayName, gradient: memberAvatarGradient(m))
                .frame(width: 38, height: 38)
                .overlay(alignment: .bottomTrailing) {
                    if m.isActiveWeek {
                        Circle()
                            .fill(Color(hex: "2B8A3E"))
                            .frame(width: 10, height: 10)
                            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                            .offset(x: 2, y: 2)
                    }
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(m.displayName ?? m.email ?? "Member")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(YGColors.ink)
                    .lineLimit(1)
                if let email = m.email {
                    Text(email)
                        .font(.system(size: 11.5))
                        .foregroundStyle(YGColors.ink.opacity(0.55))
                        .lineLimit(1)
                }
                // Role + PARENT + grade in one strip so pastors can
                // triage members at a glance.
                memberPills(role: m.role, gradeYear: m.gradeYear, isParent: m.isParent)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("⚡ \(m.xp)")
                    .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(YGColors.ink)
                if m.streak > 0 {
                    Text("🔥 \(m.streak)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(YGColors.ink.opacity(0.55))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.05), lineWidth: 0.5) }
    }

    private func rolePill(role: MemberRole) -> some View {
        let (label, color, bg): (String, Color, Color) = {
            switch role {
            case .pastor: return ("PASTOR", YGColors.violet, YGColors.violet.opacity(0.14))
            case .leader: return ("LEADER", Color(hex: "0066FF"), Color(hex: "0066FF").opacity(0.12))
            case .parent: return ("PARENT", Color(hex: "2B8A3E"), Color(hex: "B4FF3C").opacity(0.22))
            case .member: return ("MEMBER", YGColors.ink.opacity(0.55), YGColors.ink.opacity(0.06))
            }
        }()
        return pill(label: label, fg: color, bg: bg)
    }

    /// Single horizontal strip that renders the role pill (when present)
    /// plus the PARENT + grade side-pills. The orange PARENT pill is
    /// suppressed when the role pill is already "PARENT" so parent-role
    /// rows don't render the same label twice.
    @ViewBuilder
    private func memberPills(role: MemberRole?, gradeYear: Int?, isParent: Bool) -> some View {
        HStack(spacing: 6) {
            if let role {
                rolePill(role: role)
            }
            if isParent && role != .parent {
                pill(
                    label: "PARENT",
                    fg: Color(hex: "FF6B35"),
                    bg: Color(hex: "FF6B35").opacity(0.12)
                )
            }
            if let g = gradeYear {
                pill(
                    label: "\(g)\(g.ordinalSuffix) grade",
                    fg: Color(hex: "2B8A3E"),
                    bg: Color(hex: "2B8A3E").opacity(0.10)
                )
            }
        }
    }

    private func pill(label: String, fg: Color, bg: Color) -> some View {
        Text(label)
            .font(.system(size: 9, weight: .heavy))
            .tracking(0.4)
            .foregroundStyle(fg)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Small groups

    private var smallGroupsList: some View {
        ScrollView {
            VStack(spacing: 8) {
                // "+ New small group" affordance sits above the list so
                // it stays in reach even when the list grows.
                if service.activeGroupId != nil {
                    HStack {
                        Spacer()
                        Button {
                            showCreateSmallGroup = true
                        } label: {
                            Label("New small group", systemImage: "plus.circle.fill")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundStyle(YGColors.violet)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(YGColors.violet.opacity(0.10))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 4)
                }

                if service.smallGroups.isEmpty {
                    emptyState(emoji: "🧑‍🤝‍🧑",
                               title: "No small groups",
                               message: "Small groups help organize members into more intimate communities.")
                } else {
                    ForEach(service.smallGroups) { sg in
                        if let gid = service.activeGroupId {
                            NavigationLink {
                                PastorSmallGroupDetailView(youthGroupId: gid, smallGroup: sg)
                            } label: {
                                smallGroupRow(sg)
                            }
                            .buttonStyle(.plain)
                        } else {
                            smallGroupRow(sg)
                        }
                    }
                }
            }
            .padding(16)
        }
        .refreshable { await service.loadSmallGroups() }
        .sheet(isPresented: $showCreateSmallGroup) {
            if let gid = service.activeGroupId {
                CreateSmallGroupSheet(youthGroupId: gid) {
                    Task { await service.loadSmallGroups() }
                }
            }
        }
    }

    private func smallGroupRow(_ sg: PastorSmallGroup) -> some View {
        HStack(spacing: 12) {
            Text(String(sg.name.prefix(1)).uppercased())
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(LinearGradient(colors: [YGColors.violet, Color(hex: "FF3DA5")],
                                           startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(sg.name)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(YGColors.ink)
                    .lineLimit(1)
                Text("\(sg.memberCount) member\(sg.memberCount == 1 ? "" : "s")"
                     + (sg.leaderNames.isEmpty ? "" : " · led by \(sg.leaderNames.joined(separator: ", "))"))
                    .font(.system(size: 11.5))
                    .foregroundStyle(YGColors.ink.opacity(0.55))
                    .lineLimit(2)
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

    // MARK: - Avatar / helpers

    private func avatar(name: String?, gradient: LinearGradient) -> some View {
        Text(String((name?.first).map(String.init) ?? "?").uppercased())
            .font(.system(size: 13, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .background(gradient)
            .clipShape(Circle())
    }

    private func requestAvatarGradient(_ req: JoinRequest) -> LinearGradient {
        let seed = req.userId.uuidString.hashValue
        return gradient(for: seed)
    }

    private func memberAvatarGradient(_ m: PastorMember) -> LinearGradient {
        let seed = m.userId.uuidString.hashValue
        return gradient(for: seed)
    }

    private func gradient(for seed: Int) -> LinearGradient {
        let hue1 = Double(abs(seed) % 360) / 360
        let hue2 = Double(abs(seed) % 307 * 53 % 360) / 360
        return LinearGradient(
            colors: [
                Color(hue: hue1, saturation: 0.75, brightness: 0.65),
                Color(hue: hue2, saturation: 0.75, brightness: 0.55),
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private func emptyState(emoji: String, title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Text(emoji).font(.system(size: 40))
            Text(title)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(YGColors.ink)
            Text(message)
                .font(.system(size: 12.5))
                .foregroundStyle(YGColors.ink.opacity(0.55))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Loading

    private func loadFor(_ tab: Tab) async {
        switch tab {
        case .requests:    await service.loadJoinRequests()
        case .all:         await service.loadAllMembers()
        case .leaders:     await service.loadLeaders()
        case .smallGroups: await service.loadSmallGroups()
        }
    }

    private static let relativeDate: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
}

// `Int.ordinalSuffix` is defined once at module scope in
// PastorGroupManagementView.swift and reused here + in the member
// detail sheet.
