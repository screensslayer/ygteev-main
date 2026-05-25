//
//  PastorGroupManagementView.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/7/26.
//

import SwiftUI
import Supabase

// MARK: - Pastor Dashboard (Main View)
struct PastorGroupManagementView: View {
    let onDismiss: () -> Void
    
    @State private var showMembersManager = false
    @State private var showCreateEvent = false
    @State private var showEventsManager = false
    @State private var showPublishPlan = false
    @State private var showManageSmallGroups = false
    @State private var selectedTab: AppTab = .profile
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Hero with group identity
                    ZStack {
                        // Gradient background
                        LinearGradient(
                            colors: [Color(hex: "6B2BFF"), Color(hex: "3D0FB8"), Color(hex: "FF3DA5")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        
                        // Decorative circles
                        GeometryReader { geo in
                            Circle()
                                .fill(.white.opacity(0.18))
                                .frame(width: 240, height: 240)
                                .offset(x: geo.size.width - 40, y: -60)
                            
                            Circle()
                                .fill(.black.opacity(0.12))
                                .frame(width: 180, height: 180)
                                .offset(x: -40, y: 120)
                        }
                        
                        VStack {
                            // Top buttons
                            HStack {
                                // Back button
                                Button {
                                    onDismiss()
                                } label: {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 38, height: 38)
                                        .background(.white.opacity(0.25))
                                        .clipShape(Circle())
                                        .overlay {
                                            Circle()
                                                .strokeBorder(.white.opacity(0.4), lineWidth: 0.5)
                                        }
                                }
                                
                                Spacer()
                                
                                Button {} label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "qrcode")
                                            .font(.system(size: 14, weight: .bold))
                                        Text("Group QR")
                                            .font(.lilitaOne(size: 12))
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(.white.opacity(0.25))
                                    .clipShape(Capsule())
                                    .overlay {
                                        Capsule()
                                            .strokeBorder(.white.opacity(0.4), lineWidth: 0.5)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 60)
                            
                            Spacer()
                            
                            // Bottom content
                            VStack(alignment: .leading, spacing: 8) {
                                Text("PASTOR DASHBOARD")
                                    .font(.system(size: 11, weight: .heavy))
                                    .tracking(1)
                                    .foregroundStyle(.white.opacity(0.85))
                                
                                Text("Grace City Youth")
                                    .font(.lilitaOne(size: 26))
                                    .tracking(-0.8)
                                    .foregroundStyle(.white)
                                
                                HStack(spacing: 14) {
                                    Text("**184** members")
                                    Text("**6** small groups")
                                    Text("**12** requests")
                                }
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.95))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 18)
                            .padding(.bottom, 18)
                        }
                    }
                    .frame(height: 220)
                    
                    VStack(spacing: 16) {
                        // Requests alert
                        Button {
                            showMembersManager = true
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "FFD60A"), Color(hex: "FF6B35")],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 44, height: 44)
                                    .overlay {
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundStyle(YGColors.ink)
                                    }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("12 join requests waiting")
                                        .font(.lilitaOne(size: 14.5))
                                        .tracking(-0.2)
                                        .foregroundStyle(YGColors.ink)
                                    
                                    HStack(spacing: 4) {
                                        // Avatars
                                        ForEach(["Eli", "Maya", "Cole", "Jada"], id: \.self) { name in
                                            Circle()
                                                .fill(Color(hex: "6B2BFF"))
                                                .frame(width: 22, height: 22)
                                                .overlay {
                                                    Text(String(name.prefix(1)))
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundStyle(.white)
                                                }
                                                .overlay {
                                                    Circle()
                                                        .strokeBorder(.white, lineWidth: 2)
                                                }
                                        }
                                        
                                        Text("+ 8 more")
                                            .font(.system(size: 12))
                                            .foregroundStyle(YGColors.ink.opacity(0.55))
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(YGColors.ink.opacity(0.3))
                            }
                            .padding(14)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(hex: "FFD60A"))
                                    .frame(width: 4)
                            }
                            .shadow(color: YGColors.ink.opacity(0.06), radius: 14, y: 4)
                        }
                        .padding(.horizontal, 16)
                        
                        // Quick stats grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            StatCardView(number: "89%", label: "Active this week", subtitle: "vs 76% last wk", color: Color(hex: "2B8A3E"))
                            StatCardView(number: "412k", label: "Group XP earned", subtitle: "↑ 18%", color: Color(hex: "FFD60A"))
                        }
                        .padding(.horizontal, 16)
                        
                        // Tools section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tools")
                                .font(.lilitaOne(size: 16))
                                .tracking(-0.3)
                                .foregroundStyle(YGColors.ink)
                                .padding(.horizontal, 4)
                            
                            VStack(spacing: 0) {
                                ToolRowView(icon: "calendar.badge.plus", label: "Create event", subtitle: "Schedule + RSVP tracking", onTap: {
                                    showCreateEvent = true
                                })
                                ToolRowView(icon: "calendar", label: "Events", subtitle: "View & manage all events", onTap: {
                                    showEventsManager = true
                                })
                                ToolRowView(icon: "book.closed", label: "Publish a Bible plan", subtitle: "Custom plan for your group", onTap: {
                                    showPublishPlan = true
                                })
                                ToolRowView(icon: "person.3", label: "Manage small groups", subtitle: "6 groups · 28 leaders", onTap: {
                                    showManageSmallGroups = true
                                })
                                ToolRowView(icon: "person.badge.shield.checkmark", label: "Member management", subtitle: "184 members · 12 requests", onTap: {
                                    showMembersManager = true
                                })
                                ToolRowView(icon: "chart.bar", label: "Group insights", subtitle: "Engagement, retention, growth", isLast: true)
                            }
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18)
                                    .strokeBorder(Color.black.opacity(0.04), lineWidth: 0.5)
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // Recent activity
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Recent activity")
                                    .font(.lilitaOne(size: 16))
                                    .tracking(-0.3)
                                    .foregroundStyle(YGColors.ink)
                                
                                Spacer()
                                
                                Text("See all")
                                    .font(.system(size: 12.5, weight: .bold))
                                    .foregroundStyle(YGColors.violet)
                            }
                            .padding(.horizontal, 4)
                            
                            VStack(spacing: 0) {
                                ActivityRowView(name: "Maya R.", action: "finished Psalm 23 plan", xp: "+250 XP", time: "2m ago", color: Color(hex: "6B2BFF"))
                                ActivityRowView(name: "Eli J.", action: "requested to join", xp: nil, time: "14m ago", color: Color(hex: "FFD60A"))
                                ActivityRowView(name: "Tuesday SG", action: "shared notes from tonight", xp: nil, time: "1h ago", color: Color(hex: "2B8A3E"))
                                ActivityRowView(name: "Sam W.", action: "promoted to Group Leader", xp: nil, time: "3h ago", color: Color(hex: "0066FF"), isLast: true)
                            }
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18)
                                    .strokeBorder(Color.black.opacity(0.04), lineWidth: 0.5)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 100)
                }
            }
            .background(YGColors.paper)
            .ignoresSafeArea(edges: .top)
            
            // Bottom tab bar
            VStack {
                Spacer()
                YGTabBar(selectedTab: $selectedTab)
            }
            .ignoresSafeArea(.keyboard)

            // Publish-plan flow as a slide-from-trailing overlay.
            //
            // We keep the view mounted at all times (offscreen via `.offset`)
            // instead of using a `.transition(...)` insertion. Mount-on-tap
            // leaves a frame or two where the new view's layer exists but
            // SwiftUI hasn't finished compositing its contents — the system
            // window's black backdrop shows through during that gap, which
            // is the "black flash" we kept seeing. Always-mounted + animated
            // offset draws solid pixels from frame 0.
            GeometryReader { geo in
                PastorPlanCreateFlow(onDismiss: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showPublishPlan = false
                    }
                })
                .frame(width: geo.size.width, height: geo.size.height)
                .offset(x: showPublishPlan ? 0 : geo.size.width)
                .animation(.easeInOut(duration: 0.3), value: showPublishPlan)
                .allowsHitTesting(showPublishPlan)
                .zIndex(1)
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showMembersManager) {
            MembersManagerView()
        }
        .fullScreenCover(isPresented: $showCreateEvent) {
            // Source-of-truth for the active group: the pastor dashboard
            // service. Pulls the real `address` so the sheet's Default
            // location card shows the saved value instead of a mock.
            if let groupId = PastorDashboardService.shared.activeGroupId {
                let address = PastorDashboardService.shared
                    .myGroups
                    .first(where: { $0.id == groupId })?
                    .address
                CreateEventView(groupId: groupId, groupAddress: address)
            }
        }
        .fullScreenCover(isPresented: $showEventsManager) {
            EventsManagerView()
        }
        .fullScreenCover(isPresented: $showManageSmallGroups) {
            ManageSmallGroupsView()
        }
    }
}

// MARK: - Stat Card
struct StatCardView: View {
    let number: String
    let label: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(number)
                .font(.lilitaOne(size: 26))
                .tracking(-0.8)
                .foregroundStyle(YGColors.ink)
            
            Text(label)
                .font(.lilitaOne(size: 12))
                .foregroundStyle(YGColors.ink)
            
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(YGColors.ink.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.black.opacity(0.04), lineWidth: 0.5)
        }
        .shadow(color: YGColors.ink.opacity(0.04), radius: 8, y: 2)
    }
}

// MARK: - Tool Row
struct ToolRowView: View {
    let icon: String
    let label: String
    let subtitle: String
    var onTap: (() -> Void)? = nil
    var isLast: Bool = false
    
    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(YGColors.violet)
                    .frame(width: 36, height: 36)
                    .background(Color(hex: "F0EDF8"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.lilitaOne(size: 14.5))
                        .tracking(-0.2)
                        .foregroundStyle(YGColors.ink)
                    
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(YGColors.ink.opacity(0.55))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(YGColors.ink.opacity(0.3))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Color.white)
            .overlay(alignment: .top) {
                if !isLast {
                    Divider()
                        .padding(.leading, 14)
                        .offset(y: -0.5)
                }
            }
        }
    }
}

