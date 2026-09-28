// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import Foundation
import FolioKit
import XCTest

final class FolioValuesTests: XCTestCase {
    func testAuthoredSnapshotKeepsIdentityMeaningAndPresentationSeparate() throws {
        let unitID = try FolioIdentifier(rawValue: "unit-1")
        let paragraph = TextParagraph(
            identifier: try FolioIdentifier(rawValue: "paragraph-1"),
            runs: [TextRun(string: "Folio", emphasis: .emphasis,
                           presentation: TextPresentation(bold: true, underline: true))]
        )
        let unit = try TextUnit(identifier: unitID, title: "Chapter", paragraphs: [paragraph],
                                formattingWarningDismissed: true)
        let manuscript = try Manuscript(identifier: try FolioIdentifier(rawValue: "manuscript-1"), units: [unit])

        XCTAssertEqual(manuscript.units[0].identifier.rawValue, "unit-1")
        XCTAssertEqual(manuscript.units[0].string, "Folio")
        XCTAssertEqual(manuscript.units[0].paragraphs[0].runs[0].emphasis, .emphasis)
        XCTAssertTrue(manuscript.units[0].paragraphs[0].runs[0].presentation.bold)
        XCTAssertTrue(manuscript.units[0].formattingWarningDismissed)
    }

    func testInvalidIdentitiesAndManuscriptAreRejected() throws {
        XCTAssertThrowsError(try FolioIdentifier(rawValue: "")) { error in
            XCTAssertEqual(error as? FolioValueError, .emptyIdentifier)
        }
        let identifier = try FolioIdentifier(rawValue: "unit-1")
        let paragraph = TextParagraph(identifier: try FolioIdentifier(rawValue: "paragraph-1"))
        XCTAssertThrowsError(try TextUnit(identifier: identifier, title: "", paragraphs: [])) { error in
            XCTAssertEqual(error as? FolioValueError, .emptyParagraphs)
        }
        let unit = try TextUnit(identifier: identifier, title: "", paragraphs: [paragraph])
        XCTAssertThrowsError(try Manuscript(identifier: identifier, units: [unit, unit])) { error in
            XCTAssertEqual(error as? FolioValueError, .duplicateUnitIdentifier)
        }
    }

    func testSwiftStagingCleansNestedDirectoriesOnFailure() throws {
        struct ExpectedFailure: Error {}
        var directories: [URL] = []
        XCTAssertThrowsError(try PackageStaging.withTemporaryDirectory { outer in
            directories.append(outer)
            try PackageStaging.withTemporaryDirectory { inner in
                directories.append(inner)
                XCTAssertNotEqual(inner, outer)
                XCTAssertTrue(FileManager.default.fileExists(atPath: outer.path))
                throw ExpectedFailure()
            }
        })
        XCTAssertEqual(directories.count, 2)
        for directory in directories {
            XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
        }
    }
}
