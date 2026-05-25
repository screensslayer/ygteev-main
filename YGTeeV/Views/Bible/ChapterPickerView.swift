//
//  ChapterPickerView.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/7/26.
//

import SwiftUI

struct ChapterPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let book: BibleBook
    let selectedChapter: Int
    let onSelectChapter: (Int) -> Void
    
    // Chapter counts for each book
    let chapterCounts: [String: Int] = [
        "Genesis": 50, "Exodus": 40, "Leviticus": 27, "Numbers": 36, "Deuteronomy": 34,
        "Joshua": 24, "Judges": 21, "Ruth": 4, "1 Samuel": 31, "2 Samuel": 24,
        "1 Kings": 22, "2 Kings": 25, "1 Chronicles": 29, "2 Chronicles": 36, "Ezra": 10,
        "Nehemiah": 13, "Esther": 10, "Job": 42, "Psalms": 150, "Proverbs": 31,
        "Ecclesiastes": 12, "Song of Solomon": 8, "Isaiah": 66, "Jeremiah": 52, "Lamentations": 5,
        "Ezekiel": 48, "Daniel": 12, "Hosea": 14, "Joel": 3, "Amos": 9,
        "Obadiah": 1, "Jonah": 4, "Micah": 7, "Nahum": 3, "Habakkuk": 3,
        "Zephaniah": 3, "Haggai": 2, "Zechariah": 14, "Malachi": 4,
        "Matthew": 28, "Mark": 16, "Luke": 24, "John": 21, "Acts": 28,
        "Romans": 16, "1 Corinthians": 16, "2 Corinthians": 13, "Galatians": 6, "Ephesians": 6,
        "Philippians": 4, "Colossians": 4, "1 Thessalonians": 5, "2 Thessalonians": 3, "1 Timothy": 6,
        "2 Timothy": 4, "Titus": 3, "Philemon": 1, "Hebrews": 13, "James": 5,
        "1 Peter": 5, "2 Peter": 3, "1 John": 5, "2 John": 1, "3 John": 1,
        "Jude": 1, "Revelation": 22
    ]
    
    var totalChapters: Int {
        chapterCounts[book.name] ?? 50
    }
    
    let columns = [
        GridItem(.adaptive(minimum: 50), spacing: 12)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.black.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 14)
            
            // Title
            Text(book.name)
                .font(.lilitaOne(size: 24))
                .tracking(-0.5)
                .foregroundStyle(YGColors.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            
            Text("\(totalChapters) chapters")
                .font(.system(size: 14))
                .foregroundStyle(YGColors.ink.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            
            // Chapter grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(1...totalChapters, id: \.self) { chapter in
                        Button {
                            onSelectChapter(chapter)
                            dismiss()
                        } label: {
                            Text("\(chapter)")
                                .font(.lilitaOne(size: 16))
                                .foregroundStyle(selectedChapter == chapter ? .white : YGColors.ink)
                                .frame(width: 50, height: 50)
                                .background(selectedChapter == chapter ? YGColors.violet : Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                                }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
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
    ChapterPickerView(
        book: BibleBook(id: "PSA", name: "Psalms", abbreviation: "Ps", chapters: []),
        selectedChapter: 23,
        onSelectChapter: { _ in }
    )
}