// MARK: - Activity Row
struct ActivityRowView: View {
    let name: String
    let action: String
    let xp: String?
    let time: String
    let color: Color
    var isLast: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4, height: 28)
            
            HStack(spacing: 4) {
                Text(name)
                    .font(.lilitaOne(size: 14))
                    .foregroundStyle(YGColors.ink)
                
                Text(action)
                    .font(.system(size: 14))
                    .foregroundStyle(YGColors.ink.opacity(0.65))
            }
            
            Spacer()
            
            if let xp = xp {
                HStack(spacing: 3) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11))
                    Text(xp)
                        .font(.lilitaOne(size: 11))
                }
                .foregroundStyle(YGColors.ink)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(hex: "FFD60A"))
                .clipShape(Capsule())
            }
            
            Text(time)
                .font(.system(size: 11))
                .foregroundStyle(YGColors.ink.opacity(0.45))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.white)
        .overlay(alignment: .top) {
            if !isLast {
                Divider()
                    .padding(.leading, 14)
                    .offset(y: -0.5)
            }
        }
    }
}

// MARK: - Members Manager View
struct MembersManagerView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab: Tab = .requests
    
    enum Tab: String, CaseIterable {
        case requests = "Requests"
        case all = "All · 184"
        case leaders = "Leaders · 4"
        case smallGroups = "Small Groups"
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Sticky header
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            // Back button
                            Button(action: { dismiss() }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(YGColors.ink)
                                    .frame(width: 38, height: 38)
                                    .liquidGlass()
                                    .clipShape(Circle())
                            }
                            
                            Text("Members")
                                .font(.lilitaOne(size: 22))
                                .tracking(-0.5)
                                .foregroundStyle(YGColors.ink)
                            
                            Spacer()
                            
                            // Search button
                            Button {} label: {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(YGColors.ink)
                                    .frame(width: 38, height: 38)
                                    .liquidGlass()
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 60)
                        .padding(.bottom, 14)
                        
                        // Tabs
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Tab.allCases, id: \.self) { tab in
                                    Button {
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedTab = tab
                                        }
                                    } label: {
                                        HStack(spacing: 5) {
                                            Text(tab.rawValue)
                                                .font(.lilitaOne(size: 12.5))
                                            
                                            if tab == .requests {
                                                Text("12")
                                                    .font(.system(size: 10, weight: .heavy))
                                                    .foregroundStyle(selectedTab == tab ? YGColors.ink : .white)
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 1)
                                                    .background(selectedTab == tab ? Color(hex: "FFD60A") : Color(hex: "FF3DA5"))
                                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                                            }
                                        }
                                        .foregroundStyle(selectedTab == tab ? .white : YGColors.ink.opacity(0.6))
                                        .padding(.horizontal, 13)
                                        .padding(.vertical, 7)
                                        .background(selectedTab == tab ? YGColors.ink : Color.white.opacity(0.7))
                                        .clipShape(Capsule())
                                        .overlay {
                                            if selectedTab != tab {
                                                Capsule()
                                                    .strokeBorder(Color.black.opacity(0.05), lineWidth: 0.5)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.bottom, 12)
                    }
                    .background(
                        YGColors.paper.opacity(0.85)
                            .background(.ultraThinMaterial)
                    )
                    
                    // Content
                    VStack(spacing: 16) {
                        if selectedTab == .requests {
                            RequestsTabContent()
                        } else {
                            MembersTabContent(tab: selectedTab)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 100)
                }
            }
            .background(YGColors.paper)
            .ignoresSafeArea(edges: .top)
        }
    }
}

// MARK: - Requests Tab
struct RequestsTabContent: View {
    let requests = [
        ("Eli Jameson", "Asked: 14m ago · via QR scan"),
        ("Maya Rosenfeld", "Asked: 1h ago · via map"),
        ("Cole Tran", "Asked: 3h ago · via friend")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                ForEach(Array(requests.enumerated()), id: \.offset) { index, request in
                    HStack(spacing: 12) {
                        // Avatar
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "6B2BFF"), Color(hex: "FF3DA5")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 42, height: 42)
                            .overlay {
                                Text(String(request.0.prefix(1)))
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(request.0)
                                .font(.lilitaOne(size: 14.5))
                                .tracking(-0.2)
                                .foregroundStyle(YGColors.ink)
                            
                            Text(request.1)
                                .font(.system(size: 11.5))
                                .foregroundStyle(YGColors.ink.opacity(0.55))
                        }
                        
                        Spacer()
                        
                        // Reject button
                        Button {} label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color(hex: "FF3DA5"))
                                .frame(width: 36, height: 36)
                                .background(Color.white)
                                .clipShape(Circle())
                                .overlay {
                                    Circle()
                                        .strokeBorder(Color.black.opacity(0.1), lineWidth: 1)
                                }
                        }
                        
                        // Approve button
                        Button {} label: {
                            Text("Approve")
                                .font(.lilitaOne(size: 13))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .frame(height: 36)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "6B2BFF"), Color(hex: "FF3DA5")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(Capsule())
                        }
                    }
                    .padding(14)
                    .background(Color.white)
                    .overlay(alignment: .top) {
                        if index > 0 {
                            Divider()
                                .padding(.leading, 14)
                        }
                    }
                }
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.black.opacity(0.04), lineWidth: 0.5)
            }
            
            Text("+ 9 more · approving sends a notification")
                .font(.system(size: 12.5))
                .foregroundStyle(YGColors.ink.opacity(0.55))
                .padding(.top, 14)
        }
    }
}

// MARK: - Members Tab
struct MembersTabContent: View {
    let tab: MembersManagerView.Tab
    
    let members = [
        ("Pastor Jordan Kim", "pastor", "Founded · 2y", 18420, "All"),
        ("Sam Walters", "leader", "11mo", 14210, "Tuesday"),
        ("Riley Pearce", "leader", "9mo", 13800, "Worship"),
        ("Ash Diaz", "leader", "8mo", 12100, "MS Lead"),
        ("Maya Rosenfeld", "member", "6mo", 12480, "Tuesday"),
        ("Cole Tran", "member", "5mo", 11920, "Tuesday"),
        ("Jada Williams", "member", "4mo", 10810, "Friday"),
        ("Eli Jameson", "member", "3mo", 9420, "Friday"),
        ("Sophie Kim", "member", "2mo", 8870, "Sunday AM")
    ]
    
    var filteredMembers: [(String, String, String, Int, String)] {
        if tab == .leaders {
            return members.filter { $0.1 != "member" }
        }
        return members
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Tier legend
            HStack(spacing: 8) {
                TierChip(tier: "pastor", label: "Pastor", count: 1)
                TierChip(tier: "leader", label: "Group Leader", count: 6)
                TierChip(tier: "member", label: "Member", count: 177)
            }
            .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                ForEach(Array(filteredMembers.enumerated()), id: \.offset) { index, member in
                    HStack(spacing: 12) {
                        // Avatar
                        Circle()
                            .fill(
                                member.1 == "pastor" ?
                                LinearGradient(
                                    colors: [Color(hex: "6B2BFF"), Color(hex: "FF3DA5")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [Color(hex: "0066FF"), Color(hex: "3DAEFF")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 42, height: 42)
                            .overlay {
                                Text(String(member.0.prefix(1)))
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .overlay {
                                if member.1 == "pastor" {
                                    Circle()
                                        .strokeBorder(YGColors.paper, lineWidth: 2)
                                }
                            }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 5) {
                                Text(member.0)
                                    .font(.lilitaOne(size: 14.5))
                                    .tracking(-0.2)
                                    .foregroundStyle(YGColors.ink)
                                    .lineLimit(1)
                                
                                if member.1 != "member" {
                                    Text(member.1 == "pastor" ? "PASTOR" : "LEADER")
                                        .font(.system(size: 9, weight: .heavy))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(member.1 == "pastor" ? Color(hex: "6B2BFF") : Color(hex: "0066FF"))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                            }
                            
                            HStack(spacing: 8) {
                                Text(member.4)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(YGColors.ink.opacity(0.55))
                                
                                Text("·")
                                    .foregroundStyle(YGColors.ink.opacity(0.3))
                                
                                Text(member.2)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(YGColors.ink.opacity(0.55))
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 1) {
                            HStack(spacing: 3) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color(hex: "FFD60A"))
                                
                                Text("\(member.3)")
                                    .font(.lilitaOne(size: 12))
                                    .foregroundStyle(YGColors.ink)
                                    .monospacedDigit()
                            }
                            
                            Text("XP")
                                .font(.system(size: 10.5))
                                .foregroundStyle(YGColors.ink.opacity(0.4))
                        }
                        
                        Button {} label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(YGColors.ink.opacity(0.4))
                                .frame(width: 14, height: 14)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .overlay(alignment: .top) {
                        if index > 0 {
                            Divider()
                                .padding(.leading, 14)
                        }
                    }
                }
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.black.opacity(0.04), lineWidth: 0.5)
            }
        }
    }
}

// MARK: - Tier Chip
struct TierChip: View {
    let tier: String
    let label: String
    let count: Int
    
    var tierColor: Color {
        switch tier {
        case "pastor": return Color(hex: "6B2BFF")
        case "leader": return Color(hex: "0066FF")
        default: return YGColors.ink.opacity(0.6)
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tierColor)
                .frame(width: 7, height: 7)
            
            Text(label)
                .font(.lilitaOne(size: 11.5))
                .foregroundStyle(YGColors.ink)
            
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(YGColors.ink.opacity(0.45))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.white)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
        }
    }
}

// MARK: - Post Announcement View
struct PostAnnouncementView: View {
    @Environment(\.dismiss) var dismiss
    @State private var announcementText = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Message")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(YGColors.ink.opacity(0.6))
                    
