//
//  BackyardGameView.swift
//  YGTeeV
//
//  Full-screen container for the Backyard web game (three.js — can't
//  render natively, hosted at backyard.ygteev.com). Session handoff:
//  we load the site with the current Supabase access + refresh tokens
//  in the URL hash — the web shell calls auth.setSession() then
//  scrubs the tokens from the address bar so nothing sensitive
//  survives in history.
//

import SwiftUI
import WebKit

struct BackyardGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var gameURL: URL?
    @State private var loadFailed = false

    private static let baseURL = "https://backyard.ygteev.com"

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(hex: "0A0712").ignoresSafeArea()

            if let url = gameURL {
                BackyardWebView(url: url, onLoadFailed: { loadFailed = true })
                    .ignoresSafeArea()
            } else if loadFailed {
                VStack(spacing: 12) {
                    Text("Couldn't load the Backyard")
                        .font(.lilitaOne(size: 20))
                        .foregroundStyle(.white)
                    Button("Try again") {
                        loadFailed = false
                        Task { await buildURL() }
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(YGColors.violet)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView().tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Close button — floats over the game, top-left.
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.45))
                    .clipShape(Circle())
            }
            .padding(.leading, 16)
            .padding(.top, 8)
        }
        .task { await buildURL() }
    }

    private func buildURL() async {
        // Pull the live session from supabase-swift. If the token is
        // near expiry the SDK refreshes it transparently.
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            var comps = URLComponents(string: Self.baseURL)!
            comps.fragment = "at=\(session.accessToken)&rt=\(session.refreshToken)"
            gameURL = comps.url
        } catch {
            // No session (shouldn't happen — game is behind auth) —
            // load bare; web shell will show its own sign-in.
            gameURL = URL(string: Self.baseURL)
        }
    }
}

private struct BackyardWebView: UIViewRepresentable {
    let url: URL
    let onLoadFailed: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onLoadFailed: onLoadFailed) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []   // game unlocks audio on its PLAY tap
        config.websiteDataStore = .default()                    // persist the web session between opens

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false              // the game is a fixed viewport
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.04, green: 0.03, blue: 0.07, alpha: 1)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onLoadFailed: () -> Void
        init(onLoadFailed: @escaping () -> Void) { self.onLoadFailed = onLoadFailed }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            onLoadFailed()
        }
    }
}
