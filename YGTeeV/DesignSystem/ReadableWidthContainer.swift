//
//  ReadableWidthContainer.swift
//  YGTeeV
//
//  Width-capped root for iPad (Phase 1 iPad support).
//
//  Strategy: instead of redesigning every screen for a tablet-native
//  layout, we constrain the whole shell to a phone-shaped column
//  centered on the tablet display. This lets the ~365 usages of
//  `UIScreen.main.bounds` and fixed `.frame(width:)` across the
//  codebase keep working unchanged — they sit in a 620pt-wide slot
//  regardless of device width.
//
//  Applied ONCE per app-root shell (MainTabView, OnboardingRootView,
//  OnboardingCoordinatorView). Full-screen covers presented from
//  within tabs — `BackyardGameView`, `JoinGroupMapView`, video
//  players, etc. — bypass the modifier by design and render
//  edge-to-edge on iPad, which is the correct behavior for maps,
//  the WKWebView game, and immersive media.
//
//  On compact-width devices (all iPhones) this modifier is a no-op:
//  the size class is `.compact` and we return `content` as-is with
//  no extra letterbox / background.
//

import SwiftUI

struct ReadableWidthContainer: ViewModifier {
    /// The horizontal size class of the container. iPhone in portrait
    /// is `.compact`; iPad in any orientation, and Max-class iPhones
    /// in landscape, are `.regular`.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// A phone-shaped column width. Wide enough for our largest
    /// two-column card layouts (~380 + padding + secondary column)
    /// without pushing far past a portrait iPhone Pro Max.
    private let maxContentWidth: CGFloat = 620

    func body(content: Content) -> some View {
        if horizontalSizeClass == .regular {
            // Regular width: letterbox with the app's dark background
            // filling the sides so the centered column reads as a
            // deliberate phone-shaped canvas, not accidental clipping.
            ZStack {
                Color.black.ignoresSafeArea()
                content
                    .frame(maxWidth: maxContentWidth)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            // Compact width (all iPhones in portrait): no-op — the
            // content already fills the device natively.
            content
        }
    }
}

extension View {
    /// Wrap the app-root shell so it renders as a centered
    /// phone-shaped column on iPad while remaining full-bleed on
    /// iPhone. See `ReadableWidthContainer` for the strategy.
    func readableWidthContainer() -> some View {
        modifier(ReadableWidthContainer())
    }
}
