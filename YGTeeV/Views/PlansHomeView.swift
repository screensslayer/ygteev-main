//
//  PlansHomeView.swift
//  YGTeeV
//

import SwiftUI

struct PlansHomeView: View {
    @Environment(AppState.self) var appState
    @State private var showGardenFullView = false
    @State private var showPlansList = false
    @State private var showPlanIntro = false
    @State private var selectedPlan: BiblePlan?
    @State private var showDailyPlan = false
    @State private var continueOpenIds: (UUID, UUID)?
    @State private var appearanceManager = AppearanceManager.shared

    private let plansService = PlansService.shared
    private let supabase = SupabaseManager.shared

    private var user: User? { supabase.currentUser }

    /// Opens day 1 of the first published plan (the free-entry John plan).
    /// Called when the user has nothing started and taps the Get Started card.
    private func startFirstPlan() async {
        // Prefer the free-entry plan (John), falling back to the first published plan.
        let plan = plansService.publishedPlans.first(where: { $0.isFreeEntry })
            ?? plansService.publishedPlans.first
        guard let plan else { return }

        if plansService.daysByPlan[plan.id] == nil {
            await plansService.loadDays(planId: plan.id)
        }
        guard let day1 = plansService.daysByPlan[plan.id]?.first(where: { $0.dayNumber == 1 }) else {
            return
        }
        continueOpenIds = (plan.id, day1.id)
        withAnimation(.easeInOut(duration: 0.3)) {
            showDailyPlan = true
        }
    }

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        // Top header with stats
                        HStack(alignment: .firstTextBaseline) {
                            Text("Plans")
                                .font(.lilitaOne(size: 32))
                                .foregroundStyle(appearanceManager.isDarkMode ? .white : YGColors.ink)

                            Spacer()

                            HStack(spacing: 6) {
                                StatPill(icon: "flame.fill", value: "\(user?.streak ?? 0)", color: YGColors.streak, dark: appearanceManager.isDarkMode)
                                StatPill(icon: "bolt.fill", value: "\(user?.xp ?? 0)", color: YGColors.xp, dark: appearanceManager.isDarkMode)
                                StatPill(icon: "drop.fill", value: "\(user?.water ?? 0)", color: YGColors.water, dark: appearanceManager.isDarkMode)
                            }
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 60)
                        .padding(.bottom, 8)

                        // Garden card
                        Button {
                            showGardenFullView = true
                        } label: {
                            GardenPreviewCard()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)

                        // Continue card or empty state
                        VStack(alignment: .leading, spacing: 0) {
                            let synth = synthContinuePlan
                            let isContinue = plansService.continueCard != nil || synth != nil

                            SectionTitle(
                                title: isContinue ? "Continue" : "Get Started",
                                action: "See all",
                                onAction: { showPlansList = true },
                                dark: appearanceManager.isDarkMode
                            )
                            .padding(.horizontal, 20)

                            // Only surface the server-side Continue card
                            // when it points at a GLOBAL plan (one in
                            // `publishedPlans`). The same RPC also returns
                            // pastor-plan progress, which `DailyPlanView`
                            // can't render — those live in the "From
                            // [Group]" section below.
                            if let card = plansService.continueCard,
                               plansService.publishedPlans.contains(where: { $0.id == card.planId }) {
                                ContinueLiveCard(card: card) {
                                    continueOpenIds = (card.planId, card.dayId)
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showDailyPlan = true
                                    }
                                }
                                .padding(.horizontal, 20)
                            } else if let synth {
                                GetStartedCard(
                                    title: "CONTINUE",
                                    subtitle: "Day \(synth.day.dayNumber) of \(synth.plan.title)",
                                    showSparkle: false
                                ) {
                                    continueOpenIds = (synth.plan.id, synth.day.id)
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showDailyPlan = true
                                    }
                                }
                                .padding(.horizontal, 20)
                            } else {
                                GetStartedCard {
                                    Task { await startFirstPlan() }
                                }
                                .padding(.horizontal, 20)
                            }
                        }

                        // From [Group] section — pastor-published plans for
                        // the active member's youth group(s). Falls back to
                        // a "Join A Group" CTA when the user isn't in any.
                        FromYouthGroupSection()
                            .padding(.top, 28)

                        Spacer(minLength: 20)
                    }
                    .padding(.bottom, 120)
                }
                .background(appearanceManager.isDarkMode ? Color.black : ThemeColors.background(isDark: false))
                .ignoresSafeArea(edges: .top)
            }
            .sheet(isPresented: $showPlanIntro) {
                if let plan = selectedPlan {
                    PlanIntroView(plan: plan)
                }
            }
            .sheet(isPresented: $showGardenFullView) {
                GardenFullView()
            }
            .sheet(isPresented: $showPlansList) {
                PlansListView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }

            // DailyPlanView overlay
            if showDailyPlan, let ids = continueOpenIds {
                DailyPlanView(planId: ids.0, dayId: ids.1, onDismiss: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showDailyPlan = false
                        continueOpenIds = nil
                    }
                })
                .transition(.move(edge: .trailing))
                .zIndex(1)
            }
        }
        .task {
            await plansService.loadPublishedPlans()
            await plansService.loadContinueCard()
            // Load progress + days for the first/free plan so we can
            // synthesize a Continue card if the RPC didn't return one.
            if let firstPlan = plansService.publishedPlans.first(where: { $0.isFreeEntry })
                ?? plansService.publishedPlans.first {
                if plansService.daysByPlan[firstPlan.id] == nil {
                    await plansService.loadDays(planId: firstPlan.id)
                }
                await plansService.loadProgress(planId: firstPlan.id)
            }
        }
    }

    /// When `get_continue_card` returns nothing — OR returns a card for
    /// a pastor plan that the home Continue slot can't open — derive
    /// the next undone day of a global plan locally so the section
    /// still flips from "Start" to "Continue."
    private var synthContinuePlan: (plan: BiblePlan, day: PlanDayFull)? {
        let cardOpensable = plansService.continueCard
            .flatMap { card in
                plansService.publishedPlans.first(where: { $0.id == card.planId }) != nil ? card : nil
            }
        guard cardOpensable == nil else { return nil }

        // Prefer the free-entry plan; fall back to first published.
        guard let plan = plansService.publishedPlans.first(where: { $0.isFreeEntry })
            ?? plansService.publishedPlans.first else { return nil }

        let days = plansService.daysByPlan[plan.id] ?? []
        let progress = plansService.progressByPlan[plan.id] ?? []
        let hasAnyProgress = progress.contains { $0.dayComplete || !$0.stepsCompleted.isEmpty }
        guard hasAnyProgress else { return nil }

        // Find first day that isn't fully complete.
        let progressByDay = Dictionary(uniqueKeysWithValues: progress.map { ($0.dayNumber, $0) })
        let nextDay = days.first(where: { d in
            let p = progressByDay[d.dayNumber]
            return !(p?.dayComplete ?? false)
        }) ?? days.first
        guard let nextDay else { return nil }
        return (plan, nextDay)
    }
}

