//
//  FromYouthGroupSection.swift
//  YGTeeV
//
//  Container on the member's Plans tab. When the user is in no real
//  youth group, it renders the green "Join A Group" CTA. When the
//  user is in one or more real groups, it iterates the memberships in
//  API order and renders a `GroupSectionCard` per group — each card
//  owns its own Plans/Events + Active/Completed state so they don't
//  interfere with each other.
//
//  The default YGTeeV group is filtered out: per the entitlements
//  rules, that group's membership doesn't grant Pro and shouldn't get
//  its own panel here.
//

import SwiftUI

struct FromYouthGroupSection: View {
    @State private var plansService = PlansService.shared
    @State private var eventsService = EventsService.shared
    @State private var showJoinMap = false

    /// Real (non-default) memberships in the order the API returned
    /// them. `EventsService.myMemberships` is hydrated by the plans
    /// tab's parent refresh chain; we just slice + filter here.
    private var realMemberships: [MyGroupMembership] {
        eventsService.myMemberships.filter { !$0.isDefaultYgteev }
    }

    var body: some View {
        Group {
            if !plansService.hasCheckedMembership {
                // First check of this app session hasn't returned yet
                // — render nothing for one frame so users in a group
                // never see the green Join card flash by. After the
                // first check, the flag stays true for the rest of
                // the session.
                Color.clear.frame(height: 1)
            } else if realMemberships.isEmpty {
                joinGroupCard
            } else {
                VStack(spacing: 16) {
                    ForEach(realMemberships) { membership in
                        GroupSectionCard(membership: membership)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .task { await refresh() }
        .fullScreenCover(isPresented: $showJoinMap) {
            JoinGroupMapView()
        }
    }

    // MARK: - Refresh
    //
    // Fires on every appearance. The membership check is idempotent
    // and fast; the plan loads silently replace the cached rows on
    // success and leave them alone on failure (PlansService writes
    // only on the happy path). The view never goes through a "blank"
    // state on re-entry because both the gate (`hasCheckedMembership`)
    // and the row data (`youthGroupPlans`) live on the singleton.
    private func refresh() async {
        await plansService.checkInAnyYouthGroup()
        guard plansService.inAnyYouthGroup else { return }
        // Plans data — single round-trip per filter loads ALL the
        // user's groups; each `GroupSectionCard` filters the flat
        // result locally by `groupId`.
        await plansService.loadYouthGroupPlans(filter: "available")
        await plansService.loadYouthGroupPlans(filter: "completed")
    }

    // MARK: - Join group card (no real groups)

    private var joinGroupCard: some View {
        Button { showJoinMap = true } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    LinearGradient(
                        colors: [Color(hex: "B4FF3C"), Color(hex: "00C6A2")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )

                    VStack(spacing: 8) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.white)
                        Text("Join A Group")
                            .font(.lilitaOne(size: 22))
                            .foregroundStyle(.white)
                        Text("Find a youth group near you")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(20)
                }
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal, 20)
            }
        }
        .buttonStyle(.plain)
    }
}
