// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit

/// Loads a composition preview window from ComposerKit's storyboard.
@MainActor
public enum CompositionPreviewWindow {
    /// Creates a preview window and supplies its initial input on the main actor.
    ///
    /// The host owns the returned controller and calls `showWindow(_:)` when ready.
    /// Each invocation creates a new controller; it is not attached to an `NSDocument`.
    ///
    /// - Parameter input: The source snapshot to display when the view loads.
    /// - Returns: A controller loaded from ComposerKit’s `Preview` storyboard.
    /// - Precondition: The bundled window and content-controller scenes have the expected classes.
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
