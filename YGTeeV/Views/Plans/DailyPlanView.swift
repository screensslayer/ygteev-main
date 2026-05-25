//
//  DailyPlanView.swift
//  YGTeeV
//
//  Wired to Supabase: loads plan-day content + persists step progress via RPC.
//

import SwiftUI
import Supabase

// MARK: - Step Colors

enum StepColor {
    case read, study, apply, memorize, pray

    var color: Color {
        switch self {
        case .read:     return .white
        case .study:    return Color(hex: "7FCBFF")
        case .apply:    return Color(hex: "FFB13D")
        case .memorize: return Color(hex: "FFD60A")
        case .pray:     return Color(hex: "C8B5FF")
        }
    }

    var label: String {
        switch self {
        case .read:     return "READ"
        case .study:    return "STUDY"
        case .apply:    return "APPLY"
        case .memorize: return "MEMORIZE"
        case .pray:     return "PRAY"
        }
    }

    static func from(_ step: PlanStep) -> StepColor {
        switch step {
        case .read:     return .read
        case .study:    return .study
        case .apply:    return .apply
        case .memorize: return .memorize
        case .pray:     return .pray
        }
    }
}

// MARK: - DailyPlanView

struct DailyPlanView: View {
    let planId: UUID
    var onDismiss: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var dayId: UUID
    @State private var currentStepIndex = 0
    @State private var showXPAnimation = false
    @State private var earnedXP = 0
    @State private var xpTriggerCount = 0
    @State private var lastResult: StepCompletionResult?
    @State private var showCompletion = false
    @State private var submittingStep: PlanStep?
    @State private var showDayPicker = false
    @State private var isContinuingToNextDay = false
    /// Running totals for the in-progress day so the completion screen
    /// can show the real cumulative day XP/water instead of just the
    /// final step's daily-bonus value (which the server returns).
    /// Reset whenever the user opens a new day; seeded from any
    /// existing progress on resume.
    @State private var dayXpAccum: Int = 0
    @State private var dayWaterAccum: Int = 0

    init(planId: UUID, dayId: UUID, onDismiss: (() -> Void)? = nil) {
        self.planId = planId
        self.onDismiss = onDismiss
        self._dayId = State(initialValue: dayId)
    }

    private let plansService = PlansService.shared
    private let supabase = SupabaseManager.shared

    private let allSteps: [PlanStep] = [.read, .study, .apply, .memorize, .pray]

    private var day: PlanDayFull? {
        plansService.daysByPlan[planId]?.first(where: { $0.id == dayId })
    }

    private var progress: UserPlanProgress? {
        plansService.progressByPlan[planId]?.first(where: { $0.dayId == dayId })
    }

    /// The UUID of the day immediately after the current one (sorted by day_number),
    /// or nil if the current day is the last one in the plan.
    private var nextDayId: UUID? {
        guard let days = plansService.daysByPlan[planId], let current = day else { return nil }
        let sorted = days.sorted { $0.dayNumber < $1.dayNumber }
        return sorted.first(where: { $0.dayNumber > current.dayNumber })?.id
    }

    private var completedSteps: Set<PlanStep> {
        progress?.stepsDone ?? []
    }

    private var currentStep: PlanStep { allSteps[currentStepIndex] }

    private var completionPercent: Int {
        Int((Double(completedSteps.count) / 5.0) * 100)
    }

