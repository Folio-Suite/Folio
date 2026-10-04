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

  init(_ effect: HistoryTypedEffect<WorkHistoryChange>) {
    member = effect.memberID
    undo = WorkHistoryStoredChange(effect.undo)
    redo = WorkHistoryStoredChange(effect.redo)
  }

  func effect() throws -> HistoryTypedEffect<WorkHistoryChange> {
    HistoryTypedEffect(memberID: member, undo: try undo.change(), redo: try redo.change())
  }
}

private struct WorkHistoryEvidence: Codable {
  let generation: UUID
  let sequence: Int64
  let effects: [WorkHistoryStoredEffect]
}

// MARK: - Typed operation handler

/// The framework retains this handler, while its Work Session remains weakly owned.
/// The private host-store copy retains unresolved evidence until close.
@MainActor final class WorkHistoryAdapter: MainActorHistoryOperationHandler {
  typealias Command = WorkHistoryChange
  typealias Effect = WorkHistoryChange
  typealias State = WorkHistoryState

  weak var session: WorkHistorySession?

  init(session: WorkHistorySession) { self.session = session }

  // MARK: Registration and fingerprint input

  static func registration(for session: WorkHistorySession) throws
    -> HistoryOperationRegistration<WorkHistoryAdapter> {
    let changeCodec = HistoryCodec<WorkHistoryChange>(
      identifier: "app.foliosuite.work.content.change.plist.binary",
      encode: { try WorkHistoryCanonicalChange.encode($0) },
      decode: { data in
        guard data.count <= 16 * 1_024 * 1_024 else { throw WorkStore.malformed() }
        let stored = try PropertyListDecoder().decode(WorkHistoryCanonicalChange.self, from: data)
        return WorkHistoryChange(
          before: try WorkHistoryStatePayload.decode(stored.before),
          after: try WorkHistoryStatePayload.decode(stored.after))
      })
    let stateCodec = HistoryCodec<WorkHistoryState>(
      identifier: "app.foliosuite.work.content.state.plist.binary",
      encode: { try WorkHistoryStatePayload.encode($0) },
      decode: { try WorkHistoryStatePayload.decode($0) })
    return try HistoryOperationRegistration(
      operation: WorkHistorySession.family,
      commandCodec: changeCodec, effectCodec: changeCodec,
      stateCodec: stateCodec, handler: WorkHistoryAdapter(session: session))
  }

  static func canonicalIntentData(for change: WorkHistoryChange) throws -> Data {
    try WorkHistoryCanonicalChange.encode(change)
  }

  // MARK: Host callbacks

  func apply(_ commands: [(UUID, WorkHistoryChange)], context: HistoryOperationContext) async
    -> HistoryTypedOutcome<WorkHistoryChange> {
    execute(commands, token: context.token)
  }

  func undo(_ effects: [(UUID, WorkHistoryChange)], context: HistoryOperationContext) async
    -> HistoryTypedOutcome<WorkHistoryChange> {
    execute(effects, token: context.token)
  }

  func redo(_ effects: [(UUID, WorkHistoryChange)], context: HistoryOperationContext) async
    -> HistoryTypedOutcome<WorkHistoryChange> {
    execute(effects, token: context.token)
  }

  func outcome(for token: HistoryToken) async -> HistoryTypedOutcome<WorkHistoryChange> {
    guard let session else { return .unresolved }
    do {
      guard let receipt = try WorkStore.historyReceipt(
        at: session.hostStore, commandID: token.command) else { return .unresolved }
      return try outcome(receipt, token: token, session: session)
    } catch { return .unresolved }
  }

  // MARK: Atomic host evidence

  private func execute(_ members: [(UUID, WorkHistoryChange)], token: HistoryToken)
    -> HistoryTypedOutcome<WorkHistoryChange> {
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
      var effects: [HistoryTypedEffect<WorkHistoryChange>] = []
      for (memberID, change) in members {
        guard state == change.before, change.before != change.after,
          change.after.manuscript.identifier == session.committed.identifier else {
          return try reject(token, session: session, work: work)
        }
        do {
          try work.resourceStore.validate(change.before.resources)
          try work.resourceStore.validate(change.after.resources)
        } catch { return try reject(token, session: session, work: work) }
        effects.append(HistoryTypedEffect(
          memberID: memberID,
          undo: WorkHistoryChange(before: change.after, after: change.before),
          redo: change, resources: session.resourceReferences(for: change)))
        state = change.after
      }
      // Immutable bytes are already secured before the authoritative membership/receipt save.
      do {
        _ = try work.resourceStore.write(to: session.hostDirectory, extending: true)
      } catch {
        // No semantic transaction has started. Persist authoritative no-effect
        // if the host store remains writable; otherwise reconciliation stays unresolved.
        return try reject(token, session: session, work: work)
      }
      let evidence = WorkHistoryEvidence(
        generation: token.generation, sequence: token.sequence,
        effects: effects.map(WorkHistoryStoredEffect.init))
      try WorkStore.commitHistory(
        at: session.hostStore, workIdentifier: work.identifier,
        manuscript: state.manuscript, resources: state.resources,
        receipt: WorkStore.HistoryReceipt(
          commandID: token.command, fingerprint: Self.receiptFingerprint(token),
          accepted: true, evidence: try PropertyListEncoder().encode(evidence)))
      let hasLaterProvisionalInput = work.manuscript != session.committed && work.manuscript != state.manuscript
      session.committed = state.manuscript
      session.committedResources = state.resources
      work.resourceStore.adoptValidated(state.resources)
      if !hasLaterProvisionalInput { work.manuscript = state.manuscript }
      return .accepted(effects)
    } catch {
      // A save error cannot establish no effect; reconciliation reads the atomic receipt.
      return .unresolved
    }
  }

  private func reject(_ token: HistoryToken, session: WorkHistorySession, work: Work) throws
    -> HistoryTypedOutcome<WorkHistoryChange> {
    try WorkStore.commitHistory(
      at: session.hostStore, workIdentifier: work.identifier, manuscript: session.committed,
      resources: session.committedResources,
      receipt: WorkStore.HistoryReceipt(
        commandID: token.command, fingerprint: Self.receiptFingerprint(token),
        accepted: false, evidence: Data()))
    return .rejected
  }

  private func outcome(_ receipt: WorkStore.HistoryReceipt, token: HistoryToken,
                       session: WorkHistorySession) throws -> HistoryTypedOutcome<WorkHistoryChange> {
    guard receipt.fingerprint == Self.receiptFingerprint(token) else { return .unresolved }
    guard receipt.accepted else { return .rejected }
    let evidence = try PropertyListDecoder().decode(WorkHistoryEvidence.self, from: receipt.evidence)
    guard evidence.generation == token.generation, evidence.sequence == token.sequence else {
      return .unresolved
    }
    let effects = try evidence.effects.map {
      let effect = try $0.effect()
      return HistoryTypedEffect(memberID: effect.memberID, undo: effect.undo, redo: effect.redo,
                                resources: session.resourceReferences(for: effect.redo))
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

  private static func receiptFingerprint(_ token: HistoryToken) -> String {
    token.generation.uuidString + ":" + String(token.sequence)
  }
}
