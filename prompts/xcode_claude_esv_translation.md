# Xcode-Claude prompt — Add ESV as a Bible translation (separate provider)

> Paste everything below the line into xcode-claude in the YGTeeV project.
>
> Human notes (not for xcode-claude):
> - The ESV API's standard keys are licensed for **non-commercial** use.
>   YGTeeV charges subscriptions — email Crossway (api@crossway.org) for
>   commercial permission before this ships to the App Store.
> - Verified live 2026-07-21: the token below returns passages (HTTP 200),
>   and all five existing api.bible translations also work (200s).

---

Add **ESV (English Standard Version)** to the Bible reader's translation
picker. Unlike the five existing translations (which all come from
api.bible via `BibleAPIService`), ESV comes from a separate provider:
Crossway's ESV API. Verified request shape:

```
GET https://api.esv.org/v3/passage/text/?q=John+3
Authorization: Token 8887cb73f327133eab8999e8c73288051d752ace
```

Query params to always send: `include-passage-references=false`,
`include-verse-numbers=true`, `include-footnotes=false`,
`include-headings=false`, `include-short-copyright=false`,
`indent-poetry=false`. Response JSON: `{ canonical, passages: [String] }` —
`passages` entries contain verse text with the SAME `[16]`-style bracket
markers `BibleAPIService.parseChapterContent` already parses for
api.bible. `q` accepts human-readable references directly ("John 3",
"John 3:16-18", "Psalm 23") — no OSIS book-id mapping needed for ESV.

## Implementation

1. **Provider concept.** Give `BibleTranslation` (Models/Bible.swift) a
   `provider` field: `.apiBible` (default, existing five) or `.esv`. Add
   the picker entry after NLT:
   `BibleTranslation(id: "esv", abbreviation: "ESV", name: "English
   Standard Version", description: "Word-for-word · trusted", provider:
   .esv)`. Selected-translation persistence must keep working unchanged.
2. **ESVService** (new file, Services/ESVService.swift): mirrors the
   surface of `BibleAPIService` that the reader actually uses —
   `versesForReference(_:)` and whole-chapter fetch. Token and base URL
   as constants (same pattern as the api.bible key in BibleAPIService).
   Parse `passages.joined()` with the same `[n]` regex + `cleanVerse`
   pipeline as `parseChapterContent` (reuse/extract that helper rather
   than duplicating it). Reuse the same in-memory cache pattern, keyed
   `"esv|{reference}"`.
3. **Routing.** Wherever the reader/plan flow calls `BibleAPIService`
   with the selected translation, branch on `provider`: `.esv` →
   `ESVService`, else existing path. Keep call sites minimal — ideally
   one façade function switches providers so views don't know.
4. **Books list.** The ESV API has no books endpoint — for the full-Bible
   reader use the app's existing static canonical book list (the OSIS
   mapping table in BibleAPIService already enumerates the 66 books).
   Chapter counts: reuse whatever the NLT book metadata provides, or a
   static chapter-count table.
5. **Verse narration audio.** The recorded narration catalog
   (`VerseAudioService`) is NLT-only (`bible_id d6e14a625393b4da-01`).
   Gate narration on the selected translation: NLT → narration as today;
   any other translation (incl. ESV) → skip catalog lookup entirely and
   use the existing device-TTS fallback. Switching back to NLT restores
   narration.
6. **Required ESV attribution.** When ESV is the active translation, show
   "ESV" beside the passage reference in the reader, and add the full
   Crossway notice to the settings/about screen:
   "Scripture quotations are from the ESV® Bible (The Holy Bible, English
   Standard Version®), copyright © 2001 by Crossway, a publishing
   ministry of Good News Publishers. Used by permission. All rights
   reserved."
7. **Rate limit.** The token allows ~5,000 requests/day — the in-memory
   cache above is required, and do not prefetch whole books.

## Test before calling it done

- Reader: John 3 (prose), Psalm 23 (poetry — confirm clean lines with
  `indent-poetry=false`), Jude (single-chapter book reference parsing).
- A daily plan day end-to-end with ESV selected (read + quiz), then the
  same day with NLT — both must render identical verse counts for
  standard passages.
- John 5 in both: NLT omits 5:4, ESV includes it — confirm no crash or
  misalignment in the reader.
- Verse audio: ESV day uses TTS fallback with no errors; NLT day plays
  recorded narration.
- Translation picker persists ESV across app relaunch.
