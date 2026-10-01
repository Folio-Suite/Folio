// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import Foundation
import UndoKit

// This consumer is compiled with only UndoKit.framework on its framework path.
// A recipe-style host can choose a shorter ordinary Undo window without importing Folio.
@MainActor private final class RecipeHandler: MainActorHistoryOperationHandler {
    typealias Command = String
    typealias Effect = String
    typealias State = String

    func apply(_ commands: [(UUID, String)], context: HistoryOperationContext) async -> HistoryTypedOutcome<String> {
        _ = (commands, context.token, context.restorationOrigin)
        // No durable host store exists in this compile-only consumer.
        return .unresolved
    }

    func undo(_ effects: [(UUID, String)], context: HistoryOperationContext) async -> HistoryTypedOutcome<String> {
        _ = (effects, context.token, context.restorationOrigin)
        return .unresolved
    }

    func redo(_ effects: [(UUID, String)], context: HistoryOperationContext) async -> HistoryTypedOutcome<String> {
        _ = (effects, context.token, context.restorationOrigin)
        return .unresolved
    }

    func outcome(for token: HistoryToken) async -> HistoryTypedOutcome<String> {
        _ = token
        // A real host reads its own durable receipt. Absence cannot prove rejection.
        return .unresolved
    }
}

private func textCodec(_ identity: String) -> HistoryCodec<String> {
    HistoryCodec(identifier: identity,
        encode: { Data($0.utf8) },
        decode: { data in
            guard let value = String(data: data, encoding: .utf8) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return value
        })
}

@MainActor private func exercisePublicInterface(at storeURL: URL) async throws {
    let handler = RecipeHandler()
    let registration = try HistoryOperationRegistration(
        operation: "example.recipe.title",
        commandVersion: 1, effectVersion: 1, stateVersion: 1,
        commandCodec: textCodec("example.recipe.title.command.utf8"),
        effectCodec: textCodec("example.recipe.title.effect.utf8"),
        stateCodec: textCodec("example.recipe.title.state.utf8"),
        handler: handler)
    let host = MainActorHistoryRegisteredHost(registration)
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

    let payload = try handler.encodeState("A prior title", using: registration)
    let typedCommand = HistoryTypedCommand(
        fingerprint: Data("canonical intent".utf8), value: "New title",
        presentation: HistoryPayload(family: "example.recipe.title.label", data: Data("Rename".utf8)),
        expectedGeneration: transactions.snapshot.generation)
    switch await handler.submit(typedCommand, using: registration, to: transactions) {
    case .accepted(let receipt): _ = (receipt.token, receipt.groupID)
    case .rejected: break
    case .failure(let failure): _ = (failure.cause, failure.stage, failure.disposition)
    }
    _ = await transactions.undo(expectedGeneration: transactions.snapshot.generation)
    _ = await transactions.redo(expectedGeneration: transactions.snapshot.generation)
    _ = await transactions.reconcile()
    let restoredState = try handler.decodeState(payload, using: registration)
    _ = restoredState
    try exerciseRetainedHistory(history, retention: retention, state: payload)
    try await engine.close()
}

@MainActor private func exerciseRetainedHistory(
    _ history: any HistoryReading,
    retention: any HistoryRetentionManaging,
    state: HistoryPayload
) throws {
    let checkpointID = UUID()
    let checkpoint = try retention.createCheckpoint(
        id: checkpointID, name: "Before review", state: state)
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
}

print("UndoKit independent Swift consumer linked")
