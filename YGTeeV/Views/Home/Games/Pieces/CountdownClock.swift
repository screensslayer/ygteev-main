//
//  CountdownClock.swift
//  YGTeeV
//
//  Big MM:SS clock used as the lobby headline when a room has a
//  scheduled start. Ticks every second via `TimelineView(.periodic)`;
//  the host's status → in_game flip drives the actual screen
//  transition — the client never advances state itself.
//

import SwiftUI

struct CountdownClock: View {
    let target: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let secs = max(0, Int(target.timeIntervalSince(ctx.date)))
            let urgent = secs <= 10 && secs > 0
            VStack(spacing: 6) {
                Text(secs == 0 ? "STARTING NOW" : "STARTS IN")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(.white.opacity(0.55))
                Text(formatted(secs))
                    .font(.lilitaOne(size: 86))
                    .tracking(-2)
                    .foregroundStyle(urgent ? YGColors.yellow : .white)
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.easeOut(duration: 0.25), value: secs)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .padding(.horizontal, 24)
            .background(Color.black.opacity(0.22))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
    }

    private func formatted(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }
}
