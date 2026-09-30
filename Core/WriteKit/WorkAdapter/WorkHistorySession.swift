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
            return NSLocalizedString("work-history.busy", tableName: nil, bundle: WorkStore.bundle,
                value: "Wait for the current edit or history recovery to finish, then try again.",
                comment: "Work save or history operation cannot run while edits are unsettled.")
        case .rejected:
            return NSLocalizedString("work-history.rejected", tableName: nil, bundle: WorkStore.bundle,
                value: "This history operation could not be applied to the current Work.",
                comment: "A history operation failed semantic validation without changing the Work.")
        case .resourceEditingUnsupported:
            return NSLocalizedString("work-history.resources-unsupported", tableName: nil, bundle: WorkStore.bundle,
                value: "Resource changes are not yet supported while durable history is enabled.",
                comment: "First implementation supports manuscript history but not resource changes.")
        case .invalidPackage:
            return NSLocalizedString("work-history.invalid-package", tableName: nil, bundle: WorkStore.bundle,
                value: "This Work’s history is missing, damaged, or unsupported.",
                comment: "History package validation failed; existing bytes are preserved.")
        case .closed:
            return NSLocalizedString("work-history.closed", tableName: nil, bundle: WorkStore.bundle,
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
/// All calls and callbacks are main-actor isolated. A failed submission may require `reconcile()` before editing resumes.
@MainActor public final class WorkHistorySession {
    private struct Registration: Codable {
        let version: Int
        let work: String
        let scope: UUID
        let workingIdentity: UUID
    }
    private struct Change: Codable {
        let before: Data
        let after: Data
    }
    private struct Evidence: Codable {
        struct Effect: Codable {
            let member: UUID
            let undo: Data
            let redo: Data
        }
        let generation: UUID
        let sequence: Int64
        let effects: [Effect]
    }
    private static let family = "app.foliosuite.work.manuscript.replace"
    private weak var work: Work?
    private let directory: URL
    private let registration: Registration
    private let openMode: HistoryOpenMode
    private var committed: Manuscript
    private var engine: HistoryEngine?
    private var opening: Task<HistoryEngine, Error>?
    private var host: Adapter?
    private var closed = false

    /// Called after coherent availability changes. Refresh views without creating another edit.
    public var didChange: (() -> Void)?
    /// The last host-accepted state, distinct from provisional native input.
    public var committedManuscript: Manuscript { committed }
    public var canUndo: Bool { engine?.snapshot.canUndo ?? false }
    public var canRedo: Bool { engine?.snapshot.canRedo ?? false }
    public var isPending: Bool { opening != nil || engine?.snapshot.hasPending == true }
    public var isSuspended: Bool { engine?.snapshot.isSuspended ?? false }
    public var canSave: Bool { !closed && engine != nil && !isPending && !isSuspended && work?.manuscript == committed }

    private var hostDirectory: URL { directory.appendingPathComponent("Host") }
    private var hostStore: URL { hostDirectory.appendingPathComponent("Work.sqlite") }
    private var historyStore: URL { directory.appendingPathComponent("History.sqlite") }

    init(work: Work, packageURL: URL?, baseline: URL? = nil) throws {
        self.work = work
        committed = work.manuscript
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("FolioHistory-" + UUID().uuidString)
        if let packageURL {
            let history = packageURL.appendingPathComponent("History")
            let values = try history.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true, values.isSymbolicLink != true,
                  Set(try FileManager.default.contentsOfDirectory(atPath: history.path)) == ["Registration.plist", "History.sqlite"] else {
                throw WorkHistoryError.invalidPackage
            }
            let registrationURL = history.appendingPathComponent("Registration.plist")
            try WorkResourceStore.checkRegularFile(registrationURL)
            guard (try registrationURL.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? Int.max < 65_536 else {
                throw WorkHistoryError.invalidPackage
            }
            let saved = try PropertyListDecoder().decode(Registration.self, from: Data(contentsOf: registrationURL))
            guard saved.version == 1, saved.work == work.identifier.rawValue else {
                throw WorkHistoryError.invalidPackage
            }
            registration = Registration(version: 1, work: saved.work, scope: saved.scope, workingIdentity: UUID())
            openMode = .independentCopy(sourceWorkingIdentity: saved.workingIdentity)
        } else {
            openMode = .create
            registration = Registration(version: 1, work: work.identifier.rawValue,
                                        scope: UUID(), workingIdentity: UUID())
        }
        try FileManager.default.createDirectory(at: hostDirectory, withIntermediateDirectories: true)
        do {
            if let packageURL {
                _ = try WorkStore.cloneOrCopy(packageURL.appendingPathComponent("Work.sqlite"), to: hostStore)
                let source = packageURL.appendingPathComponent("History/History.sqlite")
                try WorkResourceStore.checkRegularFile(source)
                _ = try WorkStore.cloneOrCopy(source, to: historyStore)
            } else if let baseline {
                _ = try WorkStore.stageSave(workIdentifier: work.identifier, manuscript: committed,
                    resources: nil, from: baseline, to: hostDirectory)
            } else {
                let package = try WorkStore.package(workIdentifier: work.identifier, manuscript: committed)
                guard let data = package.fileWrappers?["Work.sqlite"]?.regularFileContents else {
                    throw WorkHistoryError.invalidPackage
                }
                try data.write(to: hostStore, options: .atomic)
            }
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    // The private working copy retains unresolved evidence until explicit close. A process crash never edits the saved original.
    /// Reconcile any delivered command from durable host receipts before enabling Undo/Redo.
    public func reconcile() async throws {
        let engine = try await ready()
        if let result = await engine.reconcile() { try finish(result) }
        if engine.snapshot.isSuspended { throw WorkHistoryError.busy }
        didChange?()
    }

    private func ready() async throws -> HistoryEngine {
        guard !closed else { throw WorkHistoryError.closed }
        if let engine { return engine }
        if let opening { return try await opening.value }
        let adapter = Adapter(session: self)
        host = adapter
        let url = historyStore
        let registration = registration
        let mode = openMode
        let task = Task { @MainActor in
            try await HistoryEngine.open(at: url, scope: registration.scope,
                workingIdentity: registration.workingIdentity, mode: mode, host: adapter, limits: HistoryLimits())
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

    private func submit(manuscript: Manuscript, origin: UUID?) async throws {
        let engine = try await ready()
        guard manuscript.identifier == committed.identifier else { throw WorkHistoryError.rejected }
        guard manuscript != committed else { return }
        let before = try WorkHistoryPayload.encode(committed)
        let after = try WorkHistoryPayload.encode(manuscript)
        let payload = try encodeChange(before: before, after: after)
        let result = await engine.submit(HistoryCommand(fingerprint: Data(SHA256.hash(data: payload.data)),
                                                       payload: payload, restorationOrigin: origin))
        try finish(result)
    }

    public func undo() async throws { let engine = try await ready(); try finish(await engine.undo()) }
    public func redo() async throws { let engine = try await ready(); try finish(await engine.redo()) }

    private func finish(_ result: HistoryResult) throws {
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
        _ = try engine.createCheckpoint(id: id, name: name,
            state: HistoryPayload(family: Self.family, data: WorkHistoryPayload.encode(committed)))
        didChange?()
        return id
    }

    /// Restore through a new undoable edit; the displaced continuation remains in history.
    public func restore(checkpointID: UUID) async throws {
        let engine = try await ready()
        guard let checkpoint = try engine.checkpoint(id: checkpointID),
              checkpoint.state.family == Self.family, checkpoint.state.version == 1 else {
            throw WorkHistoryError.invalidPackage
        }
        try await submit(manuscript: WorkHistoryPayload.decode(checkpoint.state.data), origin: checkpointID)
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

    func stageSave(resources: WorkResourceStore?, to destination: URL) throws -> WorkSaveReport {
        guard canSave, let work else { throw WorkHistoryError.busy }
        let report = try WorkStore.stageSave(workIdentifier: work.identifier, manuscript: committed,
            resources: resources, from: hostDirectory, to: destination)
        let history = destination.appendingPathComponent("History")
        try FileManager.default.createDirectory(at: history, withIntermediateDirectories: false)
        guard let engine else { throw WorkHistoryError.busy }
        try engine.copyStore(to: history.appendingPathComponent("History.sqlite"))
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        try encoder.encode(registration).write(to: history.appendingPathComponent("Registration.plist"), options: .atomic)
        try WorkResourceStore.markHistory(in: destination)
        return report
    }

    private func encodeChange(before: Data, after: Data) throws -> HistoryPayload {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return HistoryPayload(family: Self.family, data: try encoder.encode(Change(before: before, after: after)))
    }

    private func deliver(_ delivery: HistoryDelivery) -> HistoryHostOutcome {
        guard let work, !closed else { return .unresolved }
        do {
            if let receipt = try WorkStore.historyReceipt(at: hostStore, commandID: delivery.token.command) {
                return try outcome(receipt, token: delivery.token)
            }
            let stored = try WorkStore.readStore(at: hostStore)
            guard stored.identifier == work.identifier, stored.manuscript == committed else { return .unresolved }
            var state = committed
            var effects: [HistoryEffect] = []
            for member in delivery.members {
                guard member.payload.family == Self.family, member.payload.version == 1,
                      member.payload.data.count <= 16 * 1_024 * 1_024 else {
                    return try reject(delivery.token)
                }
                let change = try PropertyListDecoder().decode(Change.self, from: member.payload.data)
                let before = try WorkHistoryPayload.decode(change.before)
                let after = try WorkHistoryPayload.decode(change.after)
                guard state == before, before != after, after.identifier == committed.identifier else {
                    return try reject(delivery.token)
                }
                effects.append(HistoryEffect(memberID: member.id,
                    undo: try encodeChange(before: change.after, after: change.before), redo: member.payload))
                state = after
            }
            let evidence = Evidence(generation: delivery.token.generation, sequence: delivery.token.sequence,
                effects: effects.map { Evidence.Effect(member: $0.memberID, undo: $0.undo.data, redo: $0.redo.data) })
            let encoded = try PropertyListEncoder().encode(evidence)
            try WorkStore.commitHistory(at: hostStore, workIdentifier: work.identifier, manuscript: state,
                receipt: WorkStore.HistoryReceipt(commandID: delivery.token.command,
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

    private func reject(_ token: HistoryToken) throws -> HistoryHostOutcome {
        guard let work else { return .unresolved }
        try WorkStore.commitHistory(at: hostStore, workIdentifier: work.identifier, manuscript: committed,
            receipt: WorkStore.HistoryReceipt(commandID: token.command,
                fingerprint: token.generation.uuidString + ":" + String(token.sequence), accepted: false, evidence: Data()))
        return .rejected
    }

    private func outcome(_ receipt: WorkStore.HistoryReceipt, token: HistoryToken) throws -> HistoryHostOutcome {
        guard receipt.fingerprint == token.generation.uuidString + ":" + String(token.sequence) else { return .unresolved }
        guard receipt.accepted else { return .rejected }
        let evidence = try PropertyListDecoder().decode(Evidence.self, from: receipt.evidence)
        guard evidence.generation == token.generation, evidence.sequence == token.sequence else { return .unresolved }
        let stored = try WorkStore.readStore(at: hostStore)
        guard let work, stored.identifier == work.identifier else { return .unresolved }
        let hasProvisionalInput = work.manuscript != committed
        committed = stored.manuscript
        if !hasProvisionalInput { work.manuscript = stored.manuscript }
        return .accepted(evidence.effects.map {
            HistoryEffect(memberID: $0.member, undo: HistoryPayload(family: Self.family, data: $0.undo),
                          redo: HistoryPayload(family: Self.family, data: $0.redo))
        })
    }

    private final class Adapter: HistoryHost {
        weak var session: WorkHistorySession?
        init(session: WorkHistorySession) { self.session = session }
        func deliver(_ delivery: HistoryDelivery) async -> HistoryHostOutcome { session?.deliver(delivery) ?? .unresolved }
        func outcome(for token: HistoryToken) async -> HistoryHostOutcome {
            guard let session else { return .unresolved }
            do {
                guard let receipt = try WorkStore.historyReceipt(at: session.hostStore, commandID: token.command) else {
                    return .unresolved
                }
                return try session.outcome(receipt, token: token)
            } catch { return .unresolved }
        }
    }
}
