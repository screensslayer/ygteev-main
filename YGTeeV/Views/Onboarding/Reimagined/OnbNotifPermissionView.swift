//
//  OnbNotifPermissionView.swift
//  YGTeeV
//
//  M19 — Notification permission ask. Comes AFTER Day 1 completion
//  so the user has a streak worth protecting — that's the "reason"
//  the design HTML calls out as the difference-maker on opt-in.
//  Priming card first, then the OS dialog (fired via
//  `PushTokenService.requestPushPermissionWithRationale`, which is
//  the shared helper the rest of the app already uses).
//
//  Regardless of grant/deny, we advance — the user is never trapped
//  on this screen.
//

import SwiftUI

struct OnbNotifPermissionView: View {
    let state: ReimaginedOnboardingState
    let advance: () -> Void

    @State private var isAsking = false

    var body: some View {
        ZStack {
            // Deep-ink base with a soft violet vignette from the top.
            // Matches the design HTML's ink → deeper-ink gradient.
            LinearGradient(
                colors: [Color(hex: "1A1428"), Color(hex: "0A0712")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Soft orange glow behind the fire emoji so the streak
            // framing carries visual heat.
            Circle()
                .fill(YGColors.orange.opacity(0.35))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(y: -100)

            VStack(spacing: 0) {
                Spacer()

                // Streak-fire hero.
                Text("🔥")
                    .font(.system(size: 74))
                    .shadow(color: YGColors.orange.opacity(0.6), radius: 20, y: 4)

                Text("Keep your streak alive?")
                    .font(.lilitaOne(size: 30))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.top, 22)
                    .padding(.horizontal, 24)

                Text("We'll nudge you once a day at a time you pick — that's how a Day 1 becomes a Day 100.")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 14)

                Spacer()

                // Primary — asks. When iOS has already denied, this
                // returns false and we still advance — the rationale
                // helper handles all the branching internally.
                Button {
                    Task { await ask() }
                } label: {
                    HStack(spacing: 8) {
                        if isAsking { ProgressView().tint(Color(hex: "0A0712")) }
                        Text(isAsking ? "Asking…" : "Turn on reminders")
                            .font(.lilitaOne(size: 18))
                    }
                    .foregroundStyle(Color(hex: "0A0712"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [.white, Color(hex: "F0EDF8")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                }
                .disabled(isAsking)

                // Secondary — bail without asking. Copy is warm, not
                // punitive; the streak framing is aspirational.
                Button {
                    advance()
                } label: {
                    Text("Maybe later")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .disabled(isAsking)
                .padding(.top, 6)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 36)
        }
    }

    private func ask() async {
        isAsking = true
        _ = await PushTokenService.requestPushPermissionWithRationale(
            reason: "Streak reminders so you don't lose your run."
        )
        isAsking = false
        advance()
    }
}
