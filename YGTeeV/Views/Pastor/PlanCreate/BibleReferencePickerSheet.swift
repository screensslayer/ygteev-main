//
//  BibleReferencePickerSheet.swift
//  YGTeeV
//
//  Three-step picker for setting a `reading` block's verse reference:
//  Book → Chapter → Verse range. Result is a formatted string like
//  "Romans 1:1-7" (or "John 3:16" / "Romans 1") that gets written back
//  to the block.
//

import SwiftUI

struct BibleReferencePickerSheet: View {
    let initialReference: String
    let onSave: (_ reference: String) -> Void

    @Environment(\.dismiss) private var dismiss

    private enum Step {
        case book
        case chapter(book: BibleBook)
        case verses(book: BibleBook, chapter: Int)

        var isBook: Bool { if case .book = self { return true } else { return false } }
    }
    @State private var step: Step = .book

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .book:
                    BookList { book in
                        step = .chapter(book: book)
                    }
                case .chapter(let book):
                    ChapterGrid(book: book) { chapter in
                        step = .verses(book: book, chapter: chapter)
                    }
                case .verses(let book, let chapter):
                    VerseRangeEditor(book: book, chapter: chapter) { reference in
                        onSave(reference)
                        dismiss()
                    }
                }
            }
            .background(YGColors.paper)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        switch step {
                        case .book:
                            dismiss()
                        case .chapter:
                            step = .book
                        case .verses(let book, _):
                            step = .chapter(book: book)
                        }
                    } label: {
                        Image(systemName: step.isBook ? "xmark" : "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(navTitle)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(YGColors.ink)
                }
            }
        }
    }

    private var navTitle: String {
        switch step {
        case .book: return "Pick a book"
        case .chapter(let book): return "\(book.name) — pick a chapter"
        case .verses(let book, let chapter): return "\(book.name) \(chapter)"
        }
    }
}

// MARK: - Step 1: Book picker

