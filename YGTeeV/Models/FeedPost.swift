//
//  FeedPost.swift
//  YGTeeV
//
//  Models for the "For You" feed: a backend-paginated stream of video or
//  slideshow posts authored by pastors (scoped to a group) or curated by
//  YGTeeV (scope = `ygteev_official`). Hydrated entirely via the
//  `for_you_feed` RPC — see FeedService.
//

import Foundation

/// A single post in the For You feed. Decodes the row returned by the
/// `for_you_feed` Postgres RPC verbatim.
struct FeedPost: Decodable, Identifiable, Hashable {
    enum PostType: String, Decodable { case video, slideshow }
    enum Scope: String, Decodable {
        case ygteevOfficial = "ygteev_official"
        case group
    }
    enum SourceKind: String, Decodable {
        case pastorUpload        = "pastor_upload"
        case ygteevCurated       = "ygteev_curated"
        case instagramScrape     = "instagram_scrape"
        case crossGroupApproved  = "cross_group_approved"
        case unknown
    }

    let postId: UUID
    let postType: PostType
    let scope: Scope
    let groupId: UUID?
    let groupName: String?
    let sourceKind: SourceKind
    let sourceURL: String?
    let sourceHandle: String?
    let title: String?
    let caption: String?

    // video
    let videoId: UUID?
    let muxPlaybackId: String?
    let durationSec: Double?
    let aspectRatio: String?

    // slideshow
    let slideshowSecondsPerPhoto: Double?
    let photos: [FeedPhoto]

    // attribution + engagement
    let authorId: UUID?
    let authorName: String?
    let authorAvatar: String?
    var viewsCount: Int
    var likesCount: Int
    var hasViewed: Bool
    var hasLiked: Bool
    let publishedAt: Date

    var id: UUID { postId }

    enum CodingKeys: String, CodingKey {
        case postId                   = "post_id"
        case postType                 = "post_type"
        case scope
        case groupId                  = "group_id"
        case groupName                = "group_name"
        case sourceKind               = "source_kind"
        case sourceURL                = "source_url"
        case sourceHandle             = "source_handle"
        case title
        case caption
        case videoId                  = "video_id"
        case muxPlaybackId            = "mux_playback_id"
        case durationSec              = "duration_sec"
        case aspectRatio              = "aspect_ratio"
        case slideshowSecondsPerPhoto = "slideshow_seconds_per_photo"
        case photos
        case authorId                 = "author_id"
        case authorName               = "author_name"
        case authorAvatar             = "author_avatar"
        case viewsCount               = "views_count"
        case likesCount               = "likes_count"
        case hasViewed                = "has_viewed"
        case hasLiked                 = "has_liked"
        case publishedAt              = "published_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.postId        = try c.decode(UUID.self, forKey: .postId)
        self.postType      = (try? c.decode(PostType.self, forKey: .postType)) ?? .video
        self.scope         = (try? c.decode(Scope.self,    forKey: .scope))    ?? .ygteevOfficial
        self.groupId       = try? c.decode(UUID.self,   forKey: .groupId)
        self.groupName     = try? c.decode(String.self, forKey: .groupName)
        self.sourceKind    = (try? c.decode(SourceKind.self, forKey: .sourceKind)) ?? .unknown
        self.sourceURL     = try? c.decode(String.self, forKey: .sourceURL)
        self.sourceHandle  = try? c.decode(String.self, forKey: .sourceHandle)
        self.title         = try? c.decode(String.self, forKey: .title)
        self.caption       = try? c.decode(String.self, forKey: .caption)

        self.videoId       = try? c.decode(UUID.self,   forKey: .videoId)
        self.muxPlaybackId = try? c.decode(String.self, forKey: .muxPlaybackId)
        self.durationSec   = try? c.decode(Double.self, forKey: .durationSec)
        self.aspectRatio   = try? c.decode(String.self, forKey: .aspectRatio)

        self.slideshowSecondsPerPhoto = try? c.decode(Double.self, forKey: .slideshowSecondsPerPhoto)
        self.photos        = (try? c.decode([FeedPhoto].self, forKey: .photos)) ?? []

        self.authorId      = try? c.decode(UUID.self,   forKey: .authorId)
        self.authorName    = try? c.decode(String.self, forKey: .authorName)
        self.authorAvatar  = try? c.decode(String.self, forKey: .authorAvatar)
        self.viewsCount    = (try? c.decode(Int.self,  forKey: .viewsCount))  ?? 0
        self.likesCount    = (try? c.decode(Int.self,  forKey: .likesCount))  ?? 0
        self.hasViewed     = (try? c.decode(Bool.self, forKey: .hasViewed))   ?? false
        self.hasLiked      = (try? c.decode(Bool.self, forKey: .hasLiked))    ?? false
        self.publishedAt   = (try? c.decode(Date.self, forKey: .publishedAt)) ?? Date()
    }
}

/// One photo within a slideshow post. `publicURL` is pre-signed by the
/// server so the client can pass it straight into `AsyncImage`.
struct FeedPhoto: Decodable, Hashable {
    let storagePath: String
    let displayOrder: Int
    let altText: String?
    let publicURL: String

    enum CodingKeys: String, CodingKey {
        case storagePath  = "storage_path"
        case displayOrder = "display_order"
        case altText      = "alt_text"
        case publicURL    = "public_url"
    }
}
