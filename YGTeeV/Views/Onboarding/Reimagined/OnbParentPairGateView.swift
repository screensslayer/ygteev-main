//
//  OnbParentPairGateView.swift
//  YGTeeV
//
//  M7 — under-13 pre-auth "gate reveal" screen. Fires the moment
//  the birth-year double-check confirms the user is under 13, and
//  BEFORE the auth screen so the sign-up ask lands with a reason:
//  "we need a parent to unlock the family experience".
//
//  Every word reframes compliance as a perk — it's "one more
//  unlock", the parent is a "co-pilot cheering you on", never
//  "you're too young."
//
//  No service calls, no polling. The actual token mint + QR display
//  + poll for redemption lives in `OnbParentPairView` and fires
//  AFTER the child signs up (Stage B/C in the design HTML). The
//  router lays them out as separate steps so the auth screen sits
//  between them and the token can be minted against auth.uid().
//

import SwiftUI

struct OnbParentPairGateView: View {
    let state: ReimaginedOnboardingState
    let advance: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "2B8A3E"), Color(hex: "1A5224"), Color(hex: "0A0712")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 20)

                lockHero
                    .padding(.top, 20)

                oneMoreUnlockPill
                    .padding(.top, 24)

                Text("Let's bring a\ngrown-up in.")
                    .font(.lilitaOne(size: 30))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
                    .padding(.horizontal, 24)

                Text("You're one of our youngest readers — awesome. Pair with a parent to unlock the family experience: shared streaks, safe chat, and a co-pilot who's cheering you on.")
                    .font(.system(size: 14.5))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .padding(.top, 14)

                Spacer(minLength: 20)

                Button(action: advance) {
                    Text("Show me how →")
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

                Text("Takes about a minute with a parent nearby.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 12)
                    .padding(.bottom, 36)
            }
        }
        .statusBarHidden(true)
    }

    // MARK: - Hero + pill

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

            Text("🔓")
                .font(.system(size: 56))

            Text("✨")
                .font(.system(size: 22))
                .offset(x: 40, y: -46)
        }
    }

    private var oneMoreUnlockPill: some View {
        HStack(spacing: 6) {
            Circle().fill(YGColors.lime).frame(width: 6, height: 6)
            Text("ONE MORE UNLOCK")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(YGColors.lime)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(YGColors.lime.opacity(0.16))
        .overlay(
            Capsule().strokeBorder(YGColors.lime.opacity(0.4), lineWidth: 0.5)
        )
        .clipShape(Capsule())
    }
}