                    TextEditor(text: $announcementText)
                        .frame(height: 150)
                        .padding(12)
                        .scrollContentBackground(.hidden)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                        }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Send to")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(YGColors.ink.opacity(0.6))
                    
                    HStack(spacing: 12) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color(hex: "6B2BFF"))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Grace City Youth")
                                .font(.lilitaOne(size: 16))
                                .foregroundStyle(YGColors.ink)
                            
                            Text("184 members")
                                .font(.system(size: 13))
                                .foregroundStyle(YGColors.ink.opacity(0.5))
                        }
                        
                        Spacer()
                    }
                    .padding(14)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                    }
                }
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Text("Post Announcement")
                        .font(.lilitaOne(size: 16))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "6B2BFF"))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(20)
            .background(YGColors.paper)
            .navigationTitle("Post Announcement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(YGColors.ink)
                }
            }
        }
    }
}

// MARK: - Create Event View
/// Combines `events.visibility` + `events.rsvp_audience` into one
/// pastor-facing choice. The backend supports both columns
/// independently but we intentionally collapse them to two options —
/// "members only" (groupPrivate + members_only) or "open to public"
/// (public + public) — since those are the only combinations
/// `public_event_summary` accepts as fully shareable.
enum EventAudience: String, CaseIterable {
    case membersOnly = "members_only"
    case publicOpen  = "public_open"

    var title: String {
        switch self {
        case .membersOnly: return "Members only"
        case .publicOpen:  return "Open to public"
        }
    }

    var subtitle: String {
        switch self {
        case .membersOnly: return "Only your youth group can RSVP. Hidden from anyone else."
        case .publicOpen:  return "Anyone with the share link can RSVP. \"Invite a friend\" will appear on the event card."
        }
    }

    var visibility: String   { self == .publicOpen ? "public" : "groupPrivate" }
    var rsvpAudience: String { self == .publicOpen ? "public" : "members_only" }

    /// Map a saved event's two columns back into the picker option.
    /// Anything that isn't exactly the public/public pair counts as
    /// members-only so we never accidentally surface a half-public
    /// event in the share UI.
    static func from(visibility: String, rsvpAudience: String) -> EventAudience {
        (visibility == "public" && rsvpAudience == "public") ? .publicOpen : .membersOnly
    }
}

/// Card-style picker for the two audience options. Shared by
/// CreateEventView and EventDetailView's edit path so flipping a
/// private event to public uses the same visual.
struct EventAudiencePicker: View {
    @Binding var selection: EventAudience

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Who can RSVP")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(YGColors.ink.opacity(0.6))

            VStack(spacing: 10) {
                ForEach(EventAudience.allCases, id: \.self) { opt in
                    Button { selection = opt } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: selection == opt
                                  ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundStyle(selection == opt
                                                 ? YGColors.violet
                                                 : YGColors.ink.opacity(0.3))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(opt.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(YGColors.ink)
                                Text(opt.subtitle)
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(YGColors.ink.opacity(0.55))
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(selection == opt
                                              ? YGColors.violet
                                              : Color.black.opacity(0.08),
                                              lineWidth: selection == opt ? 2 : 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct CreateEventView: View {
    @Environment(\.dismiss) var dismiss

    /// The youth group this event is being created for. Backend INSERT
    /// will key on this; today it's just used to pre-fill the location.
    let groupId: UUID
    /// `public.youth_groups.address` for the active group. May be nil
    /// when the pastor never set one — in that case the Default
    /// option is disabled and we auto-flip to Custom on appear.
    let groupAddress: String?

    @State private var eventName = ""
    @State private var eventDate = Date()
    @State private var eventDescription = ""
    @State private var audience: EventAudience = .membersOnly
    @State private var useDefaultAddress = true
    @State private var customAddress = ""

    @State private var isCreating = false
    @State private var errorMessage: String?

    /// True when we have something usable to render under "Default
    /// location". The card's button is disabled and we force-switch
    /// to Custom on appear when this is false.
    private var hasUsableDefault: Bool {
        !(groupAddress?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    private var defaultAddress: String {
        groupAddress?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
            ?? "No address saved for this group"
    }

    /// The location string actually sent to the server. The DB column
    /// is NOT NULL, so callers gate on `canCreate` before sending.
    private var resolvedLocation: String {
        if useDefaultAddress, let addr = groupAddress,
           !addr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return addr.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return customAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Gate for the Create button — must have a title, a non-empty
    /// resolved location, and not already be mid-insert.
    private var canCreate: Bool {
        !isCreating
            && !eventName.trimmingCharacters(in: .whitespaces).isEmpty
            && !resolvedLocation.isEmpty
    }


    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 0) {
                        HStack {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(YGColors.ink)
                                    .frame(width: 38, height: 38)
                                    .liquidGlass()
                                    .clipShape(Circle())
                            }
                            
                            Spacer()
                            
                            Text("Create Event")
                                .font(.lilitaOne(size: 18))
                                .foregroundStyle(YGColors.ink)
                            
                            Spacer()
                            
                            Button {
                                Task { await createEvent() }
                            } label: {
                                HStack(spacing: 6) {
                                    if isCreating {
                                        ProgressView().tint(.white).scaleEffect(0.8)
                                    }
                                    Text(isCreating ? "Creating…" : "Create")
                                        .font(.lilitaOne(size: 14))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(canCreate ? Color(hex: "6B2BFF") : Color.gray.opacity(0.4))
                                .clipShape(Capsule())
                            }
                            .disabled(!canCreate)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 60)
                        .padding(.bottom, 16)
                    }
                    .background(YGColors.paper)
                    
                    VStack(spacing: 20) {
                        // Event name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Event name")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(YGColors.ink.opacity(0.6))
                            
                            TextField("e.g., Friday Worship Night", text: $eventName)
                                .foregroundStyle(YGColors.ink)
                                .padding(14)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                                }
                        }
                        
                        // Date & time
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Date & time")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(YGColors.ink.opacity(0.6))
                            
                            DatePicker("", selection: $eventDate)
                                .datePickerStyle(.compact)
                                .padding(14)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                                }
                        }
                        
                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(YGColors.ink.opacity(0.6))
                            
                            TextEditor(text: $eventDescription)
                                .foregroundStyle(YGColors.ink)
                                .frame(height: 120)
                                .padding(12)
                                .scrollContentBackground(.hidden)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                                }
                        }
                        
                        // Address
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Location")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(YGColors.ink.opacity(0.6))
                            
                            VStack(spacing: 12) {
                                // Default address option — disabled when
                                // there's no real address on file so a
                                // pastor can't pick a non-existent one.
                                Button {
                                    if hasUsableDefault { useDefaultAddress = true }
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: useDefaultAddress ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 20))
                                            .foregroundStyle(useDefaultAddress ? YGColors.violet : YGColors.ink.opacity(0.3))

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Default location")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(YGColors.ink.opacity(hasUsableDefault ? 1 : 0.45))

                                            Text(defaultAddress)
                                                .font(.system(size: 13))
                                                .foregroundStyle(YGColors.ink.opacity(hasUsableDefault ? 0.6 : 0.4))
                                                .lineLimit(2)
                                        }

                                        Spacer()
                                    }
                                    .padding(14)
                                    .background(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(useDefaultAddress ? YGColors.violet : Color.black.opacity(0.08), lineWidth: useDefaultAddress ? 2 : 1)
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(!hasUsableDefault)
                                
                                // Custom address option
                                VStack(spacing: 8) {
                                    Button {
                                        useDefaultAddress = false
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: !useDefaultAddress ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 20))
                                                .foregroundStyle(!useDefaultAddress ? YGColors.violet : YGColors.ink.opacity(0.3))
                                            
                                            Text("Custom location")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(YGColors.ink)
                                            
                                            Spacer()
                                        }
                                        .padding(14)
                                        .background(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 12)
                                                .strokeBorder(!useDefaultAddress ? YGColors.violet : Color.black.opacity(0.08), lineWidth: !useDefaultAddress ? 2 : 1)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    
                                    if !useDefaultAddress {
                                        TextField("Enter address", text: $customAddress)
                                            .foregroundStyle(YGColors.ink)
                                            .padding(14)
                                            .background(.white)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 12)
                                                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                                            }
                                    }
                                }
                            }
                        }
                        
                        // Audience picker — collapses visibility +
                        // rsvp_audience into one pastor-friendly choice.
                        EventAudiencePicker(selection: $audience)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 100)
                }
            }
            .background(YGColors.paper)
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            // If the group has no saved address, the Default card has
            // nothing to display — force the user onto Custom so they
            // can type something rather than land on a disabled radio.
            if !hasUsableDefault { useDefaultAddress = false }
        }
    }

    // MARK: - Insert

    /// Direct PostgREST insert into `public.events`. RLS policy
    /// `events: pastor write` allows the active group's pastor to
    /// write rows whose `group_id` they pastor. No RPC needed.
    private func createEvent() async {
        guard canCreate else { return }
        await MainActor.run {
            isCreating = true
            errorMessage = nil
        }
        defer { Task { @MainActor in isCreating = false } }

        struct Row: Encodable {
            let group_id: UUID
            let title: String
            let description: String?
            let starts_at: String        // ISO-8601 with fractional seconds
            let location: String
            let visibility: String       // 'public' | 'groupPrivate'
            let rsvp_audience: String    // 'members_only' | 'public'
            let latitude: Double?
            let longitude: Double?
            let created_by: String?
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let trimmedDescription = eventDescription
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Resolve coords from the location text before sending the
        // insert. The helper is timeout-capped at 4s and falls back to
        // nil on any failure — the server has a host-group fallback so
        // a null lat/lng still places the event on the map.
        let coords = await Geo.geocode(resolvedLocation)

        let row = Row(
            group_id:      groupId,
            title:         eventName.trimmingCharacters(in: .whitespacesAndNewlines),
            description:   trimmedDescription.isEmpty ? nil : trimmedDescription,
            starts_at:     iso.string(from: eventDate),
            location:      resolvedLocation,
            visibility:    audience.visibility,
            rsvp_audience: audience.rsvpAudience,
            latitude:      coords?.lat,
            longitude:     coords?.lng,
            created_by:    SupabaseManager.shared.currentUser?.id
        )

        do {
            _ = try await SupabaseManager.shared.client
                .from("events")
                .insert(row)
                .execute()
            // Refresh the events tab so the new row shows up without a
            // manual pull-to-refresh.
            try? await EventsService.shared.loadGroupEvents(groupId: groupId, upcoming: true)
            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run {
                errorMessage = "Couldn't create. \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Helpers

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

extension Int {
    /// "st" / "nd" / "rd" / "th" for an integer, honoring the 11/12/13
    /// English exceptions. Shared by the grade pill in event RSVP rows,
    /// the pastor members list, and the member detail sheet.
    var ordinalSuffix: String {
        switch self % 100 {
        case 11, 12, 13: return "th"
        default:
            switch self % 10 {
            case 1: return "st"
            case 2: return "nd"
            case 3: return "rd"
            default: return "th"
            }
        }
    }
}

// MARK: - Events Manager View
struct EventsManagerView: View {
    var groupId: UUID? = nil

    @Environment(\.dismiss) var dismiss
    @State private var eventsService = EventsService.shared
    @State private var selectedTab: EventTab = .upcoming
    @State private var showEditEvent = false
    @State private var selectedEvent: Event?
    @State private var showDeleteConfirmation = false
    @State private var eventToDelete: Event?
    @State private var showCreateEvent = false
    @State private var isLoading = false
    @State private var upcomingFetched: [Event] = []
    @State private var pastFetched: [Event] = []

    enum EventTab {
        case upcoming
        case past
    }

    /// Per-tab event lists. Pulled live from EventsService when `groupId`
    /// is supplied; falls back to the sample fixture for the legacy
    /// PastorGroupManagementView preview path.
    private var upcomingEvents: [Event] {
        groupId == nil ? Event.sampleEvents.filter { !$0.isPast } : upcomingFetched
    }

    private var pastEvents: [Event] {
        groupId == nil ? Event.sampleEvents.filter { $0.isPast } : pastFetched
    }

    var displayedEvents: [Event] {
        selectedTab == .upcoming ? upcomingEvents : pastEvents
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 0) {
                        HStack {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(YGColors.ink)
                                    .frame(width: 38, height: 38)
                                    .liquidGlass()
                                    .clipShape(Circle())
                            }
                            
                            Spacer()
                            
                            Text("Events")
                                .font(.lilitaOne(size: 18))
                                .foregroundStyle(YGColors.ink)

                            Spacer()

                            Button { showCreateEvent = true } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .heavy))
                                    .foregroundStyle(.white)
                                    .frame(width: 38, height: 38)
                                    .background(
                                        LinearGradient(colors: [YGColors.violet, Color(hex: "FF3DA5")],
                                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 60)
                        .padding(.bottom, 16)
                    }
                    .background(YGColors.paper)
                    
                    VStack(spacing: 20) {
                        // Tab selector
                        HStack(spacing: 8) {
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedTab = .upcoming
                                }
                            } label: {
                                Text("Upcoming")
                                    .font(.lilitaOne(size: 14))
                                    .foregroundStyle(selectedTab == .upcoming ? .white : YGColors.ink.opacity(0.6))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(selectedTab == .upcoming ? YGColors.violet : Color.clear)
                                    .clipShape(Capsule())
                            }
                            
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedTab = .past
                                }
                            } label: {
                                Text("Past")
                                    .font(.lilitaOne(size: 14))
                                    .foregroundStyle(selectedTab == .past ? .white : YGColors.ink.opacity(0.6))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(selectedTab == .past ? YGColors.violet : Color.clear)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(4)
                        .background(.white)
                        .clipShape(Capsule())
                        .overlay {
                            Capsule()
                                .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                        }
                        .padding(.horizontal, 20)
                        
                        // Events list
                        if displayedEvents.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: selectedTab == .upcoming ? "calendar.badge.clock" : "calendar.badge.checkmark")
                                    .font(.system(size: 48))
                                    .foregroundStyle(YGColors.ink.opacity(0.3))
                                
                                Text(selectedTab == .upcoming ? "No upcoming events" : "No past events")
                                    .font(.lilitaOne(size: 18))
                                    .foregroundStyle(YGColors.ink)
                                
                                Text(selectedTab == .upcoming ? "Create an event to get started" : "Past events will appear here")
                                    .font(.system(size: 14))
                                    .foregroundStyle(YGColors.ink.opacity(0.5))
                            }
                            .padding(.top, 60)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(displayedEvents) { event in
                                    EventCardView(
                                        event: event,
                                        isUpcoming: selectedTab == .upcoming,
                                        onTap: {
                                            selectedEvent = event
                                            if selectedTab == .upcoming {
                                                showEditEvent = true
                                            }
                                        },
                                        onDelete: {
                                            eventToDelete = event
                                            showDeleteConfirmation = true
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 100)
                }
            }
            .background(YGColors.paper)
            .ignoresSafeArea(edges: .top)
        }
        .sheet(isPresented: $showEditEvent) {
            if let event = selectedEvent {
                // Opened from the pastor management surface, so the
                // viewer is by definition a pastor of this group →
                // inline-edit mode on.
                EventDetailView(event: event, canEdit: true)
            }
        }
        .sheet(isPresented: $showCreateEvent) {
            if let groupId = PastorDashboardService.shared.activeGroupId {
                let address = PastorDashboardService.shared
                    .myGroups
                    .first(where: { $0.id == groupId })?
                    .address
                CreateEventView(groupId: groupId, groupAddress: address)
            }
        }
        .alert("Delete Event", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                // Delete event logic here
            }
        } message: {
            if let event = eventToDelete {
                Text("Are you sure you want to delete \"\(event.title)\"? This cannot be undone.")
            }
        }
        .task(id: groupId) {
            await loadEvents()
        }
        .refreshable {
            await loadEvents()
        }
    }

    private func loadEvents() async {
        guard let groupId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            // EventsService overwrites its cache per call, so snapshot
            // each side into local state.
            try await eventsService.loadGroupEvents(groupId: groupId, upcoming: true)
            upcomingFetched = (eventsService.eventsByGroup[groupId] ?? []).map(Event.init(from:))

            try await eventsService.loadGroupEvents(groupId: groupId, upcoming: false)
            pastFetched = (eventsService.eventsByGroup[groupId] ?? []).map(Event.init(from:))
        } catch {
            print("[EventsManagerView] loadGroupEvents failed:", error)
        }
    }
}

