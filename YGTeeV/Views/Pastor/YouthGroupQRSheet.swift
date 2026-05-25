//
//  YouthGroupQRSheet.swift
//  YGTeeV
//
//  Pastor-side QR for a youth group — same idea as `ProfileQRSheet` but
//  encodes `ygteev://group/<uuid>` and adds Share / Copy link / Download
//  affordances modeled on the Instagram profile QR pattern.
//

import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

struct YouthGroupQRSheet: View {
    let groupId: UUID
    let groupName: String
    let churchName: String?
    /// Optional brand gradient stops; default to the dashboard
    /// violet → pink so existing groups without per-row gradients
    /// still produce an on-brand sheet.
    let gradientFrom: String?
    let gradientTo: String?

    @Environment(\.dismiss) private var dismiss
    @State private var showShare = false
    @State private var toastMessage: String?

    /// In-app scanner payload. Mirrors the `user` form already used by
    /// `ProfileQRSheet` for parity.
    static func appDeeplink(for groupId: UUID) -> String {
        "ygteev://group/\(groupId.uuidString.lowercased())"
    }

    /// Universal link for Share / Copy. The marketing site can later
    /// add an iOS Universal Link config that hands off to the app
    /// when installed; for now it's a future-proof shape.
    static func shareLink(for groupId: UUID) -> String {
        "https://ygteev.com/g/\(groupId.uuidString.lowercased())"
    }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                topBar
                Spacer()
                qrCard
                    .padding(.horizontal, 36)
                Spacer()
                actionRow
                    .padding(.horizontal, 36)
                    .padding(.bottom, 30)
            }

            if let toastMessage {
                VStack {
                    Spacer()
                    Text(toastMessage)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(YGColors.ink)
                        .clipShape(Capsule())
                        .padding(.bottom, 110)
                        .transition(.opacity)
                }
            }
        }
        .sheet(isPresented: $showShare) {
            ActivityView(activityItems: [
                Self.shareLink(for: groupId),
                Self.generateQR(for: groupId)
            ])
        }
    }

    // MARK: - Subviews

    private var background: some View {
        LinearGradient(
            colors: [
                Color(hex: gradientFrom ?? "6B2BFF"),
                Color(hex: gradientTo   ?? "3D0FB8")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.15))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            Spacer()
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private var qrCard: some View {
        VStack(spacing: 18) {
            Image(uiImage: Self.generateQR(for: groupId))
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 240, height: 240)
                .padding(18)

            VStack(spacing: 4) {
                if let church = churchName, !church.isEmpty {
                    Text(church)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(YGColors.ink.opacity(0.55))
                }
                Text(groupName)
                    .font(.lilitaOne(size: 22))
                    .tracking(-0.4)
                    .foregroundStyle(YGColors.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 22)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(0.25), radius: 24, y: 12)
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            actionButton(icon: "square.and.arrow.up", label: "Share profile") {
                showShare = true
            }
            actionButton(icon: "link", label: "Copy link") {
                UIPasteboard.general.string = Self.shareLink(for: groupId)
                flashToast("Link copied")
            }
            actionButton(icon: "arrow.down.to.line", label: "Download") {
                saveToPhotos()
            }
        }
    }

    private func actionButton(icon: String,
                              label: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(label)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(YGColors.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func flashToast(_ text: String) {
        withAnimation { toastMessage = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation { toastMessage = nil }
        }
    }

    /// Save the branded share card (NOT the bare QR) so the saved image
    /// includes the group name + gradient context — better for sharing
    /// in iMessage / IG without iOS auto-cropping just the white card.
    private func saveToPhotos() {
        let img = Self.generateBrandedShareCard(
            groupId: groupId,
            groupName: groupName,
            churchName: churchName,
            gradientFrom: gradientFrom,
            gradientTo: gradientTo
        )
        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
        flashToast("Saved to Photos")
    }

    // MARK: - QR + branded card generation

    static func generateQR(for groupId: UUID) -> UIImage {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(appDeeplink(for: groupId).utf8)
        filter.correctionLevel = "M"
        guard let img = filter.outputImage?.transformed(by: .init(scaleX: 8, y: 8)),
              let cg = CIContext().createCGImage(img, from: img.extent) else {
            return UIImage()
        }
        return UIImage(cgImage: cg)
    }

    /// 1080×1920 share card: gradient bg, white-rounded QR plate, group
    /// + church name, "YGTeeV" footer. Used by the Download action so
    /// the resulting Photos asset is on-brand and shareable as-is.
    static func generateBrandedShareCard(groupId: UUID,
                                         groupName: String,
                                         churchName: String?,
                                         gradientFrom: String?,
                                         gradientTo: String?) -> UIImage {
        let size = CGSize(width: 1080, height: 1920)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext

            // Gradient background — same stops as the live sheet.
            let colors = [
                UIColor(Color(hex: gradientFrom ?? "6B2BFF")).cgColor,
                UIColor(Color(hex: gradientTo   ?? "3D0FB8")).cgColor
            ] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            if let grad = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
                cg.drawLinearGradient(
                    grad,
                    start: .zero,
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            }

            // White QR plate.
            let qrSize: CGFloat = 720
            let qrRect = CGRect(
                x: (size.width - qrSize) / 2,
                y: 480,
                width: qrSize,
                height: qrSize
            )
            UIColor.white.setFill()
            UIBezierPath(roundedRect: qrRect.insetBy(dx: -40, dy: -40),
                         cornerRadius: 48).fill()
            generateQR(for: groupId).draw(in: qrRect)

            // Group name.
            let nameAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 64, weight: .heavy),
                .foregroundColor: UIColor.white
            ]
            let nameStr = groupName as NSString
            let nameSize = nameStr.size(withAttributes: nameAttrs)
            nameStr.draw(
                at: CGPoint(x: (size.width - nameSize.width) / 2, y: 1320),
                withAttributes: nameAttrs
            )

            // Optional church subline.
            if let church = churchName, !church.isEmpty {
                let chAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 36, weight: .semibold),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.85)
                ]
                let chStr = church as NSString
                let chSize = chStr.size(withAttributes: chAttrs)
                chStr.draw(
                    at: CGPoint(x: (size.width - chSize.width) / 2, y: 1410),
                    withAttributes: chAttrs
                )
            }

            // YGTeeV wordmark footer.
            let footAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 32, weight: .heavy),
                .foregroundColor: UIColor.white.withAlphaComponent(0.65)
            ]
            let foot = "YGTeeV" as NSString
            let footSize = foot.size(withAttributes: footAttrs)
            foot.draw(
                at: CGPoint(x: (size.width - footSize.width) / 2, y: 1720),
                withAttributes: footAttrs
            )
        }
    }
}

// MARK: - UIKit share sheet bridge

/// Wraps `UIActivityViewController` so we can present from SwiftUI.
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
