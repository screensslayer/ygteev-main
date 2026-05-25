//
//  ChildSignInSheet.swift
//  YGTeeV
//
//  Kid-side onboarding entry for managed under-13 accounts. Two paths:
//    • Camera QR scan → extracts the `token` from a
//      `ygteev://child-signin?token=...` payload.
//    • Manual numeric-code entry — fallback when the camera can't focus.
//
//  Both routes call `FamilyService.redeemChildPairing` which installs
//  the kid's session via `auth.setSession(...)`. The caller is
//  responsible for navigating into the main app (typically by flipping
//  the `hasCompletedOnboarding` flag in YGTeeVApp).
//

import SwiftUI
import AVFoundation
import UIKit

struct ChildSignInSheet: View {
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .scan
    @State private var code: String = ""
    @State private var isRedeeming = false
    @State private var error: String?
    @State private var permissionDenied = false

    enum Mode { case scan, code }

    var body: some View {
        ZStack {
            (mode == .scan ? Color.black : YGColors.paper).ignoresSafeArea()

            switch mode {
            case .scan: scanView
            case .code: codeView
            }
        }
        .task { await ensureCameraAccess() }
    }

    // MARK: - Scan path

    private var scanView: some View {
        ZStack {
            if !permissionDenied {
                ScannerBridge { payload in
                    if let token = Self.extractToken(from: payload) {
                        Task { await redeem(token: token, numericCode: nil) }
                    }
                }
                .ignoresSafeArea()
            } else {
                permissionDeniedState
            }

            VStack {
                HStack {
                    Button { dismiss() } label: {
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

                VStack(spacing: 12) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Ask your parent to open YGTeeV → Add Family Member → Create child account, then show you the QR.")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)

                    if isRedeeming {
                        ProgressView().tint(.white).padding(.top, 10)
                    }
                    if let error {
                        Text(error)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(hex: "FFD60A"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                            .padding(.top, 6)
                    }

                    Button { mode = .code } label: {
                        Text("Enter 8-digit code instead")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(.white.opacity(0.18))
                            .clipShape(Capsule())
                            .overlay {
                                Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.5)
                            }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                .padding(.bottom, 60)
            }
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
            Text("Enable camera access in Settings, or use the 8-digit code.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            HStack(spacing: 10) {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Open Settings")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(YGColors.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.white)
                        .clipShape(Capsule())
                }
                Button { mode = .code } label: {
                    Text("Use code instead")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.18))
                        .clipShape(Capsule())
                        .overlay { Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.5) }
                }
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Code path

    private var codeView: some View {
        VStack(spacing: 0) {
            HStack {
                Button { mode = .scan } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(YGColors.ink)
                        .frame(width: 32, height: 32)
                        .background(.white)
                        .clipShape(Circle())
                        .overlay { Circle().strokeBorder(.black.opacity(0.06), lineWidth: 0.5) }
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(YGColors.ink.opacity(0.6))
                        .frame(width: 30, height: 30)
                        .background(YGColors.ink.opacity(0.06))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)

            Spacer()

            VStack(spacing: 18) {
                Text("Enter your 8-digit code")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(YGColors.ink)
                Text("Your parent will read this off their screen.")
                    .font(.system(size: 13))
                    .foregroundStyle(YGColors.ink.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                TextField("12345678", text: $code)
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .tracking(4)
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .padding(.vertical, 18)
                    .padding(.horizontal, 24)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(YGColors.violet.opacity(0.2), lineWidth: 1.5) }
                    .onChange(of: code) { _, newValue in
                        code = String(newValue.filter(\.isNumber).prefix(8))
                    }
                    .padding(.horizontal, 22)

                if let error {
                    Text(error)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }

            Spacer()

            Button {
                Task { await redeem(token: nil, numericCode: code) }
            } label: {
                HStack {
                    if isRedeeming { ProgressView().tint(.white) }
                    Text("Sign in")
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
            }
            .buttonStyle(.plain)
            .disabled(isRedeeming || code.count != 8)
            .opacity(code.count == 8 && !isRedeeming ? 1 : 0.55)
            .padding(.horizontal, 16)
            .padding(.bottom, 22)
        }
    }

    // MARK: - Redeem

    @MainActor
    private func ensureCameraAccess() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized: permissionDenied = false
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            permissionDenied = !granted
        case .denied, .restricted: permissionDenied = true
        @unknown default: permissionDenied = true
        }
    }

    private func redeem(token: String?, numericCode: String?) async {
        guard !isRedeeming else { return }
        isRedeeming = true
        error = nil
        defer { isRedeeming = false }
        do {
            try await FamilyService.shared.redeemChildPairing(
                token: token,
                numericCode: numericCode
            )
            onComplete()
            dismiss()
        } catch {
            self.error = "Couldn't sign in: \(error.localizedDescription)"
        }
    }

    /// Accepts `ygteev://child-signin?token=<hex>` or a bare token string
    /// (just in case a kid scans a QR that's already been decoded).
    private static func extractToken(from payload: String) -> String? {
        let prefix = "ygteev://child-signin?token="
        if payload.hasPrefix(prefix) {
            let token = String(payload.dropFirst(prefix.count))
            return token.isEmpty ? nil : token
        }
        return nil
    }
}

// MARK: - AVFoundation bridge (single-shot QR)

private struct ScannerBridge: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    func makeUIViewController(context: Context) -> ChildScannerVC {
        let vc = ChildScannerVC()
        vc.onScan = onScan
        return vc
    }
    func updateUIViewController(_ uiViewController: ChildScannerVC, context: Context) {}
}

private final class ChildScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
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
