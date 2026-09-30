// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import CryptoKit
import FolioKit
import Foundation
import UndoKit

/// A host validation or lifecycle failure. Existing content and history remain available for recovery.
public enum WorkHistoryError: Error, LocalizedError {
  case busy, rejected, resourceEditingUnsupported, invalidPackage, closed

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
    case .resourceEditingUnsupported:
      return NSLocalizedString(
        "work-history.resources-unsupported", tableName: nil, bundle: WorkStore.bundle,
        value: "Resource changes are not yet supported while durable history is enabled.",
        comment: "First implementation supports manuscript history but not resource changes.")
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

/// Work's adapter for durable manuscript edits. Callers settle provisional editing before submission.
/// This first operation preserves the resource set captured when history is enabled; resource editing is disabled.
/// Calls and callbacks are main-actor isolated. A failed submission may require `reconcile()` before editing resumes.
struct WorkHistoryRegistration: Codable {
  let version: Int
  let work: String
  let scope: UUID
  let workingIdentity: UUID
}

struct WorkHistoryChange: Codable {
  let before: Data
  let after: Data
}

struct WorkHistoryEffect: Codable {
  let member: UUID
  let undo: Data
  let redo: Data
}

struct WorkHistoryEvidence: Codable {
  let generation: UUID
  let sequence: Int64
  let effects: [WorkHistoryEffect]
}

@MainActor public final class WorkHistorySession {
  static let family = "app.foliosuite.work.manuscript.replace"
  weak var work: Work?
  let directory: URL
  let registration: WorkHistoryRegistration
  let openMode: HistoryOpenMode
  var committed: Manuscript
  var engine: HistoryEngine?
  var opening: Task<HistoryEngine, Error>?
  var host: Adapter?
  var closed = false

  /// Called after coherent availability changes. Refresh views without creating another edit.
  public var didChange: (() -> Void)?
  /// The last host-accepted state, distinct from provisional native input.
  public var committedManuscript: Manuscript { committed }
  public var canUndo: Bool { engine?.snapshot.canUndo ?? false }
  public var canRedo: Bool { engine?.snapshot.canRedo ?? false }
  public var isPending: Bool { opening != nil || engine?.snapshot.hasPending == true }
  public var isSuspended: Bool { engine?.snapshot.isSuspended ?? false }
  public var canSave: Bool {
    !closed && engine != nil && !isPending && !isSuspended && work?.manuscript == committed
  }

  var hostDirectory: URL { directory.appendingPathComponent("Host") }
  var hostStore: URL { hostDirectory.appendingPathComponent("Work.sqlite") }
  var historyStore: URL { directory.appendingPathComponent("History.sqlite") }

  init(work: Work, packageURL: URL?, baseline: URL? = nil) throws {
    self.work = work
    committed = work.manuscript
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

  // The private copy retains unresolved evidence until close. A process crash never edits the saved original.
  final class Adapter: HistoryHost {
    weak var session: WorkHistorySession?
    init(session: WorkHistorySession) { self.session = session }
    func deliver(_ delivery: HistoryDelivery) async -> HistoryHostOutcome {
      session?.deliver(delivery) ?? .unresolved
    }
    func outcome(for token: HistoryToken) async -> HistoryHostOutcome {
      guard let session else { return .unresolved }
      do {
        guard
          let receipt = try WorkStore.historyReceipt(
            at: session.hostStore, commandID: token.command)
        else {
          return .unresolved
        }
        return try session.outcome(receipt, token: token)
      } catch { return .unresolved }
    }
  }
}