// MARK: - Event Card View
struct EventCardView: View {
    let event: Event
    let isUpcoming: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    /// Drives the share sheet for the "Invite a friend" pill. Local
    /// to each card so a tap doesn't blast every visible card.
    @State private var showShareSheet = false

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(.lilitaOne(size: 16))
                            .tracking(-0.2)
                            .foregroundStyle(YGColors.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 12))
                                Text(event.formattedDate)
                                    .font(.system(size: 13))
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 12))
                                Text(event.time)
                                    .font(.system(size: 13))
                            }
                        }
                        .foregroundStyle(YGColors.ink.opacity(0.6))
                        
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle")
                                .font(.system(size: 12))
                            Text(event.location)
                                .font(.system(size: 13))
                        }
                        .foregroundStyle(YGColors.ink.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    if isUpcoming {
                        Menu {
                            Button {
                                onTap()
                            } label: {
                                Label("Edit Event", systemImage: "pencil")
                            }
                            
                            Button {
                                // View RSVPs
                            } label: {
                                Label("View RSVPs", systemImage: "person.2")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                onDelete()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(YGColors.ink.opacity(0.4))
                                .frame(width: 32, height: 32)
                        }
                    } else {
                        Button {
                            // Add photos/videos
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Add Media")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(YGColors.violet)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(YGColors.violet.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                }
                
                if isUpcoming, event.rsvpStatus != nil {
                    HStack(spacing: 8) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 12))
                        Text("34 going · 12 maybe · 5 no")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(YGColors.violet)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(YGColors.violet.opacity(0.1))
                    .clipShape(Capsule())
                }

                // Public events get a share pill so the pastor (or any
                // viewer) can text the public RSVP link to a friend.
                if isUpcoming, event.isPublicRsvp {
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
                            .foregroundStyle(YGColors.violet)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(YGColors.violet.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !isUpcoming && !event.media.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 12))
                        Text("\(event.media.count) photos & videos")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(YGColors.ink.opacity(0.6))
                }
            }
            .padding(16)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.black.opacity(0.05), lineWidth: 0.5)
            }
            .shadow(color: YGColors.ink.opacity(0.04), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showShareSheet) {
            ActivityView(activityItems: Self.shareItems(for: event))
        }
    }

    /// Invite blurb + public RSVP URL. The page at
    /// `ygteev.com/events/<id>` is the Lovable companion that handles
    /// the email-only RSVP flow for friends who don't have the app.
    fileprivate static func shareItems(for event: Event) -> [Any] {
        let id = event.id.lowercased()
        let url = URL(string: "\(Event.publicEventBaseURL)/\(id)")!
        let text = "Hey, you should come to the \(event.title) with me. RSVP here so they know you're coming."
        return [text, url]
    }
}

// MARK: - Event Detail View
//
// Partiful-style detail screen used by both pastors (with inline edit
// + Save) and members (read-only header + viewer RSVP buttons). RSVP
// counts and rosters come from the real `event_rsvp_summary` RPC —
// no more 34/12/5 demo numbers.
struct EventDetailView: View {
    @Environment(\.dismiss) private var dismiss

    @State var event: Event
    /// Pastors get inline editing; members get read-only header +
    /// their own RSVP buttons.
    let canEdit: Bool

    @State private var summary: EventRSVPSummary?
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var error: String?

    // Inline edit drafts — only used when `canEdit` is true.
    @State private var titleDraft = ""
    @State private var dateDraft  = Date()
    @State private var locationDraft = ""
    @State private var descriptionDraft = ""
    @State private var audienceDraft: EventAudience = .membersOnly

    @State private var rsvpFilter: RSVPFilter = .going
    enum RSVPFilter: String, CaseIterable { case going, maybe, declined }

    /// Drives the iOS share sheet for the "Invite a friend" pill.
    @State private var showShareSheet = false

    private var eventUUID: UUID? { UUID(uuidString: event.id) }

    private var hasUnsavedChanges: Bool {
        titleDraft       != event.title
        || dateDraft     != event.date
        || locationDraft != event.location
        || descriptionDraft != (event.description ?? "")
        || audienceDraft != EventAudience.from(visibility: event.visibility,
                                               rsvpAudience: event.rsvpAudience)
    }

