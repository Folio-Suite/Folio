// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import FolioKit
import Foundation
import UndoKit

extension WorkHistorySession {
  /// Import an immutable private file snapshot as one durable, undoable Work change.
  /// Settle provisional Manuscript edits first. A failure preserves accepted membership;
  /// an unresolved outcome fences later operations until reconciliation succeeds.
  /// - Parameter sourceURL: Accessible regular file, not a symbolic link.
  /// - Returns: New identity for the accepted immutable resource.
  /// - Throws: Busy/unsettled state, invalid resource input, file-system errors,
  ///   semantic rejection, or unresolved history delivery.
  /// Failed imports may retain conservative private bytes without adding membership.
  @discardableResult public func importResource(from sourceURL: URL) async throws -> FolioIdentifier {
    _ = try await ready()
    guard canSave, let work else { throw WorkHistoryError.busy }
    let previous = committedResources
    let identifier = try work.resourceStore.importResource(from: sourceURL)
    let proposed = work.resources
    work.resourceStore.adoptValidated(previous)
    // Secure the bytes in the recoverable host directory before UndoKit can deliver.
    _ = try work.resourceStore.write(to: hostDirectory, extending: true)
    try await submit(state: WorkHistoryState(manuscript: committed, resources: proposed), origin: nil)
    return identifier
  }

  /// Remove membership without deleting bytes needed by Undo, checkpoints or displaced history.
  /// Settle provisional Manuscript edits first. Missing identifiers create no transaction.
  /// - Parameter identifier: Identity in the accepted current membership.
  /// - Throws: A missing-resource error for an absent identity, busy/unsettled
  ///   state, semantic rejection, or history delivery/storage errors.
  public func removeResource(withIdentifier identifier: FolioIdentifier) async throws {
    _ = try await ready()
    guard canSave else { throw WorkHistoryError.busy }
    guard committedResources.contains(where: { $0.identifier == identifier }) else {
      throw WorkStore.missingResourceError()
    }
    let resources = committedResources.filter { $0.identifier != identifier }
    try await submit(state: WorkHistoryState(manuscript: committed, resources: resources), origin: nil)
  }

  func resourceReferences(_ resources: [WorkResource]) -> [HistoryObjectReference] {
    resources.map {
      HistoryObjectReference(storeID: registration.scope, objectKey: $0.identifier.rawValue,
                             versionKey: $0.sha256)
    }
  }

  func resourceReferences(for change: WorkHistoryChange) -> [HistoryObjectReference] {
    let references = resourceReferences(change.before.resources + change.after.resources)
    return Array(Set(references)).sorted { $0.objectKey < $1.objectKey }
  }
}
