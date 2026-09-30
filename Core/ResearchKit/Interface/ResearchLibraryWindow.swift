// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit

/// Loads the Source Library window from ResearchKit's storyboard.
@MainActor
public enum ResearchLibraryWindow {
    public static func makeWindowController() -> NSWindowController {
        let storyboard = NSStoryboard(name: "Library", bundle: Bundle(for: LibraryViewController.self))
        guard let controller = storyboard.instantiateController(withIdentifier: "Document Window Controller")
            as? NSWindowController else {
            preconditionFailure("ResearchKit Library window scene is missing")
        }
        return controller
    }
}