// MARK: - Continue Live Card

struct ContinueLiveCard: View {
    let card: ContinueCard
    let onTap: () -> Void

    var gradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: card.planGradientFrom), Color(hex: card.planGradientTo)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    /// Plan-level progress (not within-day step progress). Days the user
    /// has already finished count as 1.0; the current day contributes a
    /// fractional slice based on which of the 5 steps they've completed,
    /// so the bar advances smoothly across both day-changes and steps.
    var progress: Double {
        guard card.daysTotal > 0 else { return 0 }
        let completedDays = max(0, card.dayNumber - 1)
        let currentDayFraction = Double(card.stepsCompleted.count) / 5.0
        return min(1.0, (Double(completedDays) + currentDayFraction) / Double(card.daysTotal))
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(gradient)
                        .frame(width: 64, height: 80)
                        .overlay {
                            RadialGradient(
                                colors: [.white.opacity(0.3), .clear],
                                center: .init(x: 0.3, y: 0.3),
                                startRadius: 0,
                                endRadius: 40
                            )
                        }

                    VStack {
                        Text("\(card.dayNumber)")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Spacer()

                        Text(card.planTitle.uppercased())
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                            .tracking(0.5)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 6)
                    .frame(height: 80)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(card.dayTitle)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(YGColors.ink)
                        .lineLimit(1)

                    Text("Day \(card.dayNumber) of \(card.daysTotal) · \(card.scriptureReference)")
                        .font(.system(size: 12.5))
                        .foregroundStyle(YGColors.ink.opacity(0.55))
                        .lineLimit(1)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(YGColors.ink.opacity(0.08))

                            Rectangle()
                                .fill(gradient)
                                .frame(width: geometry.size.width * progress)
                        }
                    }
                    .frame(height: 5)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .padding(.top, 6)
                }

                Spacer()

                Circle()
                    .fill(YGColors.ink)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: card.isResume ? "play.fill" : "arrow.right")
                            .font(.system(size: 12))
                            .foregroundStyle(.white)
                    }
            }
            .padding(16)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(Color.black.opacity(0.04), lineWidth: 0.5)
            }
            .shadow(color: YGColors.ink.opacity(0.06), radius: 8)
        }
    }
}

// MARK: - Get Started Card
//
// Empty-state card for users who haven't begun a plan. Big, animated, hard
// to miss — taps fire `onStart` which opens Day 1 of the first plan (John 1).

struct GetStartedCard: View {
    var title: String = "START"
    var subtitle: String = "Begin with John 1"
    var showSparkle: Bool = true
    let onStart: () -> Void
    @State private var pulse = false

    var body: some View {
        Button(action: onStart) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.95), Color.white.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .shadow(color: .white.opacity(0.4), radius: pulse ? 14 : 6, y: 0)

