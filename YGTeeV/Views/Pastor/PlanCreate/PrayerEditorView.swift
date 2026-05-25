//
//  PrayerEditorView.swift
//  YGTeeV
//
//  Editor sheet for a prayer block: title + body + optional duration.
//

import SwiftUI

struct PrayerEditorView: View {
    let blockId: UUID
    let initialTitle: String
    let initialBody: String
    let initialDurationMinutes: Int?
    let onSave: (_ title: String, _ body: String, _ durationMinutes: Int?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var noteBody: String = ""
    @State private var durationMinutes: Int = 2
    @State private var includeDuration: Bool = true

    @FocusState private var bodyFocused: Bool

    private let bodyLimit = 1200

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    typeChip
                    titleCard
                    bodyCard
                    durationCard
                }
                .padding(16)
                .padding(.bottom, 120)
            }
            .background(YGColors.paper)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit prayer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            title.trimmingCharacters(in: .whitespaces),
                            noteBody.trimmingCharacters(in: .whitespaces),
                            includeDuration ? durationMinutes : nil
                        )
                        dismiss()
                    }
                    .bold()
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if title.isEmpty { title = initialTitle }
                if noteBody.isEmpty { noteBody = initialBody }
                if let d = initialDurationMinutes {
                    durationMinutes = d
                    includeDuration = true
                }
            }
        }
    }

    private var typeChip: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Text("🙏").font(.system(size: 11))
                Text("PRAYER")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.4)
            }
            .foregroundStyle(BlockKind.prayer.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(BlockKind.prayer.tint)
            .clipShape(Capsule())
        }
    }

    private var titleCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TITLE")
                .font(.system(size: 10.5, weight: .heavy))
                .tracking(0.4)
                .foregroundStyle(YGColors.ink.opacity(0.55))
            TextField("Pray for your week", text: $title)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(YGColors.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.06), lineWidth: 0.5) }
    }

    private var bodyCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("PRAYER PROMPT")
                    .font(.system(size: 10.5, weight: .heavy))
                    .tracking(0.4)
                    .foregroundStyle(YGColors.ink.opacity(0.55))
                Spacer()
                Text("\(noteBody.count) / \(bodyLimit)")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(YGColors.ink.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)

            ZStack(alignment: .topLeading) {
                if noteBody.isEmpty {
                    Text("What should teens pray about? Give them a starting point.")
                        .font(.system(size: 14))
                        .foregroundStyle(YGColors.ink.opacity(0.45))
                        .padding(.horizontal, 14)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $noteBody)
                    .focused($bodyFocused)
                    .scrollContentBackground(.hidden)
                    .font(.system(size: 14))
                    .foregroundStyle(YGColors.ink)
                    .frame(minHeight: 140)
                    .padding(.horizontal, 10)
                    .onChange(of: noteBody) { _, newValue in
                        if newValue.count > bodyLimit {
                            noteBody = String(newValue.prefix(bodyLimit))
                        }
                    }
            }
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.06), lineWidth: 0.5) }
    }

    private var durationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $includeDuration) {
                Text("SUGGESTED DURATION")
                    .font(.system(size: 10.5, weight: .heavy))
                    .tracking(0.4)
                    .foregroundStyle(YGColors.ink.opacity(0.55))
            }
            if includeDuration {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(durationMinutes)")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(YGColors.ink)
                        .monospacedDigit()
                    Text(durationMinutes == 1 ? "minute" : "minutes")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(YGColors.ink.opacity(0.5))
                    Spacer()
                    HStack(spacing: 8) {
                        stepperButton("−") { durationMinutes = max(1, durationMinutes - 1) }
                        stepperButton("+") { durationMinutes = min(30, durationMinutes + 1) }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.06), lineWidth: 0.5) }
    }

    private func stepperButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(YGColors.ink)
                .frame(width: 36, height: 36)
                .background(YGColors.ink.opacity(0.06))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
