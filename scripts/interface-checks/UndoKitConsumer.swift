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
    engine.snapshotDidChange = { snapshot in
        _ = (snapshot.canUndo, snapshot.canRedo, snapshot.hasPending, snapshot.isSuspended)
    }

    let payload = HistoryPayload(family: "example.recipe.title", data: Data("New title".utf8))
    let command = HistoryCommand(fingerprint: Data("canonical intent".utf8), payload: payload)
    switch await engine.submit(command) {
    case .accepted(let receipt): _ = (receipt.token, receipt.groupID)
    case .rejected: break
    case .failure(let failure): _ = (failure.cause, failure.stage, failure.disposition)
    }
    _ = await engine.undo()
    _ = await engine.redo()
    let checkpoint = try engine.createCheckpoint(name: "Before review", state: payload)
    _ = try engine.checkpoint(id: checkpoint.id)
    _ = try engine.checkpoints(limit: 20)
    _ = try engine.historyPage(limit: 20)
    try await engine.close()
}

print("UndoKit independent Swift consumer linked")