    private var canSave: Bool {
        canEdit && !isSaving && hasUnsavedChanges
            && !titleDraft.trimmingCharacters(in: .whitespaces).isEmpty
            && !locationDraft.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    hero
                    Divider().padding(.horizontal, 16)
                    detailBlock
                    if event.isPublicRsvp {
                        inviteFriendButton
                    }
                    Divider().padding(.horizontal, 16)
                    rsvpBlock
                    if let error {
                        Text(error)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 20)
            }
            .background(YGColors.paper.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(YGColors.ink)
                }
                if canEdit {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(isSaving ? "Saving…" : "Save") {
                            Task { await save() }
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(canSave ? YGColors.violet : YGColors.ink.opacity(0.3))
                        .disabled(!canSave)
                    }
                }
            }
        }
        .task {
            seedDraftsFromEvent()
            await loadSummary()
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityView(activityItems: EventCardView.shareItems(for: event))
        }
    }

    /// "Invite a friend" pill — public-RSVP events only. Drops the
    /// share sheet pre-filled with the friend-facing RSVP URL.
    private var inviteFriendButton: some View {
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
                .foregroundStyle(YGColors.violet)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(YGColors.violet.opacity(0.12))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EVENT")
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.4)
                .foregroundStyle(YGColors.violet)

            if canEdit {
                TextField("Event name", text: $titleDraft)
                    .font(.lilitaOne(size: 30))
                    .tracking(-0.6)
                    .foregroundStyle(YGColors.ink)
            } else {
                Text(event.title)
                    .font(.lilitaOne(size: 30))
                    .tracking(-0.6)
                    .foregroundStyle(YGColors.ink)
            }

            HStack(spacing: 14) {
                Label(formatted(canEdit ? dateDraft : event.date), systemImage: "calendar")
                Label(canEdit ? locationDraft.nilIfEmpty ?? event.location : event.location,
                      systemImage: "mappin.and.ellipse")
                    .lineLimit(1)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(YGColors.ink.opacity(0.6))
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Detail block

    @ViewBuilder
    private var detailBlock: some View {
        if canEdit {
            VStack(alignment: .leading, spacing: 12) {
                fieldLabel("DATE & TIME")
                DatePicker("", selection: $dateDraft)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .padding(.vertical, 4)

                fieldLabel("LOCATION")
                TextField("Address", text: $locationDraft)
                    .foregroundStyle(YGColors.ink)
                    .padding(12)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                    }

                fieldLabel("DESCRIPTION")
                TextEditor(text: $descriptionDraft)
                    .foregroundStyle(YGColors.ink)
                    .frame(height: 110)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                    }

                // Pastor can flip an existing event from members-only
                // to publicly RSVP-able (and back) after creation.
                EventAudiencePicker(selection: $audienceDraft)
            }
            .padding(.horizontal, 16)
        } else if let desc = event.description, !desc.isEmpty {
            Text(desc)
                .font(.system(size: 15))
                .foregroundStyle(YGColors.ink)
                .padding(.horizontal, 16)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .heavy))
            .tracking(1.2)
            .foregroundStyle(YGColors.ink.opacity(0.5))
    }

    // MARK: - RSVP block

    private var rsvpBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("RSVPs")
                    .font(.lilitaOne(size: 18))
                    .foregroundStyle(YGColors.ink)
                Spacer()
                if let s = summary {
                    Text("\(s.totalCount) responded")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(YGColors.ink.opacity(0.55))
                }
            }
            .padding(.horizontal, 16)

            HStack(spacing: 10) {
                rsvpChip(.going,    label: "Going",   color: Color(hex: "2B8A3E"))
                rsvpChip(.maybe,    label: "Maybe",   color: Color(hex: "B8860B"))
                rsvpChip(.declined, label: "No",      color: Color(hex: "C53030"))
            }
            .padding(.horizontal, 16)

            // Pastors are the host — no self-RSVP UI on their own event.
            if !canEdit, summary != nil {
                viewerRSVPButtons.padding(.horizontal, 16)
            }

            participantsList.padding(.horizontal, 16)
        }
    }

    private func rsvpChip(_ filter: RSVPFilter, label: String, color: Color) -> some View {
        Button { rsvpFilter = filter } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(count(for: filter))")
                    .font(.lilitaOne(size: 28))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(YGColors.ink)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(rsvpFilter == filter ? color : Color.black.opacity(0.06),
                                  lineWidth: rsvpFilter == filter ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var viewerRSVPButtons: some View {
        HStack(spacing: 8) {
            rsvpAction(label: "Going",   value: "going",    accent: Color(hex: "2B8A3E"))
            rsvpAction(label: "Maybe",   value: "maybe",    accent: Color(hex: "B8860B"))
            rsvpAction(label: "Can't",   value: "declined", accent: Color(hex: "C53030"))
        }
    }

    private func rsvpAction(label: String, value: String, accent: Color) -> some View {
        let isSelected = summary?.viewerStatus == value
        return Button {
            Task { await toggleRSVP(value: value, currentlySelected: isSelected) }
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(isSelected ? .white : accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? accent : Color.white)
                .clipShape(Capsule())
                .overlay { Capsule().strokeBorder(accent, lineWidth: 1.2) }
        }
        .buttonStyle(.plain)
    }

    private var participantsList: some View {
        VStack(spacing: 8) {
            ForEach(participants(for: rsvpFilter)) { p in
                participantRow(p)
            }
            if participants(for: rsvpFilter).isEmpty && !isLoading {
                Text("No \(rsvpFilter.rawValue) responses yet.")
                    .font(.system(size: 13))
                    .foregroundStyle(YGColors.ink.opacity(0.45))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 14)
            }
        }
    }

    private func participantRow(_ p: EventRSVPParticipant) -> some View {
        HStack(spacing: 12) {
            Text(String((p.displayName ?? "?").prefix(1)).uppercased())
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(
                    LinearGradient(
                        colors: [YGColors.violet, Color(hex: "FF3DA5")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(p.displayName ?? "Unnamed")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(YGColors.ink)

                // Handle + role + grade strip. Each chip is conditional
                // so rows with neither role nor grade collapse to just
                // the handle (or nothing) — no empty pill space.
                HStack(spacing: 6) {
                    if let h = p.handle, !h.isEmpty {
                        Text("@\(h)")
                            .font(.system(size: 11.5))
                            .foregroundStyle(YGColors.ink.opacity(0.5))
                    }
                    if let role = p.role { rolePill(role) }
                    if let grade = p.gradeYear { gradePill(grade) }
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func rolePill(_ role: String) -> some View {
        let (label, fg, bg): (String, Color, Color) = {
            switch role {
            case "pastor":
                return ("PASTOR", Color(hex: "6B2BFF"), Color(hex: "6B2BFF").opacity(0.12))
            case "leader":
                return ("LEADER", Color(hex: "0066FF"), Color(hex: "0066FF").opacity(0.12))
            default:
                return ("MEMBER", YGColors.ink.opacity(0.55), YGColors.ink.opacity(0.06))
            }
        }()
        Text(label)
            .font(.system(size: 9.5, weight: .heavy))
            .tracking(0.4)
            .foregroundStyle(fg)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func gradePill(_ grade: Int) -> some View {
        Text("\(grade)\(grade.ordinalSuffix) grade")
            .font(.system(size: 9.5, weight: .heavy))
            .tracking(0.3)
            .foregroundStyle(Color(hex: "2B8A3E"))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(hex: "2B8A3E").opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Helpers

    private func count(for filter: RSVPFilter) -> Int {
        switch filter {
        case .going:    return summary?.goingCount    ?? 0
        case .maybe:    return summary?.maybeCount    ?? 0
        case .declined: return summary?.declinedCount ?? 0
        }
    }

    private func participants(for filter: RSVPFilter) -> [EventRSVPParticipant] {
        switch filter {
        case .going:    return summary?.going    ?? []
        case .maybe:    return summary?.maybe    ?? []
        case .declined: return summary?.declined ?? []
        }
    }

    private func seedDraftsFromEvent() {
        titleDraft       = event.title
        dateDraft        = event.date
        locationDraft    = event.location
        descriptionDraft = event.description ?? ""
        audienceDraft    = EventAudience.from(visibility: event.visibility,
                                              rsvpAudience: event.rsvpAudience)
    }

    private func formatted(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: date)
    }

    // MARK: - Network

    private func loadSummary() async {
        guard let id = eventUUID else { isLoading = false; return }
        isLoading = true
        defer { isLoading = false }
        do {
            summary = try await EventsService.shared.fetchRSVPSummary(eventId: id)
        } catch {
            self.error = "Couldn't load RSVPs. \(error.localizedDescription)"
        }
    }

    private func toggleRSVP(value: String, currentlySelected: Bool) async {
        guard let id = eventUUID else { return }
        do {
            if currentlySelected {
                summary = try await EventsService.shared.clearMyRSVP(eventId: id)
            } else {
                summary = try await EventsService.shared.setMyRSVP(eventId: id, status: value)
            }
        } catch {
            self.error = "Couldn't update your RSVP. \(error.localizedDescription)"
        }
    }

    private func save() async {
        guard canSave, let id = eventUUID else { return }
        isSaving = true
        error = nil
        defer { isSaving = false }

        // Patch without coords — used when the location text didn't
        // change. Omitting `latitude`/`longitude` from the payload
        // keeps the existing stored coords intact (avoids the
        // accidental NULL-out a single Patch struct would cause).
        struct Patch: Encodable {
            let title: String
            let description: String?
            let starts_at: String
            let location: String
            let visibility: String
            let rsvp_audience: String
        }
        // Patch WITH coords — used when the user edited the address.
        // `latitude`/`longitude` are nullable so a failed geocode of a
        // new address explicitly clears stale coords.
        struct PatchWithCoords: Encodable {
            let title: String
            let description: String?
            let starts_at: String
            let location: String
            let visibility: String
            let rsvp_audience: String
            let latitude: Double?
            let longitude: Double?
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let trimmedLocation = locationDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = descriptionDraft
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        let startsAt = iso.string(from: dateDraft)
        let locationChanged = trimmedLocation != event.location

        do {
            if locationChanged {
                // Re-geocode the new address. A failed geocode here
                // resolves to nil and explicitly null-outs the
                // previously-stored coords so we don't keep stale ones.
                let coords = await Geo.geocode(trimmedLocation)
                let patch = PatchWithCoords(
                    title: titleDraft.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: trimmedDescription,
                    starts_at: startsAt,
                    location: trimmedLocation,
                    visibility: audienceDraft.visibility,
                    rsvp_audience: audienceDraft.rsvpAudience,
                    latitude: coords?.lat,
                    longitude: coords?.lng
                )
                _ = try await SupabaseManager.shared.client
                    .from("events")
                    .update(patch)
                    .eq("id", value: id.uuidString.lowercased())
                    .execute()
                event.title        = patch.title
                event.date         = dateDraft
                event.location     = patch.location
                event.description  = patch.description
                event.visibility   = patch.visibility
                event.rsvpAudience = patch.rsvp_audience
                event.latitude     = patch.latitude
                event.longitude    = patch.longitude
            } else {
                let patch = Patch(
                    title: titleDraft.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: trimmedDescription,
                    starts_at: startsAt,
                    location: trimmedLocation,
                    visibility: audienceDraft.visibility,
                    rsvp_audience: audienceDraft.rsvpAudience
                )
                _ = try await SupabaseManager.shared.client
                    .from("events")
                    .update(patch)
                    .eq("id", value: id.uuidString.lowercased())
                    .execute()
                event.title        = patch.title
                event.date         = dateDraft
                event.location     = patch.location
                event.description  = patch.description
                event.visibility   = patch.visibility
                event.rsvpAudience = patch.rsvp_audience
            }
            dismiss()
        } catch {
            self.error = "Couldn't save. \(error.localizedDescription)"
        }
    }
}

// MARK: - RSVP Stat View
struct RSVPStatView: View {
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text("\(count)")
                .font(.lilitaOne(size: 24))
                .foregroundStyle(color)
            
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(YGColors.ink.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.black.opacity(0.05), lineWidth: 0.5)
        }
    }
}

// MARK: - Publish Plan View
struct PublishPlanView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 0) {
                        HStack {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(YGColors.ink)
                                    .frame(width: 38, height: 38)
                                    .liquidGlass()
                                    .clipShape(Circle())
                            }
                            
                            Spacer()
                            
                            Text("Publish Bible Plan")
                                .font(.lilitaOne(size: 18))
                                .foregroundStyle(YGColors.ink)
                            
                            Spacer()
                            
                            // Placeholder for symmetry
                            Color.clear
                                .frame(width: 38, height: 38)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 60)
                        .padding(.bottom, 16)
                    }
                    .background(YGColors.paper)
                    
                    VStack(spacing: 16) {
                        Text("Create custom Bible reading plans for your youth group")
                            .font(.system(size: 15))
                            .foregroundStyle(YGColors.ink.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.top, 20)
                        
                        // Placeholder content
                        VStack(spacing: 12) {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(Color(hex: "6B2BFF"))
                                .padding(.top, 40)
                            
                            Text("Plan Builder")
                                .font(.lilitaOne(size: 20))
                                .foregroundStyle(YGColors.ink)
                            
                            Text("Coming soon")
                                .font(.system(size: 14))
                                .foregroundStyle(YGColors.ink.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(Color.black.opacity(0.04), lineWidth: 0.5)
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 100)
                }
            }
            .background(YGColors.paper)
            .ignoresSafeArea(edges: .top)
        }
    }
}

// MARK: - Manage Small Groups View
struct ManageSmallGroupsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showCreateGroup = false
    @State private var smallGroups: [SmallGroup]
    @State private var allMembers: [PastorGroupMember]
    
    init() {
        _smallGroups = State(initialValue: Self.sampleSmallGroups)
        _allMembers = State(initialValue: Self.sampleMembers)
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 0) {
                        HStack {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(YGColors.ink)
                                    .frame(width: 38, height: 38)
                                    .liquidGlass()
                                    .clipShape(Circle())
                            }
                            
                            Spacer()
                            
                            Text("Small Groups")
                                .font(.lilitaOne(size: 18))
                                .foregroundStyle(YGColors.ink)
                            
                            Spacer()
                            
                            Button {
                                showCreateGroup = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(YGColors.ink)
                                    .frame(width: 38, height: 38)
                                    .liquidGlass()
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 60)
                        .padding(.bottom, 16)
                    }
                    .background(YGColors.paper)
                    
                    VStack(spacing: 12) {
                        // Small group cards
                        ForEach(smallGroups) { group in
                            SmallGroupCard(
                                group: group,
                                allMembers: $allMembers,
                                smallGroups: $smallGroups
                            )
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 100)
                }
            }
            .background(YGColors.paper)
            .ignoresSafeArea(edges: .top)
        }
        .sheet(isPresented: $showCreateGroup) {
            CreateSmallGroupView(
                allMembers: $allMembers,
                smallGroups: $smallGroups
            )
        }
    }
    
    static var sampleSmallGroups: [SmallGroup] {
        [
            SmallGroup(id: "1", name: "Tuesday Night SG", leader: "Sam W.", leaderMemberId: "leader1", memberIds: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12"], day: "Tuesdays"),
            SmallGroup(id: "2", name: "Friday Morning SG", leader: "Maya R.", leaderMemberId: "leader2", memberIds: ["13", "14", "15", "16", "17", "18", "19", "20"], day: "Fridays"),
            SmallGroup(id: "3", name: "Sunday Afternoon SG", leader: "Jordan K.", leaderMemberId: "leader3", memberIds: ["21", "22", "23", "24", "25", "26", "27", "28", "29", "30", "31", "32", "33", "34", "35"], day: "Sundays"),
            SmallGroup(id: "4", name: "Wednesday SG", leader: "Alex M.", leaderMemberId: "leader4", memberIds: ["36", "37", "38", "39", "40", "41", "42", "43", "44", "45"], day: "Wednesdays"),
            SmallGroup(id: "5", name: "Saturday Morning SG", leader: "Chris L.", leaderMemberId: nil, memberIds: ["46", "47", "48", "49", "50", "51", "52", "53", "54"], day: "Saturdays"),
            SmallGroup(id: "6", name: "Thursday Evening SG", leader: "Taylor S.", leaderMemberId: nil, memberIds: ["55", "56", "57", "58", "59", "60", "61", "62", "63", "64", "65"], day: "Thursdays"),
        ]
    }
    
    static var sampleMembers: [PastorGroupMember] {
        var members: [PastorGroupMember] = []
        
        // Members in small groups
        for i in 1...65 {
            let groupId: String?
            if i <= 12 { groupId = "1" }
            else if i <= 20 { groupId = "2" }
            else if i <= 35 { groupId = "3" }
            else if i <= 45 { groupId = "4" }
            else if i <= 54 { groupId = "5" }
            else { groupId = "6" }
            
            members.append(PastorGroupMember(
                id: "\(i)",
                name: "Member \(i)",
                age: Int.random(in: 12...18),
                avatar: "😊",
                smallGroupId: groupId,
                isLeader: false
            ))
        }
        
        // Members without small groups
        for i in 66...84 {
            members.append(PastorGroupMember(
                id: "\(i)",
                name: "Member \(i)",
                age: Int.random(in: 12...18),
                avatar: "😊",
                smallGroupId: nil,
                isLeader: false
            ))
        }
        
        // Potential leaders
        members.append(contentsOf: [
            PastorGroupMember(id: "leader1", name: "Sam W.", age: 25, avatar: "👨", smallGroupId: "1", isLeader: true),
            PastorGroupMember(id: "leader2", name: "Maya R.", age: 23, avatar: "👩", smallGroupId: "2", isLeader: true),
            PastorGroupMember(id: "leader3", name: "Jordan K.", age: 26, avatar: "🧑", smallGroupId: "3", isLeader: true),
            PastorGroupMember(id: "leader4", name: "Alex M.", age: 24, avatar: "👨", smallGroupId: "4", isLeader: true),
            PastorGroupMember(id: "leader5", name: "Chris L.", age: 27, avatar: "👨", smallGroupId: nil, isLeader: true),
            PastorGroupMember(id: "leader6", name: "Taylor S.", age: 22, avatar: "👩", smallGroupId: nil, isLeader: true),
            PastorGroupMember(id: "leader7", name: "Pat M.", age: 25, avatar: "🧑", smallGroupId: nil, isLeader: true),
        ])
        
        return members
    }
}

