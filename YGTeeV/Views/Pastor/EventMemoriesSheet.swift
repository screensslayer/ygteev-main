//
//  EventMemoriesSheet.swift
//  YGTeeV
//
//  Photo + video gallery for a single event ("Memories"). Pastors get
//  an "Add Media" button that opens PhotosPicker — selected images go
//  straight to the `event-media` Storage bucket; selected videos go
//  through the `pastor-create-event-media-upload` Edge Function which
//  mints a Mux direct-upload URL, then the bytes are PUT to Mux.
//
//  Group members see the same grid (RLS does the gating server-side)
//  but no Add Media button. Tap a tile to view full-screen.
//

import SwiftUI
import PhotosUI
import AVKit
import UniformTypeIdentifiers

struct EventMemoriesSheet: View {
    let eventId: UUID
    let groupId: UUID
    /// True when the viewer is the pastor of `groupId`. Drives Add
    /// Media affordance visibility — uploads are pastor-only.
    let canManage: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var eventsService = EventsService.shared
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isUploading = false
    @State private var uploadError: String?
    @State private var selectedItem: EventMediaItem?

    private let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
    ]

    private var media: [EventMediaItem] {
        eventsService.mediaByEvent[eventId] ?? []
    }

    var body: some View {
        NavigationStack {
            ZStack {
                YGColors.paper.ignoresSafeArea()
                ScrollView {
                    if media.isEmpty {
                        emptyState
                    } else {
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(media) { item in
                                EventMediaThumbnail(
                                    item: item,
                                    videoStatus: item.videoId.flatMap { eventsService.videoStatusById[$0] }
                                ) {
                                    selectedItem = item
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 4)
                    }
                    if let uploadError {
                        Text(uploadError)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.red)
                            .padding(.top, 12)
                    }
                }
            }
            .navigationTitle("Memories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                if canManage {
                    ToolbarItem(placement: .topBarTrailing) {
                        PhotosPicker(
                            selection: $pickerItems,
                            maxSelectionCount: 20,
                            selectionBehavior: .ordered,
                            matching: .any(of: [.images, .videos])
                        ) {
                            HStack(spacing: 4) {
                                if isUploading {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "photo.badge.plus")
                                }
                                Text(isUploading ? "Uploading…" : "Add")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(YGColors.violet)
                        }
                        .disabled(isUploading)
                    }
                }
            }
            .task {
                try? await eventsService.loadEventMedia(eventId: eventId)
                await eventsService.loadVideoStatuses(forEvent: eventId)
            }
            .onChange(of: pickerItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                Task { await handlePickerSelection(newItems) }
            }
            .sheet(item: $selectedItem) { item in
                EventMediaViewer(
                    item: item,
                    videoStatus: item.videoId.flatMap { eventsService.videoStatusById[$0] }
                )
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 36))
                .foregroundStyle(YGColors.ink.opacity(0.35))
            Text(canManage ? "No memories yet" : "Nothing here yet")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(YGColors.ink)
            Text(canManage
                 ? "Tap Add to upload photos or videos from this event."
                 : "Photos and videos posted by your pastor will appear here.")
                .font(.system(size: 12.5))
                .foregroundStyle(YGColors.ink.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Upload pipeline

    private func handlePickerSelection(_ items: [PhotosPickerItem]) async {
        isUploading = true
        uploadError = nil
        defer {
            isUploading = false
            pickerItems = []
        }

        for item in items {
            do {
                if try await isVideo(item) {
                    try await uploadVideo(item: item)
                } else {
                    try await uploadPhoto(item: item)
                }
            } catch {
                print("[EventMemories] upload failed:", error)
                uploadError = "One or more uploads failed. Tap Add to try again."
            }
        }

        try? await eventsService.loadEventMedia(eventId: eventId)
        await eventsService.loadVideoStatuses(forEvent: eventId)
    }

    private func isVideo(_ item: PhotosPickerItem) async throws -> Bool {
        // Best-effort detect: PhotosPicker exposes the asset's
        // supportedContentTypes; a video item conforms to .movie/.video.
        if item.supportedContentTypes.contains(where: {
            $0.conforms(to: .movie) || $0.conforms(to: .video)
        }) {
            return true
        }
        return false
    }

    private func uploadPhoto(item: PhotosPickerItem) async throws {
        guard let data = try await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        _ = try await eventsService.uploadEventPhoto(
            eventId: eventId,
            groupId: groupId,
            image: image,
            caption: nil
        )
    }

    private func uploadVideo(item: PhotosPickerItem) async throws {
        // Pull the picked video as a temporary file URL — Mux's PUT
        // wants a file-based upload (URLSession.upload(for:fromFile:)),
        // and loading the whole movie into memory would blow up on
        // anything longer than a few seconds.
        guard let movie = try await item.loadTransferable(type: PickedMovie.self) else {
            throw NSError(domain: "EventMemories", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Couldn't read selected video."])
        }
        defer { try? FileManager.default.removeItem(at: movie.url) }
        try await eventsService.uploadEventVideo(
            eventId: eventId,
            fileURL: movie.url,
            caption: nil
        )
    }
}

// MARK: - PhotosPicker movie transferable
//
// PhotosPicker delivers a video as a Transferable. Mux's PUT endpoint
// streams from a file, so we materialize the picked video to a temp
// URL via `FileRepresentation` and hand that path back to the caller.

private struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            // PhotosPicker hands us a temp URL that vanishes when the
            // representation closure returns. Copy it into our own
            // tmp dir so the upload Task can still read it after.
            let dest = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: dest)
            return PickedMovie(url: dest)
        }
    }
}

