// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import FolioKit
import Foundation
import SQLite3
import WriteKit
import XCTest

@MainActor final class WriteKitPersistenceTests: XCTestCase {
  func testMixedScriptAuthoredTitleAndTextSurvivePackageRoundTrip() throws {
    let work = Work()
    let title = "العربية — 日本語 — Untitled"
    let text = "العربية English עברית 日本語 한글 e\u{0301} 👩🏽‍💻"
    let paragraph = TextParagraph(
      identifier: try WorkPersistenceFixtures.id("mixed-script-paragraph"),
      runs: [TextRun(string: text, emphasis: .none)])
    work.text = try TextUnit(
      identifier: work.text.identifier, title: title, paragraphs: [paragraph])
    let loaded = try Work(fileWrapper: work.fileWrapper())
    XCTAssertEqual(loaded.text.title, title)
    XCTAssertEqual(loaded.text.string, text)
    XCTAssertEqual(loaded.text.paragraphs.first?.alignment, .natural)
  }

  func testNativePackageRoundTripPreservesMeaningAppearanceWhitespaceAndIdentity() throws {
    let work = try WorkPersistenceFixtures.sampleWork()
    let package = try work.fileWrapper()
    XCTAssertEqual(
      Set(package.fileWrappers?.keys ?? [String: FileWrapper]().keys),
      Set(["Work.sqlite", "Package.json", "Resources"]))
    let manifest = try XCTUnwrap(package.fileWrappers?["Package.json"]?.regularFileContents)
    let manifestText = try XCTUnwrap(String(bytes: manifest, encoding: .utf8))
    XCTAssertTrue(manifestText.contains("opaque-resources-v1"))
    XCTAssertTrue(try XCTUnwrap(package.fileWrappers?["Resources"]).fileWrappers?.isEmpty == true)
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
      TextParagraph(
        identifier: try WorkPersistenceFixtures.id(name),
        runs: [
          TextRun(string: "Z", emphasis: .emphasis),
          TextRun(string: "A", emphasis: .none, presentation: TextPresentation(bold: true)),
          TextRun(string: "M", emphasis: .strongEmphasis),
        ], alignment: .left)
    }
    work.text = try TextUnit(
      identifier: work.text.identifier, title: work.text.title, paragraphs: paragraphs)
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
    let package = try WorkPersistenceFixtures.sampleWork().fileWrapper()
    let original = package.fileWrappers?["Work.sqlite"]?.regularFileContents
    package.addRegularFile(
      withContents: Data("future content".utf8), preferredFilename: "future.bin")
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

  func testRequiredScalarCorruptionIsRejectedWithoutChangingOriginal() throws {
    let original = try WorkPersistenceFixtures.sampleWork().fileWrapper()
    let originalStore = try XCTUnwrap(original.fileWrappers?["Work.sqlite"]?.regularFileContents)
    let corrupted = try WorkPersistenceFixtures.package(
      original,
      updatingStore: "UPDATE ZRUN SET ZBOLD = NULL WHERE Z_PK = (SELECT MIN(Z_PK) FROM ZRUN)")
    XCTAssertThrowsError(try Work(fileWrapper: corrupted))
    XCTAssertEqual(original.fileWrappers?["Work.sqlite"]?.regularFileContents, originalStore)
    XCTAssertNoThrow(try Work(fileWrapper: original))
  }

  func testFractionalStoredEmphasisIsRejected() throws {
    let original = try WorkPersistenceFixtures.sampleWork().fileWrapper()
    let corrupted = try WorkPersistenceFixtures.package(
      original,
      updatingStore: "UPDATE ZRUN SET ZEMPHASIS = 1.5 WHERE Z_PK = (SELECT MIN(Z_PK) FROM ZRUN)")
    XCTAssertThrowsError(try Work(fileWrapper: corrupted))
    XCTAssertNoThrow(try Work(fileWrapper: original))
  }

  func testCorruptAcceptedReceiptIsRejectedOnPublicReopen() async throws {
    let work = Work()
    let history = try work.enableHistory()
    let unit = work.text
    let paragraph = TextParagraph(
      identifier: unit.paragraphs[0].identifier,
      runs: [TextRun(string: "Accepted change", emphasis: .none)])
    let changedUnit = try TextUnit(
      identifier: unit.identifier, title: unit.title, paragraphs: [paragraph])
    let changed = try Manuscript(identifier: work.manuscriptIdentifier, units: [changedUnit])
    try await history.submit(manuscript: changed)
    let original = try work.fileWrapper()
    let corrupted = try WorkPersistenceFixtures.package(
      original,
      updatingStore:
        "UPDATE ZHISTORYRECEIPT SET ZACCEPTED = NULL "
          + "WHERE Z_PK = (SELECT MIN(Z_PK) FROM ZHISTORYRECEIPT)")
    XCTAssertThrowsError(try Work(fileWrapper: corrupted))
    let reopened = try Work(fileWrapper: original)
    XCTAssertEqual(reopened.text.string, "Accepted change")
    try await history.close()
    try await reopened.history?.close()
  }

  func testDuplicateParagraphIdentityCannotBeSaved() throws {
    let work = try WorkPersistenceFixtures.sampleWork()
    let paragraph = try XCTUnwrap(work.text.paragraphs.first)
    work.text = try TextUnit(
      identifier: work.text.identifier, title: work.text.title,
      paragraphs: [paragraph, paragraph])
    XCTAssertThrowsError(try work.fileWrapper())
  }

  func testStagedSaveChangesOneParagraphAndKeepsOriginalWorkReadable() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let originalURL = directory.appendingPathComponent("Original.flwrbundle", isDirectory: true)
    let stagedURL = directory.appendingPathComponent("Staged.flwrbundle", isDirectory: true)
    try FileManager.default.createDirectory(at: originalURL, withIntermediateDirectories: false)
    try FileManager.default.createDirectory(at: stagedURL, withIntermediateDirectories: false)

    let work = try WorkPersistenceFixtures.sampleWork()
    let originalParagraphs = work.text.paragraphs
    try work.stageSave(from: nil, toEmptyPackageAt: originalURL)

    var revisedParagraphs = originalParagraphs
    revisedParagraphs[0] = TextParagraph(
      identifier: originalParagraphs[0].identifier,
      runs: [TextRun(string: "Changed only this paragraph", emphasis: .emphasis)],
      alignment: .center)
    work.text = try TextUnit(
      identifier: work.text.identifier, title: work.text.title,
      paragraphs: revisedParagraphs)
    let report = try work.stageSave(from: originalURL, toEmptyPackageAt: stagedURL)

    let original = try Work(fileWrapper: FileWrapper(url: originalURL))
    let staged = try Work(fileWrapper: FileWrapper(url: stagedURL))
    XCTAssertEqual(original.text.paragraphs, originalParagraphs)
    XCTAssertEqual(staged.identifier, work.identifier)
    XCTAssertEqual(staged.manuscript, work.manuscript)
    XCTAssertEqual(report.changedParagraphs, 1)
    XCTAssertGreaterThan(report.clonedStoreBytes + report.copiedStoreBytes, 0)
  }
}
