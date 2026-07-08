//
//  RoomCodeBadge.swift
//  YGTeeV
//
//  Capsule "ROOM XXXX" pill rendered in the immersive top chrome.
//  The shell horizontally centers it between two Spacers, with a
//  matching 40pt placeholder on the right side so it stays visually
//  centered regardless of the close button on the left.
//

import SwiftUI

struct RoomCodeBadge: View {
    let code: String

    var body: some View {
        HStack(spacing: 8) {
            Text("ROOM")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.5))
            Text(code)
                .font(.lilitaOne(size: 17))
                .tracking(2)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08))
        .overlay(
            Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 1)
        )
        .clipShape(Capsule())
    }
}
