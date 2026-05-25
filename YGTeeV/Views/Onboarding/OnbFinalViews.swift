//
//  OnbFinalViews.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/7/26.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - Adult Required View (Under 13)
struct OnbAdultRequiredView: View {
    let onboardingState: OnboardingState
    @State private var showChildSignIn = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "2B8A3E"),
                    Color(hex: "1A5224"),
                    Color(hex: "0A0712")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    OnboardSkipButton(dark: true) {
                        onboardingState.skipToEnd()
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 60)
                }
                Spacer()
            }

            VStack(spacing: 0) {
                Spacer().frame(height: 130)

                VStack(spacing: 14) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: "B4FF3C"))
                            .frame(width: 6, height: 6)
                        Text("PARENT NEEDED")
                            .font(.system(size: 11, weight: .black))
                            .tracking(0.5)
                            .foregroundStyle(Color(hex: "B4FF3C"))
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(Color(hex: "B4FF3C").opacity(0.18))
                    .clipShape(Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(Color(hex: "B4FF3C").opacity(0.4), lineWidth: 0.5)
                    }

                    Text("You need a parent or\nguardian to make this\naccount.")
                        .font(.lilitaOne(size: 28))
                        .tracking(-1)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Have an adult set up their YGTeeV account first. Then come back here and scan their QR code to join their family.")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .frame(maxWidth: 320)
                        .padding(.top, 4)
                }

                Spacer()

                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.bottom, 36)

                Button {
                    showChildSignIn = true
                } label: {
                    Text("Scan a QR code")
                        .font(.lilitaOne(size: 16))
                        .tracking(-0.2)
                        .foregroundStyle(YGColors.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.3), radius: 12)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 36)
            }
            .padding(.horizontal, 22)
        }
        .fullScreenCover(isPresented: $showChildSignIn) {
            ChildSignInSheet {
                // Auth happens inside the sheet → SupabaseManager flips
                // currentUser → RootView swaps to MainTabView. Marking
                // the one-way completion flag too.
                onboardingState.hasCompletedOnboarding = true
            }
        }
    }
}

// MARK: - Step Row Component
struct StepRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "B4FF3C").opacity(0.2))
                    .overlay {
                        Circle()
                            .strokeBorder(Color(hex: "B4FF3C").opacity(0.5), lineWidth: 0.5)
                    }
                
                Text(number)
                    .font(.lilitaOne(size: 12))
                    .foregroundStyle(Color(hex: "B4FF3C"))
            }
            .frame(width: 26, height: 26)
            
            Text(text)
                .font(.lilitaOne(size: 14))
                .tracking(-0.1)
                .foregroundStyle(.white.opacity(0.92))
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - QR Code View
struct QRCodeView: View {
    let code: String
    
    var body: some View {
        ZStack {
            // Generate QR code
            if let qrImage = generateQRCode(from: code) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            } else {
                // Fallback placeholder
                Rectangle()
                    .fill(YGColors.ink)
            }
            
            // Center logo
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "6B2BFF"), YGColors.pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(.white, lineWidth: 2)
                    }
                    .shadow(color: .black.opacity(0.2), radius: 2)
                    .shadow(color: .black.opacity(0.2), radius: 4, y: -2)
                
                Text("YG")
                    .font(.lilitaOne(size: 13))
                    .tracking(-0.5)
                    .foregroundStyle(.white)
            }
            .frame(width: 38, height: 38)
        }
    }
    
    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.message = Data(string.utf8)
        filter.correctionLevel = "H"
        
        guard let outputImage = filter.outputImage else { return nil }
        
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Create Account View (Over 13)
struct OnbCreateAccountView: View {
    let onboardingState: OnboardingState
    @State private var isLogin = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @FocusState private var focusedField: Field?

    enum Field {
        case email, password, confirmPassword
    }

    init(onboardingState: OnboardingState) {
        self.onboardingState = onboardingState
        _isLogin = State(initialValue: onboardingState.startInLoginMode)
    }
    
