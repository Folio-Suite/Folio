// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import FolioKit
import Foundation

/// The current native Work document type.
public let workDocumentType = "app.foliosuite.Write.Doc"

/// The native package envelope used by a Work.
public enum WorkStorageVersion: Int, Sendable {
    case v1 = 1
    case v2 = 2
}

/// Metadata for one opaque resource retained with a Work.
public struct WorkResource: Equatable, Sendable {
    public let identifier: FolioIdentifier
    public let filename: String
    public let byteCount: Int64
    public let sha256: String
}

/// Work changed while preparing a closed native package for document replacement.
public struct WorkSaveReport: Sendable {
    public let changedContentUnits: Int
    public let changedParagraphs: Int
    public let changedRuns: Int
    public let clonedStoreBytes: Int64
    public let copiedStoreBytes: Int64
    public let clonedResourceBytes: Int64
    public let copiedResourceBytes: Int64
}

@MainActor func verifiedValue<Value>(_ make: () throws -> Value) -> Value {
    do { return try make() }
    catch { preconditionFailure("Invalid internal Work value: \(error)") }
}

/// The main-actor authority for one open Work. Its authored snapshots use FolioKit values.
@MainActor public final class Work {
    public let identifier: FolioIdentifier
    private var resourceStore: WorkResourceStore?
    private var historyBaseline: WorkHistoryBaseline?
    /// Durable manuscript history, when explicitly enabled or present in the saved package.
    public private(set) var history: WorkHistorySession?
    public var manuscript: Manuscript {
        didSet { precondition(manuscript.identifier == oldValue.identifier) }
    }

    public var manuscriptIdentifier: FolioIdentifier { manuscript.identifier }

    /// The first Content Unit, independent of sidebar selection.
    public var text: TextUnit {
        get { manuscript.units[0] }
        set {
            var units = manuscript.units
            units[0] = newValue
            manuscript = verifiedValue { try Manuscript(identifier: manuscript.identifier, units: units) }
        }
    }

    public init() {
        identifier = .make()
        manuscript = verifiedValue { try Manuscript(identifier: .make(), units: [.makeEmpty()]) }
        resourceStore = nil
    }

    private init(identifier: FolioIdentifier, manuscript: Manuscript, resourceStore: WorkResourceStore? = nil) {
        self.identifier = identifier
        self.manuscript = manuscript
        self.resourceStore = resourceStore
    }

    public convenience init(fileWrapper: FileWrapper) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let packageURL = directory.appendingPathComponent("Input.flwrbundle")
        try fileWrapper.write(to: packageURL, options: .atomic, originalContentsURL: nil)
        try self.init(contentsOf: packageURL)
    }

    /// Open a native Work package directly without loading resources into a file wrapper.
    public convenience init(contentsOf packageURL: URL) throws {
        let opened = try WorkStore.openPackage(at: packageURL)
        self.init(identifier: opened.snapshot.identifier, manuscript: opened.snapshot.manuscript,
                  resourceStore: opened.resources)
        if FileManager.default.fileExists(atPath: packageURL.appendingPathComponent("History").path) {
            history = try WorkHistorySession(work: self, packageURL: packageURL)
        } else {
            historyBaseline = try WorkHistoryBaseline(packageURL: packageURL)
        }
    }

    /// Enable durable manuscript history. Resources remain preserved but cannot be edited in this first slice.
    @discardableResult public func enableHistory() throws -> WorkHistorySession {
        if let history { return history }
        try upgradeStorage()
        let session = try WorkHistorySession(work: self, packageURL: nil, baseline: historyBaseline?.directory)
        history = session
        historyBaseline = nil
        return session
    }

    public func fileWrapper() throws -> FileWrapper {
        if resourceStore != nil {
            return try PackageStaging.withTemporaryDirectory { directory in
                let packageURL = directory.appendingPathComponent("Output.flwrbundle", isDirectory: true)
                try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: false)
                try stageSave(from: nil, toEmptyPackageAt: packageURL)
                return try FileWrapper(url: packageURL, options: .immediate)
            }
        }
        return try WorkStore.package(workIdentifier: identifier, manuscript: manuscript)
    }

    public var storageVersion: WorkStorageVersion { resourceStore == nil ? .v1 : .v2 }

    /// Select the V2 package envelope. Existing V1 bytes remain intact until a later successful save.
    public func upgradeStorage() throws {
        if resourceStore == nil { resourceStore = try WorkResourceStore() }
    }

    public var resources: [WorkResource] { resourceStore?.resources ?? [] }

    /// Retain a private, immutable snapshot of a regular file. V1 Works require an explicit upgrade first.
    @discardableResult public func importResource(from sourceURL: URL) throws -> FolioIdentifier {
        guard history == nil else { throw WorkHistoryError.resourceEditingUnsupported }
        guard let resourceStore else { throw WorkStore.upgradeRequiredError() }
        return try resourceStore.importResource(from: sourceURL)
    }

    /// Copy an opaque resource to an absent destination file.
    public func exportResource(withIdentifier identifier: FolioIdentifier, to destinationURL: URL) throws {
        guard let resourceStore else { throw WorkStore.missingResourceError() }
        try resourceStore.exportResource(identifier, to: destinationURL)
    }

    public func removeResource(withIdentifier identifier: FolioIdentifier) throws {
        guard history == nil else { throw WorkHistoryError.resourceEditingUnsupported }
        guard let resourceStore else { throw WorkStore.missingResourceError() }
        try resourceStore.removeResource(identifier)
    }

    /// Prepare this Work in an existing empty package directory. The original package is read but never changed.
    /// Pass nil for a new Work; otherwise pass a closed native package at a different URL.
    @discardableResult public func stageSave(from originalPackageURL: URL?,
                                              toEmptyPackageAt destinationPackageURL: URL) throws -> WorkSaveReport {
        if let history {
            return try history.stageSave(resources: resourceStore, to: destinationPackageURL)
        }
        return try WorkStore.stageSave(workIdentifier: identifier, manuscript: manuscript,
                                       resources: resourceStore, from: originalPackageURL, to: destinationPackageURL)
    }

    public func text(withIdentifier identifier: FolioIdentifier) -> TextUnit? {
        manuscript.units.first { $0.identifier == identifier }
    }

    /// Replace an existing Content Unit while retaining Manuscript order.
    public func replaceText(_ text: TextUnit) {
        var units = manuscript.units
        guard let index = units.firstIndex(where: { $0.identifier == text.identifier }) else {
            preconditionFailure("Replacement must retain an existing Content Unit identity")
        }
        units[index] = text
        manuscript = verifiedValue { try Manuscript(identifier: manuscript.identifier, units: units) }
    }
}
