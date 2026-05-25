//
//  QuestionEditorView.swift
//  YGTeeV
//
//  Screen 6: prompt + multiple-choice editor.
//

import SwiftUI

struct QuestionEditorView: View {
    let blockId: UUID
    let initialPrompt: String
    let initialOptions: [String]
    let initialCorrect: Int
    let onSave: (_ prompt: String, _ options: [String], _ correct: Int) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var prompt: String = ""
    @State private var options: [String] = ["", "", ""]
    @State private var correct: Int = 0

    @FocusState private var promptFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    typeRow
                    promptCard
                    HStack {
                        Text("ANSWER CHOICES")
                            .font(.system(size: 10.5, weight: .heavy))
                            .tracking(0.4)
                            .foregroundStyle(YGColors.ink.opacity(0.55))
                        Spacer()
                        Text("Tap ✓ to mark correct")
                            .font(.system(size: 11.5))
                            .foregroundStyle(YGColors.ink.opacity(0.5))
                    }
                    .padding(.horizontal, 4)

                    VStack(spacing: 8) {
                        ForEach(options.indices, id: \.self) { idx in
                            optionRow(idx: idx)
                        }
                        if options.count < 4 {
                            Button { options.append("") } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 12, weight: .heavy))
                                    Text("Add option \(letter(options.count))")
                                        .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                                }
                                .foregroundStyle(YGColors.ink.opacity(0.55))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(.white.opacity(0.7))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(YGColors.ink.opacity(0.18),
                                                      style: .init(lineWidth: 1.5, dash: [6, 6]))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    scoringNote
                }
                .padding(16)
                .padding(.bottom, 120)
            }
            .background(YGColors.paper)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit question")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let cleaned = options.map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                        let safeCorrect = min(max(0, correct), max(0, cleaned.count - 1))
                        onSave(prompt.trimmingCharacters(in: .whitespaces), cleaned, safeCorrect)
                        dismiss()
                    }
                    .bold()
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if prompt.isEmpty { prompt = initialPrompt }
                if initialOptions.isEmpty {
                    options = ["", "", ""]
                } else {
                    options = initialOptions
                }
                correct = min(max(0, initialCorrect), max(0, options.count - 1))
            }
        }
    }

    private var isValid: Bool {
        let cleaned = options.map { $0.trimmingCharacters(in: .whitespaces) }
        let nonEmpty = cleaned.filter { !$0.isEmpty }
        return !prompt.trimmingCharacters(in: .whitespaces).isEmpty
            && nonEmpty.count >= 2
            && correct < cleaned.count
            && !cleaned[correct].isEmpty
    }

    // MARK: Sections

    private var typeRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Text("❓").font(.system(size: 11))
                Text("QUESTION")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.4)
            }
            .foregroundStyle(BlockKind.question.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(BlockKind.question.tint)
            .clipShape(Capsule())

            HStack(spacing: 3) { Text("⚡"); Text("+50 XP") }
                .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                .foregroundStyle(YGColors.ink)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color(hex: "FFD60A"))
                .clipShape(Capsule())

            Spacer()
        }
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PROMPT")
                .font(.system(size: 10.5, weight: .heavy))
                .tracking(0.4)
                .foregroundStyle(YGColors.ink.opacity(0.55))
            ZStack(alignment: .topLeading) {
                if prompt.isEmpty {
                    Text("What is the main theme of Romans?")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(YGColors.ink.opacity(0.45))
                        .allowsHitTesting(false)
                }
                TextField("", text: $prompt, axis: .vertical)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(YGColors.ink)
                    .lineLimit(2...4)
                    .focused($promptFocused)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.06), lineWidth: 0.5) }
    }

    private func optionRow(idx: Int) -> some View {
        let isCorrect = idx == correct
        return HStack(spacing: 12) {
            Text(letter(idx))
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(YGColors.ink)
                .frame(width: 28, height: 28)
                .background(.white)
                .clipShape(Circle())
                .overlay { Circle().strokeBorder(.black.opacity(0.15), lineWidth: 1.2) }

            ZStack(alignment: .topLeading) {
                if options[idx].isEmpty {
                    Text("Option \(letter(idx))")
                        .font(.system(size: 14.5, weight: isCorrect ? .bold : .regular))
                        .foregroundStyle(YGColors.ink.opacity(0.45))
                        .allowsHitTesting(false)
                }
                TextField("", text: $options[idx], axis: .vertical)
                    .font(.system(size: 14.5, weight: isCorrect ? .bold : .regular))
                    .foregroundStyle(YGColors.ink)
                    .lineLimit(1...3)
            }

            Button {
                correct = idx
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(isCorrect ? Color(hex: "B4FF3C") : YGColors.ink.opacity(0.4))
                    .frame(width: 32, height: 32)
                    .background(isCorrect ? YGColors.ink : YGColors.ink.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            if options.count > 2 {
                Button {
                    if idx == correct { correct = 0 }
                    else if idx < correct { correct -= 1 }
                    options.remove(at: idx)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.red.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(isCorrect ? Color(hex: "B4FF3C") : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isCorrect ? Color(hex: "8FD92A") : Color.black.opacity(0.06),
                              lineWidth: isCorrect ? 1.5 : 0.5)
        }
        .shadow(color: isCorrect ? Color(hex: "8FD92A").opacity(0.35) : .clear, radius: 8, y: 6)
    }

    private var scoringNote: some View {
        HStack(spacing: 10) {
            Text("⚡")
                .font(.system(size: 16))
                .frame(width: 32, height: 32)
                .background(Color(hex: "FFD60A"))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text("**+50 XP** awarded on correct answer · standard scoring.")
                .font(.system(size: 12.5))
                .foregroundStyle(YGColors.ink.opacity(0.75))
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(hex: "FFD60A").opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Color(hex: "FFD60A").opacity(0.4), lineWidth: 0.5) }
    }

    private func letter(_ i: Int) -> String {
        guard let scalar = UnicodeScalar(65 + i) else { return "?" }
        return String(Character(scalar))
    }
}
