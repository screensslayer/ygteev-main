//
//  OnbParentPairView.swift
//  YGTeeV
//
//  Under-13 dead-end. The kid gets one honest screen: "you need a
//  grown-up to make you an account". No QR generated here, no
//  handoff, no polling. The parent installs YGTeeV separately,
//  runs the existing parent-first flow (Me → Add family member →
//  Create Managed Account), and hands the resulting QR / code back
//  to the kid. The kid uses "Sign in with grown-up's QR" from
//  this screen (or the splash) to install their session via the
//  existing `ChildSignInSheet` + `redeem-child-pairing-token` path.
//
//  Two exits, neither of them "advance to next onboarding step":
//    • Primary CTA presents `ChildSignInSheet`. Its `onComplete`
//      calls this view's `completeOnboarding` closure, which
//      RootView wires to `hasCompletedOnboarding = true` so the
//      kid drops into MainTabView.
//    • "I'll do this later" text link calls `goToSplash`, which
//      resets state.step to `.splash` — the kid can bail and come
//      back through the splash's "Sign in with grown-up's QR"
//      shortcut when the parent's ready.
//
//  Everything the Phase 6 handoff scaffolding built (backend RPCs,
//  FamilyService methods) is intentionally left in place, unused.
//  Nothing routes to it. A future phase can decide whether to keep
//  or drop it.
//

import SwiftUI

struct OnbParentPairView: View {
    let state: ReimaginedOnboardingState
    let completeOnboarding: () -> Void
    let goToSplash: () -> Void

    @State private var showingSignIn = false

    var body: some View {
        ZStack {
            // Green ink gradient — same "family unlock" bg language
            // as the design HTML but without any celebration.
            LinearGradient(
                colors: [Color(hex: "2B8A3E"), Color(hex: "1A5224"), Color(hex: "0A0712")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 30)

                lockHero
                    .padding(.top, 20)

                Text("Bring a grown-up in.")
                    .font(.lilitaOne(size: 30))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)
                    .padding(.horizontal, 24)

                Text("You need a parent or guardian to make you an account.")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 12)

                stepsList
                    .padding(.horizontal, 30)
                    .padding(.top, 26)

                Spacer(minLength: 20)

                Button {
                    showingSignIn = true
                } label: {
                    Text("Sign in with grown-up's QR")
                        .font(.lilitaOne(size: 18))
                        .foregroundStyle(Color(hex: "0A0712"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(
                            LinearGradient(
                                colors: [YGColors.lime, Color(hex: "8BE04B")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: YGColors.lime.opacity(0.4), radius: 26, y: 12)
                }
                .padding(.horizontal, 22)

                Button(action: goToSplash) {
                    Text("I'll do this later")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.65))
                        .padding(.vertical, 14)
                }
                .padding(.top, 4)
                .padding(.bottom, 30)
            }
        }
        .statusBarHidden(true)
        .fullScreenCover(isPresented: $showingSignIn) {
            ChildSignInSheet(onComplete: {
                showingSignIn = false
                completeOnboarding()
            })
        }
    }

    // MARK: - Hero + steps

    private var lockHero: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [YGColors.lime.opacity(0.5), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 110
                    )
                )
                .frame(width: 220, height: 220)

            RoundedRectangle(cornerRadius: 36)
                .fill(YGColors.lime.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 36)
                        .strokeBorder(YGColors.lime.opacity(0.4), lineWidth: 1)
                )
                .frame(width: 110, height: 110)

            Text("🔒")
                .font(.system(size: 56))
        }
    }

    private var stepsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            stepRow(1, "Ask a grown-up to download YGTeeV on their phone")
            stepRow(2, "They tap Me → Add family member → Create Managed Account")
            stepRow(3, "Come back here and tap \"Sign in with grown-up's QR\"")
        }
    }

    private func stepRow(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            ZStack {
                Circle()
                    .fill(YGColors.lime.opacity(0.2))
                    .overlay(
                        Circle().strokeBorder(YGColors.lime.opacity(0.5), lineWidth: 0.5)
                    )
                    .frame(width: 24, height: 24)
                Text("\(n)")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(YGColors.lime)
            }
            .padding(.top, 1)

            Text(text)
                .font(.system(size: 13.5))
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
