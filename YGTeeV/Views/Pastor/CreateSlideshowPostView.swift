//
//  CreateSlideshowPostView.swift
//  YGTeeV
//
//  Pastor-side authoring view for a slideshow feed post. Flow:
//    1. Pick 1–10 photos via PhotosPicker.
//    2. (Optional) title + caption.
//    3. Hit "Publish" — creates the draft post (RPC), uploads each
//       photo to the `feed-photos` bucket, attaches the rows, and
//       calls `pastor_publish_feed_post`. Progress is shown inline.
//

import SwiftUI
import PhotosUI

struct CreateSlideshowPostView: View {
    let groupId: UUID
    let onPublished: () -> Void

    @State private var title = ""
    @State private var caption = ""
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var pickedImages: [UIImage] = []
    @State private var isPicking = false

    /// Multi-stage progress so the user knows what's happening when the
    /// publish button is held for ~10s on a 5-photo slideshow.
    enum Stage: Equatable {
        case idle
        case loadingImages
        case creatingDraft
        case uploading(done: Int, total: Int)
        case attaching
        case publishing
        case done
        case error(String)
    }
    @State private var stage: Stage = .idle

    private var feed: FeedService { FeedService.shared }

    private var isWorking: Bool {
        switch stage {
        case .idle, .done, .error: return false
        default: return true
        }
    }

    private var canPublish: Bool {
        !pickedImages.isEmpty && !isWorking
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                pickerSection
                if !pickedImages.isEmpty {
                    thumbnailStrip
                }
                fields
                progressOrError
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 120)
        }
        .background(YGColors.paper.ignoresSafeArea())
        .navigationTitle("Photo slideshow")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            publishBar
        }
        .photosPicker(isPresented: $isPicking,
                      selection: $pickerItems,
                      maxSelectionCount: 10,
                      matching: .images)
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await loadPickedImages(items) }
        }
    }

    // MARK: - Subviews

    private var pickerSection: some View {
        Button {
            isPicking = true
        } label: {
            VStack(spacing: 10) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(YGColors.violet)
                Text(pickedImages.isEmpty ? "Pick photos" : "Replace photos")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(YGColors.ink)
                Text("Up to 10 — they'll auto-advance on the feed.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(YGColors.ink.opacity(0.55))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(YGColors.violet.opacity(0.25),
                                  style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            }
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
    }

    private var thumbnailStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(pickedImages.enumerated()), id: \.offset) { _, img in
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 86, height: 86)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(.black.opacity(0.08), lineWidth: 0.5)
                        }
                }
            }
        }
    }

    private var fields: some View {
        VStack(spacing: 0) {
            labeledField(label: "TITLE (optional)",
                         placeholder: "What's this drop?",
                         text: $title)
            Divider().padding(.leading, 16)
            labeledField(label: "CAPTION (optional)",
                         placeholder: "Add some context…",
                         text: $caption,
                         multiline: true)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.05), lineWidth: 0.5)
        }
    }

    @ViewBuilder
    private var progressOrError: some View {
        switch stage {
        case .loadingImages:
            inlineProgress(text: "Loading photos…")
        case .creatingDraft:
            inlineProgress(text: "Creating draft post…")
        case .uploading(let done, let total):
            inlineProgress(text: "Uploading \(done)/\(total)…")
        case .attaching:
            inlineProgress(text: "Linking photos…")
        case .publishing:
            inlineProgress(text: "Publishing…")
        case .error(let msg):
            Text(msg)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .done, .idle:
            EmptyView()
        }
    }

    private var publishBar: some View {
        Button(action: publish) {
            HStack(spacing: 8) {
                if isWorking { ProgressView().tint(.white) }
                Text(isWorking ? "Working…" : "Publish")
                    .font(.system(size: 15.5, weight: .black, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: [YGColors.violet, Color(hex: "FF3DA5")],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: YGColors.violet.opacity(0.35), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(!canPublish)
        .opacity(canPublish ? 1 : 0.5)
        .padding(.horizontal, 16)
        .padding(.bottom, 22)
        .padding(.top, 8)
        .background(YGColors.paper)
    }

    private func labeledField(label: String,
                              placeholder: String,
                              text: Binding<String>,
                              multiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10.5, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(YGColors.ink.opacity(0.55))
            if multiline {
                TextField(placeholder, text: text, axis: .vertical)
                    .lineLimit(2...5)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(YGColors.ink)
            } else {
                TextField(placeholder, text: text)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(YGColors.ink)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inlineProgress(text: String) -> some View {
        HStack(spacing: 8) {
            ProgressView().scaleEffect(0.8).tint(YGColors.violet)
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(YGColors.ink.opacity(0.7))
        }
    }

    // MARK: - Actions

    private func loadPickedImages(_ items: [PhotosPickerItem]) async {
        stage = .loadingImages
        var loaded: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                loaded.append(img)
            }
        }
        await MainActor.run {
            self.pickedImages = loaded
            self.stage = .idle
        }
    }

    private func publish() {
        guard canPublish else { return }
        Task { await runPublishFlow() }
    }

    private func runPublishFlow() async {
        do {
            stage = .creatingDraft
            let postId = try await feed.createSlideshowDraft(
                groupId: groupId,
                title: title,
                caption: caption
            )

            // Upload each photo at jpeg-0.85, in original picker order.
            let total = pickedImages.count
            stage = .uploading(done: 0, total: total)
            for (i, img) in pickedImages.enumerated() {
                guard let data = img.jpegData(compressionQuality: 0.85) else {
                    throw NSError(domain: "CreateSlideshowPostView", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "Couldn't encode photo \(i + 1)."])
                }
                try await feed.uploadSlideshowImage(postId: postId, index: i, data: data)
                stage = .uploading(done: i + 1, total: total)
            }

            stage = .attaching
            try await feed.attachSlideshowPhotos(postId: postId, count: total)

            stage = .publishing
            try await feed.publishPost(postId: postId)

            stage = .done
            onPublished()
        } catch {
            stage = .error("Couldn't publish: \(error.localizedDescription)")
        }
    }
}
