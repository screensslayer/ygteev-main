//
//  ChildPairingDisplaySheet.swift
//  YGTeeV
//
//  Parent-side display surface after `create-child-account` succeeds.
//  Renders the one-time pairing QR + 8-digit numeric fallback, with a
//  live countdown to `expires_at`. The kid scans (or types) on their
//  fresh device to redeem.
//

import SwiftUI
import CoreImage.CIFilterBuiltins
import Combine

struct ChildPairingDisplaySheet: View {
    let result: CreateChildResult
    @Environment(\.dismiss) private var dismiss

    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// Encoded payload the kid's scanner extracts back into the token.
    private var qrPayload: String {
        "ygteev://child-signin?token=\(result.pairingToken)"
    }

    private var remainingSeconds: Int {
        max(0, Int(result.expiresAt.timeIntervalSince(now)))
    }

    private var isExpired: Bool { remainingSeconds == 0 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Sign in \(result.displayName) on their device")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(YGColors.ink)
                    .lineLimit(2)
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
                VStack(spacing: 20) {
                    qrCard
                    orDivider
                    codeCard
                    countdown
                    instructions
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 15.5, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(YGColors.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 22)
        }
        .background(YGColors.paper)
        .onReceive(timer) { now = $0 }
    }

    // MARK: - Sections

    private var qrCard: some View {
        Image(uiImage: Self.generateQR(payload: qrPayload))
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .frame(width: 220, height: 220)
            .padding(16)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(.black.opacity(0.06), lineWidth: 0.5)
            }
            .shadow(color: YGColors.ink.opacity(0.08), radius: 12, y: 6)
            .opacity(isExpired ? 0.35 : 1)
    }

    private var orDivider: some View {
        HStack(spacing: 10) {
            Rectangle().fill(YGColors.ink.opacity(0.08)).frame(height: 1)
            Text("or")
                .font(.system(size: 11, weight: .heavy))
                .tracking(1)
                .foregroundStyle(YGColors.ink.opacity(0.45))
            Rectangle().fill(YGColors.ink.opacity(0.08)).frame(height: 1)
        }
        .padding(.horizontal, 30)
    }

    private var codeCard: some View {
        VStack(spacing: 6) {
            Text("Enter this code on their device")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(YGColors.ink.opacity(0.6))
            Text(Self.spacedCode(result.numericCode))
                .font(.system(size: 36, weight: .black, design: .rounded))
                .tracking(3)
                .monospacedDigit()
                .foregroundStyle(YGColors.ink)
                .opacity(isExpired ? 0.35 : 1)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(.black.opacity(0.05), lineWidth: 0.5) }
    }

    private var countdown: some View {
        Text(isExpired
             ? "Expired — go back and create the account again."
             : String(format: "Expires in %d:%02d ⏱", remainingSeconds / 60, remainingSeconds % 60))
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .foregroundStyle(isExpired ? .red
                             : remainingSeconds < 60 ? Color(hex: "FF6B35")
                             : YGColors.ink.opacity(0.65))
            .monospacedDigit()
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 8) {
            instructionRow(num: 1, text: "On their device, open YGTeeV.")
            instructionRow(num: 2, text: "Tap \"Sign in with parent's QR\".")
            instructionRow(num: 3, text: "Scan this QR, or type the code above.")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(YGColors.violet.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func instructionRow(num: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(num)")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(YGColors.violet)
                .clipShape(Circle())
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(YGColors.ink.opacity(0.8))
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Helpers

    /// "58271940" → "5827 1940" so it reads cleanly.
    private static func spacedCode(_ code: String) -> String {
        guard code.count > 4 else { return code }
        let half = code.count / 2
        let first = code.prefix(half)
        let rest  = code.suffix(code.count - half)
        return "\(first) \(rest)"
    }

    private static func generateQR(payload: String) -> UIImage {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let img = filter.outputImage?.transformed(by: .init(scaleX: 8, y: 8)),
              let cg = CIContext().createCGImage(img, from: img.extent) else {
            return UIImage()
        }
        return UIImage(cgImage: cg)
    }
}
