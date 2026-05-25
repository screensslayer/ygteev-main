//
//  PendingInviteBanner.swift
//  YGTeeV
//
//  "{inviter} wants to add you to {family} — Accept · Decline" banner on
//  the invited side. Renders inline above the bottom tabs whenever
//  `FamilyService.shared.topPendingInvite` is non-nil. Tap accept calls
//  `accept_family_invite(_code:)`; tap decline dismisses locally (the
//  invite expires server-side in 10 min).
//

import SwiftUI

struct PendingInviteBanner: View {
    @State private var service = FamilyService.shared
    @State private var isWorking = false
    @State private var inlineError: String?

    var body: some View {
        if let invite = service.topPendingInvite {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Text("👨‍👩‍👧")
                        .font(.system(size: 22))
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.22))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(headline(for: invite))
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        Text("Expires in \(minutesLeft(for: invite)) min")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    Spacer(minLength: 0)
                }

                if let inlineError {
                    Text(inlineError)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Color(hex: "FFD60A"))
                }

                HStack(spacing: 8) {
                    Button {
                        service.dismissInviteLocally(invite.inviteId)
                    } label: {
                        Text("Decline")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Capsule())
                            .overlay {
                                Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(isWorking)

                    Button {
                        Task { await accept(invite: invite) }
                    } label: {
                        HStack(spacing: 6) {
                            if isWorking { ProgressView().tint(YGColors.ink).controlSize(.small) }
                            Text("Accept")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                        }
                        .foregroundStyle(YGColors.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isWorking)
                }
            }
            .padding(14)
            .background(
                LinearGradient(colors: [YGColors.violet, Color(hex: "FF3DA5")],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: YGColors.violet.opacity(0.4), radius: 14, y: 6)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func headline(for invite: PendingFamilyInvite) -> String {
        let who = invite.inviterName?.isEmpty == false ? invite.inviterName! : "Someone"
        return "\(who) wants to add you to \(invite.familyName)"
    }

    private func minutesLeft(for invite: PendingFamilyInvite) -> Int {
        max(0, Int(invite.expiresAt.timeIntervalSinceNow / 60))
    }

    private func accept(invite: PendingFamilyInvite) async {
        guard !isWorking else { return }
        isWorking = true
        inlineError = nil
        defer { isWorking = false }
        do {
            _ = try await service.acceptPendingInvite(invite)
            await service.loadMyFamilies()
        } catch {
            inlineError = "Couldn't accept: \(error.localizedDescription)"
        }
    }
}
