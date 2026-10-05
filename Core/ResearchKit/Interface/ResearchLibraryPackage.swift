// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import CoreData
import FolioKit
import Foundation

/// Creates and validates the current empty Source Library package shell.
///
/// Research retains package members other than its catalog store. Validation
/// rejects an open SQLite store with sidecars and unsupported catalog models.
/// This type does not implement catalog editing or synchronization.
public enum ResearchLibraryPackage {
    private static let storeName = "Library.sqlite"
    private static let modelVersion = "FolioResearchLibraryShellV1"

    /// Creates a package containing a closed, empty `Library.sqlite` store.
    ///
    /// - Returns: An in-memory package wrapper that does not depend on temporary files.
    /// - Throws: Core Data or filesystem errors while creating and closing the store.
    /// - Note: The current model contains no Source entities; this creates a shell.
    public static func empty() throws -> FileWrapper {
        try PackageStaging.withTemporaryDirectory { directory in
            let storeURL = directory.appendingPathComponent(storeName)
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: libraryModel())
            let store = try coordinator.addPersistentStore(
                type: .sqlite,
                configuration: nil,
                at: storeURL,
                options: [NSSQLitePragmasOption: ["journal_mode": "DELETE"]]
            )
            // Detaching closes Core Data’s store before its bytes become package content.
            // A live WAL-backed store cannot be captured by copying only the main SQLite file.
            try coordinator.remove(store)
            return FileWrapper(directoryWithFileWrappers: [
                storeName: FileWrapper(regularFileWithContents: try Data(contentsOf: storeURL))
            ])
        }
    }

    /// Validates the catalog store while leaving the package and its other
    /// members untouched. Additional Research package members are supported.
    ///
    /// - Parameter package: A directory wrapper containing the closed catalog store.
    /// - Throws: A Cocoa read error for malformed structure or incompatible metadata,
    ///   or an underlying filesystem/Core Data error while inspecting the copied store.
    /// - Important: This checks package structure and store metadata, not semantic
    ///   Source records or the integrity of arbitrary additional members.
    public static func validate(_ package: FileWrapper) throws {
        guard package.isDirectory,
              let members = package.fileWrappers,
              let database = members[storeName], database.isRegularFile,
              !sidecarNames.contains(where: { members[$0] != nil })
        else {
            throw packageError(
                recovery: NSLocalizedString(
                    "source-library.structure.recovery",
                    tableName: "Localizable",
                    bundle: .researchKit,
                    value: "Expected a package containing a closed Library.sqlite snapshot. " +
                        "Live database sidecars are not supported by this shell.",
                    comment: "Recovery guidance for a malformed Source Library package."
                )
            )
        }

        try PackageStaging.withTemporaryDirectory { directory in
            let storeURL = directory.appendingPathComponent(storeName)
            try database.write(to: storeURL, options: .atomic, originalContentsURL: nil)
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                type: .sqlite,
                at: storeURL,
                options: nil
            )
            let versions = Set(metadata[NSStoreModelVersionIdentifiersKey] as? [String] ?? [])
            let model = libraryModel()
            let expectedVersions = Set(model.versionIdentifiers.compactMap { $0 as? String })
            guard versions == expectedVersions,
                  model.isConfiguration(
                    withName: nil,
                    compatibleWithStoreMetadata: metadata
                  )
            else {
                throw packageError(
                    recovery: NSLocalizedString(
                        "source-library.version.recovery",
                        tableName: "Localizable",
                        bundle: .researchKit,
                        value: "This Source Library uses a different catalog model. " +
                            "Open it with a compatible version of Research.",
                        comment: "Recovery guidance for an unsupported Source Library catalog model."
                    )
                )
            }
        }
    }

    private static func libraryModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        model.versionIdentifiers = [modelVersion]
        return model
    }

    private static func packageError(recovery: String) -> NSError {
        NSError(
            domain: NSCocoaErrorDomain,
            code: NSFileReadCorruptFileError,
            userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString(
                    "source-library.read.error",
                    tableName: "Localizable",
                    bundle: .researchKit,
                    value: "Research cannot read this Source Library.",
                    comment: "Error summary. Research is the app name; Source Library is a Folio domain term."
                ),
                NSLocalizedRecoverySuggestionErrorKey: recovery,
            ]
        )
    }
}

private extension ResearchLibraryPackage {
    static let sidecarNames = ["Library.sqlite-wal", "Library.sqlite-shm", "Library.sqlite-journal"]
}

private extension Bundle {
    static var researchKit: Bundle {
        Bundle(identifier: "dev.foliosuite.ResearchKit") ?? Bundle(for: ResearchKitBundleToken.self)
    }
}

private final class ResearchKitBundleToken: NSObject {}
