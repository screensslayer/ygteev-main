//
//  OnbBirthYearViews.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/7/26.
//

import SwiftUI

// MARK: - Birth Year View
struct OnbBirthYearView: View {
    let onboardingState: OnboardingState
    
    var years: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return (0..<60).map { currentYear - $0 }
    }
    
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
                // Header
                VStack(alignment: .leading, spacing: 10) {
                    Text("QUICK SAFETY CHECK")
                        .font(.system(size: 11, weight: .black))
                        .tracking(1.5)
                        .foregroundStyle(YGColors.violet)
                    
                    Text("When were you born?")
                        .font(.lilitaOne(size: 30))
                        .tracking(-1.1)
                        .foregroundStyle(YGColors.ink)
                    
                    Text("We need this so we keep things safe for younger users. We never share it.")
                        .font(.system(size: 13.5))
                        .foregroundStyle(YGColors.ink.opacity(0.6))
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.top, 110)
                
                Spacer()
                
                // Big year display
                VStack(spacing: 8) {
                    Text("\(onboardingState.birthYear)")
                        .font(.system(size: 88, weight: .black, design: .rounded))
                        .tracking(-3)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "6B2BFF"), YGColors.pink, Color(hex: "FFD60A")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("Tap to change")
                        .font(.system(size: 13))
                        .foregroundStyle(YGColors.ink.opacity(0.5))
                }
                
                // Year picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(years, id: \.self) { year in
                            YearButton(
                                year: year,
                                isSelected: year == onboardingState.birthYear
                            ) {
                                onboardingState.birthYear = year
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                }
                .frame(height: 60)
                .padding(.top, 30)
                
                Spacer()
                
                // Continue button
                VStack(spacing: 10) {
                    OnboardCTAButton(title: "Continue →", dark: false) {
                        onboardingState.nextStep()
                    }
                    
                    HStack(spacing: 4) {
                        Text("🛡️")
                            .font(.system(size: 11.5))
                        Text("Your birth year is private. Required for safety.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(YGColors.ink.opacity(0.45))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
    }
}

// MARK: - Year Button Component
struct YearButton: View {
    let year: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("\(year)")
                .font(.lilitaOne(size: isSelected ? 18 : 16))
                .monospacedDigit()
                .foregroundStyle(isSelected ? .white : YGColors.ink.opacity(0.65))
                .padding(.horizontal, isSelected ? 18 : 14)
                .padding(.vertical, isSelected ? 12 : 10)
                .background(isSelected ? YGColors.ink : .white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            isSelected ? Color.clear : Color.black.opacity(0.05),
                            lineWidth: 0.5
                        )
                }
                .shadow(
                    color: isSelected ? .black.opacity(0.18) : YGColors.ink.opacity(0.04),
                    radius: isSelected ? 6 : 2
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Birth Year Confirm View
struct OnbBirthConfirmView: View {
    let onboardingState: OnboardingState
    
    var age: Int {
        let currentYear = Calendar.current.component(.year, from: Date())
        return currentYear - onboardingState.birthYear
    }
    
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
            
            // Confirmation dialog
            VStack(spacing: 18) {
                // Emoji icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "FFD60A"), Color(hex: "FF6B35")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .black.opacity(0.18), radius: 3, y: -3)
                        .shadow(color: .white.opacity(0.4), radius: 1.5, y: 1.5)
                    
                    Text("🎂")
                        .font(.system(size: 30))
                }
                .frame(width: 56, height: 56)
                
                Text("Are you sure?")
                    .font(.lilitaOne(size: 22))
                    .tracking(-0.6)
                    .foregroundStyle(YGColors.ink)
                
                Text("You said you were born in")
                    .font(.system(size: 14))
                    .foregroundStyle(YGColors.ink.opacity(0.65))
                    .lineSpacing(3)
                
                Text("\(onboardingState.birthYear)")
                    .font(.lilitaOne(size: 38))
                    .tracking(-1.2)
                    .foregroundStyle(YGColors.ink)
                
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Text("That makes you")
                            .font(.system(size: 12.5))
                            .foregroundStyle(YGColors.ink.opacity(0.55))
                        
                        Text("\(age) years old")
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(YGColors.ink)
                    }
                    
                    Text("You can't change this later.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(YGColors.ink.opacity(0.55))
                }
                
                VStack(spacing: 10) {
                    OnboardCTAButton(title: "Yes, that's right", dark: false) {
                        onboardingState.nextStep()
                    }
                    
                    OnboardCTAButton(title: "No, change it", secondary: true, dark: false) {
                        onboardingState.goBack()
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 24)
            .frame(width: 320)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.35), radius: 30)
        }
    }
}

#Preview("Birth Year") {
    OnbBirthYearView(onboardingState: OnboardingState())
}

#Preview("Birth Year Confirm") {
    OnbBirthConfirmView(onboardingState: OnboardingState())
}
