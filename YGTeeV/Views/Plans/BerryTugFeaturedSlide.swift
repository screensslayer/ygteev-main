//
//  BerryTugFeaturedSlide.swift
//  YGTeeV
//
//  Featured-games carousel slide #3. Promotes the Berry Tug game.
//  Tapping anywhere on the slide launches `BerryTugGameView` full-
//  screen (the parent `PlansHomeView` owns the `@State` cover flag
//  and the .fullScreenCover modifier).
//
//  Visually mirrors `BoostItFeaturedSlide` — same banner height,
//  same bottom-anchored promo block, same MotionParallax on the
//  promo content, same stretchy-header parallax on the bg.
//
//  The tug-of-war art already carries the "TUG OF WAR" wordmark
//  built into the background image, so this slide skips the
//  separate `Image("*-logo")` and just floats a "▶ Play Now" CTA
//  pill over the composite artwork.
//

import SwiftUI
import CoreMotion

struct BerryTugFeaturedSlide: View {
    let onTap: () -> Void

    /// Matches the other slides so swiping between them doesn't
    /// make the chrome dance vertically.
    private let bannerHeight: CGFloat = 620
    private let contentCardOverlap: CGFloat = 263

    /// Reuses `MotionParallax` from `FeaturedGameBanner.swift` at
    /// file scope — same gyro driver, same low-pass filter.
    @State private var motion = MotionParallax()

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottom) {
                // Promo block — the composite art already includes
                // the "TUG OF WAR" wordmark, so we only need the
                // CTA pill here. Bottom-anchored to land at the
                // same Y as the other slides' CTAs.
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(hex: "FF3DA5"))
                        Text("Play Now")
                            .font(.lilitaOne(size: 17))
                            .foregroundStyle(YGColors.ink)
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(.white))
                    .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
                    .offset(
                        x: CGFloat(motion.roll) * 6,
                        y: CGFloat(motion.pitch) * 6
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, contentCardOverlap - 50)
            }
            .frame(height: bannerHeight)
            .frame(maxWidth: .infinity)
            // Background artwork — same `.background` pattern the
            // Boost It + Splat slides use so an intrinsic aspect
            // ratio doesn't blow up the parent width.
            .background {
                Image("tug-of-war-featured")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .scaleEffect(1.12)
                    .visualEffect { content, proxy in
                        // Same named coord-space lookup as the
                        // other slides so the stretchy header
                        // reads the outer scroll's rubber-band.
                        let minY = proxy.frame(in: .named("plansScroll")).minY
                        let pull = max(0, minY)
                        return content.scaleEffect(1 + pull / 220)
                    }
            }
            .clipped()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open Berry Tug — play the tug-of-war game")
        .accessibilityAddTraits(.isButton)
        .onAppear { motion.start() }
        .onDisappear { motion.stop() }
    }
}
