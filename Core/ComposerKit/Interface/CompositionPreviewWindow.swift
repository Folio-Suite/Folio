// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit

/// Loads a composition preview window from ComposerKit's storyboard.
@MainActor
public enum CompositionPreviewWindow {
    public static func makeWindowController(input: PublicationPreviewInput) -> NSWindowController {
        let storyboard = NSStoryboard(name: "Preview", bundle: Bundle(for: CompositionPreviewViewController.self))
        guard let controller = storyboard.instantiateController(withIdentifier: "Document Window Controller")
            as? NSWindowController,
            let content = controller.contentViewController as? CompositionPreviewViewController else {
            preconditionFailure("ComposerKit Preview window scene is missing")
        }
        content.show(input)
        return controller
    }
}
