// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import FolioKit
import Foundation
import UndoKit

// MARK: - Host values and receipts

/// The host's semantic input and compensation value for a coherent Work change.
struct WorkHistoryChange {
  let before: WorkHistoryState
  let after: WorkHistoryState
}

/// Canonical fingerprint input includes both authored state and resource membership.
private struct WorkHistoryCanonicalChange: Codable {
  let before: Data
  let after: Data

  static func encode(_ change: WorkHistoryChange) throws -> Data {
    let encoded = Self(
      before: try WorkHistoryStatePayload.encode(change.before),
      after: try WorkHistoryStatePayload.encode(change.after))
    let encoder = PropertyListEncoder()
    encoder.outputFormat = .binary
    return try encoder.encode(encoded)
  }

  func change() throws -> WorkHistoryChange {
    WorkHistoryChange(
      before: try WorkHistoryStatePayload.decode(before),
      after: try WorkHistoryStatePayload.decode(after))
  }
}

/// Domain evidence in the host receipt, independent of UndoKit's codec envelope.
private struct WorkHistoryStoredChange: Codable {
  let before: WorkHistoryStatePayload
  let after: WorkHistoryStatePayload

  init(_ change: WorkHistoryChange) {
    before = WorkHistoryStatePayload(change.before)
    after = WorkHistoryStatePayload(change.after)
  }

  func change() throws -> WorkHistoryChange {
    WorkHistoryChange(before: try before.state(), after: try after.state())
  }
}

private struct WorkHistoryStoredEffect: Codable {
  let member: UUID
  let undo: WorkHistoryStoredChange
  let redo: WorkHistoryStoredChange

  init(member: UUID, undo: WorkHistoryChange, redo: WorkHistoryChange) {
    self.member = member
    self.undo = WorkHistoryStoredChange(undo)
    self.redo = WorkHistoryStoredChange(redo)
  }

  func changes() throws -> (undo: WorkHistoryChange, redo: WorkHistoryChange) {
    (try undo.change(), try redo.change())
  }
}

private struct WorkHistoryEvidence: Codable {
  let generation: UUID
  let sequence: Int64
  let effects: [WorkHistoryStoredEffect]
}

// MARK: - Raw framework host adapter

/// The framework retains this handler, while its Work Session remains weakly owned.
/// The private host-store copy retains unresolved evidence until close.
@MainActor final class WorkHistoryAdapter {
  weak var session: WorkHistorySession?

  init(session: WorkHistorySession) { self.session = session }

  private static let changeCodec = "app.foliosuite.work.content.change.plist.binary"
  private static let stateCodec = "app.foliosuite.work.content.state.plist.binary"

  static func encodeChange(_ change: WorkHistoryChange) throws -> HistoryPayload {
    HistoryPayload(family: WorkHistorySession.family, version: 1,
      data: try WorkHistoryEncoding.encode(
        WorkHistoryCanonicalChange.encode(change), codec: changeCodec))
  }

  static func encodeState(_ state: WorkHistoryState) throws -> HistoryPayload {
    HistoryPayload(family: WorkHistorySession.family, version: 1,
      data: try WorkHistoryEncoding.encode(
        WorkHistoryStatePayload.encode(state), codec: stateCodec))
  }

  static func decodeState(_ payload: HistoryPayload) throws -> WorkHistoryState {
    guard payload.family == WorkHistorySession.family, payload.version == 1 else {
      throw HistoryFailure(.compatibility, stage: .delivery, disposition: .usable)
    }
    let bytes = try WorkHistoryEncoding.decodeBytes(from: payload.data, codec: stateCodec)
    return try WorkHistoryStatePayload.decode(bytes)
  }

  static func canonicalIntentData(for change: WorkHistoryChange) throws -> Data {
    try WorkHistoryCanonicalChange.encode(change)
  }

  // MARK: Host callbacks

  func deliver(_ delivery: HistoryDelivery) async -> HistoryHostOutcome {
    do {
      let changes = try delivery.members.map { member -> (UUID, WorkHistoryChange) in
        guard member.payload.family == WorkHistorySession.family, member.payload.version == 1 else {
          throw HistoryFailure(.compatibility, stage: .delivery, disposition: .usable)
        }
        let bytes = try WorkHistoryEncoding.decodeBytes(from: member.payload.data, codec: Self.changeCodec)
        guard bytes.count <= 16 * 1_024 * 1_024 else { throw WorkStore.malformed() }
        let canonical = try PropertyListDecoder().decode(WorkHistoryCanonicalChange.self, from: bytes)
        return (member.id, try canonical.change())
      }
      let outcome = execute(changes, token: delivery.token)
      switch outcome {
      case .rejected: return .rejected
      case .unresolved: return .unresolved
      case .failure(let failure): return .failure(failure)
      case .accepted(let effects):
        guard effects.map(\.memberID) == delivery.members.map(\.id) else { return .unresolved }
        return .accepted(effects)
      }
    } catch let failure as HistoryFailure {
      return .failure(failure)
    } catch {
      return .failure(HistoryFailure(.compatibility, stage: .delivery, disposition: .usable))
    }
  }

  // Recovery queries the durable receipt instead of repeating a possibly
  // accepted edit. Absence or unreadable evidence is unresolved, never no-effect.
  func outcome(for token: HistoryToken) async -> HistoryHostOutcome {
    guard let session else { return .unresolved }
    do {
      guard let receipt = try WorkStore.historyReceipt(
        at: session.hostStore, commandID: token.command) else { return .unresolved }
      return try outcome(receipt, token: token, session: session)
    } catch { return .unresolved }
  }

  // MARK: Atomic host evidence

