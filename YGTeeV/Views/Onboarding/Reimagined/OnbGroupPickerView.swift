//
//  OnbGroupPickerView.swift
//  YGTeeV
//
//  M3 — Group picker. First real emotional peak after the "who
//  brought you here?" question: crews near you, real + discovered,
//  with the YGTeeV flagship always pinned at the top.
//
//  Flow states:
//    • `.awaitingPermission` — asked iOS on appear; waiting for
//      the user's answer.
//    • `.loading`             — permission granted (or a city was
//      geocoded), RPC in flight.
//    • `.results`             — list of NearbyGroups is displayed.
//    • `.searchFallback`      — permission denied; a "Search by
//      city" TextField takes over.
//    • `.error`               — RPC or geocode blew up; retry.
//
//  Selection UX: tapping a row sets `state.selectedGroup` — a violet
//  border + checkmark shows it's picked. The actual `joinGroup`
//  RPC doesn't fire here; it runs post-auth in Phase 4. The bottom
//  CTA is `Continue` if a selection is made, `Skip for now` if not
//  (the user auto-lands in the default YGTeeV group either way via
//  the signup trigger).
//
//  No animation beyond the row selection tick.
//

import SwiftUI
import CoreLocation

struct OnbGroupPickerView: View {
    @Bindable var state: ReimaginedOnboardingState
    let advance: () -> Void

    @State private var loc = LocationService.shared
    private let service = OnboardingService.shared

    @State private var phase: Phase = .awaitingPermission
    @State private var errorText: String?
    @State private var cityQuery: String = ""
    @State private var isGeocoding = false

    private enum Phase {
        case awaitingPermission
        case loading
        case results
        case searchFallback
        case error
    }

    // MARK: - Sorted groups (default first, real by distance, discovered by distance)

    private var sortedGroups: [NearbyGroup] {
        // RPC already returns default at top; we re-sort defensively
        // in case the wire order ever changes.
        let all = state.nearbyGroups
        let defaults = all.filter { $0.isDefault }
        let realGroups = all.filter { $0.kind == "real" && !$0.isDefault }
            .sorted { ($0.distanceMiles ?? .greatestFiniteMagnitude)
                    < ($1.distanceMiles ?? .greatestFiniteMagnitude) }
        let discovered = all.filter { $0.kind == "discovered" }
            .sorted { ($0.distanceMiles ?? .greatestFiniteMagnitude)
                    < ($1.distanceMiles ?? .greatestFiniteMagnitude) }
        return defaults + realGroups + discovered
    }

    private var hasNoRealOrDiscovered: Bool {
        !sortedGroups.contains { !$0.isDefault }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 20)

            content

            Spacer(minLength: 0)

