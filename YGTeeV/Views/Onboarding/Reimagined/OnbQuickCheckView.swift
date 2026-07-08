//
//  OnbQuickCheckView.swift
//  YGTeeV
//
//  M15 — Quick check trivia (Questions 1-2, category "general").
//  One question at a time, Duolingo-style: overline + question +
//  4 answer rows + a running XP tally chip up top. Wrong answers
//  still earn — the goal is "small win per screen", never shaming.
//
//  Beat sheet from design HTML Moment 11:
//    • Light paper background.
//    • Top bar: violet→pink progress capsule + yellow XP tally.
//    • Overline "QUICK CHECK · N OF M" · title · "No wrong answers"
//      subtitle with a 💛 heart.
//    • 4 answer rows with a radio circle each. Tap → immediate
//      feedback: correct = green gradient fill with a check + "+X XP"
//      chip; wrong = red muted fill with an X; the correct row also
//      reveals with the same green treatment.
//    • Bottom violet CTA changes copy based on state: disabled
//      "Pick an answer" → "Nice — that's right! +250 XP →" or
//      "Not quite — next up →" → tap advances to next question or
//      out of the screen when the last question resolves.
//
//  Phase 4 graceful degradation stays intact: if there's no auth
//  session, `pick(...)` evaluates client-side using the loaded
//  `correctChoiceIndex`, awards 0 XP, and keeps the flow moving.
//

import SwiftUI

struct OnbQuickCheckView: View {
    @Bindable var state: ReimaginedOnboardingState
    let service: OnboardingService
    let advance: () -> Void

    @State private var isLoading = false
    @State private var errorText: String?
    @State private var currentIndex = 0
    @State private var selectedIndex: Int? = nil
    @State private var currentResult: OnboardingAnswerResult? = nil

    private var questions: [OnboardingQuestion] {
        service.questions.filter { $0.category == "general" }
    }

    private var currentQuestion: OnboardingQuestion? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    private var isLastQuestion: Bool {
        currentIndex >= questions.count - 1
    }

    /// Percent-fill for the top progress bar. Bumps up by 1/n as soon
    /// as the current question resolves so the fill happens with the
    /// answer, not with the next-question tap.
    private var progress: Double {
        guard !questions.isEmpty else { return 0 }
        let base = Double(currentIndex) / Double(questions.count)
        let bonus = currentResult != nil ? (1.0 / Double(questions.count)) : 0
        return min(base + bonus, 1.0)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 22)
                .padding(.top, 20)

            if isLoading && questions.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if let errorText, currentQuestion == nil {
                Spacer()
                Text(errorText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.red)
                Spacer()
            } else if let q = currentQuestion {
                questionArea(q)
                    .padding(.top, 22)

                Spacer(minLength: 12)

                bottomCTA
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(YGColors.paper)
        .task {
            if service.questions.isEmpty {
                await loadQuestions()
            }
        }
    }

    // MARK: - Top progress + XP tally

