//
//  VideoPost.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/6/26.
//

import Foundation

// Video post for the TikTok-style feed
struct VideoPost: Identifiable, Codable {
    let id: String
    let author: String
    let handle: String
    let groupId: String?
    let caption: String
    let music: String
    let verse: String?
    let likes: Int
    let comments: Int
    let saves: Int
    let kind: PostKind
    let playbackId: String
    
    enum PostKind: String, Codable {
        case sermon
        case testimony
        case event
        case worship
        case general
    }
}

extension VideoPost {
    static let samplePosts: [VideoPost] = [
        VideoPost(
            id: "v1",
            author: "Pastor Jordan",
            handle: "@pastorjordan",
            groupId: "grace",
            caption: "\"Be strong and courageous.\" — what does that look like on a Tuesday? 🔥",
            music: "Hillsong UNITED · Whole Heart",
            verse: "Joshua 1:9",
            likes: 2100,
            comments: 184,
            saves: 312,
            kind: .sermon,
            playbackId: "02l7ZulyZ2OGal02wB6fFvrUquGrHVo6bhL6Tz01B5kAW4"
        ),
        VideoPost(
            id: "v2",
            author: "Maya R.",
            handle: "@maya.rose",
            groupId: "ridge",
            caption: "baptism day 🥹💧 still can't believe it",
            music: "original sound · maya.rose",
            verse: nil,
            likes: 847,
            comments: 92,
            saves: 41,
            kind: .testimony,
            playbackId: "PbPx35Cz02HoIEYIRSIWJYVYeNgYJ4S5JwpSSRft4xm8"
        ),
        VideoPost(
            id: "v3",
            author: "The Oaks YTH",
            handle: "@theoaksyth",
            groupId: "oaks",
            caption: "Worship night this Friday. Bring a friend, bring a verse 🎸",
            music: "Maverick City · Promises",
            verse: nil,
            likes: 1400,
            comments: 67,
            saves: 220,
            kind: .event,
            playbackId: "fW7FBveIYjeZZps2H00vnAMeJ49ywUtoXXDNmv148aB4"
        )
    ]
}
