// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import FolioKit
import Foundation
import UndoKit
@testable import WriteKit
import XCTest

@MainActor final class WorkResourceHistoryTests: XCTestCase {
  private func directory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    addTeardownBlock { try? FileManager.default.removeItem(at: url) }
    return url
  }

  private func source(in directory: URL, name: String = "Figure.dat") throws -> URL {
    let url = directory.appendingPathComponent(name)
    try Data("Independent immutable resource bytes".utf8).write(to: url)
    return url
  }

  func testImportRemoveSaveReopenUndoRedoKeepsIdentityAndBytes() async throws {
    let directory = try directory()
    let source = try source(in: directory)
    let bytes = try Data(contentsOf: source)
    let work = Work()
    let history = try work.enableHistory()
    let identifier = try await history.importResource(from: source)
    let metadata = work.resources
    try Data("Source replaced".utf8).write(to: source)
    try await history.removeResource(withIdentifier: identifier)
    XCTAssertTrue(work.resources.isEmpty)
    XCTAssertThrowsError(try work.exportResource(withIdentifier: identifier,
                                                to: directory.appendingPathComponent("Absent")))
    let reopened = try Work(fileWrapper: work.fileWrapper())
    let restored = try XCTUnwrap(reopened.history)
    try await restored.reconcile()
    XCTAssertTrue(reopened.resources.isEmpty)
    try await restored.undo()
    XCTAssertEqual(reopened.resources, metadata)
    let exported = directory.appendingPathComponent("Recovered")
    try reopened.exportResource(withIdentifier: identifier, to: exported)
    XCTAssertEqual(try Data(contentsOf: exported), bytes)
    try await restored.undo()
    XCTAssertTrue(reopened.resources.isEmpty)
    try await restored.redo()
    XCTAssertEqual(reopened.resources, metadata)
    try await restored.redo()
    XCTAssertTrue(reopened.resources.isEmpty)
    try await history.close()
    try await restored.close()
  }

  func testCheckpointRestoresResourcesOnDisplacedContinuationAndReportsReferences() async throws {
    let directory = try directory()
    let work = Work()
    let history = try work.enableHistory()
    let first = try await history.importResource(from: source(in: directory))
    let checkpoint = try await history.createCheckpoint(name: "With figure")
    try await history.undo()
    let second = try await history.importResource(from: source(in: directory, name: "Other.dat"))
    XCTAssertFalse(history.canRedo)
    let reopened = try Work(fileWrapper: work.fileWrapper())
    let restored = try XCTUnwrap(reopened.history)
    try await restored.reconcile()
    try await restored.restore(checkpointID: checkpoint)
    XCTAssertEqual(reopened.resources.map(\.identifier), [first])
    try await restored.undo()
    XCTAssertEqual(reopened.resources.map(\.identifier), [second])
    let store = try await HistoryStore.open(
      at: restored.historyStore, workingIdentity: restored.registration.workingIdentity,
      mode: .existing, access: .readOnly)
    let references = try store.requiredObjects(in: restored.registration.scope, limit: 100)
    XCTAssertEqual(Set(references.objects.map { $0.reference.objectKey }), [first.rawValue, second.rawValue])
    try await store.close()
    try await history.close()
    try await restored.close()
  }

  func testInvalidSecondGroupMemberRejectsWholeAuthoredAndResourceChange() async throws {
    let directory = try directory()
    let work = Work()
    let history = try work.enableHistory()
    let identifier = try await history.importResource(from: source(in: directory))
    let before = history.committedState
    let empty = WorkHistoryState(manuscript: before.manuscript, resources: [])
    let invalid = WorkResource(identifier: .make(), filename: "Missing", byteCount: 1,
                               sha256: String(repeating: "0", count: 64))
    let missing = WorkHistoryState(manuscript: before.manuscript, resources: [invalid])
    let token = HistoryToken(scope: history.registration.scope,
                             generation: try XCTUnwrap(history.availability.generation),
                             sequence: 100, command: UUID())
    let adapter = WorkHistoryAdapter(session: history)
    let result = await adapter.apply([
      (UUID(), WorkHistoryChange(before: before, after: empty)),
      (UUID(), WorkHistoryChange(before: empty, after: missing)),
    ], context: HistoryOperationContext(token: token))
    guard case .rejected = result else { return XCTFail("Whole group must be rejected") }
    XCTAssertEqual(history.committedState, before)
    XCTAssertEqual(work.resources.map(\.identifier), [identifier])
    let stored = try WorkStore.readStore(at: history.hostStore)
    XCTAssertEqual(stored.manuscript, before.manuscript)
    XCTAssertEqual(stored.resourceMembership, before.resources)
    XCTAssertEqual(try WorkStore.historyReceipt(at: history.hostStore, commandID: token.command)?.accepted, false)
    try await history.close()
  }

  func testOutcomeLookupRecoversAcceptedMembershipWithoutReapplying() async throws {
    let directory = try directory()
    let work = Work()
    let history = try work.enableHistory()
    _ = try await history.importResource(from: source(in: directory))
    let before = history.committedState
    let empty = WorkHistoryState(manuscript: before.manuscript, resources: [])
    let token = HistoryToken(scope: history.registration.scope,
                             generation: try XCTUnwrap(history.availability.generation),
                             sequence: 100, command: UUID())
    let adapter = WorkHistoryAdapter(session: history)
    let change = WorkHistoryChange(before: before, after: empty)
    let result = await adapter.apply([(UUID(), change)], context: HistoryOperationContext(token: token))
    guard case .accepted = result else { return XCTFail("Expected acceptance") }
    // Model a stale in-memory projection after the host transaction succeeded.
    history.committedResources = before.resources
    work.resourceStore.adoptValidated(before.resources)
    let recovered = await adapter.outcome(for: token)
    guard case .accepted(let effects) = recovered else { return XCTFail("Receipt must prove acceptance") }
    XCTAssertEqual(effects.count, 1)
    XCTAssertEqual(effects[0].resources.map(\.objectKey), before.resources.map { $0.identifier.rawValue })
    XCTAssertTrue(work.resources.isEmpty)
    XCTAssertTrue(history.committedResources.isEmpty)
    let repeated = await adapter.apply([(UUID(), change)], context: HistoryOperationContext(token: token))
    guard case .accepted = repeated else { return XCTFail("Exact retry must return the receipt") }
    XCTAssertTrue(work.resources.isEmpty)
    try await history.close()
  }

  func testFailedStagingPreservesOriginalAndOmissionCopiesOnlyCurrentBytes() async throws {
    let directory = try directory()
    let work = Work()
    let history = try work.enableHistory()
    let removed = try await history.importResource(from: source(in: directory))
    let kept = try await history.importResource(from: source(in: directory, name: "Keep.dat"))
    let original = try work.fileWrapper()
    try await history.removeResource(withIdentifier: removed)
    let occupied = directory.appendingPathComponent("Occupied")
    try FileManager.default.createDirectory(at: occupied, withIntermediateDirectories: false)
    try Data().write(to: occupied.appendingPathComponent("Occupant"))
    XCTAssertThrowsError(try work.stageSave(from: nil, toEmptyPackageAt: occupied))
    XCTAssertTrue(history.canUndo)
    let saved = try Work(fileWrapper: original)
    XCTAssertEqual(Set(saved.resources.map(\.identifier)), [removed, kept])
    let omitted = directory.appendingPathComponent("Omitted")
    try FileManager.default.createDirectory(at: omitted, withIntermediateDirectories: false)
    let token = try history.beginOmissionPublication()
    try work.stageSave(from: nil, toEmptyPackageAt: omitted, omittingHistory: true)
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(
      atPath: omitted.appendingPathComponent("Resources").path), [kept.rawValue])
    let reopened = try Work(contentsOf: omitted)
    XCTAssertNil(reopened.history)
    XCTAssertEqual(reopened.resources.map(\.identifier), [kept])
    try history.cancelOmissionPublication(token)
    try await history.undo()
    XCTAssertEqual(Set(work.resources.map(\.identifier)), [removed, kept])
    try await history.close()
    try await saved.history?.close()
  }

  func testUnavailableInverseRejectsWithoutPartialMembershipOrManuscriptChange() async throws {
    let directory = try directory()
    let work = Work()
    let history = try work.enableHistory()
    let identifier = try await history.importResource(from: source(in: directory))
    let original = try work.fileWrapper()
    try await history.removeResource(withIdentifier: identifier)
    let manuscript = work.manuscript
    // Fault only the live byte cache; the saved original and durable host copy remain intact.
    try work.resourceStore.removeResource(identifier)
    do {
      try await history.undo()
      XCTFail("Unavailable required bytes must reject the entire inverse")
    } catch {}
    XCTAssertTrue(work.resources.isEmpty)
    XCTAssertEqual(work.manuscript, manuscript)
    XCTAssertFalse(history.isSuspended)
    let saved = try Work(fileWrapper: original)
    XCTAssertEqual(saved.resources.map(\.identifier), [identifier])
    try await history.close()
    try await saved.history?.close()
  }

  func testHostStoreFailureSuspendsWithoutInferringRejectionOrChangingSavedOriginal() async throws {
    let directory = try directory()
    let work = Work()
    let history = try work.enableHistory()
    let identifier = try await history.importResource(from: source(in: directory))
    let original = try work.fileWrapper()
    let membership = work.resources
    let held = directory.appendingPathComponent("Held.sqlite")
    try FileManager.default.moveItem(at: history.hostStore, to: held)
    do {
      try await history.removeResource(withIdentifier: identifier)
      XCTFail("Missing host store cannot produce an accepted change")
    } catch {}
    XCTAssertEqual(work.resources, membership)
    XCTAssertTrue(history.isSuspended)
    XCTAssertFalse(history.canSave)
    try FileManager.default.moveItem(at: held, to: history.hostStore)
    do {
      try await history.reconcile()
      XCTFail("An absent receipt is unresolved, not rejection")
    } catch {}
    XCTAssertTrue(history.isSuspended)
    XCTAssertEqual(work.resources, membership)
    let saved = try Work(fileWrapper: original)
    XCTAssertEqual(saved.resources, membership)
    try await history.close()
    XCTAssertTrue(FileManager.default.fileExists(atPath: history.hostStore.path))
    try await saved.history?.close()
    // This fixture explicitly owns its preserved unresolved copy.
    try FileManager.default.removeItem(at: history.directory)
  }

  func testInvalidImportAndMissingRemovalLeaveHistoryUsable() async throws {
    let directory = try directory()
    let work = Work()
    let history = try work.enableHistory()
    do {
      _ = try await history.importResource(from: directory)
      XCTFail("Directories are not opaque regular files")
    } catch {}
    do {
      try await history.removeResource(withIdentifier: .make())
      XCTFail("Missing resource must be refused")
    } catch {}
    XCTAssertTrue(work.resources.isEmpty)
    XCTAssertFalse(history.canUndo)
    XCTAssertTrue(history.canSave)
    _ = try await history.importResource(from: source(in: directory))
    XCTAssertEqual(work.resources.count, 1)
    try await history.close()
  }
}
