// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import CoreGraphics
import CoreText
import Foundation

/// One immutable appearance of source text in a composition request.
///
/// IDs may repeat; mappings also include the zero-based occurrence index so two
/// appearances of the same source remain distinguishable. Text is concatenated
/// in request order without normalization. Occurrence joins must not divide an
/// extended grapheme cluster in the concatenated source.
public struct TextOccurrence {
    /// Host-defined identity carried into mappings; uniqueness is not required.
    public let sourceID: String
    /// Original Unicode text for this appearance, preserved without normalization.
    public let text: String
    /// Creates an appearance without checking its neighbors or supported scalar repertoire.
    ///
    /// - Parameters:
    ///   - sourceID: Host-defined identity; repeated IDs are allowed.
    ///   - text: Original text, including any combining characters.
    public init(sourceID: String, text: String) { self.sourceID = sourceID; self.text = text }
}

/// A caller-provided replacement at an interior source boundary.
///
/// A selected break uses `beforeBreak` on the preceding line and `afterBreak`
/// on the following line; an unselected boundary uses `noBreak`. The original
/// source is never mutated. The replacement range must end at `boundary`, stay
/// within one occurrence, and not overlap another replacement. Both range ends
/// must be legal grapheme and original-source shaping boundaries. A replacement
/// crossing a selected line start, or producing an empty rendered line, is
/// unsupported. Zero-length ranges insert material without consuming source.
public struct Discretionary {
    /// Interior UTF-16 offset in concatenated source at the end of the replacement range.
    public let boundary: Int
    /// Concatenated-source UTF-16 range consumed before the boundary; may be empty.
    public let replacementRange: NSRange
    /// Material appended to the line ending at a selected boundary.
    public let beforeBreak: String
    /// Material prepended to the next line when the boundary is selected.
    public let afterBreak: String
    /// Material used in place of the source range when the boundary is unselected.
    public let noBreak: String
    /// Describes replacement material without validating its range or resulting line text.
    ///
    /// - Parameters:
    ///   - boundary: Interior concatenated-source UTF-16 boundary.
    ///   - replacementRange: Source range ending at that boundary, within one occurrence.
    ///   - beforeBreak: Preceding-line material when this boundary is selected.
    ///   - afterBreak: Following-line material when selected; defaults to empty.
    ///   - noBreak: Replacement material when unselected; defaults to empty.
    public init(boundary: Int, replacementRange: NSRange,
                beforeBreak: String, afterBreak: String = "", noBreak: String = "") {
        self.boundary = boundary; self.replacementRange = replacementRange
        self.beforeBreak = beforeBreak; self.afterBreak = afterBreak; self.noBreak = noBreak
    }
}

/// Fixed controls applied when realizing the caller's selected lines.
///
/// Distances use points; expansion and its limits are dimensionless scale
/// factors. Every value must be finite. These controls do not search for a fit:
/// unsatisfied width or height constraints produce an infeasible result.
public struct CompositionAdjustments {
    /// Additional Core Text tracking in points per character cluster; zero is neutral.
    ///
    /// Nonzero tracking can suppress nonessential ligatures. Negative finite values
    /// are accepted, but the composer does not search for a fitting amount.
    public let tracking: CGFloat
    /// Nonnegative extra width in points after each rendered ASCII space except a final space.
    public let spaceAdjustment: CGFloat
    /// Horizontal font-matrix scale, which must lie in `expansionLimits`; 1 is neutral.
    public let horizontalExpansion: CGFloat
    /// Caller-specified finite positive scale bounds; the composer applies no automatic clamping.
    public let expansionLimits: ClosedRange<CGFloat>
    /// Nonnegative leftward shift in points of an opening quote glyph only.
    ///
    /// Supported opening characters are U+201C, U+2018, ASCII double quote, and
    /// ASCII apostrophe. The shift cannot exceed that glyph's advance, and a positive
    /// request must find at least one such line. Logical caret offsets do not move.
    public let leadingProtrusion: CGFloat
    /// Creates fixed controls; their bounds are checked during composition.
    ///
    /// - Parameters:
    ///   - tracking: Additional points per Core Text character cluster; defaults to zero.
    ///   - spaceAdjustment: Nonnegative extra points after nonfinal ASCII spaces.
    ///   - horizontalExpansion: Horizontal font scale; defaults to one.
    ///   - expansionLimits: Accepted positive scale interval; defaults to `1...1`.
    ///   - leadingProtrusion: Opening-quote shift in points; defaults to zero.
    public init(tracking: CGFloat = 0, spaceAdjustment: CGFloat = 0,
                horizontalExpansion: CGFloat = 1, expansionLimits: ClosedRange<CGFloat> = 1...1,
                leadingProtrusion: CGFloat = 0) {
        self.tracking = tracking; self.spaceAdjustment = spaceAdjustment
        self.horizontalExpansion = horizontalExpansion; self.expansionLimits = expansionLimits
        self.leadingProtrusion = leadingProtrusion
    }
}

