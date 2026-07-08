//
//  OnbAuthChoiceView.swift
//  YGTeeV
//
//  M11 — Sign up / sign in via Apple, Google, or email+password.
//  Deferred to this point on purpose (Duolingo pattern): only ask
//  for credentials after the user has something worth saving —
//  a group, a name, a color on the way.
//
//  Provider flow parity with the legacy `OnbCreateAccountView` in
//  `OnbFinalViews.swift` — same SupabaseManager methods, same
//  nonce plumbing, same cancellation semantics. What's new here is
//  the post-auth pipeline, which folds in the reimagined-flow
//  extras that the legacy screen doesn't need:
//
//    signUp (or signIn)
//      └── (signUp only) OnboardingService.updateProfileBasics
//      └── (signUp only) SupabaseManager.refreshCurrentUser
//      └── (signUp only, if group picked) OnboardingService.joinGroup
//      └── copy currentUser.splatColor → state.revealedSplatColor
//      └── advance()
//
//  Everything below the signUp/signIn call is best-effort — the
//  user is authenticated at that point, and we don't want a
//  profile-patch hiccup or a join-request failure to strand them
//  on the auth screen. Errors from those steps are logged, not
//  surfaced. Auth failures themselves DO surface as a red banner.
//
//  Sign-IN path (for returning users): we skip updateProfileBasics
//  and joinGroup — those would overwrite fields the user already
//  set. We still copy splatColor + advance so the color reveal
//  renders correctly.
//

import SwiftUI
import AuthenticationServices
import CryptoKit

struct OnbAuthChoiceView: View {
    @Bindable var state: ReimaginedOnboardingState
    let service: OnboardingService
    let advance: () -> Void

    // MARK: - Form state
    @State private var isLogin = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @FocusState private var focusedField: Field?

    private enum Field { case email, password, confirmPassword }

    // MARK: - Async / error state
    @State private var isLoading = false
    @State private var errorText: String?

    /// Raw (un-hashed) nonce held between `configureAppleRequest` and
    /// `handleAppleCompletion`. Apple gets the SHA256 baked into the
    /// ID token's nonce claim; Supabase needs the raw string to
    /// verify.
    @State private var currentAppleNonce: String?

    private var trimmedName: String {
        state.displayName.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 50)

                trustPills
                    .padding(.horizontal, 24)
                    .padding(.top, 14)

                if let errorText {
                    Text(errorText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 22)
                        .padding(.top, 14)
                }

                providerButtons
                    .padding(.horizontal, 22)
                    .padding(.top, 22)

                orDivider
                    .padding(.horizontal, 22)
                    .padding(.top, 18)

                emailForm
                    .padding(.horizontal, 22)
                    .padding(.top, 12)

                primaryEmailButton
                    .padding(.horizontal, 22)
                    .padding(.top, 14)

                modeToggle
                    .padding(.top, 12)

