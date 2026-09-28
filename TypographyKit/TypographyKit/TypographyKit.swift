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

public enum CompositionStatus: String { case complete, unsupported, infeasible }
public enum DiagnosticCode: String {
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
    fileprivate let drawing: [[DrawingRun]]
    fileprivate init(status: CompositionStatus, originalText: String, lines: [ComposedLine],
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

fileprivate struct DrawingRun {
    let font: CTFont
    let glyphs: [CGGlyph]
    let positions: [CGPoint]
}
private struct SourceUnit {
    let occurrenceIndex: Int
    let sourceID: String
    let localOffset: Int
}

/// Synchronous realization of an exact line sequence with Core Text.
public enum TypographyComposer {
    public static func compose(_ request: CompositionRequest) -> CompositionResult {
        let source = request.occurrences.map(\.text).joined()
        let count = (source as NSString).length
        let provenance = CompositionProvenance(engine: "Core Text", operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
                                               requestedFont: request.fontPostScriptName, actualFonts: [],
                                               requestedFontVersion: nil, actualFontVersions: [:])
        func failure(_ status: CompositionStatus, _ code: DiagnosticCode, _ message: String, _ offset: Int? = nil) -> CompositionResult {
            CompositionResult(status: status, originalText: source, lines: [],
                              diagnostics: [CompositionDiagnostic(code: code, message: message, sourceUTF16Offset: offset)],
                              provenance: provenance, drawing: [])
        }
        guard count > 0, request.fontSize.isFinite, request.fontSize > 0,
              request.lineWidth.isFinite, request.lineWidth > 0,
              request.lineHeight.isFinite, request.lineHeight > 0 else {
            return failure(.unsupported, .invalidInput, "Text, font size, width, and line height must be positive.")
        }
        guard request.script == "Latn", request.direction == "ltr", !request.language.isEmpty else {
            return failure(.unsupported, .unsupportedScript, "Only explicit left-to-right Latin input is supported.")
        }
        guard source.unicodeScalars.allSatisfy({ scalar in
            let value = scalar.value
            return (0x20...0x024F).contains(value) || (0x0300...0x036F).contains(value) ||
                   (0x1E00...0x1EFF).contains(value) || (0x2000...0x206F).contains(value)
        }) else {
            return failure(.unsupported, .unsupportedScript, "Input contains a script or control outside the supported Latin subset.")
        }
        let controls = request.adjustments
        guard controls.tracking.isFinite, controls.spaceAdjustment.isFinite,
              controls.horizontalExpansion.isFinite, controls.leadingProtrusion.isFinite,
              controls.expansionLimits.lowerBound.isFinite, controls.expansionLimits.upperBound.isFinite,
              controls.expansionLimits.lowerBound > 0,
              controls.expansionLimits.contains(controls.horizontalExpansion),
              controls.leadingProtrusion >= 0, controls.spaceAdjustment >= 0 else {
            return failure(.unsupported, .unsupportedControl, "Invalid spacing, expansion, or protrusion policy.")
        }
        guard request.breaks.last == count,
              zip([0] + request.breaks.dropLast(), request.breaks).allSatisfy({ $0 < $1 }),
              request.breaks.allSatisfy({ $0 > 0 && $0 <= count }) else {
            return failure(.infeasible, .constraintViolation, "Selected breaks must cover the source exactly.")
        }
        let selected = Set(request.breaks)
        guard request.requiredBreaks.isSubset(of: selected), selected.isDisjoint(with: request.forbiddenBreaks) else {
            return failure(.infeasible, .constraintViolation, "Required or forbidden break constraint failed.")
        }
        var legal = Set<Int>([0, count])
        for index in source.indices { legal.insert((source[..<index] as NSString).length) }
        var occurrenceEnd = 0
        for occurrence in request.occurrences {
            occurrenceEnd += (occurrence.text as NSString).length
            guard legal.contains(occurrenceEnd) else {
                return failure(.unsupported, .invalidBoundary, "An occurrence boundary divides a grapheme cluster.", occurrenceEnd)
            }
        }
        for boundary in selected.union(request.requiredBreaks).union(request.forbiddenBreaks) where !legal.contains(boundary) {
            return failure(.unsupported, .invalidBoundary, "Boundary divides a grapheme cluster.", boundary)
        }
        var discByBoundary: [Int: Discretionary] = [:]
        var lastEnd = 0
        for disc in request.discretionaries.sorted(by: { $0.boundary < $1.boundary }) {
            let range = disc.replacementRange
            guard disc.boundary > 0, disc.boundary < count, legal.contains(disc.boundary),
                  range.location >= lastEnd, range.length >= 0, range.length <= disc.boundary,
                  range.location == disc.boundary - range.length, legal.contains(range.location),
                  discByBoundary[disc.boundary] == nil else {
                return failure(.unsupported, .invalidBoundary, "Invalid or overlapping discretionary range.", disc.boundary)
            }
            lastEnd = disc.boundary
            discByBoundary[disc.boundary] = disc
        }
        let baseFont = CTFontCreateWithName(request.fontPostScriptName as CFString, request.fontSize, nil)
        let resolved = CTFontCopyPostScriptName(baseFont) as String
        guard resolved.caseInsensitiveCompare(request.fontPostScriptName) == .orderedSame else {
            return failure(.unsupported, .fontUnavailable, "Requested PostScript font was not resolved.")
        }
        // A grapheme boundary can still divide a shaping cluster (for example a
        // ligature). Reject such supplied positions before shaping separate lines.
        let sourceAttributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key(kCTFontAttributeName as String): baseFont,
                                                                NSAttributedString.Key(kCTLanguageAttributeName as String): request.language]
        let sourceLine = CTLineCreateWithAttributedString(NSAttributedString(string: source, attributes: sourceAttributes))
        var clusterStarts = Set<Int>([0, count])
        for run in CTLineGetGlyphRuns(sourceLine) as! [CTRun] {
            let glyphCount = CTRunGetGlyphCount(run)
            guard glyphCount > 0 else { continue }
            var indices = Array(repeating: CFIndex(), count: glyphCount)
            CTRunGetStringIndices(run, CFRange(location: 0, length: glyphCount), &indices)
            clusterStarts.formUnion(indices.filter { $0 >= 0 && $0 <= count })
        }
        for boundary in selected.union(request.requiredBreaks).union(request.forbiddenBreaks) where !clusterStarts.contains(boundary) {
            return failure(.unsupported, .invalidBoundary, "Boundary divides a shaping cluster.", boundary)
        }
        for disc in request.discretionaries where !clusterStarts.contains(disc.boundary) || !clusterStarts.contains(disc.replacementRange.location) {
            return failure(.unsupported, .invalidBoundary, "Discretionary divides a shaping cluster.", disc.boundary)
        }
        var transform = CGAffineTransform(scaleX: controls.horizontalExpansion, y: 1)
        let font = CTFontCreateCopyWithAttributes(baseFont, request.fontSize, &transform, nil)
        var sourceUnits: [SourceUnit] = []
        for (index, occurrence) in request.occurrences.enumerated() {
            for offset in 0..<(occurrence.text as NSString).length {
                sourceUnits.append(SourceUnit(occurrenceIndex: index, sourceID: occurrence.sourceID, localOffset: offset))
            }
        }
        for disc in request.discretionaries where disc.replacementRange.length > 0 {
            guard sourceUnits[disc.replacementRange.location].occurrenceIndex ==
                    sourceUnits[disc.boundary - 1].occurrenceIndex else {
                return failure(.unsupported, .unsupportedControl, "A discretionary cannot replace across occurrences.", disc.boundary)
            }
        }
        var lines: [ComposedLine] = []
        var drawings: [[DrawingRun]] = []
        var diagnostics: [CompositionDiagnostic] = []
        var actualFonts = Set<String>()
        var actualFontVersions: [String: String] = [:]
        var appliedProtrusion = false
        let nsSource = source as NSString
        var start = 0
        for (lineNumber, end) in request.breaks.enumerated() {
            var rendered = ""
            var mappings: [SourceMapping] = []
            func append(_ text: String, sourceRange: NSRange, kind: MappingKind, anchor: Int) {
                let renderedStart = (rendered as NSString).length
                rendered += text
                if kind == .source {
                    var offset = sourceRange.location
                    while offset < sourceRange.location + sourceRange.length {
                        let identity = sourceUnits[offset]
                        var next = offset + 1
                        while next < sourceRange.location + sourceRange.length &&
                                sourceUnits[next].occurrenceIndex == identity.occurrenceIndex { next += 1 }
                        mappings.append(SourceMapping(occurrenceIndex: identity.occurrenceIndex, sourceID: identity.sourceID,
                                                      sourceRange: NSRange(location: identity.localOffset, length: next - offset),
                                                      renderedRange: NSRange(location: renderedStart + offset - sourceRange.location,
                                                                             length: next - offset), kind: .source))
                        offset = next
                    }
                    return
                }
                let identity = sourceUnits[min(anchor, count - 1)]
                let sourceIdentity = sourceUnits[min(sourceRange.location, count - 1)]
                mappings.append(SourceMapping(occurrenceIndex: kind == .inserted ? identity.occurrenceIndex : sourceIdentity.occurrenceIndex,
                                              sourceID: kind == .inserted ? identity.sourceID : sourceIdentity.sourceID,
                                              sourceRange: NSRange(location: kind == .inserted ? identity.localOffset : sourceIdentity.localOffset,
                                                                   length: sourceRange.length),
                                              renderedRange: NSRange(location: renderedStart, length: (text as NSString).length), kind: kind))
            }
            if let previous = discByBoundary[start], selected.contains(start), !previous.afterBreak.isEmpty {
                append(previous.afterBreak, sourceRange: NSRange(location: start, length: 0), kind: .inserted, anchor: start)
            }
            var cursor = start
            for disc in request.discretionaries.filter({ $0.boundary > start && $0.boundary <= end }).sorted(by: { $0.boundary < $1.boundary }) {
                let range = disc.replacementRange
                guard range.location >= cursor else {
                    return failure(.unsupported, .unsupportedControl, "Discretionary crosses a line boundary.", disc.boundary)
                }
                if cursor < range.location {
                    let plain = NSRange(location: cursor, length: range.location - cursor)
                    append(nsSource.substring(with: plain), sourceRange: plain, kind: .source, anchor: cursor)
                }
                let material = selected.contains(disc.boundary) ? disc.beforeBreak : disc.noBreak
                let kind: MappingKind = range.length == 0 ? .inserted : (material.isEmpty ? .omitted : .substituted)
                append(material, sourceRange: range, kind: kind, anchor: selected.contains(disc.boundary) ? disc.boundary - 1 : disc.boundary)
                cursor = disc.boundary
            }
            if cursor < end {
                let plain = NSRange(location: cursor, length: end - cursor)
                append(nsSource.substring(with: plain), sourceRange: plain, kind: .source, anchor: cursor)
            }
            guard !rendered.isEmpty else {
                return failure(.unsupported, .unsupportedControl, "Empty rendered lines are unsupported.", start)
            }
            let protrusion = ["\u{201C}", "\u{2018}", "\"", "'"].contains(String(rendered.prefix(1)))
                ? controls.leadingProtrusion : 0
            if protrusion > 0 { appliedProtrusion = true }
            var attrs: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTLanguageAttributeName as String): request.language
            ]
            if controls.tracking != 0 {
                attrs[NSAttributedString.Key(kCTTrackingAttributeName as String)] = controls.tracking
            }
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: rendered, attributes: attrs))
            var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
            let natural = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
            let utf16 = Array(rendered.utf16)
            var shifts = Array(repeating: CGFloat.zero, count: utf16.count + 1)
            var shift: CGFloat = 0
            for offset in 0..<utf16.count {
                shifts[offset] = shift
                if utf16[offset] == 0x20 && offset < utf16.count - 1 { shift += controls.spaceAdjustment }
            }
            shifts[utf16.count] = shift
            var glyphInfo: [GlyphGeometry] = []
            var drawRuns: [DrawingRun] = []
            var measuredInk = CGRect.null
            for run in CTLineGetGlyphRuns(line) as! [CTRun] {
                let glyphCount = CTRunGetGlyphCount(run)
                guard glyphCount > 0 else { continue }
                let attributes = CTRunGetAttributes(run) as NSDictionary
                guard let fontValue = attributes[kCTFontAttributeName] else { continue }
                let actualFont = fontValue as! CTFont
                let name = CTFontCopyPostScriptName(actualFont) as String
                actualFonts.insert(name)
                if let version = CTFontCopyName(actualFont, kCTFontVersionNameKey) as String? {
                    actualFontVersions[name] = version
                }
                var glyphs = Array(repeating: CGGlyph(), count: glyphCount)
                var positions = Array(repeating: CGPoint.zero, count: glyphCount)
                var indices = Array(repeating: CFIndex(), count: glyphCount)
                var advances = Array(repeating: CGSize.zero, count: glyphCount)
                CTRunGetGlyphs(run, CFRange(location: 0, length: glyphCount), &glyphs)
                CTRunGetPositions(run, CFRange(location: 0, length: glyphCount), &positions)
                CTRunGetStringIndices(run, CFRange(location: 0, length: glyphCount), &indices)
                CTRunGetAdvances(run, CFRange(location: 0, length: glyphCount), &advances)
                if glyphs.contains(0) {
                    diagnostics.append(CompositionDiagnostic(code: .fontUnavailable,
                                                             message: "A glyph is unavailable in the resolved font.", sourceUTF16Offset: start))
                }
                for i in 0..<glyphCount {
                    let offset = max(0, min(indices[i], utf16.count))
                    positions[i].x += shifts[offset]
                    if i == 0 && drawRuns.isEmpty { positions[i].x -= protrusion }
                    glyphInfo.append(GlyphGeometry(renderedUTF16Offset: offset, position: positions[i],
                                                   advance: advances[i].width, fontPostScriptName: name))
                    var glyph = glyphs[i]
                    let box = CTFontGetBoundingRectsForGlyphs(actualFont, .horizontal, &glyph, nil, 1)
                    measuredInk = measuredInk.union(box.offsetBy(dx: positions[i].x, dy: positions[i].y))
                }
                drawRuns.append(DrawingRun(font: actualFont, glyphs: glyphs, positions: positions))
            }
            let carets = (0...utf16.count).map { CTLineGetOffsetForStringIndex(line, $0, nil) + shifts[$0] }
            if protrusion > 0 && protrusion > (glyphInfo.first?.advance ?? 0) {
                return failure(.unsupported, .unsupportedControl, "Leading protrusion exceeds the opening glyph advance.", start)
            }
            let advance = natural + shift
            let ink = measuredInk.isNull ? .zero : measuredInk
            lines.append(ComposedLine(sourceRange: NSRange(location: start, length: end - start),
                                      renderedText: rendered, baseline: CGPoint(x: 0, y: -CGFloat(lineNumber) * request.lineHeight),
                                      advance: advance, ascent: ascent, descent: descent, inkBounds: ink,
                                      mappings: mappings, glyphs: glyphInfo, caretOffsets: carets))
            drawings.append(drawRuns)
            if advance - protrusion > request.lineWidth + 0.01 {
                diagnostics.append(CompositionDiagnostic(code: .overfullLine,
                                                         message: "Selected line exceeds available width.", sourceUTF16Offset: start))
            }
            if ascent + descent > request.lineHeight + 0.01 {
                diagnostics.append(CompositionDiagnostic(code: .constraintViolation,
                                                         message: "Line glyph height exceeds supplied line height.", sourceUTF16Offset: start))
            }
            start = end
        }
        if controls.leadingProtrusion > 0 && !appliedProtrusion {
            return failure(.unsupported, .unsupportedControl, "No supported leading quotation mark was available for protrusion.")
        }
        if !request.allowsFontFallback && actualFonts.contains(where: { $0.caseInsensitiveCompare(resolved) != .orderedSame }) {
            diagnostics.append(CompositionDiagnostic(code: .fontFallback,
                                                     message: "Core Text selected a fallback font.", sourceUTF16Offset: nil))
        }
        let finalProvenance = CompositionProvenance(engine: "Core Text", operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
                                                    requestedFont: request.fontPostScriptName, actualFonts: actualFonts.sorted(),
                                                    requestedFontVersion: CTFontCopyName(baseFont, kCTFontVersionNameKey) as String?,
                                                    actualFontVersions: actualFontVersions)
        return CompositionResult(status: diagnostics.isEmpty ? .complete : .infeasible,
                                 originalText: source, lines: lines, diagnostics: diagnostics,
                                 provenance: finalProvenance, drawing: drawings)
    }
}
