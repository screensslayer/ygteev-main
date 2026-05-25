//
//  JoinGroupMapView.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/6/26.
//

import SwiftUI
import MapKit
import Supabase
import AVFoundation
import UIKit

struct JoinGroupMapView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPin: YouthGroupMapPin?
    @State private var showGroupProfile = false
    @State private var showQRScanner = false
    @State private var showSubmissionForm = false
    @State private var hasLoadedGroups = false
    /// Tapped public event surfaced by the carousel below the groups
    /// list. Drives the RSVP sheet via `.sheet(item:)`.
    @State private var selectedPublicEvent: PublicEventNearby?
    /// Holds the in-flight pan/zoom reload so the next camera move
    /// can cancel it. Means only the final region the user settles on
    /// actually triggers a network round-trip.
    @State private var reloadTask: Task<Void, Never>?
    /// The "Events Near Me" detent sheet stays presented for the
    /// entire lifetime of this view. The user can drag between the
    /// three detents but never close it via gesture — `interactive
    /// DismissDisabled` enforces that.
    @State private var sheetPresented = true
    /// Tracks which detent the sheet is currently sitting at. We
    /// pass `sheetDetent == minimizedDetent` into EventsNearMeSheet
    /// as `isMinimized` so it can omit the carousel + CTA from the
    /// view tree at the smallest detent (avoids any visual leak past
    /// the clip). Initial value is the expanded detent so the map
    /// opens with the carousel already in view.
    @State private var sheetDetent: PresentationDetent = .fraction(0.35)
    private let minimizedDetent: PresentationDetent = .height(110)
    /// Populated when the QR scanner returns a payload and the
    /// `join_group_via_qr_scan` RPC succeeds. Drives the success sheet.
    @State private var joinResult: JoinResult?
    /// Friendly error message rendered as an alert after a bad QR or a
    /// failed join RPC. Self-clears via the alert's OK button.
    @State private var scanError: String?
    
    var locationService = LocationService.shared
    var groupService = YouthGroupService.shared
    
    var body: some View {
        ZStack {
            // State machine for permission and data loading
            if locationService.authorizationStatus == .notDetermined {
                // Permission not yet asked
                permissionRequestView
            } else if locationService.authorizationStatus == .denied || locationService.authorizationStatus == .restricted {
                // Permission denied
                permissionDeniedView
            } else if locationService.coordinate == nil {
                // Permission granted but no coordinate yet
                loadingView
            } else if let userCoordinate = locationService.coordinate {
                // Permission granted + coordinate: show map
                mapView(userCoordinate: userCoordinate)
            }
        }
        .task {
            locationService.requestAuthorizationAndStart()
        }
        .onChange(of: locationService.coordinate?.latitude) { _, _ in
            // When the first coordinate arrives, load nearby groups
            // and the public-events carousel from the same center
            // so both lists agree on what "nearby" means.
            if let coord = locationService.coordinate, !hasLoadedGroups {
                hasLoadedGroups = true
                Task {
                    async let groups: Void = groupService.loadNearby(lat: coord.latitude, lng: coord.longitude)
                    async let events: Void = groupService.loadPublicEvents(lat: coord.latitude, lng: coord.longitude)
                    _ = await (groups, events)
                }
            }
        }
        // Always-open Apple-Maps-style detent sheet. Every other modal
        // (event detail, group profile, QR scanner, submission form,
        // success alert) attaches INSIDE this sheet's content so they
        // stack cleanly on top of the persistent panel instead of
        // fighting it for root-level presentation.
        .sheet(isPresented: $sheetPresented) {
            EventsNearMeSheet(
                isMinimized: sheetDetent == minimizedDetent,
                events: groupService.publicEvents,
                onTapEvent: { ev in selectedPublicEvent = ev },
                onAddGroupTap: { showSubmissionForm = true }
            )
            .sheet(item: $selectedPublicEvent) { ev in
                PublicEventRSVPSheet(event: ev) { status in
                    try await groupService.rsvpPublicEvent(ev.eventId, status: status)
                }
            }
            .sheet(isPresented: $showGroupProfile) {
                if let pin = selectedPin {
                    GroupPublicProfileLoader(pin: pin)
                }
            }
            .sheet(isPresented: $showQRScanner) {
                QRScannerView { scanned in
                    showQRScanner = false
                    handleScannedCode(scanned)
                }
            }
            .sheet(item: $joinResult) { result in
                JoinSuccessSheet(result: result) {
                    joinResult = nil
                    // Pop the map back to wherever it was presented
                    // from so the user lands on their groups view.
                    dismiss()
                }
            }
            .alert("Couldn't join",
                   isPresented: Binding(
                    get: { scanError != nil },
                    set: { if !$0 { scanError = nil } }
                   ),
                   actions: { Button("OK") { scanError = nil } },
                   message: { Text(scanError ?? "") })
            .sheet(isPresented: $showSubmissionForm) {
                AddMyGroupSheet()
            }
            // Two-detent stack: a header-only minimized state that
            // shows just the "Events Near Me" bar with no carousel
            // bleeding through, and an expanded ~40% sheet that
            // surfaces the carousel + add-group button.
            // `interactiveDismissDisabled` means dragging down stops
            // at the minimized detent instead of closing the sheet;
            // `presentationBackgroundInteraction(.enabled)` keeps
            // the map fully pannable at every detent. The brand
            // violet→pink gradient fills the whole sheet surface so
            // the white title + white CTA read legibly.
            .presentationDetents(
                // Expanded detent at 0.3 so the open sheet sits tight
                // against the bottom edge — just enough for one row
                // of event cards + the CTA.
                [minimizedDetent, .fraction(0.35)],
                selection: $sheetDetent
            )
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled)
            .interactiveDismissDisabled()
            .presentationBackground { YGColors.violetPinkGradient }
        }
    }
    
    // MARK: - Permission Request View
    var permissionRequestView: some View {
        ZStack {
            Color.black.opacity(0.05)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(YGColors.violet)
                
                VStack(spacing: 8) {
                    Text("Find Youth Groups Near You")
                        .font(.lilitaOne(size: 24))
                        .tracking(-0.5)
                        .foregroundStyle(YGColors.ink)
                    
                    Text("We need your location to show youth groups within 25 miles of you.")
                        .font(.system(size: 15))
                        .foregroundStyle(YGColors.ink.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                Button {
                    locationService.requestAuthorizationAndStart()
                } label: {
                    Text("Enable Location")
                        .font(.lilitaOne(size: 18))
                        .tracking(-0.3)
                }
                .buttonStyle(.primary)
                .frame(width: 220, height: 56)
            }
            .padding(32)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.1), radius: 20)
            .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Permission Denied View
    var permissionDeniedView: some View {
        ZStack {
            Color.black.opacity(0.05)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "location.slash.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(YGColors.ink.opacity(0.3))
                
                VStack(spacing: 8) {
                    Text("Location Access Needed")
                        .font(.lilitaOne(size: 24))
                        .tracking(-0.5)
                        .foregroundStyle(YGColors.ink)
                    
                    Text("Open Settings to enable location access so we can show youth groups near you.")
                        .font(.system(size: 15))
                        .foregroundStyle(YGColors.ink.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Open Settings")
                        .font(.lilitaOne(size: 18))
                        .tracking(-0.3)
                }
                .buttonStyle(.primary)
                .frame(width: 220, height: 56)
                
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(YGColors.ink.opacity(0.6))
                }
            }
            .padding(32)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.1), radius: 20)
            .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Loading View
    var loadingView: some View {
        ZStack {
            Color.black.opacity(0.05)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(YGColors.violet)
                
                Text("Finding your location...")
                    .font(.system(size: 15))
                    .foregroundStyle(YGColors.ink.opacity(0.7))
            }
        }
    }
    
    // MARK: - Map View
    func mapView(userCoordinate: CLLocationCoordinate2D) -> some View {
        ZStack {
            // Locked radius map
            LockedRadiusMapView(
                userCoordinate: userCoordinate,
                pins: groupService.nearbyPins,
                onPinTap: { pin in
                    selectedPin = pin
                    showGroupProfile = true
                },
                onCameraChange: { region in
                    scheduleReload(center: region.center, span: region.span)
                }
            )
            .ignoresSafeArea()
            
            VStack {
                // Top bar — X on the left, "Youth Group Finder" title
                // centered, QR scanner on the right. The title sits
                // over the map with a soft shadow so it stays legible
                // against any underlying tile color.
                ZStack {
                    Text("Youth Group Finder")
                        .font(.lilitaOne(size: 22))
                        .tracking(-0.3)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.45), radius: 6, y: 1)
                        .frame(maxWidth: .infinity, alignment: .center)

                    HStack(spacing: 10) {
                        Button {
                            dismiss()
                        } label: {
                            Circle()
                                .fill(Color.white.opacity(0.55))
                                .frame(width: 38, height: 38)
                                .liquidGlass()
                                .clipShape(Circle())
                                .overlay {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(YGColors.ink)
                                }
                        }

                        Spacer()

                        Button {
                            showQRScanner = true
                        } label: {
                            Circle()
                                .fill(Color.white.opacity(0.55))
                                .frame(width: 38, height: 38)
                                .liquidGlass()
                                .clipShape(Circle())
                                .overlay {
                                    Image(systemName: "qrcode.viewfinder")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(YGColors.ink)
                                }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)

                Spacer()
            }
        }
    }

    // MARK: - Pan/zoom reload
    //
    // Cancels any in-flight reload, sleeps 250ms to coalesce the burst
    // of camera-change events that fire when programmatic moves chain
    // into manual pans, then re-queries both nearby lists with a radius
    // derived from the visible region's span.
    private func scheduleReload(center: CLLocationCoordinate2D, span: MKCoordinateSpan) {
        reloadTask?.cancel()
        reloadTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            if Task.isCancelled { return }

            // Translate span (in degrees) into a query radius (in
            // meters). 111km/degree is close enough for non-arctic
            // regions; halve it because we want radius from center,
            // not the full edge.
            let degrees = max(span.latitudeDelta, span.longitudeDelta)
            let radiusM = Int((degrees * 111_000) / 2)
            // Clamp: ≥5km so super-zoomed-in views still find something,
            // ≤200km so a near-world view doesn't drag in thousands of
            // rows.
            let clamped = max(5_000, min(radiusM, 200_000))

            async let groups: Void = groupService.loadNearby(
                lat: center.latitude,
                lng: center.longitude,
                meters: Double(clamped)
            )
            async let events: Void = groupService.loadPublicEvents(
                lat: center.latitude,
                lng: center.longitude,
                radiusM: clamped
            )
            _ = await (groups, events)
        }
    }

    // MARK: - QR scan → instant-join

    /// Standard 8-4-4-4-12 UUID pattern, case-insensitive. Compiled
    /// once and reused so every scan doesn't pay the build cost.
    private static let uuidRegex: NSRegularExpression = {
        let pattern = "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    /// Pull a group UUID out of a scanned payload, regardless of how
    /// the QR encodes it: raw UUID, path component (/g/<uuid>,
    /// /groups/<uuid>, /join/<uuid>), query parameter (?group=,
    /// ?id=, ?gid=), custom scheme (ygteev://…), or noisy input
    /// with extra whitespace/punctuation. One regex pass finds the
    /// first UUID-shaped substring anywhere in the string.
    private func parseScannedGroupId(_ raw: String) -> UUID? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Fast path: the whole thing is already a UUID.
        if let direct = UUID(uuidString: trimmed) { return direct }

        let ns = trimmed as NSString
        let range = NSRange(location: 0, length: ns.length)
        if let match = Self.uuidRegex.firstMatch(in: trimmed, options: [], range: range) {
            return UUID(uuidString: ns.substring(with: match.range))
        }
        return nil
    }

    /// Parse → call the join RPC → refresh memberships → show the
    /// confirmation sheet. Any failure flips `scanError` instead of
    /// blocking the user from scanning again.
    private func handleScannedCode(_ raw: String) {
        guard let groupId = parseScannedGroupId(raw) else {
            scanError = "That QR code doesn't look like a YGTeeV group code."
            return
        }

        Task {
            do {
                struct P: Encodable { let _group_id: String }
                struct R: Decodable {
                    let ok: Bool
                    let group_id: UUID
                    let group_name: String
                    let already_member: Bool
                    let newly_joined: Bool
                }
                let resp: R = try await SupabaseManager.shared.client
                    .rpc("join_group_via_qr_scan",
                         params: P(_group_id: groupId.uuidString.lowercased()))
                    .execute()
                    .value

                // Refresh the source-of-truth memberships list so the
                // group appears in the home top-bar + everywhere else.
                try? await EventsService.shared.loadMyMemberships()
                await EntitlementsService.shared.refreshAfterYouthGroupChange()

                await MainActor.run {
                    joinResult = JoinResult(
                        groupId: resp.group_id,
                        groupName: resp.group_name,
                        alreadyMember: resp.already_member
                    )
                }
            } catch {
                print("[QR] join failed:", error)
                let raw = error.localizedDescription.lowercased()
                let message: String
                if raw.contains("not_authenticated") {
                    message = "Please sign in first."
                } else if raw.contains("group_not_found") {
                    message = "We can't find that group. Double-check the QR code."
                } else if raw.contains("group_not_public") || raw.contains("permission denied") {
                    message = "That group is unlisted — ask the pastor for an invite."
                } else {
                    message = "Couldn't join that group. Try again, or ask the pastor for help."
                }
                await MainActor.run { scanError = message }
            }
        }
    }
}

