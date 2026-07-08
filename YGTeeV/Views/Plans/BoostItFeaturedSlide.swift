//
//  BoostItFeaturedSlide.swift
//  YGTeeV
//
//  Featured-games carousel slide #1. Promotes the youth-group map
//  (a.k.a. "Boost It") — tapping anywhere on the slide opens
//  `JoinGroupMapView` so members can boost discovered placeholders
//  and find local groups.
//
//  Visually mirrors `FeaturedGameBanner`: same banner height, same
//  bottom-anchored promo block, same `MotionParallax` logo drift.
//  The only differences are the bg image, the logo, the tagline,
//  and the white CTA pill content. No countdown — that's Splat-
//  specific. No inline page dots — the parent `FeaturedGamesCarousel`
//  owns those for the whole carousel.
//

import SwiftUI
import CoreMotion

struct BoostItFeaturedSlide: View {
    let onTap: () -> Void

    /// Matches `FeaturedGameBanner.bannerHeight` so the carousel
    /// frame stays uniform across slides. Same `contentCardOverlap`
    /// + bottom padding offset for the same reason — the promo
    /// block lands at the same Y as the Splat slide's, so swiping
    /// between them doesn't make the chrome dance vertically.
    private let bannerHeight: CGFloat = 620
    private let contentCardOverlap: CGFloat = 263

    /// `MotionParallax` lives in `FeaturedGameBanner.swift` at file
    /// scope (internal) — reuse rather than duplicate. Same gyro
    /// driver, same low-pass filter behavior.
    @State private var motion = MotionParallax()

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottom) {
                // Promo block — logo + tagline + CTA pill. Bottom-
                // anchored so it lands just above where the content
                // card overlaps the banner at rest, regardless of
                // the column's intrinsic height.
                VStack(spacing: 8) {
                    Image("boost-it-logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 260)
                        .offset(
                            x: CGFloat(motion.roll) * 14,
                            y: CGFloat(motion.pitch) * 14
                        )
                        .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
                        .accessibilityHidden(true)

                    Text("BOOST YOUR YOUTH GROUP")
                        .font(.lilitaOne(size: 17))
                        .tracking(0.6)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.55), radius: 4, y: 1)
                        .multilineTextAlignment(.center)
                        .accessibilityHidden(true)

                    // CTA pill — bolt + "Open the map" in dark ink
                    // on white, matching the geometry of the Splat
                    // slide's countdown pill so the two slides have
                    // identical chrome at the same Y. The parent
                    // Button captures the tap, so the pill is purely
                    // visual.
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(hex: "1FD4C7"))
                        Text("Open the map")
                            .font(.lilitaOne(size: 17))
                            .foregroundStyle(YGColors.ink)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(.white))
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
                }
                .padding(.horizontal, 24)
                // Same magic offset as the Splat slide — see the
                // long comment in FeaturedGameBanner for why this is
                // `contentCardOverlap - 50` instead of the bare
                // overlap. Keep the two values in lockstep so the
                // promo block lines up vertically as the user swipes
                // between slides.
                .padding(.bottom, contentCardOverlap - 50)
            }
            .frame(height: bannerHeight)
            .frame(maxWidth: .infinity)
            // Background artwork as `.background` for the same
            // width-anchoring reason called out in FeaturedGameBanner:
            // a layout-child Image with an intrinsic >1 aspect ratio
            // demands a natural width wider than the screen and
            // pushes the page out. With `.background`, the image
            // fills the banner's frame and can't grow the parent.
            .background {
                Image("boost-it-bg")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .scaleEffect(1.12)
                    .visualEffect { content, proxy in
                        let minY = proxy.frame(in: .scrollView).minY
                        let pull = max(0, minY)
                        return content.scaleEffect(1 + pull / 220)
                    }
            }
            .clipped()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open Boost It — find youth groups near you")
        .accessibilityAddTraits(.isButton)
        .onAppear { motion.start() }
        .onDisappear { motion.stop() }
    }
}
