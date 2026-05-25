//
//  FindAnEventCard.swift
//  YGTeeV
//
//  Two shapes of the same affordance: the dashed-tile that closes
//  every upcoming carousel, and the full-width banner that replaces
//  the carousel entirely when a person has zero upcoming events.
//  Both route to the map (open-group / find-event flow).
//

import SwiftUI

struct FindAnEventCard: View {
    enum Style { case tile, banner }
    let style: Style
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            switch style {
            case .tile:
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32, weight: .semibold))
                    Text("Find an event")
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(YGColors.violet)
                .frame(width: 220, height: 180)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(YGColors.violet.opacity(0.4),
                                      style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                )

            case .banner:
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Find An Upcoming Event")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(YGColors.violet, in: Capsule())
                .padding(.horizontal, 16)
            }
        }
        .buttonStyle(.plain)
    }
}
