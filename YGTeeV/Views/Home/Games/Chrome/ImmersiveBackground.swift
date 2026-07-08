//
//  ImmersiveBackground.swift
//  YGTeeV
//
//  Full-bleed background for the Game Night immersive flow. Ink fill
//  + three violet/blue/pink radial-glow ellipses to match the React
//  mockup. This is the ONLY file in the immersive flow that calls
//  `.ignoresSafeArea()` — every other view (top chrome, stages,
//  footer) respects the system safe area via the shell's layout.
//

import SwiftUI

struct ImmersiveBackground: View {
    var body: some View {
        ZStack {
            YGColors.ink

            Ellipse()
                .fill(RadialGradient(
                    colors: [YGColors.violet.opacity(0.55), .clear],
                    center: .center,
                    startRadius: 0, endRadius: 260))
                .frame(width: 520, height: 380)
                .offset(x: -120, y: -260)

            Ellipse()
                .fill(RadialGradient(
                    colors: [YGColors.blue.opacity(0.4), .clear],
                    center: .center,
                    startRadius: 0, endRadius: 230))
                .frame(width: 480, height: 380)
                .offset(x: 180, y: -100)

            Ellipse()
                .fill(RadialGradient(
                    colors: [YGColors.pink.opacity(0.35), .clear],
                    center: .center,
                    startRadius: 0, endRadius: 260))
                .frame(width: 540, height: 360)
                .offset(x: 0, y: 360)
        }
        .ignoresSafeArea()
    }
}
