//
//  OnbSourceBranchView.swift
//  YGTeeV
//
//  M2 — "How'd you get here?" Three emoji-tagged rows that describe
//  how the user arrived. All three advance to the same next step —
//  the group picker — so the answer is purely UX flavoring: it's
//  recorded on `state.source` for downstream copy hooks but never
//  sent to the backend. Design HTML footer reassures ambivalent
//  users that skipping the group later is fine.
//

import SwiftUI

struct OnbSourceBranchView: View {
    @Bindable var state: ReimaginedOnboardingState
    let advance: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots — first is the wide "active" pill, the
            // rest of the flow's phases sit as small unlit dots. The
            // splash didn't show one; this is where the crumb trail
            // starts. Matches the HTML's three-pip pattern.
            HStack(spacing: 5) {
                Capsule()
                    .fill(YGColors.ink)
                    .frame(width: 22, height: 6)
                Capsule()
                    .fill(YGColors.ink.opacity(0.15))
                    .frame(width: 6, height: 6)
                Capsule()
                    .fill(YGColors.ink.opacity(0.15))
                    .frame(width: 6, height: 6)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            // Overline + title + subtitle. The title breaks after
            // "you" per the design mock.
            VStack(alignment: .leading, spacing: 10) {
                Text("LET'S FIND YOUR PEOPLE")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(YGColors.violet)

                Text("How'd you\nget here?")
                    .font(.lilitaOne(size: 34))
                    .foregroundStyle(YGColors.ink)
                    .lineSpacing(-2)

                Text("This is how we connect you to the right crew.")
                    .font(.system(size: 14))
                    .foregroundStyle(YGColors.ink.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 20)

            // Three source rows — pink/violet / cyan/blue / lime/green.
            VStack(spacing: 12) {
                sourceRow(
                    .friend,
                    emoji: "👋",
                    tint: LinearGradient(colors: [YGColors.pink, YGColors.violet], startPoint: .topLeading, endPoint: .bottomTrailing),
                    title: "A friend invited me",
                    subtitle: "I've got a link or a code"
                )
                sourceRow(
                    .atGroup,
                    emoji: "📸",
                    tint: LinearGradient(colors: [YGColors.cyan, YGColors.blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                    title: "I'm at my youth group",
                    subtitle: "Scan the QR my leader is showing"
                )
                sourceRow(
                    .foundIt,
                    emoji: "🧭",
                    tint: LinearGradient(colors: [YGColors.lime, YGColors.pixGrassDark], startPoint: .topLeading, endPoint: .bottomTrailing),
                    title: "I found it myself",
                    subtitle: "Just exploring — no group yet"
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)

            Spacer(minLength: 20)

            // Design HTML's reassuring footer line above the safe
            // area. There's no CTA on this screen — tapping any row
            // is the advance action.
            Text("No stress if you're not sure — you can always find a group later.")
                .font(.system(size: 12))
                .foregroundStyle(YGColors.ink.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(YGColors.paper)
    }

    private func sourceRow(
        _ src: ReimaginedOnboardingState.SignupSource,
        emoji: String,
        tint: LinearGradient,
        title: String,
        subtitle: String
    ) -> some View {
        Button {
            state.source = src
            // Row tap is the advance — the design HTML has no explicit
            // "Continue" button; picking IS the confirmation.
            advance()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(tint)
                        .frame(width: 50, height: 50)
                    Text(emoji)
                        .font(.system(size: 26))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.lilitaOne(size: 17))
                        .foregroundStyle(YGColors.ink)
                    Text(subtitle)
                        .font(.system(size: 12.5))
                        .foregroundStyle(YGColors.ink.opacity(0.55))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(YGColors.ink.opacity(0.3))
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        src == .friend ? YGColors.violet.opacity(0.25) : .black.opacity(0.05),
                        lineWidth: src == .friend ? 1.5 : 0.5
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(
                color: src == .friend ? YGColors.violet.opacity(0.12) : .black.opacity(0.05),
                radius: src == .friend ? 18 : 10,
                y: src == .friend ? 6 : 3
            )
        }
        .buttonStyle(.plain)
    }
}