                termsFooter
                    .padding(.top, 20)
                    .padding(.bottom, 30)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(YGColors.paper)
        .disabled(isLoading)
        .overlay {
            if isLoading {
                loadingOverlay
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isLogin ? "COMMITMENT" : "COMMITMENT")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(YGColors.violet)

            Text(isLogin
                 ? "Welcome back."
                 : "Lock it in, \(trimmedName.isEmpty ? "friend" : trimmedName).")
                .font(.lilitaOne(size: 30))
                .foregroundStyle(YGColors.ink)

            Text(isLogin
                 ? "Sign back in to pick up right where you left off."
                 : "Save your account so your group, XP, and streak stay yours — even on a new phone.")
                .font(.system(size: 14))
                .foregroundStyle(YGColors.ink.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Trust pills

    private var trustPills: some View {
        HStack(spacing: 8) {
            trustPill(emoji: "☁️", label: "Synced")
            trustPill(emoji: "🛡️", label: "Private")
            trustPill(emoji: "✨", label: "Free")
            Spacer()
        }
    }

    private func trustPill(emoji: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(emoji).font(.system(size: 13))
            Text(label)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(YGColors.ink)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(.white)
        .overlay(
            Capsule().strokeBorder(.black.opacity(0.05), lineWidth: 0.5)
        )
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    // MARK: - Provider buttons

    private var providerButtons: some View {
        VStack(spacing: 10) {
            // Apple first per iOS convention + Apple Guideline 4.8
            // (must be at least equally prominent to other providers).
            SignInWithAppleButton(
                isLogin ? .signIn : .signUp,
                onRequest: configureAppleRequest,
                onCompletion: handleAppleCompletion
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .clipShape(Capsule())

            GoogleSignInButton(action: handleGoogleSignIn)
        }
    }

    // MARK: - "OR" divider

    private var orDivider: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(YGColors.ink.opacity(0.12))
                .frame(height: 0.5)
            Text("OR")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(YGColors.ink.opacity(0.45))
            Rectangle()
                .fill(YGColors.ink.opacity(0.12))
                .frame(height: 0.5)
        }
    }

    // MARK: - Email form

    private var emailForm: some View {
        VStack(spacing: 10) {
            emailField
            passwordField
            if !isLogin {
                confirmPasswordField
            }
        }
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("EMAIL")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(YGColors.ink.opacity(0.5))
            TextField("you@example.com", text: $email)
                .font(.system(size: 16, weight: .semibold))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    focusedField == .email ? YGColors.violet.opacity(0.5) : .black.opacity(0.06),
                    lineWidth: focusedField == .email ? 1.5 : 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PASSWORD")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(YGColors.ink.opacity(0.5))
            SecureField(isLogin ? "Your password" : "At least 6 characters", text: $password)
                .font(.system(size: 16, weight: .semibold))
                .textContentType(isLogin ? .password : .newPassword)
                .focused($focusedField, equals: .password)
                .submitLabel(isLogin ? .go : .next)
                .onSubmit {
                    if isLogin {
                        Task { await handleEmailAuth() }
                    } else {
                        focusedField = .confirmPassword
                    }
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    focusedField == .password ? YGColors.violet.opacity(0.5) : .black.opacity(0.06),
                    lineWidth: focusedField == .password ? 1.5 : 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var confirmPasswordField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("CONFIRM PASSWORD")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(YGColors.ink.opacity(0.5))
            SecureField("Type it again", text: $confirmPassword)
                .font(.system(size: 16, weight: .semibold))
                .textContentType(.newPassword)
                .focused($focusedField, equals: .confirmPassword)
                .submitLabel(.go)
                .onSubmit { Task { await handleEmailAuth() } }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    focusedField == .confirmPassword ? YGColors.violet.opacity(0.5) : .black.opacity(0.06),
                    lineWidth: focusedField == .confirmPassword ? 1.5 : 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Primary email button

    private var primaryEmailButton: some View {
        Button {
            Task { await handleEmailAuth() }
        } label: {
            Text(isLogin ? "Sign in →" : "Create account →")
                .font(.lilitaOne(size: 18))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [YGColors.violet, YGColors.violetDeep],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(Capsule())
                .shadow(color: YGColors.violet.opacity(0.4), radius: 20, y: 8)
        }
    }

    // MARK: - Mode toggle

    private var modeToggle: some View {
        HStack(spacing: 4) {
            Text(isLogin ? "New here?" : "Already have an account?")
                .font(.system(size: 13))
                .foregroundStyle(YGColors.ink.opacity(0.55))
            Button {
                errorText = nil
                withAnimation(.snappy) {
                    isLogin.toggle()
                }
            } label: {
                Text(isLogin ? "Create one" : "Sign in")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(YGColors.violet)
            }
        }
    }

    // MARK: - Terms footer

    private var termsFooter: some View {
        Text("By continuing you agree to our Terms & Privacy Policy.")
            .font(.system(size: 11))
            .foregroundStyle(YGColors.ink.opacity(0.45))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
    }

    // MARK: - Loading overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            ProgressView()
                .tint(.white)
                .scaleEffect(1.4)
                .padding(24)
                .background(Color.black.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Email/password auth

    private func handleEmailAuth() async {
        errorText = nil

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            errorText = "Enter your email to continue."
            return
        }
        guard !password.isEmpty else {
            errorText = "Enter a password."
            return
        }
        if !isLogin {
            guard password.count >= 6 else {
                errorText = "Password needs at least 6 characters."
                return
            }
            guard password == confirmPassword else {
                errorText = "Passwords don't match."
                return
            }
        }

        isLoading = true
        do {
            if isLogin {
                _ = try await SupabaseManager.shared.signIn(email: trimmedEmail, password: password)
                await finishSignIn(newUser: false)
            } else {
                _ = try await SupabaseManager.shared.signUp(email: trimmedEmail, password: password)
                await finishSignIn(newUser: true)
            }
        } catch {
            errorText = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Google

    private func handleGoogleSignIn() {
        Task {
            errorText = nil
            isLoading = true
            do {
                let cred = try await GoogleAuthService.shared.signIn()
                _ = try await SupabaseManager.shared.signInWithGoogleIdToken(
                    idToken: cred.idToken,
                    nonce: cred.rawNonce
                )
                await finishSignIn(newUser: !isLogin)
            } catch {
                // GoogleSignIn SDK uses domain "com.google.GIDSignIn" +
                // code -5 for a user-cancel; treat as a silent bail so
                // we don't yell at the user for backing out.
                let ns = error as NSError
                if ns.domain == "com.google.GIDSignIn" && ns.code == -5 {
                    isLoading = false
                    return
                }
                errorText = error.localizedDescription
                isLoading = false
            }
        }
    }

    // MARK: - Apple

    private func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonceString()
        currentAppleNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    private func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        errorText = nil
        switch result {
        case .failure(let error):
            // Cancellation is normal — quiet bail, no banner.
            if let authError = error as? ASAuthorizationError,
               authError.code == .canceled { return }
            errorText = error.localizedDescription

        case .success(let auth):
            guard
                let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let token = String(data: tokenData, encoding: .utf8),
                let rawNonce = currentAppleNonce
            else {
                errorText = "Couldn't read Apple credential."
                return
            }
            Task { await completeAppleSignIn(idToken: token, rawNonce: rawNonce) }
        }
    }

    private func completeAppleSignIn(idToken: String, rawNonce: String) async {
        isLoading = true
        do {
            _ = try await SupabaseManager.shared.signInWithAppleIdToken(
                idToken: idToken, nonce: rawNonce
            )
            await finishSignIn(newUser: !isLogin)
        } catch {
            errorText = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Post-auth pipeline
    //
    // Everything downstream of a successful sign-in. Only runs for
    // the sign-UP path — returning users skip the profile-patch +
    // group-join since those would clobber fields they've already
    // set. Both paths refresh currentUser so `splatColor` is fresh
    // for the color-reveal screen.

    private func finishSignIn(newUser: Bool) async {
        if newUser {
            // 1. Patch the profile row created by the signup trigger
            //    with the display name / grade / birth year the user
            //    entered upstream. Best-effort — auth already
            //    succeeded, so a network hiccup here shouldn't strand
            //    the user on this screen. They can edit these fields
            //    later from Settings.
            if let birth = state.birthYear {
                do {
                    try await service.updateProfileBasics(
                        displayName: trimmedName.isEmpty ? "friend" : trimmedName,
                        gradeYear: state.gradeYear,
                        birthYear: birth
                    )
                } catch {
                    print("[Onboarding] updateProfileBasics failed:", error)
                }
            }

            // 2. Refresh currentUser to hydrate the patched fields
            //    + `splat_color` (assigned by the signup trigger).
            //    Best-effort as above.
            _ = try? await SupabaseManager.shared.refreshCurrentUser()

            // 3. If the user picked a local youth group upstream,
            //    fire the join RPC. Default YGTeeV group is auto-
            //    joined by the trigger, so this only matters for
            //    real / discovered picks. Best-effort.
            if let group = state.selectedGroup {
                do {
                    try await service.joinGroup(group)
                } catch {
                    print("[Onboarding] joinGroup failed:", error)
                }
            }
        } else {
            // Returning-user path — just refresh so we have the
            // latest splat color on hand for the reveal screen.
            _ = try? await SupabaseManager.shared.refreshCurrentUser()
        }

        // Hydrate the reveal target from the profile. This is the
        // handoff into M12-M14 — the color the reveal screen paints
        // is whatever the server stamped on splat_color.
        if let color = SupabaseManager.shared.currentUser?.splatColor {
            state.revealedSplatColor = color
        }

        isLoading = false
        advance()
    }

    // MARK: - Nonce helpers (SIWA)
    //
    // Standard pattern from Apple's "Generating and validating
    // tokens" sample. The raw nonce stays on-device until we send
    // it to Supabase; the SHA256 hash is what Apple bakes into
    // the ID token's `nonce` claim.

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                precondition(status == errSecSuccess)
                return random
            }
            randoms.forEach { byte in
                if remaining == 0 { return }
                if byte < charset.count {
                    result.append(charset[Int(byte)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
