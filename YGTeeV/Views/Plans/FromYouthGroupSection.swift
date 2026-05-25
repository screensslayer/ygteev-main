//
//  FromYouthGroupSection.swift
//  YGTeeV
//
//  Member-side surface for pastor-published plans on the Plans tab.
//  Renders "From [Group]" header + Available/Completed toggle + expandable
//  plan rows. Falls back to a "Join A Group" card when the user is in no
//  youth group.
//

import SwiftUI

struct FromYouthGroupSection: View {
    @State private var service = PlansService.shared
    @State private var filter: Filter = .available
    @State private var expandedPlanId: UUID?
    @State private var openDay: OpenDay?
    @State private var showJoinMap = false
    /// `nil` until the first `am_i_in_any_youth_group` check returns; lets
    /// us render neither variant during the check so the green Join card
    /// doesn't briefly flash for users who are already in a group.
    @State private var membershipLoaded = false

    enum Filter: String, Hashable {
        case available, completed
    }

    struct OpenDay: Identifiable, Hashable {
        let planId: UUID
        let dayNumber: Int
        let planTitle: String
        let isCompleted: Bool
        var id: String { "\(planId.uuidString)-\(dayNumber)" }
    }

    private var groupName: String {
        service.youthGroupPlans[Filter.available.rawValue]?.first?.groupName
            ?? service.youthGroupPlans[Filter.completed.rawValue]?.first?.groupName
            ?? "your group"
    }

    private var rows: [YouthGroupPlanRow] {
        service.youthGroupPlans[filter.rawValue] ?? []
    }

    var body: some View {
        Group {
            if !membershipLoaded {
                // Don't show either variant until the check returns,
                // so users in a group never see the join card flash by.
                Color.clear.frame(height: 1)
            } else if service.inAnyYouthGroup {
                inGroupSection
            } else {
                joinGroupCard
            }
        }
        .task { await initialLoad() }
        .fullScreenCover(item: $openDay) { day in
            PastorPlanDayReaderView(
                planId: day.planId,
                dayNumber: day.dayNumber,
                planTitle: day.planTitle,
                isCompleted: day.isCompleted,
                onClose: { openDay = nil },
                onDayCompleted: {
                    Task {
                        // Refresh after a completion so the day list moves
                        // the day to "done" and the row's days_completed
                        // count refreshes.
                        await service.loadPlanDayProgress(planId: day.planId)
                        await service.loadYouthGroupPlans(filter: Filter.available.rawValue)
                        await service.loadYouthGroupPlans(filter: Filter.completed.rawValue)
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showJoinMap) {
            JoinGroupMapView()
        }
    }

    // MARK: - Init load

    private func initialLoad() async {
        await service.checkInAnyYouthGroup()
        membershipLoaded = true
        if service.inAnyYouthGroup {
            await service.loadYouthGroupPlans(filter: Filter.available.rawValue)
            await service.loadYouthGroupPlans(filter: Filter.completed.rawValue)
        }
    }

    // MARK: - Join group card (no group)

    private var joinGroupCard: some View {
        Button { showJoinMap = true } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text("From a Youth Group")
                    .font(.lilitaOne(size: 22))
                    .foregroundStyle(YGColors.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                ZStack {
                    LinearGradient(
                        colors: [Color(hex: "B4FF3C"), Color(hex: "00C6A2")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )

                    VStack(spacing: 8) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.white)
                        Text("Join A Group")
                            .font(.lilitaOne(size: 22))
                            .foregroundStyle(.white)
                        Text("Find a youth group near you")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(20)
                }
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal, 20)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - In-group section

    private var inGroupSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("From \(groupName)")
                    .font(.lilitaOne(size: 22))
                    .foregroundStyle(YGColors.ink)
                    .lineLimit(1)
                Spacer()
                filterToggle
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            if rows.isEmpty {
                emptyState
                    .padding(.horizontal, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(rows) { row in
                        planRow(row)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var filterToggle: some View {
        HStack(spacing: 4) {
            filterPill(.available, label: "Available")
            filterPill(.completed, label: "Completed")
        }
        .padding(3)
        .background(YGColors.ink.opacity(0.06))
        .clipShape(Capsule())
    }

    private func filterPill(_ value: Filter, label: String) -> some View {
        let on = filter == value
        return Button { filter = value } label: {
            Text(label)
                .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                .foregroundStyle(on ? .white : YGColors.ink.opacity(0.6))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(on ? YGColors.ink : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text(filter == .available ? "🎯" : "✅")
                .font(.system(size: 28))
            Text(filter == .available ? "No plans available yet"
                                       : "No completed plans yet")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(YGColors.ink)
            Text(filter == .available
                 ? "Your group's pastor will publish plans here."
                 : "Finish a plan and it'll show up here.")
                .font(.system(size: 12))
                .foregroundStyle(YGColors.ink.opacity(0.55))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(YGColors.ink.opacity(0.05), lineWidth: 0.5)
        }
    }

    // MARK: - Plan row

    @ViewBuilder
    private func planRow(_ row: YouthGroupPlanRow) -> some View {
        let isExpanded = expandedPlanId == row.id

        VStack(spacing: 0) {
            Button {
                withAnimation(.smooth(duration: 0.25)) {
                    if isExpanded {
                        expandedPlanId = nil
                    } else {
                        expandedPlanId = row.id
                        Task { await service.loadPlanDayProgress(planId: row.id) }
                    }
                }
            } label: {
                rowHeader(row, expanded: isExpanded)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().padding(.leading, 16)
                expandedDays(for: row)
            }
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(YGColors.ink.opacity(0.05), lineWidth: 0.5)
        }
    }

    private func rowHeader(_ row: YouthGroupPlanRow, expanded: Bool) -> some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(gradient(for: row))
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
    private func expandedDays(for row: YouthGroupPlanRow) -> some View {
        let days = service.pastorPlanDays[row.id] ?? []
        if days.isEmpty {
            HStack {
                ProgressView()
                Text("Loading…").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.element.id) { idx, day in
                    Button {
                        openDay = OpenDay(planId: row.planId,
                                          dayNumber: day.dayNumber,
                                          planTitle: row.title,
                                          isCompleted: day.isCompleted)
                    } label: {
                        dayRow(day)
                    }
                    .buttonStyle(.plain)
                    if idx < days.count - 1 {
                        Divider().padding(.leading, 44)
                    }
                }
            }
        }
    }

    private func dayRow(_ day: PlanDayProgress) -> some View {
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

    // MARK: - Helpers

    private func gradient(for row: YouthGroupPlanRow) -> LinearGradient {
        PlanHeaderGradient.gradient(at: row.gradientIndex)
    }

    private static let relativeDate: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
}

