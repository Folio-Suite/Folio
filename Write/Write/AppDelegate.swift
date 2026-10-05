// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import WriteKit

// @main uses AppKit’s NSApplicationDelegate.main() implementation to enter
// NSApplicationMain. The app’s Main storyboard creates this delegate and wires
// it to NSApplication; these methods are callbacks from AppKit, not a startup loop.
@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // File > New targets First Responder in Main.storyboard. AppKit’s shared
    // NSDocumentController handles newDocument: and reads NSDocumentClass in
    // Info.plist to create our document subclass. No delegate action is needed.
    // To change automatic untitled-document creation at launch, implement
    // applicationShouldOpenUntitledFile(_:); this is separate from the New action.
    @IBOutlet private(set) var emphasisMenuItem: NSMenuItem!
    @IBOutlet private(set) var strongEmphasisMenuItem: NSMenuItem!

    // AppKit has loaded the main interface and connected its outlets before this
    // callback. It is a safe place to configure those objects, not to wire them again.
    func applicationDidFinishLaunching(_ notification: Notification) {
        emphasisMenuItem.image = FormattingImages.emphasis
        strongEmphasisMenuItem.image = FormattingImages.strongEmphasis
    }

    // Opts into secure coding for AppKit’s restorable UI state. Document content
    // persistence remains the responsibility of the document/Kit save path.
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
