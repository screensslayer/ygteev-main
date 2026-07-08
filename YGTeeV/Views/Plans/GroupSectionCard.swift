//
//  GroupSectionCard.swift
//  YGTeeV
//
//  Per-group panel that lives on the member's Plans tab. Each youth
//  group the user belongs to gets its own card with a top-level
//  Plans / Events toggle and an Active / Completed sub-toggle.
//
//  Plans content reuses the existing pastor-plan row + expand-days
//  pattern that lived in `FromYouthGroupSection.inGroupSection`.
//  Events content uses `FeaturedEventCard` so RSVP, the inline
//  picker, and the "Invite a friend" share sheet all behave exactly
//  like they do on the Home Events tab.
//
//  Past-event media is read-only here per the v1 design — pastors add
//  photos from the dedicated past-event flow on Home, not from this
//  per-group panel. `FeaturedEventCard` doesn't surface an Add Photos
//  affordance, so there's nothing to suppress.
//

import SwiftUI

struct GroupSectionCard: View {
    let membership: MyGroupMembership

    @State private var plansService = PlansService.shared
    @State private var eventsService = EventsService.shared

    @State private var primaryTab: PrimaryTab = .plans
    @State private var subTab: SubTab = .active

    // Plans state
    @State private var expandedPlanId: UUID?
    @State private var openDay: OpenDay?

    // Events state — kept as local snapshots because
    // `eventsService.eventsByGroup` only holds one bucket per group,
    // and switching sub-tabs would otherwise blow the other list
    // away. Loading upcoming + past once each keeps the toggle snappy.
    @State private var upcomingEvents: [GroupEventFull] = []
    @State private var pastEvents: [GroupEventFull] = []
    @State private var expandedEventId: UUID?

    enum PrimaryTab: String, Hashable { case plans, events }
    enum SubTab: String, Hashable { case active, completed }

    struct OpenDay: Identifiable, Hashable {
        let planId: UUID
        let dayNumber: Int
        let planTitle: String
        let isCompleted: Bool
        var id: String { "\(planId.uuidString)-\(dayNumber)" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            primaryTabPill
            subTabRow
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(YGColors.ink.opacity(0.05), lineWidth: 0.5)
        }
        .task(id: subTab) {
            // Lazy-load just the visible slice on first appearance + on
            // every sub-tab switch. Plans data lives on the singleton
            // and is loaded by the parent; events fetch happens here.
            await loadEventsIfNeeded()
        }
        .fullScreenCover(item: $openDay) { day in
            PastorPlanDayReaderView(
                planId: day.planId,
                dayNumber: day.dayNumber,
                planTitle: day.planTitle,
                isCompleted: day.isCompleted,
                onClose: { openDay = nil },
                onDayCompleted: {
                    Task {
                        await plansService.loadPlanDayProgress(planId: day.planId)
                        await plansService.loadYouthGroupPlans(filter: SubTab.active.rawValue)
                        await plansService.loadYouthGroupPlans(filter: SubTab.completed.rawValue)
                    }
                }
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                Text(membership.name)
                    .font(.lilitaOne(size: 22))
                    .tracking(-0.4)
                    .foregroundStyle(YGColors.ink)
                    .lineLimit(1)
                Text("YOUR GROUP")
                    .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                    .tracking(1.0)
                    .foregroundStyle(YGColors.ink.opacity(0.45))
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var avatar: some View {
        // Prefer the group's saved logo. Fall back to the saved
        // gradient + initials so groups without a logo still get a
        // recognizable tile (same approach the Messages list uses).
        if let urlString = membership.logoUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                default:                initialsTile
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            initialsTile
        }
    }

    private var initialsTile: some View {
        let from = membership.gradientFrom ?? "6B2BFF"
        let to   = membership.gradientTo   ?? "FF3DA5"
        return ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: from), Color(hex: to)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            Text(initials)
                .font(.lilitaOne(size: 16))
                .foregroundStyle(.white)
                .tracking(-0.3)
        }
        .frame(width: 44, height: 44)
    }

    private var initials: String {
        membership.name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
            .uppercased()
    }

