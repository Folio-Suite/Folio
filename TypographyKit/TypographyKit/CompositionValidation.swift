// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import CoreText
import Foundation

extension CompositionEngine {
    func validateInput() throws {
        try validateBasicInput()
        try validateBreakSequence()
        let legal = graphemeBoundaries()
        try validateOccurrenceBoundaries(in: legal)
        try validateSelectedBoundaries(in: legal)
        try validateDiscretionaries(in: legal)
    }

    private func validateBasicInput() throws {
        guard sourceCount > 0, request.fontSize.isFinite, request.fontSize > 0,
              request.lineWidth.isFinite, request.lineWidth > 0,
              request.lineHeight.isFinite, request.lineHeight > 0 else {
            throw CompositionIssue(
                .unsupported, .invalidInput,
                "Text, font size, width, and line height must be positive."
            )
        }
        guard request.script == "Latn", request.direction == "ltr", !request.language.isEmpty,
              source.unicodeScalars.allSatisfy(isSupportedScalar) else {
            throw CompositionIssue(
                .unsupported, .unsupportedScript,
                "Only explicit left-to-right Latin input is supported."
            )
        }
        let controls = request.adjustments
        guard controls.tracking.isFinite, controls.spaceAdjustment.isFinite,
              controls.horizontalExpansion.isFinite, controls.leadingProtrusion.isFinite,
              controls.expansionLimits.lowerBound.isFinite,
              controls.expansionLimits.upperBound.isFinite,
              controls.expansionLimits.lowerBound > 0,
              controls.expansionLimits.contains(controls.horizontalExpansion),
              controls.leadingProtrusion >= 0, controls.spaceAdjustment >= 0 else {
            throw CompositionIssue(
                .unsupported, .unsupportedControl,
                "Invalid spacing, expansion, or protrusion policy."
            )
        }
    }

    private func isSupportedScalar(_ scalar: Unicode.Scalar) -> Bool {
        let value = scalar.value
        return (0x20...0x024F).contains(value) ||
            (0x0300...0x036F).contains(value) ||
            (0x1E00...0x1EFF).contains(value) ||
            (0x2000...0x206F).contains(value)
    }

    private func validateBreakSequence() throws {
        guard request.breaks.last == sourceCount,
              zip([0] + request.breaks.dropLast(), request.breaks).allSatisfy({ $0 < $1 }),
              request.breaks.allSatisfy({ $0 > 0 && $0 <= sourceCount }) else {
            throw CompositionIssue(
                .infeasible, .constraintViolation,
                "Selected breaks must cover the source exactly."
            )
        }
        guard request.requiredBreaks.isSubset(of: selected),
              selected.isDisjoint(with: request.forbiddenBreaks) else {
            throw CompositionIssue(
                .infeasible, .constraintViolation,
                "Required or forbidden break constraint failed."
            )
        }
    }

    private func graphemeBoundaries() -> Set<Int> {
        var boundaries = Set<Int>([0, sourceCount])
        for index in source.indices {
            boundaries.insert((source[..<index] as NSString).length)
        }
        return boundaries
    }

    private func validateOccurrenceBoundaries(in legal: Set<Int>) throws {
        var end = 0
        for occurrence in request.occurrences {
            end += (occurrence.text as NSString).length
            if !legal.contains(end) {
                throw CompositionIssue(
                    .unsupported, .invalidBoundary,
                    "An occurrence boundary divides a grapheme cluster.", offset: end
                )
            }
        }
    }

    private func validateSelectedBoundaries(in legal: Set<Int>) throws {
        let boundaries = selected.union(request.requiredBreaks).union(request.forbiddenBreaks)
        for boundary in boundaries where !legal.contains(boundary) {
            throw CompositionIssue(
                .unsupported, .invalidBoundary,
                "Boundary divides a grapheme cluster.", offset: boundary
            )
        }
    }

    private func validateDiscretionaries(in legal: Set<Int>) throws {
        var previousEnd = 0
        var seen: Set<Int> = []
        for disc in request.discretionaries.sorted(by: { $0.boundary < $1.boundary }) {
            let range = disc.replacementRange
            guard disc.boundary > 0, disc.boundary < sourceCount,
                  legal.contains(disc.boundary), range.location >= previousEnd,
                  range.length >= 0, range.length <= disc.boundary,
                  range.location == disc.boundary - range.length,
                  legal.contains(range.location), seen.insert(disc.boundary).inserted else {
                throw CompositionIssue(
                    .unsupported, .invalidBoundary,
                    "Invalid or overlapping discretionary range.", offset: disc.boundary
                )
            }
            try validateReplacementOwnership(disc)
            previousEnd = disc.boundary
        }
    }

    private func validateReplacementOwnership(_ disc: Discretionary) throws {
        let range = disc.replacementRange
        if range.length > 0 &&
            sourceUnits[range.location].occurrenceIndex != sourceUnits[disc.boundary - 1].occurrenceIndex {
            throw CompositionIssue(
                .unsupported, .unsupportedControl,
                "A discretionary cannot replace across occurrences.", offset: disc.boundary
            )
        }
    }

    func resolveFont() throws -> CTFont {
        let font = CTFontCreateWithName(request.fontPostScriptName as CFString, request.fontSize, nil)
        let resolved = CTFontCopyPostScriptName(font) as String
        guard resolved.caseInsensitiveCompare(request.fontPostScriptName) == .orderedSame else {
            throw CompositionIssue(
                .unsupported, .fontUnavailable,
                "Requested PostScript font was not resolved."
            )
        }
        return font
    }

    func validateShaping(with font: CTFont) throws {
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTLanguageAttributeName as String): request.language,
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: source, attributes: attributes))
        var starts = Set<Int>([0, sourceCount])
        for run in nativeRuns(in: line) {
            let count = CTRunGetGlyphCount(run)
            guard count > 0 else { continue }
            var indices = Array(repeating: CFIndex(), count: count)
            CTRunGetStringIndices(run, CFRange(location: 0, length: count), &indices)
            starts.formUnion(indices.filter { $0 >= 0 && $0 <= sourceCount })
        }
        try validateShapingBoundaries(in: starts)
    }

    private func validateShapingBoundaries(in starts: Set<Int>) throws {
        let boundaries = selected.union(request.requiredBreaks).union(request.forbiddenBreaks)
        for boundary in boundaries where !starts.contains(boundary) {
            throw CompositionIssue(
                .unsupported, .invalidBoundary,
                "Boundary divides a shaping cluster.", offset: boundary
            )
        }
        for disc in request.discretionaries where
            !starts.contains(disc.boundary) || !starts.contains(disc.replacementRange.location) {
            throw CompositionIssue(
                .unsupported, .invalidBoundary,
                "Discretionary divides a shaping cluster.", offset: disc.boundary
            )
        }
    }
}

func nativeRuns(in line: CTLine) -> [CTRun] {
    let array = CTLineGetGlyphRuns(line)
    return (0..<CFArrayGetCount(array)).compactMap { index in
        guard let pointer = CFArrayGetValueAtIndex(array, index) else { return nil }
        return Unmanaged<CTRun>.fromOpaque(pointer).takeUnretainedValue()
    }
}