struct SmallGroup: Identifiable {
    let id: String
    var name: String
    var leader: String
    var leaderMemberId: String?
    var memberIds: [String]
    var day: String
    
    var memberCount: Int {
        memberIds.count
    }
}

struct PastorGroupMember: Identifiable {
    let id: String
    let name: String
    let age: Int
    let avatar: String
    var smallGroupId: String?
    let isLeader: Bool
    
    var hasSmallGroup: Bool {
        smallGroupId != nil
    }
}

struct SmallGroupCard: View {
    let group: SmallGroup
    @Binding var allMembers: [PastorGroupMember]
    @Binding var smallGroups: [SmallGroup]
    @State private var showGroupDetail = false
    
    var body: some View {
        Button {
            showGroupDetail = true
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "6B2BFF"), Color(hex: "FF3DA5")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                    }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(group.name)
                        .font(.lilitaOne(size: 16))
                        .foregroundStyle(YGColors.ink)
                    
                    HStack(spacing: 6) {
                        Text("Led by \(group.leader)")
                            .font(.system(size: 13))
                            .foregroundStyle(YGColors.ink.opacity(0.5))
                        
                        Text("•")
                            .foregroundStyle(YGColors.ink.opacity(0.3))
                        
                        Text("\(group.memberCount) members")
                            .font(.system(size: 13))
                            .foregroundStyle(YGColors.ink.opacity(0.5))
                    }
                    
