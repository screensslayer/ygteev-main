//
//  OnbFeedbackView.swift
//  YGTeeV
//
//  M20 — Sentiment gate. Peak-goodwill moment right after Day 1
//  completion + the notif ask, so we ask one honest question with
//  a smart route:
//
//    Stage 15a  →  "Enjoying YGTeeV so far?"  →  Loving it / Not yet
//    Stage 15b  →  (Not yet) "What'd make it better?" + textarea
//                  → submits via submit_feedback, then advances
//    Stage 15c  →  (Loving it) fires the OS App Store review prompt
//                  via SwiftUI's @Environment(\.requestReview), then
//                  advances
//
//  Neither route blocks the app. Skip / Send both hand off to the
//  coordinator's advance closure.
//
//  Design note from the HTML: gate the OS review prompt on positive
//  sentiment only, and never withhold app access based on the
//  answer. Both paths lead into the app.
//

import SwiftUI
import StoreKit

struct OnbFeedbackView: View {
    @Bindable var state: ReimaginedOnboardingState
    let service: OnboardingService
    let advance: () -> Void

    /// SwiftUI's native review-prompt trigger. iOS decides whether
    /// to actually show it (rate-limits to 3× per year per app) —
    /// we just ask.
    @Environment(\.requestReview) private var requestReview

    @FocusState private var isCommentFocused: Bool
    @State private var stage: Stage = .ask
    @State private var isSubmitting = false

    private enum Stage {
        case ask         // 15a — Loving it / Not yet
        case notYetForm  // 15b — feedback textarea
    }

    var body: some View {
        Group {
            switch stage {
            case .ask:        askStage
            case .notYetForm: notYetStage
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(YGColors.paper)
    }

    // MARK: - Stage 15a — the ask

    private var askStage: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("QUICK GUT CHECK")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(YGColors.blue)

                Text("Enjoying YGTeeV so far?")
                    .font(.lilitaOne(size: 30))
                    .foregroundStyle(YGColors.ink)

                Text("Be honest — we're early, and a real person reads every answer.")
                    .font(.system(size: 14))
                    .foregroundStyle(YGColors.ink.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 60)

            Spacer(minLength: 20)

            // Two big cards — pink/violet gradient for "Loving it",
            // neutral white for "Not yet". Matches the design HTML's
            // asymmetric weighting: the positive path is visually
            // louder so we get the ratings lift.
            VStack(spacing: 14) {
                Button {
                    Task { await handleLovingIt() }
                } label: {
                    HStack(spacing: 16) {
                        Text("🤩").font(.system(size: 44))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Loving it")
                                .font(.lilitaOne(size: 22))
                                .foregroundStyle(.white)
                            Text("Exactly what I hoped for")
                                .font(.system(size: 12.5))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        Spacer()
                    }
                    .padding(.vertical, 18)
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity)
                    .background(YGColors.violetPinkGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .shadow(color: YGColors.violet.opacity(0.35), radius: 24, y: 12)
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)

                Button {
                    stage = .notYetForm
                } label: {
                    HStack(spacing: 16) {
                        Text("🤔").font(.system(size: 44))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Not yet")
                                .font(.lilitaOne(size: 22))
                                .foregroundStyle(YGColors.ink)
                            Text("Something's missing — I'll tell you")
                                .font(.system(size: 12.5))
                                .foregroundStyle(YGColors.ink.opacity(0.55))
                        }
                        Spacer()
                    }
                    .padding(.vertical, 18)
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity)
                    .background(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .strokeBorder(.black.opacity(0.08), lineWidth: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .shadow(color: .black.opacity(0.05), radius: 14, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)
            }
            .padding(.horizontal, 20)

            Spacer()

            Text("Either way, you go straight into the app next.")
                .font(.system(size: 12))
                .foregroundStyle(YGColors.ink.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 34)
        }
    }

    // MARK: - Stage 15b — "Not yet" feedback form

    private var notYetStage: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("💬")
                    .font(.system(size: 32))
                Text("What'd make it better?")
                    .font(.lilitaOne(size: 28))
                    .foregroundStyle(YGColors.ink)
                Text("The honest version, please. This goes straight to the team — no bots, no ticket queue.")
                    .font(.system(size: 14))
                    .foregroundStyle(YGColors.ink.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 60)

            // Textarea. Multiline so a longer answer doesn't feel
            // constrained; auto-focused after a beat so the keyboard
            // comes up without an extra tap.
            VStack(alignment: .leading, spacing: 0) {
                TextField("I wish…", text: $state.feedbackComment, axis: .vertical)
                    .lineLimit(4, reservesSpace: true)
                    .font(.system(size: 15))
                    .foregroundStyle(YGColors.ink)
                    .tint(YGColors.blue)
                    .focused($isCommentFocused)
            }
            .padding(16)
            .background(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        isCommentFocused ? YGColors.blue.opacity(0.4) : .black.opacity(0.08),
                        lineWidth: 1.5
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .shadow(color: .black.opacity(0.04), radius: 10, y: 4)

            HStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(YGColors.violetPinkGradient)
                        .frame(width: 20, height: 20)
                    Text("✦")
                        .font(.system(size: 11))
                        .foregroundStyle(.white)
                }
                Text("A founder reads these every morning.")
                    .font(.system(size: 12))
                    .foregroundStyle(YGColors.ink.opacity(0.55))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 12)

            Spacer()

            Button {
                Task { await submitNotYet() }
            } label: {
                HStack(spacing: 8) {
                    if isSubmitting { ProgressView().tint(.white) }
                    Text(isSubmitting ? "Sending…" : "Send & keep going →")
                        .font(.lilitaOne(size: 17))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [YGColors.violet, YGColors.violetDeep],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(Capsule())
                .shadow(color: YGColors.violet.opacity(0.4), radius: 20, y: 8)
            }
            .disabled(isSubmitting)
            .padding(.horizontal, 20)

            Button {
                advance()
            } label: {
                Text("Skip — take me to the app")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(YGColors.ink.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .disabled(isSubmitting)
            .padding(.bottom, 24)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isCommentFocused = true
            }
        }
    }

    // MARK: - Actions

    /// Positive-sentiment path: record the emoji locally, ask iOS to
    /// show the review prompt (iOS decides whether to actually show
    /// it), and advance.
    private func handleLovingIt() async {
        state.feedbackEmoji = "🤩"
        state.feedbackRating = 4
        // Best-effort submit. Silent on failure — network hiccup
        // shouldn't trap the user on the last screen.
        if SupabaseManager.shared.currentUser != nil {
            try? await service.submitFeedback(
                source: "onboarding",
                rating: 4,
                emoji: "🤩",
                comment: nil
            )
        }
        // OS review prompt. Rate-limited by iOS internally.
        requestReview()
        // Give the OS a beat to present its alert before we tear
        // down the screen behind it.
        try? await Task.sleep(nanoseconds: 300_000_000)
        advance()
    }

    /// Negative-sentiment path: submit whatever the user typed and
    /// advance. Empty comment still submits so we get the sentiment
    /// signal (rating: 1).
    private func submitNotYet() async {
        let comment = state.feedbackComment.trimmingCharacters(in: .whitespacesAndNewlines)
        state.feedbackEmoji = "🤔"
        state.feedbackRating = 1

        if SupabaseManager.shared.currentUser != nil {
            isSubmitting = true
            do {
                try await service.submitFeedback(
                    source: "onboarding",
                    rating: 1,
                    emoji: "🤔",
                    comment: comment.isEmpty ? nil : comment
                )
            } catch {
                // Silent — feedback is optional.
            }
            isSubmitting = false
        }
        advance()
    }
}