    var body: some View {
        ZStack {
            Color(hex: "0A0712").ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(hex: "BFE6F5"),
                    Color(hex: "7BB8D6"),
                    Color(hex: "2A3A4D"),
                    Color(hex: "0A0712")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(0.55)
            .frame(height: 320)
            .frame(maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                progressBar

                if let day = day {
                    TabView(selection: $currentStepIndex) {
                        ReadStepView(
                            section: day.sections.read,
                            isLocked: completedSteps.contains(.read),
                            isSubmitting: submittingStep == .read,
                            onSubmit: { picks in await submit(.read, answers: [
                                "part_answers": .array(picks.map { .integer($0) })
                            ]) },
                            onXPEarned: { amount in flashXP(amount) }
                        )
                        .tag(0)

                        StudyStepView(
                            section: day.sections.study,
                            isLocked: completedSteps.contains(.study),
                            isSubmitting: submittingStep == .study,
                            onSubmit: { pick in await submit(.study, answers: [
                                "answer": .integer(pick)
                            ]) },
                            onXPEarned: { amount in flashXP(amount) }
                        )
                        .tag(1)

                        ApplyStepView(
                            section: day.sections.apply,
                            isLocked: completedSteps.contains(.apply),
                            isSubmitting: submittingStep == .apply,
                            onSubmit: { pick in await submit(.apply, answers: [
                                "selected_challenge_index": .integer(pick)
                            ]) }
                        )
                        .tag(2)

                        MemorizeStepView(
                            section: day.sections.memorize,
                            isLocked: completedSteps.contains(.memorize),
                            isSubmitting: submittingStep == .memorize,
                            onSubmit: { passed in await submit(.memorize, answers: [
                                "passed": .bool(passed)
                            ]) }
                        )
                        .tag(3)

                        PrayStepView(
                            section: day.sections.pray,
                            isLocked: completedSteps.contains(.pray),
                            isSubmitting: submittingStep == .pray,
                            onSubmit: { await submit(.pray, answers: [:]) }
                        )
                        .tag(4)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    // Force every step view to be recreated when the user
                    // switches to a different day: resets all @State (picks,
                    // attempts, fetched verses, scroll position, etc).
                    .id(dayId)
                } else {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                    Spacer()
                }
            }

            if showXPAnimation {
                XPFlyingAnimation(xpAmount: earnedXP)
                    .id(xpTriggerCount)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .task(id: dayId) {
            // Refetch when the cached array is nil OR the target dayId
            // isn't in whatever's cached — covers the case where days
            // were loaded for an older snapshot of the plan and the
            // user opened a newly-published day that wasn't on disk.
            let cached = plansService.daysByPlan[planId]
            let hasThisDay = cached?.contains(where: { $0.id == dayId }) == true
            if cached == nil || !hasThisDay {
                print("[DailyPlanView] cache miss for day=\(dayId.uuidString.lowercased()), reloading days")
                await plansService.loadDays(planId: planId)
            }
            await plansService.loadProgress(planId: planId)
            if plansService.daysByPlan[planId]?.contains(where: { $0.id == dayId }) != true {
                print("[DailyPlanView] WARNING day=\(dayId.uuidString.lowercased()) not in loaded plan=\(planId.uuidString.lowercased()); spinner will hang")
            }
            // Seed the per-day accumulators from any already-recorded
            // server XP so a resumed day still totals correctly.
            dayXpAccum = progress?.dayXpEarned ?? 0
            dayWaterAccum = 0

            // Advance past already-completed steps for a smoother resume.
            // Reruns when dayId changes (e.g. switching days via the day picker).
            if let prog = progress {
                if let firstUndone = allSteps.firstIndex(where: { !prog.stepsDone.contains($0) }) {
                    currentStepIndex = firstUndone
                } else {
                    currentStepIndex = 0
                }
            } else {
                currentStepIndex = 0
            }
        }
        .fullScreenCover(isPresented: $showCompletion, onDismiss: {
            // If the user tapped "Continue Plan", we stay in DailyPlanView and
            // just swap the day; the X button (or any other dismiss path) falls
            // through to the parent onDismiss to return to the plans list.
            if isContinuingToNextDay {
                isContinuingToNextDay = false
                return
            }
            onDismiss?()
        }) {
            if let result = lastResult, let day = day {
                PlanCompletionView(
                    result: result,
                    dayNumber: day.dayNumber,
                    // Only show "Continue Plan" if there's a next day to go to
                    // AND the plan isn't fully complete.
                    onContinueNextDay: (!result.planCompleted && nextDayId != nil) ? {
                        if let next = nextDayId {
                            isContinuingToNextDay = true
                            dayId = next
                            showCompletion = false
                        }
                    } : nil
                )
            }
        }
        .sheet(isPresented: $showDayPicker) {
            DayPickerSheet(
                planId: planId,
                currentDayId: dayId,
                onPickDay: { newDayId in
                    showDayPicker = false
                    guard newDayId != dayId else { return }
                    // Switch day; reset transient step state.
                    dayId = newDayId
                    currentStepIndex = 0
                    submittingStep = nil
                    Task {
                        await plansService.loadProgress(planId: planId)
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(alignment: .center) {
            Button {
                onDismiss?()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "140E28").opacity(0.55))
                        .frame(width: 38, height: 38)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                        }

                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }

            Spacer()

            Button {
                showDayPicker = true
            } label: {
                HStack(spacing: 6) {
                    Text(day?.title ?? "Loading…")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .lineLimit(1)
                    if let day = day {
                        Text("·")
                            .opacity(0.5)
                        Text(day.scriptureReference)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .opacity(0.7)
                            .lineLimit(1)
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .opacity(0.7)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(hex: "140E28").opacity(0.55))
                .background(.ultraThinMaterial.opacity(0.3))
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "FFD60A"))
                Text("\(supabase.currentUser?.xp ?? 0)")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: "FFD60A"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(Array(allSteps.enumerated()), id: \.offset) { idx, step in
                RoundedRectangle(cornerRadius: 2)
                    .fill(segmentColor(for: idx, step: step))
                    .frame(height: 4)
                    .shadow(color: completedSteps.contains(step) ? Color(hex: "B4FF3C").opacity(0.5) : .clear, radius: 4)
            }

            Text("\(completionPercent)%")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(minWidth: 36)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private func segmentColor(for index: Int, step: PlanStep) -> Color {
        if completedSteps.contains(step) {
            return Color(hex: "B4FF3C")
        } else if index == currentStepIndex {
            return .white
        } else {
            return .white.opacity(0.18)
        }
    }

    /// Trigger the floating yellow XP card (gaming-style feedback) without
    /// touching the user's actual XP — that's still server-authoritative.
    /// Uses `xpTriggerCount` as a unique view identity so back-to-back calls
    /// re-fire the animation instead of being deduped.
    private func flashXP(_ amount: Int) {
        earnedXP = amount
        xpTriggerCount += 1
        showXPAnimation = true
        let snapshot = xpTriggerCount
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            // Only hide if no newer flash came in.
            if xpTriggerCount == snapshot {
                showXPAnimation = false
            }
        }
    }

    // MARK: - Submit

    private func submit(_ step: PlanStep, answers: [String: AnyJSON]) async {
        guard submittingStep == nil else { return }
        submittingStep = step
        defer { submittingStep = nil }

        do {
            var result = try await plansService.completeStep(
                planId: planId, dayId: dayId, step: step, answers: answers
            )

            // Accumulate step rewards so the completion screen reports
            // the true day total instead of just the final step's
            // server response. Skip when the step was already
            // completed — the server returns 0s for those.
            if !result.alreadyCompleted {
                dayXpAccum    += result.stepXp
                dayWaterAccum += result.stepWater
            }

            // Show XP toast only for non-already-completed steps with earned XP.
            if !result.alreadyCompleted, result.totalXpAwarded > 0 {
                earnedXP = result.totalXpAwarded
                showXPAnimation = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    showXPAnimation = false
                }
            }

            if result.dayNowComplete {
                // Overlay the locally-accumulated totals — the server's
                // total_xp_awarded for the final step undercounts the
                // step XP earned across the day. Adding the rest of
                // the bonuses (daily / milestone / plan completion)
                // back on top gives the correct grand total. Water
                // gets the same treatment for symmetry.
                let fullXp = dayXpAccum
                    + result.dailyBonusXp
                    + result.milestoneXp
                    + result.planCompletionXp
                let fullWater = dayWaterAccum
                    + result.dailyBonusWater
                    + result.milestoneWater
                    + result.planCompletionWater
                result.totalXpAwarded = max(result.totalXpAwarded, fullXp)
                result.totalWaterAwarded = max(result.totalWaterAwarded, fullWater)

                lastResult = result
                // Tiny delay so the XP toast finishes first.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    showCompletion = true
                }
            } else if currentStepIndex < allSteps.count - 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation { currentStepIndex += 1 }
                }
            }
        } catch {
            print("[DailyPlanView] submit error:", error)
        }
    }
}

// MARK: - Step Container

private struct StepShell<Content: View>: View {
    let stepNumber: Int
    let stepColor: StepColor
    let title: String
    let subtitle: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                StepHeaderView(stepNumber: stepNumber, stepColor: stepColor, title: title, subtitle: subtitle)
                    .padding(.bottom, 8)