    // MARK: - Primary tab (Plans | Events)
    //
    // Larger rounded-pill segmented control with the brand violet→pink
    // gradient on the selected side. Matches the design comp the
    // pastor shared while keeping the gradient already used elsewhere
    // in the app (header chrome, hero cards).

    private var primaryTabPill: some View {
        HStack(spacing: 0) {
            primaryTabButton(.plans, label: "Plans")
            primaryTabButton(.events, label: "Events")
        }
        .padding(4)
        .background(YGColors.ink.opacity(0.05))
        .clipShape(Capsule())
    }

    private func primaryTabButton(_ tab: PrimaryTab, label: String) -> some View {
        let isSelected = primaryTab == tab
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                primaryTab = tab
                // Switching primary tabs leaves the sub-tab selection
                // in place — pastor watches the same Active /
                // Completed selection apply to both lanes.
            }
        } label: {
            Text(label)
                .font(.lilitaOne(size: 15))
                .tracking(-0.2)
                .foregroundStyle(isSelected ? .white : YGColors.ink.opacity(0.65))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [YGColors.violet, YGColors.pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sub-tab (Active | Completed)
    //
    // Text-only with a violet underline on the selected option, to
    // match the screenshot. Less visual weight than the primary pill
    // so the eye lands on the content below.

    private var subTabRow: some View {
        HStack(spacing: 22) {
            subTabButton(.active, label: "Active")
            subTabButton(.completed, label: "Completed")
            Spacer()
        }
    }

    private func subTabButton(_ tab: SubTab, label: String) -> some View {
        let isSelected = subTab == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                subTab = tab
            }
        } label: {
            VStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(isSelected ? YGColors.ink : YGColors.ink.opacity(0.4))
                Rectangle()
                    .fill(isSelected ? YGColors.violet : Color.clear)
                    .frame(height: 2.5)
                    .frame(width: 28)
                    .clipShape(Capsule())
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch (primaryTab, subTab) {
        case (.plans, .active):     plansList(filter: .active)
        case (.plans, .completed):  plansList(filter: .completed)
        case (.events, .active):    eventsList(events: upcomingEvents, isUpcoming: true)
        case (.events, .completed): eventsList(events: pastEvents, isUpcoming: false)
        }
    }

    // MARK: - Plans

    private func planRows(filter: SubTab) -> [YouthGroupPlanRow] {
        (plansService.youthGroupPlans[filter.rawValue] ?? [])
            .filter { $0.groupId == membership.groupId }
    }

    @ViewBuilder
    private func plansList(filter: SubTab) -> some View {
        let rows = planRows(filter: filter)
        if rows.isEmpty {
            emptyState(
                emoji: filter == .active ? "🎯" : "✅",
                title: filter == .active ? "No plans available yet"
                                          : "No completed plans yet",
                blurb: filter == .active
                       ? "Your group's pastor will publish plans here."
                       : "Finish a plan and it'll show up here."
            )
        } else {
            VStack(spacing: 8) {
                ForEach(rows) { row in planRow(row) }
            }
        }
    }

    @ViewBuilder
    private func planRow(_ row: YouthGroupPlanRow) -> some View {
        let isExpanded = expandedPlanId == row.planId
        VStack(spacing: 0) {
            Button {
                withAnimation(.smooth(duration: 0.25)) {
                    if isExpanded {
                        expandedPlanId = nil
                    } else {
                        expandedPlanId = row.planId
                        Task { await plansService.loadPlanDayProgress(planId: row.planId) }
                    }
                }
            } label: {
                planRowHeader(row, expanded: isExpanded)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().padding(.leading, 16)
                planExpandedDays(for: row)
            }
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(YGColors.ink.opacity(0.05), lineWidth: 0.5)
        }
    }

    private func planRowHeader(_ row: YouthGroupPlanRow, expanded: Bool) -> some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(PlanHeaderGradient.gradient(at: row.gradientIndex))
                .frame(width: 4, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(YGColors.ink)
                    .lineLimit(1)
                if row.isCompleted, let completed = row.completedAt {
                    Text("✓ Completed " + Self.relativeDate.localizedString(for: completed, relativeTo: Date()))
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "2B8A3E"))
                        .lineLimit(1)
                } else {
                    Text("\(row.daysCompleted)/\(row.daysTotal) days · ⚡ \(row.xpReward) XP")
                        .font(.system(size: 12))
                        .foregroundStyle(YGColors.ink.opacity(0.55))
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(YGColors.ink.opacity(0.3))
                .rotationEffect(.degrees(expanded ? 90 : 0))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func planExpandedDays(for row: YouthGroupPlanRow) -> some View {
        let days = plansService.pastorPlanDays[row.planId] ?? []
        if days.isEmpty {
            HStack {
                ProgressView()
                Text("Loading…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.element.id) { idx, day in
                    Button {
                        openDay = OpenDay(
                            planId: row.planId,
                            dayNumber: day.dayNumber,
                            planTitle: row.title,
                            isCompleted: day.isCompleted
                        )
                    } label: {
                        planDayRow(day)
                    }
                    .buttonStyle(.plain)
                    if idx < days.count - 1 {
                        Divider().padding(.leading, 44)
                    }
                }
            }
        }
    }

    private func planDayRow(_ day: PlanDayProgress) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(day.isCompleted ? Color(hex: "B4FF3C").opacity(0.22) : YGColors.ink.opacity(0.06))
                    .frame(width: 28, height: 28)
                if day.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Color(hex: "2B8A3E"))
                } else {
                    Text("\(day.dayNumber)")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(YGColors.ink)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Day \(day.dayNumber)" + (day.title.isEmpty ? "" : " · \(day.title)"))
                    .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(YGColors.ink)
                    .lineLimit(1)
                if !day.scriptureReference.isEmpty {
                    Text(day.scriptureReference)
                        .font(.system(size: 11.5))
                        .foregroundStyle(YGColors.ink.opacity(0.55))
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(YGColors.ink.opacity(0.3))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - Events

    @ViewBuilder
    private func eventsList(events: [GroupEventFull], isUpcoming: Bool) -> some View {
        if events.isEmpty {
            emptyState(
                emoji: isUpcoming ? "📅" : "📭",
                title: isUpcoming ? "No upcoming events" : "No past events",
                blurb: isUpcoming
                       ? "When your group's pastor schedules an event, it'll appear here."
                       : "Finished events will appear here so you can look back."
            )
        } else {
            VStack(spacing: 12) {
                ForEach(events) { event in
                    FeaturedEventCard(
                        event: event,
                        isExpanded: expandedEventId == event.id,
                        onTap: {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                                expandedEventId = (expandedEventId == event.id) ? nil : event.id
                            }
                        }
                    )
                }
            }
        }
    }

    /// Pulls events for the visible sub-tab into local state. The
    /// shared `EventsService.eventsByGroup` cache only holds one bucket
    /// per group, so we drain it into the local snapshot immediately
    /// after each load to survive future re-loads of the other lane.
    private func loadEventsIfNeeded() async {
        let isUpcoming = subTab == .active
        let alreadyHave = isUpcoming ? !upcomingEvents.isEmpty : !pastEvents.isEmpty
        // First fetch of the lane runs unconditionally; subsequent
        // switches re-fetch silently to pick up newly RSVP'd /
        // newly-created events. (`upcomingEvents.isEmpty` would also be
        // true if the group simply has no events — the re-fetch is
        // cheap and the UI doesn't flicker because we only overwrite
        // on the happy path.)
        do {
            try await eventsService.loadGroupEvents(groupId: membership.groupId,
                                                    upcoming: isUpcoming)
            let fresh = eventsService.eventsByGroup[membership.groupId] ?? []
            if isUpcoming {
                upcomingEvents = fresh
            } else {
                pastEvents = fresh
            }
        } catch {
            // Silent — preserve whatever the previous snapshot was.
            // The empty state still renders if we never got data.
            print("[GroupSectionCard] loadGroupEvents failed for \(membership.name):", error)
            _ = alreadyHave
        }
    }

    // MARK: - Empty state

    private func emptyState(emoji: String, title: String, blurb: String) -> some View {
        VStack(spacing: 6) {
            Text(emoji).font(.system(size: 28))
            Text(title)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(YGColors.ink)
            Text(blurb)
                .font(.system(size: 12))
                .foregroundStyle(YGColors.ink.opacity(0.55))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Helpers

    private static let relativeDate: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
}
