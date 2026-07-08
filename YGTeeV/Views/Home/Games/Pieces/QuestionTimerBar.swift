//
//  QuestionTimerBar.swift
//  YGTeeV
//
//  Slim countdown bar shown at the top of the in-game stage. Source
//  of truth is `gn_rooms.question_started_at` + `room.settings.timer_seconds`
//  (defaults to 20). The bar fills green→yellow normally and flips to
//  orange→pink with a soft glow in the urgent final 5 seconds. The
//  server's status flip — not the client's timer — actually ends the
//  question; this bar is purely cosmetic.
//

import SwiftUI

struct QuestionTimerBar: View {
    let questionStartedAt: Date?
    let timerSeconds: Int

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let remaining = secondsRemaining(now: ctx.date)
            let pct = pct(remaining: remaining)
            let urgent = remaining <= 5 && remaining > 0
            HStack(spacing: 10) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                        Capsule()
                            .fill(LinearGradient(
                                colors: urgent
                                    ? [Color(hex: "FF6B35"), Color(hex: "FB7185")]
                                    : [Color(hex: "34D399"), YGColors.yellow],
                                startPoint: .leading,
                                endPoint: .trailing))
                            .frame(width: max(0, geo.size.width * pct))
                            .shadow(color: urgent ? Color(hex: "FB7185") : .clear,
                                    radius: 6)
                    }
                }
                .frame(height: 9)

                Text("\(remaining)")
                    .font(.lilitaOne(size: 17))
                    .foregroundStyle(urgent ? Color(hex: "FB7185") : .white)
                    .monospacedDigit()
                    .frame(minWidth: 24, alignment: .trailing)
            }
        }
    }

    private func secondsRemaining(now: Date) -> Int {
        guard let started = questionStartedAt else { return timerSeconds }
        let elapsed = Int(now.timeIntervalSince(started))
        return max(0, timerSeconds - elapsed)
    }

    private func pct(remaining: Int) -> Double {
        guard timerSeconds > 0 else { return 0 }
        return max(0, min(1, Double(remaining) / Double(timerSeconds)))
    }
}
