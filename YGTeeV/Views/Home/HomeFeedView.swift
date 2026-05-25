//
//  HomeFeedView.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/6/26.
//

import SwiftUI
import PhotosUI

enum HomeTab: String, CaseIterable {
    case forYou = "For You"
    case events = "Events"
    case ranking = "Ranking"
}

struct HomeFeedView: View {
    @Environment(AppState.self) var appState
    @State private var currentVideoIndex = 0
    @State private var showJoinGroup = false
    @State private var selectedTab: HomeTab = .forYou
    @State private var selectedGroupId: UUID?
    
    var eventsService = EventsService.shared

    let videos = VideoPost.samplePosts

    var currentMembership: MyGroupMembership? {
        if let selectedId = selectedGroupId {
            return eventsService.myMemberships.first(where: { $0.groupId == selectedId })
        }
        return eventsService.myMemberships.first
    }

    var body: some View {
        ZStack {
            // Main content based on selected tab
            TabView(selection: $selectedTab) {
                ForYouFeedView(selectedGroupId: selectedGroupId)
                    .tag(HomeTab.forYou)

                EventsView(selectedGroupId: selectedGroupId)
                    .tag(HomeTab.events)

                RankingView(membership: currentMembership)
                    .tag(HomeTab.ranking)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Overlay UI
            VStack(spacing: 0) {
                // Top bar with logo and groups
                TopNavigationBar(
                    memberships: eventsService.myMemberships,
                    selectedGroupId: $selectedGroupId,
                    onPlusClick: {
                        showJoinGroup = true
                    }
                )
                .padding(.top, 60)

                // Tab selector
                TikTokStyleTabBar(selectedTab: $selectedTab)
                    .padding(.top, 8)

                Spacer()
            }

        }
        .ignoresSafeArea()
        .sheet(isPresented: $showJoinGroup) {
            JoinGroupMapView()
        }
        .task {
            do {
                try await eventsService.loadMyMemberships()
                // Default to first non-default group, or first group if all default
                if selectedGroupId == nil {
                    selectedGroupId = eventsService.myMemberships.first(where: { !$0.isDefaultYgteev })?.groupId
                        ?? eventsService.myMemberships.first?.groupId
                }
            } catch {
                print("Failed to load memberships: \(error)")
            }
        }
    }
}

// MARK: - Top Navigation Bar
struct TopNavigationBar: View {
    let memberships: [MyGroupMembership]
    @Binding var selectedGroupId: UUID?
    let onPlusClick: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(memberships) { membership in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                selectedGroupId = membership.groupId
                            }
                        } label: {
                            GroupIconButton(
                                membership: membership,
                                isActive: selectedGroupId == membership.groupId
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Plus button
                    Button(action: onPlusClick) {
                        RoundedRectangle(cornerRadius: 11)
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 38, height: 38)
                            .overlay {
                                RoundedRectangle(cornerRadius: 11)
                                    .strokeBorder(
                                        Color.white.opacity(0.55),
                                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
                                    )
                            }
                            .overlay {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Group Icon Button
struct GroupIconButton: View {
    let membership: MyGroupMembership
    let isActive: Bool

    var gradient: LinearGradient {
        let from = (membership.gradientFrom != nil ? Color(hex: membership.gradientFrom!) : nil) ?? YGColors.violet
        let to = (membership.gradientTo != nil ? Color(hex: membership.gradientTo!) : nil) ?? YGColors.pink
        return LinearGradient(colors: [from, to], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    var initials: String {
        membership.name.split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map { String($0) }
            .joined()
    }

    var body: some View {
        ZStack {
            if membership.isDefaultYgteev {
                // App icon image for default YGTeeV group
                Image("AppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 38, height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 8.5))
            } else if let logoUrl = membership.logoUrl, !logoUrl.isEmpty, let url = URL(string: logoUrl) {
                // Use logo if available
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 38, height: 38)
                            .clipShape(Circle())
                    case .failure, .empty:
                        // Fallback to initials
                        Circle()
                            .fill(gradient)
                            .frame(width: 38, height: 38)
                            .overlay {
                                Text(initials)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                    @unknown default:
                        Circle()
                            .fill(gradient)
                            .frame(width: 38, height: 38)
                            .overlay {
                                Text(initials)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                    }
                }
            } else {
                // Fallback to gradient + initials
                Circle()
                    .fill(gradient)
                    .frame(width: 38, height: 38)
                    .overlay {
                        Text(initials)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
            }

            if isActive {
                RoundedRectangle(cornerRadius: membership.isDefaultYgteev ? 10.5 : 50)
                    .strokeBorder(.white, lineWidth: 2.5)
                    .frame(width: 42, height: 42)
            }
        }
    }
}

// MARK: - TikTok Style Tab Bar
struct TikTokStyleTabBar: View {
    @Binding var selectedTab: HomeTab
    @Namespace private var animation

    var body: some View {
        HStack(spacing: 0) {
            ForEach(HomeTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(tab.rawValue)
                            .font(.system(size: 16, weight: selectedTab == tab ? .bold : .medium))
                            .foregroundStyle(.white)

                        if selectedTab == tab {
                            Rectangle()
                                .fill(.white)
                                .frame(width: 32, height: 2)
                                .matchedGeometryEffect(id: "tab", in: animation)
                        } else {
                            Rectangle()
                                .fill(.clear)
                                .frame(width: 32, height: 2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Plus Hint View
struct PlusHintView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            HStack {
                Spacer()

                VStack(alignment: .center, spacing: 4) {
                    // Arrow pointing up and slightly left
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 4)
                        .rotationEffect(.degrees(-45))
                        .offset(x: 8)

                    VStack(spacing: 2) {
                        Text("Find your youth group")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)

                        Text("Tap + to get started")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .background(Color.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .shadow(color: .black.opacity(0.3), radius: 8)

                    Button {
                        onDismiss()
                    } label: {
                        Text("Got it")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.trailing, 20)
            }
            .padding(.top, 110)

            Spacer()
        }
    }
}

// MARK: - For You View
struct ForYouView: View {
    let videos: [VideoPost]
    @Binding var currentIndex: Int
    let membership: MyGroupMembership?

    @State private var scrollPosition: Int? = 0

    var filteredVideos: [VideoPost] {
        if let membership = membership, !membership.isDefaultYgteev {
            return videos.filter { $0.groupId == membership.groupId.uuidString }
        } else {
            return videos
        }
    }

    var currentVideo: VideoPost {
        guard !filteredVideos.isEmpty else {
            return videos[0]
        }
        let safeIndex = min(currentIndex, filteredVideos.count - 1)
        return filteredVideos[safeIndex]
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(filteredVideos.enumerated()), id: \.offset) { index, video in
                        ZStack {
                            // Mux video player - fills entire screen
                            MuxVideoPlayer(
                                playbackId: video.playbackId,
                                isActive: index == currentIndex
                            )

                            VStack {
                                Spacer()

                                // Bottom caption only - no action buttons
                                VideoCaption(video: video, groupName: membership?.name ?? "YGTeeV")
                                    .padding(.leading, 18)
                                    .padding(.bottom, 100)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrollPosition)
            .onChange(of: scrollPosition) { _, newValue in
                if let newValue = newValue {
                    currentIndex = newValue
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            scrollPosition = currentIndex
        }
    }
}

// MARK: - Events View
struct EventsView: View {
    let selectedGroupId: UUID?
    
    @State private var selectedEventTab: EventTab = .upcoming
    @State private var showRSVPActionSheet = false
    @State private var selectedEvent: GroupEventFull?
    @State private var expandedEventId: UUID?
    @State private var showPhotosPicker = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var uploadProgress: (current: Int, total: Int)?
    @State private var uploadError: String?
    
    var eventsService = EventsService.shared
    
    enum EventTab: String {
        case upcoming = "Upcoming"
        case past = "Past"
    }
    
    var events: [GroupEventFull] {
        guard let groupId = selectedGroupId else { return [] }
        return eventsService.eventsByGroup[groupId] ?? []
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Scrollable content
            ScrollView {
                VStack(spacing: 16) {
                    if events.isEmpty {
                        Text("No \(selectedEventTab.rawValue.lowercased()) events")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.top, 80)
                    } else {
                        ForEach(events) { event in
                            BackendEventCard(
                                event: event,
                                isExpanded: expandedEventId == event.id,
                                onRSVPTap: {
                                    selectedEvent = event
                                    showRSVPActionSheet = true
                                },
                                onEventTap: {
                                    if event.isPast {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            expandedEventId = expandedEventId == event.id ? nil : event.id
                                        }
                                    }
                                },
                                onAddPhotos: {
                                    selectedEvent = event
                                    showPhotosPicker = true
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 180)
                .padding(.bottom, 120)
            }
            .background(Color.black)
            
            // Fixed header area with toggle
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: 110)
                
                HStack(spacing: 6) {
                    ForEach([EventTab.upcoming, EventTab.past], id: \.self) { tab in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                selectedEventTab = tab
                            }
                        } label: {
                            Text(tab.rawValue)
                                .font(.lilitaOne(size: 13.5))
                                .foregroundStyle(selectedEventTab == tab ? .black : .white.opacity(0.6))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedEventTab == tab ? .white : Color.clear)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(4)
                .background(.white.opacity(0.1))
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                }
                .padding(.vertical, 12)
                
                Spacer()
            }
            .background(
                VStack(spacing: 0) {
                    Color.black.opacity(0.85)
                        .frame(height: 110)
                    Spacer()
                }
                .ignoresSafeArea(edges: .top)
            )
            
            // Upload progress overlay
            if let progress = uploadProgress {
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                        Text("Uploading \(progress.current) of \(progress.total)...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .padding(16)
                    .background(.black.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.bottom, 100)
                }
            }
        }
        .confirmationDialog("RSVP", isPresented: $showRSVPActionSheet, presenting: selectedEvent) { event in
            let currentStatus = eventsService.myRsvps[event.id]
            
            Button("Going") {
                Task {
                    try? await eventsService.setRsvp(eventId: event.id, status: .going)
                }
            }
            Button("Maybe") {
                Task {
                    try? await eventsService.setRsvp(eventId: event.id, status: .maybe)
                }
            }
            Button("Declined") {
                Task {
                    try? await eventsService.setRsvp(eventId: event.id, status: .declined)
                }
            }
            if currentStatus != nil {
                Button("Clear RSVP", role: .destructive) {
                    Task {
                        try? await eventsService.clearRsvp(eventId: event.id)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showPhotosPicker, selection: $photoItems, maxSelectionCount: 10, matching: .images)
        .onChange(of: photoItems) { _, newItems in
            guard !newItems.isEmpty, let event = selectedEvent else { return }
            Task {
                await uploadPhotos(items: newItems, event: event)
                photoItems = []
            }
        }
        .task(id: "\(selectedGroupId?.uuidString ?? "")-\(selectedEventTab)") {
            guard let groupId = selectedGroupId else { return }
            do {
                try await eventsService.loadGroupEvents(groupId: groupId, upcoming: selectedEventTab == .upcoming)
            } catch {
                print("Failed to load events: \(error)")
            }
        }
    }
    
    func uploadPhotos(items: [PhotosPickerItem], event: GroupEventFull) async {
        uploadProgress = (0, items.count)
        uploadError = nil
        
        for (index, item) in items.enumerated() {
            uploadProgress = (index + 1, items.count)
            
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    continue
                }
                _ = try await eventsService.uploadEventPhoto(eventId: event.id, groupId: event.groupId, image: image)
            } catch {
                uploadError = "Failed to upload photo \(index + 1)"
                print("Upload error: \(error)")
            }
        }
        
        uploadProgress = nil
        
        // Reload media for this event
        try? await eventsService.loadEventMedia(eventId: event.id)
    }
}

// MARK: - Backend Event Card
struct BackendEventCard: View {
    let event: GroupEventFull
    let isExpanded: Bool
    let onRSVPTap: () -> Void
    let onEventTap: () -> Void
    let onAddPhotos: () -> Void

    /// Drives the "Invite a friend" iOS share sheet. Local to the card.
    @State private var showShareSheet = false

    var eventsService = EventsService.shared

    /// True when both the event itself and its RSVP audience are public
    /// — the gate for surfacing the share pill.
    private var isPublicRsvp: Bool {
        event.visibility == "public" && event.rsvpAudience == "public"
    }
    
    var myRsvp: RsvpStatus? {
        eventsService.myRsvps[event.id]
    }
    
    var mediaItems: [EventMediaItem] {
        eventsService.mediaByEvent[event.id] ?? []
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: event.startsAt)
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: event.startsAt)
    }
    
    var canManage: Bool {
        eventsService.canManageGroup(event.groupId)
    }
    
    var canRsvp: Bool {
        if event.rsvpAudience == "public" { return true }
        // members_only: check if user is member
        return eventsService.myMemberships.contains { $0.groupId == event.groupId }
    }
    
    /// CTA label that reflects the *current* RSVP status. The default
    /// must NOT imply commitment — when the user hasn't responded yet
    /// we show "RSVP" rather than "I'm going!" so the pill is a
    /// prompt, not a false confirmation.
    private var rsvpLabel: String {
        switch myRsvp {
        case .going:    return "You're going"
        case .maybe:    return "Maybe"
        case .declined: return "Can't make it"
        case nil:       return "RSVP"
        }
    }

    /// Colors per status. No-response state stays lime as a CTA hue
    /// but the label change above removes the implication of "going".
    private var rsvpAccent: (background: Color, foreground: Color, icon: String?) {
        switch myRsvp {
        case .going:
            return (Color.white.opacity(0.12), .white, "checkmark.circle.fill")
        case .maybe:
            return (Color.white.opacity(0.12), .white, "questionmark.circle.fill")
        case .declined:
            return (Color.white.opacity(0.12), .white, "xmark.circle.fill")
        case nil:
            return (YGColors.lime, .black, nil)
        }
    }

    var rsvpButtonContent: some View {
        let accent = rsvpAccent
        return HStack(spacing: 10) {
            if let icon = accent.icon {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(YGColors.lime)
            }

            Text(rsvpLabel)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(accent.foreground)

            Spacer()

            if myRsvp == nil {
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .background(accent.background)
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(myRsvp != nil ? .white.opacity(0.3) : .clear, lineWidth: 1.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main event card content
            VStack(alignment: .leading, spacing: 16) {
                // Title and group badge
                VStack(alignment: .leading, spacing: 8) {
                    Text(event.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    if let membership = eventsService.myMemberships.first(where: { $0.groupId == event.groupId }) {
                        Text(membership.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(event.isPast ? .white.opacity(0.3) : YGColors.lime)
                            .clipShape(Capsule())
                    }
                }

                // Date, time, location in compact chips
                HStack(spacing: 8) {
                    // Date chip
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12, weight: .semibold))
                        Text(formattedDate)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.15))
                    .clipShape(Capsule())
                    
                    // Time chip
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 12, weight: .semibold))
                        Text(formattedTime)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.15))
                    .clipShape(Capsule())
                }
                
                // Location if available
                if let location = event.location {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text(location)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white.opacity(0.9))
                }

                // RSVP section for upcoming events
                if !event.isPast && canRsvp {
                    Button {
                        onRSVPTap()
                    } label: {
                        rsvpButtonContent
                    }
                    .buttonStyle(.plain)
                }

                // Public events expose an "Invite a friend" pill that
                // opens the iOS share sheet pre-filled with the
                // friend-facing RSVP URL.
                if !event.isPast && isPublicRsvp {
                    HStack {
                        Spacer()
                        Button {
                            showShareSheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 13, weight: .heavy))
                                Text("Invite a friend")
                                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.white.opacity(0.18))
                            .clipShape(Capsule())
                            .overlay {
                                Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                if event.isPast {
                    // Past event media section
                    HStack {
                        if !mediaItems.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 12))
                                Text("\(mediaItems.count) \(mediaItems.count == 1 ? "photo" : "photos")")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(.white.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        if canManage {
                            Button {
                                onAddPhotos()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add photos")
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(YGColors.lime)
                            }
                        }
                        
                        if !mediaItems.isEmpty {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
            }
            .padding(18)
            .contentShape(Rectangle())
            .onTapGesture {
                if event.isPast && !mediaItems.isEmpty {
                    onEventTap()
                }
            }
            
            // Expandable media carousel
            if isExpanded && event.isPast && !mediaItems.isEmpty {
                VStack(spacing: 0) {
                    Divider()
                        .background(.white.opacity(0.2))
                        .padding(.horizontal, 16)
                    
                    TabView {
                        ForEach(mediaItems) { item in
                            EventMediaView(item: item)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .frame(height: 320)
                    .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
                }
                .task {
                    // Load media when expanded
                    try? await eventsService.loadEventMedia(eventId: event.id)
                }
            }
        }
        .background(.ultraThinMaterial)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityView(activityItems: shareItems)
        }
    }

    /// Friend-facing invite blurb + public RSVP URL. Mirrors the
    /// helper on `EventCardView` — the page at
    /// `ygteev.com/events/<id>` is the Lovable companion that handles
    /// email-only RSVPs.
    private var shareItems: [Any] {
        let id = event.id.uuidString.lowercased()
        let url = URL(string: "\(Event.publicEventBaseURL)/\(id)")!
        let text = "Hey, you should come to the \(event.title) with me. RSVP here so they know you're coming."
        return [text, url]
    }
}

// MARK: - Event Media View
struct EventMediaView: View {
    let item: EventMediaItem
    @State private var signedUrl: URL?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            if item.kind == "photo", item.storagePath != nil {
                if let url = signedUrl {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                        case .failure:
                            placeholderView(text: "Failed to load")
                        case .empty:
                            ProgressView()
                                .tint(.white)
                        @unknown default:
                            placeholderView(text: "Unknown")
                        }
                    }
                } else if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    placeholderView(text: "No URL")
                }
            } else if item.kind == "video" {
                placeholderView(text: "Video coming soon")
            } else {
                placeholderView(text: "Unknown media")
            }
            
            // Caption overlay
            if let caption = item.caption, !caption.isEmpty {
                VStack {
                    Spacer()
                    Text(caption)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.black.opacity(0.6))
                }
            }
        }
        .task {
            guard item.kind == "photo", let path = item.storagePath else {
                isLoading = false
                return
            }
            do {
                signedUrl = try await EventsService.shared.signedUrl(for: path)
                isLoading = false
            } catch {
                isLoading = false
                print("Failed to get signed URL: \(error)")
            }
        }
    }
    
    func placeholderView(text: String) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    colors: [Color(white: 0.2), Color(white: 0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Text(text)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
    }
}

// MARK: - Legacy Event Card (keep for compatibility)
struct EventCard: View {
    let event: Event
    let isPast: Bool
    let isExpanded: Bool
    let onRSVPTap: () -> Void
    let onEventTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main event card content
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)

                        Text(event.groupName.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(isPast ? .white.opacity(0.5) : YGColors.lime)
                            .tracking(0.5)
                    }

                    Spacer()

                    if isPast && !event.media.isEmpty {
                        Image(systemName: isExpanded ? "chevron.up" : "photo.on.rectangle")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.6))
                    } else {
                        Text("📅")
                            .font(.system(size: 32))
                    }
                }

