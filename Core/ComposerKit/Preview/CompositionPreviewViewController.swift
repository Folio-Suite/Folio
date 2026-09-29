// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit

@MainActor
final class CompositionPreviewViewController: NSViewController {
    private var input: PublicationPreviewInput?

    func show(_ input: PublicationPreviewInput) {
        self.input = input
        if isViewLoaded { (view as? CompositionPreviewView)?.show(input) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if let input { (view as? CompositionPreviewView)?.show(input) }
    }
}
