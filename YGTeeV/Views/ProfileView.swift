//
//  ProfileView.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/6/26.
//

import SwiftUI

struct ProfileView: View {
    /// Held via `@State` so SwiftUI registers an observation on the
    /// `@Observable` singleton — without this, reading
    /// `SupabaseManager.shared.currentUser?.lifetimeXP` directly in
    /// the body wouldn't re-render the level bar when XP changes.
    @State private var supabaseManager = SupabaseManager.shared

    @State private var showManageGroups = false
    @State private var showJoinGroupMap = false
    @State private var showPastorManagement = false
    /// Which group the dashboard overlay should open. Nil falls back to the
    /// pastor service's active group.
    @State private var pastorDashboardGroupId: UUID?
    /// Set when a leader card is tapped so we can present the small-group
    /// detail sheet for the right group. One state field replaces the
    /// per-card `@State` we used to keep inside `MySmallGroupCard`.
    @State private var selectedLeaderGroup: LeaderSmallGroup?
    /// Tapped row from one of the My Events carousels. Drives the
    /// detail sheet via `.sheet(item:)`. `selectedReadOnly` decides
    /// whether the sheet renders the RSVP picker.
    @State private var selectedEvent: MyEvent?
    @State private var selectedReadOnly: Bool = false
    @State private var showSettings = false
    @State private var showProfileQR = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var appearanceManager = AppearanceManager.shared

    // Real, observable sources of truth. Each `@State private var =
    // ...shared` makes SwiftUI subscribe to mutations on the singleton,
    // so any service-side change re-renders the relevant section.
    @State private var pastorService = PastorDashboardService.shared
    @State private var leaderService = LeaderService.shared
    @State private var familyService = FamilyService.shared
    @State private var eventsService = EventsService.shared
    
    private var nonDefaultMemberships: [MyGroupMembership] {
        eventsService.myMemberships.filter { !$0.isDefaultYgteev }
    }

    /// True when the signed-in user pastors at least one group. Used to
    /// decide whether SettingsSheetView surfaces the extended profile
    /// editor + the Stripe billing portal row.
    private var isPastorAccount: Bool {
        !pastorService.myGroups.isEmpty
    }

    /// Leader + pastor accounts get the extended profile editor (avatar,
    /// bio); plain members + parents get a name-only edit.
    private var allowExtendedProfileFields: Bool {
        isPastorAccount || !leaderService.myLeaderGroups.isEmpty
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    ProfileHeaderView(
                        displayName: supabaseManager.currentUser?.displayName ?? "Member",
                        handle: supabaseManager.currentUser?.handle,
                        avatarUrl: supabaseManager.currentUser?.avatarUrl,
                        bio: supabaseManager.currentUser?.bio,
                        onSettingsTap: { showSettings = true }
                    )

                    LevelBarCard(lifetimeXP: supabaseManager.currentUser?.lifetimeXP ?? 0)

                    VStack(spacing: 18) {
                        // Pending family-invite banner — surfaces on the
                        // invited user's profile as soon as a parent fires
                        // `create_family_invite` against their user_id.
                        PendingInviteBanner()

                        // My Ministry — one card per group the user pastors.
                        if !pastorService.myGroups.isEmpty {
                            sectionHeader(
                                pastorService.myGroups.count > 1 ? "My Ministry" : "My Ministry"
                            )
                            ForEach(pastorService.myGroups) { group in
                                MyMinistryCard(group: group) {
                                    pastorDashboardGroupId = group.id
                                    pastorService.activeGroupId = group.id
                                    showPastorManagement = true
                                }
                            }
                        }

                        // My Small Group — one card per small group the
                        // user leads.
                        if !leaderService.myLeaderGroups.isEmpty {
                            sectionHeader(
                                leaderService.myLeaderGroups.count > 1
                                    ? "My Small Groups"
                                    : "My Small Group"
                            )
                            ForEach(leaderService.myLeaderGroups) { group in
                                MySmallGroupCard(group: group) {
                                    selectedLeaderGroup = group
                                }
                            }
                        }

                        // My Family — hidden when the user isn't in a family.
                        if familyService.hasFamily {
                            sectionHeader("My Family")
                            LiveFamilyCard()
                        }

                        // My Youth Groups — always shown. Default YGTeeV
                        // is filtered out (auto-joined catch-all).
                        GroupsRowCard(
                            pastorGroups: [],
                            memberGroups: nonDefaultMemberships,
                            onGroupTap: { _ in },
                            onPastorGroupTap: { groupId in
                                pastorDashboardGroupId = groupId
                                pastorService.activeGroupId = groupId
                                showPastorManagement = true
                            },
                            onMemberGroupTap: { groupId in
                                // Pastor-owned groups also surface here
                                // (their `youth_group_members` role is
                                // "pastor"). Tap routes into the dashboard.
                                if eventsService.myMemberships
                                    .first(where: { $0.groupId == groupId })?
                                    .role.lowercased() == "pastor" {
                                    pastorDashboardGroupId = groupId
                                    pastorService.activeGroupId = groupId
                                    showPastorManagement = true
                                }
                                // else: TODO route to member-side group home
                            },
                            onManageTap: { showManageGroups = true },
                            onFindGroupTap: { showJoinGroupMap = true }
                        )

                        // My Events / past + per-child carousels.
                        // Bundle is populated by `loadMyEventCarousels`
                        // in the task below; while it's nil we just
                        // don't render the section.
                        if let bundle = eventsService.myCarousels {
                            myEventCarousels(bundle: bundle)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 100)
                }
            }
            .background(ThemeColors.background(isDark: appearanceManager.isDarkMode))
            .ignoresSafeArea(edges: .top)

