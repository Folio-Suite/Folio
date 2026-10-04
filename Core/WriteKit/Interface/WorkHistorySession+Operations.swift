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
    let engine: any HistoryTransactions = try await transactions()
    if let result = await engine.reconcile() { try finish(result) }
    if engine.snapshot.isSuspended { throw WorkHistoryError.busy }
    didChange?()
  }

  func ready() async throws -> HistoryEngine {
    guard !closed else { throw WorkHistoryError.closed }
    if let engine { return engine }
    if let opening { return try await opening.value }
    let typed = try WorkHistoryAdapter.registration(for: self)
    let adapter = MainActorHistoryRegisteredHost(typed)
    typedRegistration = typed
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

  func transactions() async throws -> any HistoryTransactions {
    try await ready()
  }

  /// Submit a complete settled manuscript edit. Known no-ops create no transaction.
  public func submit(manuscript: Manuscript) async throws {
    try await submit(manuscript: manuscript, origin: nil)
  }

  func submit(manuscript: Manuscript, origin: UUID?) async throws {
    try await submit(state: WorkHistoryState(manuscript: manuscript, resources: committedResources),
                     origin: origin)
  }

  func submit(state: WorkHistoryState, origin: UUID?) async throws {
    guard !omissionPending else { throw WorkHistoryError.busy }
    let engine: any HistoryTransactions = try await transactions()
    guard state.manuscript.identifier == committed.identifier else { throw WorkHistoryError.rejected }
    guard state != committedState else { return }
    guard let typedRegistration else { throw WorkHistoryError.busy }
    let change = WorkHistoryChange(before: committedState, after: state)
    let fingerprint = Data(SHA256.hash(data: try WorkHistoryAdapter.canonicalIntentData(for: change)))
    let result = await typedRegistration.handler.submit(
      HistoryTypedCommand(
        fingerprint: fingerprint, value: change, restorationOrigin: origin,
        expectedGeneration: engine.snapshot.generation),
      using: typedRegistration, to: engine)
    try finish(result)
  }

  public func undo() async throws {
    guard !omissionPending else { throw WorkHistoryError.busy }
    let engine: any HistoryTransactions = try await transactions()
    try finish(await engine.undo(expectedGeneration: engine.snapshot.generation))
  }
  public func redo() async throws {
    guard !omissionPending else { throw WorkHistoryError.busy }
    let engine: any HistoryTransactions = try await transactions()
    try finish(await engine.redo(expectedGeneration: engine.snapshot.generation))
  }

  /// Select whether new ordinary edits are retained. Re-enabling saves a
  /// coherent Work baseline and cannot reconstruct edits made while Off.
  public func setRecording(_ mode: HistoryRecordingMode) async throws {
    let engine = try await ready()
    guard canSave else { throw WorkHistoryError.busy }
    if mode == .on {
      guard let typedRegistration else { throw WorkHistoryError.busy }
      _ = try engine.setRecording(.on,
        baseline: typedRegistration.handler.encodeState(committedState, using: typedRegistration),
        resources: resourceReferences(committedResources))
    } else {
      try engine.setRecording(.off)
    }
    didChange?()
  }

  /// Fence edits while the host publishes an omission of this coherent Work.
  /// Call after settling native input and before staging or safe replacement.
  /// The returned token identifies the save attempt and its later completion.
  public func beginOmissionPublication() throws -> UUID {
    guard canSave else { throw WorkHistoryError.busy }
    let token = UUID()
    omissionPublication = token
    omissionManuscript = committed
    omissionPhase = .publishing
    didChange?()
    return token
  }

  /// Release a publication fence after staging or safe replacement failed.
  /// Live Undo and retained history then become available again.
  public func cancelOmissionPublication(_ token: UUID) throws {
    guard omissionPhase == .publishing, omissionPublication == token else {
      throw WorkHistoryError.busy
    }
    omissionPhase = .none
    omissionPublication = nil
    omissionManuscript = nil
    didChange?()
  }

  /// Call only after a staged omission has replaced the saved Document.
  /// A failed publication must leave this session and its retained history intact.
  /// A post-publication failure is reported as such; the published package stays
  /// history-free. Retry this call if generation retirement or host-receipt
  /// cleanup fails; new edits and saves remain blocked until both succeed.
  public func completeOmissionAfterSave(_ token: UUID) throws {
    guard let engine else { throw WorkHistoryError.busy }
    guard omissionPublication == token, omissionManuscript == committed else {
      throw WorkHistoryError.busy
    }
    if omissionPhase == .publishing {
      omissionPhase = .retireGeneration
      didChange?()
    }
    if omissionPhase == .retireGeneration {
      guard let typedRegistration else { throw WorkHistoryError.busy }
      let baseline = try typedRegistration.handler.encodeState(committedState, using: typedRegistration)
      _ = try engine.clearHistory(adopting: baseline, resources: resourceReferences(committedResources))
      omissionPhase = .stripReceipts
      didChange?()
    }
    try WorkStore.stripHistoryReceipts(at: hostStore)
    omissionPhase = .none
    omissionPublication = nil
    omissionManuscript = nil
    didChange?()
  }

  /// Retry host-receipt cleanup after an explicit unresolved reset failed late.
  public func retryResetReceiptCleanup() throws {
    guard omissionPhase == .stripReceipts, omissionPublication == nil else {
      throw WorkHistoryError.busy
    }
    try WorkStore.stripHistoryReceipts(at: hostStore)
    omissionPhase = .none
    didChange?()
  }

  /// Acknowledge irrecoverable history continuity after the host has verified its
  /// coherent current Manuscript. The failed history store is copied to an absent
  /// quarantine URL before a new generation is installed. A post-reset receipt
  /// cleanup failure blocks saves; retry `retryResetReceiptCleanup()` to finish it.
  @discardableResult public func resetUnresolvedHistory(
    adopting manuscript: Manuscript, quarantineAt destination: URL
  ) throws -> UUID {
    guard !closed, !omissionPending, let engine, let work,
      manuscript.identifier == committed.identifier,
      try WorkStore.readStore(at: hostStore).manuscript == manuscript else {
      throw WorkHistoryError.busy
    }
    guard let typedRegistration else { throw WorkHistoryError.busy }
    guard let resources = try WorkStore.readStore(at: hostStore).resourceMembership else {
      throw WorkHistoryError.invalidPackage
    }
    try work.resourceStore.validate(resources)
    let baseline = try typedRegistration.handler.encodeState(
      WorkHistoryState(manuscript: manuscript, resources: resources), using: typedRegistration)
    let generation = try engine.resetUnresolvedHistory(
      adopting: baseline, resources: resourceReferences(resources), quarantineAt: destination)
    committed = manuscript
    committedResources = resources
    work.resourceStore.adoptValidated(resources)
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

  /// Capture a recoverable Manuscript and its current resource membership. The document host must save successfully before announcing a saved checkpoint.
  public func createCheckpoint(name: String) async throws -> UUID {
    let retention: any HistoryRetentionManaging = try await ready()
    guard canSave else { throw WorkHistoryError.busy }
    guard let typedRegistration else { throw WorkHistoryError.busy }
    let id = UUID()
    _ = try retention.createCheckpoint(
      id: id, name: name,
      state: typedRegistration.handler.encodeState(committedState, using: typedRegistration),
      resources: resourceReferences(committedResources))
    didChange?()
    return id
  }

  /// Restore through a new undoable edit; the displaced continuation remains in history.
  public func restore(checkpointID: UUID) async throws {
    let history: any HistoryReading = try await ready()
    guard let typedRegistration,
      let checkpoint = try history.checkpoint(id: checkpointID) else {
      throw WorkHistoryError.invalidPackage
    }
    try await submit(
      state: typedRegistration.handler.decodeState(checkpoint.state, using: typedRegistration),
      origin: checkpointID)
  }

  /// Fetch at most one bounded page of checkpoint metadata for a compact or window-based host presentation.
  public func checkpoints(limit: Int = 100) throws -> [WorkCheckpoint] {
    guard let engine else { return [] }
    let history: any HistoryReading = engine
    return try history.checkpoints(after: nil, limit: limit).map {
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
    guard let work else { throw WorkHistoryError.busy }
    if omittingHistory {
      guard omissionPhase == .publishing, omissionManuscript == committed,
        work.manuscript == committed, !isPending, !engineSnapshotSuspended else {
        throw WorkHistoryError.busy
      }
    } else {
      guard canSave else { throw WorkHistoryError.busy }
    }
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

  private var engineSnapshotSuspended: Bool { engine?.snapshot.isSuspended ?? true }
}
