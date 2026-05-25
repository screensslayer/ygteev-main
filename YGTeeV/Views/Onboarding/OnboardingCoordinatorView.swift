//
//  OnboardingCoordinatorView.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/7/26.
//

import SwiftUI

struct OnboardingCoordinatorView: View {
    @State private var onboardingState = OnboardingState()
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            switch onboardingState.currentStep {
            case .welcome:
                OnbWelcomeView(onboardingState: onboardingState)
                    .transition(.move(edge: .trailing))
            case .knowledgeQuestion(let index):
                OnbQuestionView(questionIndex: index, onboardingState: onboardingState)
                    .transition(.move(edge: .trailing))
            case .encouragement(let tone):
                OnbEncourageView(tone: tone, onboardingState: onboardingState)
                    .transition(.move(edge: .trailing))
            case .reward:
                OnbRewardView(onboardingState: onboardingState)
                    .transition(.move(edge: .trailing))
            case .vibeCheck:
                OnbVibeCheckView(onboardingState: onboardingState)
                    .transition(.move(edge: .trailing))
            case .reviewPrompt:
                OnbReviewPromptView(onboardingState: onboardingState)
                    .transition(.opacity)
            case .accountIntro:
                OnbAccountIntroView(onboardingState: onboardingState)
                    .transition(.move(edge: .trailing))
            case .gradeYear:
                OnbGradeYearView(onboardingState: onboardingState)
                    .transition(.move(edge: .trailing))
            case .birthYear:
                OnbBirthYearView(onboardingState: onboardingState)
                    .transition(.move(edge: .trailing))
            case .birthYearConfirm:
                OnbBirthConfirmView(onboardingState: onboardingState)
                    .transition(.opacity)
            case .adultRequired:
                OnbAdultRequiredView(onboardingState: onboardingState)
                    .transition(.move(edge: .trailing))
            case .name:
                OnbNameView(onboardingState: onboardingState)
                    .transition(.move(edge: .trailing))
            case .createAccount:
                OnbCreateAccountView(onboardingState: onboardingState)
                    .transition(.move(edge: .trailing))
            case .customizing:
                OnbCustomizingView(onboardingState: onboardingState)
                    .transition(.opacity)
            case .optionalPaywall:
                OnbPaywallView(onComplete: { onboardingState.nextStep() })
                    .transition(.move(edge: .trailing))
            case .done:
                OnbDoneView(onComplete: onComplete)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: onboardingState.currentStep)
        .onChange(of: onboardingState.hasCompletedOnboarding) { _, newValue in
            if newValue {
                onComplete()
            }
        }
    }
}

// MARK: - Skip Button Component
//
// Dev-only "Skip (dev)" shortcut used to fly through onboarding while
// building. Hidden site-wide now that onboarding is shippable —
// `body` is intentionally empty so every call site stops rendering
// the pill without needing per-screen edits. Params are kept so the
// existing call sites still compile.
struct OnboardSkipButton: View {
    let dark: Bool
    let action: () -> Void

    var body: some View {
        EmptyView()
    }
}

// MARK: - Progress Dots Component
struct OnboardProgressDots: View {
    let step: Int
    let total: Int
    let dark: Bool
    
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<total, id: \.self) { index in
                let isActive = index <= step
                let isCurrent = index == step
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(isActive ? (dark ? .white : YGColors.ink) : (dark ? Color.white.opacity(0.25) : YGColors.ink.opacity(0.15)))
                    .frame(width: isCurrent ? 18 : 6, height: 6)
                    .animation(.easeOut(duration: 0.2), value: isCurrent)
            }
        }
    }
}

// MARK: - Primary CTA Button
struct OnboardCTAButton: View {
    let title: String
    let secondary: Bool
    let dark: Bool
    let action: () -> Void
    
    init(title: String, secondary: Bool = false, dark: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.secondary = secondary
        self.dark = dark
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.lilitaOne(size: secondary ? 15 : 16))
                .tracking(-0.2)
                .foregroundStyle(secondary ? (dark ? .white : YGColors.ink) : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, secondary ? 14 : 16)
                .background(
                    Group {
                        if secondary {
                            Color.clear
                        } else {
                            LinearGradient(
                                colors: [Color(hex: "6B2BFF"), Color(hex: "3D0FB8")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                    }
                )
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(
                            secondary
                                ? (dark ? Color.white.opacity(0.25) : YGColors.ink.opacity(0.15))
                                : Color.clear,
                            lineWidth: secondary ? 1 : 0
                        )
                }
                .shadow(
                    color: secondary ? .clear : Color(hex: "6B2BFF").opacity(0.4),
                    radius: secondary ? 0 : 8,
                    y: secondary ? 0 : 2
                )
        }
    }
}

#Preview {
    OnboardingCoordinatorView(onComplete: {})
}
