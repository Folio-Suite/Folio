// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import Foundation
import ResearchKit
import UniformTypeIdentifiers
import XCTest
@testable import Research

@MainActor
final class ResearchTests: XCTestCase {
    private let libraryType = "app.foliosuite.Research.Doc"

    func testDocumentRegistrationAndKitWindow() throws {
        XCTAssertTrue(NSDocumentController.shared.documentClass(forType: libraryType) === ResearchDocument.self)
        let document = ResearchDocument()
        document.makeWindowControllers()
        defer { document.close() }
        XCTAssertEqual(document.windowControllers.count, 1)
        XCTAssertNotNil(document.windowControllers.first?.window)
    }

    func testCurrentPackagePreservesCollectedFilesAcrossSaves() throws {
        let package = try ResearchLibraryPackage.empty()
        let collectedBytes = Data("Collected research file: café, 日本語\n".utf8)
        let assets = FileWrapper(directoryWithFileWrappers: [
            "Collected.txt": FileWrapper(regularFileWithContents: collectedBytes)
        ])
        assets.preferredFilename = "assets"
        package.addFileWrapper(assets)
        try ResearchLibraryPackage.validate(package)

        let type = UTType(exportedAs: libraryType)
        XCTAssertTrue(type.conforms(to: .package))
        XCTAssertTrue(type.conforms(to: .content))

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        let firstURL = directory.appendingPathComponent("Library.flrsbundle", isDirectory: true)
        let copyURL = directory.appendingPathComponent("Copy.flrsbundle", isDirectory: true)
        let document = ResearchDocument()
        defer { document.close() }
        try document.read(from: package, ofType: libraryType)
        try document.writeSafely(to: firstURL, ofType: libraryType, for: .saveOperation)

        let reopened = try ResearchDocument(contentsOf: firstURL, ofType: libraryType)
        defer { reopened.close() }
        let reopenedPackage = try reopened.fileWrapper(ofType: libraryType)
        XCTAssertEqual(reopenedPackage.fileWrappers?["assets"]?.fileWrappers?["Collected.txt"]?.regularFileContents, collectedBytes)

        try reopened.writeSafely(to: copyURL, ofType: libraryType, for: .saveAsOperation)
        let copied = try ResearchDocument(contentsOf: copyURL, ofType: libraryType)
        defer { copied.close() }
        let copiedPackage = try copied.fileWrapper(ofType: libraryType)
        XCTAssertEqual(copiedPackage.fileWrappers?["assets"]?.fileWrappers?["Collected.txt"]?.regularFileContents, collectedBytes)
        XCTAssertNotNil(copiedPackage.fileWrappers?["Library.sqlite"])
    }

    func testInvalidPackageDoesNotReplaceAnOpenLibraryOrMutateInput() throws {
        let document = ResearchDocument()
        let original = try document.fileWrapper(ofType: libraryType)
        let originalBytes = try XCTUnwrap(original.fileWrappers?["Library.sqlite"]?.regularFileContents)
        let corruptBytes = Data("Not a SQLite database".utf8)
        let invalidPackages = [
            FileWrapper(directoryWithFileWrappers: [:]),
            FileWrapper(directoryWithFileWrappers: ["Library.sqlite": FileWrapper(regularFileWithContents: corruptBytes)]),
            FileWrapper(directoryWithFileWrappers: [
                "Library.sqlite": original.fileWrappers!["Library.sqlite"]!,
                "Library.sqlite-wal": FileWrapper(regularFileWithContents: Data())
            ])
        ]

        for invalid in invalidPackages {
            XCTAssertThrowsError(try document.read(from: invalid, ofType: libraryType))
            XCTAssertTrue(try document.fileWrapper(ofType: libraryType) === original)
            XCTAssertEqual(original.fileWrappers?["Library.sqlite"]?.regularFileContents, originalBytes)
        }
        XCTAssertEqual(invalidPackages[1].fileWrappers?["Library.sqlite"]?.regularFileContents, corruptBytes)
    }

}