                content()
                    .padding(.horizontal, 24)
                    .padding(.bottom, 140)
            }
        }
    }
}

struct StepHeaderView: View {
    let stepNumber: Int
    let stepColor: StepColor
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("\(stepNumber)")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: "0A0712"))
                    .frame(width: 18, height: 18)
                    .background(stepColor.color)
                    .clipShape(Circle())

                Text(stepColor.label)
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.5)
                    .foregroundStyle(stepColor.color)
            }

            Text(title)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
}

// MARK: - Read Step

private struct ReadStepView: View {
    let section: ReadSection
    let isLocked: Bool
    let isSubmitting: Bool
    let onSubmit: ([Int]) async -> Void
    let onXPEarned: (Int) -> Void

    @State private var currentPart = 0
    @State private var picks: [Int: Int] = [:]
    @State private var versesByPart: [Int: [BibleVerse]] = [:]
    @State private var loadingParts: Set<Int> = []
    @State private var bouncePart: Int = -1
    @State private var attemptsByPart: [Int: Int] = [:]
    @State private var revealedParts: Set<Int> = []
    @State private var didInitLockedState = false

    private var currentPick: Int? { picks[currentPart] }
    private var currentIsCorrect: Bool {
        guard let pick = currentPick else { return false }
        return pick == section.parts[currentPart].correctIndex
    }
    private var allDone: Bool {
        // "Done" = either correctly answered OR revealed-after-two-wrongs.
        section.parts.indices.allSatisfy { idx in
            picks[idx] == section.parts[idx].correctIndex || revealedParts.contains(idx)
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    StepHeaderView(stepNumber: 1, stepColor: .read, title: "Read & Reflect", subtitle: nil)
                        .padding(.bottom, 8)
                        .id("step-top")

                    VStack(spacing: 16) {
                        // Part carousel
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(section.parts.enumerated()), id: \.offset) { idx, part in
                            PartTab(
                                index: idx,
                                reference: part.verses,
                                isActive: idx == currentPart,
                                isDone: picks[idx] == part.correctIndex
                            )
                            .onTapGesture {
                                guard !isSubmitting else { return }
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    currentPart = idx
                                }
                                ensureVersesLoaded(for: idx)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }

                // Dark verses card
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(section.parts[currentPart].verses)
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(.white.opacity(0.55))
                            .tracking(1)

                        Spacer()

                        Circle()
                            .fill(.white.opacity(0.08))
                            .frame(width: 30, height: 30)
                            .overlay {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                    }

                    if loadingParts.contains(currentPart) && (versesByPart[currentPart]?.isEmpty ?? true) {
                        HStack { Spacer(); ProgressView().tint(.white); Spacer() }
                            .padding(.vertical, 20)
                    } else if let verses = versesByPart[currentPart], !verses.isEmpty {
                        ForEach(verses) { verse in
                            HStack(alignment: .firstTextBaseline, spacing: 14) {
                                Text("\(verse.number)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.45))
                                    .frame(minWidth: 18, alignment: .leading)

                                Text(cleanVerseText(verse.text))
                                    .font(.system(size: 18))
                                    .foregroundStyle(.white)
                                    .lineSpacing(6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    } else {
                        Text("Couldn't load verses. Tap a part to retry.")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.55))
                            .padding(.vertical, 8)
                    }
                }
                .padding(18)
                .background(Color.black.opacity(0.4))
                .background(.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                }

                // Quick Check card (white)
                QuickCheckCard(
                    question: section.parts[currentPart].question,
                    options: section.parts[currentPart].options,
                    correctIndex: section.parts[currentPart].correctIndex,
                    pickedIndex: currentPick,
                    bounce: bouncePart == currentPart,
                    revealedAnswer: revealedParts.contains(currentPart),
                    onPick: { idx in
                        guard !isLocked, !isSubmitting else { return }
                        guard !revealedParts.contains(currentPart) else { return }
                        let alreadyCorrect = picks[currentPart] == section.parts[currentPart].correctIndex
                        guard !alreadyCorrect else { return }

                        let newAttempts = (attemptsByPart[currentPart] ?? 0) + 1
                        attemptsByPart[currentPart] = newAttempts
                        picks[currentPart] = idx

                        let correct = idx == section.parts[currentPart].correctIndex

                        if correct {
                            // Correct on either 1st or 2nd attempt → award XP, advance.
                            SoundManager.shared.playCorrectAnswer()
                            bouncePart = currentPart
                            onXPEarned(10)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                bouncePart = -1
                                advanceToNextPart(proxy: proxy)
                            }
                        } else if newAttempts >= 2 {
                            // Second wrong → reveal, no XP, advance after a beat.
                            SoundManager.shared.playWrongAnswer()
                            revealedParts.insert(currentPart)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                                advanceToNextPart(proxy: proxy)
                            }
                        } else {
                            // First wrong → let user try again.
                            SoundManager.shared.playWrongAnswer()
                        }
                    }
                )

                if isSubmitting {
                    HStack { Spacer(); ProgressView().tint(.white); Spacer() }
                        .padding(.top, 8)
                }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 140)
                }
            }
            .onChange(of: currentPart) { _, _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo("step-top", anchor: .top)
                }
            }
        }
        .task {
            ensureVersesLoaded(for: 0)
        }
        .onAppear {
            // If the step is already completed (revisiting a finished day),
            // pre-populate every part with its correct answer so the user
            // sees what they previously did and can't re-earn XP.
            if isLocked && !didInitLockedState {
                for (idx, part) in section.parts.enumerated() {
                    picks[idx] = part.correctIndex
                }
                didInitLockedState = true
            }
        }
        .onChange(of: allDone) { _, done in
            guard done, !isSubmitting, !isLocked else { return }
            // Auto-submit after a short delay so the last bounce/sound finishes first.
            Task {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                let ordered = section.parts.indices.map { picks[$0] ?? -1 }
                await onSubmit(ordered)
            }
        }
    }

    /// Advance to the next un-completed (un-correct AND un-revealed) part.
    private func advanceToNextPart(proxy: ScrollViewProxy) {
        let nextNeedingAnswer = section.parts.indices.first { idx in
            picks[idx] != section.parts[idx].correctIndex && !revealedParts.contains(idx)
        }
        if let next = nextNeedingAnswer {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentPart = next
                proxy.scrollTo("step-top", anchor: .top)
            }
            ensureVersesLoaded(for: next)
        }
    }

    private func ensureVersesLoaded(for index: Int) {
        guard versesByPart[index] == nil, !loadingParts.contains(index) else { return }
        let reference = section.parts[index].verses
        loadingParts.insert(index)
        Task {
            do {
                let fetched = try await BibleAPIService.shared.versesForReference(reference)
                await MainActor.run {
                    versesByPart[index] = fetched
                    loadingParts.remove(index)
                }
            } catch {
                print("[ReadStepView] versesForReference \(reference) error:", error)
                await MainActor.run {
                    versesByPart[index] = []
                    loadingParts.remove(index)
                }
            }
        }
    }

    /// Strip leading verse-number markers like "[1]" or "1 " that some Bible API responses include.
    private func cleanVerseText(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Remove a leading bracketed number e.g. "[1] " or "[1]\u{00A0}"
        if s.hasPrefix("[") {
            if let close = s.firstIndex(of: "]") {
                s = String(s[s.index(after: close)...]).trimmingCharacters(in: .whitespaces)
            }
        }
        // Remove a leading bare number followed by whitespace e.g. "1 Paul..."
        if let firstSpace = s.firstIndex(where: { $0.isWhitespace }) {
            let prefix = s[..<firstSpace]
            if Int(prefix) != nil {
                s = String(s[s.index(after: firstSpace)...])
            }
        }
        return s
    }
}