            // Pastor management overlay — slides in from trailing, hosts
            // the live Supabase-backed dashboard for the active group.
            if showPastorManagement, let groupId = pastorDashboardGroupId
                                                    ?? pastorService.activeGroupId
                                                    ?? pastorService.myGroups.first?.id {
                NavigationStack {
                    PastorDashboardView(initialGroupId: groupId) {
                        showPastorManagement = false
                    }
                }
                .transition(.move(edge: .trailing))
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showPastorManagement)
        .task {
            // Hydrate every data source the layout depends on, in parallel.
            // Each service is observable, so the corresponding section
            // renders the moment its array populates.
            async let a: Void = pastorService.loadMyGroups()
            async let b: Void = leaderService.loadMyLeaderGroups()
            async let c: Void = familyService.loadMyFamilies()
            async let d: Void = familyService.loadPendingInvites()
            // Memberships is the only one we soft-load — it's already
            // cached elsewhere in the app, so don't refetch if it's hot.
            async let e: Void = loadMembershipsIfNeeded()
            // My Events + per-child carousels.
            async let f: Void = eventsService.loadMyEventCarousels()
            _ = await (a, b, c, d, e, f)
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Re-poll pending invites when the user returns to the app,
            // so a parent's recent scan surfaces without a manual refresh.
            if newPhase == .active {
                Task { await familyService.loadPendingInvites() }
            }
        }
        .sheet(isPresented: $showManageGroups) {
            ManageGroupsSheet()
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheetView(
                isPastor: isPastorAccount,
                allowExtendedProfileFields: allowExtendedProfileFields
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedLeaderGroup) { group in
            LeaderGroupDetailView(group: group)
        }
        .sheet(item: $selectedEvent) { ev in
            MyEventDetailSheet(
                event:    ev,
                readOnly: selectedReadOnly
            ) { status in
                try await eventsService.updateMyRSVP(ev.eventId, status: status)
            }
        }
        .fullScreenCover(isPresented: $showJoinGroupMap) {
            JoinGroupMapView()
        }
    }

    // MARK: - My Events carousels

    @ViewBuilder
    private func myEventCarousels(bundle: MyEventCarousels) -> some View {
        // The viewer's own upcoming + past.
        eventCarouselSection(
            title:           "My Events",
            events:          bundle.me.upcoming,
            showAddTile:     true,
            readOnly:        false,
            showEmptyBanner: bundle.me.upcoming.isEmpty
        )
        if !bundle.me.past.isEmpty {
            eventCarouselSection(
                title:           "My Past Events",
                events:          bundle.me.past,
                showAddTile:     false,
                readOnly:        true,
                showEmptyBanner: false
            )
        }

        // Per-child mirrors. Always read-only — the parent can browse
        // but not change the kid's RSVPs from this surface.
        ForEach(bundle.children, id: \.userId) { kid in
            eventCarouselSection(
                title:           "\(kid.displayName)'s Events",
                events:          kid.upcoming,
                showAddTile:     true,
                readOnly:        true,
                showEmptyBanner: kid.upcoming.isEmpty
            )
            if !kid.past.isEmpty {
                eventCarouselSection(
                    title:           "\(kid.displayName)'s Past Events",
                    events:          kid.past,
                    showAddTile:     false,
                    readOnly:        true,
                    showEmptyBanner: false
                )
            }
        }
    }

    @ViewBuilder
    private func eventCarouselSection(
        title: String,
        events: [MyEvent],
        showAddTile: Bool,
        readOnly: Bool,
        showEmptyBanner: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title)

            if showEmptyBanner {
                FindAnEventCard(style: .banner) {
                    showJoinGroupMap = true
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(events) { ev in
                            MyEventCard(event: ev) {
                                selectedEvent    = ev
                                selectedReadOnly = readOnly
                            }
                        }
                        if showAddTile {
                            FindAnEventCard(style: .tile) {
                                showJoinGroupMap = true
                            }
                        }
                    }
                }
            }
        }
        .padding(.top, 12)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.lilitaOne(size: 16))
                .tracking(-0.3)
                .foregroundStyle(YGColors.ink)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private func loadMembershipsIfNeeded() async {
        if eventsService.myMemberships.isEmpty {
            try? await eventsService.loadMyMemberships()
        }
    }
}

// MARK: - Profile Header
//
// Renders the hero gradient + avatar + display name + handle. All real
// values come from the call site — this view doesn't reach into any
// singleton — so the previews/tests can drive it with sample strings.
struct ProfileHeaderView: View {
    let displayName: String
    let handle: String?
    let avatarUrl: String?
    let bio: String?
    let onSettingsTap: () -> Void

    @State private var appearanceManager = AppearanceManager.shared

    /// Single muted gradient palette. We dropped the per-role colorways
    /// when the role-switcher came out, so every account now renders
    /// the same brand violet → pink → cyan band.
    private static let heroGradient: [Color] = [
        Color(hex: "FF3DA5"),
        Color(hex: "6B2BFF"),
        Color(hex: "00E0FF")
    ]

    private var headerHandle: String? {
        guard let h = handle, !h.isEmpty else { return nil }
        return "@\(h)"
    }

    private var initial: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.first.map(String.init) ?? "?").uppercased()
    }

    @ViewBuilder
    private var avatarInner: some View {
        if let urlString = avatarUrl,
           !urlString.isEmpty,
           let url = URL(string: urlString) {
            CachedRemoteImage(url: url) {
                initialFallback
            }
        } else {
            initialFallback
        }
    }

    private var initialFallback: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Self.heroGradient[0].opacity(0.95),
                             Self.heroGradient[0].opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Text(initial)
                    .font(.lilitaOne(size: 36))
                    .foregroundStyle(.white)
            }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ZStack {
                LinearGradient(
                    colors: Self.heroGradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                GeometryReader { geo in
                    Circle()
                        .fill(.white.opacity(0.18))
                        .frame(width: 260, height: 260)
                        .offset(x: geo.size.width - 50, y: -80)
                }

                VStack {
                    HStack {
                        Spacer()
                        Button(action: onSettingsTap) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(.white.opacity(0.22))
                                .clipShape(Circle())
                                .overlay {
                                    Circle()
                                        .strokeBorder(.white.opacity(0.4), lineWidth: 0.5)
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 60)
                    Spacer()
                }
            }
            .frame(height: 140)

            HStack(alignment: .bottom, spacing: 14) {
                Circle()
                    .fill(.white)
                    .frame(width: 94, height: 94)
                    .overlay {
                        avatarInner
                            .frame(width: 86, height: 86)
                            .clipShape(Circle())
                    }

                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayName)
                            .font(.lilitaOne(size: 22))
                            .tracking(-0.6)
                            .foregroundStyle(appearanceManager.isDarkMode ? .white : YGColors.ink)

                        if let headerHandle {
                            Text(headerHandle)
                                .font(.system(size: 12.5))
                                .foregroundStyle(appearanceManager.isDarkMode ? .white.opacity(0.7) : YGColors.ink.opacity(0.6))
                        }
                    }

                    if let bio, !bio.isEmpty {
                        Text(bio)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(3)
                            .padding(.top, 6)
                    }
                }
                .padding(.bottom, 8)

                Spacer()
            }
            .padding(.leading, 18)
            .padding(.trailing, 18)
            .offset(y: 50)
        }
        .frame(height: 140)
    }
}

