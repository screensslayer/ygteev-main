//
//  ForYouFeedView.swift
//  YGTeeV
//
//  Vertical-paging "For You" feed. Pulls posts from FeedService and
//  renders one full-screen card per post, swapping between
//  FeedVideoCard and FeedSlideshowCard based on `post.postType`. Tracks
//  which page is active so only that card's player runs / autoplays.
//

import SwiftUI

struct ForYouFeedView: View {
    @State private var service = FeedService.shared
    @State private var scrollPosition: UUID?

    /// Group filter selected from the home top-bar. `nil` → "all my groups
    /// + YGTeeV official"; specific id → group-scoped feed (or, when the
    /// id is the default YGTeeV group, ygteev_official-only).
    let selectedGroupId: UUID?

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(service.posts) { post in
                        cardView(for: post,
                                 isActive: scrollPosition == post.postId)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .id(post.postId)
                            .onAppear {
                                // Last-card prefetch.
                                if post.postId == service.posts.last?.postId {
                                    Task { await service.loadMore() }
                                }
                            }
                    }

                    if service.isLoadingMore {
                        ProgressView()
                            .tint(.white)
                            .frame(width: geo.size.width, height: 80)
                    } else if service.posts.isEmpty && !service.isLoadingInitial {
                        emptyState
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrollPosition)
            .refreshable {
                await service.loadInitial(groupId: selectedGroupId)
                scrollPosition = service.posts.first?.postId
            }
            .overlay {
                if service.isLoadingInitial {
                    ProgressView().tint(.white)
                }
            }
            .background(Color.black)
        }
        .ignoresSafeArea()
        // `.task(id:)` re-fires whenever the selector flips, so the feed
        // stays in sync with the top bar without any manual onChange.
        .task(id: selectedGroupId) {
            // Skip the reload if the service already holds this filter
            // and has posts — avoids a flash when the home tab re-mounts.
            if service.posts.isEmpty || service.currentGroupId != selectedGroupId {
                await service.loadInitial(groupId: selectedGroupId)
                scrollPosition = service.posts.first?.postId
            }
        }
    }

    // MARK: - Card switching

    @ViewBuilder
    private func cardView(for post: FeedPost, isActive: Bool) -> some View {
        switch post.postType {
        case .video:
            FeedVideoCard(
                post: post,
                isActive: isActive,
                onTapHeart: { Task { await service.toggleLike(post.postId) } }
            )
        case .slideshow:
            FeedSlideshowCard(
                post: post,
                isActive: isActive,
                onTapHeart: { Task { await service.toggleLike(post.postId) } }
            )
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .heavy))
                .foregroundStyle(.white.opacity(0.7))
            Text("Nothing here yet")
                .font(.lilitaOne(size: 22))
                .tracking(-0.4)
                .foregroundStyle(.white)
            // Wording depends on whether the user filtered to a specific
            // group — a single-group empty state is almost always "your
            // pastor hasn't posted yet" rather than a generic global lull.
            Text(selectedGroupId == nil
                 ? "Pastors and YGTeeV are still cooking. Check back soon."
                 : "Your pastor hasn't posted anything in this group yet.")
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            if let error = service.lastError {
                Text(error)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: "FF3DA5"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                    .padding(.top, 4)
                Button {
                    Task { await service.loadInitial() }
                } label: {
                    Text("Try again")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(.white.opacity(0.15))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
        }
        .padding(.bottom, 80)
    }
}
