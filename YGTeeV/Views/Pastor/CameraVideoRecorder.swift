//
//  CameraVideoRecorder.swift
//  YGTeeV
//
//  Wraps `UIImagePickerController` in `.camera` + movie mode so the
//  pastor can record a video without leaving the app. Returns the
//  captured file's local URL (already copied into our temp dir so
//  iOS doesn't reclaim it before we upload).
//
//  Shared between the pastor's plan editor and the feed-post creator
//  so both flows hit the exact same Mux upload pipeline regardless of
//  whether the bytes came from the photo library or the camera.
//

import SwiftUI
import UIKit

struct CameraVideoRecorder: UIViewControllerRepresentable {
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
        // so we degrade gracefully by falling back to photo library.
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
