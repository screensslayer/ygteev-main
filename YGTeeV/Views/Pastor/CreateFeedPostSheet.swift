//
//  CreateFeedPostSheet.swift
//  YGTeeV
//
//  Entry sheet for the pastor "create feed post" flow. Two big tiles:
//  Video (Mux upload) and Photo slideshow. Each branches into its own
//  authoring view via NavigationStack push. The sheet stays mounted
//  through the whole flow so dismiss returns to the pastor dashboard.
//

import SwiftUI

struct CreateFeedPostSheet: View {
    let groupId: UUID
    @Environment(\.dismiss) private var dismiss

    @State private var goToVideo = false
    @State private var goToSlideshow = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                header

                VStack(spacing: 14) {
                    tile(
                        emoji: "📹",
                        title: "Video",
                        subtitle: "Upload a clip — sermon snippet, worship night, hype reel.",
                        gradient: [Color(hex: "6B2BFF"), Color(hex: "FF3DA5")]
                    ) {
                        goToVideo = true
                    }

                    tile(
                        emoji: "🖼",
                        title: "Photo slideshow",
                        subtitle: "Pick a few photos. Auto-advances on the feed.",
                        gradient: [Color(hex: "00E0FF"), Color(hex: "0066FF")]
                    ) {
                        goToSlideshow = true
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .background(YGColors.paper.ignoresSafeArea())
            .navigationTitle("New post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(YGColors.ink.opacity(0.6))
                    }
                }
            }
            .navigationDestination(isPresented: $goToVideo) {
                CreateVideoPostView(groupId: groupId) {
                    dismiss()
                }
            }
            .navigationDestination(isPresented: $goToSlideshow) {
                CreateSlideshowPostView(groupId: groupId) {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Drop something on the feed")
                .font(.lilitaOne(size: 24))
                .tracking(-0.5)
                .foregroundStyle(YGColors.ink)
            Text("Only members of your group will see it.")
                .font(.system(size: 13))
                .foregroundStyle(YGColors.ink.opacity(0.6))
        }
    }

    private func tile(emoji: String,
                      title: String,
                      subtitle: String,
                      gradient: [Color],
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(colors: gradient,
                                             startPoint: .topLeading,
                                             endPoint: .bottomTrailing))
                        .frame(width: 56, height: 56)
                    Text(emoji).font(.system(size: 28))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.lilitaOne(size: 18))
                        .tracking(-0.3)
                        .foregroundStyle(YGColors.ink)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(YGColors.ink.opacity(0.6))
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(YGColors.ink.opacity(0.3))
            }
            .padding(16)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(.black.opacity(0.05), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
}
