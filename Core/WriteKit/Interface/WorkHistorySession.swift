// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import CryptoKit
import FolioKit
import Foundation
import UndoKit

/// A host validation or lifecycle failure. Existing content and history remain available for recovery.
public enum WorkHistoryError: Error, LocalizedError {
  case busy, rejected, resourceHistoryRequired, invalidPackage, closed

  public var errorDescription: String? {
    switch self {
    case .busy:
      return NSLocalizedString(
        "work-history.busy", tableName: nil, bundle: WorkStore.bundle,
        value: "Wait for the current edit or history recovery to finish, then try again.",
        comment: "Work save or history operation cannot run while edits are unsettled.")
    case .rejected:
      return NSLocalizedString(
        "work-history.rejected", tableName: nil, bundle: WorkStore.bundle,
        value: "This history operation could not be applied to the current Work.",
        comment: "A history operation failed semantic validation without changing the Work.")
    case .resourceHistoryRequired:
      return NSLocalizedString(
        "work-history.resources-unsupported", tableName: nil, bundle: WorkStore.bundle,
        value: "Use the Work’s history session to import or remove resources.",
        comment: "Direct synchronous resource edits must use the asynchronous history session.")
    case .invalidPackage:
      return NSLocalizedString(
        "work-history.invalid-package", tableName: nil, bundle: WorkStore.bundle,
        value: "This Work’s history is missing, damaged, or unsupported.",
        comment: "History package validation failed; existing bytes are preserved.")
    case .closed:
      return NSLocalizedString(
        "work-history.closed", tableName: nil, bundle: WorkStore.bundle,
        value: "This Work’s history session has closed.",
        comment: "Operation attempted after explicitly closing history.")
    }
  }
}

/// A bounded presentation row; obtaining rows does not reconstruct historical Manuscripts.
public struct WorkCheckpoint: Identifiable, Sendable {
  public let id: UUID
  public let name: String
  public let recordedAt: Date
}

struct WorkHistoryRegistration: Codable {
  let version: Int
  let work: String
  let scope: UUID
  let workingIdentity: UUID
}

/// Work's adapter for durable Manuscript and resource edits. Settle provisional editing before submission.
/// Resource bytes are retained separately from current membership for Undo and checkpoint restoration.
/// Calls and callbacks are main-actor isolated. A failed submission may require `reconcile()` before editing resumes.
@MainActor public final class WorkHistorySession {
  static let family = "app.foliosuite.work.content.replace"
  weak var work: Work?
  let directory: URL
  let registration: WorkHistoryRegistration
  let openMode: HistoryOpenMode
  var committed: Manuscript
  var committedResources: [WorkResource]
  var committedState: WorkHistoryState {
    WorkHistoryState(manuscript: committed, resources: committedResources)
  }
  var engine: HistoryEngine?
  var opening: Task<HistoryEngine, Error>?
  var host: MainActorHistoryRegisteredHost<WorkHistoryAdapter>?
  var typedRegistration: HistoryOperationRegistration<WorkHistoryAdapter>?
  var closed = false
  enum OmissionFinalizationPhase { case none, publishing, retireGeneration, stripReceipts }
  var omissionPhase: OmissionFinalizationPhase = .none
  var omissionPending: Bool { omissionPhase != .none }
  var omissionPublication: UUID?
  var omissionManuscript: Manuscript?
  private var projectedAvailability: HistorySnapshot?
  private var projectedEngineVersion: Int64?

  /// Called after coherent availability changes. Refresh views without creating another edit.
  public var didChange: (() -> Void)?
  /// The last host-accepted state, distinct from provisional native input.
  public var committedManuscript: Manuscript { committed }
  /// Token to retry finalization after a successfully published omission.
  /// Cancel it only while publication has not succeeded.
  public var pendingOmissionPublication: UUID? { omissionPublication }
  public var canUndo: Bool { availability.canUndo }
  public var canRedo: Bool { availability.canRedo }
  /// The exact scope, generation, and version used by native presentation.
  public var availability: HistorySnapshot {
    let source = engine?.snapshot ?? HistorySnapshot(
      canUndo: false, canRedo: false, isSuspended: false, hasPending: opening != nil)
    let prior = projectedAvailability
    let candidate = HistorySnapshot(
      canUndo: !omissionPending && source.canUndo,
      canRedo: !omissionPending && source.canRedo,
      isSuspended: omissionPending || source.isSuspended,
      hasPending: source.hasPending, scope: source.scope, generation: source.generation,
      version: prior?.version ?? 0)
    if let prior, projectedEngineVersion == source.version, candidate == prior { return prior }
    let projection = HistorySnapshot(
      canUndo: candidate.canUndo, canRedo: candidate.canRedo,
      isSuspended: candidate.isSuspended, hasPending: candidate.hasPending,
      scope: candidate.scope, generation: candidate.generation,
      version: (prior?.version ?? -1) + 1)
    projectedAvailability = projection
    projectedEngineVersion = source.version
    return projection
  }
  public var isPending: Bool { opening != nil || engine?.snapshot.hasPending == true }
  public var isSuspended: Bool { omissionPending || engine?.snapshot.isSuspended == true }
  public var canSave: Bool {
    !closed && engine != nil && !isPending && !isSuspended &&
      work?.manuscript == committed && work?.resources == committedResources
  }

  var hostDirectory: URL { directory.appendingPathComponent("Host") }
  var hostStore: URL { hostDirectory.appendingPathComponent("Work.sqlite") }
  var historyStore: URL { directory.appendingPathComponent("History.sqlite") }

  init(work: Work, packageURL: URL?, baseline: URL? = nil) throws {
    self.work = work
    committed = work.manuscript
    committedResources = work.resources
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "FolioHistory-" + UUID().uuidString)
    let setup = try Self.registrationSetup(packageURL: packageURL, workIdentifier: work.identifier)
    registration = setup.registration
    openMode = setup.mode
    try FileManager.default.createDirectory(at: hostDirectory, withIntermediateDirectories: true)
    do {
      if let packageURL {
        _ = try WorkStore.cloneOrCopy(
          packageURL.appendingPathComponent("Work.sqlite"), to: hostStore)
        _ = try work.resourceStore.write(to: hostDirectory)
        let source = packageURL.appendingPathComponent("History/History.sqlite")
        try WorkResourceStore.checkRegularFile(source)
        _ = try WorkStore.cloneOrCopy(source, to: historyStore)
      } else if let baseline {
        _ = try WorkStore.stageSave(
          workIdentifier: work.identifier, manuscript: committed,
          resources: work.resourceStore, from: baseline, to: hostDirectory)
      } else {
        _ = try WorkStore.stageSave(
          workIdentifier: work.identifier, manuscript: committed,
          resources: work.resourceStore, from: nil, to: hostDirectory)
      }
    } catch {
      try? FileManager.default.removeItem(at: directory)
      throw error
    }
  }

}
