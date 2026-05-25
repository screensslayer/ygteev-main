//
//  CreateVideoPostView.swift
//  YGTeeV
//
//  Pastor-side authoring view for a video feed post. Flow:
//    1. Pick a local video file via PhotosPicker (.videos).
//    2. (Optional) title + caption.
//    3. "Upload" → calls `pastor-create-mux-upload` Edge Function, which
//       returns a signed Mux direct-upload URL + draft post id + video id.
//    4. PUT the raw bytes to the Mux URL (URLSession upload task, with
//       progress).
//    5. Poll `videos` row until `status == 'ready'`.
//    6. "Publish" → `pastor_publish_feed_post`.
//

import SwiftUI
import PhotosUI
import AVFoundation

struct CreateVideoPostView: View {
    let groupId: UUID
    let onPublished: () -> Void

    @State private var title = ""
    @State private var caption = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var isPicking = false

    /// Local URL of the picked video file once we've materialized the
    /// PhotosPickerItem to disk.
    @State private var localVideoURL: URL?
    /// Server-issued IDs returned by the Edge Function.
    @State private var ticket: FeedService.MuxUploadTicket?

    /// 0…1 upload progress. Driven by URLSession upload-task delegate.
    @State private var uploadProgress: Double = 0
    /// Mux transcode status while polling.
    @State private var muxStatus: String?

    enum Stage: Equatable {
        case idle
        case loadingFile
        case creatingTicket
        case uploading
        case waitingForTranscode
        case readyToPublish
        case publishing
        case done
        case error(String)
    }
    @State private var stage: Stage = .idle

    private var feed: FeedService { FeedService.shared }

