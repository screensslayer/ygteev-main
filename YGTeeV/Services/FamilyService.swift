//
//  FamilyService.swift
//  YGTeeV
//
//  Wraps the 5 family RPCs (list/start/remove/create_invite/accept_invite).
//  Holds the user's families in an @Observable singleton so any view that
//  needs to react to membership changes can just observe it.
//

import Foundation
import Supabase

@MainActor
@Observable
final class FamilyService {
    static let shared = FamilyService()
    private let client = SupabaseManager.shared.client

    /// All families the caller is a member of. For most users this is
    /// 0 or 1 row; rare multi-family parents see more.
    var myFamilies: [Family] = []

    /// In-flight pairing code created from this device (if any) so the
    /// add-member sheet can resume the countdown when reopened.
    var pendingInvite: FamilyInviteResult?

    /// Open invites addressed to the current user. Drives the
    /// "Jacob wants to add you…" banner.
    var pendingInvitesForMe: [PendingFamilyInvite] = []

    /// Invite IDs the user has client-side dismissed this session — kept
    /// in-memory only so the next `list_my_pending_family_invites` refresh
    /// (or app relaunch) brings them back if still active server-side.
    private var locallyDismissedInviteIds: Set<UUID> = []

    private init() {}

    // MARK: - Read

    func loadMyFamilies() async {
        do {
            let rows: [Family] = try await client
                .rpc("list_my_families")
                .execute()
                .value
            self.myFamilies = rows
        } catch {
            print("[FamilyService] list_my_families failed:", error)
        }
    }

    // MARK: - Mutations

    /// Create a new family with the given name. The caller becomes the
    /// parent. Returns the new family_id (the RPC returns a uuid).
    @discardableResult
    func startFamily(name: String = "My Family") async throws -> UUID {
        struct Params: Encodable { let _name: String }
        let id: UUID = try await client
            .rpc("start_family", params: Params(_name: name))
            .execute()
            .value
        await loadMyFamilies()
        return id
    }

    /// Remove the family. Children's underlying accounts stay intact —
    /// they're just unlinked from this family.
    func removeFamily(familyId: UUID) async throws {
        struct Params: Encodable { let _family_id: String }
        _ = try await client
            .rpc("remove_family",
                 params: Params(_family_id: familyId.uuidString.lowercased()))
            .execute()
        await loadMyFamilies()
    }

    /// Generate a 4-digit pairing code (and optionally pre-target an
    /// existing user via `invitedUserId`, e.g. from a QR scan).
    func createInvite(familyId: UUID, invitedUserId: UUID? = nil) async throws -> FamilyInviteResult {
        struct Params: Encodable {
            let _family_id: String
            let _invited_user_id: String?
        }
        let result: FamilyInviteResult = try await client
            .rpc("create_family_invite",
                 params: Params(
                    _family_id: familyId.uuidString.lowercased(),
                    _invited_user_id: invitedUserId?.uuidString.lowercased()))
            .execute()
            .value
        self.pendingInvite = result
        return result
    }

    /// Scan-based add: the parent scans the target user's profile QR
    /// and we INSERT directly into `family_members` (role='child') via
    /// the `family_add_via_scan` RPC. No pairing-code typing, no
    /// pending-invite row — the new member shows up in the family
    /// roster the moment the RPC returns.
    ///
    /// Params are sent as lowercase UUID strings to match the rest of
    /// the codebase (the Swift SDK's default UUID encoding is uppercase
    /// which some Postgres comparisons treat as a different value).
    /// The RPC's return shape isn't decoded — some deploys return void,
    /// others return a uuid — both are acceptable success states.
    func addViaScan(familyId: UUID, scannedUserId: UUID) async throws {
        struct Params: Encodable {
            let _family_id: String
            let _scanned_user_id: String
        }
        print("[FamilyService] addViaScan family=\(familyId.uuidString.lowercased()) scanned=\(scannedUserId.uuidString.lowercased())")
        do {
            _ = try await client
                .rpc("family_add_via_scan",
                     params: Params(
                        _family_id: familyId.uuidString.lowercased(),
                        _scanned_user_id: scannedUserId.uuidString.lowercased()))
                .execute()
            print("[FamilyService] addViaScan OK")
        } catch {
            print("[FamilyService] addViaScan failed:", error)
            throw error
        }
        // Refresh the local roster so the parent sees the new member
        // without an extra pull-to-refresh.
        await loadMyFamilies()
    }

