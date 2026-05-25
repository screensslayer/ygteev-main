//
//  AccountSettingsView.swift
//  YGTeeV
//
//  Account-level settings reachable from the Settings sheet. Universal to
//  every role; the Subscription/Billing row is role-aware (pastors → Stripe,
//  everyone else → Apple subscription management).
//
//  Backend touch points:
//    - SupabaseManager.requestEmailChange(to:)
//    - SupabaseManager.sendPasswordResetEmail()
//    - SupabaseManager.setMapVisibility(_:)
//    - SupabaseManager.requestAccountDeletion()
//

import SwiftUI

struct AccountSettingsView: View {
    /// True when the caller pastors at least one group (drives the
    /// Stripe-billing-portal vs App-Store-subscription row). Computed
    /// once at the call site so this view doesn't reach into the
    /// service singleton.
    let isPastor: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var supabase = SupabaseManager.shared

    // Notification prefs — local for now; APNS wiring is a separate epic.
    @AppStorage("notif.push.enabled")  private var pushEnabled  = true
    @AppStorage("notif.email.enabled") private var emailEnabled = true

    // Sheets / alerts
    @State private var showChangeEmail = false
    @State private var newEmail = ""
    @State private var showResetPasswordConfirmation = false
    @State private var showDeleteAccountAlert = false
    @State private var showDeletingProgress = false

    // Inline status messages
    @State private var infoMessage: String?
    @State private var errorMessage: String?

    private static let stripePortalUrl = "https://billing.stripe.com/p/login"  // TBD: real per-pastor portal session

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // 1. Email
                    settingsCard {
                        emailRow
                    }

                    // 2. Password
                    settingsCard {
                        passwordRow
                    }

                    // 3. Notifications
                    settingsCard {
                        VStack(spacing: 0) {
                            toggleRow(
                                icon: "bell.fill", tint: YGColors.violet,
                                title: "Push Notifications",
                                subtitle: "Reminders, chat, plan progress",
                                isOn: $pushEnabled
                            )
                            divider
                            toggleRow(
                                icon: "envelope.fill", tint: Color(hex: "FF6B35"),
                                title: "Email Updates",
                                subtitle: "Weekly digest + announcements",
                                isOn: $emailEnabled
                            )
                        }
                    }

                    // 4. Subscription / Billing — role-aware
                    settingsCard {
                        subscriptionRow
                    }

                    // 5. Inline messages
                    if let infoMessage {
                        Text(infoMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(YGColors.ink.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "FF3B30"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    // 6. Delete account
                    Button {
                        showDeleteAccountAlert = true
                    } label: {
                        Text("Delete account")
                            .font(.lilitaOne(size: 14))
                            .foregroundStyle(Color(hex: "FF3B30"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .background(YGColors.paper)
            .navigationTitle("Account Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            // Change Email alert
            .alert("Change Email", isPresented: $showChangeEmail) {
                TextField("New email", text: $newEmail)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                Button("Cancel", role: .cancel) { newEmail = "" }
                Button("Send confirmation") {
                    Task { await changeEmail() }
                }
            } message: {
                Text("We'll email a confirmation link to the new address. Your email won't change until you click it.")
            }
            // Reset password confirmation
            .alert("Reset Password",
                   isPresented: $showResetPasswordConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Send reset email") {
                    Task { await sendPasswordReset() }
                }
            } message: {
                if let email = supabase.currentUser?.email {
                    Text("We'll send a password reset link to \(email).")
                } else {
                    Text("We'll send a password reset link to your account email.")
                }
            }
            // Delete account confirmation
            .alert("Delete Account?",
                   isPresented: $showDeleteAccountAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task { await deleteAccount() }
                }
            } message: {
                Text("This will deactivate your YGTeeV account. Your data is held for 30 days before being permanently removed.")
            }
        }
    }

    // MARK: - Row builders

    private var emailRow: some View {
        Button { showChangeEmail = true } label: {
            HStack(spacing: 14) {
                iconChip(name: "envelope.fill", tint: Color(hex: "0066FF"))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Email")
                        .font(.lilitaOne(size: 15))
                        .tracking(-0.2)
                        .foregroundStyle(YGColors.ink)
                    Text(supabase.currentUser?.email ?? "—")
                        .font(.system(size: 12))
                        .foregroundStyle(YGColors.ink.opacity(0.55))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                chevron
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var passwordRow: some View {
        Button { showResetPasswordConfirmation = true } label: {
            HStack(spacing: 14) {
                iconChip(name: "lock.fill", tint: Color(hex: "FFA62B"))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Password")
                        .font(.lilitaOne(size: 15))
                        .tracking(-0.2)
                        .foregroundStyle(YGColors.ink)
                    Text("Reset via email")
                        .font(.system(size: 12))
                        .foregroundStyle(YGColors.ink.opacity(0.55))
                }
                Spacer()
                chevron
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var subscriptionRow: some View {
        Button {
            if isPastor {
                if let url = URL(string: Self.stripePortalUrl) { UIApplication.shared.open(url) }
            } else {
                if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                    UIApplication.shared.open(url)
                }
            }
        } label: {
            HStack(spacing: 14) {
                iconChip(
                    name: isPastor ? "creditcard.fill" : "star.circle.fill",
                    tint: isPastor ? YGColors.violet : Color(hex: "FFD60A")
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(isPastor ? "Manage Billing" : "Manage Subscription")
                        .font(.lilitaOne(size: 15))
                        .tracking(-0.2)
                        .foregroundStyle(YGColors.ink)
                    Text(isPastor
                         ? "Stripe customer portal"
                         : "App Store subscription")
                        .font(.system(size: 12))
                        .foregroundStyle(YGColors.ink.opacity(0.55))
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(YGColors.ink.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggleRow(icon: String,
                           tint: Color,
                           title: String,
                           subtitle: String,
                           isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            iconChip(name: icon, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.lilitaOne(size: 15))
                    .tracking(-0.2)
                    .foregroundStyle(YGColors.ink)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(YGColors.ink.opacity(0.55))
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(YGColors.violet)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Card chrome

    @ViewBuilder
    private func settingsCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.black.opacity(0.04), lineWidth: 0.5)
        }
        .shadow(color: YGColors.ink.opacity(0.04), radius: 8, y: 2)
    }

    private func iconChip(name: String, tint: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 24))
            .foregroundStyle(tint)
            .frame(width: 32, alignment: .center)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(YGColors.ink.opacity(0.2))
    }

    private var divider: some View {
        Divider().padding(.leading, 54)
    }

    // MARK: - Actions

    private func changeEmail() async {
        let trimmed = newEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try await supabase.requestEmailChange(to: trimmed)
            await MainActor.run {
                infoMessage = "Confirmation link sent to \(trimmed)."
                errorMessage = nil
                newEmail = ""
            }
        } catch {
            await MainActor.run {
                errorMessage = "Couldn't update email. \(error.localizedDescription)"
                infoMessage = nil
            }
        }
    }

    private func sendPasswordReset() async {
        do {
            try await supabase.sendPasswordResetEmail()
            await MainActor.run {
                infoMessage = "Reset link sent. Check your inbox."
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = "Couldn't send reset email. \(error.localizedDescription)"
                infoMessage = nil
            }
        }
    }

    private func deleteAccount() async {
        do {
            try await supabase.requestAccountDeletion()
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run {
                errorMessage = "Couldn't delete account. \(error.localizedDescription)"
            }
        }
    }
}

#Preview("Member") { AccountSettingsView(isPastor: false) }
#Preview("Pastor") { AccountSettingsView(isPastor: true) }
