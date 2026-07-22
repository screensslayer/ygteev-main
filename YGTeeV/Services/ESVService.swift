//
//  ESVService.swift
//  YGTeeV
//
//  Fetches ESV (English Standard Version) verse text from Crossway's
//  api.esv.org. ESV is served by a different provider than the five
//  api.bible translations (NLT / NIV / NASB / NKJV / AMP), so we can't
//  reuse `BibleAPIService`'s api.bible-shaped requests.
//
//  Mirrors the shape of `BibleAPIService` for the two calls the reader
//  and plan flows actually need:
//    • `versesForReference(_:)` — for arbitrary references
//      ("John 3:16", "Romans 1:1-7", "Psalm 23")
//    • `versesForChapter(book:chapter:)` — for whole-chapter fetches
//      out of `BibleReaderView`
//
//  Response text uses the SAME `[n]`-bracket verse markers api.bible
//  returns, so we reuse `BibleAPIService.parseChapterContent` verbatim
//  instead of maintaining a second regex.
//
//  Rate limit: the shared token is ~5,000 requests/day. The in-memory
//  cache below is required — do NOT prefetch whole books, and do NOT
//  bypass the cache.
//
//  Attribution requirement: any UI that shows ESV text must display
//  "ESV" alongside the passage reference AND surface Crossway's full
//  copyright notice on the settings/about screen. See
//  `AccountSettingsView` for the notice text.
//

import Foundation

@Observable
final class ESVService {
    static let shared = ESVService()

    /// Crossway ESV API v3 base — text-only endpoint (no HTML).
    private let baseURL = "https://api.esv.org/v3/passage/text/"
    /// Shared read-only token. Rate-limited (~5k/day) — the cache
    /// below is why we don't have to worry about it in normal use.
    private let token = "8887cb73f327133eab8999e8c73288051d752ace"

    /// In-memory cache keyed by the raw reference string. Same
    /// pattern as `BibleAPIService.versesByReference`. Cleared on
    /// process death — fine, since 5k/day is plenty for a session.
    @ObservationIgnored private var versesByReference: [String: [BibleVerse]] = [:]

    private init() {}

    // MARK: - Public API

    /// Fetch verses for a human-readable reference. ESV accepts the
    /// reference string directly in `?q=`, so we don't need the OSIS
    /// book-id lookup that api.bible requires.
    func versesForReference(_ reference: String) async throws -> [BibleVerse] {
        let cacheKey = "esv|\(reference)"
        if let cached = versesByReference[cacheKey] { return cached }

        // Resolve the reference to bookId + chapter so the returned
        // `BibleVerse.id` matches the api.bible format
        // (`"{bookId}.{chapter}.{verse}"`) — downstream views index
        // on these ids and mixing formats would break highlight
        // tracking and resume offsets.
        guard let parsed = BibleAPIService.parse(reference: reference),
              let bookId = BibleAPIService.bookId(forName: parsed.bookName) else {
            print("[ESVService] couldn't parse reference: \(reference)")
            return []
        }

        let raw = try await fetchPassageText(query: reference)
        let allVerses = BibleAPIService.parseChapterContent(
            raw,
            bookId: bookId,
            chapterNumber: parsed.chapter
        )
        // Whole-chapter path uses `Int.max` as the sentinel; return
        // everything the API gave us. Partial-range paths filter.
        let filtered: [BibleVerse]
        if parsed.endVerse == Int.max {
            filtered = allVerses
        } else {
            filtered = allVerses.filter {
                $0.number >= parsed.startVerse && $0.number <= parsed.endVerse
            }
        }
        versesByReference[cacheKey] = filtered
        return filtered
    }

    /// Whole-chapter fetch used by `BibleReaderView`. Constructs the
    /// human-readable reference (`"John 3"`) and hands off to
    /// `versesForReference`, which owns the ESV call + cache.
    func versesForChapter(book: BibleBook, chapter: Int) async throws -> [BibleVerse] {
        try await versesForReference("\(book.name) \(chapter)")
    }

    // MARK: - Networking

    private func fetchPassageText(query: String) async throws -> String {
        var comps = URLComponents(string: baseURL)!
        comps.queryItems = [
            URLQueryItem(name: "q",                            value: query),
            URLQueryItem(name: "include-passage-references",   value: "false"),
            URLQueryItem(name: "include-verse-numbers",        value: "true"),
            URLQueryItem(name: "include-footnotes",            value: "false"),
            URLQueryItem(name: "include-headings",             value: "false"),
            URLQueryItem(name: "include-short-copyright",      value: "false"),
            URLQueryItem(name: "indent-poetry",                value: "false"),
        ]
        guard let url = comps.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        // Crossway uses a plain-text token in the Authorization
        // header (NOT bearer scheme). See ESV API v3 docs.
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(ESVPassageResponse.self, from: data)
        // Multiple passages are rare for the queries we send (single
        // reference or single chapter), but the API can return them
        // for cross-book queries. Join with newlines so the
        // `parseChapterContent` regex still sees all `[n]` markers.
        return decoded.passages.joined(separator: "\n")
    }

    // MARK: - Response model

    private struct ESVPassageResponse: Decodable {
        let canonical: String
        let passages: [String]
    }
}