                    Text(group.day)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "6B2BFF"))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(YGColors.ink.opacity(0.3))
            }
            .padding(16)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.black.opacity(0.04), lineWidth: 0.5)
            }
        }
        .sheet(isPresented: $showGroupDetail) {
            SmallGroupDetailView(
                group: group,
                allMembers: $allMembers,
                smallGroups: $smallGroups
            )
        }
    }
}

// MARK: - Small Group Detail View
struct SmallGroupDetailView: View {
    @Environment(\.dismiss) var dismiss
    let group: SmallGroup
    @Binding var allMembers: [PastorGroupMember]
    @Binding var smallGroups: [SmallGroup]
    @State private var showAddMembers = false
    @State private var showAssignLeader = false
    @State private var searchText = ""
    @State private var showRemoveConfirmation = false
    @State private var memberToRemove: PastorGroupMember?
    
    var groupMembers: [PastorGroupMember] {
        allMembers.filter { $0.smallGroupId == group.id }
    }
    
    var filteredMembers: [PastorGroupMember] {
        if searchText.isEmpty {
            return groupMembers
        }
        return groupMembers.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Group info header
                VStack(spacing: 12) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [YGColors.violet, YGColors.pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .overlay {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.white)
                        }
                    
                    Text(group.name)
                        .font(.lilitaOne(size: 24))
                        .foregroundStyle(YGColors.ink)
                    
                    Text("\(group.day) • \(group.memberCount) members")
                        .font(.system(size: 14))
                        .foregroundStyle(YGColors.ink.opacity(0.5))
                    
                    // Assign Leader Button
                    Button {
                        showAssignLeader = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                            Text("Leader: \(group.leader)")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(Color(hex: "6B2BFF"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(YGColors.violet.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 20)
                
                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(YGColors.ink.opacity(0.4))
                    
                    TextField("Search members...", text: $searchText)
                        .font(.system(size: 15))
                }
                .padding(12)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                
                // Members list
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(filteredMembers.enumerated()), id: \.element.id) { index, member in
                            MemberRowView(
                                member: member,
                                onRemove: {
                                    memberToRemove = member
                                    showRemoveConfirmation = true
                                }
                            )
                            
                            if index < filteredMembers.count - 1 {
                                Divider()
                                    .padding(.leading, 68)
                            }
                        }
                    }
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.black.opacity(0.04), lineWidth: 0.5)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
            .background(YGColors.paper)
            .navigationTitle("Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(YGColors.ink)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddMembers = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(YGColors.ink)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddMembers) {
            AddMembersView(
                group: group,
                allMembers: $allMembers,
                smallGroups: $smallGroups
            )
        }
        .sheet(isPresented: $showAssignLeader) {
            AssignLeaderView(
                group: group,
                allMembers: $allMembers,
                smallGroups: $smallGroups
            )
        }
        .alert("Remove Member", isPresented: $showRemoveConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                if let member = memberToRemove {
                    removeMember(member)
                }
            }
        } message: {
            if let member = memberToRemove {
                Text("Are you sure you want to remove \(member.name) from \(group.name)?")
            }
        }
    }
    
    func removeMember(_ member: PastorGroupMember) {
        if let memberIndex = allMembers.firstIndex(where: { $0.id == member.id }) {
            allMembers[memberIndex].smallGroupId = nil
        }
        
        if let groupIndex = smallGroups.firstIndex(where: { $0.id == group.id }) {
            smallGroups[groupIndex].memberIds.removeAll { $0 == member.id }
        }
    }
}

// MARK: - Member Row View
struct MemberRowView: View {
    let member: PastorGroupMember
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(YGColors.ink)
                
                Text("\(member.age) years old")
                    .font(.system(size: 13))
                    .foregroundStyle(YGColors.ink.opacity(0.5))
            }
            
            Spacer()
            
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(YGColors.ink.opacity(0.3))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Add Members View
struct AddMembersView: View {
    @Environment(\.dismiss) var dismiss
    let group: SmallGroup
    @Binding var allMembers: [PastorGroupMember]
    @Binding var smallGroups: [SmallGroup]
    @State private var searchText = ""
    @State private var showOnlyWithoutGroup = false
    @State private var selectedMemberIds: Set<String> = []
    
    var availableMembers: [PastorGroupMember] {
        allMembers.filter { member in
            member.smallGroupId != group.id && !member.isLeader
        }
    }
    
    var filteredMembers: [PastorGroupMember] {
        var members = availableMembers
        
        if showOnlyWithoutGroup {
            members = members.filter { !$0.hasSmallGroup }
        }
        
        if !searchText.isEmpty {
            members = members.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        return members
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(YGColors.ink.opacity(0.4))
                    
                    TextField("Search members...", text: $searchText)
                        .font(.system(size: 15))
                }
                .padding(12)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Filter toggle
                Button {
                    showOnlyWithoutGroup.toggle()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: showOnlyWithoutGroup ? "checkmark.square.fill" : "square")
                            .font(.system(size: 16))
                            .foregroundStyle(showOnlyWithoutGroup ? Color(hex: "6B2BFF") : YGColors.ink.opacity(0.3))
                        
                        Text("Show only members without a small group")
                            .font(.system(size: 14))
                            .foregroundStyle(YGColors.ink)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                
                // Members list
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(filteredMembers.enumerated()), id: \.element.id) { index, member in
                            SelectableMemberRow(
                                member: member,
                                isSelected: selectedMemberIds.contains(member.id),
                                onToggle: {
                                    if selectedMemberIds.contains(member.id) {
                                        selectedMemberIds.remove(member.id)
                                    } else {
                                        selectedMemberIds.insert(member.id)
                                    }
                                }
                            )
                            
                            if index < filteredMembers.count - 1 {
                                Divider()
                                    .padding(.leading, 68)
                            }
                        }
                    }
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.black.opacity(0.04), lineWidth: 0.5)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
            .background(YGColors.paper)
            .navigationTitle("Add Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(YGColors.ink)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add (\(selectedMemberIds.count))") {
                        addSelectedMembers()
                        dismiss()
                    }
                    .foregroundStyle(selectedMemberIds.isEmpty ? YGColors.ink.opacity(0.3) : Color(hex: "6B2BFF"))
                    .disabled(selectedMemberIds.isEmpty)
                }
            }
        }
    }
    
    func addSelectedMembers() {
        for memberId in selectedMemberIds {
            if let memberIndex = allMembers.firstIndex(where: { $0.id == memberId }) {
                allMembers[memberIndex].smallGroupId = group.id
            }
            
            if let groupIndex = smallGroups.firstIndex(where: { $0.id == group.id }) {
                if !smallGroups[groupIndex].memberIds.contains(memberId) {
                    smallGroups[groupIndex].memberIds.append(memberId)
                }
            }
        }
    }
}

// MARK: - Selectable Member Row
struct SelectableMemberRow: View {
    let member: PastorGroupMember
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button {
            onToggle()
        } label: {
            HStack(spacing: 12) {
                Text(member.avatar)
                    .font(.system(size: 36))
                    .frame(width: 44, height: 44)
                    .background(Color(hex: "6B2BFF").opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(YGColors.ink)
                    
                    HStack(spacing: 6) {
                        Text("\(member.age) years old")
                            .font(.system(size: 13))
                            .foregroundStyle(YGColors.ink.opacity(0.5))
                        
                        if member.hasSmallGroup {
                            Text("•")
                                .foregroundStyle(YGColors.ink.opacity(0.3))
                            Text("In group")
                                .font(.system(size: 13))
                                .foregroundStyle(YGColors.ink.opacity(0.5))
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Color(hex: "6B2BFF") : YGColors.ink.opacity(0.2))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Assign Leader View
struct AssignLeaderView: View {
    @Environment(\.dismiss) var dismiss
    let group: SmallGroup
    @Binding var allMembers: [PastorGroupMember]
    @Binding var smallGroups: [SmallGroup]
    @State private var searchText = ""
    @State private var selectedLeaderId: String?
    
    var availableLeaders: [PastorGroupMember] {
        allMembers.filter { $0.isLeader }
    }
    
    var filteredLeaders: [PastorGroupMember] {
        if searchText.isEmpty {
            return availableLeaders
        }
        return availableLeaders.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(YGColors.ink.opacity(0.4))
                    
                    TextField("Search leaders...", text: $searchText)
                        .font(.system(size: 15))
                }
                .padding(12)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                // Leaders list
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(filteredLeaders.enumerated()), id: \.element.id) { index, leader in
                            Button {
                                selectedLeaderId = leader.id
                            } label: {
                                HStack(spacing: 12) {
                                    Text(leader.avatar)
                                        .font(.system(size: 36))
                                        .frame(width: 44, height: 44)
                                        .background(Color(hex: "FFD60A").opacity(0.2))
                                        .clipShape(Circle())
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(leader.name)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(YGColors.ink)
                                        
                                        HStack(spacing: 6) {
                                            Image(systemName: "star.fill")
                                                .font(.system(size: 10))
                                            Text("Leader")
                                                .font(.system(size: 13))
                                        }
                                        .foregroundStyle(Color(hex: "FFD60A"))
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: selectedLeaderId == leader.id ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                        .foregroundStyle(selectedLeaderId == leader.id ? Color(hex: "6B2BFF") : YGColors.ink.opacity(0.2))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            
                            if index < filteredLeaders.count - 1 {
                                Divider()
                                    .padding(.leading, 68)
                            }
                        }
                    }
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.black.opacity(0.04), lineWidth: 0.5)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
            .background(YGColors.paper)
            .navigationTitle("Assign Leader")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(YGColors.ink)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Assign") {
                        assignLeader()
                        dismiss()
                    }
                    .foregroundStyle(selectedLeaderId == nil ? YGColors.ink.opacity(0.3) : Color(hex: "6B2BFF"))
                    .disabled(selectedLeaderId == nil)
                }
            }
        }
        .onAppear {
            selectedLeaderId = group.leaderMemberId
        }
    }
    
    func assignLeader() {
        guard let leaderId = selectedLeaderId,
              let leader = allMembers.first(where: { $0.id == leaderId }),
              let groupIndex = smallGroups.firstIndex(where: { $0.id == group.id }) else {
            return
        }
        
        smallGroups[groupIndex].leader = leader.name
        smallGroups[groupIndex].leaderMemberId = leaderId
    }
}

