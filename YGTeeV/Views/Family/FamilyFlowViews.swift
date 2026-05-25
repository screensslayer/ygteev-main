//
//  FamilyFlowViews.swift
//  YGTeeV
//
//  Parent/Family flow per family-flow.jsx spec:
//    • SetupFamilyPaywallSheet — 3 sheets (paywall → processing → success)
//    • AddFamilyMemberSheet    — intro + pairing-code path
//    • AcceptFamilyInviteSheet — invited-side 4-digit code entry
//
//  StoreKit purchase + `validate-storekit-receipt` are stubbed; the
//  paywall calls `start_family()` directly for now (per the spec's
//  manual age-verify SQL note). When StoreKit lands, swap in the IAP
//  here and gate `proceed()` on receipt validation.
//

import SwiftUI
import Combine
import Supabase

// MARK: - Setup family (paywall → processing → success)

struct SetupFamilyPaywallSheet: View {
    let onComplete: (UUID) -> Void   // family_id
    @Environment(\.dismiss) private var dismiss

    @State private var phase: Phase = .paywall
    @State private var newFamilyId: UUID?
    @State private var error: String?
    @State private var processingStep = 0

    enum Phase { case paywall, processing, success }

    var body: some View {
        ZStack {
            YGColors.paper.ignoresSafeArea()
            switch phase {
            case .paywall:    paywall
            case .processing: processing
            case .success:    success
            }
        }
    }

    // MARK: Paywall

    private var paywall: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Setup your family")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(YGColors.ink)
                        .padding(.top, 30)
                    Text("Verify you're an adult, then pair your students' accounts.")
                        .font(.system(size: 14))
                        .foregroundStyle(YGColors.ink.opacity(0.65))

                    VStack(spacing: 10) {
                        featureRow(emoji: "👨‍👩‍👧",
                                   title: "Link your kids' accounts",
                                   subtitle: "Scan their QR or share a 4-digit pairing code.")
                        featureRow(emoji: "🛡️",
                                   title: "Stay in the loop, safely",
                                   subtitle: "Stay in communication with your youth group.")
                    }
                    .padding(.top, 14)

