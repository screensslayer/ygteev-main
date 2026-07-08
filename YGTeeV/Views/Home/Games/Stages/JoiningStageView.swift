//
//  JoiningStageView.swift
//  YGTeeV
//
//  Stage shown during the brief window between cover presentation
//  and `gn_member_join` resolving. Pure content — the shell handles
//  the top chrome (close + ROOM badge) and there's no footer yet.
//

import SwiftUI

struct JoiningStageView: View {
    let active: ActiveGame

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            ProgressView()
                .tint(.white)
                .scaleEffect(1.3)
            Text("Joining…")
                .font(.lilitaOne(size: 18))
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
        }
    }
}
