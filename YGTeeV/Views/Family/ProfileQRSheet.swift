//
//  ProfileQRSheet.swift
//  YGTeeV
//
//  Renders the current user's profile QR. A parent on another device
//  scans this to drop a `create_family_invite` with the invited_user_id
//  pre-filled — no pairing code typing required on either side.
//

import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

struct ProfileQRSheet: View {
    let userId: UUID
    let displayName: String

    @Environment(\.dismiss) private var dismiss

    /// Payload format the family scanner expects. Anything else on the
    /// scanner side is rejected.
    static func payload(for userId: UUID) -> String {
        "ygteev://user/\(userId.uuidString.lowercased())"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("My Profile QR")
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
            .padding(.bottom, 6)

            Spacer()

            VStack(spacing: 18) {
                Text(displayName)
                    .font(.lilitaOne(size: 24))
                    .tracking(-0.4)
                    .foregroundStyle(YGColors.ink)

                Image(uiImage: Self.generateQR(for: userId))
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240, height: 240)
                    .padding(18)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22)
                            .strokeBorder(.black.opacity(0.06), lineWidth: 0.5)
                    }
                    .shadow(color: YGColors.ink.opacity(0.08), radius: 12, y: 6)

                Text("Have someone scan this to add you to their family.")
                    .font(.system(size: 13))
                    .foregroundStyle(YGColors.ink.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }

            Spacer()
            Spacer()
        }
        .background(YGColors.paper)
    }

    private static func generateQR(for userId: UUID) -> UIImage {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload(for: userId).utf8)
        filter.correctionLevel = "M"
        guard let img = filter.outputImage?.transformed(by: .init(scaleX: 8, y: 8)),
              let cg = CIContext().createCGImage(img, from: img.extent) else {
            return UIImage()
        }
        return UIImage(cgImage: cg)
    }
}
