//
//  PlansListView.swift
//  YGTeeV
//

import SwiftUI

struct PlansListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var expandedPlanId: UUID?
    @State private var showLockedSheet = false
    @State private var showJoinGroupMap = false
    @State private var introPlan: BiblePlan?
    @State private var resumeIds: (planId: UUID, dayId: UUID)?
    @State private var showDailyPlan = false

    private let plansService = PlansService.shared
    private let entitlements = EntitlementsService.shared

    private var plans: [BiblePlan] { plansService.publishedPlans }

    private func canStart(_ plan: BiblePlan) -> Bool {
        PlansService.canViewerStart(plan)
    }

    /// Find the right day to open: in-progress first, then next un-started, else day 1.
    private func resolveResumeDayId(for plan: BiblePlan) async -> UUID? {
        // Ensure days are loaded.
        if plansService.daysByPlan[plan.id] == nil {
            await plansService.loadDays(planId: plan.id)
        }
        let days = plansService.daysByPlan[plan.id] ?? []
        let progress = plansService.progressByPlan[plan.id] ?? []

        // Index progress by dayNumber for fast lookup.
        let progressByDay = Dictionary(uniqueKeysWithValues: progress.map { ($0.dayNumber, $0) })

        // Prefer: an in-progress day (has some steps done but not all).
        if let resume = days.first(where: { d in
            let p = progressByDay[d.dayNumber]
            return p != nil && !(p?.dayComplete ?? false) && !(p?.stepsCompleted.isEmpty ?? true)
        }) {
            return resume.id
        }

        // Next un-started day (no progress row OR progress row exists but no steps).
        if let next = days.first(where: { d in
            let p = progressByDay[d.dayNumber]
            return p == nil || (!p!.dayComplete && p!.stepsCompleted.isEmpty)
        }) {
            return next.id
        }

        // Plan complete — return last day's id for review.
        return days.last?.id
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your Journey")
                            .font(.lilitaOne(size: 28))
                            .foregroundStyle(.primary)

                        Text("Follow the path or explore on your own")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                    if plans.isEmpty && plansService.isLoadingPlans {
                        ProgressView()
                            .padding(.top, 40)
                    } else if plans.isEmpty {
                        Text("No plans available yet.")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .padding(.top, 40)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(Array(plans.enumerated()), id: \.element.id) { index, plan in
                                PlanJourneyCard(
                                    plan: plan,
                                    journeyNumber: index + 1,
                                    isExpanded: expandedPlanId == plan.id,
                                    isLocked: !canStart(plan),
                                    progress: plansService.progressByPlan[plan.id] ?? [],
                                    onToggle: {
                                        withAnimation(.smooth(duration: 0.3)) {
                                            expandedPlanId = expandedPlanId == plan.id ? nil : plan.id
                                        }
                                    },
                                    onStart: {
                                        if canStart(plan) {
                                            Task {
                                                let progress = plansService.progressByPlan[plan.id] ?? []
                                                let hasStarted = progress.contains { $0.dayComplete || !$0.stepsCompleted.isEmpty }

                                                if !hasStarted {
                                                    introPlan = plan
                                                    return
                                                }

                                                if let dayId = await resolveResumeDayId(for: plan) {
                                                    resumeIds = (plan.id, dayId)
                                                    showDailyPlan = true
                                                }
                                            }
                                        } else {
                                            showLockedSheet = true
                                        }
                                    },
                                    onOpenDay: { dayNumber in
                                        guard canStart(plan) else {
                                            showLockedSheet = true
                                            return
                                        }
                                        Task {
                                            if plansService.daysByPlan[plan.id] == nil {
                                                await plansService.loadDays(planId: plan.id)
                                            }
                                            if let day = plansService.daysByPlan[plan.id]?.first(where: { $0.dayNumber == dayNumber }) {
                                                resumeIds = (plan.id, day.id)
                                                showDailyPlan = true
                                            }
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(item: $introPlan) { plan in
                PlanIntroView(plan: plan)
            }
            .fullScreenCover(isPresented: $showLockedSheet) {
                // Self-contained paywall for the Your Journey locked
                // path. Dismisses cleanly back to the plans list; the
                // join-group escape hatch flips a separate cover so
                // the two presentations don't fight.
                PlanProPaywallSheet(
                    onClose: { showLockedSheet = false },
                    onJoinGroupInstead: {
                        showLockedSheet = false
                        // Next runloop so the paywall finishes
                        // dismissing before the map cover presents.
                        DispatchQueue.main.async {
                            showJoinGroupMap = true
                        }
                    }
                )
            }
            .fullScreenCover(isPresented: $showJoinGroupMap) {
                JoinGroupMapView()
            }
            .fullScreenCover(isPresented: $showDailyPlan, onDismiss: { resumeIds = nil }) {
                if let ids = resumeIds {
                    DailyPlanView(planId: ids.planId, dayId: ids.dayId, onDismiss: {
                        showDailyPlan = false
                    })
                }
            }
        }
        .task {
            await plansService.loadPublishedPlans()
            await withTaskGroup(of: Void.self) { group in
                for p in plansService.publishedPlans {
                    group.addTask { await plansService.loadProgress(planId: p.id) }
                }
            }
        }
    }
}

// MARK: - Upsell Sheet

struct UpsellSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showJoinMap = false
    @State private var showProUpgrade = false

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            Text("Unlock all plans")
                .font(.lilitaOne(size: 26))
                .padding(.top, 4)

            Text("Free members can start the Book of John. Unlock every plan in one of two ways:")
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)

            Button {
                showJoinMap = true
            } label: {
                UpsellCTACard(
                    emoji: "⛪",
                    title: "Join a youth group",
                    subtitle: "Members of any church youth group get every plan free.",
                    actionLabel: "Find a group near me"
                )
            }
            .buttonStyle(.plain)

            Button {
                showProUpgrade = true
            } label: {
                UpsellCTACard(
                    emoji: "✨",
                    title: "Become a Pro member",
                    subtitle: "Unlock every plan and content as a Pro member from $0.99/mo.",
                    actionLabel: "Upgrade to Pro"
                )
            }
            .buttonStyle(.plain)

            Button("Not now") { dismiss() }
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .padding(.top, 6)

            Spacer()
        }
        .padding(.horizontal, 18)
        .background(YGColors.paper)
        .presentationDetents([.height(520)])
        .presentationDragIndicator(.hidden)
        .fullScreenCover(isPresented: $showJoinMap, onDismiss: {
            // Membership might have flipped; refresh entitlements so locked plans unlock live.
            Task { await EntitlementsService.shared.refreshAfterYouthGroupChange() }
            dismiss()
        }) {
            JoinGroupMapView()
        }
        .alert("Coming soon", isPresented: $showProUpgrade) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Pro subscriptions launch with our App Store release. For now, joining a youth group is the easiest way to unlock everything.")
        }
    }
}

