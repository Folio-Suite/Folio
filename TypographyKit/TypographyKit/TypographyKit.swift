// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import CoreGraphics
import CoreText
import Foundation

/// One immutable source occurrence. IDs may repeat; mappings also include occurrence index.
public struct TextOccurrence {
    public let sourceID: String
    public let text: String
    public init(sourceID: String, text: String) { self.sourceID = sourceID; self.text = text }
}

/// Material at a UTF-16 boundary. A selected break uses before/after material;
/// an unselected break uses noBreak material. The source range is replaced, never mutated.
public struct Discretionary {
    public let boundary: Int
    public let replacementRange: NSRange
    public let beforeBreak: String
    public let afterBreak: String
    public let noBreak: String
    public init(boundary: Int, replacementRange: NSRange,
                beforeBreak: String, afterBreak: String = "", noBreak: String = "") {
        self.boundary = boundary; self.replacementRange = replacementRange
        self.beforeBreak = beforeBreak; self.afterBreak = afterBreak; self.noBreak = noBreak
    }
}

/// Point-valued controls. Expansion is a horizontal font scale; 1 is neutral.
public struct CompositionAdjustments {
    public let tracking: CGFloat
    public let spaceAdjustment: CGFloat
    public let horizontalExpansion: CGFloat
    public let expansionLimits: ClosedRange<CGFloat>
    public let leadingProtrusion: CGFloat
    public init(tracking: CGFloat = 0, spaceAdjustment: CGFloat = 0,
                horizontalExpansion: CGFloat = 1, expansionLimits: ClosedRange<CGFloat> = 1...1,
                leadingProtrusion: CGFloat = 0) {
        self.tracking = tracking; self.spaceAdjustment = spaceAdjustment
        self.horizontalExpansion = horizontalExpansion; self.expansionLimits = expansionLimits
        self.leadingProtrusion = leadingProtrusion
    }
}

/// An exact caller-selected paragraph composition. Break offsets index UTF-16
/// in the concatenated source, increase strictly, and include its final offset.
public struct CompositionRequest {
    public let occurrences: [TextOccurrence]
    public let fontPostScriptName: String
    public let fontSize: CGFloat
    public let allowsFontFallback: Bool
    public let language: String
    public let script: String
    public let direction: String
    public let lineWidth: CGFloat
    public let lineHeight: CGFloat
    public let breaks: [Int]
    public let requiredBreaks: Set<Int>
    public let forbiddenBreaks: Set<Int>
    public let discretionaries: [Discretionary]
    public let adjustments: CompositionAdjustments
    public init(occurrences: [TextOccurrence], fontPostScriptName: String, fontSize: CGFloat,
                allowsFontFallback: Bool = false, language: String = "en", script: String = "Latn",
                direction: String = "ltr", lineWidth: CGFloat, lineHeight: CGFloat,
                breaks: [Int], requiredBreaks: Set<Int> = [], forbiddenBreaks: Set<Int> = [],
                discretionaries: [Discretionary] = [], adjustments: CompositionAdjustments = .init()) {
        self.occurrences = occurrences; self.fontPostScriptName = fontPostScriptName
        self.fontSize = fontSize; self.allowsFontFallback = allowsFontFallback
        self.language = language; self.script = script; self.direction = direction
        self.lineWidth = lineWidth; self.lineHeight = lineHeight; self.breaks = breaks
        self.requiredBreaks = requiredBreaks; self.forbiddenBreaks = forbiddenBreaks
        self.discretionaries = discretionaries; self.adjustments = adjustments
    }
}

public enum CompositionStatus: String, Sendable { case complete, unsupported, infeasible }
public enum DiagnosticCode: String, Sendable {
    case invalidInput, invalidBoundary, unsupportedScript, unsupportedControl
    case fontUnavailable, fontFallback, overfullLine, constraintViolation
}
public struct CompositionDiagnostic {
    public let code: DiagnosticCode
    public let message: String
    public let sourceUTF16Offset: Int?
}
public enum MappingKind: String { case source, inserted, substituted, omitted }

/// Source ranges are local to the specified occurrence; rendered ranges are local to the line.
public struct SourceMapping {
    public let occurrenceIndex: Int
    public let sourceID: String
    public let sourceRange: NSRange
    public let renderedRange: NSRange
    public let kind: MappingKind
}
public struct GlyphGeometry {
    public let renderedUTF16Offset: Int
    public let position: CGPoint
    public let advance: CGFloat
    public let fontPostScriptName: String
}
public struct ComposedLine {
    public let sourceRange: NSRange
    public let renderedText: String
    public let baseline: CGPoint
    public let advance: CGFloat
    public let ascent: CGFloat
    public let descent: CGFloat
    public let inkBounds: CGRect
    public let mappings: [SourceMapping]
    public let glyphs: [GlyphGeometry]
    /// Caret x positions indexed by rendered UTF-16 offset, including the final offset.
    public let caretOffsets: [CGFloat]
}
public struct CompositionProvenance {
    public let engine: String
    public let operatingSystem: String
    public let requestedFont: String
    public let actualFonts: [String]
    public let requestedFontVersion: String?
    public let actualFontVersions: [String: String]
}

/// Retains native glyph resources so drawing uses exactly the reported geometry.
public final class CompositionResult {
    public let status: CompositionStatus
    public let originalText: String
    public let lines: [ComposedLine]
    public let diagnostics: [CompositionDiagnostic]
    public let provenance: CompositionProvenance
    private let drawing: [[DrawingRun]]
    init(status: CompositionStatus, originalText: String, lines: [ComposedLine],
         diagnostics: [CompositionDiagnostic], provenance: CompositionProvenance,
         drawing: [[DrawingRun]]) {
        self.status = status; self.originalText = originalText; self.lines = lines
        self.diagnostics = diagnostics; self.provenance = provenance; self.drawing = drawing
    }
    /// Draw in an owned Core Graphics context, using the supplied context's paint state.
    public func draw(in context: CGContext, at origin: CGPoint = .zero) {
        for (lineNumber, runs) in drawing.enumerated() {
            for run in runs {
                var positions = run.positions.map {
                    CGPoint(x: $0.x + origin.x + lines[lineNumber].baseline.x,
                            y: $0.y + origin.y + lines[lineNumber].baseline.y)
                }
                var glyphs = run.glyphs
                CTFontDrawGlyphs(run.font, &glyphs, &positions, glyphs.count, context)
            }
        }
    }
}

struct DrawingRun {
    let font: CTFont
    let glyphs: [CGGlyph]
    let positions: [CGPoint]
}

/// Synchronous realization of an exact line sequence with Core Text.
public enum TypographyComposer {
    public static func compose(_ request: CompositionRequest) -> CompositionResult {
        CompositionEngine(request).compose()
    }
}
