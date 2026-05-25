//
//  BibleReaderView.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/7/26.
//

import SwiftUI

struct BibleReaderView: View {
    let book: BibleBook
    let chapter: Int
    let translation: BibleTranslation
    let onBack: () -> Void
    let onTranslationTap: () -> Void
    let onChapterChange: (Int) -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var showChapterPicker = false
    @State private var fontSize: FontSize = .medium
    @State private var chapterContent: BibleChapter?
    @State private var verses: [BibleVerse] = []
    @State private var isLoading = true
    @State private var appearanceManager = AppearanceManager.shared

    enum FontSize {
        case small, medium, large

        var verseSize: CGFloat {
            switch self {
            case .small: return 17
            case .medium: return 19
            case .large: return 21
            }
        }

        var numberSize: CGFloat {
            switch self {
            case .small: return 11
            case .medium: return 13
            case .large: return 15
            }
        }

        mutating func cycle() {
            switch self {
            case .small: self = .medium
            case .medium: self = .large
            case .large: self = .small
            }
        }
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 0) {
                        HStack(spacing: 8) {
                            // Back button
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(ThemeColors.primaryText(isDark: appearanceManager.isDarkMode))
                                    .frame(width: 38, height: 38)
                                    .background(ThemeColors.cardBackground(isDark: appearanceManager.isDarkMode))
                                    .clipShape(Circle())
                                    .overlay {
                                        Circle()
                                            .strokeBorder(ThemeColors.border(isDark: appearanceManager.isDarkMode), lineWidth: 0.5)
                                    }
                            }

                            // Chapter selector
                            Button {
                                showChapterPicker = true
                            } label: {
                                HStack(spacing: 6) {
                                    Text("\(book.name) \(chapter)")
                                        .font(.lilitaOne(size: 14))
                                        .foregroundStyle(ThemeColors.primaryText(isDark: appearanceManager.isDarkMode))

                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 11, weight: .heavy))
                                        .foregroundStyle(ThemeColors.secondaryText(isDark: appearanceManager.isDarkMode))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                                .background(ThemeColors.cardBackground(isDark: appearanceManager.isDarkMode))
                                .clipShape(RoundedRectangle(cornerRadius: 19))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 19)
                                        .strokeBorder(ThemeColors.border(isDark: appearanceManager.isDarkMode), lineWidth: 0.5)
                                }
                            }

                            // Translation picker
                            Button(action: onTranslationTap) {
                                HStack(spacing: 6) {
                                    Text(translation.abbreviation)
                                        .font(.lilitaOne(size: 13))

                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 11, weight: .heavy))
                                }
                                .foregroundStyle(ThemeColors.primaryText(isDark: appearanceManager.isDarkMode))
                                .padding(.horizontal, 13)
                                .frame(height: 38)
                                .background(ThemeColors.cardBackground(isDark: appearanceManager.isDarkMode))
                                .clipShape(RoundedRectangle(cornerRadius: 19))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 19)
                                        .strokeBorder(ThemeColors.border(isDark: appearanceManager.isDarkMode), lineWidth: 0.5)
                                }
                            }

                            // Text size button
                            Button {
                                fontSize.cycle()
                            } label: {
                                Text("Aa")
                                    .font(.lilitaOne(size: 14))
                                    .foregroundStyle(ThemeColors.primaryText(isDark: appearanceManager.isDarkMode))
                                    .frame(width: 38, height: 38)
                                    .background(ThemeColors.cardBackground(isDark: appearanceManager.isDarkMode))
                                    .clipShape(Circle())
                                    .overlay {
                                        Circle()
                                            .strokeBorder(ThemeColors.border(isDark: appearanceManager.isDarkMode), lineWidth: 0.5)
                                    }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 60)
                        .padding(.bottom, 12)
                        .background(
                            ThemeColors.background(isDark: appearanceManager.isDarkMode).opacity(0.85)
                                .background(.ultraThinMaterial)
                        )
                    }

                    // Chapter content
                    VStack(spacing: 0) {
                        // Subtitle
                        if book.name == "Psalms" {
                            Text("A PSALM OF DAVID")
                                .font(.system(size: 12, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(ThemeColors.tertiaryText(isDark: appearanceManager.isDarkMode))
                                .padding(.top, 20)
                                .padding(.bottom, 8)
                        }

                        // Chapter number
                        Text("\(chapter)")
                            .font(.system(size: 56, weight: .bold, design: .serif))
                            .italic()
                            .tracking(-1.5)
                            .foregroundStyle(ThemeColors.primaryText(isDark: appearanceManager.isDarkMode))
                            .padding(.bottom, 26)

                        // Verses
                        if isLoading {
                            ProgressView()
                                .padding(.top, 40)
                        } else {
                            VStack(alignment: .leading, spacing: 16) {
                                ForEach(verses) { verse in
                                    VerseView(number: verse.number, text: verse.text, isHighlighted: false, fontSize: fontSize, isDarkMode: appearanceManager.isDarkMode)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 148)
                        }
                    }
                }
            }
            .background(ThemeColors.background(isDark: appearanceManager.isDarkMode))
            .ignoresSafeArea(edges: .top)

            // Fixed navigation buttons at bottom
            VStack {
                Spacer()

                HStack(spacing: 12) {
                    if chapter > 1 {
                        Button {
                            onChapterChange(chapter - 1)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .bold))
                                Text("\(book.abbreviation) \(chapter - 1)")
                                    .font(.lilitaOne(size: 16))
                            }
                            .foregroundStyle(appearanceManager.isDarkMode ? .white : YGColors.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(ThemeColors.cardBackground(isDark: appearanceManager.isDarkMode))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(ThemeColors.border(isDark: appearanceManager.isDarkMode), lineWidth: 0.5)
                            }
                            .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
                        }
                    }

                    Button {
                        onChapterChange(chapter + 1)
                    } label: {
                        HStack(spacing: 10) {
                            Text("\(book.abbreviation) \(chapter + 1)")
                                .font(.lilitaOne(size: 16))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(appearanceManager.isDarkMode ? YGColors.violet : YGColors.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
        }
        .sheet(isPresented: $showChapterPicker) {
            ChapterPickerView(book: book, selectedChapter: chapter, onSelectChapter: { newChapter in
                showChapterPicker = false
                onChapterChange(newChapter)
            })
        }
        .task(id: "\(book.id)-\(chapter)-\(translation.id)") {
            await loadChapter()
        }
        .offset(x: dragOffset)
        .gesture(
            DragGesture(minimumDistance: 30)
                .onChanged { value in
                    // Only respond to mostly horizontal swipes (right swipe to go back)
                    if value.translation.width > 0 && abs(value.translation.width) > abs(value.translation.height) * 2 {
                        dragOffset = value.translation.width
                    }
                }
                .onEnded { value in
                    if value.translation.width > 100 || value.predictedEndTranslation.width > 200 {
                        onBack()
                        dragOffset = 0
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
    }

    func loadChapter() async {
        isLoading = true
        do {
            // Construct chapter ID from book ID and chapter number
            let chapterId = "\(book.id).\(chapter)"

            print("🔍 Loading chapter: \(chapterId) for translation: \(translation.id)")

            // Fetch chapter content (which includes all verses)
            let chapter = try await BibleAPIService.shared.fetchChapter(bibleId: translation.id, chapterId: chapterId)

            print("✅ Fetched chapter content")
            print("📖 Content preview: \(chapter.content.prefix(200))")

            // Parse the content into verses
            verses = parseChapterContent(chapter.content)

            print("✅ Parsed \(verses.count) verses")
        } catch {
            print("❌ Error loading chapter: \(error)")
            if let urlError = error as? URLError {
                print("URL Error code: \(urlError.code)")
            }
            // Set empty verses on error
            verses = []
        }
        isLoading = false
    }

    func parseChapterContent(_ content: String) -> [BibleVerse] {
        // Split content by verse numbers [1], [2], etc.
        var verses: [BibleVerse] = []
        let pattern = "\\[(\\d+)\\]\\s*([^\\[]+)"

        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let nsString = content as NSString
            let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsString.length))

            for match in matches {
                if match.numberOfRanges == 3 {
                    let verseNumRange = match.range(at: 1)
                    let verseTextRange = match.range(at: 2)

                    if let verseNum = Int(nsString.substring(with: verseNumRange)) {
                        let verseText = nsString.substring(with: verseTextRange).trimmingCharacters(in: .whitespacesAndNewlines)

                        verses.append(BibleVerse(
                            id: "\(book.id).\(chapter).\(verseNum)",
                            number: verseNum,
                            text: verseText
                        ))
                    }
                }
            }
        }

        return verses
    }
}