    private var topBar: some View {
        HStack(spacing: 12) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(YGColors.ink.opacity(0.1))
                    Capsule()
                        .fill(YGColors.violetPinkGradient)
                        .frame(width: max(6, geo.size.width * progress))
                }
            }
            .frame(height: 9)
            .animation(.snappy, value: progress)

            xpChip
        }
    }

    private var xpChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Color(hex: "FFB800"))
            Text("\(state.totalTriviaXp)")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: "8A6D00"))
                .contentTransition(.numericText(value: Double(state.totalTriviaXp)))
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(Color(hex: "FFF7D6"))
        .overlay(
            Capsule().strokeBorder(Color(hex: "FFD60A").opacity(0.5), lineWidth: 1)
        )
        .clipShape(Capsule())
        .shadow(color: Color(hex: "FFD60A").opacity(0.25), radius: 12, y: 4)
    }

    // MARK: - Question area

    private func questionArea(_ q: OnboardingQuestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QUICK CHECK · \(currentIndex + 1) OF \(questions.count)")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(YGColors.violet)

            Text(q.prompt)
                .font(.lilitaOne(size: 26))
                .foregroundStyle(YGColors.ink)

            Text("No wrong answers — you earn XP either way. 💛")
                .font(.system(size: 12.5))
                .foregroundStyle(YGColors.ink.opacity(0.55))

            VStack(spacing: 10) {
                ForEach(Array(q.choices.enumerated()), id: \.offset) { idx, choice in
                    answerRow(q: q, index: idx, choice: choice)
                }
            }
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
    }

    private func answerRow(q: OnboardingQuestion, index: Int, choice: String) -> some View {
        let hasResult = currentResult != nil
        let isSelected = selectedIndex == index
        let isCorrectIndex = hasResult && index == currentResult!.correctChoiceIndex
        let isWrongPicked = hasResult && isSelected && !currentResult!.correct
        let showXpChip = isCorrectIndex &&
                         (currentResult?.correct ?? false) &&
                         (currentResult?.xpAwarded ?? 0) > 0

        return Button {
            guard !hasResult else { return }
            Task { await pick(q, idx: index) }
        } label: {
            HStack(spacing: 12) {
                circleIcon(
                    isCorrect: isCorrectIndex,
                    isWrong: isWrongPicked,
                    isPreselected: isSelected && !hasResult
                )
                Text(choice)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(isCorrectIndex || isWrongPicked ? .white : YGColors.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if showXpChip, let r = currentResult {
                    Text("+\(r.xpAwarded) XP")
                        .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(rowBackground(isCorrect: isCorrectIndex, isWrong: isWrongPicked))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isSelected && !hasResult ? YGColors.violet : Color.black.opacity(0.05),
                        lineWidth: isSelected && !hasResult ? 2 : 0.5
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(
                color: isCorrectIndex
                    ? Color(hex: "2B8A3E").opacity(0.35)
                    : (isWrongPicked ? Color(hex: "8C2A2A").opacity(0.3) : .black.opacity(0.04)),
                radius: isCorrectIndex || isWrongPicked ? 20 : 8,
                y: isCorrectIndex || isWrongPicked ? 8 : 2
            )
        }
        .buttonStyle(.plain)
        .disabled(hasResult)
    }

    @ViewBuilder
    private func circleIcon(isCorrect: Bool, isWrong: Bool, isPreselected: Bool) -> some View {
        if isCorrect {
            ZStack {
                Circle().fill(.white).frame(width: 22, height: 22)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Color(hex: "2B8A3E"))
            }
        } else if isWrong {
            ZStack {
                Circle().fill(.white).frame(width: 22, height: 22)
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Color(hex: "8C2A2A"))
            }
        } else {
            Circle()
                .strokeBorder(
                    isPreselected ? YGColors.violet : YGColors.ink.opacity(0.2),
                    lineWidth: 2
                )
                .frame(width: 22, height: 22)
        }
    }

    @ViewBuilder
    private func rowBackground(isCorrect: Bool, isWrong: Bool) -> some View {
        if isCorrect {
            LinearGradient(
                colors: [Color(hex: "8BE04B"), Color(hex: "2B8A3E")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if isWrong {
            LinearGradient(
                colors: [Color(hex: "E06B6B"), Color(hex: "8C2A2A")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color.white
        }
    }

    // MARK: - Bottom CTA

    private var bottomCTA: some View {
        let (label, enabled) = ctaState()
        return Button {
            handleCTA()
        } label: {
            Text(label)
                .font(.lilitaOne(size: 18))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    enabled
                        ? AnyShapeStyle(LinearGradient(
                            colors: [YGColors.violet, YGColors.violetDeep],
                            startPoint: .top,
                            endPoint: .bottom
                          ))
                        : AnyShapeStyle(YGColors.ink.opacity(0.15))
                )
                .clipShape(Capsule())
                .shadow(color: enabled ? YGColors.violet.opacity(0.4) : .clear, radius: 20, y: 8)
        }
        .disabled(!enabled)
    }

    /// Copy + enabled state for the bottom CTA. Idle until an answer
    /// is picked; then either celebrates or moves on based on
    /// correctness and whether we're on the last question.
    private func ctaState() -> (String, Bool) {
        guard let r = currentResult else {
            return ("Pick an answer", false)
        }
        if r.correct {
            let xpTag = r.xpAwarded > 0 ? " +\(r.xpAwarded) XP" : ""
            if isLastQuestion {
                return ("Nice work — continue →", true)
            }
            return ("Nice — that's right!\(xpTag) →", true)
        } else {
            if isLastQuestion {
                return ("No worries — continue →", true)
            }
            return ("Not quite — next up →", true)
        }
    }

    private func handleCTA() {
        guard currentResult != nil else { return }
        if isLastQuestion {
            advance()
        } else {
            currentIndex += 1
            selectedIndex = nil
            currentResult = nil
        }
    }

    // MARK: - Actions

    private func loadQuestions() async {
        isLoading = true
        errorText = nil
        do {
            try await service.loadQuestions()
        } catch {
            errorText = "Couldn't load questions. Try again."
        }
        isLoading = false
    }

    private func pick(_ q: OnboardingQuestion, idx: Int) async {
        selectedIndex = idx

        // Phase 4/5 graceful degradation: no auth session means the
        // RPC will 401. Evaluate client-side using the pre-loaded
        // correctChoiceIndex, award 0 XP, keep flow moving.
        if SupabaseManager.shared.currentUser == nil {
            let result = OnboardingAnswerResult(
                alreadyAnswered: false,
                correct: idx == q.correctChoiceIndex,
                correctChoiceIndex: q.correctChoiceIndex,
                xpAwarded: 0,
                explanation: q.explanation
            )
            currentResult = result
            state.questionResults[q.questionNumber] = result
            return
        }

        do {
            let result = try await service.recordAnswer(
                questionNumber: q.questionNumber,
                selectedIndex: idx
            )
            currentResult = result
            state.questionResults[q.questionNumber] = result
            state.totalTriviaXp += result.xpAwarded
        } catch {
            errorText = "Couldn't record your answer. Try again."
        }
    }
}
