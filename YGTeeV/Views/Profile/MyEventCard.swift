//
//  MyEventCard.swift
//  YGTeeV
//
//  Carousel card surfacing one of the user's (or their child's) RSVPed
//  events on the profile screen. Past cards soften their hero band so
//  the user can tell at a glance which events are done.
//

import SwiftUI

struct MyEventCard: View {
    let event: MyEvent
    var onTap: () -> Void

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: event.groupGradientFrom ?? "6366F1"),
                Color(hex: event.groupGradientTo   ?? "06B6D4")
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private var statusPillColor: Color {
        event.myStatus == "going" ? .green : .orange
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
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
                    // Past events render their hero at 55% so they
                    // visually fade into the "done" state without
                    // dimming the title/copy below.
                    .opacity(event.isUpcoming ? 1 : 0.55)

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

                    HStack {
                        Spacer()
                        Text(event.myStatus.capitalized)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(statusPillColor, in: Capsule())
                            .padding(8)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(event.startsAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(event.goingCount) going")
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