    /// Redeem a pairing code from the invited side. Returns the family_id
    /// the caller has now been linked into.
    @discardableResult
    func acceptInvite(code: String) async throws -> UUID {
        struct Params: Encodable { let _code: String }
        let id: UUID = try await client
            .rpc("accept_family_invite",
                 params: Params(_code: code.trimmingCharacters(in: .whitespacesAndNewlines)))
            .execute()
            .value
        await loadMyFamilies()
        return id
    }

    // MARK: - Pending invites (invited side)

    /// Refresh the list of invites addressed to the current user.
    func loadPendingInvites() async {
        do {
            let rows: [PendingFamilyInvite] = try await client
                .rpc("list_my_pending_family_invites")
                .execute()
                .value
            self.pendingInvitesForMe = rows
        } catch {
            print("[FamilyService] list_my_pending_family_invites failed:", error)
        }
    }

    /// Latest non-dismissed invite, if any.
    var topPendingInvite: PendingFamilyInvite? {
        pendingInvitesForMe
            .filter { !locallyDismissedInviteIds.contains($0.inviteId) }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    /// Dismiss a banner client-side (no server call). The invite stays on
    /// the server and will reappear on the next foreground refresh until
    /// it expires (10 min) or the user accepts it. A future
    /// `decline_family_invite` RPC can replace this with a real decline.
    func dismissInviteLocally(_ inviteId: UUID) {
        locallyDismissedInviteIds.insert(inviteId)
    }

    /// Accept-by-invite-id wrapper around the existing code-based RPC.
    /// Looks up the code from the local list before calling.
    @discardableResult
    func acceptPendingInvite(_ invite: PendingFamilyInvite) async throws -> UUID {
        let familyId = try await acceptInvite(code: invite.pairingCode)
        pendingInvitesForMe.removeAll { $0.inviteId == invite.inviteId }
        return familyId
    }

    // MARK: - Under-13 child account

    /// Calls the `create-child-account` Edge Function. Returns the
    /// pairing token + numeric fallback the kid will use to sign in.
    /// `dateOfBirth` must be < 13 years ago (server enforces).
    func createChildAccount(
        familyId: UUID,
        firstName: String,
        lastName: String?,
        dateOfBirth: Date,
        gradeYear: Int?,
        avatarURL: String?
    ) async throws -> CreateChildResult {
        struct Body: Encodable {
            let family_id: String
            let first_name: String
            let last_name: String?
            let date_of_birth: String
            let grade_year: Int?
            let avatar_url: String?
        }
        let body = Body(
            family_id: familyId.uuidString.lowercased(),
            first_name: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            last_name: (lastName?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 },
            date_of_birth: Self.isoDateOnly.string(from: dateOfBirth),
            grade_year: gradeYear,
            avatar_url: avatarURL
        )
        let result: CreateChildResult = try await client
            .functions.invoke("create-child-account",
                              options: FunctionInvokeOptions(body: body))
        // Refresh families so the new child appears in the parent's roster.
        await loadMyFamilies()
        return result
    }

    /// Calls the `redeem-child-pairing-token` Edge Function. Pass either
    /// `token` (scanned from the QR) or `numericCode` (typed fallback).
    /// On success, installs the new session into `auth.setSession(...)`
    /// and refreshes `SupabaseManager.currentUser`.
    func redeemChildPairing(token: String? = nil, numericCode: String? = nil) async throws {
        struct Body: Encodable {
            let token: String?
            let numeric_code: String?
        }
        let body = Body(
            token: token?.trimmingCharacters(in: .whitespacesAndNewlines),
            numeric_code: numericCode?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let result: RedeemChildPairingResult = try await client
            .functions.invoke("redeem-child-pairing-token",
                              options: FunctionInvokeOptions(body: body))
        _ = try await client.auth.setSession(
            accessToken: result.accessToken,
            refreshToken: result.refreshToken
        )
        // Pull the kid's profile into the @Observable currentUser.
        await SupabaseManager.shared.checkSession()
    }

    private static let isoDateOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    // MARK: - Helpers

    var hasFamily: Bool { !myFamilies.isEmpty }
    var primaryFamily: Family? { myFamilies.first }
}
