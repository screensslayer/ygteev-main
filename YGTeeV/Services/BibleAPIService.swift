//
//  BibleAPIService.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/7/26.
//

import Foundation

// MARK: - Bible API Service
@Observable
class BibleAPIService {
    static let shared = BibleAPIService()

    private let apiKey = "dAzpo9z4vm_9jY_8BW2aX"
    private let baseURL = "https://rest.api.bible/v1"

    // New Living Translation (NLT) — licensed via the paid api.bible
    // account. The same constant is also hardcoded as the default
    // argument on every fetch method below; keep them in sync if the
    // translation ever changes.
    private let defaultBibleId = "65eec8e0b60e656b-01"

    private init() {}

    // MARK: - Fetch Books
    func fetchBooks(bibleId: String = "65eec8e0b60e656b-01") async throws -> [BibleBook] {
        let url = URL(string: "\(baseURL)/bibles/\(bibleId)/books")!
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(BooksResponse.self, from: data)

        return response.data.map { book in
            BibleBook(
                id: book.id,
                name: book.name,
                abbreviation: book.abbreviation,
                chapters: []
            )
        }
    }

    // MARK: - Fetch Chapter
    func fetchChapter(bibleId: String = "65eec8e0b60e656b-01", chapterId: String) async throws -> BibleChapter {
        let url = URL(string: "\(baseURL)/bibles/\(bibleId)/chapters/\(chapterId)?content-type=text&include-verse-numbers=true")!
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(ChapterResponse.self, from: data)

        return BibleChapter(
            id: response.data.id,
            number: response.data.number,
            content: response.data.content,
            reference: response.data.reference,
            bookId: response.data.bookId
        )
    }

    // MARK: - Reference-based fetch + cache
    //
    // The plan-day backend gives us references like "Romans 1:1-7" or
    // "John 3:16". This resolves the book/chapter/range, calls the API,
    // and caches per reference so quick-tab switching doesn't refetch.

    private var versesByReference: [String: [BibleVerse]] = [:]

    func versesForReference(_ reference: String, bibleId: String = "65eec8e0b60e656b-01") async throws -> [BibleVerse] {
        let key = "\(bibleId)|\(reference)"
        if let cached = versesByReference[key] { return cached }

        guard let parsed = Self.parse(reference: reference) else {
            print("[BibleAPIService] couldn't parse reference: \(reference)")
            return []
        }
        guard let bookId = Self.bookId(forName: parsed.bookName) else {
            print("[BibleAPIService] unknown book name: \(parsed.bookName)")
            return []
        }
        let chapterId = "\(bookId).\(parsed.chapter)"

        // The `/chapters/{id}/verses` endpoint only returns metadata.
        // Use the chapter endpoint (which includes verse-number markers) and
        // parse the content.
        let chapter = try await fetchChapter(bibleId: bibleId, chapterId: chapterId)
        let allVerses = Self.parseChapterContent(chapter.content, bookId: bookId, chapterNumber: parsed.chapter)
        let filtered = allVerses.filter { v in
            v.number >= parsed.startVerse && v.number <= parsed.endVerse
        }
        versesByReference[key] = filtered
        return filtered
    }

    /// Splits chapter content like "[1] Paul, a servant... [2] the gospel..." into verses.
    private static func parseChapterContent(_ content: String, bookId: String, chapterNumber: Int) -> [BibleVerse] {
        let pattern = #"\[(\d+)\]\s+([\s\S]+?)(?=\[\d+\]|$)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        let nsString = content as NSString
        let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsString.length))

        return matches.compactMap { match -> BibleVerse? in
            guard match.numberOfRanges == 3 else { return nil }
            let numStr = nsString.substring(with: match.range(at: 1))
            let text   = nsString.substring(with: match.range(at: 2))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let n = Int(numStr) else { return nil }
            return BibleVerse(
                id: "\(bookId).\(chapterNumber).\(n)",
                number: n,
                text: text
            )
        }
    }

    private static func parse(reference: String) -> (bookName: String, chapter: Int, startVerse: Int, endVerse: Int)? {
        // Accepts:
        //   "Romans 1:1-7"   → verses 1–7 of Romans 1
        //   "1 Corinthians 13:4-13"
        //   "John 3:16"      → single verse
        //   "Numbers 23"     → entire chapter
        //   "1 Kings 2"      → entire chapter
        let trimmed = reference.trimmingCharacters(in: .whitespaces)

        let leftSide:  String
        let rightSide: String
        if let colon = trimmed.firstIndex(of: ":") {
            leftSide  = String(trimmed[..<colon]).trimmingCharacters(in: .whitespaces)
            rightSide = String(trimmed[trimmed.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        } else {
            // No colon → whole chapter
            leftSide  = trimmed
            rightSide = ""
        }

        let leftTokens = leftSide.split(whereSeparator: { $0.isWhitespace })
        guard leftTokens.count >= 2, let chapter = Int(leftTokens.last!) else { return nil }
        let bookName = leftTokens.dropLast().joined(separator: " ")

        if rightSide.isEmpty {
            // Whole chapter — fetch every verse.
            return (bookName, chapter, 1, Int.max)
        }

        let verseParts = rightSide.split(separator: "-", maxSplits: 1)
        guard let start = Int(verseParts[0]) else { return nil }
        let end = verseParts.count == 2 ? (Int(verseParts[1]) ?? start) : start
        return (bookName, chapter, start, end)
    }

    private static func bookId(forName name: String) -> String? {
        let normalized = name.lowercased()
        return BibleBook.allBooks.first { book in
            book.name.lowercased() == normalized
        }?.id
    }

    // MARK: - Fetch Verses
    func fetchVerses(bibleId: String = "65eec8e0b60e656b-01", chapterId: String) async throws -> [BibleVerse] {
        let url = URL(string: "\(baseURL)/bibles/\(bibleId)/chapters/\(chapterId)/verses?content-type=text")!
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        print("🌐 API Request: \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📡 Status code: \(httpResponse.statusCode)")
        }
        
        // Print raw JSON for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📄 Raw response: \(jsonString.prefix(500))")
        }
        
        let decodedResponse = try JSONDecoder().decode(VersesResponse.self, from: data)
        
        print("📚 Decoded \(decodedResponse.data.count) verses")

        return decodedResponse.data.map { verse in
            BibleVerse(
                id: verse.id,
                number: Int(verse.id.split(separator: ".").last ?? "1") ?? 1,
                text: verse.content ?? ""
            )
        }
    }
}

// MARK: - API Response Models
struct BooksResponse: Codable {
    let data: [BookData]
}

struct BookData: Codable {
    let id: String
    let name: String
    let abbreviation: String
}

struct ChapterResponse: Codable {
    let data: ChapterData
}

struct ChapterData: Codable {
    let id: String
    let bookId: String
    let number: String
    let content: String
    let reference: String
}

struct VersesResponse: Codable {
    let data: [VerseData]
}

struct VerseData: Codable {
    let id: String
    let reference: String
    let content: String?
}
