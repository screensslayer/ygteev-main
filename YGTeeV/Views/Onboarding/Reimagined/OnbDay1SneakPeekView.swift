//
//  OnbDay1SneakPeekView.swift
//  YGTeeV
//
//  M16-M17 — Day 1 sneak peek (Questions 3-5, category "john_day_1").
//  The whole flow has been building to a first real Bible read, so
//  this hands over the John 1:1 passage personally ("{Name}'s first
//  day") + gates the read with a comprehension question. One MC
//  question per screen; the verse card stays as anchoring context.
//
//  Beat sheet from design HTML Moment 12:
//    • Dark linear gradient bg with a violet glow top-left.
//    • Green "🌱 {NAME}'S FIRST DAY" pill.
//    • "The Book of John" title (Lilita) + "Day 1 · Who is Jesus?"
//      subtitle.
//    • Glass verse card with an italic serif pull + "JOHN 1:1" ref
//      in green.
//    • "QUICK ONE" overline in green + question + 3-4 answer choices.
//    • Correct answer: green gradient fill with checkmark + "+X XP"
//      chip. Wrong: red muted fill with X.
//    • Bottom violet→pink gradient CTA: dynamic copy.
//
//  Phase 4/5 graceful degradation intact — unauthenticated answers
//  are evaluated client-side and award 0 XP without hitting the RPC.
//

import SwiftUI

struct OnbDay1SneakPeekView: View {
    @Bindable var state: ReimaginedOnboardingState
    let service: OnboardingService
    let advance: () -> Void

    @State private var isLoading = false
    @State private var errorText: String?
    @State private var currentIndex = 0
    @State private var selectedIndex: Int? = nil
    @State private var currentResult: OnboardingAnswerResult? = nil

    private var questions: [OnboardingQuestion] {
        service.questions.filter { $0.category == "john_day_1" }
    }

    private var currentQuestion: OnboardingQuestion? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    private var isLastQuestion: Bool {
        currentIndex >= questions.count - 1
    }

    private var displayNameCaps: String {
        let name = state.displayName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "YOUR" : "\(name.uppercased())'S"
    }

    var body: some View {
        ZStack {
            // Dark ink gradient bg with a violet glow flooding in
            // from top-left. Matches the design HTML's #1A1428 →
            // #0A0712 blend + rgba(107,43,255,.5) blur.
            LinearGradient(
                colors: [Color(hex: "1A1428"), Color(hex: "0A0712")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(YGColors.violet.opacity(0.5))
                .frame(width: 260, height: 260)
                .blur(radius: 40)
                .offset(x: -100, y: -260)

            content
        }
        .statusBarHidden(true)
        .task {
            if service.questions.isEmpty {
                await loadQuestions()
            }
        }
    }

    // MARK: - Body content

    @ViewBuilder
    private var content: some View {
        if isLoading && questions.isEmpty {
            ProgressView().tint(.white)
        } else if let errorText, currentQuestion == nil {
            Text(errorText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.red)
                .padding(.horizontal, 24)
        } else if let q = currentQuestion {
            VStack(spacing: 0) {
                header
                    .padding(.top, 30)
                    .padding(.horizontal, 24)

                verseCard
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                questionArea(q)
                    .padding(.horizontal, 24)
                    .padding(.top, 22)

                Spacer(minLength: 12)

                bottomCTA
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Text("🌱")
                Text("\(displayNameCaps) FIRST DAY")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.0)
                    .foregroundStyle(YGColors.lime)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(YGColors.lime.opacity(0.16))
            .overlay(
                Capsule().strokeBorder(YGColors.lime.opacity(0.4), lineWidth: 0.5)
            )
            .clipShape(Capsule())

            Text("The Book\nof John")
                .font(.lilitaOne(size: 34))
                .foregroundStyle(.white)
                .padding(.top, 4)

            Text("Day 1 · Who is Jesus?")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var verseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\"In the beginning was the Word, and the Word was with God, and the Word was God.\"")
                .font(.system(size: 17, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(.white)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Text("JOHN 1:1")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(YGColors.lime)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .background(.ultraThinMaterial.opacity(0.4), in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private func questionArea(_ q: OnboardingQuestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(questions.count > 1 ? "QUICK ONE · \(currentIndex + 1) OF \(questions.count)" : "QUICK ONE")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(YGColors.lime)

            Text(q.prompt)
                .font(.lilitaOne(size: 19))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 9) {
                ForEach(Array(q.choices.enumerated()), id: \.offset) { idx, choice in
                    answerRow(q: q, index: idx, choice: choice)
                }
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            HStack(spacing: 11) {
                circleIcon(
                    isCorrect: isCorrectIndex,
                    isWrong: isWrongPicked,
                    isPreselected: isSelected && !hasResult
                )
                Text(choice)
                    .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(isCorrectIndex || isWrongPicked ? .white : .white.opacity(0.9))
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if showXpChip, let r = currentResult {
                    Text("+\(r.xpAwarded) XP")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(rowBackground(isCorrect: isCorrectIndex, isWrong: isWrongPicked))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        strokeColor(isSelected: isSelected, hasResult: hasResult),
                        lineWidth: isSelected && !hasResult ? 2 : 0.5
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(
                color: isCorrectIndex ? Color(hex: "2B8A3E").opacity(0.4) : .clear,
                radius: isCorrectIndex ? 20 : 0,
                y: isCorrectIndex ? 8 : 0
            )
        }
        .buttonStyle(.plain)
        .disabled(hasResult)
    }

    @ViewBuilder
    private func circleIcon(isCorrect: Bool, isWrong: Bool, isPreselected: Bool) -> some View {
        if isCorrect {
            ZStack {
                Circle().fill(.white).frame(width: 20, height: 20)
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Color(hex: "2B8A3E"))
            }
        } else if isWrong {
            ZStack {
                Circle().fill(.white).frame(width: 20, height: 20)
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Color(hex: "8C2A2A"))
            }
        } else {
            Circle()
                .strokeBorder(
                    isPreselected ? YGColors.lime : Color.white.opacity(0.3),
                    lineWidth: 2
                )
                .frame(width: 20, height: 20)
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
            Color.white.opacity(0.06)
        }
    }

    private func strokeColor(isSelected: Bool, hasResult: Bool) -> Color {
        if isSelected && !hasResult {
            return YGColors.lime
        }
        return Color.white.opacity(0.14)
    }

    // MARK: - Bottom CTA

    private var bottomCTA: some View {
        let (label, enabled) = ctaState()
        return Button {
            handleCTA()
        } label: {
            Text(label)
                .font(.lilitaOne(size: 17))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    enabled
                        ? AnyShapeStyle(YGColors.violetPinkGradient)
                        : AnyShapeStyle(Color.white.opacity(0.1))
                )
                .clipShape(Capsule())
                .shadow(color: enabled ? YGColors.violet.opacity(0.45) : .clear, radius: 24, y: 12)
        }
        .disabled(!enabled)
    }

    private func ctaState() -> (String, Bool) {
        guard let r = currentResult else {
            return ("Pick an answer", false)
        }
        if isLastQuestion {
            return ("Complete Day 1 Sneak Peek →", true)
        }
        if r.correct {
            let xpTag = r.xpAwarded > 0 ? " +\(r.xpAwarded) XP" : ""
            return ("Nice — that's right!\(xpTag) →", true)
        }
        return ("Not quite — next up →", true)
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
