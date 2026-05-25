//
//  FeedService.swift
//  YGTeeV
//
//  Backs the "For You" feed. Loads pages from the `for_you_feed` RPC,
//  records views/watches/likes, and provides pastor-side CRUD helpers
//  (Mux video upload + slideshow creation). Engagement RPCs are
//  per-post-id deduplicated within a session so re-scrolling past a
//  card or re-mounting the player doesn't re-hit the server.
//

import Foundation
import SwiftUI
import Supabase

@MainActor
@Observable
final class FeedService {
    static let shared = FeedService()
    private let client = SupabaseManager.shared.client

    /// The currently-loaded feed, newest first.
    var posts: [FeedPost] = []
    /// True while the initial page is hydrating.
    var isLoadingInitial = false
    /// True while a "load next page" call is in flight.
    var isLoadingMore = false
    /// True once the server returned an empty page (no more rows).
    var reachedEnd = false
    /// Last-page error message, surfaced inline in the feed UI.
    var lastError: String?
    /// The group filter the loaded feed was scoped to. `nil` = "all groups
    /// I'm in + YGTeeV official posts"; matches the home top-bar selector.
    var currentGroupId: UUID?

    /// In-session set of post IDs we've already fired a `record_view` for.
    private var viewedThisSession: Set<UUID> = []
    /// In-session set of post IDs we've already fired a `watch_complete` for.
    private var watchedThisSession: Set<UUID> = []

    private let pageSize = 20

    // MARK: - Feed loading

    /// Hydrate the first page for a given group filter. `groupId == nil`
    /// matches the legacy "all my groups + YGTeeV official" behavior; a
    /// specific id scopes the feed to either that one group or — when the
    /// id is the default YGTeeV group — `ygteev_official`-only.
    ///
    /// Replaces `posts` entirely; safe to call from `.refreshable {}`,
    /// cold-start, or whenever the top selector changes. Note: the
    /// per-session view/watch dedup sets are NOT cleared here — they
    /// span the app lifetime so pulling to refresh doesn't re-fire view
    /// records for cards the user already saw this session.
    func loadInitial(groupId: UUID? = nil) async {
        // Flip the loading flag BEFORE clearing posts, otherwise SwiftUI
        // sees the in-between `posts.isEmpty && !isLoadingInitial` state
        // and flashes the empty card for a frame on every group switch.
        isLoadingInitial = true
        lastError = nil
        defer { isLoadingInitial = false }

        // Reset cursor + filter atomically so a stale page doesn't bleed
        // into the new selection while loading.
        self.currentGroupId = groupId
        self.posts = []
        self.reachedEnd = false

        do {
            let rows = try await fetchPage()
            self.posts = rows
            self.reachedEnd = rows.count < pageSize
        } catch is CancellationError {
            // SwiftUI cancels the previous `.task(id:)` body whenever
            // the user flips groups — swallow so we don't surface
            // "cancelled" as a user-facing error.
        } catch {
            // Some SDK / URLSession paths surface cancellation as a
            // non-typed error whose message contains "cancel". Don't
            // surface those either.
            if !error.localizedDescription.localizedCaseInsensitiveContains("cancel") {
                self.lastError = error.localizedDescription
            }
        }
    }

