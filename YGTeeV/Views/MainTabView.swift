//
//  MainTabView.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/6/26.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: AppTab = .home
    @Environment(AppState.self) var appState
    
    var body: some View {
        ZStack {
            // Tab content
            Group {
                switch selectedTab {
                case .home:
                    HomeFeedView()
                case .plans:
                    PlansHomeView()
                case .bible:
                    BibleHomeView()
                case .messages:
                    MessagesListView()
                case .profile:
                    ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Tab bar overlay
            VStack {
                Spacer()
                YGTabBar(selectedTab: $selectedTab)
            }
            .ignoresSafeArea(.keyboard)
        }
    }
}

#Preview {
    MainTabView()
        .environment(AppState())
}
