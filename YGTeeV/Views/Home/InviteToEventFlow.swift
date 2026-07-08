//
//  InviteToEventFlow.swift
//  YGTeeV
//
//  One-tap "Invite a friend" path for public events. Mirrors the
//  proven `InviteYouthPastorFlow` pattern: when SMS is available we
//  drop the user straight into `MFMessageComposeViewController` with
//  the invite body pre-filled and an empty recipient list (they pick
//  who to text inside Messages). When SMS isn't available callers
//  fall back to the existing `ActivityView` share sheet.
//
//  Single source of truth for the invite copy lives in
//  `InviteToEventCopy.body(…)` so the message body, any future
//  analytics description, and the share-sheet text never drift apart.
//

import SwiftUI
import UIKit
import MessageUI

/// Canonical SMS copy for a public-event invite. Format mirrors the
/// existing share-sheet text but tightens the wording for the
/// composer's narrower presentation context.
enum InviteToEventCopy {
    static func body(eventTitle: String, startsAt: Date, publicEventURL: URL) -> String {
        let df = DateFormatter(); df.dateFormat = "EEEE, MMM d"
        let tf = DateFormatter(); tf.dateFormat = "h:mm a"
        let when = "\(df.string(from: startsAt)) at \(tf.string(from: startsAt))"
        return "Hey, you should come to \(eventTitle) with me — \(when). RSVP here: \(publicEventURL.absoluteString)"
    }
}

/// SwiftUI host for `MFMessageComposeViewController`. Designed to be
/// mounted inside a `.sheet`; SwiftUI presents the returned composer
/// modally. Callers are expected to gate on
/// `MFMessageComposeViewController.canSendText()` BEFORE flipping the
/// sheet binding to true — the internal `canSendText` guard here is
/// belt-and-suspenders so the sheet doesn't leave an empty VC up if
/// something slips through.
struct InviteToEventMessageComposer: UIViewControllerRepresentable {
    let eventTitle: String
    let startsAt: Date
    let publicEventURL: URL
    /// Fired from the composer delegate so the parent can flip its
    /// `showMessageComposer` binding back to false.
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onDismiss: onDismiss) }

    func makeUIViewController(context: Context) -> UIViewController {
        guard MFMessageComposeViewController.canSendText() else {
            // Defer to the next runloop tick so SwiftUI has finished
            // mounting the sheet before we ask it to dismiss.
            DispatchQueue.main.async { onDismiss() }
            return UIViewController()
        }
        let composer = MFMessageComposeViewController()
        composer.recipients = []
        composer.body = InviteToEventCopy.body(
            eventTitle:     eventTitle,
            startsAt:       startsAt,
            publicEventURL: publicEventURL
        )
        composer.messageComposeDelegate = context.coordinator
        return composer
    }

    func updateUIViewController(_ ui: UIViewController, context: Context) {}

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onDismiss: () -> Void
        init(onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }

        func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                          didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true) { [onDismiss] in onDismiss() }
        }
    }
}
