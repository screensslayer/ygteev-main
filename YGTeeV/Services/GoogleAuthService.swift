//
//  GoogleAuthService.swift
//  YGTeeV
//
//  Thin wrapper around `GoogleSignIn-iOS` that hides the SDK's
//  view-controller-presenting plumbing from the SwiftUI views. Returns
//  an OIDC ID token + the raw nonce so the caller can pass both into
//  Supabase's `signInWithIdToken(credentials:)`.
//
//  Why both: Google bakes the SHA-256 hash of our nonce into the
//  `nonce` claim of the id_token. Supabase re-hashes whatever raw
//  nonce we send it and compares — mismatched (or missing) nonce =
//  "Passed nonce and nonce in id_token should either both exist or
//  not." We mint the nonce here so both sides line up.
//

import Foundation
import CryptoKit
import GoogleSignIn
import UIKit

@MainActor
final class GoogleAuthService {
    static let shared = GoogleAuthService()
    private init() {}

    /// Bundle returned by `signIn()`. Caller hands `idToken` + `rawNonce`
    /// to `SupabaseManager.signInWithGoogleIdToken(idToken:nonce:)`.
    struct Credential {
        let idToken: String
        let rawNonce: String
    }

    /// Presents the native Google sign-in sheet anchored to the
    /// topmost view controller and returns the Google-issued ID token
    /// plus the raw nonce we generated for this attempt. Throws on
    /// cancel or any other failure — caller distinguishes cancel from
    /// real errors via the NSError code (`com.google.GIDSignIn` / -5).
    func signIn() async throws -> Credential {
        guard
            let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
            let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController
        else {
            throw GoogleAuthError.noPresenter
        }

        // Walk to the topmost presented controller — without this the
        // sign-in sheet tries to mount on a controller that's already
        // hosting another modal and silently no-ops.
        var topmost: UIViewController = root
        while let presented = topmost.presentedViewController {
            topmost = presented
        }

        // Fresh nonce per attempt. Google receives the SHA-256 hash
        // (which lands in the id_token's `nonce` claim); Supabase
        // receives the raw value and hashes server-side to compare.
        let rawNonce = Self.randomNonce()
        let hashedNonce = Self.sha256(rawNonce)

        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: topmost,
            hint: nil,
            additionalScopes: nil,
            nonce: hashedNonce
        )
        guard let idToken = result.user.idToken?.tokenString else {
            throw GoogleAuthError.noIdToken
        }
        return Credential(idToken: idToken, rawNonce: rawNonce)
    }

    /// Clears the Google session so the next "Continue with Google" tap
    /// shows the account picker. Called from `SupabaseManager.signOut`.
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }

    // MARK: - Nonce helpers

    /// 32-byte URL-safe nonce. Same character set Apple's SIWA sample
    /// uses; modulo-mapping into the charset is safe because the bytes
    /// from SecRandomCopyBytes are uniformly distributed and the
    /// charset length (64) divides 256 evenly.
    private static func randomNonce(length: Int = 32) -> String {
        let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var random = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &random)
        return String(random.map { chars[Int($0) % chars.count] })
    }

    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

enum GoogleAuthError: Error, LocalizedError {
    case noPresenter
    case noIdToken

    var errorDescription: String? {
        switch self {
        case .noPresenter: return "Couldn't present Google sign-in."
        case .noIdToken:   return "Google didn't return an ID token."
        }
    }
}
