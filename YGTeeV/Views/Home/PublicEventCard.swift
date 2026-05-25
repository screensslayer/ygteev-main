//
//  PublicEventCard.swift
//  YGTeeV
//
//  Horizontal-carousel card for the "Public events nearby" row under
//  the groups list on the join-group map. Tapping opens the RSVP
//  sheet — no group membership required.
//

import SwiftUI

struct PublicEventCard: View {
    let event: PublicEventNearby
    var onTap: () -> Void

    private var gradient: LinearGradient {
        let from = Color(hex: event.groupGradientFrom ?? "6366F1")
        let to   = Color(hex: event.groupGradientTo   ?? "06B6D4")
        return LinearGradient(colors: [from, to],
                              startPoint: .topLeading,
                              endPoint:   .bottomTrailing)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Hero band — cover image when present, gradient fallback.
                ZStack(alignment: .topLeading) {
                    Group {
                        if let url = event.coverUrl, let u = URL(string: url) {
                            AsyncImage(url: u) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                gradient
                            }
                        } else {
                            gradient
                        }
                    }
                    .frame(height: 96)
                    .clipped()

                    // Group logo chip — sits over the hero so the
                    // viewer always knows which church is hosting.
                    HStack(spacing: 6) {
                        if let logo = event.groupLogoUrl, let lu = URL(string: logo) {
                            AsyncImage(url: lu) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Color.white.opacity(0.4)
                            }
                            .frame(width: 22, height: 22)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        Text(event.groupName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.35), in: Capsule())
                    .padding(8)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(event.startsAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        Text("\(event.goingCount) going")
                        Text("·")
                        Text(event.distanceLabel)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: 220)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
}
