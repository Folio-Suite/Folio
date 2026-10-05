// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import FolioKit
import Foundation

/// The uniform type identifier used by the host to register native `.flwrbundle` documents.
public let workDocumentType = "app.foliosuite.Write.Doc"

/// Metadata for one opaque resource retained with a Work.
public struct WorkResource: Equatable, Sendable, Codable {
  /// Stable identity of this resource within its Work; independent of its filename.
  public let identifier: FolioIdentifier
  /// Original import filename for presentation; package storage uses the resource identity.
  public let filename: String
  /// Logical size of the immutable resource snapshot in bytes.
  public let byteCount: Int64
  /// SHA-256 digest of the snapshot bytes, represented as lowercase hexadecimal.
  public let sha256: String

  private enum CodingKeys: String, CodingKey { case identifier, filename, byteCount, sha256 }

  init(identifier: FolioIdentifier, filename: String, byteCount: Int64, sha256: String) {
    self.identifier = identifier
    self.filename = filename
    self.byteCount = byteCount
    self.sha256 = sha256
  }

  /// Decode resource metadata without opening or validating its backing bytes.
  ///
  /// The identifier is validated by FolioKit. Work package loading separately validates
  /// filename, size, digest, ordering, membership, and the actual resource files.
  /// - Parameter decoder: A decoder containing the metadata fields.
  /// - Throws: Decoding errors or an invalid Folio identifier.
  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    identifier = try FolioIdentifier(rawValue: values.decode(String.self, forKey: .identifier))
    filename = try values.decode(String.self, forKey: .filename)
    byteCount = try values.decode(Int64.self, forKey: .byteCount)
    sha256 = try values.decode(String.self, forKey: .sha256)
  }

  /// Encode metadata, including the identifier as its raw string; resource bytes are omitted.
  /// - Parameter encoder: The destination encoder.
  /// - Throws: Errors from the encoder.
  public func encode(to encoder: any Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encode(identifier.rawValue, forKey: .identifier)
    try values.encode(filename, forKey: .filename)
    try values.encode(byteCount, forKey: .byteCount)
    try values.encode(sha256, forKey: .sha256)
  }
}

/// Changes and logical transfer sizes observed while staging a native package.
///
/// These measurements describe preparation, not successful document publication.
/// Cloned bytes are logical file sizes, not physical disk allocation or bytes copied.
public struct WorkSaveReport: Sendable {
  /// Number of Content Unit records inserted, removed, or updated during staging.
  /// Reordering only the Manuscript list or editing only paragraph text does not
  /// itself count as updating the containing Content Unit record.
  public let changedContentUnits: Int
  /// Number of paragraphs inserted, removed, or changed during store reconciliation.
  public let changedParagraphs: Int
  /// Number of runs inserted, removed, or changed during store reconciliation.
  public let changedRuns: Int
  /// Logical bytes in the original SQLite store successfully cloned for staging.
  public let clonedStoreBytes: Int64
  /// Logical bytes in the original SQLite store copied when cloning was unsupported.
  public let copiedStoreBytes: Int64
  /// Logical resource bytes successfully cloned into the staged package.
  public let clonedResourceBytes: Int64
  /// Logical resource bytes copied into the staged package when cloning was unsupported.
  public let copiedResourceBytes: Int64
}

@MainActor func verifiedValue<Value>(_ make: () throws -> Value) -> Value {
  do { return try make() } catch { preconditionFailure("Invalid internal Work value: \(error)") }
}

/// The main-actor authority for one open Work. Its authored snapshots use FolioKit values.
@MainActor public final class Work {
  /// Stable identity of this Work, preserved across native save and reopen.
  public let identifier: FolioIdentifier
  var resourceStore: WorkResourceStore
  private var historyBaseline: WorkHistoryBaseline?
  /// Durable Manuscript and resource history, when explicitly enabled or present in the saved package.
  public private(set) var history: WorkHistorySession?
  /// Current authored snapshot, which may include provisional native edits.
  ///
  /// Assignment must preserve the Manuscript identifier or triggers a precondition
  /// failure. Assignment does not submit durable history or save a document; with
  /// history enabled, settle native input and submit it through the session.
  public var manuscript: Manuscript {
    didSet { precondition(manuscript.identifier == oldValue.identifier) }
  }

