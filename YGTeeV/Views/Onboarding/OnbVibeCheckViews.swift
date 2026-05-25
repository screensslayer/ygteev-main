//
//  OnbVibeCheckViews.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/7/26.
//

import SwiftUI

// MARK: - Vibe Check View
struct OnbVibeCheckView: View {
    let onboardingState: OnboardingState
    
    var body: some View {
        ZStack {
            Color(hex: "FAF8FF")
                .ignoresSafeArea()
            
            // Skip button
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
                Spacer()
                    .frame(height: 130)
                
                // Header
                VStack(alignment: .leading, spacing: 10) {
                    Text("QUICK VIBE CHECK")
                        .font(.system(size: 11, weight: .black))
                        .tracking(1.5)
                        .foregroundStyle(YGColors.violet)
                    
                    Text("Are you liking the app so far?")
                        .font(.lilitaOne(size: 30))
                        .tracking(-1.1)
                        .foregroundStyle(YGColors.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("Honestly. We're early — your answer actually shapes what we build next.")
                        .font(.system(size: 14))
                        .foregroundStyle(YGColors.ink.opacity(0.6))
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                
                // Options
                VStack(spacing: 14) {
                    // Love it
                    Button {
                        onboardingState.showReviewPrompt()
                    } label: {
                        HStack(spacing: 16) {
                            Text("🤩")
                                .font(.system(size: 44))
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text("I'm loving it")
                                    .font(.lilitaOne(size: 20))
                                    .tracking(-0.5)
                                    .foregroundStyle(.white)
                                
                                Text("This is exactly what I wanted")
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 20)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "6B2BFF"), YGColors.pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .shadow(color: YGColors.violet.opacity(0.35), radius: 12)
                    }
                    
                    // Not really
                    Button {
                        onboardingState.nextStep()
                    } label: {
                        HStack(spacing: 16) {
                            Text("🤔")
                                .font(.system(size: 44))
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Not really")
                                    .font(.lilitaOne(size: 20))
                                    .tracking(-0.5)
                                    .foregroundStyle(YGColors.ink)
                                
                                Text("Show me more before I decide")
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(YGColors.ink.opacity(0.55))
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 20)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .overlay {
                            RoundedRectangle(cornerRadius: 22)
                                .strokeBorder(YGColors.ink.opacity(0.08), lineWidth: 0.5)
                        }
                        .shadow(color: YGColors.ink.opacity(0.05), radius: 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)
                
                Spacer()
            }
        }
    }
}

// MARK: - Review Prompt View
struct OnbReviewPromptView: View {
    let onboardingState: OnboardingState
    
    var body: some View {
        ZStack {
            // Blurred background
            Color.black.opacity(0.55)
                .background(.ultraThinMaterial)
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
            .zIndex(1)
            
            // Alert-style dialog
            VStack(spacing: 0) {
                // Content
                VStack(spacing: 10) {
                    // App icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "6B2BFF"), YGColors.pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .black.opacity(0.2), radius: 3, y: -3)
                            .shadow(color: .white.opacity(0.3), radius: 1.5, y: 1.5)
                        
                        Text("YG")
                            .font(.lilitaOne(size: 20))
                            .tracking(-0.5)
                            .foregroundStyle(.white)
                    }
                    .frame(width: 56, height: 56)
                    
                    Text("Enjoying YGTeeV?")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black)
                    
                    Text("Tap a star to rate it on the App Store.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "3C3C43"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                    
                    // Stars
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(Color(hex: "FFB800"))
                        }
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                // Buttons
                HStack(spacing: 0) {
                    Button {
                        onboardingState.nextStep()
                    } label: {
                        Text("Not Now")
                            .font(.system(size: 16))
                            .foregroundStyle(Color(hex: "0A84FF"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                    }
                    
                    Divider()
                        .frame(height: 44)
                        .background(Color(hex: "3C3C43").opacity(0.18))
                    
                    Button {
                        // Rate action - then continue
                        onboardingState.nextStep()
                    } label: {
                        Text("Rate")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(hex: "0A84FF"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                    }
                }
                .overlay(alignment: .top) {
                    Divider()
                        .background(Color(hex: "3C3C43").opacity(0.18))
                }
            }
            .frame(width: 280)
            .background(Color(hex: "F5F5F7").opacity(0.95))
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.3), radius: 30)
            
            // Bottom caption
            VStack {
                Spacer()
                
                Text("Tap any option to keep going")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.bottom, 30)
            }
        }
    }
}

// MARK: - Account Intro View
struct OnbAccountIntroView: View {
    let onboardingState: OnboardingState
    