// MARK: - Level Bar Card
//
// Derives level + progress from `lifetime_xp` via the shared
// `LevelSystem` helper. Formula is universal (no per-role tier cap);
// any user's lifetime XP maps to a unique level the same way.
struct LevelBarCard: View {
    /// Driven by `SupabaseManager.shared.currentUser?.lifetimeXP`. The
    /// only thing that decides which Level and how full the bar is.
    let lifetimeXP: Int64

    private var snap: LevelSystem.Progress {
        LevelSystem.progress(for: lifetimeXP)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Level \(snap.level)")
                    .font(.lilitaOne(size: 16))
                    .tracking(-0.3)
                    .foregroundStyle(YGColors.ink)

                Spacer()

                // Show the in-level ratio (matches the visual bar) —
                // e.g. "1,130 / 4,000 XP" at Level 7 means 1,130 of the
                // 4,000 needed to reach Level 8 are banked.
                Text("\(snap.xpIntoLevel.formatted()) / \(snap.levelSpan.formatted()) XP")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(YGColors.ink.opacity(0.55))
                    .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(hex: "F0EDF8"))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "6B2BFF"), Color(hex: "FF3DA5"), Color(hex: "FFD60A")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * min(max(snap.fraction, 0), 1))
                }
            }
            .frame(height: 10)

            Text("\(snap.xpToNext.formatted()) XP to **Level \(snap.level + 1)**")
                .font(.system(size: 11.5))
                .foregroundStyle(YGColors.ink.opacity(0.5))
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.black.opacity(0.04), lineWidth: 0.5)
        }
        .shadow(color: YGColors.ink.opacity(0.04), radius: 8, y: 2)
        .padding(.horizontal, 16)
        .padding(.top, 62)
    }
}

// MARK: - My Ministry Card
//
// One card per group the user pastors. Compact by design (so a pastor
// of multiple groups can stack three or four cards without scrolling
// off the screen) — the heavy stats live inside the dashboard the tap
// opens. Member count comes from the row itself, no per-card RPC.
struct MyMinistryCard: View {
    let group: PastorGroup
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "6B2BFF"), Color(hex: "3D0FB8"), Color(hex: "FF3DA5")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                GeometryReader { geo in
                    Circle()
                        .fill(.white.opacity(0.12))
                        .frame(width: 160, height: 160)
                        .offset(x: geo.size.width - 110, y: -40)
                }

                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PASTOR DASHBOARD")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(.white.opacity(0.85))
                        Text(group.name)
                            .font(.lilitaOne(size: 22))
                            .tracking(-0.5)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                    }

                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                            Text("\(group.memberCount) member\(group.memberCount == 1 ? "" : "s")")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            Text("Manage")
                                .font(.lilitaOne(size: 12.5))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(.white)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.black.opacity(0.04), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
    }
}


// MARK: - My Small Group Card (Leader)
//
// One card per small group the user leads. The owning ProfileView
// supplies the section header and the sheet routing — this view just
// renders a single group's card. Member roster comes from
// `LeaderService.membersByGroup[group.id]`; we kick off the load via
// `.task(id: group.id)` so the count + initials populate without the
// owner having to wire it.
struct MySmallGroupCard: View {
    let group: LeaderSmallGroup
    let onTap: () -> Void

    @State private var leaderService = LeaderService.shared

    private var members: [SmallGroupMemberRow] {
        leaderService.membersByGroup[group.id] ?? []
    }
    private var studentMembers: [SmallGroupMemberRow] {
        members.filter { $0.role == "member" }
    }
    private var memberCount: Int { studentMembers.count }

    private var initials: String {
        group.name.split(separator: " ").prefix(2)
            .map { String($0.prefix(1)) }.joined().uppercased()
    }

    private var subtitleText: String {
        var parts: [String] = ["\(memberCount) student\(memberCount == 1 ? "" : "s")"]
        if let day = group.meetingDay, !day.isEmpty {
            var meets = "meets \(day)"
            if let time = group.meetingTime, !time.isEmpty {
                meets += " \(time)"
            }
            parts.append(meets)
        }
        return parts.joined(separator: " · ")
    }

    private var nextMeetText: String {
        let day = group.meetingDay?.prefix(3).capitalized ?? "—"
        let time = group.meetingTime ?? ""
        return time.isEmpty ? String(day) : "\(day) \(time)"
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    // Youth-group logo if available; falls back to the cyan-blue
                    // gradient + initials block when the parent group has no logo.
                    GroupAvatar(logoUrl: group.youthGroupLogoUrl, size: 46, cornerRadius: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "00E0FF"), Color(hex: "0066FF")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(
                                            LinearGradient(
                                                colors: [.white.opacity(0.3), .clear, .black.opacity(0.18)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                }

                            Text(initials)
                                .font(.lilitaOne(size: 16))
                                .tracking(-0.5)
                                .foregroundStyle(.white)
                        }
                        .frame(width: 46, height: 46)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.name)
                            .font(.lilitaOne(size: 14.5))
                            .tracking(-0.2)
                            .foregroundStyle(YGColors.ink)
                            .lineLimit(1)

                        Text(subtitleText)
                            .font(.system(size: 11.5))
                            .foregroundStyle(YGColors.ink.opacity(0.55))
                            .lineLimit(1)
                    }

                    Spacer()

                    Text("View")
                        .font(.lilitaOne(size: 11.5))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(YGColors.ink)
                        .clipShape(Capsule())
                }

                HStack(spacing: 8) {
                    statTile(value: "\(memberCount)", label: "Students")
                    statTile(value: "—", label: "Plans done")
                    statTile(value: nextMeetText, label: "Next meet")
                }

                if !studentMembers.isEmpty {
                    HStack(spacing: 8) {
                        HStack(spacing: -8) {
                            ForEach(studentMembers.prefix(5)) { m in
                                Circle()
                                    .fill(Color(hex: "00E0FF").opacity(0.2))
                                    .frame(width: 26, height: 26)
                                    .overlay {
                                        Text(memberInitial(m))
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(Color(hex: "0066FF"))
                                    }
                                    .overlay {
                                        Circle()
                                            .strokeBorder(.white, lineWidth: 1.5)
                                    }
                            }
                        }

                        if memberCount > 5 {
                            Text("+\(memberCount - 5) more")
                                .font(.system(size: 12))
                                .foregroundStyle(YGColors.ink.opacity(0.6))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(YGColors.ink.opacity(0.2))
                    }
                    .padding(.top, 2)
                }
            }
            .padding(14)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.black.opacity(0.04), lineWidth: 0.5)
            }
            .shadow(color: YGColors.ink.opacity(0.04), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
        // Pull the member roster for this group on first appearance so
        // the count + initial avatars populate. Keyed off `group.id` so
        // SwiftUI re-fires if a different group's instance is recycled
        // into this slot.
        .task(id: group.id) {
            await leaderService.loadMembers(smallGroupId: group.id)
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.lilitaOne(size: 15))
                .tracking(-0.4)
                .foregroundStyle(YGColors.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(label)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(YGColors.ink.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(hex: "FAF8FF"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func memberInitial(_ m: SmallGroupMemberRow) -> String {
        let source = m.displayName ?? m.email ?? "?"
        return String(source.first ?? "?").uppercased()
    }
}

// MARK: - Leader Actions Row
struct LeaderActionsRow: View {
    let actions: [(emoji: String, label: String)] = [
        ("📣", "Post to SG"),
        ("📅", "Plan a meet"),
        ("✅", "Take roll"),
        ("📖", "Assign plan")
    ]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(actions, id: \.emoji) { action in
                VStack(spacing: 6) {
                    Text(action.emoji)
                        .font(.system(size: 22))
                    
                    Text(action.label)
                        .font(.lilitaOne(size: 10.5))
                        .tracking(-0.1)
                        .foregroundStyle(YGColors.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 6)
                .padding(.vertical, 12)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.black.opacity(0.04), lineWidth: 0.5)
                }
                .shadow(color: YGColors.ink.opacity(0.04), radius: 8, y: 2)
            }
        }
    }
}

