//
//  FeedSlideshowCard.swift
//  YGTeeV
//
//  Full-screen feed card for slideshow posts. Auto-advances between
//  photos using `slideshowSecondsPerPhoto` from the server (default 4s),
//  pauses when the card isn't the active page, and exposes the same
//  caption + heart UI as the video card.
//

import SwiftUI

struct FeedSlideshowCard: View {
    let post: FeedPost
    let isActive: Bool
    let onTapHeart: () -> Void

    @State private var pageIndex = 0
    @State private var advanceTask: Task<Void, Never>?
    @State private var heartPulse = false
    @State private var didFireWatchComplete = false

    private var feed: FeedService { FeedService.shared }

    /// Server default fallback — 4s feels right for a single photo.
    private var perPhotoSeconds: Double {
        post.slideshowSecondsPerPhoto ?? 4
    }

    var body: some View {
        ZStack {
            Color.black
            slideshowPager
                .ignoresSafeArea()

            // Scrim for text legibility.
            LinearGradient(
                colors: [.black.opacity(0.0), .black.opacity(0.55)],
                startPoint: .center,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            // Top-row overlay: just the page dots. The source badge
            // is intentionally suppressed for every post type — author
            // + group attribution lives in the caption area.
            VStack {
                HStack {
                    pageDots.padding(.leading, 18).padding(.top, 110)
                    Spacer()
                }
                Spacer()
            }
            .allowsHitTesting(false)

            // Caption + heart.
            VStack {
                Spacer()
                HStack(alignment: .bottom, spacing: 14) {
                    captionStack
                    Spacer(minLength: 8)
                    heartButton
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 150)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { fireHeart() }
        .onChange(of: isActive) { _, nowActive in
            if nowActive { onActivate() } else { stopAdvance() }
        }
        .onAppear {
            if isActive { onActivate() }
        }
        .onDisappear {
            stopAdvance()
        }
    }

    // MARK: - Slideshow renderer

    private var slideshowPager: some View {
        Group {
            if post.photos.isEmpty {
                // Server gave us a slideshow row but no photos — show a
                // placeholder rather than a blank black screen.
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("No photos")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
            } else {
                TabView(selection: $pageIndex) {
                    ForEach(Array(post.photos.enumerated()), id: \.element) { i, photo in
                        slidePhoto(url: photo.publicURL)
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
    }

    private func slidePhoto(url: String) -> some View {
        AsyncImage(url: URL(string: url)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure:
                Color.black.overlay {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white.opacity(0.4))
                }
            case .empty:
                Color.black.overlay { ProgressView().tint(.white) }
            @unknown default:
                Color.black
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    // MARK: - Overlays

    private var pageDots: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(post.photos.count, 1), id: \.self) { i in
                Capsule()
                    .fill(i == pageIndex ? Color.white : Color.white.opacity(0.4))
                    .frame(width: i == pageIndex ? 16 : 6, height: 4)
            }
        }
    }

    private var captionStack: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = post.title, !title.isEmpty {
                Text(title)
                    .font(.lilitaOne(size: 18))
                    .tracking(-0.3)
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
            if let caption = post.caption, !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heartButton: some View {
        Button(action: fireHeart) {
            VStack(spacing: 2) {
                Image(systemName: post.hasLiked ? "heart.fill" : "heart")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(post.hasLiked ? Color(hex: "FF3DA5") : .white)
                    .scaleEffect(heartPulse ? 1.25 : 1.0)
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
                Text(formatCount(post.likesCount))
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 2)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Activation / auto-advance

    private func onActivate() {
        feed.recordView(post.postId)
        // Treat one full pass through the slideshow as a "watch complete"
        // — fires after photos.count * perPhotoSeconds elapses.
        startAdvanceLoop()
    }

    private func startAdvanceLoop() {
        advanceTask?.cancel()
        let count = post.photos.count
        guard count > 0 else { return }
        let stepNanos = UInt64(perPhotoSeconds * 1_000_000_000)
        advanceTask = Task {
            var elapsed: Double = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: stepNanos)
                if Task.isCancelled { return }
                elapsed += perPhotoSeconds
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        pageIndex = (pageIndex + 1) % count
                    }
                }
                // Fire watch-complete once a full pass through has elapsed.
                if !didFireWatchComplete, elapsed >= Double(count) * perPhotoSeconds {
                    await MainActor.run {
                        didFireWatchComplete = true
                        feed.recordWatchComplete(post.postId)
                    }
                }
            }
        }
    }

    private func stopAdvance() {
        advanceTask?.cancel()
        advanceTask = nil
    }

    private func fireHeart() {
        onTapHeart()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) {
            heartPulse = true
        }
        Task {
            try? await Task.sleep(nanoseconds: 220_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.18)) { heartPulse = false }
            }
        }
    }

    private func formatCount(_ n: Int) -> String {
        switch n {
        case 0..<1_000:          return "\(n)"
        case 1_000..<10_000:     return String(format: "%.1fK", Double(n) / 1_000)
        case 10_000..<1_000_000: return "\(n / 1_000)K"
        default:                 return String(format: "%.1fM", Double(n) / 1_000_000)
        }
    }
}