// MARK: - Verse View
struct VerseView: View {
    let number: Int
    let text: String
    let isHighlighted: Bool
    let fontSize: BibleReaderView.FontSize
    let isDarkMode: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(number)")
                .font(.system(size: fontSize.numberSize, weight: .bold))
                .foregroundStyle(isHighlighted ? .white : ThemeColors.tertiaryText(isDark: isDarkMode))
                .frame(width: 24, alignment: .trailing)

            Text(text)
                .font(.system(size: fontSize.verseSize, design: .serif))
                .lineSpacing(6)
                .foregroundStyle(isHighlighted ? .white : ThemeColors.primaryText(isDark: isDarkMode))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, isHighlighted ? 16 : 0)
        .padding(.vertical, isHighlighted ? 12 : 0)
        .background(
            isHighlighted ?
            LinearGradient(
                colors: [YGColors.violet.opacity(0.15), YGColors.pink.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ) : nil
        )
        .clipShape(RoundedRectangle(cornerRadius: isHighlighted ? 12 : 0))
    }
}

#Preview {
    BibleReaderView(
        book: BibleBook(id: "PSA", name: "Psalms", abbreviation: "Ps", chapters: []),
        chapter: 23,
        translation: BibleTranslation.translations[0],
        onBack: {},
        onTranslationTap: {},
        onChapterChange: { _ in }
    )
}

#Preview("Dark Mode") {
    BibleReaderView(
        book: BibleBook(id: "PSA", name: "Psalms", abbreviation: "Ps", chapters: []),
        chapter: 23,
        translation: BibleTranslation.translations[0],
        onBack: {},
        onTranslationTap: {},
        onChapterChange: { _ in }
    )
    .onAppear {
        AppearanceManager.shared.isDarkMode = true
    }
}
