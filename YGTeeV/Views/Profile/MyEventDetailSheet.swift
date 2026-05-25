//
//  MyEventDetailSheet.swift
//  YGTeeV
//
//  Bottom sheet a user gets from tapping a "My Events" / past / child
//  carousel card on the profile screen. For their own upcoming
//  events they can flip Going / Maybe / Can't; everything else
//  (past, kid carousels) renders read-only.
//

import SwiftUI

struct MyEventDetailSheet: View {
    let event: MyEvent
    let readOnly: Bool
    /// Called when the viewer toggles their own RSVP. Returns the new
    /// server-side `going_count` so the sheet can update its live
    /// count without a full reload.
    var onChangeStatus: ((_ status: String) async throws -> Int)?

    @Environment(\.dismiss) private var dismiss
    @State private var liveStatus: String
    @State private var liveGoing: Int
    @State private var submitting = false
    @State private var errorText: String?

    init(event: MyEvent,
         readOnly: Bool = false,
         onChangeStatus: ((_ status: String) async throws -> Int)? = nil) {
        self.event          = event
        self.readOnly       = readOnly
        self.onChangeStatus = onChangeStatus
        _liveStatus = State(initialValue: event.myStatus)
        _liveGoing  = State(initialValue: event.goingCount)
    }

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: event.groupGradientFrom ?? "6366F1"),
                Color(hex: event.groupGradientTo   ?? "06B6D4")
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
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

                    Label("\(liveGoing) going", systemImage: "person.2.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let desc = event.description, !desc.isEmpty {
                        Divider()
                        Text("About this event")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(desc).font(.body)
                    }

                    Divider()

                    if readOnly || !event.isUpcoming {
                        // Read-only: past events + kid carousels.
                        HStack(spacing: 8) {
                            Text("RSVP")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(liveStatus.capitalized)
                                .font(.subheadline.weight(.bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(liveStatus == "going" ? Color.green : Color.orange,
                                            in: Capsule())
                                .foregroundStyle(.white)
                        }
                    } else {
                        VStack(spacing: 10) {
                            Text("Your RSVP")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            HStack(spacing: 8) {
                                statusButton("going",    label: "Going")
                                statusButton("maybe",    label: "Maybe")
                                statusButton("declined", label: "Can't")
                            }
                            if let err = errorText {
                                Text(err)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func statusButton(_ value: String, label: String) -> some View {
        let isSelected = liveStatus == value
        Button {
            Task { await change(to: value) }
        } label: {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? YGColors.violet : Color(.secondarySystemBackground),
                            in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .disabled(submitting)
    }

    private func change(to status: String) async {
        guard let handler = onChangeStatus else { return }
        submitting = true
        errorText  = nil
        defer { submitting = false }
        do {
            liveGoing  = try await handler(status)
            liveStatus = status
        } catch {
            errorText = "Couldn't update RSVP — try again."
            print("[MyEventDetailSheet] change failed:", error)
        }
    }
}
