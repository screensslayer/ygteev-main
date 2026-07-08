//
//  FeaturedGamesCarousel.swift
//  YGTeeV
//
//  Paged carousel that hosts the Plans-tab hero. Replaces the
//  single-slide `FeaturedGameBanner` mount with a `TabView(.page)`
//  cycling through every featured game. Each slide is a separate
//  view (`BoostItFeaturedSlide`, `FeaturedGameBanner`, …) so they
//  keep their own destinations, taglines, and chrome.
//
//  Behavior:
//    • Auto-advances every 5s.
//    • Any manual swipe — or a slide tap that opens its destination
//      and then dismisses back — pauses auto-advance for 8s so we
//      don't yank the slide out from under the user.
//    • Pagination dots are owned at the carousel level so dots don't
//      duplicate inside individual slides.
//
//  Adding a third slide is a 3-step change:
//    1. New `@State var showXyz` in `PlansHomeView`.
//    2. New `.fullScreenCover` modifier next to the existing ones.
//    3. Bump `slideCount` here and add a third tab inside the
//       TabView, with `tag(2)` and an `onTap` closure.
//

import SwiftUI

struct FeaturedGamesCarousel: View {
    /// Each slide reports its tap through one of these closures so
    /// the parent can present the right destination. Adding slides
    /// = adding closures + tabs.
    let onTapBoostIt: () -> Void
    let onTapSplat: () -> Void

    @State private var selectedIndex: Int = 0
    /// Auto-advance is gated on `Date() >= pausedUntil`. We push this
    /// 8s into the future whenever the user does anything — manual
    /// swipe, or a tap that bounces back from a destination — so the
    /// carousel doesn't jump while they're still looking.
    @State private var pausedUntil: Date = .distantPast

    /// Total slides in the carousel. Bump when adding more.
    private let slideCount: Int = 2

    private let autoAdvanceSeconds: TimeInterval = 5
    private let pauseAfterInteractionSeconds: TimeInterval = 8

    /// Matches each individual slide's bannerHeight so the carousel's
    /// frame doesn't add a vertical gap or clip the slide content.
    private let bannerHeight: CGFloat = 620

    var body: some View {
        TabView(selection: $selectedIndex) {
            BoostItFeaturedSlide(onTap: handleTap(0, onTapBoostIt))
                .tag(0)
            FeaturedGameBanner(onTap: handleTap(1, onTapSplat))
                .tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: bannerHeight)
        .overlay(alignment: .bottom) {
            // Dots sit a bit off the bottom edge so they don't fall
            // under the content card that overlaps the banner at
            // rest. Hidden from accessibility — they're decorative;
            // VoiceOver users already get the individual slides as
            // buttons.
            PaginationDots(count: slideCount, selected: selectedIndex)
                .padding(.bottom, 220)
                .accessibilityHidden(true)
        }
        .onChange(of: selectedIndex) { _, _ in
            // Manual swipe → pause auto-advance for the grace window.
            pausedUntil = Date().addingTimeInterval(pauseAfterInteractionSeconds)
        }
        .task {
            // Auto-advance loop. Forever — the view is part of the
            // Plans tab which lives in the main tab bar. Task is
            // cancelled when the view disappears.
            while !Task.isCancelled {
                try? await Task.sleep(
                    nanoseconds: UInt64(autoAdvanceSeconds * 1_000_000_000)
                )
                guard !Task.isCancelled else { return }
                if Date() >= pausedUntil {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        selectedIndex = (selectedIndex + 1) % slideCount
                    }
                }
            }
        }
    }

    /// Wraps each slide's tap handler so we ALSO push the pause
    /// window before firing the parent's closure. Without this, the
    /// destination dismisses → auto-advance immediately ticks → the
    /// user lands on a different slide than they tapped.
    private func handleTap(_ index: Int, _ underlying: @escaping () -> Void) -> () -> Void {
        return {
            pausedUntil = Date().addingTimeInterval(pauseAfterInteractionSeconds)
            underlying()
        }
    }
}

// MARK: - Pagination dots

private struct PaginationDots: View {
    let count: Int
    let selected: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == selected ? Color.white : Color.white.opacity(0.4))
                    .frame(width: i == selected ? 22 : 6, height: 6)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: selected)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.25))
        .clipShape(Capsule())
    }
}
