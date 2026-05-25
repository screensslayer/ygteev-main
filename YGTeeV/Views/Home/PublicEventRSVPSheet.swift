//
//  PublicEventRSVPSheet.swift
//  YGTeeV
//
//  Bottom sheet a user gets from tapping a "Public events nearby"
//  card. They can RSVP "going" or "maybe" without joining the host
//  group — the action runs through `rsvp_public_event` and the
//  sheet replaces its CTAs with a success card on the way back.
//

import SwiftUI

struct PublicEventRSVPSheet: View {
    let event: PublicEventNearby
    /// Returns the new server-side `going_count` on success, throws on
    /// failure so the sheet can surface a retry message.
    var onRSVP: (_ status: String) async throws -> Int

    @Environment(\.dismiss) private var dismiss
    @State private var liveGoingCount: Int
    @State private var submitted = false
    @State private var submitting = false
    @State private var errorText: String?

    init(event: PublicEventNearby,
         onRSVP: @escaping (_ status: String) async throws -> Int) {
        self.event   = event
        self.onRSVP  = onRSVP
        _liveGoingCount = State(initialValue: event.goingCount)
    }

    private var gradient: LinearGradient {
        let from = Color(hex: event.groupGradientFrom ?? "6366F1")
        let to   = Color(hex: event.groupGradientTo   ?? "06B6D4")
        return LinearGradient(colors: [from, to],
                              startPoint: .topLeading,
                              endPoint:   .bottomTrailing)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomLeading) {
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
                    .frame(height: 200)
                    .clipped()

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            if let logo = event.groupLogoUrl, let lu = URL(string: logo) {
                                AsyncImage(url: lu) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: {
                                    Color.white.opacity(0.4)
                                }
                                .frame(width: 28, height: 28)
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                            }
                            Text(event.groupName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                        Text(event.title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LinearGradient(colors: [.clear, .black.opacity(0.55)],
                                               startPoint: .top, endPoint: .bottom))
                }

                VStack(alignment: .leading, spacing: 16) {
                    Label(event.startsAt.formatted(date: .complete, time: .shortened),
                          systemImage: "calendar")
                        .font(.subheadline)

                    if let loc = event.location, !loc.isEmpty {
                        Label(loc, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                    }

                    Label("\(liveGoingCount) going · \(event.distanceLabel) away",
                          systemImage: "person.2.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let desc = event.description, !desc.isEmpty {
                        Divider()
                        Text("About this event")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(desc)
                            .font(.body)
                    }

                    Divider()

                    if submitted {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.green)
                            Text("You're going!")
                                .font(.headline)
                            Text("See you at \(event.title).")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 10) {
                            Button {
                                Task { await submit("going") }
                            } label: {
                                Text(submitting ? "RSVPing..." : "I'm Going!")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(gradient, in: Capsule())
                            }
                            .disabled(submitting)

                            Button {
                                Task { await submit("maybe") }
                            } label: {
                                Text("Maybe")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(.secondarySystemBackground),
                                                in: Capsule())
                            }
                            .disabled(submitting)
                        }

                        if let err = errorText {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(16)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func submit(_ status: String) async {
        submitting = true
        errorText  = nil
        defer { submitting = false }
        do {
            liveGoingCount = try await onRSVP(status)
            submitted = true
        } catch {
            errorText = "Could not RSVP — try again."
            print("[PublicEventRSVPSheet] rsvp failed:", error)
        }
    }
}
