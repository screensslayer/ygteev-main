//
//  VideoEditorView.swift
//  YGTeeV
//
//  Editor sheet for a video block. Pastor can either:
//    1. Pick a local file and upload it directly to Mux via a one-time
//       upload URL the Edge Function mints for us. Mux's webhook then
//       fills in `mux_playback_id` + flips `status` to 'ready' — we
//       poll the `videos` row to learn that.
//    2. Paste a URL (Mux playback URL, YouTube embed, etc.) as a
//       fallback for external assets or testing.
//

import SwiftUI
import PhotosUI
import AVFoundation

struct VideoEditorView: View {
    let planId: UUID
    let dayNumber: Int
    let blockId: UUID
    let initialTitle: String
    let initialURL: String
    let initialDurationSeconds: Int?
    let initialVideoId: UUID?
    let onSave: (_ title: String,
                 _ url: String,
                 _ durationSeconds: Int?,
                 _ videoId: UUID?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var service = PastorPlanService.shared

    @State private var title: String = ""
    @State private var url: String = ""
    @State private var durationSeconds: Int = 60
    @State private var includeDuration: Bool = false
    @State private var videoId: UUID?
    @State private var showURLField: Bool = false

    // Picker + upload state machine
    @State private var pickedVideo: PhotosPickerItem?
    @State private var isPicking: Bool = false
    /// Camera-based capture; presented as a full-screen cover hosting
    /// `UIImagePickerController` in video mode.
    @State private var isRecording: Bool = false
    @State private var stage: Stage = .idle
    @State private var uploadProgress: Double = 0
    @State private var muxStatus: String?
    @State private var muxPlaybackId: String?
    @State private var pollTask: Task<Void, Never>?
    @State private var errorMessage: String?

    enum Stage: Equatable {
        case idle              // nothing picked / no video attached
        case preparing         // resolving plan_day_id + minting upload URL
        case uploading         // PUT in flight (uploadProgress drives the bar)
        case processing        // Mux is encoding, we're polling
        case ready             // Mux returned 'ready' with a playback id
        case errored
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    typeChip
                    titleCard
                    videoSourceCard
                    if showURLField || (!url.isEmpty && videoId == nil) {
                        urlCard
                    }
                    durationCard
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(16)
                .padding(.bottom, 120)
            }
            .background(YGColors.paper)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        pollTask?.cancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        pollTask?.cancel()
                        onSave(
                            title.trimmingCharacters(in: .whitespaces),
                            url.trimmingCharacters(in: .whitespaces),
                            includeDuration ? durationSeconds : nil,
                            videoId
                        )
                        dismiss()
                    }
                    .bold()
                    .disabled(!isValid)
                }
            }
            .photosPicker(isPresented: $isPicking,
                          selection: $pickedVideo,
                          matching: .videos)
            .onChange(of: pickedVideo) { _, item in
                guard let item else { return }
                Task { await beginUpload(item: item) }
            }
            .fullScreenCover(isPresented: $isRecording) {
                CameraVideoRecorder { result in
                    isRecording = false
                    switch result {
                    case .recorded(let localURL):
                        Task { await runUploadFlow(localURL: localURL,
                                                   cleanupAfterUpload: true) }
                    case .cancelled:
                        break
                    case .failed(let message):
                        errorMessage = message
                        stage = .errored
                    }
                }
                .ignoresSafeArea()
            }
            .onAppear {
                if title.isEmpty { title = initialTitle }
                if url.isEmpty { url = initialURL }
                if videoId == nil { videoId = initialVideoId }
                if let d = initialDurationSeconds {
                    durationSeconds = d
                    includeDuration = true
                }
                showURLField = !initialURL.isEmpty && initialVideoId == nil
                Task { await refreshStatusFromServer() }
            }
            .onDisappear { pollTask?.cancel() }
        }
    }

    // MARK: - Validation

    private var isValid: Bool {
        let t = title.trimmingCharacters(in: .whitespaces)
        let u = url.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return false }
        if videoId != nil { return true }
        return !u.isEmpty && (u.hasPrefix("http://") || u.hasPrefix("https://"))
    }

    // MARK: - Subviews

    private var typeChip: some View {
        HStack(spacing: 5) {
            Text("🎥").font(.system(size: 11))
            Text("VIDEO")
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.4)
        }
        .foregroundStyle(BlockKind.video.accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(BlockKind.video.tint)
        .clipShape(Capsule())
    }

    private var titleCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TITLE")
                .font(.system(size: 10.5, weight: .heavy))
                .tracking(0.4)
                .foregroundStyle(YGColors.ink.opacity(0.55))
            TextField("What is Romans about?", text: $title)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(YGColors.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.06), lineWidth: 0.5) }
    }

    private var videoSourceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("VIDEO")
                .font(.system(size: 10.5, weight: .heavy))
                .tracking(0.4)
                .foregroundStyle(YGColors.ink.opacity(0.55))

            statusBlock

            // Two equal-weight CTAs: pick from library OR record in-app.
            // Both feed the same upload pipeline.
            HStack(spacing: 8) {
                Button {
                    errorMessage = nil
                    isPicking = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 14, weight: .heavy))
                        Text(uploadButtonLabel)
                            .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [YGColors.violet, Color(hex: "FF3DA5")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: YGColors.violet.opacity(0.35), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(busyCapturing)
                .opacity(busyCapturing ? 0.5 : 1)

                Button {
                    errorMessage = nil
                    isRecording = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 13, weight: .heavy))
                        Text(recordButtonLabel)
                            .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(YGColors.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.white)
                    .clipShape(Capsule())
                    .overlay {
                        Capsule().strokeBorder(YGColors.violet.opacity(0.4), lineWidth: 1.5)
                    }
                }
                .buttonStyle(.plain)
                .disabled(busyCapturing)
                .opacity(busyCapturing ? 0.5 : 1)
            }

            if videoId != nil {
                Button {
                    pollTask?.cancel()
                    videoId = nil
                    url = ""
                    durationSeconds = 60
                    includeDuration = false
                    muxStatus = nil
                    muxPlaybackId = nil
                    uploadProgress = 0
                    stage = .idle
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .heavy))
                        Text("Remove video")
                            .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(Color(hex: "D11149"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color(hex: "D11149").opacity(0.10))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(busyCapturing)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showURLField.toggle()
                }
            } label: {
                Text(showURLField ? "Hide URL field" : "Paste a URL instead")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(YGColors.violet)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.06), lineWidth: 0.5) }
    }

    /// Library-pick button label.
    private var uploadButtonLabel: String {
        switch stage {
        case .uploading:  return "Uploading…"
        case .preparing:  return "Preparing…"
        case .processing: return "Replace video"
        case .ready:      return "Replace video"
        case .idle, .errored: return videoId == nil ? "Upload video" : "Replace video"
        }
    }

    /// In-app camera capture button label.
    private var recordButtonLabel: String {
        videoId == nil ? "Record video" : "Re-record"
    }

    /// True while we're mid-pipeline and shouldn't accept another
    /// pick/record. Disables both CTAs.
    private var busyCapturing: Bool {
        stage == .preparing || stage == .uploading
    }

    @ViewBuilder
    private var statusBlock: some View {
        switch stage {
        case .idle:
            statusRow(icon: "video.slash",
                      color: YGColors.ink.opacity(0.5),
                      tint: YGColors.ink.opacity(0.05),
                      title: videoId == nil ? "No video attached" : "Video attached",
                      subtitle: videoId == nil
                          ? "Upload from your library or paste a video URL."
                          : "Saved · pastors can preview at any status.")
        case .preparing:
            statusRow(icon: "clock",
                      color: YGColors.violet,
                      tint: YGColors.violet.opacity(0.10),
                      title: "Preparing upload…",
                      subtitle: "Reserving an upload slot for this block.",
                      showSpinner: true)
        case .uploading:
            VStack(alignment: .leading, spacing: 8) {
                statusRow(icon: "arrow.up.circle",
                          color: YGColors.violet,
                          tint: YGColors.violet.opacity(0.10),
                          title: "Uploading to YGTeeV · \(Int(uploadProgress * 100))%",
                          subtitle: "Keep this screen open until it finishes.")
                ProgressView(value: uploadProgress)
                    .tint(YGColors.violet)
            }
        case .processing:
            statusRow(icon: "gearshape.2",
                      color: Color(hex: "B8860B"),
                      tint: Color(hex: "FFD60A").opacity(0.18),
                      title: "YGTeeV is encoding…",
                      subtitle: "Status: \(muxStatus ?? "processing"). This usually takes < 30s.",
                      showSpinner: true)
        case .ready:
            statusRow(icon: "checkmark.circle.fill",
                      color: Color(hex: "2B8A3E"),
                      tint: Color(hex: "B4FF3C").opacity(0.20),
                      title: "Ready to play",
                      subtitle: muxPlaybackId.map { "Playback id: …\($0.suffix(6))" } ?? "Video is ready for members.")
        case .errored:
            statusRow(icon: "exclamationmark.triangle.fill",
                      color: Color(hex: "D11149"),
                      tint: Color(hex: "D11149").opacity(0.10),
                      title: "Upload failed",
                      subtitle: errorMessage ?? "Try again or paste a URL instead.")
        }
    }

    private func statusRow(icon: String,
                           color: Color,
                           tint: Color,
                           title: String,
                           subtitle: String,
                           showSpinner: Bool = false) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(tint)
                    .frame(width: 36, height: 36)
                if showSpinner {
                    ProgressView().scaleEffect(0.8).tint(color)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(color)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(YGColors.ink)
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(YGColors.ink.opacity(0.55))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }

    private var urlCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("VIDEO URL")
                .font(.system(size: 10.5, weight: .heavy))
                .tracking(0.4)
                .foregroundStyle(YGColors.ink.opacity(0.55))
            TextField("https://stream.mux.com/…", text: $url)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(YGColors.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.06), lineWidth: 0.5) }
    }

    private var durationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $includeDuration) {
                Text("DURATION")
                    .font(.system(size: 10.5, weight: .heavy))
                    .tracking(0.4)
                    .foregroundStyle(YGColors.ink.opacity(0.55))
            }
            if includeDuration {
                HStack(alignment: .firstTextBaseline) {
                    Text(formatDuration(durationSeconds))
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(YGColors.ink)
                        .monospacedDigit()
                    Spacer()
                    HStack(spacing: 8) {
                        stepperButton("−15s") { durationSeconds = max(15, durationSeconds - 15) }
                        stepperButton("+15s") { durationSeconds = min(3600, durationSeconds + 15) }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.06), lineWidth: 0.5) }
    }

    private func stepperButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(YGColors.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(YGColors.ink.opacity(0.06))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Upload flow

    /// Materializes the picked `PhotosPickerItem` to a local file and
    /// hands off to the shared upload flow.
    @MainActor
    private func beginUpload(item: PhotosPickerItem) async {
        // Reset the picker binding so picking the same file again
        // re-fires onChange.
        defer { pickedVideo = nil }
        errorMessage = nil
        uploadProgress = 0
        stage = .preparing

        do {
            guard let localURL = try await materializeToTempFile(item: item) else {
                errorMessage = "Couldn't read that video."
                stage = .errored
                return
            }
            await runUploadFlow(localURL: localURL, cleanupAfterUpload: true)
        } catch {
            errorMessage = error.localizedDescription
            stage = .errored
        }
    }

    /// Shared upload pipeline used by both the library picker and the
    /// in-app recorder: resolve the day id → mint an upload URL → PUT
    /// the file → poll until ready. `cleanupAfterUpload` deletes the
    /// temp file we created on iOS' side after the upload finishes.
    @MainActor
    private func runUploadFlow(localURL: URL, cleanupAfterUpload: Bool) async {
        pollTask?.cancel()
        errorMessage = nil
        uploadProgress = 0
        stage = .preparing
        muxStatus = nil
        muxPlaybackId = nil

        do {
            // Make sure the bible_plan_days row exists. Autosave's
            // 500ms debounce might still be in flight, and we need the
            // day's row id for the Edge Function.
            await service.flushPending(forDay: dayNumber)
            guard let dayId = try await service.fetchPlanDayId(planId: planId, dayNumber: dayNumber) else {
                errorMessage = "This day hasn't been saved yet. Add a block and try again."
                stage = .errored
                return
            }

            let handle = try await service.createPlanVideoUpload(
                planId: planId,
                dayId: dayId,
                blockId: blockId,
                title: title.trimmingCharacters(in: .whitespaces)
            )

            // Persist video_id immediately so a background/kill
            // mid-upload doesn't strand the row.
            videoId = handle.videoId

            guard let uploadURL = URL(string: handle.uploadUrl) else {
                errorMessage = "Bad upload URL from server."
                stage = .errored
                return
            }

            stage = .uploading
            try await service.uploadVideoFile(localURL, to: uploadURL) { fraction in
                Task { @MainActor in self.uploadProgress = fraction }
            }

            if cleanupAfterUpload {
                try? FileManager.default.removeItem(at: localURL)
            }

            stage = .processing
            pollTask = Task { await pollForReady(videoId: handle.videoId) }
        } catch {
            errorMessage = error.localizedDescription
            stage = .errored
        }
    }

    /// Polls `videos` every 3s until `status='ready'` (success) or
    /// `status='errored'` (failure). Caps at 3 minutes — Mux short
    /// clips usually finish in under 30s but a slow network on the
    /// pastor's end can stretch the upload.
    @MainActor
    private func pollForReady(videoId vid: UUID) async {
        let deadline = Date().addingTimeInterval(180)
        while Date() < deadline {
            if Task.isCancelled { return }
            do {
                if let row = try await service.fetchPlanVideo(id: vid) {
                    muxStatus = row.status
                    switch row.status {
                    case "ready":
                        muxPlaybackId = row.muxPlaybackId
                        if let pid = row.muxPlaybackId {
                            // Cache the resolved URL on the block so the
                            // member-side reader doesn't need to round-trip.
                            url = "https://stream.mux.com/\(pid).m3u8"
                        }
                        if let dur = row.durationSec {
                            durationSeconds = Int(dur.rounded())
                            includeDuration = true
                        }
                        stage = .ready
                        return
                    case "errored":
                        errorMessage = "YGTeeV couldn't process this file."
                        stage = .errored
                        return
                    default:
                        break // still uploading / processing
                    }
                }
            } catch {
                // Transient lookup errors shouldn't kill the poll loop.
                print("[VideoEditorView] fetchPlanVideo error:", error)
            }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
        }
        errorMessage = "Encoding is taking longer than expected. The video may still finish — re-open the block in a minute."
        stage = .errored
    }

    /// On reopening an existing block with a `video_id`, pull the
    /// current state so the UI reflects ready/processing/errored
    /// without making the pastor start a new upload.
    @MainActor
    private func refreshStatusFromServer() async {
        guard let vid = videoId else {
            stage = .idle
            return
        }
        do {
            if let row = try await service.fetchPlanVideo(id: vid) {
                muxStatus = row.status
                muxPlaybackId = row.muxPlaybackId
                switch row.status {
                case "ready":
                    if url.isEmpty, let pid = row.muxPlaybackId {
                        url = "https://stream.mux.com/\(pid).m3u8"
                    }
                    if let dur = row.durationSec, !includeDuration {
                        durationSeconds = Int(dur.rounded())
                        includeDuration = true
                    }
                    stage = .ready
                case "errored":
                    stage = .errored
                case "uploading":
                    // No active task on our side — treat as processing
                    // so the user sees a spinner rather than a CTA.
                    stage = .processing
                    pollTask = Task { await pollForReady(videoId: vid) }
                default:
                    stage = .processing
                    pollTask = Task { await pollForReady(videoId: vid) }
                }
            } else {
                stage = .idle
            }
        } catch {
            stage = .idle
        }
    }

    /// Drop the PhotosPickerItem onto disk so URLSession can stream it
    /// out via `upload(for:fromFile:)`. We prefer the movie
    /// `Transferable` form (gives us a stable URL); fall back to
    /// raw Data → temp file when it isn't available.
    private func materializeToTempFile(item: PhotosPickerItem) async throws -> URL? {
        if let movie = try await item.loadTransferable(type: PickedPlanVideo.self) {
            return movie.url
        }
        if let data = try await item.loadTransferable(type: Data.self) {
            let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("plan-video-\(UUID().uuidString).mov")
            try data.write(to: tmp)
            return tmp
        }
        return nil
    }
}

