// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import Foundation
import UndoKit

// This consumer is compiled with only UndoKit.framework on its framework path.
// It proves API shape; it does not provide a durable domain host or runtime proof.
@MainActor private final class RecipeLease: HistoryHostLease {
    func open(_ mode: HistoryOpenMode) async throws { _ = mode }
    func close() async throws {}
}

@MainActor private final class RecipeHandler: MainActorHistoryOperationHandler {
    typealias Command = String
    typealias Effect = String

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

private func textCodec() -> HistoryCodec<String> {
    HistoryCodec(identifier: "example.recipe.title.utf8",
        encode: { Data($0.utf8) },
        decode: { data in
            guard let value = String(data: data, encoding: .utf8) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return value
        })
}

@MainActor private func exercisePublicInterface(at storeURL: URL) async throws {
    let operation = try HistoryOperation(
        operation: "example.recipe.title",
        commandCodec: textCodec(),
        effectCodec: textCodec(),
        handler: RecipeHandler(),
        fingerprint: { commands in Data(commands.joined(separator: "\n").utf8) },
        metadata: { _ in
            HistoryOperationMetadata(presentation: HistoryPayload(
                family: "example.recipe.title.label", data: Data("Rename".utf8)))
        })

    let limits = HistoryLimits(maxUndoGroups: 100)
    let configuration = HistorySessionConfiguration(
        historyURL: storeURL,
        scope: UUID(),
        workingIdentity: UUID(),
        mode: .create,
        limits: limits)
    let sessions = HistorySessions()
    let lease = RecipeLease()
    let session = await sessions.open(
        configuration: configuration, lease: lease, operations: [operation.erased])
    let commands = try session.commands(for: operation)
    let history = session.advanced

    let typedCommand = "New title"
    _ = await commands.submit(typedCommand)
    _ = await session.undo()
    _ = await session.redo()
    _ = await session.reconcile()

    let state = HistoryPayload(family: "example.recipe.title.state", data: Data("A prior title".utf8))
    try exerciseRetainedHistory(history, state: state)
    await session.close()
}

@MainActor private func exerciseRetainedHistory(
    _ history: HistorySessionAdvanced,
    state: HistoryPayload
) throws {
    let checkpointID = UUID()
    let checkpoint = try history.createCheckpoint(
        id: checkpointID, name: "Before review", state: state, resources: [])
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

    let hold = try history.holdState(checkpoint.id, id: UUID())
    _ = try history.retentionHolds()
    try history.releaseHold(hold.id)
    _ = try history.consolidateHistory(
        through: checkpoint.id, policy: HistoryRetentionPolicy(targetDetailedGroups: 100))
}

print("UndoKit independent Swift consumer linked")
