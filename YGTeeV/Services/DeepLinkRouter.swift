//
//  DeepLinkRouter.swift
//  YGTeeV
//
//  Single dispatcher for URLs that arrive from outside the app:
//    • `ygteev://` custom scheme (push payload `deep_link`, share
//      sheet, child-pairing QR, future Universal Links)
//
//  Phase 1 stub — logs the inbound URL. Phase 5 wires it up to the
//  AppState navigation (route into a specific event detail, group
//  thread, plan day, etc.).
//

import Foundation

@MainActor
final class DeepLinkRouter {
    static let shared = DeepLinkRouter()
    private init() {}

    func handle(_ url: URL) {
        #if DEBUG
        print("[deeplink] received:", url.absoluteString)
        #endif
        // TODO(phase 5): parse url.host / url.pathComponents and route
        // into the right tab + detail sheet.
    }
}