// MARK: - Create Small Group View
struct CreateSmallGroupView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var allMembers: [PastorGroupMember]
    @Binding var smallGroups: [SmallGroup]
    
    @State private var groupName = ""
    @State private var meetingDay = "Tuesdays"
    @State private var selectedLeaderId: String?
    @State private var selectedMemberIds: Set<String> = []
    @State private var showSelectLeader = false
    @State private var showSelectMembers = false
    
    let days = ["Mondays", "Tuesdays", "Wednesdays", "Thursdays", "Fridays", "Saturdays", "Sundays"]
    
    var selectedLeader: PastorGroupMember? {
        allMembers.first(where: { $0.id == selectedLeaderId })
    }
    
    var canCreate: Bool {
        !groupName.isEmpty && selectedLeaderId != nil && !selectedMemberIds.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Group name")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(YGColors.ink.opacity(0.6))
                        
                        TextField("e.g., Tuesday Night SG", text: $groupName)
                            .padding(14)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Meeting day")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(YGColors.ink.opacity(0.6))
                        
                        Picker("Day", selection: $meetingDay) {
                            ForEach(days, id: \.self) { day in
                                Text(day).tag(day)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(14)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Leader")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(YGColors.ink.opacity(0.6))
                        
                        Button {
                            showSelectLeader = true
                        } label: {
                            HStack {
                                if let leader = selectedLeader {
                                    Text(leader.avatar)
                                        .font(.system(size: 28))
                                    
                                    Text(leader.name)
                                        .font(.system(size: 15))
                                        .foregroundStyle(YGColors.ink)
                                } else {
                                    Text("Select a leader")
                                        .font(.system(size: 15))
                                        .foregroundStyle(YGColors.ink.opacity(0.4))
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(YGColors.ink.opacity(0.3))
                            }
                            .padding(14)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Members")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(YGColors.ink.opacity(0.6))
                        
                        Button {
                            showSelectMembers = true
                        } label: {
                            HStack {
                                Text(selectedMemberIds.isEmpty ? "Select members" : "\(selectedMemberIds.count) members selected")
                                    .font(.system(size: 15))
                                    .foregroundStyle(selectedMemberIds.isEmpty ? YGColors.ink.opacity(0.4) : YGColors.ink)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(YGColors.ink.opacity(0.3))
                            }
                            .padding(14)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                            }
                        }
                    }
                    
                    Button {
                        createGroup()
                        dismiss()
                    } label: {
                        Text("Create Group")
                            .font(.lilitaOne(size: 16))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(canCreate ? Color(hex: "6B2BFF") : YGColors.ink.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(!canCreate)
                    .padding(.top, 20)
                }
                .padding(20)
            }
            .background(YGColors.paper)
            .navigationTitle("New Small Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(YGColors.ink)
                }
            }
        }
        .sheet(isPresented: $showSelectLeader) {
            SelectLeaderForNewGroupView(
                allMembers: allMembers,
                selectedLeaderId: $selectedLeaderId
            )
        }
        .sheet(isPresented: $showSelectMembers) {
            SelectMembersForNewGroupView(
                allMembers: allMembers,
                selectedMemberIds: $selectedMemberIds
            )
        }
    }
    
    func createGroup() {
        guard let leaderId = selectedLeaderId,
              let leader = allMembers.first(where: { $0.id == leaderId }) else {
            return
        }
        
        let newGroup = SmallGroup(
            id: UUID().uuidString,
            name: groupName,
            leader: leader.name,
            leaderMemberId: leaderId,
            memberIds: Array(selectedMemberIds),
            day: meetingDay
        )
        
        smallGroups.append(newGroup)
        
        // Update member assignments
        for memberId in selectedMemberIds {
            if let memberIndex = allMembers.firstIndex(where: { $0.id == memberId }) {
                allMembers[memberIndex].smallGroupId = newGroup.id
            }
        }
    }
}

// MARK: - Select Leader For New Group
struct SelectLeaderForNewGroupView: View {
    @Environment(\.dismiss) var dismiss
    let allMembers: [PastorGroupMember]
    @Binding var selectedLeaderId: String?
    @State private var searchText = ""
    
    var availableLeaders: [PastorGroupMember] {
        allMembers.filter { $0.isLeader }
    }
    
    var filteredLeaders: [PastorGroupMember] {
        if searchText.isEmpty {
            return availableLeaders
        }
        return availableLeaders.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(YGColors.ink.opacity(0.4))
                    
                    TextField("Search leaders...", text: $searchText)
                        .font(.system(size: 15))
                }
                .padding(12)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(filteredLeaders.enumerated()), id: \.element.id) { index, leader in
                            Button {
                                selectedLeaderId = leader.id
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Text(leader.avatar)
                                        .font(.system(size: 36))
                                        .frame(width: 44, height: 44)
                                        .background(Color(hex: "FFD60A").opacity(0.2))
                                        .clipShape(Circle())
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(leader.name)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(YGColors.ink)
                                        
                                        HStack(spacing: 6) {
                                            Image(systemName: "star.fill")
                                                .font(.system(size: 10))
                                            Text("Leader")
                                                .font(.system(size: 13))
                                        }
                                        .foregroundStyle(Color(hex: "FFD60A"))
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedLeaderId == leader.id {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(Color(hex: "6B2BFF"))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            
                            if index < filteredLeaders.count - 1 {
                                Divider()
                                    .padding(.leading, 68)
                            }
                        }
                    }
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.black.opacity(0.04), lineWidth: 0.5)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .background(YGColors.paper)
            .navigationTitle("Select Leader")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(YGColors.ink)
                }
            }
        }
    }
}

// MARK: - Select Members For New Group
struct SelectMembersForNewGroupView: View {
    @Environment(\.dismiss) var dismiss
    let allMembers: [PastorGroupMember]
    @Binding var selectedMemberIds: Set<String>
    @State private var searchText = ""
    @State private var showOnlyWithoutGroup = false
    
    var availableMembers: [PastorGroupMember] {
        allMembers.filter { !$0.isLeader }
    }
    
    var filteredMembers: [PastorGroupMember] {
        var members = availableMembers
        
        if showOnlyWithoutGroup {
            members = members.filter { !$0.hasSmallGroup }
        }
        
        if !searchText.isEmpty {
            members = members.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        return members
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(YGColors.ink.opacity(0.4))
                    
                    TextField("Search members...", text: $searchText)
                        .font(.system(size: 15))
                }
                .padding(12)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Button {
                    showOnlyWithoutGroup.toggle()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: showOnlyWithoutGroup ? "checkmark.square.fill" : "square")
                            .font(.system(size: 16))
                            .foregroundStyle(showOnlyWithoutGroup ? Color(hex: "6B2BFF") : YGColors.ink.opacity(0.3))
                        
                        Text("Show only members without a small group")
                            .font(.system(size: 14))
                            .foregroundStyle(YGColors.ink)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(filteredMembers.enumerated()), id: \.element.id) { index, member in
                            SelectableMemberRow(
                                member: member,
                                isSelected: selectedMemberIds.contains(member.id),
                                onToggle: {
                                    if selectedMemberIds.contains(member.id) {
                                        selectedMemberIds.remove(member.id)
                                    } else {
                                        selectedMemberIds.insert(member.id)
                                    }
                                }
                            )
                            
                            if index < filteredMembers.count - 1 {
                                Divider()
                                    .padding(.leading, 68)
                            }
                        }
                    }
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.black.opacity(0.04), lineWidth: 0.5)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
            .background(YGColors.paper)
            .navigationTitle("Select Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(YGColors.ink)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done (\(selectedMemberIds.count))") {
                        dismiss()
                    }
                    .foregroundStyle(Color(hex: "6B2BFF"))
                }
            }
        }
    }
}

// MARK: - Pastor Plan Create Flow
//
// Hosts the new 8-screen "Publish a Bible plan" flow. Resolves the
// pastor's youth-group id from EventsService.myMemberships, then
// presents PastorPlanSetupView → PlanDayBuilderView via NavigationStack.
//
// Replaces the old `PublishPlanView` placeholder.

struct PastorPlanCreateFlow: View {
    /// Caller-supplied dismiss handler. Used when the flow is presented
    /// as a sibling overlay rather than a modal (no @Environment(\.dismiss)
    /// is reachable in that case).
    let onDismiss: () -> Void

    @State private var eventsService = EventsService.shared

    @State private var groupId: UUID?
    @State private var loadError: String?

    /// First non-default youth group the user pastors. The new plan is
    /// scoped to that group.
    private func resolvePastorGroupId() -> UUID? {
        eventsService.myMemberships.first(where: { $0.role == "pastor" })?.groupId
    }

    var body: some View {
        // Paint an opaque backdrop FIRST, then mount the NavigationStack on
        // top of it. The slide-from-trailing transition flickers black when
        // the moving view isn't already opaque at frame zero — the ZStack
        // here guarantees there's a solid `paper` fill behind everything,
        // including the system safe-area edges, the whole way through the
        // animation.
        ZStack {
            YGColors.paper
                .ignoresSafeArea()

            NavigationStack {
                Group {
                    if let groupId {
                        PastorPlansListView(groupId: groupId, onClose: onDismiss)
                    } else if let loadError {
                        VStack(spacing: 12) {
                            Text("Couldn't open plan builder")
                                .font(.system(size: 17, weight: .heavy, design: .rounded))
                                .foregroundStyle(YGColors.ink)
                            Text(loadError)
                                .font(.system(size: 13))
                                .foregroundStyle(YGColors.ink.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            Button("Close") { onDismiss() }
                                .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(YGColors.paper)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(YGColors.paper)
                    }
                }
            }
        }
        .task {
            if eventsService.myMemberships.isEmpty {
                try? await eventsService.loadMyMemberships()
            }
            if let id = resolvePastorGroupId() {
                groupId = id
            } else {
                loadError = "You don't pastor a youth group yet. Set one up first."
            }
        }
    }
}

#Preview {
    PastorGroupManagementView(onDismiss: {})
}
