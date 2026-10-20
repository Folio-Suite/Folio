// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import FolioKit
import Foundation
import SQLite3
import WriteKit
import XCTest

@MainActor extension WriteKitPersistenceTests {
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
    let work = try WorkPersistenceFixtures.sampleWork()
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
    let work = try WorkPersistenceFixtures.sampleWork()
    let first = work.text
    let second = try TextUnit(
      identifier: WorkPersistenceFixtures.id("second-unit"), title: "Second",
      paragraphs: [
        TextParagraph(
          identifier: WorkPersistenceFixtures.id("second-paragraph"),
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
    let work = try WorkPersistenceFixtures.sampleWork()
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
    let work = try WorkPersistenceFixtures.sampleWork()
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
