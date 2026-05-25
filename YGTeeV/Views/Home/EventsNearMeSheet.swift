//
//  EventsNearMeSheet.swift
//  YGTeeV
//
//  Apple-Maps-style sliding panel that always sits at one of three
//  detents (minimized handle, medium, large) above the map. Surfaces
//  only the "Events Near Me" carousel + an Add-My-Youth-Group button.
//  The map underneath stays fully interactive via
//  `presentationBackgroundInteraction(.enabled)`.
//

import SwiftUI

struct EventsNearMeSheet: View {
    /// True when the parent sheet is sitting at the smallest detent.
    /// We physically REMOVE the carousel + CTA from the view tree in
    /// that case instead of relying on the detent's visual clip,
    /// which otherwise lets the tops of the cards leak through.
    let isMinimized: Bool
    let events: [PublicEventNearby]
    var onTapEvent: (PublicEventNearby) -> Void
    var onAddGroupTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Always-visible header — bold white over the violet→pink
            // brand gradient that fills the entire sheet.
            Text("Events Near Me")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 12)

            // Carousel + CTA only exist while the sheet is expanded.
            // Removing them from the tree (rather than just clipping)
            // means the minimized detent shows the title and nothing
            // else, no card edges peeking past the clip.
            if !isMinimized {
                if events.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.85))
                        Text("No public events nearby in the next 2 weeks.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(events) { ev in
                                PublicEventCard(event: ev) {
                                    onTapEvent(ev)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                    }
                }

                // Add-my-group affordance — bottom of the expanded sheet.
                // White text on the brand gradient so it reads as part
                // of the same surface.
                Button(action: onAddGroupTap) {
                    Text("Add My Youth Group On The Map")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
