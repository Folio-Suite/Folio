// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import TypographyKit

/// A bounded publication input whose source belongs to its caller.
public struct PublicationPreviewInput {
    public let sourceIdentifier: String
    public let text: String
    public let selectedBreaks: [Int]
    public let lineWidth: CGFloat

    public init(sourceIdentifier: String, text: String, selectedBreaks: [Int], lineWidth: CGFloat) {
        self.sourceIdentifier = sourceIdentifier
        self.text = text
        self.selectedBreaks = selectedBreaks
        self.lineWidth = lineWidth
    }
}

/// Adapts publication input without transferring Document ownership to TypographyKit.
public enum ComposerPreview {
    public static func compose(_ input: PublicationPreviewInput) -> CompositionResult {
        TypographyComposer.compose(CompositionRequest(
            occurrences: [TextOccurrence(sourceID: input.sourceIdentifier, text: input.text)],
            fontPostScriptName: "Times-Roman", fontSize: 20,
            lineWidth: input.lineWidth, lineHeight: 28, breaks: input.selectedBreaks
        ))
    }
}
