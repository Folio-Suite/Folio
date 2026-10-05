// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit

/// Loads the Source Library window from ResearchKit's storyboard.
@MainActor
public enum ResearchLibraryWindow {
    /// Instantiates a new window controller from the Kit’s `Library` storyboard.
    ///
    /// Call on the main actor. The host must retain the result or attach it with
    /// `NSDocument.addWindowController(_:)`, then arrange to show its window.
    /// This method neither opens a package nor creates a document.
    ///
    /// - Returns: The unshown Source Library shell window controller.
    /// - Precondition: The bundled document-window scene exists with its expected class.
    public static func makeWindowController() -> NSWindowController {
        // NSApplication loads the app’s Main storyboard automatically. A framework
        // storyboard is a separate resource: select the owning Kit bundle explicitly.
        let storyboard = NSStoryboard(name: "Library", bundle: Bundle(for: LibraryViewController.self))
        guard let controller = storyboard.instantiateController(withIdentifier: "Document Window Controller")
            as? NSWindowController else {
            preconditionFailure("ResearchKit Library window scene is missing")
        }
        return controller
    }
}