struct UpsellCTACard: View {
    let emoji: String
    let title: String
    let subtitle: String
    let actionLabel: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji)
                .font(.system(size: 30))
                .frame(width: 44, height: 44)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 4) {
                    Text(actionLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(YGColors.violet)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(YGColors.violet)
                }
                .padding(.top, 2)
            }

            Spacer()
        }
        .padding(14)
        .background(YGColors.violet.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(YGColors.violet.opacity(0.18), lineWidth: 1)
        }
    }
}

// MARK: - Plan Journey Card

struct PlanJourneyCard: View {
    let plan: BiblePlan
    let journeyNumber: Int
    let isExpanded: Bool
    let isLocked: Bool
    let progress: [UserPlanProgress]
    let onToggle: () -> Void
    let onStart: () -> Void
    let onOpenDay: (Int) -> Void

    enum DayStatus { case done, inProgress, notStarted

        var color: Color {
            switch self {
            case .done: return .green
            case .inProgress: return .yellow
            case .notStarted: return .secondary.opacity(0.2)
            }
        }
    }

    private var completedCount: Int {
        progress.filter { $0.dayComplete }.count
    }

    private var progressFraction: Double {
        guard plan.daysTotal > 0 else { return 0 }
        return Double(completedCount) / Double(plan.daysTotal)
    }

    private var dayStatuses: [DayStatus] {
        (1...max(plan.daysTotal, 1)).map { dayNumber in
            if let row = progress.first(where: { $0.dayNumber == dayNumber }) {
                if row.dayComplete { return .done }
                if !row.stepsCompleted.isEmpty { return .inProgress }
            }
            return .notStarted
        }
    }

    var body: some View {
        if isLocked {
            // Whole-card tap shows the upsell sheet.
            Button(action: onStart) {
                cardBody
            }
            .buttonStyle(.plain)
        } else {
            cardBody
        }
    }

