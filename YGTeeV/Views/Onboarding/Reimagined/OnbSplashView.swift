//
//  OnbSplashView.swift
//  YGTeeV
//
//  M1 — Cold-launch splash. Full-bleed dark card with a radial violet
//  glow, brand overline, gradient wordmark on "with your group.", and
//  a primary "Let's go →" CTA + secondary "Sign in with parent's QR"
//  stub. The parent-QR button is intentionally non-functional in
//  Phase 4 — Phase 6 wires it up alongside the pairing flow. Design
//  HTML lists the button in the primary card so we keep the visual
//  spot reserved rather than skipping it entirely.
//

import SwiftUI

struct OnbSplashView: View {
    let state: ReimaginedOnboardingState
    let advance: () -> Void

    @State private var showingParentQRAlert = false

    var body: some View {
        ZStack {
            // Deep-ink base + radial violet/pink glow from top-center.
            // Matches the design HTML's `radial-gradient(ellipse at top,
            // #6B2BFF 0%, #3D0FB8 48%, #0A0712 100%)`.
            LinearGradient(
                colors: [Color(hex: "0A0712"), Color(hex: "0A0712")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [YGColors.violet, YGColors.violetDeep, Color(hex: "0A0712")],
                center: UnitPoint(x: 0.5, y: 0.05),
                startRadius: 20,
                endRadius: 520
            )
            .ignoresSafeArea()

            // Soft accent glows behind the wordmark — pink lower-left,
            // cyan upper-right — to keep the frame from feeling flat.
            Circle()
                .fill(YGColors.pink.opacity(0.35))
                .frame(width: 220, height: 220)
                .blur(radius: 40)
                .offset(x: -140, y: -120)

            Circle()
                .fill(YGColors.cyan.opacity(0.28))
                .frame(width: 200, height: 200)
                .blur(radius: 40)
                .offset(x: 140, y: -160)

            VStack(spacing: 0) {
                Spacer()

                // Brand overline.
                Text("YGTEEV")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(2.4)
                    .foregroundStyle(.white.opacity(0.72))

                // Two-line wordmark with a rainbow gradient on the
                // second line — the promise of "group" carries the
                // color, so it lands harder than the noun before it.
                VStack(spacing: 2) {
                    Text("The Bible,")
                        .font(.lilitaOne(size: 44))
                        .foregroundStyle(.white)
                    Text("with your group.")
                        .font(.lilitaOne(size: 44))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [YGColors.yellow, YGColors.pink, YGColors.cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                .multilineTextAlignment(.center)
                .padding(.top, 14)

                Text("Read together. Earn XP. Grow a garden you actually care about.")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .padding(.top, 16)

                Spacer()

                // Primary CTA — white pill.
                Button(action: advance) {
                    Text("Let's go →")
                        .font(.lilitaOne(size: 20))
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

                // Secondary CTA — translucent pill for the parent-QR
                // flow. Stubbed to an alert until Phase 6 wires it
                // to the actual pairing coordinator.
                Button {
                    showingParentQRAlert = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 15, weight: .bold))
                        Text("Sign in with parent's QR")
                            .font(.lilitaOne(size: 17))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.white.opacity(0.12))
                    .overlay(
                        Capsule().strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .clipShape(Capsule())
                }
                .padding(.top, 10)

                Text("Already have an account? ")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                +
                Text("Sign in")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.95))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
        .alert("Coming soon", isPresented: $showingParentQRAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Parent QR sign-in unlocks in the family-pair rollout. For now, tap Let's go to keep going.")
        }
    }
}