// MARK: - Join confirmation

struct JoinResult: Identifiable {
    let id = UUID()
    let groupId: UUID
    let groupName: String
    let alreadyMember: Bool
}

struct JoinSuccessSheet: View {
    let result: JoinResult
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text(result.alreadyMember
                 ? "You're already in \(result.groupName)"
                 : "Welcome to \(result.groupName)!")
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
            if !result.alreadyMember {
                Text("You're now a member. You'll see their plans, events, and chat threads.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            Spacer().frame(height: 8)
            Button(action: onDone) {
                Text("Open Group")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(YGColors.violet, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .presentationDetents([.fraction(0.4)])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Group Preview Card
struct GroupPreviewCard: View {
    let pin: YouthGroupMapPin
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    GroupAvatar(logoUrl: pin.logoUrl, size: 42, cornerRadius: 42 * 0.28) {
                        YGGroupIcon(pin: pin, size: 42)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(pin.name)
                            .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(YGColors.ink)
                            .lineLimit(1)
                        
                        Text("\(pin.distanceLabel) · \(pin.memberCount) members")
                            .font(.system(size: 12))
                            .foregroundStyle(YGColors.ink.opacity(0.55))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                HStack(spacing: 6) {
                    Tag(text: GroupAudience.label(groupType: pin.groupType, grades: pin.grades))
                    Tag(text: pin.meetingTime ?? "TBD")
                }
            }
            .padding(14)
            .frame(width: 200)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
            }
            .shadow(color: YGColors.ink.opacity(0.06), radius: 4)
        }
    }
}

struct Tag: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(YGColors.violet)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(YGColors.violet.opacity(0.08))
            .clipShape(Capsule())
    }
}