// MARK: - Part Tab (carousel)

private struct PartTab: View {
    let index: Int
    let reference: String
    let isActive: Bool
    let isDone: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if isDone {
                    Circle()
                        .fill(Color(hex: "B4FF3C"))
                        .frame(width: 14, height: 14)
                        .overlay {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundStyle(Color(hex: "0A0712"))
                        }
                } else {
                    Circle()
                        .fill(isActive ? Color(hex: "0A0712") : .white.opacity(0.18))
                        .frame(width: 14, height: 14)
                        .overlay {
                            Text("\(index + 1)")
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .foregroundStyle(isActive ? .white : .white.opacity(0.7))
                        }
                }

                Text("PART \(index + 1)")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.5)
                    .foregroundStyle(isActive ? Color(hex: "0A0712").opacity(0.7) : .white.opacity(0.85))
            }

            Text(reference)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(isActive ? Color(hex: "0A0712") : .white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minWidth: 140, alignment: .leading)
        .background(
            isActive ? AnyShapeStyle(.white)
            : isDone ? AnyShapeStyle(Color(hex: "B4FF3C").opacity(0.12))
            : AnyShapeStyle(Color.white.opacity(0.06))
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(isActive ? 0 : 0.08), lineWidth: 0.5)
        }
    }
}

// MARK: - Quick Check Card

