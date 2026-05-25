//
//  Bible.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/7/26.
//

import SwiftUI

// MARK: - Bible Book
struct BibleBook: Identifiable, Codable {
    let id: String
    let name: String
    let abbreviation: String
    let chapters: [BibleChapter]

    var initials: String {
        name.split(separator: " ")
            .prefix(2)
            .map { String($0.prefix(1)) }
            .joined()
    }

    var colorHue: Double {
        Double(name.unicodeScalars.first?.value ?? 0) * 9
    }
}

// MARK: - Bible Chapter
struct BibleChapter: Identifiable, Codable {
    let id: String
    let number: String
    let content: String
    let reference: String
    let bookId: String
}

// MARK: - Bible Verse
struct BibleVerse: Identifiable, Codable {
    let id: String
    let number: Int
    let text: String
    var isHighlighted: Bool = false
}

// MARK: - Bible Translation
struct BibleTranslation: Identifiable {
    let id: String
    let abbreviation: String
    let name: String
    let description: String

    static let translations: [BibleTranslation] = [
        BibleTranslation(id: "de4e12af7f28f599-02", abbreviation: "NLT", name: "New Living Translation", description: "Modern · easy to read"),
        BibleTranslation(id: "de4e12af7f28f599-01", abbreviation: "NIV", name: "New International Version", description: "Most common"),
        BibleTranslation(id: "06125adad2d5898a-01", abbreviation: "NASB", name: "New American Standard Bible", description: "Word-for-word · accurate"),
    ]
}

// MARK: - Sample Data
extension BibleBook {
    static let oldTestament: [BibleBook] = [
        BibleBook(id: "GEN", name: "Genesis", abbreviation: "Gen", chapters: []),
        BibleBook(id: "EXO", name: "Exodus", abbreviation: "Exod", chapters: []),
        BibleBook(id: "LEV", name: "Leviticus", abbreviation: "Lev", chapters: []),
        BibleBook(id: "NUM", name: "Numbers", abbreviation: "Num", chapters: []),
        BibleBook(id: "DEU", name: "Deuteronomy", abbreviation: "Deut", chapters: []),
        BibleBook(id: "JOS", name: "Joshua", abbreviation: "Josh", chapters: []),
        BibleBook(id: "JDG", name: "Judges", abbreviation: "Judg", chapters: []),
        BibleBook(id: "RUT", name: "Ruth", abbreviation: "Ruth", chapters: []),
        BibleBook(id: "1SA", name: "1 Samuel", abbreviation: "1 Sam", chapters: []),
        BibleBook(id: "2SA", name: "2 Samuel", abbreviation: "2 Sam", chapters: []),
        BibleBook(id: "1KI", name: "1 Kings", abbreviation: "1 Kgs", chapters: []),
        BibleBook(id: "2KI", name: "2 Kings", abbreviation: "2 Kgs", chapters: []),
        BibleBook(id: "1CH", name: "1 Chronicles", abbreviation: "1 Chr", chapters: []),
        BibleBook(id: "2CH", name: "2 Chronicles", abbreviation: "2 Chr", chapters: []),
        BibleBook(id: "EZR", name: "Ezra", abbreviation: "Ezra", chapters: []),
        BibleBook(id: "NEH", name: "Nehemiah", abbreviation: "Neh", chapters: []),
        BibleBook(id: "EST", name: "Esther", abbreviation: "Esth", chapters: []),
        BibleBook(id: "JOB", name: "Job", abbreviation: "Job", chapters: []),
        BibleBook(id: "PSA", name: "Psalms", abbreviation: "Ps", chapters: []),
        BibleBook(id: "PRO", name: "Proverbs", abbreviation: "Prov", chapters: []),
        BibleBook(id: "ECC", name: "Ecclesiastes", abbreviation: "Eccl", chapters: []),
        BibleBook(id: "SNG", name: "Song of Solomon", abbreviation: "Song", chapters: []),
        BibleBook(id: "ISA", name: "Isaiah", abbreviation: "Isa", chapters: []),
        BibleBook(id: "JER", name: "Jeremiah", abbreviation: "Jer", chapters: []),
        BibleBook(id: "LAM", name: "Lamentations", abbreviation: "Lam", chapters: []),
        BibleBook(id: "EZK", name: "Ezekiel", abbreviation: "Ezek", chapters: []),
        BibleBook(id: "DAN", name: "Daniel", abbreviation: "Dan", chapters: []),
        BibleBook(id: "HOS", name: "Hosea", abbreviation: "Hos", chapters: []),
        BibleBook(id: "JOL", name: "Joel", abbreviation: "Joel", chapters: []),
        BibleBook(id: "AMO", name: "Amos", abbreviation: "Amos", chapters: []),
        BibleBook(id: "OBA", name: "Obadiah", abbreviation: "Obad", chapters: []),
        BibleBook(id: "JON", name: "Jonah", abbreviation: "Jonah", chapters: []),
        BibleBook(id: "MIC", name: "Micah", abbreviation: "Mic", chapters: []),
        BibleBook(id: "NAM", name: "Nahum", abbreviation: "Nah", chapters: []),
        BibleBook(id: "HAB", name: "Habakkuk", abbreviation: "Hab", chapters: []),
        BibleBook(id: "ZEP", name: "Zephaniah", abbreviation: "Zeph", chapters: []),
        BibleBook(id: "HAG", name: "Haggai", abbreviation: "Hag", chapters: []),
        BibleBook(id: "ZEC", name: "Zechariah", abbreviation: "Zech", chapters: []),
        BibleBook(id: "MAL", name: "Malachi", abbreviation: "Mal", chapters: []),
    ]

