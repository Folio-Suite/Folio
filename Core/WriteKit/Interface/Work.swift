// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import FolioKit
import Foundation

/// The current native Work document type.
public let workDocumentType = "app.foliosuite.Write.Doc"

/// Metadata for one opaque resource retained with a Work.
public struct WorkResource: Equatable, Sendable, Codable {
  public let identifier: FolioIdentifier
  public let filename: String
  public let byteCount: Int64
  public let sha256: String

  private enum CodingKeys: String, CodingKey { case identifier, filename, byteCount, sha256 }

  init(identifier: FolioIdentifier, filename: String, byteCount: Int64, sha256: String) {
    self.identifier = identifier
    self.filename = filename
    self.byteCount = byteCount
    self.sha256 = sha256
  }

  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    identifier = try FolioIdentifier(rawValue: values.decode(String.self, forKey: .identifier))
    filename = try values.decode(String.self, forKey: .filename)
    byteCount = try values.decode(Int64.self, forKey: .byteCount)
    sha256 = try values.decode(String.self, forKey: .sha256)
  }

  public func encode(to encoder: any Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encode(identifier.rawValue, forKey: .identifier)
    try values.encode(filename, forKey: .filename)
    try values.encode(byteCount, forKey: .byteCount)
    try values.encode(sha256, forKey: .sha256)
  }
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
  do { return try make() } catch { preconditionFailure("Invalid internal Work value: \(error)") }
}

/// The main-actor authority for one open Work. Its authored snapshots use FolioKit values.
@MainActor public final class Work {
  public let identifier: FolioIdentifier
  var resourceStore: WorkResourceStore
  private var historyBaseline: WorkHistoryBaseline?
  /// Durable Manuscript and resource history, when explicitly enabled or present in the saved package.
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
    resourceStore = WorkResourceStore()
  }

  private init(
    identifier: FolioIdentifier, manuscript: Manuscript, resourceStore: WorkResourceStore
  ) {
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
    self.init(
      identifier: opened.snapshot.identifier, manuscript: opened.snapshot.manuscript,
      resourceStore: opened.resources)
    if FileManager.default.fileExists(atPath: packageURL.appendingPathComponent("History").path) {
      history = try WorkHistorySession(work: self, packageURL: packageURL)
    } else {
      historyBaseline = try WorkHistoryBaseline(packageURL: packageURL, resources: resourceStore)
    }
  }

  /// Enable durable Manuscript and resource history. Submit resource edits through the returned session.
  @discardableResult public func enableHistory() throws -> WorkHistorySession {
    if let history { return history }
    let session = try WorkHistorySession(
      work: self, packageURL: nil, baseline: historyBaseline?.directory)
    history = session
    historyBaseline = nil
    return session
  }

  public func fileWrapper() throws -> FileWrapper {
    try PackageStaging.withTemporaryDirectory { directory in
      let packageURL = directory.appendingPathComponent("Output.flwrbundle", isDirectory: true)
      try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: false)
      try stageSave(from: nil, toEmptyPackageAt: packageURL)
      return try FileWrapper(url: packageURL, options: .immediate)
    }
  }

  public var resources: [WorkResource] { resourceStore.resources }

  /// Retain a private, immutable snapshot before history is enabled.
  /// With history enabled, use `WorkHistorySession.importResource(from:)` instead.
  @discardableResult public func importResource(from sourceURL: URL) throws -> FolioIdentifier {
    guard history == nil else { throw WorkHistoryError.resourceHistoryRequired }
    return try resourceStore.importResource(from: sourceURL)
  }

  /// Copy an opaque resource to an absent destination file.
  public func exportResource(withIdentifier identifier: FolioIdentifier, to destinationURL: URL)
    throws {
    try resourceStore.exportResource(identifier, to: destinationURL)
  }

  /// Remove a resource before history is enabled; otherwise use the asynchronous history session.
  public func removeResource(withIdentifier identifier: FolioIdentifier) throws {
    guard history == nil else { throw WorkHistoryError.resourceHistoryRequired }
    try resourceStore.removeResource(identifier)
  }

  /// Prepare this Work in an existing empty package directory. The original package is read but never changed.
  /// Pass nil for a new Work; otherwise pass a closed native package at a different URL.
  /// When omitting history, the staged artifact contains current Work and resources
  /// without the History directory or host receipt rows. Confirm successful host
  /// publication before calling `WorkHistorySession.completeOmissionAfterSave(_:)`.
  /// Begin an omission publication on the history session before staging.
  @discardableResult public func stageSave(
    from originalPackageURL: URL?,
    toEmptyPackageAt destinationPackageURL: URL,
    omittingHistory: Bool = false
  ) throws -> WorkSaveReport {
    if let history {
      return try history.stageSave(resources: resourceStore, to: destinationPackageURL,
                                   omittingHistory: omittingHistory)
    }
    return try WorkStore.stageSave(
      workIdentifier: identifier, manuscript: manuscript,
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
