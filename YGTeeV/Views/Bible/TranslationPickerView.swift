//
//  TranslationPickerView.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/7/26.
//

import SwiftUI

struct TranslationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTranslation: BibleTranslation

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.black.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 14)

            // Title
            Text("Translation")
                .font(.lilitaOne(size: 24))
                .tracking(-0.5)
                .foregroundStyle(YGColors.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

            // Translation list
            VStack(spacing: 0) {
                ForEach(Array(BibleTranslation.translations.enumerated()), id: \.element.id) { index, translation in
                    Button {
                        selectedTranslation = translation
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Text(translation.abbreviation)
                                .font(.lilitaOne(size: 15))
                                .foregroundStyle(selectedTranslation.id == translation.id ? YGColors.violet : YGColors.ink)
                                .frame(width: 50, alignment: .leading)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(translation.name)
                                    .font(.lilitaOne(size: 14.5))
                                    .foregroundStyle(YGColors.ink)

                                Text(translation.description)
                                    .font(.system(size: 12))
                                    .foregroundStyle(YGColors.ink.opacity(0.55))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if selectedTranslation.id == translation.id {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(YGColors.violet)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .background(.white)
                        .overlay(alignment: .top) {
                            if index > 0 {
                                Divider()
                                    .padding(.leading, 78)
                            }
                        }
                    }
                }
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.black.opacity(0.05), lineWidth: 0.5)
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color.white.opacity(0.96)
                .background(.ultraThinMaterial)
        )
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }
}

#Preview {
    TranslationPickerView(selectedTranslation: .constant(BibleTranslation.translations[0]))
}