    /// Fetch the next page using `posts.count` as the integer offset.
    /// No-op when a load is already in-flight or we've already hit the
    /// end. Uses the group filter that the initial page was loaded with.
    func loadMore() async {
        guard !isLoadingMore, !reachedEnd, !posts.isEmpty else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let rows = try await fetchPage()
            // De-dup: with the unseen → seen bucketing, a record_view fired
            // between pages can shuffle a row's bucket and we could see it
            // again on the next offset window. A Set lookup is cheap.
            let known = Set(posts.map(\.postId))
            let fresh = rows.filter { !known.contains($0.postId) }
            self.posts.append(contentsOf: fresh)
            self.reachedEnd = rows.count < pageSize
        } catch is CancellationError {
            // Same swallow as loadInitial — page flips cancel us.
        } catch {
            if !error.localizedDescription.localizedCaseInsensitiveContains("cancel") {
                self.lastError = error.localizedDescription
            }
        }
    }

    /// One page of `for_you_feed`. Offset is implicit (`posts.count`) so
    /// `loadInitial` (which empties `posts` first) and `loadMore` share
    /// the same code path. Always passes `_group_id` explicitly (as null
    /// when unfiltered) — Supabase's named-RPC params treat missing-vs-
    /// null differently, and the server's overload routing depends on
    /// null being present.
    private func fetchPage() async throws -> [FeedPost] {
        struct Params: Encodable {
            let _limit: Int
            let _offset: Int
            let _group_id: String?
        }
        let params = Params(
            _limit: pageSize,
            _offset: posts.count,
            _group_id: currentGroupId?.uuidString.lowercased()
        )
        return try await client
            .rpc("for_you_feed", params: params)
            .execute().value
    }

    // MARK: - Engagement

    /// Fire-and-forget. Idempotent per session — re-scrolling past a card
    /// is silent after the first hit.
    func recordView(_ postId: UUID) {
        guard !viewedThisSession.contains(postId) else { return }
        viewedThisSession.insert(postId)
        Task { [client] in
            struct Params: Encodable { let _post_id: String }
            _ = try? await client
                .rpc("feed_post_record_view",
                     params: Params(_post_id: postId.uuidString.lowercased()))
                .execute()
        }
        // Reflect locally so the UI doesn't re-trigger or double-count.
        if let i = posts.firstIndex(where: { $0.postId == postId }), !posts[i].hasViewed {
            posts[i].hasViewed = true
            posts[i].viewsCount += 1
        }
    }

    /// Fired when the player crosses ≥80% of the duration. Idempotent per
    /// session (loops shouldn't keep firing it).
    func recordWatchComplete(_ postId: UUID) {
        guard !watchedThisSession.contains(postId) else { return }
        watchedThisSession.insert(postId)
        Task { [client] in
            struct Params: Encodable { let _post_id: String }
            _ = try? await client
                .rpc("feed_post_record_watch_complete",
                     params: Params(_post_id: postId.uuidString.lowercased()))
                .execute()
        }
    }

    /// Toggle the heart. Optimistically flips local state, rolls back on
    /// failure. Returns the new server-truth liked state.
    @discardableResult
    func toggleLike(_ postId: UUID) async -> Bool {
        guard let i = posts.firstIndex(where: { $0.postId == postId }) else { return false }
        let wasLiked = posts[i].hasLiked
        // Optimistic flip.
        posts[i].hasLiked = !wasLiked
        posts[i].likesCount += wasLiked ? -1 : 1

        struct Params: Encodable { let _post_id: String }
        do {
            let newState: Bool = try await client
                .rpc("feed_post_toggle_like",
                     params: Params(_post_id: postId.uuidString.lowercased()))
                .execute().value
            // Reconcile with server truth in case the optimistic flip
            // disagreed (e.g. simultaneous tap from another device).
            if posts[i].hasLiked != newState {
                posts[i].likesCount += newState ? 1 : -1
                posts[i].hasLiked = newState
            }
            return newState
        } catch {
            // Roll back the optimistic flip.
            posts[i].hasLiked = wasLiked
            posts[i].likesCount += wasLiked ? 1 : -1
            return wasLiked
        }
    }

    // MARK: - Pastor authoring — slideshow

    /// Step 1 of the slideshow flow: create the draft post and return its
    /// id so the caller can stage photo uploads against it.
    func createSlideshowDraft(groupId: UUID,
                              title: String?,
                              caption: String?) async throws -> UUID {
        struct Params: Encodable {
            let _group_id: String
            let _title: String?
            let _caption: String?
        }
        let id: UUID = try await client
            .rpc("pastor_create_feed_slideshow_post",
                 params: Params(
                    _group_id: groupId.uuidString.lowercased(),
                    _title:    title?.isEmpty == true ? nil : title,
                    _caption:  caption?.isEmpty == true ? nil : caption
                 ))
            .execute().value
        return id
    }

    /// Upload one image to the `feed-photos` bucket at `<postId>/<index>.jpg`.
    func uploadSlideshowImage(postId: UUID, index: Int, data: Data) async throws {
        let path = "\(postId.uuidString.lowercased())/\(index).jpg"
        try await client.storage
            .from("feed-photos")
            .upload(path, data: data, options: .init(contentType: "image/jpeg"))
    }

    /// Bulk-attach photo rows in display order. Storage uploads must
    /// already be complete — server validates that each path exists.
    func attachSlideshowPhotos(postId: UUID, count: Int) async throws {
        let photos: [AnyJSON] = (0..<count).map { i in
            .object([
                "storage_path":  .string("\(postId.uuidString.lowercased())/\(i).jpg"),
                "display_order": .integer(i),
                "alt_text":      .null,
            ])
        }
        let params: [String: AnyJSON] = [
            "_post_id": .string(postId.uuidString.lowercased()),
            "_photos":  .array(photos),
        ]
        _ = try await client
            .rpc("pastor_attach_slideshow_photos", params: params)
            .execute()
    }

    // MARK: - Pastor authoring — video (Mux)

    /// Response from the `pastor-create-mux-upload` Edge Function.
    struct MuxUploadTicket: Decodable {
        let uploadURL: String
        let muxUploadId: String
        let videoId: UUID
        let postId: UUID

        enum CodingKeys: String, CodingKey {
            case uploadURL   = "upload_url"
            case muxUploadId = "mux_upload_id"
            case videoId     = "video_id"
            case postId      = "post_id"
        }
    }

    /// Mints a Mux direct-upload URL and a draft `feed_posts` row.
    func createMuxUploadTicket(groupId: UUID,
                               title: String?,
                               caption: String?) async throws -> MuxUploadTicket {
        struct Body: Encodable {
            let group_id: String
            let title: String?
            let caption: String?
        }
        let body = Body(
            group_id: groupId.uuidString.lowercased(),
            title:    title?.isEmpty == true ? nil : title,
            caption:  caption?.isEmpty == true ? nil : caption
        )
        return try await client.functions.invoke(
            "pastor-create-mux-upload",
            options: FunctionInvokeOptions(body: body)
        )
    }

    /// Single row pulled from `videos` while polling for transcode status.
    struct VideoStatusRow: Decodable {
        let id: UUID
        let status: String           // "uploading" | "processing" | "ready" | "errored"
        let muxPlaybackId: String?
        let durationSec: Double?
        let aspectRatio: String?

        enum CodingKeys: String, CodingKey {
            case id, status
            case muxPlaybackId = "mux_playback_id"
            case durationSec   = "duration_sec"
            case aspectRatio   = "aspect_ratio"
        }
    }

    /// One-shot poll of the `videos` row for the given id. Caller drives
    /// the loop + backoff so the UI can show progress / cancel.
    func fetchVideoStatus(videoId: UUID) async throws -> VideoStatusRow {
        try await client
            .from("videos")
            .select("id, status, mux_playback_id, duration_sec, aspect_ratio")
            .eq("id", value: videoId.uuidString.lowercased())
            .single()
            .execute().value
    }

    // MARK: - Publish / archive / delete (works for both video & slideshow)

    func publishPost(postId: UUID) async throws {
        struct Params: Encodable { let _post_id: String }
        _ = try await client
            .rpc("pastor_publish_feed_post",
                 params: Params(_post_id: postId.uuidString.lowercased()))
            .execute()
        // Force a refresh on next viewer entry: simplest is to drop the
        // cached feed so the pastor sees their own post when they pop
        // back to the home tab. Preserve the current group filter.
        await loadInitial(groupId: currentGroupId)
    }

    func archivePost(postId: UUID) async throws {
        struct Params: Encodable { let _post_id: String }
        _ = try await client
            .rpc("pastor_archive_feed_post",
                 params: Params(_post_id: postId.uuidString.lowercased()))
            .execute()
        posts.removeAll { $0.postId == postId }
    }

    func deletePost(postId: UUID) async throws {
        struct Params: Encodable { let _post_id: String }
        _ = try await client
            .rpc("pastor_delete_feed_post",
                 params: Params(_post_id: postId.uuidString.lowercased()))
            .execute()
        posts.removeAll { $0.postId == postId }
    }
}