// MARK: - Groups Row Card
struct GroupsRowCard: View {
    /// When the caller is acting as a pastor, supply the real groups
    /// fetched via `pastor_my_groups()`. Empty array → falls through to
    /// `memberGroups` or the legacy sample cards.
    var pastorGroups: [PastorGroup] = []
    /// All youth groups the signed-in user is a member of (via
    /// `EventsService.loadMyMemberships()`). Used for non-pastor roles.
    var memberGroups: [MyGroupMembership] = []
    let onGroupTap: (String) -> Void
    var onPastorGroupTap: ((UUID) -> Void)? = nil
    var onMemberGroupTap: ((UUID) -> Void)? = nil
    let onManageTap: () -> Void
    let onFindGroupTap: () -> Void

    private static let cardGradients: [[Color]] = [
        [Color(hex: "6B2BFF"), Color(hex: "FF3DA5")],
        [Color(hex: "00E0FF"), Color(hex: "0066FF")],
        [Color(hex: "FF6B35"), Color(hex: "FFD60A")],
        [Color(hex: "B4FF3C"), Color(hex: "2B8A3E")],
        [Color(hex: "FFD60A"), Color(hex: "FF3DA5")],
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("My Youth Groups")
                    .font(.lilitaOne(size: 16))
                    .tracking(-0.3)
                    .foregroundStyle(YGColors.ink)

                Spacer()

                Button {
                    onManageTap()
                } label: {
                    Text("Manage")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(Color(hex: "6B2BFF"))
                }
            }
            .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if !pastorGroups.isEmpty {
                        ForEach(Array(pastorGroups.enumerated()), id: \.element.id) { index, group in
                            Button {
                                onPastorGroupTap?(group.id)
                            } label: {
                                GroupCardItem(
                                    name: group.name,
                                    shortName: Self.initials(group.name),
                                    subtitle: "Pastor · \(group.memberCount)",
                                    gradient: Self.cardGradients[index % Self.cardGradients.count]
                                )
                            }
                        }
                    } else if !memberGroups.isEmpty {
                        ForEach(Array(memberGroups.enumerated()), id: \.element.id) { index, group in
                            Button {
                                onMemberGroupTap?(group.groupId)
                            } label: {
                                GroupCardItem(
                                    name: group.name,
                                    shortName: Self.initials(group.name),
                                    subtitle: Self.memberSubtitle(role: group.role),
                                    gradient: Self.memberGradient(
                                        from: group.gradientFrom,
                                        to:   group.gradientTo,
                                        fallbackIdx: index
                                    )
                                )
                            }
                        }
                    }
                    // When the user has no real pastor / member groups
                    // yet, the row collapses to just the "Find a group"
                    // tile below — no fake "Grace City" / "Ridge Valley"
                    // placeholders.

                    // Add group card
                    Button {
                        onFindGroupTap()
                    } label: {
                        VStack(alignment: .leading, spacing: 9) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color(hex: "6B2BFF").opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                                    .frame(width: 44, height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.white)
                                    )
                                
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(Color(hex: "6B2BFF"))
                            }
                            
                            Text("Find a group")
                                .font(.lilitaOne(size: 13))
                                .tracking(-0.2)
                                .foregroundStyle(Color(hex: "6B2BFF"))
                            
                            Text("Map · QR · invite")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(Color(hex: "6B2BFF").opacity(0.7))
                        }
                        .frame(width: 124)
                        .padding(12)
                        .background(Color(hex: "6B2BFF").opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color(hex: "6B2BFF").opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
            }
        }
    }

    private static func initials(_ name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        let chars = parts.compactMap { $0.first }
        return chars.isEmpty ? "?" : String(chars).uppercased()
    }

    /// Subtitle for member-group cards. Pastors/leaders surface their role
    /// explicitly; everyone else just sees "Member".
    private static func memberSubtitle(role: String) -> String {
        switch role.lowercased() {
        case "pastor": return "Pastor"
        case "leader": return "Leader"
        case "parent": return "Parent"
        default:       return "Member"
        }
    }

    /// Use the group's own gradient when present; otherwise rotate through
    /// the same palette used for pastor cards so adjacent cards don't all
    /// blur into a single color.
    private static func memberGradient(from: String?, to: String?, fallbackIdx: Int) -> [Color] {
        if let from, let to {
            return [Color(hex: from), Color(hex: to)]
        }
        return cardGradients[fallbackIdx % cardGradients.count]
    }
}

struct GroupCardItem: View {
    let name: String
    let shortName: String
    let subtitle: String
    let gradient: [Color]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .clear, .black.opacity(0.18)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                
                Text(shortName)
                    .font(.lilitaOne(size: 18))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)
            
            Text(name)
                .font(.lilitaOne(size: 13))
                .tracking(-0.2)
                .foregroundStyle(YGColors.ink)
                .lineLimit(2)
            
            Text(subtitle)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(YGColors.ink.opacity(0.5))
        }
        .frame(width: 124, alignment: .leading)
        .padding(12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.black.opacity(0.05), lineWidth: 0.5)
        }
        .shadow(color: YGColors.ink.opacity(0.04), radius: 8, y: 2)
    }
}

// MARK: - Manage Groups Sheet
struct ManageGroupsSheet: View {
    @Environment(\.dismiss) var dismiss

    @State private var eventsService = EventsService.shared
    @State private var pendingLeave: MyGroupMembership?
    @State private var isLeaving = false
    @State private var leaveError: String?