    var body: some View {
        ZStack {
            // Background + tap-to-dismiss the keyboard whenever the
            // user taps any empty space outside a field.
            Color(hex: "FAF8FF")
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { focusedField = nil }

            // Skip button overlay (kept for legacy API even though
            // OnboardSkipButton renders empty now).
            VStack {
                HStack {
                    Spacer()
                    OnboardSkipButton(dark: false) {
                        onboardingState.skipToEnd()
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 60)
                }
                Spacer()
            }
            .allowsHitTesting(false)

            // Scrollable form. ScrollView smoothly scrolls the focused
            // field into view instead of the whole layout jumping on
            // every focus change. `scrollDismissesKeyboard(.interactively)`
            // lets the user drag down to close the keyboard.
            ScrollView {
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 80)

                // Logo
                Image("ygteev-logo-black")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140)
                    .padding(.bottom, 30)
                
                // Header
                VStack(alignment: .leading, spacing: 10) {
                    Text(isLogin ? "Welcome back" : "Create your account")
                        .font(.lilitaOne(size: 30))
                        .tracking(-1.1)
                        .foregroundStyle(YGColors.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                
                // Auth form
                VStack(spacing: 14) {
                        // Email field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("EMAIL")
                                .font(.system(size: 10.5, weight: .bold))
                                .tracking(0.4)
                                .foregroundStyle(YGColors.ink.opacity(0.55))
                                .padding(.leading, 4)
                            
                            TextField("you@example.com", text: $email)
                                // System font + no tracking on input —
                                // Lilita One is a display face that
                                // re-lays out per keystroke and feels
                                // janky. Labels stay lilitaOne; only
                                // typed text uses system.
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(YGColors.ink)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .password }
                                .focused($focusedField, equals: .email)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay {
                                    // Constant line width so focus changes
                                    // only swap color, not re-lay out.
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(
                                            focusedField == .email ? YGColors.violet : Color.black.opacity(0.05),
                                            lineWidth: 1
                                        )
                                }
                        }
                        
                        // Password field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PASSWORD")
                                .font(.system(size: 10.5, weight: .bold))
                                .tracking(0.4)
                                .foregroundStyle(YGColors.ink.opacity(0.55))
                                .padding(.leading, 4)
                            
                            SecureField("Enter your password", text: $password)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(YGColors.ink)
                                .textContentType(isLogin ? .password : .newPassword)
                                .submitLabel(isLogin ? .go : .next)
                                .onSubmit {
                                    if isLogin {
                                        Task { await handleEmailAuth() }
                                    } else {
                                        focusedField = .confirmPassword
                                    }
                                }
                                .focused($focusedField, equals: .password)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(
                                            focusedField == .password ? YGColors.violet : Color.black.opacity(0.05),
                                            lineWidth: 1
                                        )
                                }
                        }
                        