/// PhotosPicker movie Transferable wrapper — copies the picked file
/// into the temp directory so we have a stable URL after the picker's
/// short-lived security-scoped URL goes away.
private struct PickedPlanVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("plan-video-\(UUID().uuidString).mov")
            if FileManager.default.fileExists(atPath: copy.path) {
                try FileManager.default.removeItem(at: copy)
            }
            try FileManager.default.copyItem(at: received.file, to: copy)
            return PickedPlanVideo(url: copy)
        }
    }
}

// MARK: - In-app camera video recorder

/// Wraps `UIImagePickerController` in `.camera` + movie mode so the
/// pastor can record a video without leaving the app. Returns the
/// captured file's local URL (already copied into our temp dir so
/// iOS doesn't reclaim it before we upload).
private struct CameraVideoRecorder: UIViewControllerRepresentable {
    enum Result {
        case recorded(URL)
        case cancelled
        case failed(String)
    }

    let onComplete: (Result) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        // If the device doesn't have a camera (simulator, etc.) we
        // can't avoid the crash UIImagePickerController would throw,
        // so we degrade gracefully by reporting a friendly error and
        // dismissing in `viewDidAppear`.
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.mediaTypes = ["public.movie"]
            picker.cameraCaptureMode = .video
            picker.videoQuality = .typeHigh
            picker.allowsEditing = false
        } else {
            picker.sourceType = .photoLibrary
            picker.mediaTypes = ["public.movie"]
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onComplete: (Result) -> Void
        init(onComplete: @escaping (Result) -> Void) { self.onComplete = onComplete }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // UIImagePickerController hands us a URL inside its own
            // sandbox — copy it into our tempDir so the file survives
            // after the controller dismisses.
            guard let pickedURL = info[.mediaURL] as? URL else {
                onComplete(.failed("No video file was returned by the camera."))
                return
            }
            let dest = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("recorded-\(UUID().uuidString).mov")
            do {
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.copyItem(at: pickedURL, to: dest)
                onComplete(.recorded(dest))
            } catch {
                onComplete(.failed("Couldn't save the recording: \(error.localizedDescription)"))
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onComplete(.cancelled)
        }
    }
}