private struct QuickCheckCard: View {
    let question: String
    let options: [String]
    let correctIndex: Int
    let pickedIndex: Int?
    let bounce: Bool
    /// True when the answer should be force-shown (either the step was already
    /// completed before, or the user failed twice and the correct answer is revealed).
    /// In either case the card is locked and no XP is awarded.
    var revealedAnswer: Bool = false
    let onPick: (Int) -> Void

    private func optionLetter(_ idx: Int) -> String {
        String(UnicodeScalar(65 + idx)!) // A, B, C, …
    }

    private func tint(for idx: Int) -> (background: Color, border: Color, showCheck: Bool, showX: Bool) {
        let unselectedBg = Color(hex: "F2F2F7")
        let isCorrect = idx == correctIndex
        let isPicked = pickedIndex == idx

        if revealedAnswer {
            // Force-display the correct answer; if the user's last pick was wrong, also keep the red X.
            if isCorrect {
                return (Color(hex: "B4FF3C"), Color(hex: "B4FF3C"), true, false)
            }
            if isPicked && !isCorrect {
                return (Color.red.opacity(0.15), Color.red.opacity(0.5), false, true)
            }
            return (unselectedBg, .clear, false, false)
        }

        guard let _ = pickedIndex else {
            return (unselectedBg, .clear, false, false)
        }
        if isPicked && isCorrect {
            return (Color(hex: "B4FF3C"), Color(hex: "B4FF3C"), true, false)
        }
        if isPicked && !isCorrect {
            return (Color.red.opacity(0.15), Color.red.opacity(0.5), false, true)
        }
        return (unselectedBg, .clear, false, false)
    }

    private var isLocked: Bool {
        revealedAnswer || (pickedIndex != nil && pickedIndex == correctIndex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text("QUICK CHECK")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.5)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: "0A0712"))
                    .clipShape(Capsule())

                Text("+10 PTS")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(Color(hex: "0A0712").opacity(0.45))
            }

            Text(question)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(Color(hex: "0A0712"))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 2)

            VStack(spacing: 10) {
                ForEach(Array(options.enumerated()), id: \.offset) { idx, option in
                    let tints = tint(for: idx)
                    let isPickedCorrect = pickedIndex == idx && idx == correctIndex
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(.white)
                                .frame(width: 34, height: 34)
                            Circle()
                                .strokeBorder(Color(hex: "0A0712").opacity(0.15), lineWidth: 1)
                                .frame(width: 34, height: 34)
                            Text(optionLetter(idx))
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color(hex: "0A0712"))
                        }

                        Text(option)
                            .font(.system(size: 15))
                            .foregroundStyle(Color(hex: "0A0712"))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if tints.showCheck {
                            Image(systemName: "checkmark")
                                .font(.system(size: 18, weight: .heavy))
                                .foregroundStyle(Color(hex: "0A0712"))
                        } else if tints.showX {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .heavy))
                                .foregroundStyle(Color.red)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(tints.background)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(tints.border, lineWidth: 1.5)
                    }
                    .scaleEffect(isPickedCorrect && bounce ? 1.04 : 1.0)
                    .animation(.spring(response: 0.35, dampingFraction: 0.5), value: bounce)
                    .contentShape(RoundedRectangle(cornerRadius: 14))
                    .onTapGesture {
                        guard !isLocked else { return }
                        onPick(idx)
                    }
                }
            }
        }
        .padding(18)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
    }
}

// MARK: - Study Step

private struct StudyStepView: View {
    let section: StudySection
    let isLocked: Bool
    let isSubmitting: Bool
    let onSubmit: (Int) async -> Void
    let onXPEarned: (Int) -> Void

    @State private var pick: Int?
    @State private var bounce = false
    @State private var attempts = 0
    @State private var revealed = false
    @State private var didInitLockedState = false

