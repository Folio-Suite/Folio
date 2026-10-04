// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import FolioKit
import Foundation
import SQLite3
import WriteKit
import XCTest

@MainActor final class WriteKitPersistenceTests: XCTestCase {
  private func id(_ raw: String) throws -> FolioIdentifier { try FolioIdentifier(rawValue: raw) }

  private func sampleWork() throws -> Work {
    let work = Work()
    let runs = [
      TextRun(string: "Meaning & <words> 👑 ", emphasis: .emphasis),
      TextRun(string: "strong", emphasis: .strongEmphasis),
      TextRun(
        string: " bold italic  ", emphasis: .none,
        presentation: TextPresentation(bold: true, italic: true)),
    ]
    let paragraphs = [
      TextParagraph(identifier: try id("paragraph-one"), runs: runs, alignment: .center),
      TextParagraph(identifier: .make()), TextParagraph(identifier: .make()),
    ]
    work.text = try TextUnit(
      identifier: work.text.identifier, title: work.text.title, paragraphs: paragraphs)
    return work
  }

  private func package(_ original: FileWrapper, updatingStore sql: String) throws -> FileWrapper {
    let packageURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try original.write(to: packageURL, options: .atomic, originalContentsURL: nil)
    defer { try? FileManager.default.removeItem(at: packageURL) }
    let storeURL = packageURL.appendingPathComponent("Work.sqlite")
    var database: OpaquePointer?
    guard sqlite3_open_v2(storeURL.path, &database, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK,
      let database
    else {
      if let database { sqlite3_close(database) }
      throw NSError(domain: "WriteKitPersistenceTests.SQLite", code: 1)
    }
    let update = sqlite3_exec(database, sql, nil, nil, nil)
    let changed = sqlite3_changes(database)
    let close = sqlite3_close(database)
    guard update == SQLITE_OK, changed == 1, close == SQLITE_OK
    else { throw NSError(domain: "WriteKitPersistenceTests.SQLite", code: 2) }
    return try FileWrapper(url: packageURL, options: .immediate)
  }

  func testMixedScriptAuthoredTitleAndTextSurvivePackageRoundTrip() throws {
    let work = Work()
    let title = "العربية — 日本語 — Untitled"
    let text = "العربية English עברית 日本語 한글 e\u{0301} 👩🏽‍💻"
    let paragraph = TextParagraph(
      identifier: try id("mixed-script-paragraph"),
      runs: [TextRun(string: text, emphasis: .none)])
    work.text = try TextUnit(
      identifier: work.text.identifier, title: title, paragraphs: [paragraph])
    let loaded = try Work(fileWrapper: work.fileWrapper())
    XCTAssertEqual(loaded.text.title, title)
    XCTAssertEqual(loaded.text.string, text)
    XCTAssertEqual(loaded.text.paragraphs.first?.alignment, .natural)
  }

  func testNativePackageRoundTripPreservesMeaningAppearanceWhitespaceAndIdentity() throws {
    let work = try sampleWork()
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
        identifier: try id(name),
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
    let package = try sampleWork().fileWrapper()
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
    let original = try sampleWork().fileWrapper()
    let originalStore = try XCTUnwrap(original.fileWrappers?["Work.sqlite"]?.regularFileContents)
    let corrupted = try package(
      original,
      updatingStore: "UPDATE ZRUN SET ZBOLD = NULL WHERE Z_PK = (SELECT MIN(Z_PK) FROM ZRUN)")
    XCTAssertThrowsError(try Work(fileWrapper: corrupted))
    XCTAssertEqual(original.fileWrappers?["Work.sqlite"]?.regularFileContents, originalStore)
    XCTAssertNoThrow(try Work(fileWrapper: original))
  }

  func testFractionalStoredEmphasisIsRejected() throws {
    let original = try sampleWork().fileWrapper()
    let corrupted = try package(
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
    let corrupted = try package(
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
    let work = try sampleWork()
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

    let work = try sampleWork()
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

  func testDefaultResourceStorageRetainsImportedResourceAfterSourceChanges() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let originalURL = directory.appendingPathComponent("Original.flwrbundle", isDirectory: true)
    let stagedURL = directory.appendingPathComponent("Staged.flwrbundle", isDirectory: true)
    try FileManager.default.createDirectory(at: originalURL, withIntermediateDirectories: false)
    try FileManager.default.createDirectory(at: stagedURL, withIntermediateDirectories: false)
    let sourceURL = directory.appendingPathComponent("source-image.bin")
    let exportedURL = directory.appendingPathComponent("exported-image.bin")
    let originalBytes = Data(repeating: 0xA5, count: 1_048_576)
    try originalBytes.write(to: sourceURL)

    let work = Work()
    try work.stageSave(from: nil, toEmptyPackageAt: originalURL)
    let resourceID = try work.importResource(from: sourceURL)
    try Data(repeating: 0x5A, count: originalBytes.count).write(to: sourceURL)
    let report = try work.stageSave(from: originalURL, toEmptyPackageAt: stagedURL)

    let reopened = try Work(contentsOf: stagedURL)
    XCTAssertEqual(reopened.resources.map(\.identifier), [resourceID])
    try reopened.exportResource(withIdentifier: resourceID, to: exportedURL)
    XCTAssertEqual(try Data(contentsOf: exportedURL), originalBytes)
    let wrapped = try Work(fileWrapper: reopened.fileWrapper())
    let wrapperExportURL = directory.appendingPathComponent("wrapper-export.bin")
    try wrapped.exportResource(withIdentifier: resourceID, to: wrapperExportURL)
    XCTAssertEqual(try Data(contentsOf: wrapperExportURL), originalBytes)
    XCTAssertEqual(
      Set(try FileManager.default.contentsOfDirectory(atPath: originalURL.path)),
      ["Work.sqlite", "Package.json", "Resources"])
    XCTAssertGreaterThan(report.clonedResourceBytes + report.copiedResourceBytes, 0)
  }

  func testStagingUnchangedWorkReportsNoChangedRows() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let originalURL = directory.appendingPathComponent("Original.flwrbundle", isDirectory: true)
    let stagedURL = directory.appendingPathComponent("Staged.flwrbundle", isDirectory: true)
    try FileManager.default.createDirectory(at: originalURL, withIntermediateDirectories: false)
    try FileManager.default.createDirectory(at: stagedURL, withIntermediateDirectories: false)
    let work = try sampleWork()
    try work.stageSave(from: nil, toEmptyPackageAt: originalURL)

    let report = try work.stageSave(from: originalURL, toEmptyPackageAt: stagedURL)
    XCTAssertEqual(report.changedContentUnits, 0)
    XCTAssertEqual(report.changedParagraphs, 0)
    XCTAssertEqual(report.changedRuns, 0)
    XCTAssertEqual(try Work(contentsOf: stagedURL).manuscript, work.manuscript)
  }
}

extension WriteKitPersistenceTests {
  func testStagingReorderAndParagraphDeletionPreserveSurvivingIdentities() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let originalURL = directory.appendingPathComponent("Original.flwrbundle", isDirectory: true)
    let stagedURL = directory.appendingPathComponent("Staged.flwrbundle", isDirectory: true)
    try FileManager.default.createDirectory(at: originalURL, withIntermediateDirectories: false)
    try FileManager.default.createDirectory(at: stagedURL, withIntermediateDirectories: false)
    let work = try sampleWork()
    let first = work.text
    let second = try TextUnit(
      identifier: id("second-unit"), title: "Second",
      paragraphs: [
        TextParagraph(
          identifier: id("second-paragraph"),
          runs: [TextRun(string: "second text", emphasis: .none)]),
      ])
    work.manuscript = try Manuscript(identifier: work.manuscriptIdentifier, units: [first, second])
    try work.stageSave(from: nil, toEmptyPackageAt: originalURL)

    let trimmed = try TextUnit(
      identifier: first.identifier, title: first.title,
      paragraphs: [first.paragraphs[0]])
    work.manuscript = try Manuscript(
      identifier: work.manuscriptIdentifier, units: [second, trimmed])
    let report = try work.stageSave(from: originalURL, toEmptyPackageAt: stagedURL)

    let reopened = try Work(contentsOf: stagedURL)
    XCTAssertEqual(reopened.manuscript, work.manuscript)
    XCTAssertEqual(
      reopened.manuscript.units.map(\.identifier), [second.identifier, first.identifier])
    XCTAssertEqual(
      reopened.manuscript.units[1].paragraphs[0].identifier, first.paragraphs[0].identifier)
    XCTAssertEqual(report.changedParagraphs, 2)
    XCTAssertEqual(try Work(contentsOf: originalURL).manuscript.units[0].paragraphs.count, 3)
  }

  func testCorruptResourceCannotBeStagedOverCleanDestination() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let originalURL = directory.appendingPathComponent("Original.flwrbundle", isDirectory: true)
    let destinationURL = directory.appendingPathComponent(
      "Destination.flwrbundle", isDirectory: true)
    try FileManager.default.createDirectory(at: originalURL, withIntermediateDirectories: false)
    try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: false)
    let resourceURL = directory.appendingPathComponent("source.bin")
    try Data("original bytes".utf8).write(to: resourceURL)
    let work = Work()
    let identifier = try work.importResource(from: resourceURL)
    try work.stageSave(from: nil, toEmptyPackageAt: originalURL)
    let retainedURL = originalURL.appendingPathComponent("Resources").appendingPathComponent(
      identifier.rawValue)
    try Data("corrupt bytes".utf8).write(to: retainedURL)

