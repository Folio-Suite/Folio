// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import ComposerKit

@MainActor
@objc(ViewController)
final class ViewController: NSViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        guard let preview = view as? CompositionPreviewView else { return }
        // A controlled specimen; Arrangement persistence is a separate capability.
        let first = "Folio composes authored text."
        let second = "Source identity stays with the publication."
        preview.show(PublicationPreviewInput(sourceIdentifier: "composer-preview-specimen",
            text: first + second, selectedBreaks: [first.utf16.count, first.utf16.count + second.utf16.count],
            lineWidth: 430))
    }
}