/// An immutable request to realize an exact caller-selected line sequence.
///
/// Break offsets index UTF-16 in the concatenated original source, increase
/// strictly, and include its final offset. They are not Swift `String.Index`
/// values or character counts. The composer checks grapheme boundaries and
/// glyph string indices from shaping the original source with the requested
/// font; it does not generate line-break opportunities or choose new breaks.
///
/// The current source subset requires `script == "Latn"`, `direction == "ltr"`,
/// and a nonempty language. Accepted source scalars are U+0020–U+024F,
/// U+0300–U+036F, U+1E00–U+1EFF, and U+2000–U+206F. This bounds input validation;
/// it does not provide complex-script, bidirectional, or control-character
/// layout semantics. Source text must be nonempty, and font size, line width,
/// and line height must be finite and positive. Validation occurs in
/// ``TypographyComposer/compose(_:)``; constructing this value does not validate it.
public struct CompositionRequest {
    /// Source appearances concatenated in array order; mappings retain their indices.
    public let occurrences: [TextOccurrence]
    /// Installed or otherwise resolvable PostScript font name; best-match substitution is rejected.
    public let fontPostScriptName: String
    /// Finite positive font size in points.
    public let fontSize: CGFloat
    /// Whether shaped runs may use other fonts after the requested font resolves.
    ///
    /// False retains the shaped lines with an infeasible status when fallback occurs.
    /// True reports fallback fonts in provenance without making fallback alone a failure.
    public let allowsFontFallback: Bool
    /// Nonempty language hint passed to Core Text; no hyphenation dictionary is consulted.
    public let language: String
    /// Explicit script policy; the current implementation accepts only `"Latn"`.
    public let script: String
    /// Explicit direction policy; the current implementation accepts only `"ltr"`.
    public let direction: String
    /// Finite positive available width in points, checked against line advance less allowed protrusion.
    public let lineWidth: CGFloat
    /// Finite positive baseline spacing in points; ascent plus descent must also fit this height.
    public let lineHeight: CGFloat
    /// Strictly increasing positive concatenated-source UTF-16 ends, one per line, ending at source length.
    public let breaks: [Int]
    /// Source UTF-16 boundaries that must occur in `breaks`; all must be valid cluster boundaries.
    public let requiredBreaks: Set<Int>
    /// Source UTF-16 boundaries that must be absent from `breaks`; all must be valid cluster boundaries.
    public let forbiddenBreaks: Set<Int>
    /// Unique interior-boundary replacements; input order is irrelevant because boundaries are sorted.
    public let discretionaries: [Discretionary]
    /// Fixed geometry controls applied to every selected line.
    public let adjustments: CompositionAdjustments
    /// Captures a selected line sequence without performing composition or validation.
    ///
    /// - Parameters:
    ///   - occurrences: Ordered source appearances whose concatenation must be nonempty.
    ///   - fontPostScriptName: Requested font's resolvable PostScript name.
    ///   - fontSize: Positive finite size in points.
    ///   - allowsFontFallback: Permit other fonts in shaped runs; defaults to false.
    ///   - language: Nonempty Core Text language hint; defaults to `"en"`.
    ///   - script: Supported script policy, currently `"Latn"`.
    ///   - direction: Supported direction policy, currently `"ltr"`.
    ///   - lineWidth: Positive finite available width in points.
    ///   - lineHeight: Positive finite baseline spacing and height bound in points.
    ///   - breaks: Exact UTF-16 line ends, strictly increasing through the source length.
    ///   - requiredBreaks: Valid source boundaries that must be selected.
    ///   - forbiddenBreaks: Valid source boundaries that must remain unselected.
    ///   - discretionaries: Nonoverlapping interior-boundary replacements.
    ///   - adjustments: Fixed tracking, spacing, expansion, and protrusion policy.
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

/// Whether the exact requested composition is supported and satisfies its constraints.
public enum CompositionStatus: String, Sendable {
    /// All selected lines were realized without diagnostics.
    ///
    /// This establishes the supported geometry contract, not publication quality.
    case complete
    /// Input, font resolution, boundaries, or controls fall outside the supported subset.
    ///
    /// No lines or drawing resources are returned.
    case unsupported
    /// A selected break or geometry constraint could not be satisfied.
    ///
    /// Break-sequence rejection returns no lines. Overfull lines, insufficient
    /// line height, missing glyphs, and disallowed fallback retain inspectable lines.
    case infeasible
}
/// Structured reasons a request or its realized geometry could not be accepted.
///
/// Use these codes for host-localized explanations rather than parsing messages.
public enum DiagnosticCode: String, Sendable {
    /// Empty source or invalid font size, width, or line height.
    case invalidInput
    /// An occurrence, break, or discretionary boundary is invalid or divides a cluster.
    case invalidBoundary
    /// Source scalars, script, direction, or language do not meet the supported input policy.
    case unsupportedScript
    /// Adjustment or discretionary policy is outside the implemented subset.
    case unsupportedControl
    /// The requested font could not be resolved, a run lacks a font, or a glyph is missing.
    case fontUnavailable
    /// Core Text used another font while the request disallowed fallback.
    case fontFallback
    /// A realized line exceeds the supplied width after permitted protrusion.
    case overfullLine
    /// Selected breaks, required/forbidden breaks, or realized line height violate a constraint.
    case constraintViolation
}
/// An explanation attached to a result, optionally located in the original source.
///
/// These values are produced by the composer; callers cannot construct them
/// through a public initializer. Rejected requests carry one diagnostic;
/// realized lines may produce several.
public struct CompositionDiagnostic {
    /// Structured reason for rejection or a realized constraint failure.
    public let code: DiagnosticCode
    /// English developer explanation; hosts should localize using `code` instead of parsing this text.
    public let message: String
    /// Concatenated-original-source UTF-16 location when available; nil denotes an unlocated issue.
    public let sourceUTF16Offset: Int?
}
/// How a rendered fragment relates to its original occurrence.
public enum MappingKind: String {
    /// Unchanged source with equal source and rendered UTF-16 lengths.
    case source
    /// Material added at a source anchor, with a zero-length source range.
    case inserted
    /// Nonempty replacement material for a nonempty source range; lengths may differ.
    case substituted
    /// Source consumed without rendering material, with a zero-length rendered range.
    case omitted
}

/// A UTF-16 relationship between one original occurrence and one rendered line.
///
/// Source ranges are local to the specified occurrence; rendered ranges are
/// local to the line. Unchanged fragments are split at occurrence joins. A
/// replacement maps its whole source range to its whole rendered range, without
/// promising a per-character correspondence. Insertions use a zero-length
/// source anchor, so an anchor is not evidence that an original character was
/// consumed. These projections are produced by the composer.
public struct SourceMapping {
    /// Zero-based index into the request's occurrence array, distinguishing repeated source IDs.
    public let occurrenceIndex: Int
    /// Host-defined source identity copied from that occurrence.
    public let sourceID: String
    /// UTF-16 range local to the original occurrence; insertions have zero length.
    public let sourceRange: NSRange
    /// UTF-16 range local to the containing line's rendered text; omissions have zero length.
    public let renderedRange: NSRange
    /// Whether the fragment preserves, inserts, replaces, or omits source material.
    public let kind: MappingKind
}
/// One shaped glyph's position and originating rendered UTF-16 offset.
///
/// Glyphs are not characters: ligatures may cover several code units and
/// multiple glyphs may share an offset. Use ``ComposedLine/caretOffsets`` for
/// insertion geometry rather than inferring caret positions from advances.
public struct GlyphGeometry {
    /// Core Text glyph string index in the containing line's rendered text, not an original-source index.
    public let renderedUTF16Offset: Int
    /// Glyph origin in points relative to the line baseline, including space shifts and protrusion.
    public let position: CGPoint
    /// Core Text horizontal glyph advance in points; extra space shifts are represented in positions.
    public let advance: CGFloat
    /// Actual font used for this glyph, including fallback where applicable.
    public let fontPostScriptName: String
}
/// The rendered text, source relationships, and geometry of one selected line.
///
/// Geometry uses points in a Y-up coordinate system. Glyph positions and ink
/// bounds are local to the line's baseline origin; add `baseline` to place them
/// in result coordinates. The first baseline is at zero, and subsequent
/// baselines descend by the request's fixed line height. Width and height
/// violations remain available here with an infeasible result status.
public struct ComposedLine {
    /// Consumed UTF-16 range in concatenated original source, independent of replacement lengths.
    public let sourceRange: NSRange
    /// Exact text shaped for this line after discretionary insertion, omission, or substitution.
    public let renderedText: String
    /// Baseline origin in Y-up result coordinates; line n has y equal to `-n * lineHeight`.
    public let baseline: CGPoint
    /// Typographic line width in points including added spaces; leading protrusion is not subtracted.
    public let advance: CGFloat
    /// Core Text typographic distance above the baseline in points.
    public let ascent: CGFloat
    /// Core Text typographic distance below the baseline in points.
    public let descent: CGFloat
    /// Union of positioned glyph design bounds relative to the line baseline.
    ///
    /// These are font metrics, not rasterized pixel bounds, clipping bounds, or
    /// a typographic line rectangle. Protrusion and added-space positioning are included.
    public let inkBounds: CGRect
    /// Occurrence-aware relationships from original source fragments to rendered UTF-16 ranges.
    public let mappings: [SourceMapping]
    /// Shaped glyph projections in native run order, with actual-font and rendered-index information.
    public let glyphs: [GlyphGeometry]
    /// Primary Core Text caret x positions in points, indexed by rendered UTF-16 offset including the end.
    ///
    /// Added-space shifts are included; leading protrusion is excluded. Code-unit
    /// offsets inside grapheme or shaping clusters are not necessarily legal editing
    /// positions. The host must enforce its own selection and accessibility policy.
    public let caretOffsets: [CGFloat]
}
/// Engine and font environment observed during composition.
///
/// This describes the environment that produced the geometry; it is not a
/// portable reproduction guarantee. Fonts and OS shaping behavior may differ
/// on another machine. A request rejected before assembly has no actual fonts
/// or font-version records, even if font resolution had already succeeded.
public struct CompositionProvenance {
    /// Name of the shaping engine; currently `"Core Text"`.
    public let engine: String
    /// System-reported OS version description for the composition environment.
    public let operatingSystem: String
    /// PostScript font name supplied by the caller.
    public let requestedFont: String
    /// Sorted distinct PostScript names observed in shaped runs; empty for rejected requests.
    public let actualFonts: [String]
    /// Version name from the resolved requested font, when assembly succeeds and the font exposes one.
    public let requestedFontVersion: String?
    /// Font version names keyed by actual PostScript name; entries are absent when metadata is unavailable.
    public let actualFontVersions: [String: String]
}

/// Immutable composition evidence and the native resources used to draw it.
///
/// The result retains shaped glyph arrays, positions, and their actual Core Text
/// fonts, so later drawing does not reshape text or resolve fonts again. Keep
/// the result alive for drawing; it does not retain a caller's graphics context.
/// Public values are snapshots with no public result initializer. This type
/// has no `Sendable` conformance or actor isolation; hosts own concurrency and
/// graphics-context access.
public final class CompositionResult {
    /// Acceptance classification; inspect this before treating lines as satisfying the request.
    public let status: CompositionStatus
    /// All occurrence text concatenated without normalization or discretionary modifications.
    public let originalText: String
    /// Selected lines in source order; empty when composition rejects the request before returning geometry.
    public let lines: [ComposedLine]
    /// Structured rejection or constraint evidence; empty for a complete composition.
    public let diagnostics: [CompositionDiagnostic]
    /// Engine, operating-system, and font metadata associated with this attempt.
    public let provenance: CompositionProvenance
    private let drawing: [[DrawingRun]]
    init(status: CompositionStatus, originalText: String, lines: [ComposedLine],
         diagnostics: [CompositionDiagnostic], provenance: CompositionProvenance,
         drawing: [[DrawingRun]]) {
        self.status = status; self.originalText = originalText; self.lines = lines
        self.diagnostics = diagnostics; self.provenance = provenance; self.drawing = drawing
    }
    /// Draws the retained shaped glyphs using the supplied context's paint state.
    ///
    /// Positions use points in Y-up result coordinates, translated by `origin`.
    /// The context's current transform maps them into the destination; the host
    /// must arrange any flipped-view conversion. Drawing does not clip to the
    /// requested width, and it also draws inspectable infeasible lines. A result
    /// without lines draws nothing. No context is retained and no reshaping occurs.
    ///
    /// Core Text's `CTFontDrawGlyphs` changes the context's font, text size, and
    /// font-specified text matrix without restoring them. Save and restore the
    /// graphics state for the font and size; preserve and restore `textMatrix`
    /// separately, because it is outside the graphics-state stack.
    /// See [Apple's glyph drawing contract](https://developer.apple.com/documentation/coretext/ctfontdrawglyphs(_:_:_:_:_:)).
    /// The [text-matrix contract](https://developer.apple.com/documentation/coregraphics/cgcontextsettextmatrix)
    /// explains this separate restoration requirement.
    ///
    /// - Parameters:
    ///   - context: A caller-owned destination with the desired paint state and
    ///     coordinate transform. The caller must serialize access to it.
    ///   - origin: The destination position of the first line's baseline origin.
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
