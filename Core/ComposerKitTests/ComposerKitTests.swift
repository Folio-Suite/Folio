// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import ComposerKit
import XCTest

final class ComposerKitTests: XCTestCase {
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
