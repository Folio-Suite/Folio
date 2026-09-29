// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import WriteKit

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet private(set) var emphasisMenuItem: NSMenuItem!
    @IBOutlet private(set) var strongEmphasisMenuItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        emphasisMenuItem.image = FormattingImages.emphasis
        strongEmphasisMenuItem.image = FormattingImages.strongEmphasis
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
