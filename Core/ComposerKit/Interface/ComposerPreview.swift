// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import TypographyKit

/// A bounded publication input whose source belongs to its caller.
public struct PublicationPreviewInput {
    /// Opaque identity retained in the result’s source mappings.
    public let sourceIdentifier: String
    /// Original authored characters; the preview does not normalize or edit them.
    public let text: String
    /// Cumulative UTF-16 end offsets for the requested lines, not Swift character indices.
    /// The final offset must equal the text’s UTF-16 length; TypographyKit validates boundaries.
    public let selectedBreaks: [Int]
    /// Available typographic line width in points.
    public let lineWidth: CGFloat

    /// Stores a preview request without validating whether its breaks or width are feasible.
    /// Inspect the result of ``ComposerPreview/compose(_:)`` for validation diagnostics.
    public init(sourceIdentifier: String, text: String, selectedBreaks: [Int], lineWidth: CGFloat) {
        self.sourceIdentifier = sourceIdentifier
        self.text = text
        self.selectedBreaks = selectedBreaks
        self.lineWidth = lineWidth
    }
}

/// Adapts publication input without transferring Document ownership to TypographyKit.
public enum ComposerPreview {
    /// Synchronously composes the requested lines using the current preview typography.
    ///
    /// Uses Times-Roman at 20 points and a 28-point line height. Break selection belongs
    /// to the caller; this operation does not paginate, optimize breaks, or persist output.
    ///
    /// - Parameter input: Source text, source identity, UTF-16 line ends, and line width.
    /// - Returns: A TypographyKit result whose status and diagnostics must be inspected;
    ///   unsupported or infeasible input is reported in that result rather than thrown.
    public static func compose(_ input: PublicationPreviewInput) -> CompositionResult {
        TypographyComposer.compose(CompositionRequest(
            occurrences: [TextOccurrence(sourceID: input.sourceIdentifier, text: input.text)],
            fontPostScriptName: "Times-Roman", fontSize: 20,
            lineWidth: input.lineWidth, lineHeight: 28, breaks: input.selectedBreaks
        ))
    }
}