    XCTAssertThrowsError(try Work(contentsOf: originalURL))
    XCTAssertThrowsError(try work.stageSave(from: originalURL, toEmptyPackageAt: destinationURL))
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: destinationURL.path), [])
    XCTAssertEqual(try Data(contentsOf: retainedURL), Data("corrupt bytes".utf8))
  }

  func testStagingFailureAfterClonePreservesOriginalAndAllowsRetry() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let originalURL = directory.appendingPathComponent("Original.flwrbundle", isDirectory: true)
    let stagedURL = directory.appendingPathComponent("Staged.flwrbundle", isDirectory: true)
    try FileManager.default.createDirectory(at: originalURL, withIntermediateDirectories: false)
    try FileManager.default.createDirectory(at: stagedURL, withIntermediateDirectories: false)
    let work = try sampleWork()
    try work.stageSave(from: nil, toEmptyPackageAt: originalURL)
    let originalText = work.text.string
    let paragraph = work.text.paragraphs[0]
    work.text = try TextUnit(
      identifier: work.text.identifier, title: work.text.title,
      paragraphs: [
        TextParagraph(
          identifier: paragraph.identifier,
          runs: [TextRun(string: "retry succeeds", emphasis: .none)]),
        work.text.paragraphs[1], work.text.paragraphs[2],
      ])
    let storeURL = originalURL.appendingPathComponent("Work.sqlite")
    try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: storeURL.path)
    defer {
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o644], ofItemAtPath: storeURL.path)
    }

    XCTAssertThrowsError(try work.stageSave(from: originalURL, toEmptyPackageAt: stagedURL))
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: stagedURL.path), [])
    XCTAssertEqual(try Work(contentsOf: originalURL).text.string, originalText)
    try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: storeURL.path)
    try work.stageSave(from: originalURL, toEmptyPackageAt: stagedURL)
    XCTAssertEqual(try Work(contentsOf: stagedURL).text.string, work.text.string)
  }

  func testStagingRejectsUnknownOriginalMemberWithoutWritingDestination() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let originalURL = directory.appendingPathComponent("Original.flwrbundle", isDirectory: true)
    let stagedURL = directory.appendingPathComponent("Staged.flwrbundle", isDirectory: true)
    try FileManager.default.createDirectory(at: originalURL, withIntermediateDirectories: false)
    try FileManager.default.createDirectory(at: stagedURL, withIntermediateDirectories: false)
    let work = try sampleWork()
    try work.stageSave(from: nil, toEmptyPackageAt: originalURL)
    let originalStore = try Data(contentsOf: originalURL.appendingPathComponent("Work.sqlite"))
    let unknownURL = originalURL.appendingPathComponent("future.bin")
    try Data("future".utf8).write(to: unknownURL)

    XCTAssertThrowsError(try work.stageSave(from: originalURL, toEmptyPackageAt: stagedURL))
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: stagedURL.path), [])
    XCTAssertEqual(
      try Data(contentsOf: originalURL.appendingPathComponent("Work.sqlite")), originalStore)
    XCTAssertEqual(try Data(contentsOf: unknownURL), Data("future".utf8))
  }

  func testStagingRefusesSymlinkAndNestedDestinations() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let originalURL = directory.appendingPathComponent("Original.flwrbundle", isDirectory: true)
    let emptyURL = directory.appendingPathComponent("Empty.flwrbundle", isDirectory: true)
    try FileManager.default.createDirectory(at: originalURL, withIntermediateDirectories: false)
    try FileManager.default.createDirectory(at: emptyURL, withIntermediateDirectories: false)
    let work = Work()
    try work.stageSave(from: nil, toEmptyPackageAt: originalURL)
    let originalStore = try Data(contentsOf: originalURL.appendingPathComponent("Work.sqlite"))

    let aliasURL = directory.appendingPathComponent("Alias.flwrbundle", isDirectory: true)
    try FileManager.default.createSymbolicLink(at: aliasURL, withDestinationURL: emptyURL)
    XCTAssertThrowsError(try work.stageSave(from: originalURL, toEmptyPackageAt: aliasURL))
    let nestedURL = originalURL.appendingPathComponent("Nested.flwrbundle", isDirectory: true)
    try FileManager.default.createDirectory(at: nestedURL, withIntermediateDirectories: false)
    XCTAssertThrowsError(try work.stageSave(from: originalURL, toEmptyPackageAt: nestedURL))
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: emptyURL.path), [])
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: nestedURL.path), [])
    XCTAssertEqual(
      try Data(contentsOf: originalURL.appendingPathComponent("Work.sqlite")), originalStore)
  }
}
