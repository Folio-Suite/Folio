// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

/// Synchronously realizes an exact line sequence using Core Text.
///
/// The composer owns no document, editor, break search, or graphics context.
/// Each invocation uses its own transient layout objects; it does not require
/// the main actor, schedule asynchronous work, or mutate the request.
public enum TypographyComposer {
    /// Validates a request and returns its realized geometry or rejection evidence.
    ///
    /// Font matching requires the requested PostScript name to resolve exactly
    /// (case-insensitively); allowing fallback only permits other fonts used for
    /// shaped glyph runs. The original source is shaped to validate boundaries
    /// before tracking, expansion, and discretionary material are applied to
    /// individual lines. No alternative break sequence or adjustment is attempted.
    ///
    /// - Parameter request: Immutable source, exact breaks, font environment,
    ///   dimensions, and fixed adjustment policy.
    /// - Returns: A retained result whose status and diagnostics must be inspected
    ///   before accepting its lines. The method does not throw. Unsupported inputs
    ///   and rejected break constraints return no lines; realized constraint
    ///   failures retain geometry for inspection and drawing.
    public static func compose(_ request: CompositionRequest) -> CompositionResult {
        CompositionEngine(request).compose()
    }
}
