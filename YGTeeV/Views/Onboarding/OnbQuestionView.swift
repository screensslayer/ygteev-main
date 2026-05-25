//
//  OnbQuestionView.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/7/26.
//

import SwiftUI

struct OnbQuestionView: View {
    let questionIndex: Int
    let onboardingState: OnboardingState
    @State private var selectedAnswer: String? = nil
    
    var question: KnowledgeQuestion {
        KnowledgeQuestions.all[questionIndex]
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(hex: "FAF8FF")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Skip button and progress
                HStack {
                    OnboardProgressDots(step: questionIndex, total: 9, dark: false)
                        .padding(.leading, 16)
                    
                    Spacer()
                    
                    OnboardSkipButton(dark: false) {
                        onboardingState.skipToEnd()
                    }
                    .padding(.trailing, 16)
                }
                .padding(.top, 64)
                
                // Question header
                VStack(alignment: .leading, spacing: 8) {
                    Text(question.kind == .self_ ? "ABOUT YOU" : "QUICK CHECK · \(questionIndex) OF 2")
                        .font(.system(size: 11, weight: .black))
                        .tracking(1.5)
                        .foregroundStyle(YGColors.violet)
                    
                    Text(question.question)
                        .font(.lilitaOne(size: 28))
                        .tracking(-1)
                        .foregroundStyle(YGColors.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if question.kind == .trivia {
                        Text("No wrong answer here — we'll meet you where you are.")
                            .font(.system(size: 13))
                            .foregroundStyle(YGColors.ink.opacity(0.55))
                            .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.top, 46)
                
                // Options
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(question.options) { option in
                            OptionButton(
                                option: option,
                                isSelected: selectedAnswer == option.id,
                                action: {
                                    withAnimation(.spring(response: 0.2)) {
                                        selectedAnswer = option.id
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 30)
                }
                
                // Continue button
                VStack(spacing: 0) {
                    OnboardCTAButton(
                        title: selectedAnswer != nil ? "Continue →" : "Pick one to continue",
                        dark: false
                    ) {
                        guard let answer = selectedAnswer else { return }
                        onboardingState.userAnswers["question_\(questionIndex)"] = answer
                        onboardingState.nextStep()
                    }
                    .disabled(selectedAnswer == nil)
                    .opacity(selectedAnswer != nil ? 1 : 0.5)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
    }
}

// MARK: - Option Button
struct OptionButton: View {
    let option: KnowledgeQuestion.QuestionOption
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Radio button
                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? .clear : YGColors.ink.opacity(0.2),
                            lineWidth: 2
                        )
                        .frame(width: 22, height: 22)
                    
                    if isSelected {
                        Circle()
                            .fill(.white)
                            .frame(width: 22, height: 22)
                        
                        Circle()
                            .fill(YGColors.violet)
                            .frame(width: 10, height: 10)
                    }
                }
                
                // Label
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.label)
                        .font(.lilitaOne(size: 15.5))
                        .tracking(-0.2)
                        .foregroundStyle(isSelected ? .white : YGColors.ink)
                    
                    if let subtitle = option.subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(isSelected ? Color.white.opacity(0.85) : YGColors.ink.opacity(0.55))
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                isSelected
                    ? LinearGradient(
                        colors: [Color(hex: "6B2BFF"), YGColors.pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    : LinearGradient(colors: [.white], startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isSelected ? Color.clear : Color.black.opacity(0.05),
                        lineWidth: 0.5
                    )
            }
            .shadow(
                color: isSelected ? YGColors.violet.opacity(0.35) : YGColors.ink.opacity(0.04),
                radius: isSelected ? 8 : 2
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    OnbQuestionView(questionIndex: 0, onboardingState: OnboardingState())
}

#Preview("Trivia Question") {
    OnbQuestionView(questionIndex: 1, onboardingState: OnboardingState())
}
