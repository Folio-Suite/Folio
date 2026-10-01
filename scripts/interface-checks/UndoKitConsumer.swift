// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import Foundation
import UndoKit

// This consumer is compiled with only UndoKit.framework on its framework path.
// A recipe-style host can choose a shorter ordinary Undo window without importing Folio.
@MainActor private final class RecipeHost: HistoryHost {
    func deliver(_ delivery: HistoryDelivery) async -> HistoryHostOutcome {
        guard let member = delivery.members.first else { return .rejected }
        let inverse = HistoryPayload(family: member.payload.family, data: Data())
        _ = HistoryEffect(memberID: member.id, undo: inverse, redo: member.payload)
        // This compile-only example has no domain store to prove an accepted effect.
        return .unresolved
    }

    func outcome(for token: HistoryToken) async -> HistoryHostOutcome {
        // A real host reads its own durable receipt. Absence cannot prove rejection.
        .unresolved
    }
}

@MainActor private func exercisePublicInterface(at storeURL: URL) async throws {
    let host = RecipeHost()
    let limits = HistoryLimits(maxUndoGroups: 100)
    let scope = UUID()
    let engine = try await HistoryEngine.open(at: storeURL, scope: scope,
        workingIdentity: UUID(), mode: .create, host: host, limits: limits)
    let transactions: any HistoryTransactions = engine
    let history: any HistoryReading = engine
    let retention: any HistoryRetentionManaging = engine
    transactions.snapshotDidChange = { snapshot in
        _ = (snapshot.canUndo, snapshot.canRedo, snapshot.hasPending, snapshot.isSuspended)
    }

    let payload = HistoryPayload(family: "example.recipe.title", data: Data("New title".utf8))
    let command = HistoryCommand(fingerprint: Data("canonical intent".utf8), payload: payload)
    switch await transactions.submit(command) {
    case .accepted(let receipt): _ = (receipt.token, receipt.groupID)
    case .rejected: break
    case .failure(let failure): _ = (failure.cause, failure.stage, failure.disposition)
    }
    _ = await transactions.undo(expectedGeneration: transactions.snapshot.generation)
    _ = await transactions.redo(expectedGeneration: transactions.snapshot.generation)
    _ = await transactions.reconcile()
    let checkpointID = UUID()
    let checkpoint = try retention.createCheckpoint(
        id: checkpointID, name: "Before review", state: payload)
    _ = try history.checkpoint(id: checkpoint.id)
    _ = try history.checkpoints(limit: 20)
    _ = try history.historyPage(limit: 20)
    let identity = try history.readIdentity()
    _ = try history.presentation(forGroup: identity.latestGroupID ?? UUID())
    _ = try history.nativeActionNames(resolve: { _ in nil })

    let plan = try history.beginRecoveryPlan(
        to: .checkpoint(checkpoint.id), using: .acceptedEffects)
    let page = try history.recoveryPage(plan, limit: 20)
    _ = try history.recoveryCheckpoint(plan)
    for step in page.steps {
        for ordinal in 0..<step.memberCount {
            _ = try history.recoveryMaterial(plan, groupID: step.groupID, ordinal: ordinal)
        }
    }
    history.releaseRecoveryPlan(plan)

    let hold = try retention.holdState(checkpoint.id)
    _ = try retention.retentionHolds()
    try retention.releaseHold(hold.id)
    _ = try retention.consolidateHistory(
        through: checkpoint.id, policy: HistoryRetentionPolicy(targetDetailedGroups: 100))
    try await engine.close()
}

print("UndoKit independent Swift consumer linked")