    private var isCorrect: Bool {
        pick != nil && pick == section.correctIndex
    }

    private var isDone: Bool {
        isCorrect || revealed
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    StepHeaderView(stepNumber: 2, stepColor: .study, title: "Study", subtitle: nil)
                        .padding(.bottom, 8)
                        .id("step-top")

                    VStack(spacing: 16) {
                        // Commentary card
                        Text(section.commentary)
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineSpacing(5)
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18)
                                    .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                            }

                        // Quick Check card (same component used by Read step)
                        QuickCheckCard(
                            question: section.question,
                            options: section.options,
                            correctIndex: section.correctIndex,
                            pickedIndex: pick,
                            bounce: bounce,
                            revealedAnswer: revealed,
                            onPick: { idx in
                                guard !isLocked, !isSubmitting else { return }
                                guard !revealed else { return }
                                let alreadyCorrect = pick == section.correctIndex
                                guard !alreadyCorrect else { return }

                                attempts += 1
                                pick = idx
                                let correct = idx == section.correctIndex

                                if correct {
                                    SoundManager.shared.playCorrectAnswer()
                                    bounce = true
                                    onXPEarned(10)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                        bounce = false
                                    }
                                } else if attempts >= 2 {
                                    SoundManager.shared.playWrongAnswer()
                                    revealed = true
                                } else {
                                    // First wrong → let user try again.
                                    SoundManager.shared.playWrongAnswer()
                                }
                            }
                        )

                        if isSubmitting {
                            HStack { Spacer(); ProgressView().tint(.white); Spacer() }
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 140)
                }
            }
        }
        .onAppear {
            // Revisiting a previously completed step: show the correct answer.
            if isLocked && !didInitLockedState {
                pick = section.correctIndex
                didInitLockedState = true
            }
        }
        .onChange(of: isDone) { _, done in
            // Auto-submit once the user is finished — whether by getting it right
            // OR by hitting two wrongs and having the answer revealed (no XP path).
            // Locked / already-submitting paths short-circuit.
            guard done, !isSubmitting, !isLocked else { return }
            Task {
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                // Send whichever pick the user landed on (correct or wrong) so the
                // server can grade and award 0 XP if the answer was wrong.
                let payload = pick ?? section.correctIndex
                await onSubmit(payload)
            }
        }
    }
}

// MARK: - Apply Step

private struct ApplyStepView: View {
    let section: ApplySection
    let isLocked: Bool
    let isSubmitting: Bool
    let onSubmit: (Int) async -> Void

    @State private var pick: Int?

    var body: some View {
        StepShell(stepNumber: 3, stepColor: .apply, title: "Live it out", subtitle: "Pick one challenge you'll try this week.") {
            VStack(spacing: 12) {
                ForEach(Array(section.challenges.enumerated()), id: \.offset) { idx, challenge in
                    Button {
                        guard !isLocked, !isSubmitting else { return }
                        pick = idx
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: pick == idx ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundStyle(pick == idx ? StepColor.apply.color : .white.opacity(0.4))
                            Text(challenge)
                                .font(.system(size: 15))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(16)
                        .background(.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(pick == idx ? StepColor.apply.color : .white.opacity(0.1), lineWidth: 1)
                        }
                    }
                }

                FinishStepButton(
                    label: "Commit",
                    color: StepColor.apply.color,
                    isLocked: isLocked,
                    isSubmitting: isSubmitting,
                    disabled: pick == nil
                ) {
                    if pick != nil { Task { await onSubmit(pick!) } }
                }
            }
        }
    }
}

// MARK: - Memorize Step

private struct MemorizeStepView: View {
    let section: MemorizeSection
    let isLocked: Bool
    let isSubmitting: Bool
    let onSubmit: (Bool) async -> Void

    @State private var revealed = false
    @State private var passed = false
    @State private var attempted = false
    /// Shuffled 3-word phrases the user taps to rebuild the verse.
    /// Indexed positionally so identical phrases (rare but possible)
    /// stay distinguishable.
    @State private var shuffledPhrases: [String] = []
    /// Indices into `shuffledPhrases`, in the order the user tapped them.
    @State private var pickedIndices: [Int] = []
    /// Correct phrase ordering — the original 3-word grouping.
    @State private var correctPhrases: [String] = []

    /// Peek charges + "currently un-blurred?" state. Each peek burns one
    /// charge and reveals the verse for 3 seconds via the Task below.
    @State private var peekCharges = 3
    @State private var isPeeking = false

    /// 3-word chunks, with the trailing chunk allowed to be 1 or 2 words
    /// so the verse always fits cleanly. Whitespace tokenization keeps
    /// punctuation glued to the word it follows.
    private func chunkIntoPhrases(_ text: String, size: Int = 3) -> [String] {
        let tokens = text.split(whereSeparator: { $0.isWhitespace }).map { String($0) }
        var out: [String] = []
        var i = 0
        while i < tokens.count {
            let end = min(i + size, tokens.count)
            out.append(tokens[i..<end].joined(separator: " "))
            i = end
        }
        return out
    }

