//
//  InGameStageView.swift
//  YGTeeV
//
//  Stage shown while `room.status == .inGame`. Pure content — no
//  chrome, no padding, no frame fill. The shell wraps it with the
//  standard 20pt inset and the top chrome row.
//
//  Single-step UX: one tap on a card immediately submits that
//  choice as both `guess` and `ownChoice`. Tapping the OTHER card
//  re-submits the new pick — the server takes the latest answer
//  per player per question. There is NO debounce: a debounced
//  submit + an `.onDisappear` cancellation race would silently
//  drop the user's pick when the timer expired before the debounce
//  fired, which is what produced "Time's up — you didn't lock in"
//  on a question the user had visibly tapped.
//

import SwiftUI

struct InGameStageView: View {
    let room: GameRoom
    let myPlayer: GamePlayer?
    let questionStartedAt: Date
    /// Called with `(guess, ownChoice)`. In this single-step UX
    /// they're always the same value.
    let onSubmit: (_ guess: String, _ ownChoice: String) -> Void

    @State private var pick: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            QuestionTimerBar(
                questionStartedAt: room.questionStartedAt,
                timerSeconds: room.timerSeconds
            )
            .padding(.top, 12)

            Text("MAJORITY RULES")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(YGColors.violetSoft)

            Text("Which got MORE votes?")
                .font(.lilitaOne(size: 26))
                .tracking(-0.8)
                .foregroundStyle(.white)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            choicesRow
                .padding(.top, 4)

            // Only show the prompt before the user has picked — once
            // they've selected, the visual highlight is feedback enough
            // and we don't want a contradictory "locking in…" message.
            if pick == nil {
                Text("Tap the option you think the room picked most")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Building blocks

    @ViewBuilder
    private var choicesRow: some View {
        if let q = room.currentQuestionPublic,
           !q.optionA.text.isEmpty || !q.optionB.text.isEmpty {
            HStack(spacing: 12) {
                ChoiceCard(
                    letter: "A",
                    text: q.optionA.text,
                    accent: Color(hex: "38BDF8"),
                    isPicked: pick == "A",
                    isDisabled: false,
                    action: { tap("A") }
                )
                ChoiceCard(
                    letter: "B",
                    text: q.optionB.text,
                    accent: Color(hex: "FB7185"),
                    isPicked: pick == "B",
                    isDisabled: false,
                    action: { tap("B") }
                )
            }
        } else {
            // No silent fallback. If `current_question_public` is
            // null or empty, make it visible.
            VStack(spacing: 8) {
                ProgressView().tint(.white)
                Text("Loading question…")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .frame(maxWidth: .infinity, minHeight: 140)
            .background(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
        }
    }

    // MARK: - Interaction

    private func tap(_ id: String) {
        // Ignore taps on the already-picked card — saves a redundant
        // RPC roundtrip when the user double-taps to "confirm".
        guard pick != id else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            pick = id
        }
        // Fire the submit immediately. If the user changes their
        // mind and taps the other card, this fires again with the
        // new value — the server takes the latest submission.
        onSubmit(id, id)
    }
}