// MARK: - Grid thumbnail

struct EventMediaThumbnail: View {
    let item: EventMediaItem
    let videoStatus: EventVideoStatus?
    let onTap: () -> Void

    @State private var signedUrl: URL?
    @State private var loadError: Bool = false

    private var isVideo: Bool { item.kind == "video" }
    private var isProcessing: Bool { isVideo && videoStatus?.isReady != true }

    private var thumbnailUrl: URL? {
        if isVideo, let playbackId = videoStatus?.muxPlaybackId {
            return URL(string: "https://image.mux.com/\(playbackId)/thumbnail.jpg?width=640")
        }
        return signedUrl
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Color.black.opacity(0.06)

                if let url = thumbnailUrl {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure:
                            placeholderIcon
                        default:
                            ProgressView().tint(YGColors.ink.opacity(0.4))
                        }
                    }
                } else if loadError {
                    placeholderIcon
                } else {
                    ProgressView().tint(YGColors.ink.opacity(0.4))
                }

                if isVideo {
                    if isProcessing {
                        VStack(spacing: 4) {
                            Image(systemName: "clock.badge")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("Processing…")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .padding(8)
                        .background(.black.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.black.opacity(0.45))
                            .clipShape(Circle())
                    }
                }
            }
            .aspectRatio(1, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .task(id: item.id) {
            await resolveSignedUrlIfNeeded()
        }
    }

    private var placeholderIcon: some View {
        Image(systemName: isVideo ? "video.slash" : "photo")
            .font(.system(size: 22))
            .foregroundStyle(YGColors.ink.opacity(0.35))
    }

    private func resolveSignedUrlIfNeeded() async {
        guard !isVideo, signedUrl == nil, let path = item.storagePath else { return }
        do {
            signedUrl = try await EventsService.shared.signedUrl(for: path)
        } catch {
            loadError = true
        }
    }
}

// MARK: - Full-screen viewer

private struct EventMediaViewer: View {
    let item: EventMediaItem
    let videoStatus: EventVideoStatus?

    @Environment(\.dismiss) private var dismiss
    @State private var signedUrl: URL?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 16)
                }
                Spacer()
            }
        }
        .task {
            await resolveSignedUrl()
        }
    }

    @ViewBuilder
    private var content: some View {
        if item.kind == "video" {
            if let id = videoStatus?.muxPlaybackId, videoStatus?.isReady == true,
               let url = URL(string: "https://stream.mux.com/\(id).m3u8") {
                VideoPlayer(player: AVPlayer(url: url))
                    .ignoresSafeArea()
            } else {
                VStack(spacing: 8) {
                    ProgressView().tint(.white)
                    Text("Video is still processing…")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        } else {
            if let url = signedUrl {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFit()
                    case .failure: Text("Couldn't load photo").foregroundStyle(.white)
                    default: ProgressView().tint(.white)
                    }
                }
                .padding()
            } else {
                ProgressView().tint(.white)
            }
        }
    }

    private func resolveSignedUrl() async {
        guard item.kind == "photo", let path = item.storagePath else { return }
        signedUrl = try? await EventsService.shared.signedUrl(for: path)
    }
}