// MARK: - Group Public Profile Loader
struct GroupPublicProfileLoader: View {
    let pin: YouthGroupMapPin
    @State private var profile: YouthGroupPublicProfile?
    @State private var isLoading = true
    @State private var loadError: String?
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading group details...")
                        .font(.system(size: 15))
                        .foregroundStyle(YGColors.ink.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(YGColors.paper)
            } else if let error = loadError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(YGColors.ink.opacity(0.3))
                    Text(error)
                        .font(.system(size: 15))
                        .foregroundStyle(YGColors.ink.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(YGColors.paper)
            } else if let profile = profile {
                GroupPublicProfileView(pin: pin, profile: profile)
            }
        }
        .task {
            do {
                profile = try await YouthGroupService.shared.loadPublicProfile(groupId: pin.id)
                isLoading = false
            } catch {
                loadError = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// MARK: - Group Public Profile
struct GroupPublicProfileView: View {
    let pin: YouthGroupMapPin
    let profile: YouthGroupPublicProfile
    @Environment(\.dismiss) private var dismiss
    @State private var isSubmittingJoin = false
    @State private var joinError: String?
    @State private var showJoinConfirmation = false
    @State private var showErrorAlert = false
    @State private var joinedStatus: String?
    @State private var showQRScanner = false
    /// Locally tracks a fresh "request sent" state so the bottom CTA flips
    /// immediately after the RPC succeeds — without waiting for a re-fetch.
    @State private var locallyRequested = false

    /// True if the user already belongs to this group.
    private var isMember: Bool { profile.viewerIsMember }
    /// True if there's an existing pending request (from the RPC) or we just
    /// submitted one in this session.
    private var hasPendingRequest: Bool {
        profile.viewerPendingRequest || locallyRequested
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Hero section
                    Rectangle()
                        .fill(profile.gradient)
                        .frame(height: 200)
                        .overlay {
                            // Abstract shapes
                            Circle()
                                .fill(.white.opacity(0.18))
                                .frame(width: 180, height: 180)
                                .offset(x: 100, y: -40)
                            
                            Circle()
                                .fill(.black.opacity(0.12))
                                .frame(width: 120, height: 120)
                                .offset(x: -60, y: 120)
                        }
                        .clipped()
                    
                    // Content
                    VStack(alignment: .leading, spacing: 0) {
                        // Group icon overlapping hero — logo if set, gradient+initials otherwise
                        GroupAvatar(logoUrl: profile.logoUrl, size: 80, cornerRadius: 80 * 0.28) {
                            YGGroupIcon(pin: pin, size: 80)
                        }
                        .overlay {
                            if profile.logoUrl?.isEmpty == false {
                                RoundedRectangle(cornerRadius: 80 * 0.28)
                                    .strokeBorder(Color.white, lineWidth: 4)
                            }
                        }
                        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
                        .offset(y: -32)
                        .padding(.leading, 20)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text(profile.name)
                                .font(.lilitaOne(size: 26))
                                .tracking(-0.5)
                                .foregroundStyle(YGColors.ink)
                            
                            HStack(spacing: 6) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 13))
                                
                                Text("\(profile.churchName) · \(pin.distanceLabel) away")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(YGColors.ink.opacity(0.55))
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, -16)
                        
                        // About
                        Text(profile.description)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(YGColors.ink.opacity(0.85))
                            .lineSpacing(5)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        
                        // Leaders
                        if !profile.leaders.isEmpty {
                            Text("Leaders")
                                .font(.lilitaOne(size: 16))
                                .tracking(-0.3)
                                .foregroundStyle(YGColors.ink)
                                .padding(.horizontal, 20)
                                .padding(.top, 24)
                                .padding(.bottom, 12)
                            
                            HStack(spacing: 14) {
                                ForEach(profile.leaders) { leader in
                                    VStack(spacing: 6) {
                                        if let urlString = leader.avatarUrl, !urlString.isEmpty, let url = URL(string: urlString) {
                                            AsyncImage(url: url) { phase in
                                                switch phase {
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 54, height: 54)
                                                        .clipShape(Circle())
                                                        .overlay {
                                                            Circle()
                                                                .strokeBorder(.white, lineWidth: 2)
                                                        }
                                                case .failure, .empty:
                                                    YGAvatar(name: leader.displayName ?? "—", size: 54)
                                                @unknown default:
                                                    YGAvatar(name: leader.displayName ?? "—", size: 54)
                                                }
                                            }
                                        } else {
                                            YGAvatar(name: leader.displayName ?? "—", size: 54)
                                        }
                                        
                                        Text(leader.displayName ?? "—")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(YGColors.ink)
                                        
                                        Text(leader.role.capitalized)
                                            .font(.system(size: 11))
                                            .foregroundStyle(YGColors.ink.opacity(0.5))
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Upcoming Events
                        if !profile.upcomingEvents.isEmpty {
                            Text("Upcoming Events")
                                .font(.lilitaOne(size: 16))
                                .tracking(-0.3)
                                .foregroundStyle(YGColors.ink)
                                .padding(.horizontal, 20)
                                .padding(.top, 24)
                                .padding(.bottom, 12)
                            
                            VStack(spacing: 8) {
                                ForEach(profile.upcomingEvents) { event in
                                    GroupProfileEventRow(
                                        title: event.title,
                                        date: event.startsAt.formatted(.dateTime.month(.abbreviated).day()),
                                        time: event.startsAt.formatted(.dateTime.hour().minute()),
                                        location: event.location ?? "TBD"
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        Spacer(minLength: 140)
                    }
                    .padding(.bottom, 100)
                }
            }
            .background(YGColors.paper)
            .ignoresSafeArea()
            
            // Bottom CTA — four states. Server-computed `viewerIsMember`
            // and `viewerPendingRequest` take priority; otherwise we
            // additionally gate the join button on grade eligibility so
            // we never round-trip a doomed request.
            let viewerGrade = SupabaseManager.shared.currentUser?.gradeYear
            let eligible = GroupAudience.viewerIsEligible(
                viewerGradeYear: viewerGrade,
                groupGrades: profile.grades
            )

            VStack {
                Spacer()

                if isMember {
                    // Member: small confirmation chip, no CTA.
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .bold))
                        Text("You're a member")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.green)
                    .clipShape(Capsule())
                    .padding(.bottom, 40)
                } else if hasPendingRequest {
                    // Pending: disabled "Request sent" pill.
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                        Text("Request sent")
                            .font(.lilitaOne(size: 18))
                            .tracking(-0.3)
                    }
                    .foregroundStyle(YGColors.ink.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(YGColors.ink.opacity(0.08))
                    .clipShape(Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(YGColors.ink.opacity(0.12), lineWidth: 1)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                } else if !eligible {
                    // Viewer's grade is outside the group's accepted range —
                    // disable the CTA and explain who the group is for.
                    Text(GroupAudience.ineligibleCTA(
                        groupType: profile.groupType,
                        grades: profile.grades
                    ))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(YGColors.ink.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(YGColors.ink.opacity(0.06))
                        .clipShape(Capsule())
                        .overlay {
                            Capsule()
                                .strokeBorder(YGColors.ink.opacity(0.12), lineWidth: 1)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                } else {
                    // Non-member, no pending request: the original CTA.
                    Button {
                        Task {
                            isSubmittingJoin = true
                            do {
                                let req = try await YouthGroupService.shared
                                    .requestToJoin(groupId: profile.id)
                                joinedStatus = req.status
                                // Flip the CTA immediately so the user sees the new state.
                                locallyRequested = true
                                showJoinConfirmation = true
                            } catch {
                                joinError = friendlyJoinError(error.localizedDescription)
                                showErrorAlert = true
                            }
                            isSubmittingJoin = false
                        }
                    } label: {
                        if isSubmittingJoin {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Request to Join")
                                .font(.lilitaOne(size: 18))
                                .tracking(-0.3)
                        }
                    }
                    .buttonStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                    .disabled(isSubmittingJoin)
                }
            }
        }
        .sheet(isPresented: $showQRScanner) {
            QRScannerView()
        }
        .alert("Request sent!", isPresented: $showJoinConfirmation) {
            Button("Got it") {
                dismiss()
            }
        } message: {
            if joinedStatus == "approved" {
                Text("You're in! Welcome to \(profile.name).")
            } else {
                Text("Your request is pending — pastors will be notified.")
            }
        }
        .alert("Unable to Join", isPresented: $showErrorAlert) {
            Button("OK") { }
        } message: {
            if let error = joinError {
                Text(error)
            }
        }
    }
    
    func friendlyJoinError(_ msg: String) -> String {
        switch msg {
        case let s where s.contains("already_member"):
            return "You're already a member of this group."
        case let s where s.contains("group_not_public"):
            return "This group isn't currently accepting requests."
        case let s where s.contains("cannot_request_default_group"):
            return "You can't request to join the default group."
        case let s where s.contains("grade_not_eligible"):
            return "This group is for a different grade range."
        case let s where s.contains("not_authenticated"):
            return "Please sign in first."
        default:
            return "Something went wrong. Try again."
        }
    }
}

/// Simple row used in the public-profile sheet's "Upcoming Events"
/// list. Distinct from the carousel-style `PublicEventCard` used on
/// the map's bottom sheet.
struct GroupProfileEventRow: View {
    let title: String
    let date: String
    let time: String
    let location: String

    var body: some View {
        HStack(spacing: 12) {
            Text("📅")
                .font(.system(size: 28))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(YGColors.ink)
                
                HStack(spacing: 4) {
                    Text(date)
                        .font(.system(size: 13))
                    Text("·")
                    Text(time)
                        .font(.system(size: 13))
                    Text("·")
                    Text(location)
                        .font(.system(size: 13))
                }
                .foregroundStyle(YGColors.ink.opacity(0.6))
            }
            
            Spacer()
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.black.opacity(0.05), lineWidth: 0.5)
        }
    }
}

// MARK: - QR Scanner View
struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    /// Fires the first time a QR code is decoded. Caller is responsible
    /// for dismissing this sheet — we don't auto-dismiss so the caller
    /// has a chance to validate the payload before tearing down the
    /// scanner. Defaults to a no-op so existing call sites still
    /// compile without behavior change.
    var onScan: ((String) -> Void)? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Live camera feed driving the metadata callback. When
            // `onScan` is nil, the scanner still runs (so it doesn't
            // look broken in legacy presentations) but its output is
            // dropped.
            GroupQRCameraView { payload in
                onScan?(payload)
            }
            .ignoresSafeArea()

            // Reticle + corner brackets
            VStack {
                Spacer()

                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(.white.opacity(0.3), lineWidth: 3)
                    .frame(width: 250, height: 250)
                    .overlay {
                        ForEach(0..<4) { i in
                            CornerBracket(position: i)
                        }
                    }

                Spacer()

                VStack(spacing: 8) {
                    Text("Scan to instant-join")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))

                    Text("Ask a leader for the group's QR — usually printed on the lobby table.")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .foregroundStyle(.white)
                .padding(.bottom, 60)
            }

            // Top bar
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Circle()
                            .fill(Color.white.opacity(0.45))
                            .frame(width: 38, height: 38)
                            .liquidGlass(dark: true)
                            .clipShape(Circle())
                            .overlay {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                    }

                    Spacer()

                    Text("Hold steady on group's QR")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .liquidGlass(dark: true)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)

                Spacer()
            }
        }
    }
}

