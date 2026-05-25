//
//  PlanIntroView.swift
//  YGTeeV
//

import SwiftUI

struct PlanIntroView: View {
    let plan: BiblePlan
    @Environment(\.dismiss) private var dismiss
    @State private var showDailyPlan = false
    @State private var firstDayId: UUID?
    @State private var loadingDays = false

    private let plansService = PlansService.shared

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [YGColors.violet, Color(hex: "1A0D3E"), YGColors.ink],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            GeometryReader { geometry in
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geometry.size.height * 0.62))
                    path.addLine(to: CGPoint(x: geometry.size.width * 0.2, y: geometry.size.height * 0.45))
                    path.addLine(to: CGPoint(x: geometry.size.width * 0.4, y: geometry.size.height * 0.6))
                    path.addLine(to: CGPoint(x: geometry.size.width * 0.6, y: geometry.size.height * 0.4))
                    path.addLine(to: CGPoint(x: geometry.size.width * 0.8, y: geometry.size.height * 0.575))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height * 0.475))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                    path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
                    path.closeSubpath()
                }
                .fill(Color(hex: "1A0D3E"))

                Path { path in
                    path.move(to: CGPoint(x: 0, y: geometry.size.height * 0.75))
                    path.addLine(to: CGPoint(x: geometry.size.width * 0.25, y: geometry.size.height * 0.625))
                    path.addLine(to: CGPoint(x: geometry.size.width * 0.45, y: geometry.size.height * 0.725))
                    path.addLine(to: CGPoint(x: geometry.size.width * 0.7, y: geometry.size.height * 0.575))
                    path.addLine(to: CGPoint(x: geometry.size.width * 0.95, y: geometry.size.height * 0.675))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height * 0.65))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                    path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
                    path.closeSubpath()
                }
                .fill(YGColors.ink)
            }

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Circle()
                            .fill(Color.white.opacity(0.45))
                            .frame(width: 38, height: 38)
                            .liquidGlass(dark: true)
                            .clipShape(Circle())
                            .overlay {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                    }

                    Spacer()

                    Text("\(plan.daysTotal) DAYS")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .liquidGlass(dark: true)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)

                Spacer()

                Circle()
                    .fill(plan.gradient)
                    .frame(width: 110, height: 110)
                    .overlay {
                        Text("📖")
                            .font(.system(size: 44))
                    }

                Spacer()

                VStack(alignment: .leading, spacing: 0) {
                    Text("A Bible Plan")
                        .font(.system(size: 11.5, weight: .heavy))
                        .foregroundStyle(YGColors.yellow)
                        .textCase(.uppercase)
                        .tracking(1)
                        .padding(.bottom, 8)

                    Text(plan.title)
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.bottom, 12)

                    if let description = plan.description {
                        Text(description)
                            .font(.system(size: 14.5))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineSpacing(4)
                            .padding(.bottom, 16)
                    }

                    HStack(spacing: 10) {
                        RewardBadge(icon: "⚡", label: "\(plan.xpReward) XP", color: YGColors.yellow)
                        RewardBadge(icon: "💧", label: "\(plan.waterReward) water", color: YGColors.water)
                    }
                    .padding(.bottom, 18)

                    Button {
                        Task { await startPlan() }
                    } label: {
                        HStack {
                            if loadingDays {
                                ProgressView()
                                    .tint(YGColors.ink)
                            } else {
                                Text("Start day 1 →")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundStyle(YGColors.ink)
                            }
                        }
                    }
                    .buttonStyle(.primary(
                        gradient: LinearGradient(
                            colors: [YGColors.yellow, YGColors.orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        textColor: YGColors.ink
                    ))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .disabled(loadingDays)
                }
                .padding(24)
                .padding(.bottom, 6)
                .background(
                    LinearGradient(
                        colors: [.clear, YGColors.ink.opacity(0.92), YGColors.ink],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .fullScreenCover(isPresented: $showDailyPlan) {
            if let firstDayId = firstDayId {
                DailyPlanView(planId: plan.id, dayId: firstDayId)
            }
        }
    }

    private func startPlan() async {
        loadingDays = true
        defer { loadingDays = false }
        if plansService.daysByPlan[plan.id] == nil {
            await plansService.loadDays(planId: plan.id)
        }
        if let day1 = plansService.daysByPlan[plan.id]?.first(where: { $0.dayNumber == 1 }) {
            firstDayId = day1.id
            showDailyPlan = true
        }
    }
}

struct RewardBadge: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Text(icon)
                .font(.system(size: 12))
            Text(label)
                .font(.system(size: 12.5, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(color.opacity(0.4), lineWidth: 1)
        }
    }
}