    private var cardBody: some View {
        VStack(spacing: 0) {
            // Header row — tappable for expand/collapse on unlocked
            // cards only. When locked we deliberately attach NO inner
            // tap gesture, otherwise SwiftUI consumes the tap before
            // the outer Button (which routes to the paywall) can fire.
            if isLocked {
                headerRow
            } else {
                headerRow
                    .contentShape(Rectangle())
                    .onTapGesture { onToggle() }
            }

            // Only expand when the user has tapped (and only unlocked plans
            // can be expanded — locked taps route to the upsell sheet).
            if isExpanded {
                expandedBody
            }
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    // MARK: Header row

    private var headerRow: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(plan.gradient)
                    .frame(width: 48, height: 48)
                    .opacity(isLocked ? 0.35 : 1)
                    .saturation(isLocked ? 0.2 : 1)

                Text("\(journeyNumber)")
                    .font(.lilitaOne(size: 24))
                    .foregroundStyle(.white)
                    .opacity(isLocked ? 0.6 : 1)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(plan.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isLocked ? .secondary : .primary)

                    if plan.isFreeEntry && !isLocked {
                        Text("FREE")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    if isLocked {
                        HStack(spacing: 3) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text("PRO")
                                .font(.system(size: 9, weight: .heavy))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(YGColors.violet)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }

                if completedCount == plan.daysTotal && plan.daysTotal > 0 && !isLocked {
                    Text("Completed ✓")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.green)
                } else if isLocked {
                    Text("Tap to unlock")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(YGColors.violet)
                } else {
                    Text("\(completedCount) / \(plan.daysTotal) days done")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }

                if completedCount > 0 && !isLocked {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.secondary.opacity(0.2))
                                .frame(height: 4)

                            Capsule()
                                .fill(plan.gradient)
                                .frame(width: geometry.size.width * progressFraction, height: 4)
                        }
                    }
                    .frame(height: 4)
                    .padding(.top, 2)
                }
            }

            Spacer()

            Image(systemName: isLocked ? "lock.fill" : "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(isLocked ? 0 : (isExpanded ? 90 : 0)))
        }
        .padding(16)
    }

    // MARK: Expanded body (day grid + reward row + CTA)

    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 8) {
                Text("Days")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                    ForEach(1...max(plan.daysTotal, 1), id: \.self) { day in
                        DayCircle(
                            day: day,
                            status: dayStatuses[day - 1],
                            isLocked: isLocked
                        )
                        .contentShape(Circle())
                        .onTapGesture {
                            guard !isLocked else { return }
                            onOpenDay(day)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .allowsHitTesting(!isLocked)
            }

            // Reward row
            HStack(spacing: 16) {
                Label {
                    Text("+\(plan.xpReward) XP")
                        .font(.system(size: 14, weight: .medium))
                } icon: {
                    Text("⚡").font(.system(size: 16))
                }

                Label {
                    Text("+\(plan.waterReward) Water")
                        .font(.system(size: 14, weight: .medium))
                } icon: {
                    Text("💧").font(.system(size: 16))
                }

                Spacer()
            }
            .foregroundStyle(isLocked ? .secondary : Color.primary.opacity(0.8))
            .opacity(isLocked ? 0.55 : 1)
            .padding(.horizontal, 16)
            .padding(.top, 4)

            // CTA — pure styled view; tap is owned by the outer Button (locked)
            // or wrapped in its own Button (unlocked) below.
            if isLocked {
                ctaPill
                    .padding(.horizontal, 16)
            } else {
                Button(action: onStart) {
                    ctaPill
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 16)
        .background(.background)
    }

    private var ctaPill: some View {
        HStack {
            Image(systemName: isLocked ? "lock.fill" : "play.fill")
                .font(.system(size: 13))
            Text(ctaLabel)
                .font(.system(size: 15, weight: .bold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(YGColors.violet)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var ctaLabel: String {
        if isLocked { return "Unlock" }
        if completedCount == 0 { return "Start" }
        if completedCount == plan.daysTotal { return "Review" }
        return "Continue"
    }
}

// MARK: - Day Circle

struct DayCircle: View {
    let day: Int
    let status: PlanJourneyCard.DayStatus
    var isLocked: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(status.color)
                .frame(width: 36, height: 36)
                .saturation(isLocked ? 0.0 : 1.0)
                .opacity(isLocked ? 0.5 : 1.0)

            if status == .done {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Text("\(day)")
                    .font(.system(size: 13, weight: status == .inProgress ? .bold : .medium))
                    .foregroundStyle(status == .notStarted ? .secondary : .primary)
            }
        }
        .opacity(isLocked ? 0.6 : 1.0)
    }
}

#Preview {
    PlansListView()
        .environment(AppState())
}