                    if let error {
                        Text(error)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.red)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }

            VStack(spacing: 10) {
                Button {
                    proceed()
                } label: {
                    HStack {
                        Text("Setup your family · $0.99")
                            .font(.system(size: 15.5, weight: .black, design: .rounded))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .heavy))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [YGColors.violet, Color(hex: "FF3DA5")],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: YGColors.violet.opacity(0.4), radius: 14, y: 6)
                }
                .buttonStyle(.plain)

                Text("Charged via Apple ID. Non-refundable. One-time only. By continuing you confirm you're over 18 and a parent or legal guardian.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(YGColors.ink.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 22)
        }
    }

    private func featureRow(emoji: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji).font(.system(size: 22))
                .frame(width: 38, height: 38)
                .background(YGColors.violet.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(YGColors.ink)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(YGColors.ink.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.05), lineWidth: 0.5) }
    }

    // MARK: Processing

    private var processing: some View {
        VStack(spacing: 24) {
            Spacer()
            ProgressView().controlSize(.large).tint(YGColors.violet)
            VStack(alignment: .leading, spacing: 10) {
                processingItem("Verifying purchase",     done: processingStep > 0)
                processingItem("Stamping age verification", done: processingStep > 1)
                processingItem("Activating family account", done: processingStep > 2)
            }
            .padding(.horizontal, 30)
            if let error {
                Text(error)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 30)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func processingItem(_ label: String, done: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18))
                .foregroundStyle(done ? Color(hex: "2B8A3E") : YGColors.ink.opacity(0.3))
            Text(label)
                .font(.system(size: 14, weight: done ? .heavy : .semibold, design: .rounded))
                .foregroundStyle(done ? YGColors.ink : YGColors.ink.opacity(0.6))
            Spacer()
        }
    }

    // MARK: Success

    private var success: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color(hex: "2B8A3E"))
            Text("You're a family now.")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(YGColors.ink)
            Text("Add your first family member — they can scan your QR or enter a 4-digit code.")
                .font(.system(size: 13))
                .foregroundStyle(YGColors.ink.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            VStack(spacing: 10) {
                Button {
                    if let id = newFamilyId { onComplete(id) }
                    dismiss()
                } label: {
                    Text("Add your first member")
                        .font(.system(size: 15.5, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(colors: [YGColors.violet, Color(hex: "FF3DA5")],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)

                Button("I'll do this later") { dismiss() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(YGColors.ink.opacity(0.55))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 22)
        }
    }

    // MARK: Submit

    private func proceed() {
        Task { await proceedToStartFamily() }
    }

    /// Tick through the processing-screen checklist, then call
    /// `start_family()` and transition to the success phase.
    private func proceedToStartFamily() async {
        error = nil
        processingStep = 0
        withAnimation { phase = .processing }
        // Stubs: real path will purchase IAP + validate receipt here.
        // For now, fake-tick the steps and call start_family directly.
        try? await Task.sleep(nanoseconds: 500_000_000)
        processingStep = 1
        try? await Task.sleep(nanoseconds: 500_000_000)
        processingStep = 2
        do {
            let id = try await FamilyService.shared.startFamily()
            newFamilyId = id
            processingStep = 3
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation { phase = .success }
        } catch {
            self.error = "Couldn't start family. \(error.localizedDescription)"
            withAnimation { phase = .paywall }
        }
    }

}

// MARK: - Add family member sheet

struct AddFamilyMemberSheet: View {
    let familyId: UUID
    @Environment(\.dismiss) private var dismiss

    @State private var path: Path = .intro
    @State private var invite: FamilyInviteResult?
    @State private var error: String?
    @State private var now = Date()
    @State private var showScanner = false
    @State private var isSendingInvite = false
    @State private var showSentToast = false
    @State private var showCreateChild = false
    @State private var childPairing: CreateChildResult?
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    enum Path { case intro, pairingCode }

    var body: some View {
        ZStack {
            YGColors.paper.ignoresSafeArea()
            switch path {
            case .intro:       intro
            case .pairingCode: pairing
            }

            if showSentToast {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15))
                        Text("Added to your family!")
                            .font(.system(size: 12.5, weight: .semibold))
                            .lineLimit(2)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(YGColors.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onReceive(timer) { now = $0 }
        .fullScreenCover(isPresented: $showScanner) {
            FamilyQRScanner(
                onScan: { userId in
                    showScanner = false
                    Task { await invite(viaScannedUserId: userId) }
                },
                onCancel: { showScanner = false },
                currentUserId: (SupabaseManager.shared.currentUser?.id).flatMap { UUID(uuidString: $0) }
            )
        }
        .sheet(isPresented: $showCreateChild) {
            CreateChildAccountView(familyId: familyId) { result in
                showCreateChild = false
                // Defer setting the pairing presentation until the create
                // sheet fully dismisses, otherwise iOS will queue the
                // second sheet behind it.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    childPairing = result
                }
            }
        }
        .sheet(item: $childPairing) { result in
            ChildPairingDisplaySheet(result: result)
                .presentationDetents([.large])
        }
    }

    // MARK: Intro

    private var intro: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add a family member")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(YGColors.ink)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(YGColors.ink.opacity(0.6))
                        .frame(width: 30, height: 30)
                        .background(YGColors.ink.opacity(0.06))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 14)

            ScrollView {
                VStack(spacing: 10) {
                    optionCard(
                        emoji: "📱",
                        title: "Scan their QR",
                        subtitle: "They open their profile QR. We'll link their existing account."
                    ) {
                        showScanner = true
                    }
                    optionCard(
                        emoji: "🔢",
                        title: "Use a pairing code",
                        subtitle: "Show them a 4-digit code to enter on their device."
                    ) {
                        Task { await createCode() }
                    }
                    optionCard(
                        emoji: "👨‍👩‍👧",
                        title: "Create Managed Account",
                        subtitle: "Spin up a managed account you control."
                    ) {
                        showCreateChild = true
                    }

                    if let error {
                        Text(error)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.red)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
    }

    private func optionCard(emoji: String, title: String, subtitle: String,
                            disabled: Bool = false, badge: String? = nil,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Text(emoji).font(.system(size: 28))
                    .frame(width: 50, height: 50)
                    .background(YGColors.violet.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(YGColors.ink)
                        if let badge {
                            Text(badge)
                                .font(.system(size: 9.5, weight: .heavy))
                                .tracking(0.4)
                                .foregroundStyle(YGColors.ink.opacity(0.55))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(YGColors.ink.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    Text(subtitle)
                        .font(.system(size: 12.5))
                        .foregroundStyle(YGColors.ink.opacity(0.6))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.black.opacity(0.05), lineWidth: 0.5)
            }
            .opacity(disabled ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private func createCode() async {
        error = nil
        do {
            let result = try await FamilyService.shared.createInvite(familyId: familyId)
            invite = result
            withAnimation { path = .pairingCode }
        } catch {
            self.error = "Couldn't generate code. \(error.localizedDescription)"
        }
    }

    /// Direct add via the `family_add_via_scan` RPC. Scanning a profile
    /// QR is sufficient consent from both sides, so this skips the
    /// pending-invite path entirely — the scanned user lands in the
    /// family roster immediately.
    private func invite(viaScannedUserId userId: UUID) async {
        guard !isSendingInvite else { return }
        isSendingInvite = true
        error = nil
        defer { isSendingInvite = false }
        do {
            _ = try await FamilyService.shared.addViaScan(
                familyId: familyId,
                scannedUserId: userId
            )
            withAnimation { showSentToast = true }
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            dismiss()
        } catch {
            self.error = "Couldn't add to family. \(error.localizedDescription)"
        }
    }

    // MARK: Pairing code

    private var pairing: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    invite = nil
                    withAnimation { path = .intro }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(YGColors.ink)
                        .frame(width: 30, height: 30)
                        .background(.white)
                        .clipShape(Circle())
                        .overlay { Circle().strokeBorder(.black.opacity(0.06), lineWidth: 0.5) }
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(YGColors.ink.opacity(0.6))
                        .frame(width: 30, height: 30)
                        .background(YGColors.ink.opacity(0.06))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)

            VStack(spacing: 16) {
                Spacer()
                Text("Show this to your family member")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(YGColors.ink)
                    .multilineTextAlignment(.center)

                Text(invite?.pairingCode ?? "----")
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .tracking(8)
                    .monospacedDigit()
                    .foregroundStyle(YGColors.ink)
                    .padding(.vertical, 26)
                    .padding(.horizontal, 36)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(YGColors.violet.opacity(0.25), lineWidth: 1.5) }
                    .shadow(color: YGColors.violet.opacity(0.18), radius: 14, y: 6)

                Text(countdownLabel)
                    .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(countdownColor)
                    .monospacedDigit()

                Text("They enter this on their device under **Settings → Join a family**. Auto-expires.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(YGColors.ink.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()

                Button("Done — refresh later") { dismiss() }
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(YGColors.ink)
                    .padding(.bottom, 20)
            }
        }
    }

    private var remainingSeconds: Int {
        guard let invite else { return 0 }
        return max(0, Int(invite.expiresAt.timeIntervalSince(now)))
    }

    private var countdownLabel: String {
        if invite == nil { return "" }
        let s = remainingSeconds
        if s == 0 { return "Expired — generate a new code." }
        return String(format: "Expires in %d:%02d ⏱", s / 60, s % 60)
    }

    private var countdownColor: Color {
        remainingSeconds == 0 ? .red
            : remainingSeconds < 60 ? Color(hex: "FF6B35")
            : YGColors.ink.opacity(0.65)
    }
}

// MARK: - Accept family invite (invited side)

struct AcceptFamilyInviteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var code: String = ""
    @State private var isSubmitting = false
    @State private var error: String?
    @State private var success = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Join a family")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(YGColors.ink)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(YGColors.ink.opacity(0.6))
                        .frame(width: 30, height: 30)
                        .background(YGColors.ink.opacity(0.06))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 14)

            VStack(spacing: 16) {
                Spacer()
                if success {
                    VStack(spacing: 14) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(Color(hex: "2B8A3E"))
                        Text("You're linked.")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(YGColors.ink)
                    }
                } else {
                    Text("Enter the 4-digit code your parent shared.")
                        .font(.system(size: 14))
                        .foregroundStyle(YGColors.ink.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)

                    TextField("1234", text: $code)
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .tracking(8)
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .padding(.vertical, 18)
                        .padding(.horizontal, 28)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(YGColors.violet.opacity(0.2), lineWidth: 1.5) }
                        .onChange(of: code) { _, newValue in
                            code = String(newValue.filter(\.isNumber).prefix(4))
                        }
                }

                if let error {
                    Text(error)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 24)
                }
                Spacer()
            }
            .padding(.horizontal, 16)

            VStack(spacing: 8) {
                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        if isSubmitting { ProgressView().tint(.white) }
                        Text(success ? "Done" : "Join family")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [YGColors.violet, Color(hex: "FF3DA5")],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .disabled(!success && (isSubmitting || code.count != 4))
                .opacity(success || code.count == 4 ? 1 : 0.5)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 22)
        }
        .background(YGColors.paper)
    }

    private func submit() async {
        if success { dismiss(); return }
        guard code.count == 4 else { return }
        isSubmitting = true
        error = nil
        defer { isSubmitting = false }
        do {
            _ = try await FamilyService.shared.acceptInvite(code: code)
            success = true
        } catch {
            self.error = "Couldn't join: \(error.localizedDescription)"
        }
    }
}
