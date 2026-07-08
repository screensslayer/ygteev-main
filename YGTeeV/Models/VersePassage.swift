//
//  VersePassage.swift
//  YGTeeV
//
//  Self-contained payload the voice reader needs to play (and
//  resume + highlight) one block of scripture. Built from the
//  verses currently visible in the Read step's active part.
//
//  Three things travel together:
//    • `text`         — what the synthesizer reads. Numbers already
//                       stripped, verses joined by a single space.
//    • `identifier`   — stable key for resume tracking. Format is
//                       `{planId}:{dayId}:{partIndex}` so the same
//                       passage can be picked up across mini-player
//                       open/close cycles within a session.
//    • `verseMap`     — character-offset ↔ verse-number index so
//                       `willSpeakRangeOfSpeechString` can report
//                       which verse is currently being read for the
//                       highlight effect.
//

import Foundation

struct VersePassage: Equatable {
    let text: String
    let identifier: String
    let title: String
    let verseMap: [VerseRange]

    struct VerseRange: Equatable {
        let verseNumber: Int
        /// Inclusive start offset (in `text`) where this verse begins.
        let startOffset: Int
        /// Exclusive end offset (in `text`) where this verse ends.
        let endOffset: Int
    }
}
