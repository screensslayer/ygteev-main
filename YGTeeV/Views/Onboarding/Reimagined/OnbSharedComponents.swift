//
//  OnbSharedComponents.swift
//  YGTeeV
//
//  Shared chrome for the Phase 1 skeleton screens. Each new
//  onboarding screen currently wraps its content in
//  `SkeletonScreen(title:subtitle:actionLabel:onAction:)` so the
//  flow is functional end-to-end (title + advance button) before
//  Phase 2 layers on the real copy, animation, and inputs.
//
//  Delete or repurpose this file once every screen has its final
//  design.
//

import SwiftUI

struct SkeletonScreen<Content: View>: View {
    let stepLabel: String
    let title: String
    let subtitle: String?
    let actionLabel: String
    var actionEnabled: Bool = true
    let onAction: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text(stepLabel)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(YGColors.violet)
                Text(title)
                    .font(.lilitaOne(size: 30))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(YGColors.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 15))
                        .foregroundStyle(YGColors.ink.opacity(0.65))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 60)

            content()
                .frame(maxWidth: .infinity)

            Spacer()

            Button(action: onAction) {
                Text(actionLabel)
                    .font(.lilitaOne(size: 18))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(actionEnabled ? YGColors.violet : Color.gray.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!actionEnabled)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(YGColors.paper)
    }
}

// Convenience for screens that don't need extra content between
// title and CTA — they can just pass an empty EmptyView.
extension SkeletonScreen where Content == EmptyView {
    init(
        stepLabel: String,
        title: String,
        subtitle: String? = nil,
        actionLabel: String,
        actionEnabled: Bool = true,
        onAction: @escaping () -> Void
    ) {
        self.stepLabel = stepLabel
        self.title = title
        self.subtitle = subtitle
        self.actionLabel = actionLabel
        self.actionEnabled = actionEnabled
        self.onAction = onAction
        self.content = { EmptyView() }
    }
}
