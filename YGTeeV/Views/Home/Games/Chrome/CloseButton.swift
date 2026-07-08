//
//  CloseButton.swift
//  YGTeeV
//
//  Top-leading close affordance for the immersive Game Night shell.
//  Circular 40×40 translucent button with a chevron-down glyph. Only
//  used by `ImmersiveGameShell` — stage views never close themselves.
//

import SwiftUI

struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.down")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.1))
                .overlay(
                    Circle().strokeBorder(.white.opacity(0.16), lineWidth: 1)
                )
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