// MARK: - AVFoundation camera bridge for the group-join scanner.
// Lives here so the existing `FamilyQRScanner.CameraView` stays
// fileprivate to its own module.

private struct GroupQRCameraView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> GroupQRScannerVC {
        let vc = GroupQRScannerVC()
        vc.onScan = onScan
        return vc
    }

    func updateUIViewController(_ uiViewController: GroupQRScannerVC, context: Context) {}
}

private final class GroupQRScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var preview: AVCaptureVideoPreviewLayer?
    private var hasFired = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasFired = false
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.stopRunning()
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview?.frame = view.bounds
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        preview = layer
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !hasFired,
              let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              obj.type == .qr,
              let value = obj.stringValue else { return }
        hasFired = true
        onScan?(value)
    }
}

struct CornerBracket: View {
    let position: Int
    
    var body: some View {
        let size: CGFloat = 28
        
        Path { path in
            path.move(to: CGPoint(x: size, y: 0))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 0, y: size))
        }
        .stroke(YGColors.violet, lineWidth: 3)
        .frame(width: size, height: size)
        .rotationEffect(.degrees(Double(position) * 90))
        .offset(
            x: position == 1 || position == 2 ? 111 : -111,
            y: position >= 2 ? 111 : -111
        )
    }
}

#Preview("Map") {
    JoinGroupMapView()
}

#Preview("QR Scanner") {
    QRScannerView()
}
