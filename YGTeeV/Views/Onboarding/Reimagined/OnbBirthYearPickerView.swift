//
//  OnbBirthYearPickerView.swift
//  YGTeeV
//
//  M5 — Birth year picker. Framed as a "quick safety check", not a
//  data-collection form: overline + honest one-liner about *why* we
//  need it. The design HTML replaces a standard date picker with a
//  huge gradient numeral you scrub, and a horizontal chip row below
//  as a visual reference of neighboring years.
//
//  Renamed from `OnbBirthYearView` to avoid a struct-name collision
//  with the legacy `Views/Onboarding/OnbBirthYearViews.swift` which
//  defines the same identifier — will be deleted in Phase 7 cutover.
//

import SwiftUI

struct OnbBirthYearPickerView: View {
    @Bindable var state: ReimaginedOnboardingState
    let advance: () -> Void

    /// Full picker range — 2005 through the current year. The default
    /// selection lands at 2012 (matches the design mock and keeps a
    /// realistic teen default). If the user cold-launches with a
    /// prior selection, we honor that instead.
    private var years: [Int] {
        let now = Calendar.current.component(.year, from: Date())
        return Array(2005...now)
    }

    /// The year currently displayed as the huge gradient numeral +
    /// centered chip. Seeded either from prior state or the default
    /// mid-teen year.
    @State private var selectedYear: Int = 2012

    var body: some View {
        VStack(spacing: 0) {
            // Progress crumbs — third phase is active. The wide pill
            // is the third dot per the design mock's "Safety" step.
            HStack(spacing: 5) {
                Capsule().fill(YGColors.ink.opacity(0.85)).frame(width: 6, height: 6)
                Capsule().fill(YGColors.ink.opacity(0.85)).frame(width: 6, height: 6)
                Capsule().fill(YGColors.ink).frame(width: 22, height: 6)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            VStack(alignment: .leading, spacing: 10) {
                Text("QUICK SAFETY CHECK")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(YGColors.violet)

                Text("What year\nwere you born?")
                    .font(.lilitaOne(size: 32))
                    .foregroundStyle(YGColors.ink)

                Text("We use this to keep younger users safe. We never share it.")
                    .font(.system(size: 13))
                    .foregroundStyle(YGColors.ink.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 20)

            Spacer(minLength: 20)

            // Big gradient year numeral — the hero visual.
            VStack(spacing: 8) {
                Text(String(selectedYear))
                    .font(.lilitaOne(size: 92))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [YGColors.violet, YGColors.pink, YGColors.yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .contentTransition(.numericText(value: Double(selectedYear)))
                    .animation(.snappy, value: selectedYear)

                Text("Swipe to change")
                    .font(.system(size: 12.5))
                    .foregroundStyle(YGColors.ink.opacity(0.5))
            }

            // Horizontal chip picker. Currently-selected chip is a
            // dark filled pill; neighbors are subtle white cards. Tap
            // any chip to jump to it — swipe naturally via the
            // ScrollView + scrollPosition binding.
            YearChipRow(years: years, selected: $selectedYear)
                .padding(.top, 20)

            Spacer()

            // Primary CTA + private/required footer.
            VStack(spacing: 10) {
                Button {
                    state.birthYear = selectedYear
                    advance()
                } label: {
                    Text("Continue →")
                        .font(.lilitaOne(size: 18))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [YGColors.violet, YGColors.violetDeep],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: YGColors.violet.opacity(0.4), radius: 20, y: 8)
                }

                HStack(spacing: 5) {
                    Text("🛡️")
                    Text("Private. Required for safety.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(YGColors.ink.opacity(0.45))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(YGColors.paper)
        .onAppear {
            if let stored = state.birthYear {
                selectedYear = stored
            }
        }
    }
}

// MARK: - YearChipRow
//
// Horizontal scroll of year chips. Uses iOS 17's `scrollPosition`
// binding to snap the selected chip to center; taps on visible chips
// select without scroll. The active chip is dark/filled, neighbors
// are white cards — matches the design mock's chip strip.

private struct YearChipRow: View {
    let years: [Int]
    @Binding var selected: Int

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(years, id: \.self) { year in
                        chip(year: year)
                            .id(year)
                            .onTapGesture {
                                withAnimation(.snappy) {
                                    selected = year
                                    proxy.scrollTo(year, anchor: .center)
                                }
                            }
                    }
                }
                .padding(.horizontal, 40)
            }
            .frame(height: 60)
            .onAppear {
                // Center the initial selection with no animation.
                proxy.scrollTo(selected, anchor: .center)
            }
            .onChange(of: selected) { _, new in
                withAnimation(.snappy) {
                    proxy.scrollTo(new, anchor: .center)
                }
            }
        }
    }

    private func chip(year: Int) -> some View {
        let isActive = year == selected
        return Text(String(year))
            .font(.lilitaOne(size: isActive ? 20 : 16))
            .foregroundStyle(isActive ? Color.white : YGColors.ink.opacity(0.5))
            .padding(.horizontal, isActive ? 18 : 14)
            .padding(.vertical, isActive ? 12 : 10)
            .background(isActive ? YGColors.ink : Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.black.opacity(0.05), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(isActive ? 0.2 : 0.03), radius: isActive ? 8 : 2, y: isActive ? 4 : 1)
    }
}