    static let newTestament: [BibleBook] = [
        BibleBook(id: "MAT", name: "Matthew", abbreviation: "Matt", chapters: []),
        BibleBook(id: "MRK", name: "Mark", abbreviation: "Mark", chapters: []),
        BibleBook(id: "LUK", name: "Luke", abbreviation: "Luke", chapters: []),
        BibleBook(id: "JHN", name: "John", abbreviation: "John", chapters: []),
        BibleBook(id: "ACT", name: "Acts", abbreviation: "Acts", chapters: []),
        BibleBook(id: "ROM", name: "Romans", abbreviation: "Rom", chapters: []),
        BibleBook(id: "1CO", name: "1 Corinthians", abbreviation: "1 Cor", chapters: []),
        BibleBook(id: "2CO", name: "2 Corinthians", abbreviation: "2 Cor", chapters: []),
        BibleBook(id: "GAL", name: "Galatians", abbreviation: "Gal", chapters: []),
        BibleBook(id: "EPH", name: "Ephesians", abbreviation: "Eph", chapters: []),
        BibleBook(id: "PHP", name: "Philippians", abbreviation: "Phil", chapters: []),
        BibleBook(id: "COL", name: "Colossians", abbreviation: "Col", chapters: []),
        BibleBook(id: "1TH", name: "1 Thessalonians", abbreviation: "1 Thess", chapters: []),
        BibleBook(id: "2TH", name: "2 Thessalonians", abbreviation: "2 Thess", chapters: []),
        BibleBook(id: "1TI", name: "1 Timothy", abbreviation: "1 Tim", chapters: []),
        BibleBook(id: "2TI", name: "2 Timothy", abbreviation: "2 Tim", chapters: []),
        BibleBook(id: "TIT", name: "Titus", abbreviation: "Titus", chapters: []),
        BibleBook(id: "PHM", name: "Philemon", abbreviation: "Phlm", chapters: []),
        BibleBook(id: "HEB", name: "Hebrews", abbreviation: "Heb", chapters: []),
        BibleBook(id: "JAS", name: "James", abbreviation: "Jas", chapters: []),
        BibleBook(id: "1PE", name: "1 Peter", abbreviation: "1 Pet", chapters: []),
        BibleBook(id: "2PE", name: "2 Peter", abbreviation: "2 Pet", chapters: []),
        BibleBook(id: "1JN", name: "1 John", abbreviation: "1 John", chapters: []),
        BibleBook(id: "2JN", name: "2 John", abbreviation: "2 John", chapters: []),
        BibleBook(id: "3JN", name: "3 John", abbreviation: "3 John", chapters: []),
        BibleBook(id: "JUD", name: "Jude", abbreviation: "Jude", chapters: []),
        BibleBook(id: "REV", name: "Revelation", abbreviation: "Rev", chapters: []),
    ]
    
    static var allBooks: [BibleBook] {
        oldTestament + newTestament
    }
}
