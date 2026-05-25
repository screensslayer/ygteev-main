//
//  ProPriceSlider.swift
//  YGTeeV
//
//  Shared 5-stop price slider used by every Pro paywall surface
//  (onboarding paywall + plan-card paywall). Bound to an Int index
//  into PurchasesManager.subscriptionPackages so the host view can show
//  the selected package's localized price in the CTA.
//

import SwiftUI
import RevenueCat

struct ProPriceSlider: View {
    @Binding var selectedIndex: Int
    let packages: [Package]

    /// Loading placeholder when packages haven't landed yet.
    private var isLoading: Bool { packages.isEmpty }

    var body: some View {
        VStack(spacing: 14) {
            if isLoading {
                placeholder
            } else {
                stops
                priceLabel
            }
        }
        .padding(.horizontal, 22)
    }

    // MARK: - Stops

    private var stops: some View {
        GeometryReader { geo in
            let count = max(packages.count, 1)
            let trackHeight: CGFloat = 6
            let dotSize: CGFloat = 26
            let selectedDotSize: CGFloat = 36
            let stepWidth = geo.size.width / CGFloat(count - 1 == 0 ? 1 : count - 1)
            let selectedX = stepWidth * CGFloat(selectedIndex)

            ZStack(alignment: .leading) {
                // Muted track
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: trackHeight)
                    .frame(maxWidth: .infinity)

                // Active portion of the track up to the selected stop
                Capsule()
                    .fill(LinearGradient(
                        colors: [Color(hex: "FFD60A"), Color(hex: "FF6B35")],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: max(selectedX, 0), height: trackHeight)

                // Stop circles
                ForEach(packages.indices, id: \.self) { idx in
                    let isSelected = idx == selectedIndex
                    let x = stepWidth * CGFloat(idx)
                    Circle()
                        .fill(
                            isSelected
                            ? AnyShapeStyle(LinearGradient(
                                colors: [Color(hex: "FFD60A"), Color(hex: "FF6B35")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            : AnyShapeStyle(Color.white.opacity(0.25))
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(isSelected ? 0.0 : 0.35), lineWidth: 0.5)
                        )
                        .frame(
                            width: isSelected ? selectedDotSize : dotSize,
                            height: isSelected ? selectedDotSize : dotSize
                        )
                        .shadow(
                            color: isSelected ? Color(hex: "FF6B35").opacity(0.5) : .clear,
                            radius: 8, y: 3
                        )
                        .position(x: x, y: geo.size.height / 2)
                        .contentShape(Rectangle().inset(by: -12))
                        .onTapGesture {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                                selectedIndex = idx
                            }
                        }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let ratio = max(0, min(1, value.location.x / max(geo.size.width, 1)))
                        let raw = Int((ratio * CGFloat(count - 1)).rounded())
                        if raw != selectedIndex {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                selectedIndex = raw
                            }
                        }
                    }
            )
        }
        .frame(height: 48)
    }

    // MARK: - Price label

    private var priceLabel: some View {
        let selected = packages[safe: selectedIndex]
        let priceString = selected?.storeProduct.localizedPriceString ?? "—"
        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(priceString)
                .font(.lilitaOne(size: 36))
                .tracking(-1.2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "FFD60A"), Color(hex: "FF6B35")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            Text("/mo")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Placeholder

    private var placeholder: some View {
        HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 8, height: 8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48)
    }
}

// MARK: - Safe-subscript helper
//
// Kept fileprivate so it doesn't collide with any project-wide helper
// of the same name. If one already exists in the codebase, this file
// quietly uses it via Swift's name resolution.
extension Array {
    fileprivate subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
