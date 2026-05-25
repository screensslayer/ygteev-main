//
//  OnbCustomizingView.swift
//  YGTeeV
//
//  Brief "setting up your account" animation between signup and the
//  optional paywall. Cosmetic only — no network calls happen here,
//  the user's profile was already written during createAccount. After
//  ~2.5s the flow auto-advances.
//

import SwiftUI

struct OnbCustomizingView: View {
    let onboardingState: OnboardingState

    @State private var progress: Double = 0
    @State private var captionIndex: Int = 0

    private let captions = [
        "Picking your starter plant…",
        "Loading today's plan…",
        "Setting up your garden…",
        "Calibrating to your answers…"
    ]

    private let totalDuration: Double = 2.4
    private let stepInterval: Double = 0.6

    var body: some View {
        ZStack {
            background

            VStack(spacing: 36) {
                Spacer()

                Image("ygteev-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 110)

                Text("Setting things up")
                    .font(.lilitaOne(size: 28))
                    .tracking(-0.9)
                    .foregroundStyle(.white)

                progressBar
                    .padding(.horizontal, 32)

                Text(captions[captionIndex])
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut(duration: 0.25), value: captionIndex)
                    .frame(maxWidth: 280)

                Spacer()
            }
        }
        .task {
            await run()
        }
    }

    // MARK: - Subviews

    private var background: some View {
        LinearGradient(
            colors: [
                Color(hex: "0A0712"),
                Color(hex: "1A1428"),
                Color(hex: "2D2542")
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                Capsule()
                    .fill(LinearGradient(
                        colors: [Color(hex: "FFD60A"), Color(hex: "FF6B35")],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: max(8, geo.size.width * progress))
            }
        }
        .frame(height: 8)
    }

    // MARK: - Animation driver

    private func run() async {
        let steps = captions.count
        let perStepProgress = 1.0 / Double(steps)

        for i in 0..<steps {
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.4)) {
                    captionIndex = i
                    progress = min(1.0, Double(i + 1) * perStepProgress)
                }
            }
            let nanos = UInt64(stepInterval * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
            if Task.isCancelled { return }
        }

        // Total elapsed ≈ steps * stepInterval. Tiny hold so the user sees
        // the 100% bar before transitioning.
        try? await Task.sleep(nanoseconds: 250_000_000)
        if Task.isCancelled { return }

        await MainActor.run { onboardingState.nextStep() }
    }
}

#Preview {
    OnbCustomizingView(onboardingState: OnboardingState())
}