    /// Default YGTeeV is the auto-joined catch-all and can't be left from
    /// this surface — surface only the real church groups.
    private var manageableGroups: [MyGroupMembership] {
        eventsService.myMemberships.filter { !$0.isDefaultYgteev }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("My Groups")
                        .font(.lilitaOne(size: 24))
                        .tracking(-0.6)
                        .foregroundStyle(YGColors.ink)

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(YGColors.ink.opacity(0.5))
                            .frame(width: 32, height: 32)
                            .background(YGColors.paper)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                ScrollView {
                    VStack(spacing: 12) {
                        if manageableGroups.isEmpty {
                            VStack(spacing: 8) {
                                Text("🏠").font(.system(size: 36))
                                Text("No youth groups yet")
                                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                                    .foregroundStyle(YGColors.ink)
                                Text("Find your church's youth group from the Plans tab to join.")
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(YGColors.ink.opacity(0.55))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 30)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            ForEach(manageableGroups) { group in
                                ManageGroupRow(group: group) {
                                    pendingLeave = group
                                }
                            }
                        }

                        if let leaveError {
                            Text(leaveError)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.red)
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .background(YGColors.paper)
        }
        .task {
            // Refresh memberships when the sheet opens so leaves elsewhere
            // are reflected and the list is never stale.
            try? await eventsService.loadMyMemberships()
        }
        .confirmationDialog(
            "Leave this group?",
            isPresented: Binding(
                get: { pendingLeave != nil },
                set: { if !$0 { pendingLeave = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingLeave
        ) { group in
            Button("Leave \(group.name)", role: .destructive) {
                Task { await leave(group: group) }
            }
            Button("Cancel", role: .cancel) {
                pendingLeave = nil
            }
        } message: { group in
            Text("You'll stop receiving messages and updates from \(group.name). You can request to rejoin later.")
        }
    }

    private func leave(group: MyGroupMembership) async {
        guard !isLeaving else { return }
        isLeaving = true
        leaveError = nil
        defer { isLeaving = false }
        do {
            try await YouthGroupService.shared.leaveYouthGroup(groupId: group.groupId)
            // Refresh the source-of-truth list so the row disappears.
            try? await eventsService.loadMyMemberships()
            // Entitlements may flip (Pro vs Free) when leaving a real group.
            await EntitlementsService.shared.refreshAfterYouthGroupChange()
            pendingLeave = nil
        } catch {
            // Defense-in-depth: the UI hides "Leave" for pastors, but if
            // any future path slips past that gate, translate the
            // trigger's raw Postgres message into something a user can act
            // on.
            let raw = error.localizedDescription
            if raw.contains("pastor_cannot_leave_own_group") {
                leaveError = "You're the pastor of this group. Transfer ownership before leaving."
            } else {
                leaveError = "Couldn't leave: \(raw)"
            }
        }
    }
}

struct ManageGroupRow: View {
    let group: MyGroupMembership
    let onLeave: () -> Void

    /// Pastors own the group — the backend's `pastor_cannot_leave_own_group`
    /// trigger would reject a self-leave anyway, so we hide the button
    /// entirely and show an "Owner" badge instead.
    private var isPastor: Bool {
        group.role.lowercased() == "pastor"
    }

    private var shortName: String {
        let parts = group.name.split(separator: " ").prefix(2)
        let chars = parts.compactMap { $0.first }
        return chars.isEmpty ? "?" : String(chars).uppercased()
    }

    private var gradient: [Color] {
        if let from = group.gradientFrom, let to = group.gradientTo {
            return [Color(hex: from), Color(hex: to)]
        }
        return [Color(hex: "6B2BFF"), Color(hex: "FF3DA5")]
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .clear, .black.opacity(0.18)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }

                Text(shortName)
                    .font(.lilitaOne(size: 16))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.lilitaOne(size: 16))
                    .tracking(-0.2)
                    .foregroundStyle(YGColors.ink)
                Text(roleLabel(group.role))
                    .font(.system(size: 11.5))
                    .foregroundStyle(YGColors.ink.opacity(0.55))
            }

            Spacer()

            if isPastor {
                Text("Owner")
                    .font(.system(size: 11.5, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(YGColors.violet)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(YGColors.violet.opacity(0.1))
                    .clipShape(Capsule())
            } else {
                Button(action: onLeave) {
                    Text("Leave")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(hex: "EF4444"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(hex: "EF4444").opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.black.opacity(0.04), lineWidth: 0.5)
        }
        .shadow(color: YGColors.ink.opacity(0.04), radius: 8, y: 2)
    }

    private func roleLabel(_ role: String) -> String {
        switch role.lowercased() {
        case "pastor": return "Pastor"
        case "leader": return "Leader"
        case "parent": return "Parent"
        default:       return "Member"
        }
    }
}

// MARK: - Leader Group Detail View
struct LeaderGroupDetailView: View {
    let group: LeaderSmallGroup

    @Environment(\.dismiss) private var dismiss
    @State private var leaderService = LeaderService.shared

    enum Tab: String, CaseIterable, Hashable {
        case members = "Members"
        case attendance = "Attendance"
        case edit = "Edit"
    }
    @State private var tab: Tab = .members

    // Edit-tab state. Seeded from `group` on appear via the init.
    @State private var editName: String
    @State private var editDescription: String
    @State private var editMeetingDay: String
    @State private var editMeetingTime: String
    @State private var isSavingEdits = false
    @State private var editSaveError: String?

    // Take-roll sheet state
    @State private var showNewRollSheet = false
    @State private var editingEvent: AttendanceEvent?

    private let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    init(group: LeaderSmallGroup) {
        self.group = group
        self._editName        = State(initialValue: group.name)
        self._editDescription = State(initialValue: group.description ?? "")
        self._editMeetingDay  = State(initialValue: group.meetingDay ?? "Tuesday")
        self._editMeetingTime = State(initialValue: group.meetingTime ?? "")
    }

    private var members: [SmallGroupMemberRow] {
        leaderService.membersByGroup[group.id] ?? []
    }
    private var events: [AttendanceEventSummary] {
        leaderService.eventsByGroup[group.id] ?? []
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabBar

                Group {
                    switch tab {
                    case .members:    membersTab
                    case .attendance: attendanceTab
                    case .edit:       editTab
                    }
                }
            }
            .background(YGColors.paper)
            .navigationTitle(group.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(YGColors.ink)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if tab == .edit {
                        Button { Task { await saveEdits() } } label: {
                            if isSavingEdits { ProgressView() }
                            else { Text("Save").bold() }
                        }
                        .disabled(isSavingEdits || editName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .foregroundStyle(Color(hex: "0066FF"))
                    }
                }
            }
        }
        .task {
            if leaderService.membersByGroup[group.id] == nil {
                await leaderService.loadMembers(smallGroupId: group.id)
            }
            if leaderService.eventsByGroup[group.id] == nil {
                await leaderService.loadAttendanceHistory(smallGroupId: group.id)
            }
        }
        .sheet(isPresented: $showNewRollSheet) {
            TakeRollSheet(group: group)
        }
        .sheet(item: $editingEvent) { event in
            TakeRollSheet(group: group, existingEvent: event)
        }
        .alert("Couldn't save",
               isPresented: Binding(get: { editSaveError != nil },
                                    set: { if !$0 { editSaveError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(editSaveError ?? "")
        }
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { t in
                Button { tab = t } label: {
                    Text(t.rawValue)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(tab == t ? YGColors.ink : YGColors.ink.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            VStack(spacing: 0) {
                                Spacer()
                                Rectangle()
                                    .fill(tab == t ? Color(hex: "0066FF") : .clear)
                                    .frame(height: 2)
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .background(.white)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.5)
        }
    }

    // MARK: - Members tab

    private var membersTab: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if members.isEmpty {
                    Text("No members yet.")
                        .font(.system(size: 13))
                        .foregroundStyle(YGColors.ink.opacity(0.55))
                        .padding(.top, 40)
                } else {
                    ForEach(members) { m in
                        LeaderMemberRow(member: m)
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Attendance tab

    private var attendanceTab: some View {
        ScrollView {
            VStack(spacing: 14) {
                Button {
                    showNewRollSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text("Take roll")
                            .font(.system(size: 16, weight: .heavy))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(hex: "0066FF"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                if events.isEmpty {
                    Text("No attendance events yet.")
                        .font(.system(size: 13))
                        .foregroundStyle(YGColors.ink.opacity(0.55))
                        .padding(.top, 30)
                } else {
                    VStack(spacing: 10) {
                        ForEach(events) { ev in
                            Button {
                                // The summary view only exposes the fields the TakeRollSheet needs
                                // for edit mode (id, title, occurredAt). Fill the rest with placeholders
                                // — they aren't read by the sheet.
                                editingEvent = AttendanceEvent(
                                    id: ev.eventId,
                                    smallGroupId: ev.smallGroupId,
                                    title: ev.title,
                                    occurredAt: ev.occurredAt,
                                    notes: nil,
                                    createdBy: nil,
                                    createdAt: ev.occurredAt,
                                    updatedAt: ev.occurredAt
                                )
                            } label: {
                                AttendanceEventRow(summary: ev)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Edit tab

    private var editTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                fieldLabel("Group name")
                TextField("Group name", text: $editName)
                    .padding(14)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                    }

                fieldLabel("Description")
                TextEditor(text: $editDescription)
                    .frame(height: 100)
                    .padding(12)
                    .scrollContentBackground(.hidden)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                    }

                fieldLabel("Meeting day")
                Picker("Day", selection: $editMeetingDay) {
                    ForEach(days, id: \.self) { day in
                        Text(day).tag(day)
                    }
                }
                .pickerStyle(.menu)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                }

                fieldLabel("Meeting time")
                TextField("e.g., 7:00 PM", text: $editMeetingTime)
                    .padding(14)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                    }
            }
            .padding(20)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(YGColors.ink.opacity(0.6))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Save edits

    private func saveEdits() async {
        isSavingEdits = true
        defer { isSavingEdits = false }
        editSaveError = nil
        do {
            try await leaderService.updateSmallGroup(
                id: group.id,
                name: editName,
                description: editDescription.isEmpty ? nil : editDescription,
                meetingDay: editMeetingDay.isEmpty ? nil : editMeetingDay,
                meetingTime: editMeetingTime.isEmpty ? nil : editMeetingTime
            )
            // Refresh the leader's groups so the parent card picks up the new values.
            await leaderService.loadMyLeaderGroups()
            dismiss()
        } catch {
            editSaveError = "You don't have permission to edit this group."
        }
    }
}

// MARK: - Live member row (real Supabase data)

private struct LeaderMemberRow: View {
    let member: SmallGroupMemberRow

    private var displayName: String {
        member.displayName ?? member.email ?? "—"
    }

    private var subtitle: String? {
        if let bio = member.bio, !bio.isEmpty {
            return String(bio.prefix(60)) + (bio.count > 60 ? "…" : "")
        }
        return member.email
    }

    private var isRecentlyActive: Bool {
        guard let last = member.lastOpenedAt else { return false }
        return Date().timeIntervalSince(last) < 14 * 24 * 60 * 60
    }

    var body: some View {
        // Non-interactive row. Leader↔member 1:1 chat navigation is deferred —
        // we don't want the placeholder DM sheet opening on tap.
        HStack(spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(displayName)
                        .font(.system(size: 14.5, weight: .heavy))
                        .foregroundStyle(YGColors.ink)
                        .lineLimit(1)

                    if member.role != "member" {
                        Text(member.role.uppercased())
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(0.5)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(YGColors.violet)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(YGColors.ink.opacity(0.55))
                        .lineLimit(1)
                }
            }

            Spacer()

            if isRecentlyActive {
                Text("Active")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.green)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.white)
        .overlay(alignment: .bottom) {
            Divider().padding(.leading, 60).opacity(0.5)
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if let s = member.avatarUrl, !s.isEmpty, let url = URL(string: s) {
            AsyncImage(url: url) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                YGAvatar(name: displayName, size: 36)
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())
        } else {
            YGAvatar(name: displayName, size: 36)
        }
    }
}

// MARK: - Attendance event row (history)

private struct AttendanceEventRow: View {
    let summary: AttendanceEventSummary

    private var datePill: String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f.string(from: summary.occurredAt)
    }

    private var ratio: Double {
        guard summary.rosterTotal > 0 else { return 0 }
        return Double(summary.presentCount) / Double(summary.rosterTotal)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(datePill)
                    .font(.system(size: 10.5, weight: .heavy))
                    .tracking(0.5)
                    .foregroundStyle(YGColors.ink.opacity(0.6))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(YGColors.paper)
                    .clipShape(Capsule())

                Text(summary.title)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(YGColors.ink)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text("\(summary.presentCount) of \(summary.rosterTotal) present")
                        .font(.system(size: 11.5))
                        .foregroundStyle(YGColors.ink.opacity(0.55))

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(YGColors.ink.opacity(0.1))
                                .frame(height: 4)
                            Capsule().fill(Color(hex: "0066FF"))
                                .frame(width: geo.size.width * ratio, height: 4)
                        }
                    }
                    .frame(height: 4)
                }
                .padding(.top, 2)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(YGColors.ink.opacity(0.25))
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.black.opacity(0.05), lineWidth: 0.5)
        }
    }
}

// MARK: - Take roll sheet

struct TakeRollSheet: View {
    let group: LeaderSmallGroup
    var existingEvent: AttendanceEvent? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var occurredAt: Date = .now
    @State private var roster: [AttendanceRosterRow] = []
    @State private var isSaving = false
    @State private var saveError: String?
    @FocusState private var titleFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Event title")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(YGColors.ink.opacity(0.55))
                        TextField("e.g. Wednesday Night · Nov 12", text: $title)
                            .foregroundStyle(YGColors.ink)
                            .focused($titleFocused)
                            .padding(12)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(.black.opacity(0.08))
                            }
                    }

                    DatePicker("When", selection: $occurredAt,
                               displayedComponents: [.date, .hourAndMinute])
                        .foregroundStyle(YGColors.ink)
                        .padding(12)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Divider().padding(.vertical, 4)

                    Text("Roster · \(roster.count) student\(roster.count == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(YGColors.ink.opacity(0.55))

                    ForEach($roster) { $r in
                        RosterRowEditor(row: $r)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, minHeight: 0, alignment: .topLeading)
                .contentShape(Rectangle())
                .onTapGesture {
                    // Tap anywhere outside the text field dismisses the keyboard.
                    titleFocused = false
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(YGColors.paper)
            .navigationTitle(existingEvent == nil ? "Take roll" : "Edit attendance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await save() } } label: {
                        if isSaving { ProgressView() }
                        else { Text("Save").bold() }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .task { await loadRoster() }
            .alert("Couldn't save",
                   isPresented: Binding(
                       get: { saveError != nil },
                       set: { if !$0 { saveError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(saveError ?? "") }
        }
    }

    private func loadRoster() async {
        let svc = LeaderService.shared
        if svc.membersByGroup[group.id] == nil {
            await svc.loadMembers(smallGroupId: group.id)
        }
        if let ev = existingEvent {
            if svc.recordsByEvent[ev.id] == nil {
                await svc.loadAttendanceRecords(eventId: ev.id)
            }
            await MainActor.run {
                title = ev.title
                occurredAt = ev.occurredAt
            }
        }
        let existing: [UUID: Bool] = Dictionary(uniqueKeysWithValues:
            (svc.recordsByEvent[existingEvent?.id ?? UUID()] ?? [])
                .map { ($0.userId, $0.present) }
        )
        let members = (svc.membersByGroup[group.id] ?? [])
            .filter { $0.role == "member" }
        await MainActor.run {
            roster = members.map { m in
                AttendanceRosterRow(
                    userId: m.userId,
                    displayName: m.displayName ?? m.email ?? "—",
                    avatarUrl: m.avatarUrl,
                    present: existing[m.userId]
                )
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        saveError = nil
        do {
            let event: AttendanceEvent
            if let existing = existingEvent {
                event = existing
            } else {
                event = try await LeaderService.shared.createAttendanceEvent(
                    smallGroupId: group.id, title: title, occurredAt: occurredAt)
            }
            _ = try await LeaderService.shared.saveAttendance(
                eventId: event.id, roster: roster)
            await LeaderService.shared.loadAttendanceHistory(smallGroupId: group.id)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

private struct RosterRowEditor: View {
    @Binding var row: AttendanceRosterRow

    var body: some View {
        HStack(spacing: 12) {
            avatar
            Text(row.displayName)
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(YGColors.ink)
                .lineLimit(1)
            Spacer()
            HStack(spacing: 6) {
                pill(label: "Yes", on: row.present == true,
                     onColor: Color(hex: "B4FF3C")) { row.present = true }
                pill(label: "No", on: row.present == false,
                     onColor: Color(hex: "FF6B35"),
                     textOnColor: .white) { row.present = false }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var avatar: some View {
        if let s = row.avatarUrl, !s.isEmpty, let url = URL(string: s) {
            AsyncImage(url: url) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                YGAvatar(name: row.displayName, size: 36)
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())
        } else {
            YGAvatar(name: row.displayName, size: 36)
        }
    }

    private func pill(label: String, on: Bool, onColor: Color,
                      textOnColor: Color = YGColors.ink,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12.5, weight: .heavy))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(on ? textOnColor : YGColors.ink.opacity(0.6))
                .background(on ? onColor : YGColors.paper)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct GroupMember: Identifiable {
    let id: String
    let name: String
    let xp: String
    let isActive: Bool
}

struct GroupMemberRow: View {
    let member: GroupMember
    @State private var showMessageView = false
    
    var body: some View {
        Button {
            showMessageView = true
        } label: {
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "00E0FF"), Color(hex: "0066FF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 42, height: 42)
                    .overlay {
                        Text(member.name.prefix(1))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(member.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(YGColors.ink)
                    
                    HStack(spacing: 6) {
                        Text(member.xp)
                            .font(.system(size: 12))
                            .foregroundStyle(YGColors.ink.opacity(0.5))
                        
                        if member.isActive {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(Color(hex: "2B8A3E"))
                                    .frame(width: 5, height: 5)
                                
                                Text("Active")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color(hex: "2B8A3E"))
                            }
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(YGColors.ink.opacity(0.3))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .sheet(isPresented: $showMessageView) {
            MessageViewPlaceholder(memberName: member.name)
        }
    }
}

struct MessageViewPlaceholder: View {
    let memberName: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                
                VStack(spacing: 12) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color(hex: "0066FF"))
                    
                    Text("DM with \(memberName)")
                        .font(.lilitaOne(size: 20))
                        .foregroundStyle(YGColors.ink)
                    
                    Text("This would open the direct message\nconversation in the Messages view")
                        .font(.system(size: 14))
                        .foregroundStyle(YGColors.ink.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
            }
            .background(YGColors.paper)
            .navigationTitle("Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(YGColors.ink)
                }
            }
        }
    }
}

// MARK: - Manage Family View (Placeholder)
struct ManageFamilyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Manage Family Members")
                    .font(.lilitaOne(size: 24))
                    .padding()
                
                Text("Select family members to remove")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Settings Sheet View
struct SettingsSheetView: View {
    /// True when the caller pastors at least one group. Passed through
    /// to AccountSettingsView for the Stripe-vs-StoreKit billing row.
    let isPastor: Bool
    /// True for leaders + pastors. Drives the "Edit Profile" vs "Edit
    /// Name" label and the underlying form's affordances.
    let allowExtendedProfileFields: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var appearanceManager = AppearanceManager.shared
    @State private var familyService = FamilyService.shared
    @State private var showEditProfile = false
    @State private var showAccountSettings = false
    @State private var showSignOutConfirmation = false
    @State private var showSetupFamily = false
    @State private var showRemoveFamilyConfirm = false
    @State private var showJoinFamily = false
    @State private var showProfileQR = false

    var body: some View {
        VStack(spacing: 0) {
            // Title
            Text("Settings")
                .font(.lilitaOne(size: 22))
                .tracking(-0.5)
                .foregroundStyle(YGColors.ink)
                .padding(.top, 20)
                .padding(.bottom, 24)

            // Settings options
            VStack(spacing: 0) {
                // Edit Profile / Edit Name
                Button {
                    showEditProfile = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(YGColors.violet)
                            .frame(width: 32, alignment: .center)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(allowExtendedProfileFields ? "Edit Profile" : "Edit Name")
                                .font(.lilitaOne(size: 15))
                                .tracking(-0.2)
                                .foregroundStyle(YGColors.ink)

                            Text(allowExtendedProfileFields
                                 ? "Update photo, name, and bio"
                                 : "Change your display name")
                                .font(.system(size: 12))
                                .foregroundStyle(YGColors.ink.opacity(0.55))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(YGColors.ink.opacity(0.2))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.leading, 62)

                // Color Mode
                Button {
                    appearanceManager.isDarkMode.toggle()
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: appearanceManager.isDarkMode ? "moon.fill" : "sun.max.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(appearanceManager.isDarkMode ? YGColors.violet : Color(hex: "FFD60A"))
                            .frame(width: 32, alignment: .center)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Color Mode")
                                .font(.lilitaOne(size: 15))
                                .tracking(-0.2)
                                .foregroundStyle(YGColors.ink)

                            Text(appearanceManager.isDarkMode ? "Dark mode" : "Light mode")
                                .font(.system(size: 12))
                                .foregroundStyle(YGColors.ink.opacity(0.55))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(YGColors.ink.opacity(0.2))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.leading, 62)

                // Account Settings
                Button {
                    showAccountSettings = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color(hex: "FF6B35"))
                            .frame(width: 32, alignment: .center)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Account Settings")
                                .font(.lilitaOne(size: 15))
                                .tracking(-0.2)
                                .foregroundStyle(YGColors.ink)

                            Text("Manage your account")
                                .font(.system(size: 12))
                                .foregroundStyle(YGColors.ink.opacity(0.55))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(YGColors.ink.opacity(0.2))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 62)

                familyRow

                Divider().padding(.leading, 62)

                Button {
                    showProfileQR = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 22))
                            .foregroundStyle(YGColors.violet)
                            .frame(width: 32, alignment: .center)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show my profile QR")
                                .font(.lilitaOne(size: 15))
                                .tracking(-0.2)
                                .foregroundStyle(YGColors.ink)
                            Text("Let a parent scan to add you to their family")
                                .font(.system(size: 12))
                                .foregroundStyle(YGColors.ink.opacity(0.55))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(YGColors.ink.opacity(0.2))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.black.opacity(0.04), lineWidth: 0.5)
            }
            .shadow(color: YGColors.ink.opacity(0.04), radius: 8, y: 2)
            .padding(.horizontal, 20)
            
            // Sign Out Button
            Button {
                showSignOutConfirmation = true
            } label: {
                Text("Sign out")
                    .font(.lilitaOne(size: 14))
                    .foregroundStyle(Color(hex: "FF3B30"))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
            
            Spacer()
        }
        .background(YGColors.paper)
        .alert("Sign Out", isPresented: $showSignOutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                Task {
                    do {
                        try await SupabaseManager.shared.signOut()
                        // Reset onboarding flag to show onboarding again
                        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                        dismiss()
                    } catch {
                        print("Error signing out: \(error)")
                    }
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Remove your family?", isPresented: $showRemoveFamilyConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                Task {
                    guard let id = familyService.primaryFamily?.familyId else { return }
                    try? await familyService.removeFamily(familyId: id)
                }
            }
        } message: {
            Text("Your kids' accounts stay intact — they're just unlinked from your profile.")
        }
        .sheet(isPresented: $showSetupFamily) {
            SetupFamilyPaywallSheet { _ in }
        }
        .sheet(isPresented: $showJoinFamily) {
            AcceptFamilyInviteSheet()
        }
        .sheet(isPresented: $showProfileQR) {
            if let idString = SupabaseManager.shared.currentUser?.id,
               let id = UUID(uuidString: idString) {
                ProfileQRSheet(
                    userId: id,
                    displayName: SupabaseManager.shared.currentUser?.displayName ?? "My profile"
                )
                .presentationDetents([.large])
            }
        }
        .task {
            if familyService.myFamilies.isEmpty {
                await familyService.loadMyFamilies()
            }
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(allowExtendedFields: allowExtendedProfileFields)
        }
        .sheet(isPresented: $showAccountSettings) {
            AccountSettingsView(isPastor: isPastor)
        }
    }

    /// Start a Family (no family yet) → Remove Family (already a parent) →
    /// Join a Family (the invited side, no family but wants to redeem a
    /// code). Single row that swaps label/action based on state.
    @ViewBuilder
    private var familyRow: some View {
        let hasFamily = familyService.hasFamily
        let label = hasFamily ? "Remove Family" : "Start a Family"
        let subtitle = hasFamily ? "Unlink your family circle" : "Pair with your kids' accounts"

        Button {
            if hasFamily {
                showRemoveFamilyConfirm = true
            } else {
                showSetupFamily = true
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(hex: "FF3DA5"))
                    .frame(width: 32, alignment: .center)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.lilitaOne(size: 15))
                        .tracking(-0.2)
                        .foregroundStyle(YGColors.ink)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(YGColors.ink.opacity(0.55))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(YGColors.ink.opacity(0.2))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        // Join-a-family entry point (the invited side). Hidden once the
        // user is in any family — they can leave first if they want to
        // switch.
        if !hasFamily {
            Divider().padding(.leading, 62)
            Button {
                showJoinFamily = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 22))
                        .foregroundStyle(YGColors.violet)
                        .frame(width: 32, alignment: .center)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Join a Family")
                            .font(.lilitaOne(size: 15))
                            .tracking(-0.2)
                            .foregroundStyle(YGColors.ink)
                        Text("Got a 4-digit code? Enter it here.")
                            .font(.system(size: 12))
                            .foregroundStyle(YGColors.ink.opacity(0.55))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(YGColors.ink.opacity(0.2))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    ProfileView()
}