    var body: some View {
        ZStack {
            Color(hex: "FAF8FF")
                .ignoresSafeArea()
            
            // Skip button
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
                Spacer()
                    .frame(height: 110)
                
                // Garden preview with spotlight
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "A0E5FF"), Color(hex: "C8B5FF")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 200, height: 200)
                        .overlay {
                            RoundedRectangle(cornerRadius: 28)
                                .strokeBorder(.white, lineWidth: 4)
                        }
                        .shadow(color: YGColors.violet.opacity(0.25), radius: 20)
                    
                    // Sun
                    Circle()
                        .fill(Color(hex: "FFD60A"))
                        .frame(width: 24, height: 24)
                        .shadow(color: Color(hex: "FFD60A").opacity(0.6), radius: 11)
                        .offset(x: 66, y: -72)
                    
                    // Ground
                    LinearGradient(
                        colors: [Color(hex: "4CC65A"), Color(hex: "2B8A3E")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: 200, height: 70)
                    .offset(y: 65)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    
                    // Existing tree
                    SimplePixelTree(size: 70, color: Color(hex: "2B8A3E"))
                        .offset(x: -40, y: 30)
                    
                    // Spotlight on empty plot
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(hex: "FFD60A").opacity(0.5), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 18
                            )
                        )
                        .frame(width: 36, height: 36)
                        .offset(x: 28, y: 32)
                    
                    Text("?")
                        .font(.lilitaOne(size: 18))
                        .foregroundStyle(Color(hex: "FFD60A"))
                        .offset(x: 28, y: 30)
                }
                
                // Earned rewards
                HStack(spacing: 14) {
                    // XP earned
                    HStack(spacing: 6) {
                        Text("⚡")
                            .font(.system(size: 16))
                        Text("+3000 XP")
                            .font(.lilitaOne(size: 14))
                            .tracking(-0.2)
                            .foregroundStyle(Color(hex: "FFD60A"))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(hex: "FFD60A").opacity(0.15))
                    .clipShape(Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(Color(hex: "FFD60A").opacity(0.3), lineWidth: 0.5)
                    }
                    
                    // Water earned
                    HStack(spacing: 6) {
                        Text("💧")
                            .font(.system(size: 16))
                        Text("+27 Water")
                            .font(.lilitaOne(size: 14))
                            .tracking(-0.2)
                            .foregroundStyle(Color(hex: "3DAEFF"))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(hex: "3DAEFF").opacity(0.15))
                    .clipShape(Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(Color(hex: "3DAEFF").opacity(0.3), lineWidth: 0.5)
                    }
                }
                .padding(.top, 20)
                
                // Text content
                VStack(spacing: 12) {
                    Text("Save your garden.")
                        .font(.lilitaOne(size: 30))
                        .tracking(-1.1)
                        .foregroundStyle(YGColors.ink)
                    
                    Text("Create a free account so your XP and water can be used to grow your garden.")
                        .font(.system(size: 15))
                        .foregroundStyle(YGColors.ink.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .frame(maxWidth: 320)
                }
                .padding(.horizontal, 22)
                .padding(.top, 30)
                
                Spacer()
                
                // Continue button
                OnboardCTAButton(title: "Create my account →", dark: false) {
                    onboardingState.nextStep()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
    }
}

// MARK: - Feature Pill Component
struct FeaturePill: View {
    let icon: String
    let label: String
    
    var body: some View {
        HStack(spacing: 5) {
            Text(icon)
                .font(.system(size: 12))
            Text(label)
                .font(.lilitaOne(size: 12))
                .tracking(-0.1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.white)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.black.opacity(0.05), lineWidth: 0.5)
        }
        .shadow(color: YGColors.ink.opacity(0.04), radius: 2)
    }
}

#Preview("Vibe Check") {
    OnbVibeCheckView(onboardingState: OnboardingState())
}

#Preview("Review Prompt") {
    OnbReviewPromptView(onboardingState: OnboardingState())
}

#Preview("Account Intro") {
    OnbAccountIntroView(onboardingState: OnboardingState())
}
