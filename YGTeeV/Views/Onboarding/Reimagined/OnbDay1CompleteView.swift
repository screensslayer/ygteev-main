//
//  OnbDay1CompleteView.swift
//  YGTeeV
//
//  M18 — Welcome bonus reveal. Calls `service.completeOnboarding()`
//  which grants the +3000 XP welcome bonus and stamps
//  `profiles.onboarding_completed_at`. Idempotent — safe on relaunch.
//
//  Phase 2: XP counter animates from the user's PRIOR total → new
//  total using a spring-easing `AnimatableCounter`. So a user
//  arriving with 4,277 XP (3,027 seed + 1,250 trivia) sees the
//  digit roll 4,277 → 7,277 rather than 0 → 3,000. The delta below
//  is shown separately as "+X · welcome bonus".
//

import SwiftUI

struct OnbDay1CompleteView: View {
    @Bindable var state: ReimaginedOnboardingState
    let service: OnboardingService
    let advance: () -> Void

    @State private var isLoading = false
    @State private var errorText: String?
    /// The value the on-screen counter is currently displaying.
    /// Seeded to the user's PRE-bonus total when the RPC returns,
    /// then bumped up to the post-bonus total inside a
    /// `withAnimation(.spring)` so the digits climb.
    @State private var displayedXp: Double = 0

    var body: some View {
        SkeletonScreen(
            stepLabel: "M18 · DAY 1 COMPLETE",
            title: state.welcomeBonusAwarded > 0
                ? "You did it, \(state.displayName.isEmpty ? "friend" : state.displayName)! 🎉"
                : "Locking it in…",
            subtitle: state.welcomeBonusAwarded > 0
                ? "+\(state.welcomeBonusAwarded) XP · welcome bonus"
                : "One sec while we drop your welcome bonus.",
            actionLabel: "Keep going →",
            actionEnabled: state.welcomeBonusAwarded > 0 || !isLoading,
            onAction: advance
        ) {
            if isLoading {
                ProgressView().padding(.vertical, 20)
            } else if let errorText {
                VStack(spacing: 10) {
                    Text(errorText)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                    Button("Retry") { Task { await complete() } }
                        .buttonStyle(.borderedProminent)
                }
                .padding(14)
                .background(Color.red.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if state.welcomeBonusAwarded > 0 {
                VStack(spacing: 6) {
                    AnimatableCounter(value: displayedXp)
                        .font(.lilitaOne(size: 64))
                        .foregroundStyle(YGColors.violet)
                        .contentTransition(.numericText(value: displayedXp))
                    Text("XP")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(YGColors.ink.opacity(0.65))
                }
                .padding(24)
            }
        }
        .task {
            if state.welcomeBonusAwarded == 0 {
                await complete()
            }
        }
    }

    private func complete() async {
        isLoading = true
        errorText = nil
        do {
            let result = try await service.completeOnboarding()
            state.welcomeBonusAwarded = result.xpAwarded
            state.totalXpAfterWelcome = result.totalXp

            // Seed the counter at the PRE-bonus total, then spring
            // it up to the final total. If this is a re-run
            // (already_completed), `xpAwarded` is 0 and we simply
            // display the final total without animation.
            let priorTotal = Double(result.totalXp - result.xpAwarded)
            let finalTotal = Double(result.totalXp)
            displayedXp = priorTotal
            withAnimation(.spring(response: 1.4, dampingFraction: 0.9)) {
                displayedXp = finalTotal
            }
        } catch {
            errorText = "Couldn't drop your bonus. Try again in a sec."
        }
        isLoading = false
    }
}

// MARK: - AnimatableCounter
//
// The `Animatable` protocol lets SwiftUI interpolate a Double across
// the animation curve — the view's body is called for every
// intermediate value, so `Text("\(Int(value.rounded()))")` renders
// each in-between number and the digit rolls smoothly.
//
// This is the standard SwiftUI pattern for animating a Text
// number; the alternative (`.contentTransition(.numericText)`) only
// crossfades between START and END without showing intermediates,
// which reads more like a swap than a count-up.

private struct AnimatableCounter: View, Animatable {
    var value: Double

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text("\(Int(value.rounded()))")
            .monospacedDigit()
    }
}