    private var pickedText: String {
        pickedIndices.map { shuffledPhrases[$0] }.joined(separator: " ")
    }

    var body: some View {
        StepShell(stepNumber: 4, stepColor: .memorize, title: "Lock it in", subtitle: section.verseReference) {
            VStack(spacing: 16) {
                verseCard
                if revealed {
                    pickedCard
                    phrasePool
                    actionsRow
                    if attempted {
                        Text(passed ? "Nailed it ✨ +20 XP" : "Close — hit Reset and try again.")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(passed ? Color(hex: "B4FF3C") : .white.opacity(0.7))
                    }
                }

                // Skip-step button is gone — the only way out of this
                // step is to actually rebuild the verse and pass the
                // Check. Finish appears only after the user nails it.
                if attempted && passed {
                    FinishStepButton(
                        label: "Finish step",
                        color: StepColor.memorize.color,
                        isLocked: isLocked,
                        isSubmitting: isSubmitting,
                        disabled: false
                    ) {
                        Task { await onSubmit(true) }
                    }
                }
            }
        }
    }

    // MARK: - Verse card

    /// The verse card. Pre-reveal it shows the plain text with a "Hide
    /// & test me" CTA. Post-reveal it stays in place but blurred,
    /// with a Peek button that briefly un-blurs it on demand.
    @ViewBuilder
    private var verseCard: some View {
        VStack(spacing: 14) {
            Text(section.verseText)
                .font(.system(size: 17))
                .foregroundStyle(.white)
                .lineSpacing(5)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                // Only blur once the user has hidden the verse to test
                // themselves. The peek timer toggles `isPeeking` to
                // briefly drop the blur.
                .blur(radius: revealed && !isPeeking ? 8 : 0)
                .animation(.easeInOut(duration: 0.25), value: isPeeking)

            if !revealed {
                Button("Hide & test me") {
                    let phrases = chunkIntoPhrases(section.verseText)
                    correctPhrases = phrases
                    shuffledPhrases = phrases.shuffled()
                    pickedIndices = []
                    peekCharges = 3
                    isPeeking = false
                    revealed = true
                }
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: "0A0712"))
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(StepColor.memorize.color)
                .clipShape(Capsule())
            } else {
                peekButton
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var peekButton: some View {
        Button {
            Task { await runPeek() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 12, weight: .heavy))
                Text(peekCharges > 0 ? "Peek (\(peekCharges))" : "No peeks left")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(peekCharges > 0 && !isPeeking ? Color(hex: "0A0712") : .white.opacity(0.4))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background((peekCharges > 0 && !isPeeking) ? StepColor.memorize.color : .white.opacity(0.08))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(peekCharges <= 0 || isPeeking)
    }

    /// One peek = drop the blur for 3 seconds, then snap it back. The
    /// charge is decremented up-front so the button greys immediately.
    private func runPeek() async {
        guard peekCharges > 0, !isPeeking else { return }
        peekCharges -= 1
        isPeeking = true
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        isPeeking = false
    }

    // MARK: - Picked + pool (rendered below the verse card)

    /// Live preview of what the user has built so far, in order.
    private var pickedCard: some View {
        Text(pickedText.isEmpty ? "Tap the phrases below in order…" : pickedText)
            .font(.system(size: 16))
            .foregroundStyle(pickedText.isEmpty ? .white.opacity(0.4) : .white)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .padding(14)
            .background(.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    /// Phrase pool. Tapped phrases are greyed out, not removed — keeps
    /// the pool layout stable and prevents the "where did that pill go?"
    /// confusion.
    private var phrasePool: some View {
        FlowLayout(spacing: 8) {
            ForEach(shuffledPhrases.indices, id: \.self) { idx in
                let isUsed = pickedIndices.contains(idx)
                Button {
                    if !isUsed { pickedIndices.append(idx) }
                } label: {
                    Text(shuffledPhrases[idx])
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isUsed ? .white.opacity(0.35) : .white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isUsed ? .white.opacity(0.04) : .white.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isUsed)
            }
        }
    }

    private var actionsRow: some View {
        HStack {
            Button("Reset") {
                pickedIndices = []
                attempted = false
                passed = false
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white.opacity(0.7))

            Spacer()

            Button("Check") {
                let assembled = pickedIndices.map { shuffledPhrases[$0] }
                passed = assembled == correctPhrases
                attempted = true
            }
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(Color(hex: "0A0712"))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(StepColor.memorize.color)
            .clipShape(Capsule())
            .disabled(pickedIndices.count != correctPhrases.count)
            .opacity(pickedIndices.count == correctPhrases.count ? 1 : 0.5)
        }
    }
}

// MARK: - Pray Step

private struct PrayStepView: View {
    let section: PraySection
    let isLocked: Bool
    let isSubmitting: Bool
    let onSubmit: () async -> Void

    var body: some View {
        StepShell(stepNumber: 5, stepColor: .pray, title: "Quiet time", subtitle: nil) {
            VStack(spacing: 16) {
                Text(section.prayerText)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                    }

                FinishStepButton(
                    label: "Done",
                    color: StepColor.pray.color,
                    isLocked: isLocked,
                    isSubmitting: isSubmitting,
                    disabled: false
                ) {
                    Task { await onSubmit() }
                }
            }
        }
    }
}

// MARK: - Shared widgets

private struct AnswerButton: View {
    let text: String
    let isSelected: Bool
    let isCorrect: Bool?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                Spacer()
                if let isCorrect = isCorrect, isSelected {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(isCorrect ? Color(hex: "B4FF3C") : .red)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(isSelected ? 0.1 : 0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.1), lineWidth: isSelected ? 1.5 : 0.5)
            }
        }
    }
}

