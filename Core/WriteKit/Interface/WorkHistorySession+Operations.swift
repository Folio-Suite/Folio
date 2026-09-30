// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import CryptoKit
import FolioKit
import Foundation
import UndoKit

extension WorkHistorySession {
  static func registrationSetup(
    packageURL: URL?, workIdentifier: FolioIdentifier
  ) throws -> (registration: WorkHistoryRegistration, mode: HistoryOpenMode) {
    guard let packageURL else {
      return (
        WorkHistoryRegistration(
          version: 1, work: workIdentifier.rawValue,
          scope: UUID(), workingIdentity: UUID()),
        .create)
    }
    let history = packageURL.appendingPathComponent("History")
    let values = try history.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
    guard values.isDirectory == true, values.isSymbolicLink != true,
      Set(try FileManager.default.contentsOfDirectory(atPath: history.path)) == [
        "Registration.plist", "History.sqlite",
      ]
    else {
      throw WorkHistoryError.invalidPackage
    }
    let registrationURL = history.appendingPathComponent("Registration.plist")
    try WorkResourceStore.checkRegularFile(registrationURL)
    guard
      (try registrationURL.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? Int.max < 65_536
    else {
      throw WorkHistoryError.invalidPackage
    }
    let saved = try PropertyListDecoder().decode(
      WorkHistoryRegistration.self, from: Data(contentsOf: registrationURL))
    guard saved.version == 1, saved.work == workIdentifier.rawValue else {
      throw WorkHistoryError.invalidPackage
    }
    return (
      WorkHistoryRegistration(
        version: 1, work: saved.work, scope: saved.scope, workingIdentity: UUID()),
      .independentCopy(sourceWorkingIdentity: saved.workingIdentity))
  }

  /// Reconcile any delivered command from durable host receipts before enabling Undo/Redo.
  public func reconcile() async throws {
    guard !omissionPending else { throw WorkHistoryError.busy }
    let engine = try await ready()
    if let result = await engine.reconcile() { try finish(result) }
    if engine.snapshot.isSuspended { throw WorkHistoryError.busy }
    didChange?()
  }

  func ready() async throws -> HistoryEngine {
    guard !closed else { throw WorkHistoryError.closed }
    if let engine { return engine }
    if let opening { return try await opening.value }
    let adapter = Adapter(session: self)
    host = adapter
    let url = historyStore
    let registration = registration
    let mode = openMode
    let task = Task { @MainActor in
      try await HistoryEngine.open(
        at: url, scope: registration.scope,
        workingIdentity: registration.workingIdentity, mode: mode, host: adapter,
        limits: HistoryLimits())
    }
    opening = task
    defer { opening = nil }
    let opened = try await task.value
    engine = opened
    opened.snapshotDidChange = { [weak self] _ in self?.didChange?() }
    return opened
  }

  /// Submit a complete settled manuscript edit. Known no-ops create no transaction.
  public func submit(manuscript: Manuscript) async throws {
    try await submit(manuscript: manuscript, origin: nil)
  }

  func submit(manuscript: Manuscript, origin: UUID?) async throws {
    guard !omissionPending else { throw WorkHistoryError.busy }
    let engine = try await ready()
    guard manuscript.identifier == committed.identifier else { throw WorkHistoryError.rejected }
    guard manuscript != committed else { return }
    let before = try WorkHistoryPayload.encode(committed)
    let after = try WorkHistoryPayload.encode(manuscript)
    let payload = try encodeChange(before: before, after: after)
    let result = await engine.submit(
      HistoryCommand(
        fingerprint: Data(SHA256.hash(data: payload.data)),
        payload: payload, restorationOrigin: origin,
        expectedGeneration: engine.snapshot.generation))
    try finish(result)
  }

  public func undo() async throws {
    guard !omissionPending else { throw WorkHistoryError.busy }
    let engine = try await ready()
    try finish(await engine.undo(expectedGeneration: engine.snapshot.generation))
  }
  public func redo() async throws {
    guard !omissionPending else { throw WorkHistoryError.busy }
    let engine = try await ready()
    try finish(await engine.redo(expectedGeneration: engine.snapshot.generation))
  }

  /// Select whether new ordinary edits are retained. Re-enabling saves a
  /// coherent Manuscript baseline and cannot reconstruct edits made while Off.
  public func setRecording(_ mode: HistoryRecordingMode) async throws {
    let engine = try await ready()
    guard canSave else { throw WorkHistoryError.busy }
    if mode == .on {
      _ = try engine.setRecording(.on,
        baseline: HistoryPayload(family: Self.family, data: try WorkHistoryPayload.encode(committed)))
    } else {
      try engine.setRecording(.off)
    }
    didChange?()
  }

  /// Call only after a staged omission has replaced the saved Document.
  /// A failed publication must leave this session and its retained history intact.
  /// A post-publication failure is reported as such; the published package stays
  /// history-free. Retry this call if generation retirement or host-receipt
  /// cleanup fails; new edits and saves remain blocked until both succeed.
  public func completeOmissionAfterSave() throws {
    guard let engine else { throw WorkHistoryError.busy }
    if omissionPhase == .none {
      guard canSave else { throw WorkHistoryError.busy }
      omissionPhase = .retireGeneration
      didChange?()
    }
    if omissionPhase == .retireGeneration {
      let baseline = HistoryPayload(family: Self.family,
                                    data: try WorkHistoryPayload.encode(committed))
      _ = try engine.clearHistory(adopting: baseline)
      omissionPhase = .stripReceipts
      didChange?()
    }
    try WorkStore.stripHistoryReceipts(at: hostStore)
    omissionPhase = .none
    didChange?()
  }

  /// Acknowledge irrecoverable history continuity after the host has verified its
  /// coherent current Manuscript. The failed history store is copied to an absent
  /// quarantine URL before a new generation is installed. A post-reset receipt
  /// cleanup failure blocks saves; retry `completeOmissionAfterSave()` to finish it.
  @discardableResult public func resetUnresolvedHistory(
    adopting manuscript: Manuscript, quarantineAt destination: URL
  ) throws -> UUID {
    guard !closed, !omissionPending, let engine, let work,
      manuscript.identifier == committed.identifier,
      try WorkStore.readStore(at: hostStore).manuscript == manuscript else {
      throw WorkHistoryError.busy
    }
    let baseline = HistoryPayload(family: Self.family,
                                  data: try WorkHistoryPayload.encode(manuscript))
    let generation = try engine.resetUnresolvedHistory(
      adopting: baseline, quarantineAt: destination)
    committed = manuscript
    work.manuscript = manuscript
    omissionPhase = .stripReceipts
    didChange?()
    try WorkStore.stripHistoryReceipts(at: hostStore)
    omissionPhase = .none
    didChange?()
    return generation
  }

  func finish(_ result: HistoryResult) throws {
    didChange?()
    switch result {
    case .accepted: break
    case .rejected: throw WorkHistoryError.rejected
    case .failure(let failure): throw failure
    }
  }

  /// Capture a recoverable Manuscript. The document host must save successfully before announcing a saved checkpoint.
  public func createCheckpoint(name: String) async throws -> UUID {
    let engine = try await ready()
    guard canSave else { throw WorkHistoryError.busy }
    let id = UUID()
    _ = try engine.createCheckpoint(
      id: id, name: name,
      state: HistoryPayload(family: Self.family, data: WorkHistoryPayload.encode(committed)))
    didChange?()
    return id
  }

  /// Restore through a new undoable edit; the displaced continuation remains in history.
  public func restore(checkpointID: UUID) async throws {
    let engine = try await ready()
    guard let checkpoint = try engine.checkpoint(id: checkpointID),
      checkpoint.state.family == Self.family, checkpoint.state.version == 1
    else {
      throw WorkHistoryError.invalidPackage
    }
    try await submit(
      manuscript: WorkHistoryPayload.decode(checkpoint.state.data), origin: checkpointID)
  }

  /// Fetch at most one bounded page of checkpoint metadata for a compact or window-based host presentation.
  public func checkpoints(limit: Int = 100) throws -> [WorkCheckpoint] {
    guard let engine else { return [] }
    return try engine.checkpoints(limit: limit).map {
      WorkCheckpoint(id: $0.id, name: $0.name ?? "", recordedAt: $0.recordedAt)
    }
  }

  /// Finish delivered work and release ownership. No further operations are accepted by this session.
  public func close() async throws {
    if let opening { engine = try await opening.value }
    let preserveRecovery = isSuspended
    try await engine?.close()
    closed = true
    if !preserveRecovery && !isSuspended { try? FileManager.default.removeItem(at: directory) }
  }

  func stageSave(resources: WorkResourceStore, to destination: URL,
                 omittingHistory: Bool = false) throws -> WorkSaveReport {
    guard canSave, let work else { throw WorkHistoryError.busy }
    let report = try WorkStore.stageSave(
      workIdentifier: work.identifier, manuscript: committed,
      resources: resources, from: hostDirectory, to: destination,
      omitHistoryReceipts: omittingHistory)
    if omittingHistory { return report }
    let history = destination.appendingPathComponent("History")
    try FileManager.default.createDirectory(at: history, withIntermediateDirectories: false)
    guard let engine else { throw WorkHistoryError.busy }
    try engine.copyStore(to: history.appendingPathComponent("History.sqlite"))
    let encoder = PropertyListEncoder()
    encoder.outputFormat = .xml
    try encoder.encode(registration).write(
      to: history.appendingPathComponent("Registration.plist"), options: .atomic)
    try WorkResourceStore.markHistory(in: destination)
    return report
  }

  func encodeChange(before: Data, after: Data) throws -> HistoryPayload {
    let encoder = PropertyListEncoder()
    encoder.outputFormat = .binary
    return HistoryPayload(
      family: Self.family,
      data: try encoder.encode(WorkHistoryChange(before: before, after: after)))
  }

  func deliver(_ delivery: HistoryDelivery) -> HistoryHostOutcome {
    guard let work, !closed, !omissionPending else { return .unresolved }
    do {
      if let receipt = try WorkStore.historyReceipt(
        at: hostStore, commandID: delivery.token.command) {
        return try outcome(receipt, token: delivery.token)
      }
      let stored = try WorkStore.readStore(at: hostStore)
      guard stored.identifier == work.identifier, stored.manuscript == committed else {
        return .unresolved
      }
      var state = committed
      var effects: [HistoryEffect] = []
      for member in delivery.members {
        guard member.payload.family == Self.family, member.payload.version == 1,
          member.payload.data.count <= 16 * 1_024 * 1_024
        else {
          return try reject(delivery.token)
        }
        let change = try PropertyListDecoder().decode(WorkHistoryChange.self, from: member.payload.data)
        let before = try WorkHistoryPayload.decode(change.before)
        let after = try WorkHistoryPayload.decode(change.after)
        guard state == before, before != after, after.identifier == committed.identifier else {
          return try reject(delivery.token)
        }
        effects.append(
          HistoryEffect(
            memberID: member.id,
            undo: try encodeChange(before: change.after, after: change.before), redo: member.payload
          ))
        state = after
      }
      let evidence = WorkHistoryEvidence(
        generation: delivery.token.generation, sequence: delivery.token.sequence,
        effects: effects.map {
          WorkHistoryEffect(member: $0.memberID, undo: $0.undo.data, redo: $0.redo.data)
        })
      let encoded = try PropertyListEncoder().encode(evidence)
      try WorkStore.commitHistory(
        at: hostStore, workIdentifier: work.identifier, manuscript: state,
        receipt: WorkStore.HistoryReceipt(
          commandID: delivery.token.command,
          fingerprint: delivery.token.generation.uuidString + ":" + String(delivery.token.sequence),
          accepted: true, evidence: encoded))
      let hasLaterProvisionalInput = work.manuscript != committed && work.manuscript != state
      committed = state
      if !hasLaterProvisionalInput { work.manuscript = state }
      return .accepted(effects)
    } catch {
      // A save error is not evidence of rejection. Look up the atomic host receipt on reconciliation.
      return .unresolved
    }
  }

  func reject(_ token: HistoryToken) throws -> HistoryHostOutcome {
    guard let work else { return .unresolved }
    try WorkStore.commitHistory(
      at: hostStore, workIdentifier: work.identifier, manuscript: committed,
      receipt: WorkStore.HistoryReceipt(
        commandID: token.command,
        fingerprint: token.generation.uuidString + ":" + String(token.sequence), accepted: false,
        evidence: Data()))
    return .rejected
  }

  func outcome(_ receipt: WorkStore.HistoryReceipt, token: HistoryToken) throws
    -> HistoryHostOutcome {
    guard receipt.fingerprint == token.generation.uuidString + ":" + String(token.sequence) else {
      return .unresolved
    }
    guard receipt.accepted else { return .rejected }
    let evidence = try PropertyListDecoder().decode(WorkHistoryEvidence.self, from: receipt.evidence)
    guard evidence.generation == token.generation, evidence.sequence == token.sequence else {
      return .unresolved
    }
    let stored = try WorkStore.readStore(at: hostStore)
    guard let work, stored.identifier == work.identifier else { return .unresolved }
    let hasProvisionalInput = work.manuscript != committed
    committed = stored.manuscript
    if !hasProvisionalInput { work.manuscript = stored.manuscript }
    return .accepted(
      evidence.effects.map {
        HistoryEffect(
          memberID: $0.member, undo: HistoryPayload(family: Self.family, data: $0.undo),
          redo: HistoryPayload(family: Self.family, data: $0.redo))
      })
  }
}
