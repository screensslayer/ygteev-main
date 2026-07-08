//
//  FeedPrewarmer.swift
//  YGTeeV
//
//  Runs during the splash window so the user lands on a populated
//  For-You feed instead of an empty page that fetches on appear.
//  Two layers of warming:
//
//    1. FeedService.loadInitial() — primes `service.posts`. The
//       For-You view's `.task` already skips its own fetch when posts
//       exist (ForYouFeedView line 87), so this is a clean win with
//       zero double-fetching.
//
//    2. AVURLAsset.load(.isPlayable, .duration) on the first two
//       video URLs — best-effort. Pulls the HLS m3u8 manifest into
//       URLCache.shared so MuxVideoPlayer's first manifest request
//       hits cache and starts streaming sooner. Does NOT prefetch
//       media segments — that would need an active AVPlayer preroll
//       which we deliberately avoid to keep audio session state
//       clean for whatever flow runs next.
//
//  Safe to call before the auth check: an unauthenticated session
//  causes the RPC to return empty and the prewarm exits cheaply.
//

import AVFoundation
import Foundation

@MainActor
@Observable
final class FeedPrewarmer {
    static let shared = FeedPrewarmer()

    /// Strong references to the assets we kicked off so their network
    /// loads don't get cancelled when the local var goes out of scope.
    private var warmedAssets: [AVURLAsset] = []
    private var didRun = false

    private init() {}

    func prewarmFirstVideos(count: Int = 2) async {
        guard !didRun else { return }
        didRun = true

        await FeedService.shared.loadInitial()

        let urls = FeedService.shared.posts
            .compactMap(Self.playbackURL(for:))
            .prefix(count)

        let assets = urls.map { AVURLAsset(url: $0) }
        self.warmedAssets = assets

        await withTaskGroup(of: Void.self) { group in
            for asset in assets {
                group.addTask {
                    _ = try? await asset.load(.isPlayable, .duration)
                }
            }
        }
    }

    private static func playbackURL(for post: FeedPost) -> URL? {
        if let pbid = post.muxPlaybackId, !pbid.isEmpty {
            return URL(string: "https://stream.mux.com/\(pbid).m3u8")
        }
        if let src = post.sourceURL, !src.isEmpty {
            return URL(string: src)
        }
        return nil
    }
}
