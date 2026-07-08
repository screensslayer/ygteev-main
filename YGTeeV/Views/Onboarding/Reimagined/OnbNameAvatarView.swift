//
//  OnbNameAvatarView.swift
//  YGTeeV
//
//  M10 — Display name + avatar color pick. Live avatar preview
//  updates as the user types (initials + tinted background). Six
//  color swatches below let the user pick their avatar tint — this
//  is DISTINCT from the Splat team color, which is randomly assigned
//  and revealed at M12-M14. A rainbow conic-gradient ring around the
//  avatar teases the team-color reveal one screen away.
//
//  CTA copy echoes the display name once entered ("Nice to meet you,
//  {name} →") — matches the design HTML.
//

import SwiftUI

struct OnbNameAvatarView: View {
    @Bindable var state: ReimaginedOnboardingState
    let advance: () -> Void

    @FocusState private var isNameFocused: Bool

    /// Six avatar color options — four SplatPalette colors + two
    /// brand accents (violet + amber). Ordered so the default at
    /// index 0 (green) is the calmest / friendliest.
    private let colors: [Color] = [
        Color(hex: "8BE04B"), // green (splat)
        Color(hex: "3DAEFF"), // blue (splat)
        Color(hex: "FFC23C"), // orange/amber (splat)
        Color(hex: "FF5BD0"), // pink (splat)
        Color(hex: "6B2BFF"), // violet (brand)
        Color(hex: "FFD60A")  // yellow (brand accent)
    ]

    private var trimmedName: String {
        state.displayName.trimmingCharacters(in: .whitespaces)
    }

    private var initials: String {
        let n = trimmedName
        if n.isEmpty { return "?" }
        return String(n.prefix(1)).uppercased()
    }

    private var canContinue: Bool {
        !trimmedName.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("MAKE IT YOURS")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(YGColors.violet)

                Text("What should\nwe call you?")
                    .font(.lilitaOne(size: 32))
                    .foregroundStyle(YGColors.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 24)

            Spacer(minLength: 20)

            // Avatar preview — rainbow conic ring around a tinted
            // gradient body with the user's initial. Design HTML calls
            // out that the ring is intentionally rainbow-neutral
            // because the team color drops in a screen later — the
            // teaser line under the avatar reinforces that.
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(YGColors.rainbowRingGradient)
                        .frame(width: 132, height: 132)
                        .opacity(0.9)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 122, height: 122)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    colors[state.avatarColorIndex],
                                    colors[state.avatarColorIndex].opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 114, height: 114)

                    Text(initials)
                        .font(.lilitaOne(size: 52))
                        .foregroundStyle(.white)
                }

                HStack(spacing: 5) {
                    Text("✨")
                    Text("Your team color drops onto this ring next")
                        .font(.system(size: 12))
                        .foregroundStyle(YGColors.ink.opacity(0.55))
                }
            }

            // Six-swatch color picker.
            HStack(spacing: 10) {
                ForEach(colors.indices, id: \.self) { i in
                    Button {
                        state.avatarColorIndex = i
                    } label: {
                        ZStack {
                            Circle()
                                .fill(colors[i])
                                .frame(width: 34, height: 34)
                            if state.avatarColorIndex == i {
                                Circle()
                                    .strokeBorder(YGColors.ink, lineWidth: 3)
                                    .frame(width: 42, height: 42)
                            }
                        }
                        .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 22)

            // Display-name field. Bordered card so the entry point is
            // obvious; violet caret + border tint on focus.
            VStack(alignment: .leading, spacing: 6) {
                Text("DISPLAY NAME")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(YGColors.ink.opacity(0.5))

                TextField("Your name", text: $state.displayName)
                    .font(.lilitaOne(size: 22))
                    .foregroundStyle(YGColors.ink)
                    .tint(YGColors.violet)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(true)
                    .focused($isNameFocused)
                    .submitLabel(.done)
                    .onSubmit { if canContinue { advance() } }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isNameFocused ? YGColors.violet.opacity(0.5) : YGColors.violet.opacity(0.25),
                        lineWidth: 1.5
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: YGColors.violet.opacity(0.1), radius: 10, y: 4)
            .padding(.horizontal, 24)
            .padding(.top, 28)

            Text("This is how your crew sees you. You can change it anytime.")
                .font(.system(size: 12))
                .foregroundStyle(YGColors.ink.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 12)

            Spacer()

            // Primary CTA — copy echoes the name when present.
            Button(action: advance) {
                Text(canContinue ? "Nice to meet you, \(trimmedName) →" : "Add your name to continue")
                    .font(.lilitaOne(size: 17))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        canContinue
                        ? AnyShapeStyle(LinearGradient(colors: [YGColors.violet, YGColors.violetDeep], startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(Color.gray.opacity(0.3))
                    )
                    .clipShape(Capsule())
                    .shadow(
                        color: canContinue ? YGColors.violet.opacity(0.4) : .clear,
                        radius: 20, y: 8
                    )
            }
            .disabled(!canContinue)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(YGColors.paper)
        .onAppear {
            // Auto-focus the field so the keyboard lifts as the
            // screen mounts — one less tap.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isNameFocused = true
            }
        }
    }
}
