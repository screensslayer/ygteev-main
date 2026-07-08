//
//  ChoiceCard.swift
//  YGTeeV
//
//  A single A-or-B choice tile rendered in the Majority Rules
//  in-game stage. Two of these live in an HStack and each uses
//  `.frame(maxWidth: .infinity)` so they share the row evenly. The
//  card sizes to its content with a sensible `minHeight` floor —
//  there's no bottom Spacer because the cards live in an HStack
//  inside a vertically-flexible parent, and pushing the text away
//  from the letter badge would let the card stretch to fill the
//  whole vertical column (which is what made them look 350pt tall).
//
//  Picked state fills with the accent gradient + white border;
//  unpicked is a soft tint with a 1.5pt border in the accent
//  colour. No emoji — the backend's `current_question_public`
//  payload for Majority Rules ships text only.
//

import SwiftUI

struct ChoiceCard: View {
    let letter: String
    let text: String
    let accent: Color
    let isPicked: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                HStack {
                    Text(letter)
                        .font(.lilitaOne(size: 17))
                        .foregroundStyle(isPicked ? YGColors.ink : .white)
                        .frame(width: 32, height: 32)
                        .background(isPicked ? Color.white : accent)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Spacer()
                }

                Text(text)
                    .font(.lilitaOne(size: 19))
                    .tracking(-0.4)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, minHeight: 140)
            .background(
                Group {
                    if isPicked {
                        LinearGradient(colors: [accent, accent.opacity(0.6)],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing)
                    } else {
                        accent.opacity(0.12)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(isPicked ? Color.white : accent.opacity(0.4),
                                  lineWidth: isPicked ? 2 : 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .shadow(color: isPicked ? accent.opacity(0.5) : .clear, radius: 16, y: 10)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}
