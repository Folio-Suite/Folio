// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import Foundation
import XCTest
import TypographyKit

final class CompositionTests: XCTestCase {
    func testSelectedBreakAndDiscretionaryKeepOriginalAndMapEveryUnit() {
        let request = CompositionRequest(occurrences: [.init(sourceID: "passage", text: "extraordinary")],
            fontPostScriptName: "Times-Roman", fontSize: 12,
            lineWidth: 100, lineHeight: 16, breaks: [5, 13],
            discretionaries: [.init(boundary: 5, replacementRange: NSRange(location: 5, length: 0), beforeBreak: "-")])
        let result = TypographyComposer.compose(request)
        XCTAssertEqual(result.status, .complete)
        XCTAssertEqual(result.originalText, "extraordinary")
        XCTAssertEqual(result.lines.map(\.renderedText), ["extra-", "ordinary"])
        XCTAssertEqual(result.lines[0].mappings.reduce(0) { $0 + $1.sourceRange.length }, 5)
        XCTAssertEqual(result.lines[0].mappings.reduce(0) { $0 + $1.renderedRange.length }, 6)
        XCTAssertTrue(result.lines[0].mappings.contains { $0.kind == .inserted && $0.sourceRange.length == 0 })
    }

    func testInfeasibleBreakAndUnsupportedClusterStayExplicit() {
        let overfull = TypographyComposer.compose(.init(occurrences: [.init(sourceID: "a", text: "MMMMMMMM")],
            fontPostScriptName: "Times-Roman", fontSize: 12,
            lineWidth: 20, lineHeight: 16, breaks: [8]))
        XCTAssertEqual(overfull.status, .infeasible)
        XCTAssertEqual(overfull.lines.count, 1)
        XCTAssertTrue(overfull.diagnostics.contains { $0.code == .overfullLine })
        let invalid = TypographyComposer.compose(.init(occurrences: [.init(sourceID: "a", text: "a\u{301}b")],
            fontPostScriptName: "Times-Roman", fontSize: 12,
            lineWidth: 100, lineHeight: 16, breaks: [1, 3]))
        XCTAssertEqual(invalid.status, .unsupported)
        XCTAssertEqual(invalid.diagnostics.first?.code, .invalidBoundary)
    }

    func testControlsHaveMeasuredGeometry() {
        func compose(_ text: String, _ controls: CompositionAdjustments) -> CompositionResult {
            TypographyComposer.compose(.init(occurrences: [.init(sourceID: "a", text: text)],
                fontPostScriptName: "Times-Roman", fontSize: 12,
                lineWidth: 200, lineHeight: 16, breaks: [(text as NSString).length], adjustments: controls))
        }
        let base = compose("HHHH", .init())
        let tracked = compose("HHHH", .init(tracking: 0.5))
        XCTAssertEqual(tracked.lines[0].glyphs[3].position.x - base.lines[0].glyphs[3].position.x, 1.5, accuracy: 0.1)
        let plainQuote = compose("“Quoted words”", .init())
        let hungQuote = compose("“Quoted words”", .init(leadingProtrusion: 2.5))
        XCTAssertEqual(hungQuote.lines[0].glyphs[0].position.x - plainQuote.lines[0].glyphs[0].position.x, -2.5, accuracy: 0.01)
        XCTAssertEqual(hungQuote.lines[0].glyphs[1].position.x, plainQuote.lines[0].glyphs[1].position.x, accuracy: 0.01)
    }
}
