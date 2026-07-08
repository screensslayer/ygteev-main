//
//  GameFooter.swift
//  YGTeeV
//
//  Persistent bottom chrome rendered by `ImmersiveGameShell` when
//  the current room status warrants it (in_game / reveal /
//  finished — never lobby). Shows the caller's avatar + handle on
//  the left and a row of per-question result squares on the right.
//
//  No running score — Majority Rules doesn't credit points along
//  the way; only the final podium gets XP. Displaying a running 0
//  was misleading.
//

import SwiftUI

struct GameFooter: View {
    let totalQuestions: Int?
    let questionResults: [Int: Bool]
    let currentQuestionIndex: Int?

    private var myName: String {
        SupabaseManager.shared.currentUser?.handle
            ?? SupabaseManager.shared.currentUser?.displayName
            ?? "You"
    }

    private var myAvatarUrl: String? {
        SupabaseManager.shared.currentUser?.avatarUrl
    }

    var body: some View {
        HStack(spacing: 12) {
            YGAvatar(name: myName, size: 36, imageURL: myAvatarUrl)
            Text(myName)
                .font(.lilitaOne(size: 16))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 8)

            if let total = totalQuestions, total > 0 {
                ProgressSquares(
                    total: total,
                    results: questionResults,
                    currentIndex: currentQuestionIndex
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [.clear, YGColors.ink.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

/// Row of small per-question status squares. Green ✓ for correct,
/// red ✗ for wrong, neutral grey for unanswered / not-yet-revealed.
/// Square size scales modestly for longer games so the row keeps
/// fitting in the footer.
struct ProgressSquares: View {
    let total: Int
    let results: [Int: Bool]
    let currentIndex: Int?

    private var squareSize: CGFloat {
        // Tighten the squares for longer games so we fit without
        // crowding the username on the left.
        switch total {
        case ..<6:  return 22
        case ..<9:  return 20
        case ..<12: return 18
        default:    return 16
        }
    }

    private var spacing: CGFloat {
        total <= 8 ? 5 : 4
    }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<total, id: \.self) { idx in
                square(for: idx)
            }
        }
    }

    @ViewBuilder
    private func square(for idx: Int) -> some View {
        let state = results[idx]
        ZStack {
            RoundedRectangle(cornerRadius: squareSize * 0.22)
                .fill(fillColor(state))
                .frame(width: squareSize, height: squareSize)
            if state == true {
                Image(systemName: "checkmark")
                    .font(.system(size: squareSize * 0.55, weight: .heavy))
                    .foregroundStyle(.white)
            } else if state == false {
                Image(systemName: "xmark")
                    .font(.system(size: squareSize * 0.55, weight: .heavy))
                    .foregroundStyle(.white)
            }
        }
    }

    private func fillColor(_ state: Bool?) -> Color {
        switch state {
        case .some(true):  return Color(hex: "34D399")
        case .some(false): return Color(hex: "FB7185")
        case .none:        return Color.white.opacity(0.18)
        }
    }
}
