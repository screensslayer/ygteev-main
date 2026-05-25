//
//  FeedSourceBadge.swift
//  YGTeeV
//
//  The "where did this come from?" chip in the top-right of every For You
//  card. Attribution differs per source kind — pastor uploads get a
//  pastor + group line, IG scrapes get the handle with a camera glyph,
//  YGTeeV-curated gets the brand mark, and cross-group reposts get a
//  small star next to the originating group's name.
//

import SwiftUI

struct FeedSourceBadge: View {
    let post: FeedPost

    var body: some View {
        HStack(spacing: 6) {
            iconLeading
            VStack(alignment: .leading, spacing: 0) {
                Text(primary)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                if let secondary {
                    Text(secondary)
                        .font(.system(size: 10.5, weight: .semibold))
                        .opacity(0.85)
                        .lineLimit(1)
                }
            }
            if showStar {
                Image(systemName: "star.fill")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(Color(hex: "FFD60A"))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.black.opacity(0.45))
        .clipShape(Capsule())
        .overlay {
            Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
        }
    }

    // MARK: - Per-source-kind rendering

    @ViewBuilder
    private var iconLeading: some View {
        switch post.sourceKind {
        case .pastorUpload:
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 11, weight: .heavy))
        case .ygteevCurated:
            Image(systemName: "leaf.fill")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Color(hex: "B4FF3C"))
        case .instagramScrape:
            Image(systemName: "camera.fill")
                .font(.system(size: 11, weight: .heavy))
        case .crossGroupApproved:
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 11, weight: .heavy))
        case .unknown:
            Image(systemName: "questionmark.circle")
                .font(.system(size: 11, weight: .heavy))
        }
    }

    private var primary: String {
        switch post.sourceKind {
        case .pastorUpload:
            return post.authorName ?? "Pastor"
        case .ygteevCurated:
            return "YGTeeV"
        case .instagramScrape:
            return post.sourceHandle.map { "@\($0)" } ?? "Instagram"
        case .crossGroupApproved:
            return post.groupName ?? "Curated"
        case .unknown:
            return post.groupName ?? "Unknown"
        }
    }

    private var secondary: String? {
        switch post.sourceKind {
        case .pastorUpload:    return post.groupName
        case .ygteevCurated:   return nil
        case .instagramScrape: return nil
        case .crossGroupApproved: return "Curated"
        case .unknown:         return nil
        }
    }

    private var showStar: Bool {
        post.sourceKind == .crossGroupApproved
    }
}
