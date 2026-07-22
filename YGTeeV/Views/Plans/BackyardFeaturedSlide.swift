//
//  BackyardFeaturedSlide.swift
//  YGTeeV
//
//  Featured-games carousel slide. Promotes the YGTeeV Backyard web
//  game — tapping anywhere on the slide opens `BackyardGameView` in
//  a full-screen WKWebView (the parent `PlansHomeView` owns the
//  cover flag and the .fullScreenCover modifier).
//
//  Visually mirrors `BoostItFeaturedSlide`: same banner height, same
//  bottom-anchored promo block, same `MotionParallax` on the logo,
//  same stretchy-header parallax on the bg. Adds a tagline between
//  the wordmark and the CTA pill.
//

import SwiftUI
import CoreMotion

struct BackyardFeaturedSlide: View {
    let onTap: () -> Void

    /// Matches the other slides so swiping between them doesn't make
    /// the chrome dance vertically.
    private let bannerHeight: CGFloat = 620
    private let contentCardOverlap: CGFloat = 263

    /// Reuse the gyro driver defined in `FeaturedGameBanner.swift` at
    /// file scope so all slides share the same low-pass filter feel.
    @State private var motion = MotionParallax()

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottom) {
                VStack(spacing: 8) {
                    Image("backyard-logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 260)
                        .offset(
                            x: CGFloat(motion.roll) * 14,
                            y: CGFloat(motion.pitch) * 14
                        )
                        .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
                        .accessibilityHidden(true)

                    Text("GROW YOUR GROUP'S GARDEN")
                        .font(.lilitaOne(size: 15))
                        .foregroundStyle(.white)
                        .tracking(1)
                        .shadow(color: .black.opacity(0.45), radius: 6, y: 2)

                    // CTA pill — leaf + "Play Backyard" in dark ink on
                    // white, matching the geometry of the Boost It /
                    // Splat slide pills so all slides land the same
                    // chrome at the same Y as the user swipes.
                    HStack(spacing: 8) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(hex: "8BE04B"))
                        Text("Play Backyard")
                            .font(.lilitaOne(size: 17))
                            .foregroundStyle(YGColors.ink)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(.white))
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, contentCardOverlap - 50)
            }
            .frame(height: bannerHeight)
            .frame(maxWidth: .infinity)
            .background {
                Image("backyard-bg")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .scaleEffect(1.12)
                    .visualEffect { content, proxy in
                        // Named coord-space lookup so the stretchy
                        // header reads the OUTER ScrollView's
                        // rubber-band, not the TabView pager that
                        // wraps each carousel slide.
                        let minY = proxy.frame(in: .named("plansScroll")).minY
                        let pull = max(0, minY)
                        return content.scaleEffect(1 + pull / 220)
                    }
            }
            .clipped()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open YGTeeV Backyard — grow your group's garden")
        .accessibilityAddTraits(.isButton)
        .onAppear { motion.start() }
        .onDisappear { motion.stop() }
    }
}
