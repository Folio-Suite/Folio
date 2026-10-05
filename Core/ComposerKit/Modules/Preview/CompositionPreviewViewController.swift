// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit

@MainActor
final class CompositionPreviewViewController: NSViewController {
    // A storyboard controller can exist before its view does. Keep input until
    // viewDidLoad, then forward later updates immediately to the already loaded canvas.
    private var input: PublicationPreviewInput?

    func show(_ input: PublicationPreviewInput) {
        self.input = input
        if isViewLoaded { (view as? CompositionPreviewView)?.show(input) }
    }

    // AppKit calls this once the view hierarchy and its outlets have been loaded.
    // Merely instantiating the controller does not guarantee this callback has run.
    override func viewDidLoad() {
        super.viewDidLoad()
        if let input { (view as? CompositionPreviewView)?.show(input) }
    }
}
