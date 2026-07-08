//
//  OnbGradeYearView.swift
//  YGTeeV
//
//  M4 — Grade year picker. 6-12 or "not a student". Reads/writes
//  `state.gradeYear`. Phase 1 uses a compact grid; Phase 4 will match
//  the design HTML's chunky pill styling.
//

import SwiftUI

struct OnbGradeYearView: View {
    @Bindable var state: ReimaginedOnboardingState
    let advance: () -> Void

    private let grades: [Int] = Array(6...12)

    var body: some View {
        SkeletonScreen(
            stepLabel: "M4 · GRADE",
            title: "What grade are you in?",
            subtitle: "Tap 'Not a student' if you're past school.",
            actionLabel: "Continue →",
            onAction: advance
        ) {
            VStack(spacing: 10) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(grades, id: \.self) { grade in
                        gradePill(grade)
                    }
                }
                Button {
                    state.gradeYear = nil
                } label: {
                    Text("Not a student")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(state.gradeYear == nil ? YGColors.violet.opacity(0.12) : .white)
                        .foregroundStyle(state.gradeYear == nil ? YGColors.violet : YGColors.ink)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(state.gradeYear == nil ? YGColors.violet : .black.opacity(0.08),
                                              lineWidth: state.gradeYear == nil ? 2 : 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 4)
        }
    }

    private func gradePill(_ grade: Int) -> some View {
        Button {
            state.gradeYear = grade
        } label: {
            Text("\(grade)")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(state.gradeYear == grade ? .white : YGColors.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(state.gradeYear == grade ? YGColors.violet : .white)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(state.gradeYear == grade ? Color.clear : .black.opacity(0.08),
                                      lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
