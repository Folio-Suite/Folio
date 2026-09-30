// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import ComposerKit

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var previewWindow: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        showPreview()
    }

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

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
