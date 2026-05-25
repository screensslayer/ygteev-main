//
//  CommentaryEditorView.swift
//  YGTeeV
//
//  Screen 5: title + body editor with AI assist panel.
//

import SwiftUI

struct CommentaryEditorView: View {
    let blockId: UUID
    let initialTitle: String
    let initialBody: String
    let scriptureRef: String
    let planTitle: String
    let onSave: (_ title: String, _ body: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var service = PastorPlanService.shared

    @State private var title: String = ""
    @State private var noteBody: String = ""
    @State private var suggestions: [PastorPlanService.Suggestion] = []
    @State private var isAILoading = false
    @State private var errorMessage: String?

    @FocusState private var bodyFocused: Bool

    private let bodyLimit = 2000

    private var charCount: String { "\(noteBody.count) / \(bodyLimit)" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    typeChip
                    titleCard
                    bodyCard
                    if !suggestions.isEmpty || isAILoading {
                        suggestionsCard
                    }
                    if let errorMessage {
                        Text(errorMessage).font(.system(size: 12, weight: .semibold)).foregroundStyle(.red)
                    }
                }
                .padding(16)
                .padding(.bottom, 120)
            }
            .background(YGColors.paper)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit commentary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(title.trimmingCharacters(in: .whitespaces),
                               noteBody.trimmingCharacters(in: .whitespaces))
                        dismiss()
                    }
                    .bold()
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if title.isEmpty { title = initialTitle }
                if noteBody.isEmpty { noteBody = initialBody }
            }
        }
    }

    // MARK: Sections

    private var typeChip: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Text("✍️").font(.system(size: 11))
                Text("COMMENTARY")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.4)
            }
            .foregroundStyle(BlockKind.commentary.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(BlockKind.commentary.tint)
            .clipShape(Capsule())
            Text("Block · \(scriptureRef.isEmpty ? "Plan day" : scriptureRef)")
                .font(.system(size: 11.5))
                .foregroundStyle(YGColors.ink.opacity(0.5))
        }
    }

    private var titleCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TITLE")
                .font(.system(size: 10.5, weight: .heavy))
                .tracking(0.4)
                .foregroundStyle(YGColors.ink.opacity(0.55))
            TextField("Why Paul writes to Rome", text: $title)
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
                Text("STUDY NOTES")
                    .font(.system(size: 10.5, weight: .heavy))
                    .tracking(0.4)
                    .foregroundStyle(YGColors.ink.opacity(0.55))
                Spacer()
                Text(charCount)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(YGColors.ink.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)

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

            // AI assist row
            HStack(spacing: 8) {
                Button { Task { await fetchSuggestions() } } label: {
                    HStack(spacing: 6) {
                        if isAILoading { ProgressView().tint(.white).scaleEffect(0.7) }
                        else { Text("✨") }
                        Text("YGTeeV AI assist")
                            .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(colors: [YGColors.violet, Color(hex: "FF3DA5")],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isAILoading || scriptureRef.isEmpty)

                Text(scriptureRef.isEmpty ? "Add a reference first" : "Draft from \(scriptureRef)")
                    .font(.system(size: 11.5))
                    .foregroundStyle(YGColors.ink.opacity(0.55))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                LinearGradient(colors: [YGColors.violet.opacity(0.04), Color(hex: "FF3DA5").opacity(0.04)],
                               startPoint: .leading, endPoint: .trailing)
            )
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.06), lineWidth: 0.5) }
    }

    private var suggestionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text("✨")
                Text("AI suggestions")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(YGColors.violet)
                Spacer()
                Text("tap Use this to replace your notes")
                    .font(.system(size: 11))
                    .foregroundStyle(YGColors.ink.opacity(0.5))
            }

            if isAILoading {
                ProgressView().padding(.vertical, 8)
            }

            ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, s in
                suggestionCard(index: index, suggestion: s)
            }
        }
        .padding(14)
        .background(
            LinearGradient(colors: [YGColors.violet.opacity(0.06), Color(hex: "FF3DA5").opacity(0.06)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(YGColors.violet.opacity(0.15), lineWidth: 0.5) }
    }

    private func suggestionCard(index: Int, suggestion: PastorPlanService.Suggestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Option \(index + 1)")
                .font(.system(size: 10.5, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(YGColors.ink.opacity(0.55))

            Text(suggestion.body)
                .font(.system(size: 14))
                .foregroundStyle(YGColors.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Spacer()
                Button {
                    replace(with: suggestion)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 11, weight: .heavy))
                        Text("Use this")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(YGColors.ink)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(YGColors.ink.opacity(0.06), lineWidth: 0.5) }
    }

    private func replace(with suggestion: PastorPlanService.Suggestion) {
        noteBody = String(suggestion.body.prefix(bodyLimit))
    }

    private func fetchSuggestions() async {
        guard !scriptureRef.isEmpty else { return }
        isAILoading = true
        defer { isAILoading = false }
        errorMessage = nil
        do {
            let results = try await service.aiAssist(
                reference: scriptureRef,
                planTitle: planTitle,
                currentDraft: noteBody.isEmpty ? nil : noteBody
            )
            suggestions = results
        } catch {
            errorMessage = "AI assist failed: \(error.localizedDescription)"
        }
    }
}
