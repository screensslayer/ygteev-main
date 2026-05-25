//
//  OnbGradeYearView.swift
//  YGTeeV
//
//  "What grade are you in?" — between accountIntro and birthYear. The
//  school-year label flips on May 1 each year so a student picking in
//  June is choosing for the upcoming year, not the one that just ended.
//

import SwiftUI

struct OnbGradeYearView: View {
    let onboardingState: OnboardingState

    @State private var picked: Int? = nil
    @State private var notAStudent: Bool = false

    /// Six through twelve only — the audience is teens.
    private let grades = Array(6...12)

    private var schoolYearLabel: String { SchoolYear.currentLabel() }

    private var canContinue: Bool {
        picked != nil || notAStudent
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

                VStack(alignment: .leading, spacing: 8) {
                    Text("ABOUT YOU")
                        .font(.system(size: 11, weight: .black))
                        .tracking(1.5)
                        .foregroundStyle(YGColors.violet)

                    Text("What grade are you in for the \(schoolYearLabel) school year?")
                        .font(.lilitaOne(size: 26))
                        .tracking(-0.9)
                        .foregroundStyle(YGColors.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.top, 6)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(grades, id: \.self) { g in
                            gradeCard(grade: g)
                        }

                        notAStudentRow
                            .padding(.top, 6)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 22)
                    .padding(.bottom, 24)
                }

                Spacer(minLength: 0)

                OnboardCTAButton(title: "Continue →") {
                    onboardingState.gradeLevel = notAStudent ? nil : picked
                    onboardingState.nextStep()
                }
                .opacity(canContinue ? 1 : 0.4)
                .disabled(!canContinue)
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
    }

    // MARK: - Subviews

    private func gradeCard(grade: Int) -> some View {
        let isPicked = picked == grade && !notAStudent
        return Button {
            picked = grade
            notAStudent = false
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            isPicked ? Color.white : YGColors.ink.opacity(0.2),
                            lineWidth: 2
                        )
                        .background(Circle().fill(isPicked ? Color.white : .clear))
                    if isPicked {
                        Circle()
                            .fill(YGColors.violet)
                            .frame(width: 10, height: 10)
                    }
                }
                .frame(width: 22, height: 22)

                Text(ordinal(grade))
                    .font(.lilitaOne(size: 16))
                    .tracking(-0.2)
                    .foregroundStyle(isPicked ? .white : YGColors.ink)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                Group {
                    if isPicked {
                        LinearGradient(
                            colors: [YGColors.violet, Color(hex: "FF3DA5")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        Color.white
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isPicked ? Color.clear : Color.black.opacity(0.05), lineWidth: 0.5)
            }
            .shadow(
                color: isPicked ? YGColors.violet.opacity(0.35) : YGColors.ink.opacity(0.04),
                radius: isPicked ? 8 : 2,
                y: isPicked ? 4 : 0
            )
        }
        .buttonStyle(.plain)
    }

    private var notAStudentRow: some View {
        Button {
            notAStudent = true
            picked = nil
        } label: {
            HStack(spacing: 10) {
                Image(systemName: notAStudent ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(notAStudent ? YGColors.violet : YGColors.ink.opacity(0.35))
                Text("I'm not a student")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(YGColors.ink)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(notAStudent ? YGColors.violet.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func ordinal(_ n: Int) -> String {
        let suffix: String
        switch n {
        case 11, 12: suffix = "th"
        default:
            switch n % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix) grade"
    }
}

// MARK: - School-year helper

enum SchoolYear {
    /// Returns "2026-27"-style label. US academic year flips on May 1 —
    /// picking a grade in June is for the upcoming September, not the
    /// year that just ended in May.
    static func currentLabel(now: Date = .now,
                             calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: now)
        let year = comps.year ?? 2026
        let month = comps.month ?? 1
        let day = comps.day ?? 1
        let isAfterMay1 = month > 5 || (month == 5 && day >= 1)
        let startYear = isAfterMay1 ? year : year - 1
        let endTwo = String(startYear + 1).suffix(2)
        return "\(startYear)-\(endTwo)"
    }
}

#Preview {
    OnbGradeYearView(onboardingState: OnboardingState())
}
