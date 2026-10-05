// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import CoreGraphics
import CoreText
import Foundation

struct SourceUnit {
    let occurrenceIndex: Int
    let sourceID: String
    let localOffset: Int
}

struct CompositionIssue: Error {
    let status: CompositionStatus
    let code: DiagnosticCode
    let message: String
    let offset: Int?

    init(_ status: CompositionStatus, _ code: DiagnosticCode, _ message: String, offset: Int? = nil) {
        self.status = status
        self.code = code
        self.message = message
        self.offset = offset
    }
}

struct RenderedLine {
    let text: String
    let sourceRange: NSRange
    let mappings: [SourceMapping]
}

struct ShapedLine {
    let geometry: ComposedLine
    let drawing: [DrawingRun]
    let diagnostics: [CompositionDiagnostic]
    let fontNames: Set<String>
    let fontVersions: [String: String]
    let protruded: Bool
}

struct CompositionEngine {
    let request: CompositionRequest
    let source: String
    let sourceCount: Int
    let sourceUnits: [SourceUnit]
    let selected: Set<Int>

    init(_ request: CompositionRequest) {
        self.request = request
        source = request.occurrences.map(\.text).joined()
        // NSString and Core Text ranges count UTF-16 code units, whereas Swift
        // String iteration counts grapheme clusters. Keep this index space for
        // source bookkeeping so a combining sequence is not mistaken for one unit.
        sourceCount = (source as NSString).length
        selected = Set(request.breaks)
        sourceUnits = request.occurrences.enumerated().flatMap { index, occurrence in
            (0..<(occurrence.text as NSString).length).map {
                SourceUnit(occurrenceIndex: index, sourceID: occurrence.sourceID, localOffset: $0)
            }
        }
    }

    func compose() -> CompositionResult {
        do {
            try validateInput()
            let baseFont = try resolveFont()
            try validateShaping(with: baseFont)
            let font = expandedFont(from: baseFont)
            var assembled = CompositionAssembly()
            var start = 0
            for (lineNumber, end) in request.breaks.enumerated() {
                let rendered = try renderLine(from: start, to: end)
                let shaped = try shapeLine(rendered, font: font, lineNumber: lineNumber)
                assembled.append(shaped)
                start = end
            }
            try validateProtrusion(in: assembled)
            assembled.checkFallback(request: request, resolvedFontName: CTFontCopyPostScriptName(baseFont) as String)
            return assembled.result(originalText: source, request: request, baseFont: baseFont)
        } catch let issue as CompositionIssue {
            return failure(issue)
        } catch {
            return failure(CompositionIssue(.unsupported, .invalidInput, "Composition could not be realized."))
        }
    }

    func expandedFont(from font: CTFont) -> CTFont {
        // Put expansion in the font matrix before shaping. Scaling only drawing
        // would leave Core Text's reported advances and bounds at the old width.
        var transform = CGAffineTransform(scaleX: request.adjustments.horizontalExpansion, y: 1)
        return CTFontCreateCopyWithAttributes(font, request.fontSize, &transform, nil)
    }

    func failure(_ issue: CompositionIssue) -> CompositionResult {
        let provenance = CompositionProvenance(
            engine: "Core Text",
            operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
            requestedFont: request.fontPostScriptName,
            actualFonts: [],
            requestedFontVersion: nil,
            actualFontVersions: [:]
        )
        let diagnostic = CompositionDiagnostic(
            code: issue.code,
            message: issue.message,
            sourceUTF16Offset: issue.offset
        )
        return CompositionResult(
            status: issue.status,
            originalText: source,
            lines: [],
            diagnostics: [diagnostic],
            provenance: provenance,
            drawing: []
        )
    }

    func validateProtrusion(in assembled: CompositionAssembly) throws {
        if request.adjustments.leadingProtrusion > 0 && !assembled.protruded {
            throw CompositionIssue(
                .unsupported, .unsupportedControl,
                "No supported leading quotation mark was available for protrusion."
            )
        }
    }
}

struct CompositionAssembly {
    var lines: [ComposedLine] = []
    var drawings: [[DrawingRun]] = []
    var diagnostics: [CompositionDiagnostic] = []
    var fontNames: Set<String> = []
    var fontVersions: [String: String] = [:]
    var protruded = false

    mutating func append(_ shaped: ShapedLine) {
        lines.append(shaped.geometry)
        drawings.append(shaped.drawing)
        diagnostics.append(contentsOf: shaped.diagnostics)
        fontNames.formUnion(shaped.fontNames)
        fontVersions.merge(shaped.fontVersions) { _, new in new }
        protruded = protruded || shaped.protruded
    }

    mutating func checkFallback(request: CompositionRequest, resolvedFontName: String) {
        if !request.allowsFontFallback && fontNames.contains(where: {
            $0.caseInsensitiveCompare(resolvedFontName) != .orderedSame
        }) {
            diagnostics.append(CompositionDiagnostic(
                code: .fontFallback,
                message: "Core Text selected a fallback font.",
                sourceUTF16Offset: nil
            ))
        }
    }

    func result(originalText: String, request: CompositionRequest, baseFont: CTFont) -> CompositionResult {
        let provenance = CompositionProvenance(
            engine: "Core Text",
            operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
            requestedFont: request.fontPostScriptName,
            actualFonts: fontNames.sorted(),
            requestedFontVersion: CTFontCopyName(baseFont, kCTFontVersionNameKey) as String?,
            actualFontVersions: fontVersions
        )
        return CompositionResult(
            status: diagnostics.isEmpty ? .complete : .infeasible,
            originalText: originalText,
            lines: lines,
            diagnostics: diagnostics,
            provenance: provenance,
            drawing: drawings
        )
    }
}
