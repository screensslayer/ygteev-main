//
//  OnbBirthDoubleCheckView.swift
//  YGTeeV
//
//  M6 — "Are you sure?" confirmation for the birth-year answer.
//  Rendered as a full-bleed dark backdrop with a centered card, per
//  the design HTML — this is intentionally NOT a normal step because
//  the age lock is permanent. Translates the year into an age
//  ("That makes you 14 years old") so a mis-scroll is obvious.
//
//  This is the only screen in the flow with a real "back" edge —
//  the "No — let me fix it" button routes to M5. Every other screen
//  advances forward-only.
//

import SwiftUI

struct OnbBirthDoubleCheckView: View {
    let state: ReimaginedOnboardingState
    let advance: () -> Void
    let goBack: () -> Void

    /// Age derived from birth year against today's date. Nil only if
    /// the user reached this screen with no birth year selected —
    /// shouldn't happen but we degrade gracefully.
    private var age: Int? {
        guard let year = state.birthYear else { return nil }
        return Calendar.current.component(.year, from: Date()) - year
    }

    var body: some View {
        ZStack {
            // Dim + blur under-layer. Matches the design HTML's
            // rgba(10,7,18,.5) + backdrop-filter blur.
            Color(hex: "0A0712").opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Cake emoji chip — warm, not clinical.
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [YGColors.yellow, YGColors.orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .shadow(color: .black.opacity(0.15), radius: 4, y: -2)
                    Text("🎂")
                        .font(.system(size: 30))
                }
                .padding(.top, 26)

                Text("Double-checking")
                    .font(.lilitaOne(size: 26))
                    .foregroundStyle(YGColors.ink)
                    .padding(.top, 16)

                Text("You told us you were born in")
                    .font(.system(size: 14))
                    .foregroundStyle(YGColors.ink.opacity(0.6))
                    .padding(.top, 10)

                Text(state.birthYear.map(String.init) ?? "—")
                    .font(.lilitaOne(size: 48))
                    .foregroundStyle(YGColors.ink)
                    .padding(.top, 6)

                // Age callout — the sanity anchor.
                (
                    Text("That makes you ")
                        .foregroundStyle(YGColors.ink.opacity(0.58))
                    +
                    Text(age.map { "\($0) years old" } ?? "—")
                        .foregroundStyle(YGColors.ink)
                        .fontWeight(.heavy)
                    +
                    Text(". This locks in for safety — you can't change it later.")
                        .foregroundStyle(YGColors.ink.opacity(0.58))
                )
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 22)
                .padding(.top, 8)

                // Yes — the primary path. Big violet gradient pill.
                Button(action: advance) {
                    Text("Yep, that's right")
                        .font(.lilitaOne(size: 17))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            LinearGradient(
                                colors: [YGColors.violet, YGColors.violetDeep],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: YGColors.violet.opacity(0.35), radius: 20, y: 8)
                }
                .padding(.top, 22)
                .padding(.horizontal, 22)

                // No — routes back to M5. Outlined pill, low visual
                // weight so the primary path is clear.
                Button(action: goBack) {
                    Text("No — let me fix it")
                        .font(.lilitaOne(size: 16))
                        .foregroundStyle(YGColors.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .overlay(
                            Capsule().strokeBorder(YGColors.ink.opacity(0.15), lineWidth: 1)
                        )
                }
                .padding(.top, 10)
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 26))
            .shadow(color: .black.opacity(0.4), radius: 40, y: 20)
            .padding(.horizontal, 22)
        }
    }
}
