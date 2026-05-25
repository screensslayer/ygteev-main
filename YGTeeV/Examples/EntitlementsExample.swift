//
//  EntitlementsExample.swift
//  YGTeeV
//
//  Created by Claude Code on 5/8/26.
//
//  Example: How to gate features based on entitlements
//

import SwiftUI

struct EntitlementsExampleView: View {
    @Environment(EntitlementsService.self) private var entitlementsService

    var body: some View {
        List {
            Section("Entitlements Status") {
                EntitlementRow(label: "Pro", value: entitlementsService.entitlements.isPro)
                EntitlementRow(label: "Site Admin", value: entitlementsService.entitlements.isSiteAdmin)
                EntitlementRow(label: "Pastor", value: entitlementsService.entitlements.isPastor)
                EntitlementRow(label: "Parent", value: entitlementsService.entitlements.isParent)
                EntitlementRow(label: "Can Create Events", value: entitlementsService.entitlements.canCreateEvents)
                EntitlementRow(label: "Can Create Plans", value: entitlementsService.entitlements.canCreatePlans)
                EntitlementRow(label: "Can Run Youth Group", value: entitlementsService.entitlements.canRunYouthGroup)
            }

            Section("Example: Pro Feature Gate") {
                if entitlementsService.entitlements.isPro {
                    Text("✅ Pro feature unlocked!")
                        .foregroundStyle(.green)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("🔒 This is a Pro feature")
                            .foregroundStyle(.secondary)
                        Button("Upgrade to Pro") {
                            // TODO: Present subscription paywall
                            print("Show subscription paywall")
                        }
                    }
                }
            }

            Section("Example: Pastor-Only Feature") {
                if entitlementsService.entitlements.isPastor {
                    NavigationLink("Youth Group Management") {
                        Text("Pastor dashboard")
                    }
                } else {
                    Text("Pastor access required")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Debug Actions") {
                Button("Force Refresh") {
                    Task {
                        await entitlementsService.refresh()
                    }
                }

                Button("Force Heartbeat") {
                    Task {
                        await entitlementsService.forceHeartbeat()
                    }
                }

                if let lastRefresh = entitlementsService.lastRefreshDate {
                    Text("Last refresh: \(lastRefresh, format: .dateTime)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Entitlements Example")
    }
}

struct EntitlementRow: View {
    let label: String
    let value: Bool

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Image(systemName: value ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(value ? .green : .secondary)
        }
    }
}

#Preview {
    NavigationStack {
        EntitlementsExampleView()
            .environment(EntitlementsService.shared)
    }
}
