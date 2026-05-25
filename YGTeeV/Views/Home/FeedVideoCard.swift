//
//  FeedVideoCard.swift
//  YGTeeV
//
//  Full-screen feed card that hosts MuxVideoPlayer + the overlay UI
//  (source badge, caption, heart/likes). Drives the engagement RPCs:
//    • record_view fires once the card becomes active
//    • record_watch_complete fires after 80% of duration_sec has elapsed
//      while the card stays active
//    • toggle_like fires on heart-tap or double-tap
//

import SwiftUI

struct FeedVideoCard: View {
    let post: FeedPost
    let isActive: Bool
    let onTapHeart: () -> Void

    /// Timer task that fires `recordWatchComplete` after 80% of duration.
    /// Cancelled on disappear / when the card scrolls away.
    @State private var watchTask: Task<Void, Never>?
    @State private var didFireWatchComplete = false
    @State private var heartPulse = false

    private var feed: FeedService { FeedService.shared }

    var body: some View {
        ZStack {
            // Pastor/curated uploads stream from Mux. Instagram-scraped
            // posts come with a direct `source_url` (the IG media URL),
            // so we hand that straight to AVPlayer instead. Both routes
            // use the same looping player; only the URL differs.
            if let pbid = post.muxPlaybackId, !pbid.isEmpty {
                MuxVideoPlayer(playbackId: pbid, isActive: isActive)
            } else if let src = post.sourceURL,
                      let url = URL(string: src) {
                MuxVideoPlayer(url: url, isActive: isActive)
            } else {
                Rectangle().fill(Color.black)
            }

            // Subtle scrim so caption + badge stay legible against any frame.
            LinearGradient(
                colors: [.black.opacity(0.0), .black.opacity(0.55)],
                startPoint: .center,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            // Source badge intentionally suppressed for every post
            // type — author + group attribution lives in the caption
            // area, the top-right corner stays clean.

            // Caption + heart — bottom row.
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
        // Double-tap anywhere to like (TikTok-style).
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { fireHeart() }
        .onChange(of: isActive) { _, nowActive in
            if nowActive {
                onActivate()
            } else {
                stopWatchTimer()
            }
        }
        .onAppear {
            if isActive { onActivate() }
        }
        .onDisappear {
            stopWatchTimer()
        }
    }

    // MARK: - Sub-views

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

    // MARK: - Engagement plumbing

    private func onActivate() {
        feed.recordView(post.postId)
        startWatchTimer()
    }

    /// Mux player loops, so we can't use playback completion as a signal.
    /// Instead: kick a Task that sleeps for 80% of `durationSec` while
    /// the card is active; if the user swipes away first, the task is
    /// cancelled and watch-complete is skipped. Per-card-session dedup
    /// prevents loops from re-firing.
    private func startWatchTimer() {
        guard !didFireWatchComplete else { return }
        watchTask?.cancel()
        // Sensible default if the server hasn't filled duration yet.
        let duration = post.durationSec ?? 15
        let threshold = max(2, duration * 0.8)
        let nanos = UInt64(threshold * 1_000_000_000)
        watchTask = Task {
            try? await Task.sleep(nanoseconds: nanos)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard !didFireWatchComplete else { return }
                didFireWatchComplete = true
                feed.recordWatchComplete(post.postId)
            }
        }
    }

    private func stopWatchTimer() {
        watchTask?.cancel()
        watchTask = nil
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
        case 0..<1_000:       return "\(n)"
        case 1_000..<10_000:  return String(format: "%.1fK", Double(n) / 1_000)
        case 10_000..<1_000_000: return "\(n / 1_000)K"
        default:              return String(format: "%.1fM", Double(n) / 1_000_000)
        }
    }
}
