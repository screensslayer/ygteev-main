//
//  VerseAudioService.swift
//  YGTeeV
//
//  Resolves a scripture reference (e.g. "John 3:16-21") to a list of
//  pre-recorded verse-narration URLs from Supabase's public
//  `verse-audio` bucket. Returns nil when no rows exist for the
//  reference, letting the caller (`ReadStepView` / `VersePlaybackController`)
//  fall back to on-device `AVSpeechSynthesizer`.
//
//  Backend contract (see CLAUDE.md discussion):
//    table `verse_audio` — anon SELECT allowed
//      bible_id  = "d6e14a625393b4da-01"   (NLT, same as BibleAPIService)
//      voice_id  = "NPJ9YKwI4PhhZaBPyKlD"  (our narrator)
//      book_id, chapter, verse, storage_path, duration_seconds
//    files served publicly from
//      https://<project>.supabase.co/storage/v1/object/public/verse-audio/{storage_path}
//

import Foundation
import Supabase

struct VerseAudioItem {
    let verse: Int
    let url: URL
    let duration: Double
}

@Observable
final class VerseAudioService {
    static let shared = VerseAudioService()

    /// Same NLT id BibleAPIService uses. Keep them in lockstep — if
    /// the app's default translation changes we'd want narration to
    /// track it (or gracefully fall back to TTS for the new one).
    private let bibleId  = "d6e14a625393b4da-01"
    /// The single ElevenLabs voice we've recorded John with.
    private let voiceId  = "NPJ9YKwI4PhhZaBPyKlD"
    /// Public bucket base URL for the verse-audio files. Files are
    /// intentionally unauthenticated — no signed URL needed.
    private let publicBucketBase =
        "https://tkesywmshaicjmywbovn.supabase.co/storage/v1/object/public/verse-audio/"

    /// In-memory cache keyed by the raw reference string. Same
    /// pattern as `BibleAPIService.versesByReference`.
    @ObservationIgnored private var itemsByReference: [String: [VerseAudioItem]] = [:]

    private init() {}

    /// Look up pre-recorded narration for a reference.
    ///
    /// Returns:
    ///   • `nil` — no rows at all (caller should fall back to TTS).
    ///   • non-empty `[VerseAudioItem]` — one entry per verse we have
    ///     audio for, in verse order. If the row-set is a subset of
    ///     the reference range (e.g. NLT omissions like John 5:4),
    ///     we still return the subset — the queue just skips the
    ///     missing verse. Same behavior as `BibleAPIService`, which
    ///     also returns what's present.
    func narration(for reference: String) async -> [VerseAudioItem]? {
        if let cached = itemsByReference[reference] {
            return cached.isEmpty ? nil : cached
        }

        guard let parsed = BibleAPIService.parse(reference: reference),
              let bookId = BibleAPIService.bookId(forName: parsed.bookName)
        else {
            print("[VerseAudioService] couldn't resolve reference: \(reference)")
            return nil
        }

        // BibleAPIService uses Int.max as a sentinel for "whole chapter".
        // Fetch open-ended in that case (no upper `.lte`), otherwise
        // clamp to the requested range.
        let wholeChapter = parsed.endVerse == Int.max

        do {
            let client = SupabaseManager.shared.client
            var query = client
                .from("verse_audio")
                .select("verse, storage_path, duration_seconds")
                .eq("bible_id", value: bibleId)
                .eq("voice_id", value: voiceId)
                .eq("book_id", value: bookId)
                .eq("chapter", value: parsed.chapter)
                .gte("verse", value: parsed.startVerse)
            if !wholeChapter {
                query = query.lte("verse", value: parsed.endVerse)
            }
            let rows: [Row] = try await query
                .order("verse", ascending: true)
                .execute()
                .value

            let items: [VerseAudioItem] = rows.compactMap { row in
                guard let url = URL(string: publicBucketBase + row.storage_path) else {
                    return nil
                }
                return VerseAudioItem(
                    verse: row.verse,
                    url: url,
                    duration: row.duration_seconds
                )
            }
            // Cache the result (including empty) so a plan with no
            // narration doesn't re-hit Supabase on every speaker tap.
            itemsByReference[reference] = items
            return items.isEmpty ? nil : items
        } catch {
            print("[VerseAudioService] query error for \(reference):", error)
            return nil
        }
    }

    // MARK: - Row model

    /// Matches the columns we `.select()` above. `snake_case` names
    /// are what PostgREST returns; letting the JSONDecoder use them
    /// directly avoids a translation layer.
    private struct Row: Decodable {
        let verse: Int
        let storage_path: String
        let duration_seconds: Double
    }
}
