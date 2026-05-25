//
//  LevelSystem.swift
//  YGTeeV
//
//  Mirrors the server-side `xp_for_level` / `level_for_xp` helpers so
//  we don't need a round-trip just to render the level badge or the
//  progress bar. Formula is `xp_for_level(n) = 500 * n * (n - 1)` —
//  Level 1 = 0 XP, Level 2 = 1000, Level 3 = 3000, Level 4 = 6000,
//  Level 5 = 10000, Level 8 = 28000, etc. No cap.
//
//  Always derive level from `lifetime_xp`, NEVER from the spendable
//  `xp` balance — otherwise buying things would level you down once
//  the store ships.
//

import Foundation

enum LevelSystem {
    /// Cumulative lifetime XP required to be AT this level.
    static func xpForLevel(_ level: Int) -> Int64 {
        let n = Int64(max(1, level))
        return 500 * n * (n - 1)
    }

    /// Current level given lifetime XP. Clamped to ≥ 1; uncapped above.
    static func levelForXP(_ xp: Int64) -> Int {
        let safe = max(0, xp)
        // Inverting xp = 500·n·(n−1) gives n = (1 + √(1 + xp/125)) / 2.
        let discriminant = 1.0 + Double(safe) / 125.0
        let n = (1.0 + discriminant.squareRoot()) / 2.0
        return max(1, Int(n.rounded(.down)))
    }

    /// All-in-one snapshot for the level bar UI. Pre-computes the
    /// surrounding floor + ceiling so the view doesn't have to.
    struct Progress {
        let level: Int
        let lifetimeXP: Int64
        let xpAtLevelFloor: Int64
        let xpAtNextLevel: Int64

        var xpIntoLevel: Int64 { lifetimeXP - xpAtLevelFloor }
        var xpToNext: Int64    { max(0, xpAtNextLevel - lifetimeXP) }
        var levelSpan: Int64   { max(1, xpAtNextLevel - xpAtLevelFloor) }

        var fraction: Double {
            Double(xpIntoLevel) / Double(levelSpan)
        }
    }

    static func progress(for lifetimeXP: Int64) -> Progress {
        let lvl = levelForXP(lifetimeXP)
        return Progress(
            level: lvl,
            lifetimeXP: lifetimeXP,
            xpAtLevelFloor: xpForLevel(lvl),
            xpAtNextLevel:  xpForLevel(lvl + 1)
        )
    }
}