    private var isWorking: Bool {
        switch stage {
        case .idle, .readyToPublish, .done, .error: return false
        default: return true
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                pickerSection
                fields
                progressSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 120)
        }
        .background(YGColors.paper.ignoresSafeArea())
        .navigationTitle("Video")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            primaryBar
        }
        .photosPicker(isPresented: $isPicking,
                      selection: $pickerItem,
                      matching: .videos)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await loadPicked(item) }
        }
    }

    // MARK: - Subviews

    private var pickerSection: some View {
        Button {
            isPicking = true
        } label: {
            VStack(spacing: 10) {
                Image(systemName: localVideoURL == nil ? "video.badge.plus" : "checkmark.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(YGColors.violet)
                Text(localVideoURL == nil ? "Pick a video" : "Video selected · tap to replace")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(YGColors.ink)
                Text("Vertical or square works best. Up to ~5 minutes.")
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

    private var fields: some View {
        VStack(spacing: 0) {
            labeledField(label: "TITLE (optional)", placeholder: "What is it?", text: $title)
            Divider().padding(.leading, 16)
            labeledField(label: "CAPTION (optional)", placeholder: "Caption…", text: $caption, multiline: true)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.05), lineWidth: 0.5)
        }
    }

    @ViewBuilder
    private var progressSection: some View {
        switch stage {
        case .loadingFile:
            inlineProgress(text: "Reading file…")
        case .creatingTicket:
            inlineProgress(text: "Reserving upload slot…")
        case .uploading:
            VStack(alignment: .leading, spacing: 6) {
                Text("Uploading to Mux · \(Int(uploadProgress * 100))%")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(YGColors.ink.opacity(0.7))
                ProgressView(value: uploadProgress)
                    .tint(YGColors.violet)
            }
        case .waitingForTranscode:
            inlineProgress(text: "Mux is transcoding · \(muxStatus ?? "processing")…")
        case .readyToPublish:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(.green)
                Text("Ready — hit Publish to drop it on the feed.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(YGColors.ink.opacity(0.8))
            }
        case .publishing:
            inlineProgress(text: "Publishing…")
        case .error(let msg):
            Text(msg)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .idle, .done:
            EmptyView()
        }
    }

    private var primaryBar: some View {
        Button(action: primaryTap) {
            HStack(spacing: 8) {
                if isWorking { ProgressView().tint(.white) }
                Text(primaryLabel)
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
        .disabled(!primaryEnabled)
        .opacity(primaryEnabled ? 1 : 0.5)
        .padding(.horizontal, 16)
        .padding(.bottom, 22)
        .padding(.top, 8)
        .background(YGColors.paper)
    }

    private var primaryLabel: String {
        switch stage {
        case .readyToPublish: return "Publish"
        case .publishing:     return "Publishing…"
        default:              return isWorking ? "Working…" : "Upload"
        }
    }

    private var primaryEnabled: Bool {
        switch stage {
        case .idle, .error:      return localVideoURL != nil
        case .readyToPublish:    return true
        default:                 return false
        }
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

    private func loadPicked(_ item: PhotosPickerItem) async {
        stage = .loadingFile
        do {
            // PhotosPicker can return a `Movie` `Transferable` representation
            // that materializes to a local URL — that's what we want for a
            // streaming PUT upload.
            if let movie = try await item.loadTransferable(type: PickedMovie.self) {
                await MainActor.run {
                    self.localVideoURL = movie.url
                    self.stage = .idle
                }
                return
            }
            // Fall back to loading raw bytes and writing them to tmp.
            if let data = try await item.loadTransferable(type: Data.self) {
                let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("upload-\(UUID().uuidString).mov")
                try data.write(to: tmp)
                await MainActor.run {
                    self.localVideoURL = tmp
                    self.stage = .idle
                }
                return
            }
            await MainActor.run {
                self.stage = .error("Couldn't read the picked video.")
            }
        } catch {
            await MainActor.run {
                self.stage = .error("Couldn't load video: \(error.localizedDescription)")
            }
        }
    }

    private func primaryTap() {
        switch stage {
        case .readyToPublish:
            Task { await runPublish() }
        default:
            Task { await runUpload() }
        }
    }

    private func runUpload() async {
        guard let url = localVideoURL else { return }
        do {
            stage = .creatingTicket
            let ticket = try await feed.createMuxUploadTicket(
                groupId: groupId,
                title: title,
                caption: caption
            )
            self.ticket = ticket

            stage = .uploading
            try await streamUpload(fileURL: url, to: ticket.uploadURL)

            stage = .waitingForTranscode
            try await pollUntilReady(videoId: ticket.videoId)

            stage = .readyToPublish
        } catch {
            stage = .error("Upload failed: \(error.localizedDescription)")
        }
    }

    private func runPublish() async {
        guard let postId = ticket?.postId else { return }
        do {
            stage = .publishing
            try await feed.publishPost(postId: postId)
            stage = .done
            onPublished()
        } catch {
            stage = .error("Publish failed: \(error.localizedDescription)")
        }
    }

    /// Streams the picked file to the Mux direct-upload URL via a PUT
    /// request. Drives `uploadProgress` so the UI shows real progress.
    private func streamUpload(fileURL: URL, to uploadURLString: String) async throws {
        guard let uploadURL = URL(string: uploadURLString) else {
            throw NSError(domain: "CreateVideoPostView", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Bad Mux upload URL."])
        }
        var req = URLRequest(url: uploadURL)
        req.httpMethod = "PUT"
        // Mux accepts any video MIME; the actual transcode is content-based.
        req.setValue("video/mp4", forHTTPHeaderField: "Content-Type")

        let delegate = UploadProgressDelegate { fraction in
            Task { @MainActor in self.uploadProgress = fraction }
        }
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let (_, response) = try await session.upload(for: req, fromFile: fileURL)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw NSError(domain: "CreateVideoPostView", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Mux rejected upload (HTTP \(http.statusCode))."])
        }
    }

    /// Polls `videos.status` every 3s up to ~3 minutes. Returns when status
    /// hits `ready`; throws on `errored` or timeout.
    private func pollUntilReady(videoId: UUID) async throws {
        let deadline = Date().addingTimeInterval(180)
        while Date() < deadline {
            let row = try await feed.fetchVideoStatus(videoId: videoId)
            await MainActor.run { self.muxStatus = row.status }
            switch row.status {
            case "ready":   return
            case "errored": throw NSError(domain: "CreateVideoPostView", code: 2,
                                          userInfo: [NSLocalizedDescriptionKey: "Mux transcoding failed."])
            default:        try await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
        throw NSError(domain: "CreateVideoPostView", code: 3,
                      userInfo: [NSLocalizedDescriptionKey: "Transcode took too long — try again."])
    }
}

// MARK: - PhotosPicker movie transferable

/// PhotosPicker can hand back a movie file URL via a custom `Transferable`
/// representation. We copy it into the temp dir so we have a stable path
/// for the URLSession upload (the picker's URL is short-lived).
struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("upload-\(UUID().uuidString).mov")
            if FileManager.default.fileExists(atPath: copy.path) {
                try FileManager.default.removeItem(at: copy)
            }
            try FileManager.default.copyItem(at: received.file, to: copy)
            return PickedMovie(url: copy)
        }
    }
}

// MARK: - URLSession upload progress

/// Bridges URLSession upload-task progress into a SwiftUI-safe callback.
/// Owned for the duration of the upload by `streamUpload`.
private final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate {
    let onProgress: (Double) -> Void
    init(onProgress: @escaping (Double) -> Void) { self.onProgress = onProgress }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64,
                    totalBytesExpectedToSend: Int64) {
        guard totalBytesExpectedToSend > 0 else { return }
        let fraction = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        onProgress(min(max(fraction, 0), 1))
    }
}