            bottomCTA
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(YGColors.paper)
        .task { await start() }
        .onChange(of: loc.authorizationStatus) { _, newStatus in
            Task { await handleAuthChange(newStatus) }
        }
        .onChange(of: loc.coordinate?.latitude) { _, _ in
            if phase == .loading, let c = loc.coordinate {
                Task { await fetchGroups(at: c) }
            }
        }
    }

    // MARK: - Chrome

    private var header: some View {
        VStack(spacing: 6) {
            Text("M3 · GROUP")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(YGColors.violet)
            Text("Find your crew.")
                .font(.lilitaOne(size: 30))
                .foregroundStyle(YGColors.ink)
            Text("Youth groups near you. The YGTeeV flagship is on the house — you can leave any time.")
                .font(.system(size: 14))
                .foregroundStyle(YGColors.ink.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .awaitingPermission:
            waitingCard(label: "Checking your area…")
        case .loading:
            waitingCard(label: "Finding crews near you…")
        case .results:
            resultsList
        case .searchFallback:
            searchFallback
        case .error:
            errorCard
        }
    }

    private func waitingCard(label: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(YGColors.ink.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private var errorCard: some View {
        VStack(spacing: 12) {
            Text(errorText ?? "Something went wrong.")
                .font(.system(size: 13))
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
            Button("Try again") {
                Task { await start() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Results list

    private var resultsList: some View {
        ScrollView {
            VStack(spacing: 10) {
                if hasNoRealOrDiscovered {
                    Text("No crews near you yet — you'll be part of the YGTeeV flagship group. You can find one later on the map.")
                        .font(.system(size: 13))
                        .foregroundStyle(YGColors.ink.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 4)
                }
                ForEach(sortedGroups) { group in
                    groupRow(group)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
        }
    }

    private func groupRow(_ group: NearbyGroup) -> some View {
        let isSelected = state.selectedGroup?.id == group.id
        return Button {
            state.selectedGroup = group
        } label: {
            HStack(spacing: 12) {
                avatar(for: group)
                    .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(group.name)
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(YGColors.ink)
                            .lineLimit(1)
                        if group.isDefault {
                            Text("FLAGSHIP")
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(YGColors.violet)
                                .clipShape(Capsule())
                        }
                    }
                    if let sub = subtitleFor(group) {
                        Text(sub)
                            .font(.system(size: 12))
                            .foregroundStyle(YGColors.ink.opacity(0.55))
                            .lineLimit(1)
                    }
                    HStack(spacing: 6) {
                        if let d = group.distanceMiles {
                            metaChip(String(format: "%.1f mi", d))
                        }
                        metaChip(secondaryMetric(for: group))
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text(ctaCopy(for: group))
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(YGColors.violet)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(YGColors.violet)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? YGColors.violet : Color.black.opacity(0.08),
                                  lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func avatar(for group: NearbyGroup) -> some View {
        Group {
            if let s = group.logoUrl, let url = URL(string: s) {
                CachedRemoteImage(url: url) { letterAvatar(for: group) }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                letterAvatar(for: group)
            }
        }
    }

    private func letterAvatar(for group: NearbyGroup) -> some View {
        let initial = String(group.name.prefix(1)).uppercased()
        return ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(group.isDefault ? YGColors.violet : YGColors.violet.opacity(0.6))
            Text(initial)
                .font(.lilitaOne(size: 20))
                .foregroundStyle(.white)
        }
    }

    private func metaChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(YGColors.ink.opacity(0.55))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.black.opacity(0.05))
            .clipShape(Capsule())
    }

    // MARK: - Row copy

    private func subtitleFor(_ group: NearbyGroup) -> String? {
        if let church = group.churchName, !church.isEmpty { return church }
        if let city = group.city, let stateAbbrev = group.state {
            return "\(city), \(stateAbbrev)"
        }
        return group.description
    }

    private func secondaryMetric(for group: NearbyGroup) -> String {
        if let count = group.memberCount, group.kind == "real" {
            return "\(count) member\(count == 1 ? "" : "s")"
        }
        if group.kind == "discovered" {
            return "\(group.boostCount) boost\(group.boostCount == 1 ? "" : "s")"
        }
        return "Community"
    }

    private func ctaCopy(for group: NearbyGroup) -> String {
        if group.isDefault { return "Join →" }
        switch group.kind {
        case "real":       return "Request →"
        case "discovered": return "Boost & follow →"
        default:           return "Continue →"
        }
    }

    // MARK: - Search fallback

    private var searchFallback: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Can't grab your location — no worries. Type in your city instead.")
                .font(.system(size: 13))
                .foregroundStyle(YGColors.ink.opacity(0.65))
                .padding(.horizontal, 20)

            HStack(spacing: 8) {
                TextField("City, state (e.g. Charlotte, NC)", text: $cityQuery)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.black.opacity(0.08), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .submitLabel(.search)
                    .onSubmit { Task { await geocodeAndFetch() } }

                Button {
                    Task { await geocodeAndFetch() }
                } label: {
                    if isGeocoding {
                        ProgressView().tint(.white)
                            .frame(width: 44, height: 44)
                    } else {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                    }
                }
                .background(cityQuery.isEmpty ? Color.gray.opacity(0.3) : YGColors.violet)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(cityQuery.isEmpty || isGeocoding)
            }
            .padding(.horizontal, 20)

            if let errorText {
                Text(errorText)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 20)
            }

            // Once a search returned results, show the same row list
            // right below the search field.
            if !state.nearbyGroups.isEmpty {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(sortedGroups) { group in
                            groupRow(group)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                }
            }
        }
    }

    // MARK: - Bottom CTA

    private var bottomCTA: some View {
        let hasSelection = state.selectedGroup != nil
        return Button(action: advance) {
            Text(hasSelection ? "Continue →" : "Skip for now →")
                .font(.lilitaOne(size: 18))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(hasSelection ? YGColors.violet : YGColors.violet.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Location + fetch lifecycle

    /// Kicks the flow off on view appear. If iOS already has an
    /// authorization decision, we skip straight to the appropriate
    /// state; otherwise we ask.
    private func start() async {
        errorText = nil
        switch loc.authorizationStatus {
        case .notDetermined:
            phase = .awaitingPermission
            loc.requestAuthorizationAndStart()
        case .authorizedWhenInUse, .authorizedAlways:
            phase = .loading
            loc.requestAuthorizationAndStart()
            if let c = loc.coordinate {
                await fetchGroups(at: c)
            }
            // else: onChange(coordinate) fires when it lands
        case .denied, .restricted:
            phase = .searchFallback
        @unknown default:
            phase = .searchFallback
        }
    }

    private func handleAuthChange(_ status: CLAuthorizationStatus) async {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            phase = .loading
            if let c = loc.coordinate {
                await fetchGroups(at: c)
            }
        case .denied, .restricted:
            phase = .searchFallback
        default:
            break
        }
    }

    private func fetchGroups(at c: CLLocationCoordinate2D) async {
        do {
            let groups = try await service.groupsNearMe(lat: c.latitude, lng: c.longitude)
            state.nearbyGroups = groups
            state.currentLocation = c
            phase = .results
        } catch {
            errorText = "Couldn't reach the group list. Try again in a sec."
            phase = .error
        }
    }

    /// Geocode the user's typed city + fetch groups near it. Used
    /// only when location permission is denied and the user is
    /// operating the search fallback.
    private func geocodeAndFetch() async {
        let query = cityQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        isGeocoding = true
        errorText = nil
        defer { isGeocoding = false }
        do {
            let placemarks = try await CLGeocoder().geocodeAddressString(query)
            guard let coord = placemarks.first?.location?.coordinate else {
                errorText = "Couldn't find that place. Try a nearby city?"
                return
            }
            await fetchGroups(at: coord)
        } catch {
            errorText = "Couldn't find that place. Try a nearby city?"
        }
    }
}
