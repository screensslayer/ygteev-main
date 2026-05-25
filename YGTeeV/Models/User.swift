//
//  User.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/8/26.
//

import Foundation

// MARK: - User Model
// Maps to public.profiles table
struct User: Identifiable, Codable {
    let id: String              // UUID primary key
    let email: String?          // Email from auth.users
    var displayName: String?    // User's display name
    var handle: String?         // Server-generated unique handle; never client-edited
    var avatarUrl: String?      // Profile avatar URL
    var ageBand: String?        // Age band category
    var bio: String?            // Short profile bio (≤280 chars)
    var xp: Int                 // Spendable XP balance
    var lifetimeXP: Int64       // Total XP ever earned, never decremented — drives `level`
    var water: Int              // Water currency
    var streak: Int             // Current streak count
    var gradeYear: Int?         // 6..12, or nil for "not a student" / adult
    var lastOpenedAt: Date      // Last app open timestamp (updated by heartbeat RPC)
    var createdAt: Date         // Profile creation timestamp
    var updatedAt: Date         // Last update timestamp

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case handle
        case avatarUrl = "avatar_url"
        case ageBand = "age_band"
        case bio
        case xp
        case lifetimeXP = "lifetime_xp"
        case water
        case streak
        case gradeYear = "grade_year"
        case lastOpenedAt = "last_opened_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Defensive decoder: tolerate narrower `select(...)` callers that
    /// don't return `grade_year`. All other fields stay required.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(String.self, forKey: .id)
        email         = try c.decodeIfPresent(String.self, forKey: .email)
        displayName   = try c.decodeIfPresent(String.self, forKey: .displayName)
        handle        = try c.decodeIfPresent(String.self, forKey: .handle)
        avatarUrl     = try c.decodeIfPresent(String.self, forKey: .avatarUrl)
        ageBand       = try c.decodeIfPresent(String.self, forKey: .ageBand)
        bio           = try c.decodeIfPresent(String.self, forKey: .bio)
        xp            = try c.decodeIfPresent(Int.self, forKey: .xp) ?? 0
        lifetimeXP    = try c.decodeIfPresent(Int64.self, forKey: .lifetimeXP) ?? 0
        water         = try c.decodeIfPresent(Int.self, forKey: .water) ?? 0
        streak        = try c.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        gradeYear     = try c.decodeIfPresent(Int.self, forKey: .gradeYear)
        lastOpenedAt  = try c.decodeIfPresent(Date.self, forKey: .lastOpenedAt) ?? Date()
        createdAt     = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt     = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
}
