//
//  OnbWelcomeView.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/7/26.
//

import SwiftUI

struct OnbWelcomeView: View {
    let onboardingState: OnboardingState
    @State private var showChildSignIn = false

    var body: some View {
        ZStack {
            // Gradient background
            RadialGradient(
                colors: [
                    Color(hex: "6B2BFF"),
                    Color(hex: "3D0FB8"),
                    Color(hex: "0A0712")
                ],
                center: .top,
                startRadius: 0,
                endRadius: 600
            )
            .ignoresSafeArea()
            
            // Floating decoration
            Circle()
                .fill(RadialGradient(
                    colors: [YGColors.pink.opacity(0.6), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 100
                ))
                .frame(width: 200, height: 200)
                .blur(radius: 10)
                .offset(x: -120, y: -300)
            
            Circle()
                .fill(RadialGradient(
                    colors: [YGColors.cyan.opacity(0.5), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 90
                ))
                .frame(width: 180, height: 180)
                .blur(radius: 10)
                .offset(x: 140, y: -330)
            
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
            

            
            // Bottom content
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 12) {
                    // Logo
                    Image("ygteev-logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120)
                    
                    VStack(spacing: 0) {
                        Text("Grow your faith.")
                            .font(.lilitaOne(size: 34))
                            .tracking(-1.2)
                            .foregroundStyle(.white)

                        Text("Grow your garden.")
                            .font(.lilitaOne(size: 34))
                            .tracking(-1.2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "FFD60A"), YGColors.pink, YGColors.cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }

                    Text("The Bible app made to earn XP, build streaks, and find a local community.")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .frame(maxWidth: 290)
                        .padding(.top, 6)
                    
                    OnboardCTAButton(title: "Let's go →", dark: true) {
                        onboardingState.nextStep()
                    }
                    .padding(.top, 16)
                    
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.55))

                        Button {
                            onboardingState.goToLogin()
                        } label: {
                            Text("Sign in")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white.opacity(0.95))
                        }
                    }
                    .padding(.top, 6)

                    Button {
                        showChildSignIn = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 12, weight: .heavy))
                            Text("Sign in with parent's QR")
                                .font(.system(size: 12, weight: .heavy))
                        }
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Capsule())
                        .overlay {
                            Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
                        }
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 36)
            }
        }
        .fullScreenCover(isPresented: $showChildSignIn) {
            ChildSignInSheet {
                // The kid is now signed in. Flip the onboarding flag so
                // RootView swaps from OnboardingCoordinator → MainTabView.
                onboardingState.hasCompletedOnboarding = true
            }
        }
    }
}

// MARK: - Simple Pixel Tree Component
struct SimplePixelTree: View {
    let size: CGFloat
    let color: Color
    
    var body: some View {
        VStack(spacing: 0) {
            // Crown - simple triangle shape made with rectangles
            VStack(spacing: -size * 0.08) {
                Rectangle()
                    .fill(color)
                    .frame(width: size * 0.3, height: size * 0.3)
                
                Rectangle()
                    .fill(color)
                    .frame(width: size * 0.5, height: size * 0.3)
                
                Rectangle()
                    .fill(color)
                    .frame(width: size * 0.7, height: size * 0.3)
            }
            
            // Trunk
            Rectangle()
                .fill(Color(hex: "5D4E37"))
                .frame(width: size * 0.2, height: size * 0.25)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    OnbWelcomeView(onboardingState: OnboardingState())
}