private struct BookList: View {
    let onPick: (BibleBook) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                section(title: "Old Testament", books: BibleBook.oldTestament)
                section(title: "New Testament", books: BibleBook.newTestament)
            }
            .padding(.bottom, 24)
        }
    }

    private func section(title: String, books: [BibleBook]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(YGColors.ink.opacity(0.5))
                .padding(.horizontal, 20)
                .padding(.top, 14)

            VStack(spacing: 0) {
                ForEach(books) { book in
                    Button { onPick(book) } label: {
                        HStack {
                            Text(book.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(YGColors.ink)
                            Spacer()
                            Text("\(BibleReferenceCounts.chapters(for: book.id))")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(YGColors.ink.opacity(0.4))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(YGColors.ink.opacity(0.3))
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(.white)
                        .overlay(alignment: .bottom) {
                            Divider().padding(.leading, 18).opacity(0.5)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 14)
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.black.opacity(0.06), lineWidth: 0.5)
                    .padding(.horizontal, 14)
            }
        }
    }
}

// MARK: - Step 2: Chapter grid

private struct ChapterGrid: View {
    let book: BibleBook
    let onPick: (Int) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(1...BibleReferenceCounts.chapters(for: book.id), id: \.self) { ch in
                    Button { onPick(ch) } label: {
                        Text("\(ch)")
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundStyle(YGColors.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(.black.opacity(0.06), lineWidth: 0.5) }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Step 3: Verse range

private struct VerseRangeEditor: View {
    let book: BibleBook
    let chapter: Int
    let onSave: (_ reference: String) -> Void

    @State private var startVerse: Int = 1
    @State private var endVerse: Int = 1
    @State private var wholeChapter: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 14) {
                    // Headline preview
                    VStack(spacing: 4) {
                        Text("PREVIEW")
                            .font(.system(size: 10.5, weight: .heavy))
                            .tracking(0.5)
                            .foregroundStyle(YGColors.ink.opacity(0.5))
                        Text(currentReference)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(YGColors.ink)
                            .padding(.top, 2)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 22)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(colors: [YGColors.violet.opacity(0.08), Color(hex: "FF3DA5").opacity(0.08)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                    // Whole-chapter toggle
                    Toggle(isOn: $wholeChapter) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Whole chapter")
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundStyle(YGColors.ink)
                            Text("All verses in \(book.name) \(chapter)")
                                .font(.system(size: 12))
                                .foregroundStyle(YGColors.ink.opacity(0.55))
                        }
                    }
                    .tint(YGColors.violet)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.06), lineWidth: 0.5) }

                    if !wholeChapter {
                        verseRangeControls
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 120)
            }

            // Save footer
            Button {
                onSave(currentReference)
            } label: {
                Text("Use this reference")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        LinearGradient(colors: [YGColors.violet, Color(hex: "FF3DA5")],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: YGColors.violet.opacity(0.5), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 26)
            .background(YGColors.paper)
        }
        .onAppear {
            // Default to the whole chapter on first arrival; clamp ranges sensibly.
            startVerse = 1
            endVerse = 1
        }
        .onChange(of: wholeChapter) { _, on in
            if !on {
                startVerse = 1
                endVerse = max(startVerse, endVerse)
            }
        }
    }

    private var currentReference: String {
        if wholeChapter {
            return "\(book.name) \(chapter)"
        }
        let s = max(1, min(199, startVerse))
        let e = max(s, min(199, endVerse))
        if s == e { return "\(book.name) \(chapter):\(s)" }
        return "\(book.name) \(chapter):\(s)-\(e)"
    }

    private var verseRangeControls: some View {
        VStack(spacing: 10) {
            verseStepper(label: "Start verse", value: $startVerse, minVal: 1)
                .onChange(of: startVerse) { _, newStart in
                    if endVerse < newStart { endVerse = newStart }
                }
            verseStepper(label: "End verse", value: $endVerse, minVal: startVerse)
        }
    }

    private func verseStepper(label: String, value: Binding<Int>, minVal: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(YGColors.ink.opacity(0.6))
                Text("\(value.wrappedValue)")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(YGColors.ink)
            }
            Spacer()
            HStack(spacing: 8) {
                circleButton("−") {
                    let next = max(minVal, value.wrappedValue - 1)
                    value.wrappedValue = next
                }
                circleButton("+") {
                    value.wrappedValue = min(199, value.wrappedValue + 1)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.06), lineWidth: 0.5) }
    }

    private func circleButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(YGColors.ink)
                .frame(width: 38, height: 38)
                .background(.white)
                .clipShape(Circle())
                .overlay { Circle().strokeBorder(.black.opacity(0.12), lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chapter counts (66-book canon)

enum BibleReferenceCounts {
    /// Returns the number of chapters in a book by its 3-letter id. Falls
    /// back to 1 for unknown ids.
    static func chapters(for bookId: String) -> Int {
        chapterCounts[bookId] ?? 1
    }

    private static let chapterCounts: [String: Int] = [
        // Old Testament
        "GEN": 50, "EXO": 40, "LEV": 27, "NUM": 36, "DEU": 34,
        "JOS": 24, "JDG": 21, "RUT":  4, "1SA": 31, "2SA": 24,
        "1KI": 22, "2KI": 25, "1CH": 29, "2CH": 36, "EZR": 10,
        "NEH": 13, "EST": 10, "JOB": 42, "PSA": 150, "PRO": 31,
        "ECC": 12, "SNG":  8, "ISA": 66, "JER": 52, "LAM":  5,
        "EZK": 48, "DAN": 12, "HOS": 14, "JOL":  3, "AMO":  9,
        "OBA":  1, "JON":  4, "MIC":  7, "NAM":  3, "HAB":  3,
        "ZEP":  3, "HAG":  2, "ZEC": 14, "MAL":  4,
        // New Testament
        "MAT": 28, "MRK": 16, "LUK": 24, "JHN": 21, "ACT": 28,
        "ROM": 16, "1CO": 16, "2CO": 13, "GAL":  6, "EPH":  6,
        "PHP":  4, "COL":  4, "1TH":  5, "2TH":  3, "1TI":  6,
        "2TI":  4, "TIT":  3, "PHM":  1, "HEB": 13, "JAS":  5,
        "1PE":  5, "2PE":  3, "1JN":  5, "2JN":  1, "3JN":  1,
        "JUD":  1, "REV": 22
    ]
}
