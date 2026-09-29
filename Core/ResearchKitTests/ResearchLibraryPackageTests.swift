// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import CoreData
import Foundation
import ResearchKit
import XCTest

final class ResearchLibraryPackageTests: XCTestCase {
    func testEmptyPackageCreatesClosedCatalogStore() throws {
        let package = try ResearchLibraryPackage.empty()

        XCTAssertTrue(package.isDirectory)
        XCTAssertEqual(Set(package.fileWrappers?.keys.map { $0 } ?? []), ["Library.sqlite"])
        try ResearchLibraryPackage.validate(package)
    }

    func testValidationAllowsAndRetainsAdditionalMembers() throws {
        let package = try ResearchLibraryPackage.empty()
        let asset = FileWrapper(regularFileWithContents: Data("collected bytes".utf8))
        let original = package.fileWrappers?["Library.sqlite"]?.regularFileContents
        let withAsset = FileWrapper(directoryWithFileWrappers: [
            "Library.sqlite": package.fileWrappers!["Library.sqlite"]!,
            "assets": FileWrapper(directoryWithFileWrappers: ["Notes.txt": asset]),
            "catalog.json": FileWrapper(regularFileWithContents: Data("metadata".utf8))
        ])

        try ResearchLibraryPackage.validate(withAsset)

        XCTAssertEqual(withAsset.fileWrappers?["Library.sqlite"]?.regularFileContents, original)
        XCTAssertEqual(withAsset.fileWrappers?["assets"]?.fileWrappers?["Notes.txt"]?.regularFileContents, Data("collected bytes".utf8))
        XCTAssertNotNil(withAsset.fileWrappers?["catalog.json"])
    }

    func testValidationRejectsSQLiteSidecars() throws {
        let original = try ResearchLibraryPackage.empty()
        let validDatabase = try XCTUnwrap(original.fileWrappers?["Library.sqlite"])
        for sidecar in ["Library.sqlite-wal", "Library.sqlite-shm", "Library.sqlite-journal"] {
            let package = FileWrapper(directoryWithFileWrappers: [
                "Library.sqlite": validDatabase,
                sidecar: FileWrapper(regularFileWithContents: Data())
            ])

            XCTAssertThrowsError(try ResearchLibraryPackage.validate(package), sidecar)
        }
    }

    func testValidationRejectsMalformedAndIncompatibleStores() throws {
        let malformed = FileWrapper(directoryWithFileWrappers: [
            "Library.sqlite": FileWrapper(regularFileWithContents: Data("not a database".utf8))
        ])
        XCTAssertThrowsError(try ResearchLibraryPackage.validate(malformed))

        let incompatible = try packageWithVersion("UnsupportedCatalogV2")
        XCTAssertThrowsError(try ResearchLibraryPackage.validate(incompatible))
    }

    private func packageWithVersion(_ version: String) throws -> FileWrapper {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        let model = NSManagedObjectModel()
        model.versionIdentifiers = [version]
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let storeURL = directory.appendingPathComponent("Library.sqlite")
        let store = try coordinator.addPersistentStore(
            type: .sqlite,
            configuration: nil,
            at: storeURL,
            options: [NSSQLitePragmasOption: ["journal_mode": "DELETE"]]
        )
        try coordinator.remove(store)

        return FileWrapper(directoryWithFileWrappers: [
            "Library.sqlite": FileWrapper(regularFileWithContents: try Data(contentsOf: storeURL))
        ])
    }
}
