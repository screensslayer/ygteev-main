//
//  RevealStageView.swift
//  YGTeeV
//
//  Stage shown while `room.status == .reveal`. Big check / cross
//  badge, the crowd's actual pick, and the caller's running score.
//  This is the ONLY place the personal result is shown — the in-
//  game stage stays neutral until the server flips status.
//
//  Correctness is a literal string compare:
//      revealData.correctOption ("A" | "B") == mySubmittedGuess
//  No `myCorrect` flag, no inferred truth. If `correctOption` is
//  nil (decoder bug or status flipped early) we show neutral copy
//  rather than guessing.
//

import SwiftUI

struct RevealStageView: View {
    let room: GameRoom
    let myPlayer: GamePlayer?
    /// What the user submitted as their `guess` (the crowd-prediction
    /// step). Held in `ImmersiveGameFlow.@State` because by the time
    /// this view renders, the in-game stage's local state is gone.
    let mySubmittedGuess: String?

    /// Server-scored winner — "A" or "B" — taken straight from the
    /// reveal payload.
    private var serverCorrect: String? {
        room.revealData?.correctOption
    }

    /// Did the user predict the majority correctly? Nil when we
    /// don't yet have the comparison inputs (e.g. mid-decode or a
    /// late join after the user never submitted).
    private var didIWinIt: Bool? {
        guard let serverCorrect, let myGuess = mySubmittedGuess else {
            return nil
        }
        return myGuess.uppercased() == serverCorrect.uppercased()
    }

    /// Text label of the option the room actually picked, pulled
    /// from the reveal payload's `optionA.text` / `optionB.text`.
    private var crowdChoiceLabel: String {
        guard let id = serverCorrect, let r = room.revealData else {
            return "the crowd's pick"
        }
        switch id.uppercased() {
        case "A": return r.optionA?.text ?? "Option A"
        case "B": return r.optionB?.text ?? "Option B"
        default:  return "the crowd's pick"
        }
    }

    private var headline: String {
        switch didIWinIt {
        case .some(true):  return "Nailed it!"
        case .some(false): return "Not quite"
        case .none:        return "Crowd's pick"
        }
    }

    private var headlineColor: [Color] {
        switch didIWinIt {
        case .some(true):  return [Color(hex: "34D399"), Color(hex: "10B981")]
        case .some(false): return [Color(hex: "FB7185"), Color(hex: "FF6B35")]
        case .none:        return [YGColors.violet, YGColors.pink]
        }
    }

    private var headlineGlyph: String {
        switch didIWinIt {
        case .some(true):  return "✅"
        case .some(false): return "❌"
        case .none:        return "👀"
        }
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: headlineColor,
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing))
                    .frame(width: 144, height: 144)
                    .shadow(color: headlineColor.first?.opacity(0.55) ?? .clear,
                            radius: 26, y: 14)
                Text(headlineGlyph).font(.system(size: 72))
            }

            VStack(spacing: 6) {
                Text(headline)
                    .font(.lilitaOne(size: 38))
                    .tracking(-1.2)
                    .foregroundStyle(.white)
                Text("The crowd picked \(crowdChoiceLabel).")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }

            scorePanel
            Spacer()
        }
    }

    private var scorePanel: some View {
        VStack(spacing: 4) {
            Text("YOUR SCORE")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.5))
            Text((myPlayer?.score ?? 0).formatted())
                .font(.lilitaOne(size: 38))
                .tracking(-1)
                .foregroundStyle(YGColors.yellow)
                .monospacedDigit()
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
