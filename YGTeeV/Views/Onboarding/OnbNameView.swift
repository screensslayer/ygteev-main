//
//  OnbNameView.swift
//  YGTeeV
//
//  Captures full name (over-13 path) before the create-account step.
//  Single field — first/last split adds friction without much value
//  here, and group members see one display string anyway.
//

import SwiftUI

struct OnbNameView: View {
    let onboardingState: OnboardingState

    @State private var name: String = ""
    @FocusState private var focused: Bool

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canContinue: Bool {
        !trimmed.isEmpty
    }

    var body: some View {
        ZStack {
            Color(hex: "FAF8FF").ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    OnboardSkipButton(dark: false) {
                        onboardingState.skipToEnd()
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 60)
                }
                Spacer()
            }

            VStack(spacing: 0) {
                Spacer().frame(height: 110)

                VStack(alignment: .leading, spacing: 10) {
                    Text("ABOUT YOU")
                        .font(.system(size: 11, weight: .black))
                        .tracking(1.5)
                        .foregroundStyle(YGColors.violet)

                    Text("What's your name?")
                        .font(.lilitaOne(size: 30))
                        .tracking(-1.1)
                        .foregroundStyle(YGColors.ink)

                    Text("Your group will see this. You can change it later.")
                        .font(.system(size: 14))
                        .foregroundStyle(YGColors.ink.opacity(0.6))
                        .lineSpacing(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)

                VStack(alignment: .leading, spacing: 8) {
                    Text("FULL NAME")
                        .font(.system(size: 10.5, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(YGColors.ink.opacity(0.55))
                        .padding(.leading, 4)

                    TextField("First & last", text: $name)
                        .focused($focused)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .font(.lilitaOne(size: 18))
                        .tracking(-0.2)
                        .foregroundStyle(YGColors.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(
                                    focused ? YGColors.violet : Color.black.opacity(0.05),
                                    lineWidth: focused ? 1.5 : 0.5
                                )
                        }
                        .shadow(color: YGColors.ink.opacity(0.04), radius: 2)
                }
                .padding(.horizontal, 22)
                .padding(.top, 28)

                Spacer()

                OnboardCTAButton(title: "Continue →") {
                    onboardingState.fullName = trimmed
                    onboardingState.nextStep()
                }
                .opacity(canContinue ? 1 : 0.4)
                .disabled(!canContinue)
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            // Pre-fill if the user navigated back. Auto-focus so the
            // keyboard opens without an extra tap.
            name = onboardingState.fullName
            focused = true
        }
    }
}

#Preview {
    OnbNameView(onboardingState: OnboardingState())
}
