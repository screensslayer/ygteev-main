//
//  PlanCompletionView.swift
//  YGTeeV
//
//  Shows server-computed rewards after a plan day is completed.
//

import SwiftUI

struct PlanCompletionView: View {
    let result: StepCompletionResult
    let dayNumber: Int
    /// If non-nil, the caller knows what the next day is and the "Continue Plan"
    /// CTA will fire this. If nil (e.g. the plan is fully complete), the CTA
    /// falls back to a plain "Done" that dismisses.
    var onContinueNextDay: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var showConfetti = false
    @State private var treeScale: CGFloat = 0.8
    @State private var showGarden = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [YGColors.yellow, YGColors.orange, YGColors.violet],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if showConfetti {
                ForEach(0..<40, id: \.self) { index in
                    ConfettiPiece(index: index)
                }
            }

            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 40)

                    ZStack {
                        PixelTree(size: 140, stage: .stage4, species: "cherry")
                            .scaleEffect(treeScale)
                            .animation(.spring(response: 0.6, dampingFraction: 0.6), value: treeScale)

                        Text("✨")
                            .font(.system(size: 28))
                            .offset(x: 60, y: -50)
                            .opacity(showConfetti ? 1 : 0)
                            .scaleEffect(showConfetti ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.2), value: showConfetti)

                        Text("💧")
                            .font(.system(size: 22))
                            .offset(x: -70, y: 20)
                            .opacity(showConfetti ? 1 : 0)
                            .scaleEffect(showConfetti ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.4), value: showConfetti)
                    }
                    .padding(.bottom, 22)

                    Text("DAY \(dayNumber) COMPLETE")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 2, y: 2)
                        .padding(.bottom, 6)

                    Text(result.planCompleted ? "Plan complete! 🎉" : "You crushed\nit! 💪")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.2), radius: 10)
                        .padding(.bottom, 26)

                    // Big day-total chips. XP + water use the
                    // grand-total fields (step XP + daily bonus +
                    // milestone + plan-completion + 2× when Pro) so
                    // the headline number matches what the user
                    // actually earned across every step today.
                    HStack(spacing: 10) {
                        RewardChip(icon: "⚡", value: "+\(result.totalXpAwarded)", label: "XP", color: YGColors.yellow)
                        RewardChip(icon: "💧", value: "+\(result.totalWaterAwarded)", label: "water", color: YGColors.water)
                        RewardChip(icon: "🔥", value: "\(result.newStreak ?? 0)", label: "streak", color: YGColors.orange)
                    }
                    .padding(.bottom, 20)

                    // Milestone (if hit)
                    if let milestone = result.milestoneHit {
                        VStack(spacing: 6) {
                            Text("🔥 \(milestone)-day streak!")
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                            Text("+\(result.milestoneXp) XP, +\(result.milestoneWater) water")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Capsule())
                        .padding(.bottom, 16)
                    }

                    // Plan complete bonus (if applicable)
                    if result.planCompleted {
                        VStack(spacing: 6) {
                            Text("🎉 Plan complete!")
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                            Text("+\(result.planCompletionXp) XP, +\(result.planCompletionWater) water")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.bottom, 16)
                    }

                    // Grand total
                    VStack(spacing: 4) {
                        Text("+\(result.totalXpAwarded) XP earned this day")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text("+\(result.totalWaterAwarded) water earned")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.bottom, 28)

                    Text("Want more XP today? Knock out another plan — your tree grows faster.")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 28)

                    VStack(spacing: 8) {
                        Button {
                            showGarden = true
                        } label: {
                            Text("Visit my garden 🌱")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(YGColors.violetDeep)
                        }
                        .buttonStyle(.primary(
                            gradient: LinearGradient(colors: [.white, .white], startPoint: .leading, endPoint: .trailing),
                            textColor: YGColors.violetDeep
                        ))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .shadow(color: .black.opacity(0.2), radius: 14, y: 8)

                        Button {
                            if let next = onContinueNextDay {
                                next()
                            } else {
                                dismiss()
                            }
                        } label: {
                            Text(onContinueNextDay == nil ? "Done" : "Continue Plan")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.white.opacity(0.15))
                                .background(.ultraThinMaterial.opacity(0.3))
                                .clipShape(Capsule())
                                .overlay {
                                    Capsule()
                                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }

            // Close X — sends the user back to the main plan view
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.black.opacity(0.25))
                            .clipShape(Circle())
                            .overlay {
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer()
            }
        }
        .onAppear {
            withAnimation {
                showConfetti = true
                treeScale = 1.0
            }
        }
        .sheet(isPresented: $showGarden) {
            GardenFullView()
        }
    }
}

struct ConfettiPiece: View {
    let index: Int
    @State private var position: CGPoint = .zero
    @State private var rotation: Double = 0
    @State private var opacity: Double = 0

    private let colors: [Color] = [
        YGColors.yellow, YGColors.pink, YGColors.cyan, YGColors.lime, .white
    ]

    private var color: Color { colors[index % colors.count] }
    private var startX: CGFloat {
        CGFloat((index * 17 + 7) % 100) * UIScreen.main.bounds.width / 100
    }
    private var startY: CGFloat {
        CGFloat((index * 23) % 80) * UIScreen.main.bounds.height / 100 - 100
    }

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 8, height: 14)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .position(position)
            .onAppear {
                position = CGPoint(x: startX, y: startY)

                withAnimation(.linear(duration: 3).delay(Double(index) * 0.05)) {
                    position = CGPoint(
                        x: startX + CGFloat.random(in: -50...50),
                        y: UIScreen.main.bounds.height + 50
                    )
                    opacity = 0.9
                }

                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

struct RewardChip: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(icon)
                .font(.system(size: 24))

            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(YGColors.ink)

            Text(label.uppercased())
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(YGColors.ink.opacity(0.55))
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}
