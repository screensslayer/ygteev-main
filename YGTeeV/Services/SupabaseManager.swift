//
//  SupabaseManager.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/8/26.
//

import Foundation
import Supabase

@Observable
class SupabaseManager {
    static let shared = SupabaseManager()

    // Expose client for EntitlementsService
    internal var client: SupabaseClient
    var currentUser: User?
    var isAuthenticated: Bool {
        currentUser != nil
    }
    /// True from app launch until the very first `checkSession()` call
    /// finishes — successful or not. Drives the splash-screen gate in
    /// `RootView` so the user doesn't briefly see Onboarding flash before
    /// the restored session swaps in MainTabView.
    var isCheckingSession: Bool = true

    private static let supabaseDecoder: JSONDecoder = {
        let d = JSONDecoder()
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let s = try c.decode(String.self)
            if let date = withFractional.date(from: s) { return date }
            if let date = plain.date(from: s) { return date }
            throw DecodingError.dataCorruptedError(
                in: c, debugDescription: "Unparseable date: \(s)")
        }
        return d
    }()
    
    private static let supabaseEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    
    private init() {
        // Supabase URL + anon key are injected into Info.plist at build time
        // from the active xcconfig (Prod.xcconfig / Staging.xcconfig). Reading
        // them via Bundle.main means the same binary build script produces
        // either build by just switching scheme — no code change needed.
        let info = Bundle.main.infoDictionary
        let urlString = info?["SUPABASE_URL"] as? String ?? ""
        let supabaseKey = info?["SUPABASE_ANON_KEY"] as? String ?? ""
        guard let supabaseURL = URL(string: urlString), !supabaseKey.isEmpty else {
            fatalError("SUPABASE_URL / SUPABASE_ANON_KEY missing or malformed in Info.plist — check the active xcconfig.")
        }
        #if DEBUG
        print("[SupabaseManager] connected to \(supabaseURL.absoluteString)")
        #endif

        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey,
            options: .init(
                db: .init(
                    encoder: Self.supabaseEncoder,
                    decoder: Self.supabaseDecoder
                ),
                auth: .init(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )

        // Check for existing session on init
        Task {
            await checkSession()
        }
    }

    // MARK: - Authentication

    /// Sign up a new user with email and password
    func signUp(email: String, password: String) async throws -> User {
        // Create auth user
        let authResponse = try await client.auth.signUp(
            email: email,
            password: password
        )

        guard let session = authResponse.session else {
            throw AuthError.noSession
        }

        // Fetch the user profile created by the database trigger
        // Retry a few times in case the trigger hasn't completed yet
        var user: User?
        var lastError: Error?
        
        for attempt in 1...5 {
            do {
                user = try await fetchUserProfile(userId: session.user.id.uuidString)
                break
            } catch {
                lastError = error
                if attempt < 5 {
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                }
            }
        }
        
        guard let fetchedUser = user else {
            throw lastError ?? AuthError.noSession
        }

        self.currentUser = fetchedUser

        // Hand the RC SDK our auth.users.id (UUID) so its app_user_id
        // matches what our webhook expects — otherwise apple_subscriptions
        // rows get dropped server-side.
        await PurchasesManager.shared.logIn(userId: fetchedUser.id)

        // After successful sign-up: heartbeat then refresh entitlements
        await EntitlementsService.shared.heartbeat()
        await EntitlementsService.shared.refresh()

        return fetchedUser
    }

    /// Sign in existing user with email and password
    func signIn(email: String, password: String) async throws -> User {
        let session = try await client.auth.signIn(
            email: email,
            password: password
        )

        // Fetch user profile from database
        let user = try await fetchUserProfile(userId: session.user.id.uuidString)

        self.currentUser = user

        await PurchasesManager.shared.logIn(userId: user.id)

        // After successful sign-in: heartbeat then refresh entitlements
        await EntitlementsService.shared.heartbeat()
        await EntitlementsService.shared.refresh()

        return user
    }

    /// Sign in with Google
    func signInWithGoogle() async throws {
        try await client.auth.signInWithOAuth(provider: .google)
    }

    /// Sign in with Apple
    func signInWithApple() async throws {
        try await client.auth.signInWithOAuth(provider: .apple)
    }

    /// Sign out current user
    func signOut() async throws {
        try await client.auth.signOut()
        self.currentUser = nil

        // Detach RC from this user so subsequent purchases on this device
        // (e.g. a second account logging in) don't get associated with
        // the wrong app_user_id.
        await PurchasesManager.shared.logOut()

        // Reset services on sign-out
        await EntitlementsService.shared.reset()
        ChatService.shared.reset()
        PlansService.shared.reset()
        LeaderService.shared.reset()
    }

    /// Check for existing session
    func checkSession() async {
        // Always flip the flag at the end so the splash gate releases
        // whether session restore succeeded or failed.
        defer { self.isCheckingSession = false }
        do {
            let session = try await client.auth.session
            let user = try await fetchUserProfile(userId: session.user.id.uuidString)
            self.currentUser = user

            await PurchasesManager.shared.logIn(userId: user.id)

            // After auth restore: heartbeat then refresh entitlements
            await EntitlementsService.shared.heartbeat()
            await EntitlementsService.shared.refresh()
        } catch {
            self.currentUser = nil
        }
    }

    /// Re-pulls the signed-in user's profile from `profiles` and
    /// replaces `currentUser`. Safe to call after any XP / water /
    /// streak-mutating RPC — the optimistic local patch handles the
    /// instant UI tick-up, this call reconciles drift (multi-device,
    /// milestone grants, anything we didn't model in the response).
    @discardableResult
    func refreshCurrentUser() async throws -> User {
        guard let cur = currentUser else { throw AuthError.notAuthenticated }
        let fresh = try await fetchUserProfile(userId: cur.id)
        await MainActor.run { self.currentUser = fresh }
        return fresh
    }

    // MARK: - Database Operations

    /// Fetch user profile from database
    private func fetchUserProfile(userId: String) async throws -> User {
        do {
            let response: User = try await client
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            return response
        } catch {
            print("❌ Error fetching user profile for userId: \(userId)")
            print("Error details: \(error)")
            
            // Check if this is the "no rows" error
            if error.localizedDescription.contains("single") || error.localizedDescription.contains("JSON") {
                throw AuthError.profileNotFound
            }
            throw error
        }
    }

    // MARK: - Profile mutations

    /// Update display name + bio + avatar URL on the caller's profile. Pass
    /// `nil` for any field you want to leave unchanged. Refreshes
    /// `currentUser` on success so observers re-render.
    @discardableResult
    func updateProfileBasics(displayName: String? = nil,
                             bio: String? = nil,
                             avatarUrl: String? = nil) async throws -> User {
        guard let currentUser else { throw AuthError.notAuthenticated }

        // Build the PATCH body as an explicit JSON object so we have full
        // control over the wire format. Earlier struct-based approaches were
        // getting serialized into something PostgREST didn't recognize as a
        // column-update set (only updated_at would change on the server).
        // Using AnyJSON guarantees the body is a flat key→value object.
        var patch: [String: AnyJSON] = [:]
        if let displayName {
            patch["display_name"] = .string(displayName)
        }
        if let bio {
            patch["bio"] = .string(bio)
        }
        if let avatarUrl {
            patch["avatar_url"] = .string(avatarUrl)
        }

        guard !patch.isEmpty else {
            // Nothing to write — bail before round-tripping.
            return currentUser
        }

        print("[SupabaseManager] updateProfileBasics PATCH:", patch.keys.sorted())

        // .select().single() forces PostgREST to return the updated row,
        // which both validates the write and gives us decode-able feedback
        // if the column-update path silently no-ops again.
        let updated: User = try await client
            .from("profiles")
            .update(patch)
            .eq("id", value: currentUser.id)
            .select()
            .single()
            .execute()
            .value

        print("[SupabaseManager] updateProfileBasics returned: name=\(updated.displayName ?? "<nil>") bio=\(updated.bio ?? "<nil>") avatar=\(updated.avatarUrl ?? "<nil>")")

        self.currentUser = updated
        return updated
    }

    /// Write the onboarding-collected profile fields (display_name,
    /// grade_year, date_of_birth) to the caller's row. Pass `nil` for any
    /// field that should be left untouched. We only have a birth *year*
    /// from onboarding — convert it to a `YYYY-06-01` ISO date so the
    /// server-side COPPA check has something to compare against.
    @discardableResult
    func updateProfile(displayName: String? = nil,
                       gradeYear: Int? = nil,
                       dateOfBirth: Date? = nil) async throws -> User {
        guard let currentUser else { throw AuthError.notAuthenticated }

        var patch: [String: AnyJSON] = [:]
        if let displayName, !displayName.isEmpty {
            patch["display_name"] = .string(displayName)
        }
        if let gradeYear {
            patch["grade_year"] = .integer(gradeYear)
        }
        if let dateOfBirth {
            let df = ISO8601DateFormatter()
            df.formatOptions = [.withFullDate]
            patch["date_of_birth"] = .string(df.string(from: dateOfBirth))
        }

        guard !patch.isEmpty else { return currentUser }

        print("[SupabaseManager] updateProfile PATCH keys:", patch.keys.sorted(),
              "user:", currentUser.id)
        let updated: User = try await client
            .from("profiles")
            .update(patch)
            .eq("id", value: currentUser.id)
            .select()
            .single()
            .execute()
            .value
        print("[SupabaseManager] updateProfile OK: name=\(updated.displayName ?? "<nil>")")

        self.currentUser = updated
        return updated
    }

    /// Upload an image to the `avatars` storage bucket under
    /// `<user_id>/avatar-<timestamp>.<ext>` and return the public URL.
    /// Storage RLS already allows self-upload to that path prefix.
    func uploadAvatar(imageData: Data, contentType: String = "image/jpeg") async throws -> String {
        guard let currentUser else { throw AuthError.notAuthenticated }

        // Lowercase the user-id segment of the path so it matches what
        // `auth.uid()::text` returns server-side. PostgREST gives us a
        // lowercase UUID via `currentUser.id`, but be defensive in case
        // anything upstream uppercased it.
        let userIdSegment = currentUser.id.lowercased()
        let filename = "avatar-\(Int(Date().timeIntervalSince1970)).jpg"
        let path = "\(userIdSegment)/\(filename)"

        // --- Diagnostics (printed via NSLog so they aren't filtered out) --
        let headerBytes = imageData.prefix(4).map { String(format: "%02X", $0) }.joined(separator: " ")
        let isJPEGMagic = imageData.starts(with: [0xFF, 0xD8, 0xFF])
        NSLog("[uploadAvatar] path=%@ contentType=%@ size=%dB header=%@ jpeg=%@",
              path, contentType, imageData.count, headerBytes, isJPEGMagic ? "true" : "false")
        print("[uploadAvatar] path=\(path) contentType=\(contentType) size=\(imageData.count)B header=\(headerBytes) jpeg=\(isJPEGMagic)")
        // ------------------------------------------------------------------

        // Match EventsService.uploadEventPhoto exactly: bucket reference,
        // FileOptions shape, no upsert. Anything we add beyond this has been
        // associated with 400s, so keep it byte-identical.
        do {
            try await client.storage
                .from("avatars")
                .upload(path, data: imageData, options: .init(contentType: contentType))
        } catch {
            // The Supabase Swift SDK embeds the server's JSON response in the
            // error's `localizedDescription` and/or the underlying response
            // body. Dump every angle so the actual reason isn't hidden.
            let reflected = String(reflecting: error)
            NSLog("[uploadAvatar] ❌ storage error: %@", reflected)
            print("[uploadAvatar] ❌ storage error:", error)
            print("[uploadAvatar] ❌ localizedDescription:", error.localizedDescription)
            print("[uploadAvatar] ❌ debugDescription:", reflected)

            // Try to surface the response body if the SDK wrapped a URLResponse.
            let mirror = Mirror(reflecting: error)
            for child in mirror.children {
                print("[uploadAvatar] ❌ child:", child.label ?? "<nil>", "=>", child.value)
            }
            throw error
        }

        let publicURL = try client.storage
            .from("avatars")
            .getPublicURL(path: path)

        return publicURL.absoluteString
    }

    /// Send a password-reset email to the current user's address. Avoids
    /// re-auth friction inside the app; user finishes the change in their
    /// inbox.
    func sendPasswordResetEmail() async throws {
        guard let email = currentUser?.email, !email.isEmpty else {
            throw AuthError.notAuthenticated
        }
        try await client.auth.resetPasswordForEmail(email)
    }

    /// Start an email-change request. Supabase emails the new address a
    /// confirmation link; the auth.users.email row flips once the link is
    /// clicked.
    func requestEmailChange(to newEmail: String) async throws {
        let attributes = UserAttributes(email: newEmail)
        _ = try await client.auth.update(user: attributes)
    }

    /// Soft-delete the calling user's profile via the server RPC, then sign
    /// out. Hard deletion of the auth.users row is an admin-only follow-up.
    func requestAccountDeletion() async throws {
        try await client.rpc("request_account_deletion").execute()
        try await signOut()
    }

    /// Toggle whether the caller appears on the public youth-group map.
    @discardableResult
    func setMapVisibility(_ visible: Bool) async throws -> Bool {
        struct Params: Encodable { let _visible: Bool }
        let newValue: Bool = try await client
            .rpc("set_map_visibility", params: Params(_visible: visible))
            .execute()
            .value
        return newValue
    }
}

// MARK: - Auth Errors
enum AuthError: LocalizedError {
    case noSession
    case notAuthenticated
    case unauthorized
    case invalidCredentials
    case profileNotFound

    var errorDescription: String? {
        switch self {
        case .noSession:
            return "No session found"
        case .notAuthenticated:
            return "User not authenticated"
        case .unauthorized:
            return "Unauthorized action"
        case .invalidCredentials:
            return "Invalid email or password"
        case .profileNotFound:
            return "User profile not found in database. Please contact support or try signing up again."
        }
    }
}