  /// Stable identity of the Manuscript, distinct from the Work identity.
  public var manuscriptIdentifier: FolioIdentifier { manuscript.identifier }

  /// The first Content Unit, independent of sidebar selection.
  /// Setting it replaces the first unit in the in-memory snapshot; it neither
  /// saves nor submits history and must preserve Manuscript validity.
  public var text: TextUnit {
    get { manuscript.units[0] }
    set {
      var units = manuscript.units
      units[0] = newValue
      manuscript = verifiedValue { try Manuscript(identifier: manuscript.identifier, units: units) }
    }
  }

  /// Create an unsaved Work with new Work and Manuscript identities and one empty Content Unit.
  /// Resources begin empty and durable history is initially disabled.
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

  /// Open a complete native package supplied as an in-memory file wrapper.
  ///
  /// The wrapper is materialized temporarily and validated through the same path as
  /// ``init(contentsOf:)``. Retained resources and history use independent working
  /// copies; the temporary input is removed before this initializer returns.
  /// - Parameter fileWrapper: A directory wrapper containing a native Work package.
  /// - Throws: File-system errors or invalid or unsupported package content.
  public convenience init(fileWrapper: FileWrapper) throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    let packageURL = directory.appendingPathComponent("Input.flwrbundle")
    try fileWrapper.write(to: packageURL, options: .atomic, originalContentsURL: nil)
    try self.init(contentsOf: packageURL)
  }

  /// Open a native Work package directly without loading resources into a file wrapper.
  ///
  /// Reads a closed package and retains independent working copies. A saved
  /// History directory attaches a session but does not reconcile or replay it;
  /// await ``WorkHistorySession/reconcile()`` before enabling native history.
  /// - Parameter packageURL: A local native package directory with the current supported schema.
  /// - Throws: File-system errors or invalid, damaged, or unsupported package structure.
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
  ///
  /// Returns the existing session when already enabled. The Work retains the
  /// session; the session refers weakly to the Work, so keep the Work alive.
  /// Opening UndoKit is deferred until an asynchronous session operation.
  /// - Returns: This Work's main-actor history session.
  /// - Throws: Errors preparing private working storage or validating a saved baseline.
  @discardableResult public func enableHistory() throws -> WorkHistorySession {
    if let history { return history }
    let session = try WorkHistorySession(
      work: self, packageURL: nil, baseline: historyBaseline?.directory)
    history = session
    historyBaseline = nil
    return session
  }

  /// Serialize the complete Work package into an independent in-memory directory wrapper.
  ///
  /// With history enabled, the session must be opened, settled, and eligible to save.
  /// This prepares bytes only; the host still owns safe replacement and change counts.
  /// For large resources, prefer ``stageSave(from:toEmptyPackageAt:omittingHistory:)``.
  /// - Returns: A wrapper including current content, retained resources, and enabled history.
  /// - Throws: Staging or file-system errors, or a busy history session.
  public func fileWrapper() throws -> FileWrapper {
    try PackageStaging.withTemporaryDirectory { directory in
      let packageURL = directory.appendingPathComponent("Output.flwrbundle", isDirectory: true)
      try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: false)
      try stageSave(from: nil, toEmptyPackageAt: packageURL)
      return try FileWrapper(url: packageURL, options: .immediate)
    }
  }

  /// Current resource membership, sorted by raw identifier.
  /// Resources retained only for Undo or checkpoints are excluded.
  public var resources: [WorkResource] { resourceStore.resources }

  /// Retain a private, immutable snapshot before history is enabled.
  /// With history enabled, use ``WorkHistorySession/importResource(from:)`` instead.
  /// - Parameter sourceURL: An accessible regular file, not a symbolic link.
  /// - Returns: A new resource identity. Later source changes do not affect its bytes.
  /// - Throws: Resource validation or file-system errors, or
  ///   ``WorkHistoryError/resourceHistoryRequired`` when history is enabled.
  @discardableResult public func importResource(from sourceURL: URL) throws -> FolioIdentifier {
    guard history == nil else { throw WorkHistoryError.resourceHistoryRequired }
    return try resourceStore.importResource(from: sourceURL)
  }

  /// Copy a currently included resource to an absent destination file.
  /// - Parameters:
  ///   - identifier: Identity from ``resources``.
  ///   - destinationURL: A writable local file URL that does not already exist.
  /// - Throws: A missing-resource error for absent membership or an existing
  ///   destination, or a file-system copy error. No Work membership is changed.
  public func exportResource(withIdentifier identifier: FolioIdentifier, to destinationURL: URL)
    throws {
    try resourceStore.exportResource(identifier, to: destinationURL)
  }

  /// Remove a resource and its private bytes before history is enabled.
  /// - Parameter identifier: Identity of an imported resource.
  /// - Throws: A missing-resource or file-system error, or
  ///   ``WorkHistoryError/resourceHistoryRequired`` when history is enabled.
  ///
  /// With history enabled, use ``WorkHistorySession/removeResource(withIdentifier:)``
  /// to retain bytes required by Undo and checkpoints.
  public func removeResource(withIdentifier identifier: FolioIdentifier) throws {
    guard history == nil else { throw WorkHistoryError.resourceHistoryRequired }
    try resourceStore.removeResource(identifier)
  }

  /// Prepare this Work in an existing empty package directory. The original package is read but never changed.
  /// Pass nil for a new Work; otherwise pass a closed native package at a different URL.
  /// When omitting history, the staged artifact contains current Work and resources
  /// without the History directory or host receipt rows. Confirm successful host
  /// publication before calling ``WorkHistorySession/completeOmissionAfterSave(_:)``.
  /// Begin an omission publication on the history session before staging.
  ///
  /// With history enabled, the session's private accepted store supplies the
  /// baseline instead of `originalPackageURL`. Preparation never acknowledges
  /// document saving or safe replacement. A failed attempt may leave partial
  /// staging content; discard it and retry with another empty destination.
  /// - Parameters:
  ///   - originalPackageURL: Closed prior package, or `nil` for a new Work.
  ///   - destinationPackageURL: Existing empty directory, outside the original package.
  ///   - omittingHistory: Whether an enabled session's publication fence authorizes a history-free artifact.
  /// - Returns: Changes and logical clone/copy sizes for this preparation.
  /// - Throws: A busy history session, invalid staging inputs, or persistence or file-system errors.
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

  /// Look up a current Content Unit without changing selection or history.
  /// - Parameter identifier: The Content Unit identity to find.
  /// - Returns: Its current snapshot, or `nil` when it is absent from the Manuscript.
  public func text(withIdentifier identifier: FolioIdentifier) -> TextUnit? {
    manuscript.units.first { $0.identifier == identifier }
  }

  /// Replace an existing Content Unit while retaining Manuscript order.
  /// - Parameter text: A replacement with an identity already present in the Manuscript.
  ///
  /// A missing identity triggers a precondition failure. This changes only the
  /// in-memory snapshot; the host owns durable submission and document saving.
  public func replaceText(_ text: TextUnit) {
    var units = manuscript.units
    guard let index = units.firstIndex(where: { $0.identifier == text.identifier }) else {
      preconditionFailure("Replacement must retain an existing Content Unit identity")
    }
    units[index] = text
    manuscript = verifiedValue { try Manuscript(identifier: manuscript.identifier, units: units) }
  }
}
