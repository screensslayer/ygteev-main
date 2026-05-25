//
//  AddMyGroupSheet.swift
//  YGTeeV
//
//  Branded "get your pastor on YGTeeV" sheet. Primary CTA opens
//  Messages with a pre-written invite SMS; secondary CTA opens Mail
//  with a longer body. We log both channels to
//  `youth_group_submissions` for analytics but no longer fire the
//  server-side lead-welcome email — the student is the messenger now.
//

import SwiftUI
import UIKit
import Supabase

struct AddMyGroupSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var pastorFirstName = ""
    @State private var pastorPhone = ""
    @State private var pastorEmail = ""
    @State private var churchName = ""

    /// Brand gradient — matches the rest of the YGTeeV app and the
    /// EventsNearMeSheet panel on the map.
    private var brandGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "6B2BFF"), Color(hex: "FF3DA5")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var canText: Bool {
        !pastorFirstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        pastorPhone.filter(\.isNumber).count >= 10
    }

    private var canEmail: Bool {
        !pastorFirstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        pastorEmail.contains("@") &&
        pastorEmail.contains(".")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    hero
                    formCard
                }
            }
            .background(Color.white)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(YGColors.ink)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        // `environment(\.colorScheme, .light)` resolves synchronously
        // for child views, so the first frame already paints the
        // light-mode colors. `preferredColorScheme` is an async hint
        // to the hosting window and was causing the dark→light flash
        // when the sheet first opened.
        .environment(\.colorScheme, .light)
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.title)
                Text("Get your youth group on YGTeeV")
                    .font(.title2.weight(.bold))
                    .lineLimit(3)
            }
            .foregroundStyle(.white)

            Text("Text them in 10 seconds — we wrote the message for you.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .padding(.bottom, 28)
        .background(brandGradient)
    }

    // MARK: - Form

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            section(title: "YOUTH PASTOR") {
                fieldRow("Pastor first name", text: $pastorFirstName)
                Divider().padding(.leading, 16)
                fieldRow("Pastor phone (US)", text: $pastorPhone, keyboard: .phonePad)
                Divider().padding(.leading, 16)
                fieldRow("Pastor email (optional)",
                         text: $pastorEmail,
                         keyboard: .emailAddress,
                         autocap: false)
            }

            section(title: "YOUR CHURCH (OPTIONAL)") {
                fieldRow("Church name", text: $churchName)
            }

            ctaStack
        }
        .padding(16)
    }

    @ViewBuilder
    private func section<Content: View>(title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                // Explicit gray so the section header renders the
                // same colour on the very first frame regardless of
                // the host window's color scheme.
                .foregroundStyle(Color(hex: "8E8E93"))

            VStack(spacing: 0) { content() }
                // `Color(.secondarySystemBackground)` resolves to a
                // dark surface on a dark host before our color-scheme
                // override kicks in. Pin to systemGray6-light hex
                // (#F2F2F7) so it's consistent immediately.
                .background(Color(hex: "F2F2F7"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    @ViewBuilder
    private func fieldRow(_ placeholder: String,
                          text: Binding<String>,
                          keyboard: UIKeyboardType = .default,
                          autocap: Bool = true) -> some View {
        TextField(placeholder, text: text)
            .textInputAutocapitalization(autocap ? .words : .never)
            .autocorrectionDisabled(!autocap)
            .keyboardType(keyboard)
            .padding(14)
    }

    private var ctaStack: some View {
        VStack(spacing: 10) {
            Button(action: handleText) {
                Text("Text My Pastor")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(brandGradient, in: Capsule())
                    .opacity(canText ? 1.0 : 0.5)
            }
            .disabled(!canText)
            .buttonStyle(.plain)

            Button(action: handleEmail) {
                Text("Email Instead")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(YGColors.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "F2F2F7"), in: Capsule())
                    .opacity(canEmail ? 1.0 : 0.5)
            }
            .disabled(!canEmail)
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    // MARK: - Outreach actions

    private func handleText() {
        Task { await logSubmission(channel: "sms") }

        let body = composedSMSBody()
        let digits = pastorPhone.filter { $0.isNumber || $0 == "+" }
        // iOS quirk: sms: URLs use `&body=`, not `?body=`.
        let bodyEnc = body.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) ?? ""
        if let url = URL(string: "sms:\(digits)&body=\(bodyEnc)"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            dismiss()
        }
    }

    private func handleEmail() {
        Task { await logSubmission(channel: "email") }

        let churchOrGroup = churchName
            .trimmingCharacters(in: .whitespaces)
            .isEmpty ? "our youth group" : churchName.trimmingCharacters(in: .whitespaces)
        let subject = "Can you get \(churchOrGroup) on YGTeeV?"
        let body = composedEmailBody()
        let subjEnc = subject.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed) ?? ""
        let bodyEnc = body.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed) ?? ""
        let to = pastorEmail.trimmingCharacters(in: .whitespaces)
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "mailto:\(to)?subject=\(subjEnc)&body=\(bodyEnc)"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            dismiss()
        }
    }

    // MARK: - Message bodies

    private var studentFirst: String {
        let full = SupabaseManager.shared.currentUser?.displayName ?? ""
        return full.split(separator: " ").first.map(String.init) ?? "A student"
    }

    private func composedSMSBody() -> String {
        let pastor = pastorFirstName.trimmingCharacters(in: .whitespaces)
        return """
        Hey \(pastor), We need to get our youth group added on YGTeeV — it's a Bible reading app that turns daily devos into a game for our youth group. https://pastors.ygteev.com/create
        """
    }

    private func composedEmailBody() -> String {
        let pastor = pastorFirstName.trimmingCharacters(in: .whitespaces)
        let church = churchName.trimmingCharacters(in: .whitespaces)
        let groupRef = church.isEmpty ? "our youth group" : church
        return """
        Hey \(pastor),

        This is \(studentFirst). We need to get \(groupRef) added on YGTeeV — it's a Bible reading app for teens that turns daily reading into a game with the youth group. We earn XP, grow a little garden, and chat with you / our leaders in-app.

        All I need is for you to create our page on the pastor dashboard so I (and the rest of our group) can join. There's a 14-day free trial — would you check it out?

        Sign up here: https://pastors.ygteev.com/create

        Thanks,
        \(studentFirst)
        """
    }

    // MARK: - Analytics submission

    /// Best-effort log. If the table is missing the newer
    /// `pastor_phone` / `referral_channel` columns, the insert will
    /// error and we silently swallow — the student's text/email goes
    /// through either way.
    private func logSubmission(channel: String) async {
        struct Row: Encodable {
            let church_name: String?
            let pastor_name: String
            let pastor_email: String?
            let pastor_phone: String?
            let lead_stage: String
            let referral_channel: String
        }
        let trimmedChurch = churchName.trimmingCharacters(in: .whitespaces)
        let trimmedEmail  = pastorEmail.trimmingCharacters(in: .whitespaces)
        let trimmedPhone  = pastorPhone.trimmingCharacters(in: .whitespaces)
        let row = Row(
            church_name:      trimmedChurch.isEmpty ? nil : trimmedChurch,
            pastor_name:      pastorFirstName.trimmingCharacters(in: .whitespaces),
            pastor_email:     trimmedEmail.isEmpty ? nil : trimmedEmail,
            pastor_phone:     trimmedPhone.isEmpty ? nil : trimmedPhone,
            lead_stage:       "student_sent",
            referral_channel: channel
        )
        do {
            _ = try await SupabaseManager.shared.client
                .from("youth_group_submissions")
                .insert(row)
                .execute()
        } catch {
            print("[AddMyGroup] log failed:", error)
        }
    }
}
