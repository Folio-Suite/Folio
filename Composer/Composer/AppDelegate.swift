// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import ComposerKit

// @main uses AppKit’s NSApplicationDelegate.main() implementation to enter
// NSApplicationMain. The app’s Main storyboard creates this delegate and wires
// it to NSApplication; these methods are callbacks from AppKit, not a startup loop.
@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // Composer currently hosts a preview, not an NSDocument. The app retains its
    // window controller itself; a document controller does not manage this window.
    private var previewWindow: NSWindowController?

    // AppKit has loaded the main interface and connected its outlets before this
    // callback. It is a safe place to configure those objects, not to wire them again.
    func applicationDidFinishLaunching(_ notification: Notification) {
        showPreview()
    }

    // AppKit sends a reopen request when the running app is opened again (for
    // example from the Dock). Reuse the retained preview when no window is visible.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { showPreview() }
        return true
    }

    private func showPreview() {
        if previewWindow == nil {
            let first = "Folio composes authored text."
            let second = "Source identity stays with the publication."
            let input = PublicationPreviewInput(sourceIdentifier: "composer-preview-specimen",
                text: first + second, selectedBreaks: [first.utf16.count, first.utf16.count + second.utf16.count],
                lineWidth: 430)
            previewWindow = CompositionPreviewWindow.makeWindowController(input: input)
        }
        previewWindow?.showWindow(nil)
    }

    // Opts into secure coding for AppKit’s restorable UI state. Document content
    // persistence remains the responsibility of the document/Kit save path.
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
