//
//  NotificationSettingsService.swift
//  YGTeeV
//
//  Wraps the `my_notification_settings()` RPC for reads and direct
//  `notification_preferences` table writes (RLS allows the caller to
//  edit their own row).
//
//  Two surfaces:
//    • `load()` — pull the full category+kind layout for the current
//      user, scoped to their roles by the server.
//    • `save(disabledCategories:disabledKinds:dailyReadingHour:tz:)`
//      — debounced upsert from the settings UI.
//    • `syncTimezoneIfNeeded()` — fired from the app-launch task so
//      the daily-reading reminder cron uses the user's CURRENT local
//      time, even if they crossed a timezone since their last visit.
//

import Foundation
import Supabase

@MainActor
final class NotificationSettingsService {
    static let shared = NotificationSettingsService()
    private let client = SupabaseManager.shared.client
    private init() {}

    // MARK: - Read

    func load() async throws -> NotificationSettings {
        try await client
            .rpc("my_notification_settings")
            .execute()
            .value
    }

    // MARK: - Write

    /// Patch the caller's `notification_preferences` row with the
    /// disabled-keys arrays + daily-reading hour/timezone. Caller is
    /// responsible for debouncing.
    func save(
        disabledCategories: [String],
        disabledKinds: [String],
        dailyReadingHour: Int,
        dailyReadingTimezone: String
    ) async throws {
        guard let uid = SupabaseManager.shared.currentUser?.id else {
            throw NSError(domain: "NotificationSettingsService", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Not signed in."])
        }
        struct Patch: Encodable {
            let disabled_categories: [String]
            let disabled_kinds: [String]
            let daily_reading_hour: Int
            let daily_reading_timezone: String
        }
        _ = try await client
            .from("notification_preferences")
            .update(Patch(
                disabled_categories: disabledCategories,
                disabled_kinds: disabledKinds,
                daily_reading_hour: dailyReadingHour,
                daily_reading_timezone: dailyReadingTimezone
            ))
            .eq("user_id", value: uid.lowercased())
            .execute()
    }

    /// Upserts the user's local timezone into
    /// `notification_preferences.daily_reading_timezone`. Called from
    /// the launch path so the row exists even before the user opens
    /// the notification settings screen, and the daily-reminder cron
    /// always has the freshest tz to compare against.
    func syncTimezoneIfNeeded() async {
        guard let uid = SupabaseManager.shared.currentUser?.id else { return }
        struct Row: Encodable {
            let user_id: String
            let daily_reading_timezone: String
        }
        do {
            _ = try await client
                .from("notification_preferences")
                .upsert(
                    Row(user_id: uid.lowercased(),
                        daily_reading_timezone: TimeZone.current.identifier),
                    onConflict: "user_id"
                )
                .execute()
        } catch {
            print("[notifications] tz upsert failed:", error)
        }
    }
}
