// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import ComposerKit
import XCTest

final class ComposerKitTests: XCTestCase {
    @MainActor
    func testPreviewWindowLoadsFromComposerKitAndDisplaysInput() throws {
        let input = PublicationPreviewInput(sourceIdentifier: "test-source", text: "Preview text",
            selectedBreaks: [12], lineWidth: 430)
        let controller = CompositionPreviewWindow.makeWindowController(input: input)
        XCTAssertNotNil(controller.window)
        let content = try XCTUnwrap(controller.contentViewController)
        XCTAssertEqual(NSStringFromClass(type(of: content)), "ComposerKit.CompositionPreviewViewController")
        let preview = try XCTUnwrap(content.view as? CompositionPreviewView)
        XCTAssertEqual(preview.result?.originalText, "Preview text")
    }

    func testPreviewRetainsPublicationSourceAndUsesSelectedLines() {
        let result = ComposerPreview.compose(PublicationPreviewInput(
            sourceIdentifier: "unit-1", text: "First lineSecond line", selectedBreaks: [10, 21], lineWidth: 400
        ))
        XCTAssertEqual(result.status, .complete)
        XCTAssertEqual(result.lines.map(\.renderedText), ["First line", "Second line"])
        XCTAssertEqual(Set(result.lines.flatMap(\.mappings).map(\.sourceID)), ["unit-1"])
        XCTAssertTrue(result.diagnostics.isEmpty)
    }

    func testPreviewDoesNotClaimImpossibleWidthIsComplete() {
        let result = ComposerPreview.compose(PublicationPreviewInput(
            sourceIdentifier: "unit-2", text: "Wide text", selectedBreaks: [9], lineWidth: 1
        ))
        XCTAssertEqual(result.status, .infeasible)
        XCTAssertFalse(result.diagnostics.isEmpty)
    }
}
