//
//  ModerationService.swift
//  YGTeeV
//
//  Minimum UGC-moderation surface required by Apple Guideline 1.2 for
//  v1 submission:
//
//    1. Block a user — adds their `user_id` to a per-device set kept in
//       UserDefaults. Chat threads + feeds + event media call
//       `isBlocked(_:)` and filter out anything authored by a blocked
//       user. The block list is namespaced by the signed-in user, so
//       multiple accounts on the same device don't share blocks.
//
//    2. Report content — opens a system mail composer pre-addressed to
//       support@ygteev.com with the content identifier in the subject.
//       The backend will replace this with a `report_content` Edge
//       Function once the moderation queue is wired up; for now the
//       in-app affordance is what Apple needs to see at review.
//

import Foundation
import SwiftUI
import UIKit

@MainActor
@Observable
final class ModerationService {
    static let shared = ModerationService()

    /// In-memory mirror of the per-user "blocked authors" set so views
    /// observe changes without re-reading UserDefaults each render.
    private(set) var blockedUserIds: Set<UUID> = []

    private init() {
        reload()
    }

    // MARK: - Blocking

    func isBlocked(_ userId: UUID) -> Bool {
        blockedUserIds.contains(userId)
    }

    func block(_ userId: UUID) {
        guard !blockedUserIds.contains(userId) else { return }
        blockedUserIds.insert(userId)
        persist()
    }

    func unblock(_ userId: UUID) {
        guard blockedUserIds.contains(userId) else { return }
        blockedUserIds.remove(userId)
        persist()
    }

    /// Re-read the persisted block list. Call after sign-in / sign-out
    /// so the set follows the active account.
    func reload() {
        let key = Self.storageKey()
        let stored = UserDefaults.standard.array(forKey: key) as? [String] ?? []
        blockedUserIds = Set(stored.compactMap(UUID.init(uuidString:)))
    }

    private func persist() {
        let key = Self.storageKey()
        UserDefaults.standard.set(blockedUserIds.map { $0.uuidString.lowercased() }, forKey: key)
    }

    private static func storageKey() -> String {
        let uid = SupabaseManager.shared.currentUser?.id ?? "anon"
        return "moderation.blocked.\(uid)"
    }

    // MARK: - Reporting

    /// Categories surfaced in the report sheet. Aligned with Apple's
    /// suggested taxonomy + our own internal policy.
    enum ReportReason: String, CaseIterable, Identifiable {
        case spam              = "Spam or scam"
        case harassment        = "Harassment or bullying"
        case hateSpeech        = "Hate speech"
        case sexualContent     = "Sexual content"
        case violence          = "Violence or threats"
        case selfHarm          = "Self-harm content"
        case childSafety       = "Child safety concern"
        case other             = "Something else"

        var id: String { rawValue }
    }

    enum ReportTarget {
        case message(id: UUID, authorId: UUID?, threadId: UUID)
        case feedPost(id: UUID, authorId: UUID?)
        case eventMedia(id: UUID, eventId: UUID)
        case profile(userId: UUID)

        var subjectSuffix: String {
            switch self {
            case .message(let id, _, _):  return "message:\(id.uuidString.lowercased())"
            case .feedPost(let id, _):    return "post:\(id.uuidString.lowercased())"
            case .eventMedia(let id, _):  return "media:\(id.uuidString.lowercased())"
            case .profile(let id):        return "profile:\(id.uuidString.lowercased())"
            }
        }
    }

    /// Build a mailto: URL with the report details URL-encoded into the
    /// subject + body. The mail composer presented by
    /// `UIApplication.shared.open` lets the user attach screenshots or
    /// add detail before sending — that's the audit trail until the
    /// `report_content` Edge Function lands.
    func reportMailtoURL(reason: ReportReason, details: String, target: ReportTarget) -> URL? {
        let subject = "Report (\(reason.rawValue)) — \(target.subjectSuffix)"
        var body = """
        Reason: \(reason.rawValue)
        Target: \(target.subjectSuffix)
        Reporter: \(SupabaseManager.shared.currentUser?.id ?? "anonymous")

        Details:
        \(details.isEmpty ? "(none)" : details)
        """
        body.append("\n\n— Sent from YGTeeV iOS")

        var comps = URLComponents()
        comps.scheme = "mailto"
        comps.path = "support@ygteev.com"
        comps.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body",    value: body),
        ]
        return comps.url
    }
}
