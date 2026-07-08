//
//  ReportContentSheet.swift
//  YGTeeV
//
//  Lightweight report-content surface presented from the context menus
//  on chat messages, feed posts, event media, and profile rows. Picks a
//  reason, optional details, then opens the system mail composer
//  pre-filled with the report payload (see `ModerationService`).
//
//  Once the backend `report_content` Edge Function ships, swap the
//  mailto: call in `submit` for a direct RPC.
//

import SwiftUI

struct ReportContentSheet: View {
    let target: ModerationService.ReportTarget
    /// Optional name shown in the sheet header so the reporter can
    /// double-check who/what they're reporting. Nil-safe.
    let contextLabel: String?

    @Environment(\.dismiss) private var dismiss
    @State private var reason: ModerationService.ReportReason = .spam
    @State private var details: String = ""
    @State private var sentInfo: String?

    var body: some View {
        NavigationStack {
            Form {
                if let contextLabel {
                    Section("Reporting") {
                        Text(contextLabel)
                            .font(.subheadline.weight(.semibold))
                    }
                }
                Section("What's the issue?") {
                    Picker("Reason", selection: $reason) {
                        ForEach(ModerationService.ReportReason.allCases) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section("Additional details (optional)") {
                    TextEditor(text: $details)
                        .frame(minHeight: 100)
                }
                if let sentInfo {
                    Section {
                        Text(sentInfo)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { submit() }
                }
            }
        }
    }

    private func submit() {
        if let url = ModerationService.shared.reportMailtoURL(
            reason: reason,
            details: details,
            target: target
        ), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url) { _ in
                dismiss()
            }
        } else {
            // No mail account on device, OR mailto: is unreachable.
            // Surface a fallback note so the reporter has a path.
            sentInfo = "Email isn't set up on this device. Please email support@ygteev.com and include this code: \(target.subjectSuffix)"
        }
    }
}
