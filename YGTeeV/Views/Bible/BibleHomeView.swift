//
//  BibleHomeView.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/6/26.
//

import SwiftUI

struct BibleHomeView: View {
    @State private var selectedTab: Testament = .newTestament
    @State private var selectedBook: BibleBook?
    @State private var selectedChapter: Int = 1
    @State private var showReader = false
    @State private var showTranslationPicker = false
    @State private var selectedTranslation = BibleTranslation.translations[0]

    // Persist last read location
    @AppStorage("lastReadBookId") private var lastReadBookId: String = "JHN"
    @AppStorage("lastReadChapter") private var lastReadChapter: Int = 1

    enum Testament {
        case oldTestament
        case newTestament
    }

    var books: [BibleBook] {
        selectedTab == .oldTestament ? BibleBook.oldTestament : BibleBook.newTestament
    }

    var lastReadBook: BibleBook? {
        BibleBook.allBooks.first(where: { $0.id == lastReadBookId })
    }

    var continueReadingText: String {
        if let book = lastReadBook {
            return "\(book.name) \(lastReadChapter)"
        }
        return "John 1"
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    HStack(alignment: .bottom) {
                        Text("Bible")
                            .font(.lilitaOne(size: 34))
                            .tracking(-1)
                            .foregroundStyle(YGColors.ink)

                        Spacer()

                        Button {
                            showTranslationPicker = true
                        } label: {
                            HStack(spacing: 5) {
                                Text(selectedTranslation.abbreviation)
                                    .font(.lilitaOne(size: 13))
                                    .foregroundStyle(YGColors.ink)

                                Image(systemName: "chevron.down")
                                    .font(.system(size: 11, weight: .heavy))
                                    .foregroundStyle(YGColors.ink.opacity(0.6))
                            }
                            .padding(.horizontal, 13)
                            .padding(.vertical, 7)
                            .liquidGlass()
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    .padding(.bottom, 20)

                    // Continue reading card
                    Button {
                        // Navigate to last read location or John 1 if never read
                        if let book = lastReadBook {
                            selectedBook = book
                            selectedChapter = lastReadChapter
                            showReader = true
                        }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 22)
                                .fill(
                                    LinearGradient(
                                        colors: [YGColors.violet, YGColors.pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: YGColors.violet.opacity(0.3), radius: 12, y: 8)
                                .clipped()

                            // Background circle
                            Circle()
                                .fill(.white.opacity(0.15))
                                .frame(width: 140, height: 140)
                                .offset(x: 90, y: -50)

                            HStack(spacing: 14) {
                                Image(systemName: "book.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.white)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("CONTINUE READING")
                                        .font(.system(size: 11.5, weight: .bold))
                                        .tracking(0.5)
                                        .foregroundStyle(.white.opacity(0.85))

                                    Text(continueReadingText)
                                        .font(.lilitaOne(size: 22))
                                        .tracking(-0.5)
                                        .foregroundStyle(.white)
                                }

                                Spacer()
                            }
                            .padding(18)
                        }
                        .frame(height: 90)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                    // OT/NT tabs
                    HStack(spacing: 6) {
                        ForEach([Testament.newTestament, Testament.oldTestament], id: \.self) { testament in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedTab = testament
                                }
                            } label: {
                                Text(testament == .newTestament ? "New Testament" : "Old Testament")
                                    .font(.lilitaOne(size: 13.5))
                                    .foregroundStyle(selectedTab == testament ? .white : YGColors.ink.opacity(0.6))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedTab == testament ? YGColors.ink : Color.clear)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(4)
                    .liquidGlass()
                    .clipShape(Capsule())
                    .padding(.top, 24)
                    .padding(.bottom, 12)

                    // Books list
                    VStack(spacing: 0) {
                        ForEach(Array(books.enumerated()), id: \.element.id) { index, book in
                            Button {
                                selectedBook = book
                                selectedChapter = 1
                                showReader = true
                            } label: {
                                HStack(spacing: 12) {
                                    Text(book.name)
                                        .font(.lilitaOne(size: 16))
                                        .tracking(-0.2)
                                        .foregroundStyle(YGColors.ink)

                                    Spacer()

                                    Text(chapterCount(for: book.name))
                                        .font(.system(size: 12))
                                        .foregroundStyle(YGColors.ink.opacity(0.4))

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(YGColors.ink.opacity(0.3))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color.white)
                                .overlay(alignment: .top) {
                                    if index > 0 {
                                        Divider()
                                            .padding(.leading, 16)
                                    }
                                }
                            }
                        }
                    }
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(Color.black.opacity(0.04), lineWidth: 0.5)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
            }
            .background(YGColors.paper)
            .ignoresSafeArea(edges: .top)

            // Reader overlay
            if showReader, let book = selectedBook {
                BibleReaderView(
                    book: book,
                    chapter: selectedChapter,
                    translation: selectedTranslation,
                    onBack: {
                        showReader = false
                    },
                    onTranslationTap: {
                        showTranslationPicker = true
                    },
                    onChapterChange: { newChapter in
                        selectedChapter = newChapter
                        // Save last read location
                        lastReadBookId = book.id
                        lastReadChapter = newChapter
                    }
                )
                .transition(.move(edge: .trailing))
                .zIndex(1)
                .onAppear {
                    // Save last read location when reader opens
                    lastReadBookId = book.id
                    lastReadChapter = selectedChapter
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showReader)
        .sheet(isPresented: $showTranslationPicker) {
            TranslationPickerView(selectedTranslation: $selectedTranslation)
        }
    }

    func chapterCount(for bookName: String) -> String {
        let counts: [String: Int] = [
            "Psalms": 150,
            "Proverbs": 31,
            "John": 21,
            "Genesis": 50,
            "Matthew": 28,
            "Acts": 28,
            "Romans": 16
        ]

        if let count = counts[bookName] {
            return "\(count) ch"
        }
        return "\(Int.random(in: 15...28)) ch"
    }
}

#Preview {
    BibleHomeView()
}