  private func execute(_ members: [(UUID, WorkHistoryChange)], token: HistoryToken)
    -> HistoryHostOutcome {
    guard let session, let work = session.work, !session.closed, !session.omissionPending else {
      return .unresolved
    }
    do {
      if let receipt = try WorkStore.historyReceipt(
        at: session.hostStore, commandID: token.command) {
        return try outcome(receipt, token: token, session: session)
      }
      let stored = try WorkStore.readStore(at: session.hostStore)
      guard stored.identifier == work.identifier, stored.manuscript == session.committed,
        stored.resourceMembership == session.committedResources else {
        return .unresolved
      }
      var state = session.committedState
      var effects: [HistoryEffect] = []
      var storedEffects: [WorkHistoryStoredEffect] = []
      for (memberID, change) in members {
        guard state == change.before, change.before != change.after,
          change.after.manuscript.identifier == session.committed.identifier else {
          return try reject(token, session: session, work: work)
        }
        do {
          try work.resourceStore.validate(change.before.resources)
          try work.resourceStore.validate(change.after.resources)
        } catch { return try reject(token, session: session, work: work) }
        let undo = WorkHistoryChange(before: change.after, after: change.before)
        storedEffects.append(WorkHistoryStoredEffect(member: memberID, undo: undo, redo: change))
        effects.append(HistoryEffect(
          memberID: memberID, undo: try Self.payload(for: undo), redo: try Self.payload(for: change),
          resources: session.resourceReferences(for: change)))
        state = change.after
      }
      guard stageResources(work, session: session) else {
        return try reject(token, session: session, work: work)
      }
      let evidence = WorkHistoryEvidence(
        generation: token.generation, sequence: token.sequence,
        effects: storedEffects)
      try WorkStore.commitHistory(
        at: session.hostStore, workIdentifier: work.identifier,
        manuscript: state.manuscript, resources: state.resources,
        receipt: WorkStore.HistoryReceipt(
          commandID: token.command, fingerprint: Self.receiptFingerprint(token),
          accepted: true, evidence: try PropertyListEncoder().encode(evidence)))
      adoptAcceptedState(state, session: session, work: work)
      return .accepted(effects)
    } catch {
      // A save error cannot establish no effect; reconciliation reads the atomic receipt.
      return .unresolved
    }
  }

  private func adoptAcceptedState(
    _ state: WorkHistoryState, session: WorkHistorySession, work: Work
  ) {
    // Main-actor isolation does not prevent later input across async awaits.
    // Advance accepted state without erasing a newer provisional editor snapshot.
    let hasLaterProvisionalInput = work.manuscript != session.committed && work.manuscript != state.manuscript
    session.committed = state.manuscript
    session.committedResources = state.resources
    work.resourceStore.adoptValidated(state.resources)
    if !hasLaterProvisionalInput { work.manuscript = state.manuscript }
  }

  // Resource failure precedes semantic acceptance. A rejection still requires
  // the durable no-effect receipt; an unwritable host store remains unresolved.
  private func stageResources(_ work: Work, session: WorkHistorySession) -> Bool {
    do {
      _ = try work.resourceStore.write(to: session.hostDirectory, extending: true)
      return true
    } catch { return false }
  }

  private func reject(_ token: HistoryToken, session: WorkHistorySession, work: Work) throws
    -> HistoryHostOutcome {
    try WorkStore.commitHistory(
      at: session.hostStore, workIdentifier: work.identifier, manuscript: session.committed,
      resources: session.committedResources,
      receipt: WorkStore.HistoryReceipt(
        commandID: token.command, fingerprint: Self.receiptFingerprint(token),
        accepted: false, evidence: Data()))
    return .rejected
  }

  private func outcome(_ receipt: WorkStore.HistoryReceipt, token: HistoryToken,
                       session: WorkHistorySession) throws -> HistoryHostOutcome {
    guard receipt.fingerprint == Self.receiptFingerprint(token) else { return .unresolved }
    guard receipt.accepted else { return .rejected }
    let evidence = try PropertyListDecoder().decode(WorkHistoryEvidence.self, from: receipt.evidence)
    guard evidence.generation == token.generation, evidence.sequence == token.sequence else {
      return .unresolved
    }
    let effects = try evidence.effects.map {
      let changes = try $0.changes()
      return HistoryEffect(memberID: $0.member,
        undo: try Self.payload(for: changes.undo), redo: try Self.payload(for: changes.redo),
        resources: session.resourceReferences(for: changes.redo))
    }
    let stored = try WorkStore.readStore(at: session.hostStore)
    guard let work = session.work, stored.identifier == work.identifier else { return .unresolved }
    guard let resources = stored.resourceMembership else { return .unresolved }
    try work.resourceStore.select(resources)
    session.committedResources = resources
    let hasProvisionalInput = work.manuscript != session.committed
    session.committed = stored.manuscript
    if !hasProvisionalInput { work.manuscript = stored.manuscript }
    return .accepted(effects)
  }

  private static func payload(for change: WorkHistoryChange) throws -> HistoryPayload {
    try encodeChange(change)
  }

  private static func receiptFingerprint(_ token: HistoryToken) -> String {
    token.generation.uuidString + ":" + String(token.sequence)
  }
}

/// Nonisolated protocol bridge; all document and domain work stays on MainActor.
final class WorkHistoryHost: HistoryHost {
  private let adapter: WorkHistoryAdapter

  init(adapter: WorkHistoryAdapter) { self.adapter = adapter }

  func deliver(_ delivery: HistoryDelivery) async -> HistoryHostOutcome {
    await adapter.deliver(delivery)
  }

  func outcome(for token: HistoryToken) async -> HistoryHostOutcome {
    await adapter.outcome(for: token)
  }
}
