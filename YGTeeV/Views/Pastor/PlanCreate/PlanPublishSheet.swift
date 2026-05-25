//
//  PlanPublishSheet.swift
//  YGTeeV
//
//  Screen 8: bottom sheet with totals + Publish CTA.
//

import SwiftUI

struct PlanPublishSheet: View {
    let draft: BiblePlanDraft
    let totalXP: Int
    let totalWater: Int
    let totalQuestions: Int
    let groupName: String?
    let onPublish: (_ visibility: PlanVisibility) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isPublishing = false
    @State private var visibility: PlanVisibility = .private

    var body: some View {
        ZStack {
            // Hero gradient backdrop, peeking from behind the sheet.
            PlanHeaderGradient.gradient(at: draft.gradientIndex)
                .opacity(0.85)
                .frame(height: 320, alignment: .top)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .overlay(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("READY TO PUBLISH")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(1.5)
                            .foregroundStyle(.white.opacity(0.85))
                        Text(draft.title)
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .shadow(color: .black.opacity(0.25), radius: 16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 100)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 0) {
                    Capsule()
                        .fill(YGColors.ink.opacity(0.18))
                        .frame(width: 40, height: 4)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                        .padding(.bottom, 12)

                    Text("Publish to your youth group?")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(YGColors.ink)
                        .padding(.horizontal, 20)

                    Text("Members will see this in their Plans tab tomorrow at 6 AM.")
                        .font(.system(size: 13.5))
                        .foregroundStyle(YGColors.ink.opacity(0.6))
                        .padding(.horizontal, 20)
                        .padding(.top, 4)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        statTile(value: "\(draft.totalDays)", label: "days", color: YGColors.violet)
                        statTile(value: "\(totalXP)", label: "XP total", color: Color(hex: "FFD60A"))
                        statTile(value: "\(totalWater)", label: "water drops", color: Color(hex: "3DAEFF"))
                        statTile(value: "\(totalQuestions)", label: "questions", color: Color(hex: "FF3DA5"))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    visibilitySection
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    Button {
                        Task {
                            isPublishing = true
                            await onPublish(visibility)
                            isPublishing = false
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isPublishing { ProgressView().tint(.white) }
                            else { Text("Publish plan →").font(.system(size: 16, weight: .black, design: .rounded)) }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(colors: [YGColors.violet, Color(hex: "FF3DA5")],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: YGColors.violet.opacity(0.5), radius: 14, y: 8)
                    }
                    .disabled(isPublishing)
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.top, 18)

                    Button("Cancel") { dismiss() }
                        .font(.system(size: 13.5, weight: .heavy))
                        .foregroundStyle(YGColors.ink.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        .padding(.bottom, 28)
                }
                .background(YGColors.paper)
                .clipShape(.rect(topLeadingRadius: 24, topTrailingRadius: 24))
                .shadow(color: YGColors.ink.opacity(0.4), radius: 60, y: -20)
            }
        }
        .background(YGColors.paper.ignoresSafeArea(edges: .bottom))
        .onAppear { visibility = draft.visibility }
    }

    // MARK: - Visibility picker

    private var visibilitySection: some View {
        VStack(spacing: 8) {
            Text("VISIBILITY")
                .font(.system(size: 10.5, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(YGColors.ink.opacity(0.55))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)

            visibilityOption(
                option: .private,
                emoji: "🔒",
                tint: Color(hex: "B4FF3C").opacity(0.18),
                title: "Private — only my youth group",
                subtitle: groupName.map { "Just members of \($0)" } ?? "Just members of your group"
            )

            visibilityOption(
                option: .public,
                emoji: "🌎",
                tint: Color(hex: "FFD60A").opacity(0.20),
                title: "Public — anyone on YGTeeV",
                subtitle: "Anyone using the app can find and start this plan"
            )
        }
    }

    private func visibilityOption(option: PlanVisibility,
                                  emoji: String,
                                  tint: Color,
                                  title: String,
                                  subtitle: String) -> some View {
        let selected = visibility == option
        return Button { visibility = option } label: {
            HStack(spacing: 12) {
                Text(emoji)
                    .font(.system(size: 18))
                    .frame(width: 38, height: 38)
                    .background(tint)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(YGColors.ink)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(YGColors.ink.opacity(0.55))
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                ZStack {
                    Circle()
                        .strokeBorder(selected ? YGColors.violet : YGColors.ink.opacity(0.25), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if selected {
                        Circle()
                            .fill(YGColors.violet)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(selected ? YGColors.violet.opacity(0.5) : .black.opacity(0.05),
                                  lineWidth: selected ? 1.5 : 0.5)
            }
        }
        .buttonStyle(.plain)
    }

    private func statTile(value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(YGColors.ink)
            Text(label)
                .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                .foregroundStyle(YGColors.ink.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.05), lineWidth: 0.5) }
    }
}
