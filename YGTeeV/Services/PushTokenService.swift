//
//  PushTokenService.swift
//  YGTeeV
//
//  Persists the device's APNS token on the backend so the
//  `dispatch-notification` Edge Function can fan-out pushes to this
//  device for the signed-in user. The AppDelegate posts the token
//  via `register(token:)` whenever Apple issues a fresh one — which
//  happens on first launch after permission is granted, on app
//  reinstall, on restore from backup, and occasionally on iOS update.
//

import Foundation
import Supabase
import UIKit

@MainActor
final class PushTokenService {
    static let shared = PushTokenService()
    private init() {}

    /// Hands the APNS hex token to the `register-push-token` Edge
    /// Function. Idempotent server-side — re-registering the same
    /// token just updates `last_seen_at` on the existing row.
    /// Fire-and-forget: the caller (AppDelegate) doesn't await.
    func register(token: String) async {
        struct P: Encodable {
            let device_token: String
            let app_version: String?
        }
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        do {
            _ = try await SupabaseManager.shared.client.functions.invoke(
                "register-push-token",
                options: FunctionInvokeOptions(body: P(
                    device_token: token,
                    app_version: appVersion
                ))
            )
            #if DEBUG
            print("[apns] register-push-token ok (\(token.prefix(12))…)")
            #endif
        } catch {
            print("[apns] register-push-token failed:", error)
        }
    }

    /// Idempotent permission check — pops the system prompt on first
    /// run (status == .notDetermined) and triggers
    /// `registerForRemoteNotifications` on grant. No-ops if the user
    /// has already answered, regardless of allow/deny.
    static func requestPushPermissionIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        } catch {
            print("[apns] permission request failed:", error)
        }
    }
}