                Divider()
                    .background(.white.opacity(0.2))

                VStack(alignment: .leading, spacing: 6) {
                    Label(event.formattedDate, systemImage: "calendar")
                        .font(.system(size: 14))

                    Label(event.time, systemImage: "clock")
                        .font(.system(size: 14))

                    Label(event.location, systemImage: "mappin.circle")
                        .font(.system(size: 14))
                }
                .foregroundStyle(.white.opacity(0.8))

                if !isPast {
                    Button {
                        onRSVPTap()
                    } label: {
                        HStack(spacing: 8) {
                            Text(event.rsvpStatus?.displayName ?? "RSVP")
                                .font(.system(size: 15, weight: .bold))
                            
                            if event.rsvpStatus != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                            }
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(YGColors.lime)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                } else if !event.media.isEmpty {
                    HStack {
                        Text("\(event.media.count) \(event.media.count == 1 ? "photo" : "photos/videos")")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                        
                        Spacer()
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(.top, 4)
                }
            }
            .padding(16)
            .contentShape(Rectangle())
            .onTapGesture {
                if isPast && !event.media.isEmpty {
                    onEventTap()
                }
            }
            
            // Expandable media carousel
            if isExpanded && isPast && !event.media.isEmpty {
                VStack(spacing: 0) {
                    Divider()
                        .background(.white.opacity(0.2))
                        .padding(.horizontal, 16)
                    
                    TabView {
                        ForEach(event.media) { media in
                            MediaCarouselItem(media: media)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .frame(height: 300)
                    .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
                }
            }
        }
        .background(.ultraThinMaterial)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        }
    }
}