private struct FinishStepButton: View {
    let label: String
    let color: Color
    let isLocked: Bool
    let isSubmitting: Bool
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isSubmitting {
                    ProgressView().tint(Color(hex: "0A0712"))
                } else {
                    Text(isLocked ? "Done" : label)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "0A0712"))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color)
            .clipShape(Capsule())
        }
        .disabled(disabled || isSubmitting)
        .opacity(disabled ? 0.45 : 1)
    }
}

// MARK: - XP Flying Animation
//
// Gaming-style: a chunky yellow capsule pops in with a spring scale, floats
// upward toward the top-right XP counter, then fades out.

struct XPFlyingAnimation: View {
    let xpAmount: Int
    @State private var offset: CGSize = CGSize(width: 0, height: 0)
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.4
    @State private var wobble: Double = -6

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 16, weight: .heavy))
            Text("+\(xpAmount) XP")
                .font(.system(size: 20, weight: .black, design: .rounded))
        }
        .foregroundStyle(Color(hex: "0A0712"))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [Color(hex: "FFE45C"), Color(hex: "FFB13D")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.white.opacity(0.5), lineWidth: 1.5)
        }
        .shadow(color: Color(hex: "FFD60A").opacity(0.5), radius: 18, y: 6)
        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        .scaleEffect(scale)
        .rotationEffect(.degrees(wobble))
        .opacity(opacity)
        .offset(offset)
        .onAppear {
            // Pop in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                scale = 1.0
                opacity = 1
                wobble = 0
            }
            // Float up toward the XP counter (top-right)
            withAnimation(.easeOut(duration: 1.2).delay(0.2)) {
                offset = CGSize(width: 110, height: -260)
            }
            // Fade out at the end
            withAnimation(.easeIn(duration: 0.45).delay(1.05)) {
                opacity = 0
                scale = 0.7
            }
        }
    }
}

// MARK: - Flow layout (token grid)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let containerWidth = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0
        var rowWidth: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if rowWidth + size.width > containerWidth {
                totalHeight += rowHeight + spacing
                rowHeight = size.height
                rowWidth = size.width + spacing
            } else {
                rowHeight = max(rowHeight, size.height)
                rowWidth += size.width + spacing
            }
        }
        totalHeight += rowHeight
        return CGSize(width: containerWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Safe-index helper

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Day Picker Sheet

struct DayPickerSheet: View {
    let planId: UUID
    let currentDayId: UUID
    let onPickDay: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    private let plansService = PlansService.shared

    enum DayStatus { case done, inProgress, notStarted }

    private var days: [PlanDayFull] {
        plansService.daysByPlan[planId] ?? []
    }

    private var progressByDay: [Int: UserPlanProgress] {
        let rows = plansService.progressByPlan[planId] ?? []
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.dayNumber, $0) })
    }

    private func status(for day: PlanDayFull) -> DayStatus {
        if let row = progressByDay[day.dayNumber] {
            if row.dayComplete { return .done }
            if !row.stepsCompleted.isEmpty { return .inProgress }
        }
        return .notStarted
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 8) {
                    if days.isEmpty {
                        ProgressView()
                            .padding(.top, 40)
                    } else {
                        ForEach(days) { day in
                            DayRow(
                                day: day,
                                isCurrent: day.id == currentDayId,
                                status: status(for: day)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onPickDay(day.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .navigationTitle("All days")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .task {
            // Ensure days + progress are present so statuses render correctly.
            if plansService.daysByPlan[planId] == nil {
                await plansService.loadDays(planId: planId)
            }
            await plansService.loadProgress(planId: planId)
        }
    }
}

private struct DayRow: View {
    let day: PlanDayFull
    let isCurrent: Bool
    let status: DayPickerSheet.DayStatus

    private var statusColor: Color {
        switch status {
        case .done:       return .green
        case .inProgress: return .yellow
        case .notStarted: return Color.secondary.opacity(0.25)
        }
    }

    private var statusLabel: String {
        switch status {
        case .done:       return "Completed"
        case .inProgress: return "In progress"
        case .notStarted: return "Not started"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 36, height: 36)
                if status == .done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(day.dayNumber)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(status == .notStarted ? .secondary : .primary)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Day \(day.dayNumber) · \(day.title)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(statusLabel + " · " + day.scriptureReference)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isCurrent {
                Text("CURRENT")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.5)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(YGColors.violet)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(isCurrent ? YGColors.violet.opacity(0.08) : Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isCurrent ? YGColors.violet.opacity(0.4) : Color.clear, lineWidth: 1)
        }
    }
}

