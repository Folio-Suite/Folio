// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit

@MainActor
@objc(AppDelegate)
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
            previewWindow = NSStoryboard(name: "Main", bundle: nil)
                .instantiateController(withIdentifier: "Document Window Controller") as? NSWindowController
        }
        previewWindow?.showWindow(nil)
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