                    Image(systemName: "play.fill")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(YGColors.violetDeep)
                        .offset(x: 2)
                }
                .scaleEffect(pulse ? 1.04 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulse)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .tracking(1)
                        if showSparkle {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(YGColors.yellow)
                        }
                    }

                    Text(subtitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: [YGColors.violet, YGColors.pink],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
            }
            .shadow(color: YGColors.violet.opacity(0.4), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
        .onAppear { pulse = true }
    }
}

// MARK: - Custom Plan Row

struct CustomPlanRow: View {
    let title: String
    let subtitle: String
    let color: Color
    var dark: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(color)
                .frame(width: 4, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14.5, weight: .bold, design: .rounded))
                    .foregroundStyle(dark ? .white : YGColors.ink)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(dark ? Color.white.opacity(0.6) : YGColors.ink.opacity(0.55))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(dark ? Color.white.opacity(0.4) : YGColors.ink.opacity(0.3))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Garden Preview Card

struct GardenPreviewCard: View {
    @Environment(AppState.self) var appState

    var itemNeedingWater: GardenItem? {
        appState.gardenItems
            .filter { $0.stage < 5 }
            .max(by: { $0.watersCompleted < $1.watersCompleted })
    }

    func sizeForStage(_ stage: Int, species: String) -> CGFloat {
        let scale: CGFloat = 0.2
        let isSmallPlant = ["lavender", "wheat", "sunflower", "tulip"].contains(species)
        let isBush = ["mustard", "rose"].contains(species)

        if isSmallPlant {
            switch stage {
            case 1: return 32 * scale
            case 2: return 44 * scale
            case 3: return 54 * scale
            case 4: return 64 * scale
            default: return 64 * scale
            }
        } else if isBush {
            switch stage {
            case 1: return 48 * scale
            case 2: return 60 * scale
            case 3: return 72 * scale
            case 4: return 84 * scale
            case 5: return 96 * scale
            case 6: return 104 * scale
            case 7: return 112 * scale
            default: return 112 * scale
            }
        } else {
            switch stage {
            case 1: return 64 * scale
            case 2: return 88 * scale
            case 3: return 112 * scale
            case 4: return 144 * scale
            case 5: return 176 * scale
            case 6: return 208 * scale
            case 7: return 240 * scale
            case 8: return 264 * scale
            case 9: return 292 * scale
            case 10: return 320 * scale
            default: return 96 * scale
            }
        }
    }

    func scalePositionForCard(_ position: CGPoint, containerWidth: CGFloat) -> CGPoint {
        let scale: CGFloat = 0.2
        let centerOffset = containerWidth * 2.5
        return CGPoint(
            x: position.x * scale + centerOffset,
            y: position.y * scale
        )
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ZStack {
                    PixelGarden()
                    ForEach(appState.gardenItems) { item in
                        PixelTree(size: sizeForStage(item.stage, species: item.type), stage: item.currentStage, species: item.type, isBloom: item.isInBloom)
                            .position(scalePositionForCard(item.position, containerWidth: geometry.size.width))
                    }
                }
                .frame(width: geometry.size.width * 5, height: 800)
                .scaleEffect(0.2)
                .offset(y: -10)
                .frame(width: geometry.size.width, height: 140)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .shadow(color: YGColors.ink.opacity(0.06), radius: 8)
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(Color.black.opacity(0.04), lineWidth: 0.5)
                }

                VStack {
                    HStack {
                        Text("MY GARDEN")
                            .font(.lilitaOne(size: 16))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)

                    Spacer()

                    if let item = itemNeedingWater {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(item.displayName.uppercased()) · STAGE \(item.stage) OF 5")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(YGColors.lime)
                                .tracking(0.5)

                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.15))
                                        .frame(height: 4)

                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                colors: [YGColors.lime, YGColors.yellow],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geometry.size.width * item.progress, height: 4)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                            }
                            .frame(height: 4)

                            Text("Water \(item.watersUntilNext) more times to \(item.stage == 4 ? "bloom" : "grow") 🌸")
                                .font(.system(size: 10.5))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        .padding(10)
                        .background(Color.black.opacity(0.7))
                        .background(.ultraThinMaterial.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                    } else {
                        VStack(spacing: 6) {
                            Text(appState.gardenItems.isEmpty ? "🌱" : "🌿")
                                .font(.system(size: 32))
                            Text(appState.gardenItems.isEmpty ? "Start Your Garden" : "Grow Your Garden")
                                .font(.lilitaOne(size: 16))
                                .foregroundStyle(.white)
                            Text("Tap to visit the store")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(12)
                        .background(Color.black.opacity(0.7))
                        .background(.ultraThinMaterial.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                    }
                }
            }
        }
        .frame(height: 140)
    }
}

#Preview {
    PlansHomeView()
        .environment(AppState())
}
