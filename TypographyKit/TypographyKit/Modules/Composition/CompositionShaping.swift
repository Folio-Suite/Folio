// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import CoreGraphics
import CoreText
import Foundation

private struct GlyphRunOutput {
    let drawing: DrawingRun
    let geometry: [GlyphGeometry]
    let inkBounds: CGRect
    let fontName: String
    let fontVersion: String?
    let missingGlyph: Bool
}

private struct LineMetrics {
    let advance: CGFloat
    let ascent: CGFloat
    let descent: CGFloat
    let protrusion: CGFloat
    let sourceOffset: Int
}

extension CompositionEngine {
    func shapeLine(_ rendered: RenderedLine, font: CTFont, lineNumber: Int) throws -> ShapedLine {
        let line = createLine(rendered.text, font: font)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let naturalAdvance = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
        let shifts = spaceShifts(in: rendered.text)
        let protrusion = leadingProtrusion(for: rendered.text)
        let runs = try shapeRuns(in: line, shifts: shifts, protrusion: protrusion)
        let glyphs = runs.flatMap(\.geometry)
        if protrusion > (glyphs.first?.advance ?? 0) {
            throw CompositionIssue(
                .unsupported, .unsupportedControl,
                "Leading protrusion exceeds the opening glyph advance.",
                offset: rendered.sourceRange.location
            )
        }
        let advance = naturalAdvance + shifts[shifts.count - 1]
        let caretOffsets = (0..<shifts.count).map {
            CTLineGetOffsetForStringIndex(line, $0, nil) + shifts[$0]
        }
        let geometry = ComposedLine(
            sourceRange: rendered.sourceRange,
            renderedText: rendered.text,
            baseline: CGPoint(x: 0, y: -CGFloat(lineNumber) * request.lineHeight),
            advance: advance,
            ascent: ascent,
            descent: descent,
            inkBounds: runs.reduce(CGRect.null) { $0.union($1.inkBounds) },
            mappings: rendered.mappings,
            glyphs: glyphs,
            caretOffsets: caretOffsets
        )
        return ShapedLine(
            geometry: geometry,
            drawing: runs.map(\.drawing),
            diagnostics: lineDiagnostics(runs: runs, metrics: LineMetrics(
                advance: advance,
                ascent: ascent,
                descent: descent,
                protrusion: protrusion,
                sourceOffset: rendered.sourceRange.location
            )),
            fontNames: Set(runs.map(\.fontName)),
            fontVersions: Dictionary(runs.compactMap { run in
                run.fontVersion.map { (run.fontName, $0) }
            }, uniquingKeysWith: { first, _ in first }),
            protruded: protrusion > 0
        )
    }

    private func createLine(_ text: String, font: CTFont) -> CTLine {
        var attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTLanguageAttributeName as String): request.language,
        ]
        if request.adjustments.tracking != 0 {
            attributes[NSAttributedString.Key(kCTTrackingAttributeName as String)] =
                request.adjustments.tracking
        }
        return CTLineCreateWithAttributedString(
            NSAttributedString(string: text, attributes: attributes)
        )
    }

    private func spaceShifts(in text: String) -> [CGFloat] {
        let units = Array(text.utf16)
        var shifts = Array(repeating: CGFloat.zero, count: units.count + 1)
        var accumulated: CGFloat = 0
        for offset in units.indices {
            shifts[offset] = accumulated
            if units[offset] == 0x20 && offset < units.count - 1 {
                accumulated += request.adjustments.spaceAdjustment
            }
        }
        shifts[units.count] = accumulated
        return shifts
    }

    private func leadingProtrusion(for text: String) -> CGFloat {
        let quote = String(text.prefix(1))
        return ["\u{201C}", "\u{2018}", "\"", "'"].contains(quote)
            ? request.adjustments.leadingProtrusion : 0
    }

    private func shapeRuns(in line: CTLine, shifts: [CGFloat], protrusion: CGFloat) throws -> [GlyphRunOutput] {
        var output: [GlyphRunOutput] = []
        for run in nativeRuns(in: line) where CTRunGetGlyphCount(run) > 0 {
            output.append(try shapeRun(run, shifts: shifts, protrusion: output.isEmpty ? protrusion : 0))
        }
        return output
    }

    private func shapeRun(_ run: CTRun, shifts: [CGFloat], protrusion: CGFloat) throws -> GlyphRunOutput {
        let attributes = CTRunGetAttributes(run)
        guard let pointer = CFDictionaryGetValue(
            attributes, Unmanaged.passUnretained(kCTFontAttributeName).toOpaque()
        ) else {
            throw CompositionIssue(.unsupported, .fontUnavailable, "Core Text run has no font.")
        }
        let actualFont = Unmanaged<CTFont>.fromOpaque(pointer).takeUnretainedValue()
        let name = CTFontCopyPostScriptName(actualFont) as String
        let count = CTRunGetGlyphCount(run)
        var glyphs = Array(repeating: CGGlyph(), count: count)
        var positions = Array(repeating: CGPoint.zero, count: count)
        var indices = Array(repeating: CFIndex(), count: count)
        var advances = Array(repeating: CGSize.zero, count: count)
        let range = CFRange(location: 0, length: count)
        CTRunGetGlyphs(run, range, &glyphs)
        CTRunGetPositions(run, range, &positions)
        CTRunGetStringIndices(run, range, &indices)
        CTRunGetAdvances(run, range, &advances)
        var geometry: [GlyphGeometry] = []
        var ink = CGRect.null
        for index in 0..<count {
            let offset = max(0, min(indices[index], shifts.count - 1))
            positions[index].x += shifts[offset]
            if index == 0 { positions[index].x -= protrusion }
            geometry.append(GlyphGeometry(
                renderedUTF16Offset: offset,
                position: positions[index],
                advance: advances[index].width,
                fontPostScriptName: name
            ))
            var glyph = glyphs[index]
            let box = CTFontGetBoundingRectsForGlyphs(actualFont, .horizontal, &glyph, nil, 1)
            ink = ink.union(box.offsetBy(dx: positions[index].x, dy: positions[index].y))
        }
        return GlyphRunOutput(
            drawing: DrawingRun(font: actualFont, glyphs: glyphs, positions: positions),
            geometry: geometry,
            inkBounds: ink,
            fontName: name,
            fontVersion: CTFontCopyName(actualFont, kCTFontVersionNameKey) as String?,
            missingGlyph: glyphs.contains(0)
        )
    }

    private func lineDiagnostics(runs: [GlyphRunOutput], metrics: LineMetrics) -> [CompositionDiagnostic] {
        var diagnostics: [CompositionDiagnostic] = []
        if runs.contains(where: \.missingGlyph) {
            diagnostics.append(CompositionDiagnostic(
                code: .fontUnavailable,
                message: "A glyph is unavailable in the resolved font.",
                sourceUTF16Offset: metrics.sourceOffset
            ))
        }
        if metrics.advance - metrics.protrusion > request.lineWidth + 0.01 {
            diagnostics.append(CompositionDiagnostic(
                code: .overfullLine,
                message: "Selected line exceeds available width.",
                sourceUTF16Offset: metrics.sourceOffset
            ))
        }
        if metrics.ascent + metrics.descent > request.lineHeight + 0.01 {
            diagnostics.append(CompositionDiagnostic(
                code: .constraintViolation,
                message: "Line glyph height exceeds supplied line height.",
                sourceUTF16Offset: metrics.sourceOffset
            ))
        }
        return diagnostics
    }
}