                        // Confirm Password field (only for signup)
                        if !isLogin {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("CONFIRM PASSWORD")
                                    .font(.system(size: 10.5, weight: .bold))
                                    .tracking(0.4)
                                    .foregroundStyle(YGColors.ink.opacity(0.55))
                                    .padding(.leading, 4)
                                
                                SecureField("Confirm your password", text: $confirmPassword)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(YGColors.ink)
                                    .textContentType(.newPassword)
                                    .submitLabel(.go)
                                    .onSubmit { Task { await handleEmailAuth() } }
                                    .focused($focusedField, equals: .confirmPassword)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14)
                                            .strokeBorder(
                                                focusedField == .confirmPassword ? YGColors.violet : Color.black.opacity(0.05),
                                                lineWidth: 1
                                            )
                                    }
                            }
                        }
                        
                        // Divider
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
                        .padding(.vertical, 8)
                        
                        // Social auth buttons
                        AuthButton(
                            icon: "apple.logo",
                            label: "Continue with Apple",
                            dark: true,
                            action: handleAppleSignIn
                        )

                        AuthButton(
                            icon: "g.circle.fill",
                            label: "Continue with Google",
                            dark: false,
                            action: handleGoogleSignIn
                        )
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 30)

                // Fixed gap instead of Spacer(): inside a ScrollView
                // Spacer doesn't expand, and the previous implicit
                // collapse was part of the keyboard-jump problem.
                Color.clear.frame(height: 40)

                // Continue button
                VStack(spacing: 14) {
                    OnboardCTAButton(
                        title: isLogin ? "Sign in →" : "Create account →",
                        dark: false
                    ) {
                        Task {
                            await handleEmailAuth()
                        }
                    }
                    
                    // Toggle between login/signup
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isLogin.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(isLogin ? "Don't have an account?" : "Already have an account?")
                                .font(.system(size: 13))
                                .foregroundStyle(YGColors.ink.opacity(0.6))
                            
                            Text(isLogin ? "Sign up" : "Sign in")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(YGColors.violet)
                        }
                    }
                    
                    if !isLogin {
                        Text("By continuing, you agree to our **Terms** and **Privacy Policy**.")
                            .font(.system(size: 11))
                            .foregroundStyle(YGColors.ink.opacity(0.45))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .alert("Authentication Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .disabled(isLoading)
    }

    // MARK: - Authentication Methods

    func handleEmailAuth() async {
        // Validate inputs
        guard !email.isEmpty else {
            errorMessage = "Please enter your email"
            showError = true
            return
        }

        guard !password.isEmpty else {
            errorMessage = "Please enter your password"
            showError = true
            return
        }

        if !isLogin && password != confirmPassword {
            errorMessage = "Passwords don't match"
            showError = true
            return
        }

        await MainActor.run {
            isLoading = true
        }

        do {
            if isLogin {
                _ = try await SupabaseManager.shared.signIn(email: email, password: password)
                // A returning user who can log in is onboarded by
                // definition. Flip the AppStorage flag so RootView routes
                // to MainTabView — on a fresh install the flag would
                // otherwise still be false and the user would be stuck on
                // the login form even though signIn succeeded.
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            } else {
                _ = try await SupabaseManager.shared.signUp(email: email, password: password)
                // Profile-write failures shouldn't block onboarding: the
                // user is already authenticated, and they can edit any
                // missing fields from Settings later. Surface the error
                // to the console so we can diagnose it.
                do {
                    try await persistOnboardingProfile()
                } catch {
                    print("[Onboarding] persistOnboardingProfile failed:", error)
                }
                await MainActor.run { onboardingState.nextStep() }
            }
            await MainActor.run { isLoading = false }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
                isLoading = false
            }
        }
    }

    func handleGoogleSignIn() {
        Task {
            isLoading = true
            do {
                try await SupabaseManager.shared.signInWithGoogle()
                if isLogin {
                    // OAuth user reached the login form — they have an
                    // account already. Mark onboarding complete so
                    // RootView routes to MainTabView.
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                } else {
                    do {
                        try await persistOnboardingProfile()
                    } catch {
                        print("[Onboarding] persistOnboardingProfile failed:", error)
                    }
                    await MainActor.run { onboardingState.nextStep() }
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }

    func handleAppleSignIn() {
        Task {
            isLoading = true
            do {
                try await SupabaseManager.shared.signInWithApple()
                if isLogin {
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                } else {
                    do {
                        try await persistOnboardingProfile()
                    } catch {
                        print("[Onboarding] persistOnboardingProfile failed:", error)
                    }
                    await MainActor.run { onboardingState.nextStep() }
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }

    /// Push the onboarding-collected display_name + grade_year +
    /// date_of_birth onto the freshly-created profile row. We only have
    /// a birth year from the user; June 1 of that year is a reasonable
    /// midpoint for the server-side under-13 check.
    private func persistOnboardingProfile() async throws {
        let displayName = onboardingState.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        var components = DateComponents()
        components.year = onboardingState.birthYear
        components.month = 6
        components.day = 1
        let dob = Calendar(identifier: .gregorian).date(from: components)

        print("[Onboarding] persisting profile: name=\(displayName) grade=\(String(describing: onboardingState.gradeLevel)) year=\(onboardingState.birthYear)")

        try await SupabaseManager.shared.updateProfile(
            displayName: displayName.isEmpty ? nil : displayName,
            gradeYear: onboardingState.gradeLevel,
            dateOfBirth: dob
        )
    }
}

// MARK: - Auth Button Component
struct AuthButton: View {
    let icon: String
    let label: String
    let dark: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: dark ? .medium : .regular))
                    .foregroundStyle(dark ? .white : YGColors.ink)
                    .frame(width: 22)
                
                Text(label)
                    .font(.lilitaOne(size: 15.5))
                    .tracking(-0.2)
                    .foregroundStyle(dark ? .white : YGColors.ink)
                    .frame(maxWidth: .infinity)
                
                Spacer()
                    .frame(width: 22)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(dark ? YGColors.ink : .white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        dark ? Color.clear : Color.black.opacity(0.08),
                        lineWidth: 0.5
                    )
            }
            .shadow(
                color: dark ? .black.opacity(0.18) : YGColors.ink.opacity(0.06),
                radius: 2
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Done View
struct OnbDoneView: View {
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Radial gradient
            RadialGradient(
                colors: [
                    Color(hex: "6B2BFF"),
                    Color(hex: "3D0FB8"),
                    Color(hex: "0A0712")
                ],
                center: .center,
                startRadius: 0,
                endRadius: 600
            )
            .ignoresSafeArea()
            
            VStack(spacing: 28) {
                // Big emoji circle
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "FFD60A"), Color(hex: "FF6B35")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color(hex: "FF6B35").opacity(0.5), radius: 30)
                        .shadow(color: .black.opacity(0.2), radius: 12, y: -6)
                    
                    Text("🌳")
                        .font(.system(size: 56))
                }
                .frame(width: 120, height: 120)
                
                VStack(spacing: 14) {
                    Text("You're all set.")
                        .font(.lilitaOne(size: 36))
                        .tracking(-1.3)
                        .foregroundStyle(.white)
                    
                    Text("Time to plant your first tree. Today's plan is waiting.")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .frame(maxWidth: 280)
                }
            }
            .padding(.horizontal, 24)
            
            // Enter button
            VStack {
                Spacer()
                
                Button {
                    onComplete()
                } label: {
                    Text("Enter the app →")
                        .font(.lilitaOne(size: 16))
                        .tracking(-0.2)
                        .foregroundStyle(YGColors.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.3), radius: 12)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
    }
}

#Preview("Adult Required") {
    OnbAdultRequiredView(onboardingState: OnboardingState())
}

#Preview("Create Account") {
    OnbCreateAccountView(onboardingState: OnboardingState())
}

#Preview("Done") {
    OnbDoneView(onComplete: {})
}
