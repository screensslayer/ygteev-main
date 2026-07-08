//
//  OnbBirthYearView.swift
//  YGTeeV
//
//  M5 — Birth year picker. Drives the under-13 branch derived by
//  `state.isUnder13` on the next screen (M6 double-check).
//

import SwiftUI

struct OnbBirthYearView: View {
    @Bindable var state: ReimaginedOnboardingState
    let advance: () -> Void

    private var years: [Int] {
        let now = Calendar.current.component(.year, from: Date())
        return Array((now - 25)...(now - 5)).reversed()
    }

    var body: some View {
        SkeletonScreen(
            stepLabel: "M5 · BIRTH YEAR",
            title: "When were you born?",
            subtitle: "We use this to keep young users protected under COPPA.",
            actionLabel: "Continue →",
            actionEnabled: state.birthYear != nil,
            onAction: advance
        ) {
            Picker("Birth year", selection: Binding(
                get: { state.birthYear ?? years.first ?? 2010 },
                set: { state.birthYear = $0 }
            )) {
                ForEach(years, id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxHeight: 220)
        }
    }
}
