//
//  OnbEncourageAndRewardViews.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/7/26.
//

import SwiftUI

// MARK: - Encouragement View
struct OnbEncourageView: View {
    let tone: OnboardingState.EncouragementTone
    let onboardingState: OnboardingState
    
    var message: (emoji: String, title: String, body: String) {
        switch tone {
        case .new:
            return ("🌱", "Beginner's mind — best mind.", "We'll start gentle. By Sunday you'll have read more than you think.")
        case .casual:
            return ("🪴", "Welcome back to the rhythm.", "A few minutes a day adds up faster than you think. Daily plans incoming.")
        case .regular:
            return ("🌳", "You've got the habit.", "Let's give it a community — and a garden that actually grows.")
        case .deep:
            return ("👑", "Bible nerd. Respect.", "We'll surface deeper plans + commentary so you keep going further.")
        case .correct:
            return ("⚡", "Nice — that's right.", "+50 XP.")
        case .tryAgain:
            return ("💧", "No worries — that's why we're here.", "+25 XP for trying. Every plan teaches you the answers.")
        }
    }
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color(hex: "6B2BFF"), Color(hex: "3D0FB8")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Skip button
            VStack {
                HStack {
                    Spacer()
                    OnboardSkipButton(dark: true) {
                        onboardingState.skipToEnd()
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 60)
                }
                Spacer()
            }
            
            // Content
            VStack(spacing: 28) {
                // Emoji circle
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .overlay {
                            Circle()
                                .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
                        }
                        .shadow(color: .black.opacity(0.3), radius: 20)
                        .shadow(color: .black.opacity(0.2), radius: 12, y: -6)
                    
                    Text(message.emoji)
                        .font(.system(size: 64))
                }
                .frame(width: 130, height: 130)
                
                VStack(spacing: 14) {
                    Text(message.title)
                        .font(.lilitaOne(size: 30))
                        .tracking(-1)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    
                    Text(message.body)
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .frame(maxWidth: 300)
                }
            }
            .padding(.horizontal, 24)
            
            // Continue button
            VStack {
                Spacer()
                
                OnboardCTAButton(title: "Keep going →", dark: true) {
                    onboardingState.nextStep()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
    }
}

// MARK: - Reward View
struct OnbRewardView: View {
    let onboardingState: OnboardingState
    
    var body: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [Color(hex: "0A0712"), Color(hex: "1A1428")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Confetti dots
            ForEach(0..<28, id: \.self) { index in
                ConfettiDot(index: index)
            }
            
            // Skip button
            VStack {
                HStack {
                    Spacer()
                    OnboardSkipButton(dark: true) {
                        onboardingState.skipToEnd()
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 60)
                }
                Spacer()
            }
            .zIndex(1)
            
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 130)
                
                // Header
                VStack(spacing: 8) {
                    Text("WELCOME REWARD")
                        .font(.system(size: 11, weight: .black))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    Text("Your starter pack 🎁")
                        .font(.lilitaOne(size: 34))
                        .tracking(-1.2)
                        .foregroundStyle(.white)
                    
                    Text("Plant your first tree on day one.")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                // Rewards
                VStack(spacing: 14) {
                    RewardCard(
                        icon: "⚡",
                        color: Color(hex: "FFD60A"),
                        number: "+3000",
                        label: "XP earned",
                        subtitle: "Spend on seeds in the store"
                    )

                    RewardCard(
                        icon: "💧",
                        color: Color(hex: "3DAEFF"),
                        number: "+27",
                        label: "Water drops",
                        subtitle: "Use to grow your garden"
                    )
                }
                .padding(.horizontal, 22)
                .padding(.top, 50)
                
                Spacer()
                
                // Continue button
                OnboardCTAButton(title: "Awesome →", dark: true) {
                    onboardingState.nextStep()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .zIndex(2)
        }
    }
}

// MARK: - Reward Card Component
struct RewardCard: View {
    let icon: String
    let color: Color
    let number: String
    let label: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon container
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.opacity(0.2))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(color.opacity(0.35), lineWidth: 1)
                    }
                
                Text(icon)
                    .font(.system(size: 28))
            }
            .frame(width: 56, height: 56)
            
            // Text content
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(number)
                        .font(.lilitaOne(size: 28))
                        .tracking(-0.8)
                        .foregroundStyle(color)
                    
                    Text(label)
                        .font(.lilitaOne(size: 14))
                        .foregroundStyle(.white.opacity(0.85))
                }
                
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
        }
        .background(.ultraThinMaterial.opacity(0.3))
    }
}

#Preview("Encourage - New") {
    OnbEncourageView(tone: .new, onboardingState: OnboardingState())
}

// MARK: - Confetti Dot Component
struct ConfettiDot: View {
    let index: Int
    
    private let colors = [Color(hex: "FFD60A"), YGColors.pink, YGColors.cyan, Color(hex: "B4FF3C"), Color(hex: "FF6B35")]
    
    private var size: CGFloat {
        CGFloat(6 + (index % 3) * 2)
    }
    
    private var xPos: CGFloat {
        CGFloat((index * 31) % 95 + 2) * UIScreen.main.bounds.width / 100
    }
    
    private var yPos: CGFloat {
        CGFloat((index * 47) % 60 + 10) * UIScreen.main.bounds.height / 100
    }
    
    var body: some View {
        Group {
            if index % 2 == 0 {
                Circle()
                    .fill(colors[index % 5])
            } else {
                RoundedRectangle(cornerRadius: 1)
                    .fill(colors[index % 5])
            }
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(Double(index * 20)))
        .opacity(0.9)
        .position(x: xPos, y: yPos)
    }
}

#Preview("Encourage - Correct") {
    OnbEncourageView(tone: .correct, onboardingState: OnboardingState())
}

#Preview("Reward") {
    OnbRewardView(onboardingState: OnboardingState())
}
