//
//  NotificationSettings.swift
//  YGTeeV
//
//  Shapes returned by the `my_notification_settings()` RPC and the
//  payload we write back to `notification_preferences`. The server
//  filters categories+kinds by the caller's roles before returning,
//  so we don't have to do any role-aware UI gating client-side.
//

import Foundation

struct NotificationSettings: Decodable, Hashable {
    let myRoles: [String]
    let dailyReadingHour: Int
    let dailyReadingTimezone: String?
    let categories: [NotificationCategory]

    enum CodingKeys: String, CodingKey {
        case myRoles              = "my_roles"
        case dailyReadingHour     = "daily_reading_hour"
        case dailyReadingTimezone = "daily_reading_timezone"
        case categories
    }
}

struct NotificationCategory: Decodable, Identifiable, Hashable {
    var id: String { key }
    let key: String
    let label: String
    let sortOrder: Int
    /// Server-derived: `false` when this category's key sits in the
    /// user's `disabled_categories` array. Drives the master Toggle.
    let enabled: Bool
    let kinds: [NotificationKind]

    enum CodingKeys: String, CodingKey {
        case key, label, enabled, kinds
        case sortOrder = "sort_order"
    }
}

struct NotificationKind: Decodable, Identifiable, Hashable {
    var id: String { key }
    let key: String
    let label: String
    let description: String?
    /// Server-derived: `false` when this kind's key sits in the user's
    /// `disabled_kinds` array. Drives the per-kind Toggle.
    let enabled: Bool
}
