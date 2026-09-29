// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit

@MainActor
@objc(FCDocument)
final class ComposerDocument: NSDocument {
    override class var autosavesInPlace: Bool { true }

    override func makeWindowControllers() {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        guard let controller = storyboard.instantiateController(withIdentifier: "Document Window Controller") as? NSWindowController else {
            preconditionFailure("Composer document window scene is missing")
        }
        addWindowController(controller)
    }
}
