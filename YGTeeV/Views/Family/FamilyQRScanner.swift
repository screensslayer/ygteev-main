//
//  FamilyQRScanner.swift
//  YGTeeV
//
//  AVFoundation-backed QR scanner. Wraps a single-shot capture session
//  in a UIViewControllerRepresentable. Only recognises payloads of the
//  form `ygteev://user/<uuid>` — anything else is ignored. Rejects the
//  current user's own QR so a parent can't self-invite.
//

import SwiftUI
import AVFoundation
import UIKit

struct FamilyQRScanner: View {
    /// Returns the scanned user_id (already validated to be a real UUID,
    /// and not the current user).
    let onScan: (UUID) -> Void
    let onCancel: () -> Void
    let currentUserId: UUID?

    @State private var permissionDenied = false
    @State private var ignoreSelfMessage = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if permissionDenied {
                permissionDeniedState
            } else {
                CameraView { payload in
                    guard let userId = parseUserId(from: payload) else { return }
                    if let me = currentUserId, me == userId {
                        // Avoid spam-toasting on every frame.
                        if !ignoreSelfMessage {
                            ignoreSelfMessage = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                ignoreSelfMessage = false
                            }
                        }
                        return
                    }
                    onScan(userId)
                }
                .ignoresSafeArea()
            }

            // Top bar
            VStack {
                HStack {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(.black.opacity(0.55))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)

                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Point your camera at their profile QR")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    if ignoreSelfMessage {
                        Text("That's your QR — scan someone else's")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(hex: "FFD60A"))
                            .padding(.top, 4)
                    }
                }
                .padding(.bottom, 80)
            }
        }
        .task { await ensureCameraAccess() }
    }

    // MARK: - Permission

    @MainActor
    private func ensureCameraAccess() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            permissionDenied = false
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            permissionDenied = !granted
        case .denied, .restricted:
            permissionDenied = true
        @unknown default:
            permissionDenied = true
        }
    }

    private var permissionDeniedState: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.85))
            Text("Camera access needed")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("Enable camera access in Settings to scan a profile QR.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(YGColors.ink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 6)
        }
    }

    // MARK: - Payload parsing

    private func parseUserId(from payload: String) -> UUID? {
        let prefix = "ygteev://user/"
        guard payload.hasPrefix(prefix) else { return nil }
        let raw = String(payload.dropFirst(prefix.count))
        return UUID(uuidString: raw)
    }
}

// MARK: - AVFoundation bridge

private struct CameraView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerVC {
        let vc = ScannerVC()
        vc.onScan = onScan
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerVC, context: Context) {}
}

private final class ScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var preview: AVCaptureVideoPreviewLayer?
    private var hasFired = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasFired = false
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.stopRunning()
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview?.frame = view.bounds
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        preview = layer
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !hasFired,
              let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              obj.type == .qr,
              let value = obj.stringValue else { return }
        hasFired = true
        onScan?(value)
    }
}
