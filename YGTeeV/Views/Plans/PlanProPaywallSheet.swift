//
//  PlanProPaywallSheet.swift
//  YGTeeV
//
//  Paywall surfaced when a non-Pro user taps a Pro plan card on the
//  Your Journey list. Mirrors the onboarding paywall's look and shares
//  the same RevenueCat-backed purchase flow via PurchasesManager.
//  Self-contained — no nested fullScreenCovers — so it presents cleanly
//  from inside the host plans-list sheet without SwiftUI stack conflicts.
//

import SwiftUI
import RevenueCat

struct PlanProPaywallSheet: View {
    /// Called when the user picks any exit path (purchase, "Maybe
    /// later", X). The caller dismisses its presenter from here.
    var onClose: () -> Void
    /// Called when the user picks the "Join a youth group" escape
    /// hatch. The caller dismisses the paywall AND routes the user
    /// to the map join flow.
    var onJoinGroupInstead: () -> Void

    @State private var purchases = PurchasesManager.shared
    @State private var isPurchasing = false
    @State private var selectedTierIndex: Int = 2
    @State private var purchaseErrorMessage: String?

    private let perks: [(String, String, String)] = [
        ("📖", "Premium plans & commentary", "500+ deeper studies"),
        ("⚡", "2× XP all the time",          "Grow faster, level up sooner"),
        ("🔕", "No ads, ever",               "Cleanest reading experience"),
    ]

    private var currentPackage: Package? {
        let pkgs = purchases.subscriptionPackages
        guard pkgs.indices.contains(selectedTierIndex) else { return nil }
        return pkgs[selectedTierIndex]
    }

    var body: some View {
        ZStack {
            background

            VStack {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(.white.opacity(0.14), in: Circle())
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 60)
                }
                Spacer()
            }

            // Decorative glow behind the badge.
            Circle()
                .fill(RadialGradient(
                    colors: [Color(hex: "FFD60A").opacity(0.4), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 150
                ))
                .frame(width: 300, height: 300)
                .blur(radius: 20)
                .offset(y: -260)

            VStack(spacing: 0) {
                Spacer().frame(height: 110)
                heroBlock
                Spacer().frame(height: 24)
                perksList
                Spacer()
                pricingBlock
                ctaStack
            }
        }
        .alert("Purchase failed", isPresented: Binding(
            get: { purchaseErrorMessage != nil },
            set: { if !$0 { purchaseErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { purchaseErrorMessage = nil }
        } message: {
            Text(purchaseErrorMessage ?? "")
        }
    }

    // MARK: - Subviews

    private var background: some View {
        LinearGradient(
            colors: [
                Color(hex: "0A0712"),
                Color(hex: "1A1428"),
                Color(hex: "2D2542")
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var heroBlock: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(
                        colors: [Color(hex: "FFD60A"), Color(hex: "FF6B35")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .shadow(color: Color(hex: "FF6B35").opacity(0.4), radius: 14, y: 6)
                Text("⚡").font(.system(size: 32))
            }
            .frame(width: 64, height: 64)

            HStack(spacing: 6) {
                Text("Go further with")
                    .font(.lilitaOne(size: 26))
                    .tracking(-0.9)
                    .foregroundStyle(.white)
                Text("YGTeeV+")
                    .font(.lilitaOne(size: 26))
                    .tracking(-0.9)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "FFD60A"), Color(hex: "FF3DA5")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }

            Text("Pay what feels right. Cancel anytime.")
                .font(.system(size: 13.5))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 22)
    }

    private var perksList: some View {
        VStack(spacing: 4) {
            ForEach(perks, id: \.1) { perk in
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.08))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                            }
                        Text(perk.0).font(.system(size: 16))
                    }
                    .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(perk.1)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text(perk.2)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    Spacer()
                }
                .padding(.vertical, 6)
            }
        }
        .padding(.horizontal, 22)
    }

    @ViewBuilder
    private var pricingBlock: some View {
        if purchases.isAvailable {
            ProPriceSlider(
                selectedIndex: $selectedTierIndex,
                packages: purchases.subscriptionPackages
            )
            .padding(.bottom, 18)
        }
    }

    private var ctaStack: some View {
        VStack(spacing: 10) {
            primaryCTA

            Button {
                onJoinGroupInstead()
            } label: {
                Text("Join a youth group and get full access for free →")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: "B4FF3C"))
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            Button(action: onClose) {
                Text("Maybe later")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 26)
    }

    @ViewBuilder
    private var primaryCTA: some View {
        if !purchases.isAvailable {
            Text("Purchases unavailable in staging")
                .font(.lilitaOne(size: 16))
                .tracking(-0.2)
                .foregroundStyle(.white.opacity(0.55))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                )
        } else {
            Button(action: purchase) {
                HStack(spacing: 8) {
                    if isPurchasing { ProgressView().tint(YGColors.ink) }
                    Text(ctaLabel)
                        .font(.lilitaOne(size: 16))
                        .tracking(-0.2)
                }
                .foregroundStyle(YGColors.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "FFD60A"), Color(hex: "FF6B35")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: Color(hex: "FF6B35").opacity(0.4), radius: 14, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(isCTADisabled)
            .opacity(isCTADisabled ? 0.55 : 1)
        }
    }

    private var isCTADisabled: Bool {
        isPurchasing || purchases.isLoading || currentPackage == nil
    }

    private var ctaLabel: String {
        if isPurchasing { return "Connecting…" }
        if let price = currentPackage?.storeProduct.localizedPriceString {
            return "Get full access — \(price)/mo"
        }
        return "Loading prices…"
    }

    // MARK: - Purchase

    private func purchase() {
        guard let pkg = currentPackage else { return }
        isPurchasing = true
        Task {
            do {
                let isPro = try await purchases.purchase(pkg)
                isPurchasing = false
                if isPro {
                    onClose()
                } else if let msg = purchases.lastError {
                    purchaseErrorMessage = msg
                }
            } catch {
                isPurchasing = false
                purchaseErrorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    PlanProPaywallSheet(onClose: {}, onJoinGroupInstead: {})
}