// MARK: - Media Carousel Item
struct MediaCarouselItem: View {
    let media: EventMedia
    
    var body: some View {
        ZStack {
            // Placeholder background
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hue: Double(media.id.hashValue % 360) / 360.0, saturation: 0.6, brightness: 0.4),
                            Color(hue: Double(media.id.hashValue % 360) / 360.0, saturation: 0.4, brightness: 0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Media type indicator
            VStack(spacing: 12) {
                if media.type == .video {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                Text(media.type == .video ? "Video" : "Photo")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - RSVP Confirmation Sheet
struct RSVPConfirmationSheet: View {
    let event: Event
    let onConfirm: (RSVPStatus) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Title
            VStack(spacing: 8) {
                Text("RSVP to Event")
                    .font(.lilitaOne(size: 22))
                    .tracking(-0.5)
                    .foregroundStyle(YGColors.ink)
                
                Text(event.title)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)
            .padding(.bottom, 24)
            
            // RSVP options
            VStack(spacing: 12) {
                ForEach([RSVPStatus.yes, RSVPStatus.maybe, RSVPStatus.no], id: \.self) { status in
                    Button {
                        onConfirm(status)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: iconForStatus(status))
                                .font(.system(size: 20))
                                .foregroundStyle(colorForStatus(status))
                                .frame(width: 32)
                            
                            Text(status.displayName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(YGColors.ink)
                            
                            Spacer()
                            
                            if event.rsvpStatus == status {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(colorForStatus(status))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .background(Color(.systemBackground))
    }
    
    func iconForStatus(_ status: RSVPStatus) -> String {
        switch status {
        case .yes: return "hand.thumbsup.fill"
        case .maybe: return "questionmark.circle.fill"
        case .no: return "hand.thumbsdown.fill"
        }
    }
    
    func colorForStatus(_ status: RSVPStatus) -> Color {
        switch status {
        case .yes: return YGColors.lime
        case .maybe: return .orange
        case .no: return .red
        }
    }
}

// MARK: - Event Slideshow View
struct EventSlideshowView: View {
    let event: Event
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex = 0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text(event.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                        
                        Text(event.formattedDate)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    // Placeholder for symmetry
                    Color.clear
                        .frame(width: 38, height: 38)
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 16)
                
                // Media viewer
                TabView(selection: $currentIndex) {
                    ForEach(Array(event.media.enumerated()), id: \.element.id) { index, media in
                        MediaItemView(media: media)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                
                // Counter
                Text("\(currentIndex + 1) / \(event.media.count)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Media Item View
struct MediaItemView: View {
    let media: EventMedia
    
    var body: some View {
        ZStack {
            if media.type == .photo {
                // Placeholder for photo
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [YGColors.violet.opacity(0.3), YGColors.pink.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.white.opacity(0.5))
                            
                            Text("Photo")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 20)
            } else {
                // Placeholder for video
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [YGColors.violet.opacity(0.3), YGColors.pink.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(.white.opacity(0.7))
                            
                            Text("Video")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Ranking View

enum RankingMode: Hashable { case groups, users }

struct RankingView: View {
    let membership: MyGroupMembership?

    @State private var service = RankingService.shared
    @State private var mode: RankingMode = .groups

    /// Resets at Monday 00:00 UTC. Using ISO-8601 calendar so weekday=2
    /// reliably maps to Monday regardless of locale.
    private static func endOfWeekUTC(from reference: Date) -> Date {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.nextDate(
            after: reference,
            matching: DateComponents(hour: 0, minute: 0, weekday: 2),
            matchingPolicy: .nextTime
        ) ?? reference.addingTimeInterval(7 * 86400)
    }

    private static func countdownString(from now: Date) -> String {
        let target = endOfWeekUTC(from: now)
        let seconds = max(0, Int(target.timeIntervalSince(now)))
        let d = seconds / 86400
        let h = (seconds % 86400) / 3600
        let m = (seconds % 3600) / 60
        if d > 0 { return "Resets in \(d)d \(h)h \(m)m" }
        if h > 0 { return "Resets in \(h)h \(m)m" }
        return "Resets in \(m)m"
    }

    private var isDefaultGroup: Bool {
        membership?.isDefaultYgteev == true
    }

    private var segmentLabel: String {
        membership?.name ?? "Members"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                segmentedToggle
                    .padding(.bottom, 18)

                if membership == nil {
                    emptyHint("Join a youth group to see this week's leaderboard.")
                } else if isDefaultGroup {
                    // Default YGTeeV context: no class to compete in,
                    // so fall back to platform-wide leaderboards.
                    switch mode {
                    case .groups: overallGroupsSection
                    case .users:  overallUsersSection
                    }
                    footerFinePrint
                } else {
                    switch mode {
                    case .groups: groupsSection
                    case .users:  usersSection
                    }
                    footerFinePrint
                }
            }
            .padding(.bottom, 120)
        }
        .background(Color.black)
        .task(id: membership?.groupId) {
            // Re-fetch whenever the active group flips in the top header.
            // Default-group context uses the overall RPCs; everyone else
            // gets the class-based ones.
            guard let gid = membership?.groupId else { return }
            if isDefaultGroup {
                await service.loadOverall()
            } else {
                await service.load(groupId: gid)
            }
        }
    }

    // MARK: - Header

    /// Class label of the user's own group, pulled from whichever row in
    /// `service.groups` has `isMyGroup == true`. Nil while groups are
    /// still loading, in which case the header falls back to "THIS WEEK".
    private var myClassLabel: String? {
        service.groups.first(where: { $0.isMyGroup })?.classLabel
    }

    /// "THIS WEEK IN BOLTS" for a real group, plain "THIS WEEK" for the
    /// default YGTeeV context (there's no class — it's the overall list).
    private var headerTitle: String {
        if isDefaultGroup { return "THIS WEEK" }
        if let cls = myClassLabel { return "THIS WEEK IN \(cls.uppercased())" }
        return "THIS WEEK"
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(headerTitle)
                .font(.lilitaOne(size: 20))
                .tracking(0.5)
                .foregroundStyle(.white)
            // TimelineView ticks once a minute so the countdown stays
            // accurate without us juggling a Combine publisher.
            TimelineView(.periodic(from: .now, by: 60)) { ctx in
                Text(Self.countdownString(from: ctx.date))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
        .padding(.bottom, 18)
    }

    private var segmentedToggle: some View {
        HStack(spacing: 6) {
            segmentButton(label: "Groups", isSelected: mode == .groups) {
                withAnimation(.spring(response: 0.3)) { mode = .groups }
            }
            segmentButton(label: segmentLabel, isSelected: mode == .users) {
                withAnimation(.spring(response: 0.3)) { mode = .users }
            }
        }
        .padding(4)
        .background(.white.opacity(0.1))
        .clipShape(Capsule())
        .overlay {
            Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
        }
    }

    private func segmentButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.lilitaOne(size: 13.5))
                .lineLimit(1)
                .foregroundStyle(isSelected ? .black : .white.opacity(0.6))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? .white : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Groups section

    @ViewBuilder
    private var groupsSection: some View {
        let groups = service.groups
        if groups.isEmpty {
            emptyHint(service.isLoading ? "Loading…" : "No groups in this class yet.")
        } else {
            let podium = Array(groups.prefix(3))
            let rest   = groups.dropFirst(3)

            if podium.count >= 3 {
                HStack(alignment: .bottom, spacing: 12) {
                    GroupPodiumCard(group: podium[1], height: 140)
                    GroupPodiumCard(group: podium[0], height: 180)
                    GroupPodiumCard(group: podium[2], height: 120)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            } else {
                VStack(spacing: 10) {
                    ForEach(podium) { GroupLeaderboardRow(group: $0) }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }

            if !rest.isEmpty {
                VStack(spacing: 1) {
                    ForEach(rest) { GroupLeaderboardRow(group: $0) }
                }
                .background(.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Users section

    @ViewBuilder
    private var usersSection: some View {
        let users = service.users
        if users.isEmpty {
            emptyHint(service.isLoading ? "Loading…" : "No XP earned in this group this week.")
        } else {
            let podium = Array(users.prefix(3))
            let rest   = users.dropFirst(3)

            if podium.count >= 3 {
                HStack(alignment: .bottom, spacing: 12) {
                    UserPodiumCard(user: podium[1], height: 140)
                    UserPodiumCard(user: podium[0], height: 180)
                    UserPodiumCard(user: podium[2], height: 120)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            } else {
                VStack(spacing: 10) {
                    ForEach(podium) { UserLeaderboardRow(user: $0) }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }

            if !rest.isEmpty {
                VStack(spacing: 1) {
                    ForEach(rest) { UserLeaderboardRow(user: $0) }
                }
                .background(.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Overall (default-group) sections

    @ViewBuilder
    private var overallGroupsSection: some View {
        let groups = service.groupsOverall
        if groups.isEmpty {
            emptyHint(service.isLoading ? "Loading…" : "No groups have earned XP this week yet.")
        } else {
            let podium = Array(groups.prefix(3))
            let rest   = groups.dropFirst(3)

            if podium.count >= 3 {
                HStack(alignment: .bottom, spacing: 12) {
                    GroupOverallPodiumCard(group: podium[1], height: 140)
                    GroupOverallPodiumCard(group: podium[0], height: 180)
                    GroupOverallPodiumCard(group: podium[2], height: 120)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            } else {
                VStack(spacing: 10) {
                    ForEach(podium) { GroupOverallLeaderboardRow(group: $0) }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }

            if !rest.isEmpty {
                VStack(spacing: 1) {
                    ForEach(rest) { GroupOverallLeaderboardRow(group: $0) }
                }
                .background(.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)
            }
        }
    }

    @ViewBuilder
    private var overallUsersSection: some View {
        let users = service.usersOverall
        if users.isEmpty {
            emptyHint(service.isLoading ? "Loading…" : "No XP earned anywhere yet this week.")
        } else {
            let podium = Array(users.prefix(3))
            let rest   = users.dropFirst(3)

            if podium.count >= 3 {
                HStack(alignment: .bottom, spacing: 12) {
                    UserOverallPodiumCard(user: podium[1], height: 140)
                    UserOverallPodiumCard(user: podium[0], height: 180)
                    UserOverallPodiumCard(user: podium[2], height: 120)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            } else {
                VStack(spacing: 10) {
                    ForEach(podium) { UserOverallLeaderboardRow(user: $0) }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }

            if !rest.isEmpty {
                VStack(spacing: 1) {
                    ForEach(rest) { UserOverallLeaderboardRow(user: $0) }
                }
                .background(.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Footer

    private var footerFinePrint: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(isDefaultGroup ? "Overall this week" : "How it works")
                .font(.system(size: 11.5, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(.white.opacity(0.55))
            Text(isDefaultGroup
                 ? "Every group and every user across YGTeeV, ranked by raw weekly XP. Your own church's group is included here in addition to the class-based leaderboard you see on its tab."
                 : "Groups compete inside their own class — Bolts (1–19 active users), Volts (20–49), Surge (50–99), Storm (100–199), Thunder (200–499), Legends (500+). A handicap multiplier (max ×3.00) levels the field within each class so smaller groups can still win. Each group's multiplier is shown next to its name.")
                .font(.system(size: 11.5))
                .foregroundStyle(.white.opacity(0.45))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(.white.opacity(0.5))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 30)
            .padding(.top, 60)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Group cards

struct GroupPodiumCard: View {
    let group: RankedGroup
    let height: CGFloat

    private var rankColor: Color {
        switch group.rank {
        case 1: return .yellow
        case 2: return Color(hex: "C0C0C0")
        case 3: return Color(hex: "CD7F32")
        default: return .gray
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            GroupAvatarBubble(group: group, size: group.rank == 1 ? 60 : 50)
                .overlay(alignment: .bottom) {
                    Circle()
                        .fill(rankColor)
                        .frame(width: 24, height: 24)
                        .overlay {
                            Text("\(group.rank)")
                                .font(.system(size: 12, weight: .black))
                                .foregroundStyle(.white)
                        }
                        .offset(y: 8)
                }
            VStack(spacing: 4) {
                Text(group.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                multiplierPill(group)
                HStack(spacing: 4) {
                    Text("⚡").font(.system(size: 12))
                    Text("\(group.adjustedXp.formatted())")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(YGColors.yellow)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .background(rankColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(rankColor.opacity(0.4), lineWidth: 2)
            }
            .overlay {
                if group.isMyGroup {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(YGColors.violet, lineWidth: 2)
                }
            }
        }
    }
}

struct GroupLeaderboardRow: View {
    let group: RankedGroup

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(group.rank)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 40, alignment: .leading)

            GroupAvatarBubble(group: group, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.system(size: 14.5, weight: group.isMyGroup ? .bold : .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(group.classLabel.uppercased())
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(0.4)
                        .foregroundStyle(.white.opacity(0.55))
                    multiplierPill(group)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Text("⚡").font(.system(size: 14))
                Text("\(group.adjustedXp.formatted())")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(YGColors.yellow)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(group.isMyGroup ? YGColors.violet.opacity(0.2) : .clear)
    }
}

/// Multiplier color ramps with how big the handicap is. ≈1.00 = the
/// group is the biggest in its class (no help), >1.50 = small fish in
/// a big pond.
private func multiplierPill(_ group: RankedGroup) -> some View {
    let m = group.multiplier
    let fg: Color = {
        if m > 1.50 { return Color(hex: "FF6B35") }   // orange
        if m > 1.10 { return YGColors.yellow }        // gold
        return .white.opacity(0.55)                   // gray
    }()
    let bg = fg.opacity(0.18)
    let formatted = String(format: "×%.2f", m)
    return Text(formatted)
        .font(.system(size: 11, weight: .heavy, design: .monospaced))
        .foregroundStyle(fg)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 4))
}

struct GroupAvatarBubble: View {
    let group: RankedGroup
    let size: CGFloat

    var body: some View {
        ZStack {
            gradient
            if let urlStr = group.logoUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default:                fallbackInitial
                    }
                }
            } else {
                fallbackInitial
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var fallbackInitial: some View {
        Text(String(group.name.prefix(1)).uppercased())
            .font(.system(size: size * 0.42, weight: .black, design: .rounded))
            .foregroundStyle(.white)
    }

    private var gradient: LinearGradient {
        let from = Color(hex: group.gradientFrom ?? "6B2BFF")
        let to   = Color(hex: group.gradientTo ?? "FF3DA5")
        return LinearGradient(colors: [from, to],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - User cards

struct UserPodiumCard: View {
    let user: RankedUser

    let height: CGFloat

    private var rankColor: Color {
        switch user.rank {
        case 1: return .yellow
        case 2: return Color(hex: "C0C0C0")
        case 3: return Color(hex: "CD7F32")
        default: return .gray
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            YGAvatar(name: user.isMe ? "You" : (user.displayName ?? "?"),
                     size: user.rank == 1 ? 60 : 50,
                     showRing: true)
                .overlay(alignment: .bottom) {
                    Circle()
                        .fill(rankColor)
                        .frame(width: 24, height: 24)
                        .overlay {
                            Text("\(user.rank)")
                                .font(.system(size: 12, weight: .black))
                                .foregroundStyle(.white)
                        }
                        .offset(y: 8)
                }
            VStack(spacing: 4) {
                Text(user.isMe ? "You" : (user.displayName ?? "Unknown"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let role = MessageThread.LeaderRole.from(rawServer: user.role) {
                    rolePill(role)
                }
                HStack(spacing: 4) {
                    Text("⚡").font(.system(size: 12))
                    Text("\(user.weekXp.formatted())")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(YGColors.yellow)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .background(rankColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(rankColor.opacity(0.4), lineWidth: 2)
            }
            .overlay {
                if user.isMe {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(YGColors.violet, lineWidth: 2)
                }
            }
        }
    }
}

struct UserLeaderboardRow: View {
    let user: RankedUser

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(user.rank)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 40, alignment: .leading)

            YGAvatar(name: user.displayName ?? "?", size: 40, showRing: false)

            VStack(alignment: .leading, spacing: 2) {
                Text(user.isMe ? "You" : (user.displayName ?? "Unknown"))
                    .font(.system(size: 15, weight: user.isMe ? .bold : .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let role = MessageThread.LeaderRole.from(rawServer: user.role) {
                    rolePill(role)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Text("⚡").font(.system(size: 14))
                Text("\(user.weekXp.formatted())")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(YGColors.yellow)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(user.isMe ? YGColors.violet.opacity(0.2) : .clear)
    }
}

/// Shared user-role pill renderer. Matches the color set used in the
/// Messages list so the same pastor/leader/parent/student/member colors
/// surface everywhere a person's role is shown.
private func rolePill(_ role: MessageThread.LeaderRole) -> some View {
    Text(role.rawValue)
        .font(.system(size: 9, weight: .heavy))
        .tracking(0.4)
        .foregroundStyle(role.color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(role.color.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 4))
}

// MARK: - Overall (default-group) cards
//
// Same visual shape as the class-based cards above, minus the
// multiplier pill / class label (no handicap in the overall view) and
// with each user row carrying a group-name subtitle so platform-wide
// rankings still let you see "who's playing for which church".

struct GroupOverallPodiumCard: View {
    let group: RankedGroupOverall
    let height: CGFloat

    private var rankColor: Color {
        switch group.rank {
        case 1: return .yellow
        case 2: return Color(hex: "C0C0C0")
        case 3: return Color(hex: "CD7F32")
        default: return .gray
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            OverallGroupAvatarBubble(
                name: group.name,
                logoUrl: group.logoUrl,
                gradientFrom: group.gradientFrom,
                gradientTo: group.gradientTo,
                size: group.rank == 1 ? 60 : 50
            )
            .overlay(alignment: .bottom) {
                Circle()
                    .fill(rankColor)
                    .frame(width: 24, height: 24)
                    .overlay {
                        Text("\(group.rank)")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(.white)
                    }
                    .offset(y: 8)
            }
            VStack(spacing: 4) {
                Text(group.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text("⚡").font(.system(size: 12))
                    Text("\(group.weekXp.formatted())")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(YGColors.yellow)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .background(rankColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(rankColor.opacity(0.4), lineWidth: 2)
            }
            .overlay {
                if group.isMyGroup {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(YGColors.violet, lineWidth: 2)
                }
            }
        }
    }
}

struct GroupOverallLeaderboardRow: View {
    let group: RankedGroupOverall

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(group.rank)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 40, alignment: .leading)

            OverallGroupAvatarBubble(
                name: group.name,
                logoUrl: group.logoUrl,
                gradientFrom: group.gradientFrom,
                gradientTo: group.gradientTo,
                size: 40
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.system(size: 14.5, weight: group.isMyGroup ? .bold : .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let church = group.churchName, !church.isEmpty {
                    Text(church)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Text("⚡").font(.system(size: 14))
                Text("\(group.weekXp.formatted())")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(YGColors.yellow)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(group.isMyGroup ? YGColors.violet.opacity(0.2) : .clear)
    }
}

/// Avatar bubble that's free of the `RankedGroup`-specific fields the
/// class-based `GroupAvatarBubble` consumes — accepts the raw name and
/// optional logo/gradient strings so it works for both `RankedGroup`
/// and `RankedGroupOverall` without an awkward shared protocol.
struct OverallGroupAvatarBubble: View {
    let name: String
    let logoUrl: String?
    let gradientFrom: String?
    let gradientTo: String?
    let size: CGFloat

    var body: some View {
        ZStack {
            gradient
            if let urlStr = logoUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default:                fallbackInitial
                    }
                }
            } else {
                fallbackInitial
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var fallbackInitial: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: size * 0.42, weight: .black, design: .rounded))
            .foregroundStyle(.white)
    }

    private var gradient: LinearGradient {
        let from = Color(hex: gradientFrom ?? "6B2BFF")
        let to   = Color(hex: gradientTo ?? "FF3DA5")
        return LinearGradient(colors: [from, to],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct UserOverallPodiumCard: View {
    let user: RankedUserOverall
    let height: CGFloat

    private var rankColor: Color {
        switch user.rank {
        case 1: return .yellow
        case 2: return Color(hex: "C0C0C0")
        case 3: return Color(hex: "CD7F32")
        default: return .gray
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            YGAvatar(name: user.isMe ? "You" : (user.displayName ?? "?"),
                     size: user.rank == 1 ? 60 : 50,
                     showRing: true)
                .overlay(alignment: .bottom) {
                    Circle()
                        .fill(rankColor)
                        .frame(width: 24, height: 24)
                        .overlay {
                            Text("\(user.rank)")
                                .font(.system(size: 12, weight: .black))
                                .foregroundStyle(.white)
                        }
                        .offset(y: 8)
                }
            VStack(spacing: 4) {
                Text(user.isMe ? "You" : (user.displayName ?? "Unknown"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let group = user.groupName, !group.isEmpty {
                    Text(group)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
                HStack(spacing: 4) {
                    Text("⚡").font(.system(size: 12))
                    Text("\(user.weekXp.formatted())")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(YGColors.yellow)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .background(rankColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(rankColor.opacity(0.4), lineWidth: 2)
            }
            .overlay {
                if user.isMe {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(YGColors.violet, lineWidth: 2)
                }
            }
        }
    }
}

struct UserOverallLeaderboardRow: View {
    let user: RankedUserOverall

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(user.rank)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 40, alignment: .leading)

            YGAvatar(name: user.displayName ?? "?", size: 40, showRing: false)

            VStack(alignment: .leading, spacing: 2) {
                Text(user.isMe ? "You" : (user.displayName ?? "Unknown"))
                    .font(.system(size: 15, weight: user.isMe ? .bold : .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let group = user.groupName, !group.isEmpty {
                    Text(group)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Text("⚡").font(.system(size: 14))
                Text("\(user.weekXp.formatted())")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(YGColors.yellow)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(user.isMe ? YGColors.violet.opacity(0.2) : .clear)
    }
}

// MARK: - Video Caption
struct VideoCaption: View {
    let video: VideoPost
    let groupName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(video.handle)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text(groupName.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.18))
                    .background(.ultraThinMaterial.opacity(0.3))
                    .clipShape(Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                    }
            }

            Text(video.caption)
                .font(.system(size: 14.5))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 2)
                .lineLimit(3)

            HStack(spacing: 6) {
                Image(systemName: "music.note")
                    .font(.system(size: 12))

                Text(video.music)
                    .font(.system(size: 12))
                    .lineLimit(1)
            }
            .foregroundStyle(.white.opacity(0.92))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Video Actions
struct VideoActions: View {
    let video: VideoPost

    var body: some View {
        VStack(spacing: 18) {
            // Author avatar with plus
            ZStack(alignment: .bottom) {
                YGAvatar(name: video.author, size: 48, showRing: true)

                Circle()
                    .fill(YGColors.pink)
                    .frame(width: 22, height: 22)
                    .overlay {
                        Circle()
                            .strokeBorder(.white, lineWidth: 2)
                    }
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(.white)
                    }
                    .offset(y: 8)
            }

            ActionButton(icon: "heart.fill", count: video.likes, color: YGColors.pink)
            ActionButton(icon: "message.fill", count: video.comments)
            ActionButton(icon: "bookmark.fill", count: video.saves, color: YGColors.yellow)
            ActionButton(icon: "arrowshape.turn.up.right.fill", label: "Share")

            // Spinning music disc
            Circle()
                .fill(
                    RadialGradient(
                        colors: [YGColors.ink2, .black, Color(white: 0.3), YGColors.ink2],
                        center: .center,
                        startRadius: 10,
                        endRadius: 22
                    )
                )
                .frame(width: 44, height: 44)
                .overlay {
                    Circle()
                        .strokeBorder(.white, lineWidth: 2)
                }
                .overlay {
                    Circle()
                        .fill(.white)
                        .frame(width: 8, height: 8)
                }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.45), radius: 3)
    }
}

struct ActionButton: View {
    let icon: String
    var count: Int? = nil
    var label: String? = nil
    var color: Color = .white

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(color)

            if let count = count {
                Text("\(count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            } else if let label = label {
                Text(label)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
        }
    }
}

#Preview {
    HomeFeedView()
        .environment(AppState())
}
