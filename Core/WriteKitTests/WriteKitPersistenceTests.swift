// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import FolioKit
import Foundation
import WriteKit
import XCTest

@MainActor final class WriteKitPersistenceTests: XCTestCase {
    private func id(_ raw: String) throws -> FolioIdentifier { try FolioIdentifier(rawValue: raw) }

    private func sampleWork() throws -> Work {
        let work = Work()
        let runs = [
            TextRun(string: "Meaning & <words> 👑 ", emphasis: .emphasis),
            TextRun(string: "strong", emphasis: .strongEmphasis),
            TextRun(string: " bold italic  ", emphasis: .none,
                    presentation: TextPresentation(bold: true, italic: true))
        ]
        let paragraphs = [
            TextParagraph(identifier: try id("paragraph-one"), runs: runs, alignment: .center),
            TextParagraph(identifier: .make()), TextParagraph(identifier: .make())
        ]
        work.text = try TextUnit(identifier: work.text.identifier, title: work.text.title, paragraphs: paragraphs)
        return work
    }

    func testMixedScriptAuthoredTitleAndTextSurvivePackageRoundTrip() throws {
        let work = Work()
        let title = "العربية — 日本語 — Untitled"
        let text = "العربية English עברית 日本語 한글 e\u{0301} 👩🏽‍💻"
        let paragraph = TextParagraph(identifier: try id("mixed-script-paragraph"),
            runs: [TextRun(string: text, emphasis: .none)])
        work.text = try TextUnit(identifier: work.text.identifier, title: title, paragraphs: [paragraph])
        let loaded = try Work(fileWrapper: work.fileWrapper())
        XCTAssertEqual(loaded.text.title, title)
        XCTAssertEqual(loaded.text.string, text)
        XCTAssertEqual(loaded.text.paragraphs.first?.alignment, .natural)
    }

    func testNativePackageRoundTripPreservesMeaningAppearanceWhitespaceAndIdentity() throws {
        let work = try sampleWork()
        let package = try work.fileWrapper()
        XCTAssertEqual(Array(package.fileWrappers?.keys ?? Dictionary<String, FileWrapper>().keys), ["Work.sqlite"])
        let data = try XCTUnwrap(package.fileWrappers?["Work.sqlite"]?.regularFileContents)
        XCTAssertGreaterThan(data.count, 16)
        XCTAssertEqual(String(data: data.prefix(15), encoding: .ascii), "SQLite format 3")
        let loaded = try Work(fileWrapper: package)
        XCTAssertEqual(loaded.identifier, work.identifier)
        XCTAssertEqual(loaded.manuscriptIdentifier, work.manuscriptIdentifier)
        XCTAssertEqual(loaded.text.identifier, work.text.identifier)
        XCTAssertEqual(loaded.text.string, work.text.string)
        XCTAssertEqual(loaded.text.paragraphs.count, 3)
        XCTAssertEqual(loaded.text.paragraphs.map(\.identifier), work.text.paragraphs.map(\.identifier))
        let paragraph = try XCTUnwrap(loaded.text.paragraphs.first)
        XCTAssertEqual(paragraph.alignment, .center)
        XCTAssertEqual(paragraph.runs[0].emphasis, .emphasis)
        XCTAssertEqual(paragraph.runs[0].presentation, TextPresentation())
        XCTAssertEqual(paragraph.runs[1].emphasis, .strongEmphasis)
        XCTAssertEqual(paragraph.runs[2].emphasis, .none)
        XCTAssertEqual(paragraph.runs[2].presentation, TextPresentation(bold: true, italic: true))
    }

    func testNativeOrderedRelationshipsPreserveParagraphAndRunOrder() throws {
        var work = Work()
        let identifiers = ["z-last-alphabetically", "a-first-alphabetically", "m-middle"]
        let paragraphs = try identifiers.map { name in
            TextParagraph(identifier: try id(name), runs: [
                TextRun(string: "Z", emphasis: .emphasis),
                TextRun(string: "A", emphasis: .none, presentation: TextPresentation(bold: true)),
                TextRun(string: "M", emphasis: .strongEmphasis)
            ], alignment: .left)
        }
        work.text = try TextUnit(identifier: work.text.identifier, title: work.text.title, paragraphs: paragraphs)
        for _ in 0..<2 {
            let loaded = try Work(fileWrapper: work.fileWrapper())
            XCTAssertEqual(loaded.text.paragraphs.map(\.identifier), paragraphs.map(\.identifier))
            for paragraph in loaded.text.paragraphs {
                XCTAssertEqual(paragraph.runs.map(\.string), ["Z", "A", "M"])
                XCTAssertEqual(paragraph.runs[1].presentation, TextPresentation(bold: true))
            }
            work = loaded
        }
    }

    func testEmptyWorkCanBeSavedAndReopened() throws {
        let loaded = try Work(fileWrapper: Work().fileWrapper())
        XCTAssertEqual(loaded.text.string, "")
        XCTAssertEqual(loaded.text.paragraphs.count, 1)
    }

    func testUnknownPackageContentsAreRejectedWithoutChangingOriginal() throws {
        let package = try sampleWork().fileWrapper()
        let original = package.fileWrappers?["Work.sqlite"]?.regularFileContents
        package.addRegularFile(withContents: Data("future content".utf8), preferredFilename: "future.bin")
        XCTAssertThrowsError(try Work(fileWrapper: package))
        XCTAssertEqual(package.fileWrappers?["Work.sqlite"]?.regularFileContents, original)
        XCTAssertNotNil(package.fileWrappers?["future.bin"])
    }

    func testCorruptStoreIsRejected() {
        let package = FileWrapper(directoryWithFileWrappers: [
            "Work.sqlite": FileWrapper(regularFileWithContents: Data("not a database".utf8))
        ])
        XCTAssertThrowsError(try Work(fileWrapper: package))
    }

    func testDuplicateParagraphIdentityCannotBeSaved() throws {
        let work = try sampleWork()
        let paragraph = try XCTUnwrap(work.text.paragraphs.first)
        work.text = try TextUnit(identifier: work.text.identifier, title: work.text.title,
                                 paragraphs: [paragraph, paragraph])
        XCTAssertThrowsError(try work.fileWrapper())
    }

    func testBaselineWriterPackageReopensThroughPublicWorkAPI() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appendingPathComponent("tests/fixtures/swift-migration-baseline/Baseline.flwrbundle")
        let work = try Work(fileWrapper: FileWrapper(url: url))
        XCTAssertEqual(work.text.title, "Migration baseline")
        XCTAssertEqual(work.text.paragraphs.count, 2)
        XCTAssertEqual(work.text.paragraphs.map(\.alignment), [.left, .natural])
        XCTAssertEqual(work.text.paragraphs[0].runs[0].emphasis, .strongEmphasis)
        XCTAssertEqual(work.text.paragraphs[0].runs[0].presentation, TextPresentation(bold: true))
        XCTAssertTrue(work.text.formattingWarningDismissed)
        XCTAssertEqual(work.text.string,
            "Baseline Work fixture: authored words, Unicode café / 日本語, and paragraph order.\n" +
            "Second paragraph preserves a separate paragraph boundary.")
        let reopened = try Work(fileWrapper: work.fileWrapper())
        XCTAssertEqual(reopened.identifier, work.identifier)
        XCTAssertEqual(reopened.manuscript, work.manuscript)
    }
}
