// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import CoreData
import FolioKit
import Foundation
import UndoKit
@testable import WriteKit
import XCTest

@MainActor final class WorkHistoryTests: XCTestCase {
  private func manuscript(_ work: Work, text: String) throws -> Manuscript {
    let unit = work.text
    let paragraph = TextParagraph(
      identifier: unit.paragraphs[0].identifier,
      runs: [TextRun(string: text, emphasis: .none)])
    let changed = try TextUnit(
      identifier: unit.identifier, title: unit.title, paragraphs: [paragraph])
    return try Manuscript(identifier: work.manuscriptIdentifier, units: [changed])
  }

  private func receiptCount(in package: URL) throws -> Int {
    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: try WorkStore.model())
    let store = try coordinator.addPersistentStore(
      ofType: NSSQLiteStoreType, configurationName: nil,
      at: package.appendingPathComponent("Work.sqlite"),
      options: [NSReadOnlyPersistentStoreOption: true])
    defer { try? coordinator.remove(store) }
    let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
    context.persistentStoreCoordinator = coordinator
    return try context.performAndWait {
      try context.count(for: NSFetchRequest<NSManagedObject>(entityName: "HistoryReceipt"))
    }
  }

  func testAcceptedEditSurvivesSaveAndReopenThenUndoAndRedo() async throws {
    let work = Work()
    let history = try work.enableHistory()
    try await history.submit(manuscript: manuscript(work, text: "A durable sentence."))
    let package = try work.fileWrapper()
    let historyFiles = try XCTUnwrap(package.fileWrappers?["History"]?.fileWrappers)
    XCTAssertEqual(Set(historyFiles.keys), ["History.sqlite", "Registration.plist"])
    let reopened = try Work(fileWrapper: package)
    let restored = try XCTUnwrap(reopened.history)
    try await restored.reconcile()
    XCTAssertEqual(reopened.text.string, "A durable sentence.")
    XCTAssertTrue(restored.canUndo)
    try await restored.undo()
    XCTAssertEqual(reopened.text.string, "")
    try await restored.redo()
    XCTAssertEqual(reopened.text.string, "A durable sentence.")
    try await history.close()
    try await restored.close()
  }

  func testEnablingHistoryAfterTemporaryImportKeepsCurrentManuscript() async throws {
    let original = Work()
    original.manuscript = try manuscript(original, text: "Imported")
    let work = try Work(fileWrapper: original.fileWrapper())
    work.manuscript = try manuscript(work, text: "Edited before enabling history")
    let history = try work.enableHistory()
    try await history.submit(manuscript: manuscript(work, text: "Durable edit"))
    try await history.undo()
    XCTAssertEqual(work.text.string, "Edited before enabling history")
    let reopened = try Work(fileWrapper: work.fileWrapper())
    XCTAssertEqual(reopened.text.string, "Edited before enabling history")
    try await history.close()
    try await reopened.history?.close()
  }

  func testCheckpointRestorationRetainsDisplacedWorkAndResources() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    let source = directory.appendingPathComponent("Reference.txt")
    let bytes = Data("A resource retained by every checkpoint.".utf8)
    try bytes.write(to: source)
    let work = Work()
    let resource = try work.importResource(from: source)
    let history = try work.enableHistory()
    try await history.submit(manuscript: manuscript(work, text: "A"))
    let checkpoint = try await history.createCheckpoint(name: "First draft")
    try await history.submit(manuscript: manuscript(work, text: "B"))
    try await history.submit(manuscript: manuscript(work, text: "C"))
    let reopened = try Work(fileWrapper: work.fileWrapper())
    let restored = try XCTUnwrap(reopened.history)
    try await restored.reconcile()
    XCTAssertEqual(try restored.checkpoints().map(\.name), ["First draft"])
    try await restored.restore(checkpointID: checkpoint)
    XCTAssertEqual(reopened.text.string, "A")
    try await restored.undo()
    XCTAssertEqual(reopened.text.string, "C")
    try await restored.redo()
    XCTAssertEqual(reopened.text.string, "A")
    let exported = directory.appendingPathComponent("Recovered.txt")
    try reopened.exportResource(withIdentifier: resource, to: exported)
    XCTAssertEqual(try Data(contentsOf: exported), bytes)
    let again = try Work(fileWrapper: reopened.fileWrapper())
    let againHistory = try XCTUnwrap(again.history)
    try await againHistory.reconcile()
    try await againHistory.undo()
    XCTAssertEqual(again.text.string, "C")
    try await history.close()
    try await restored.close()
    try await againHistory.close()
  }

  func testEditingAfterUndoKeepsCheckpointOnDisplacedBranchAndFiltersNoOp() async throws {
    let work = Work()
    let history = try work.enableHistory()
    try await history.submit(manuscript: work.manuscript)
    XCTAssertFalse(history.canUndo)
    try await history.submit(manuscript: manuscript(work, text: "A"))
    try await history.submit(manuscript: manuscript(work, text: "B"))
    let displaced = try await history.createCheckpoint(name: "Displaced B")
    try await history.undo()
    try await history.submit(manuscript: manuscript(work, text: "C"))
    XCTAssertFalse(history.canRedo)
    try await history.restore(checkpointID: displaced)
    XCTAssertEqual(work.text.string, "B")
    try await history.undo()
    XCTAssertEqual(work.text.string, "C")
    try await history.close()
  }

  func testOversizedEditIsRefusedWithoutChangingAcceptedWork() async throws {
    let work = Work()
    let history = try work.enableHistory()
    try await history.reconcile()
    let original = work.manuscript
    do {
      try await history.submit(
        manuscript: manuscript(work, text: String(repeating: "x", count: 9 * 1_024 * 1_024)))
      XCTFail("Oversized input must be refused")
    } catch {
      XCTAssertEqual(work.manuscript, original)
      XCTAssertEqual(history.committedManuscript, original)
      XCTAssertFalse(history.canUndo)
      XCTAssertFalse(history.isSuspended)
    }
    let reopened = try Work(fileWrapper: work.fileWrapper())
    XCTAssertEqual(reopened.manuscript, original)
    try await history.close()
    try await reopened.history?.close()
  }

  func testMissingRequiredHistoryIsNotSilentlyOpenedAsEmptyHistory() async throws {
    let work = Work()
    let history = try work.enableHistory()
    try await history.submit(manuscript: manuscript(work, text: "Preserve this."))
    let package = try work.fileWrapper()
    let historyWrapper = try XCTUnwrap(package.fileWrappers?["History"])
    package.removeFileWrapper(historyWrapper)
    XCTAssertThrowsError(try Work(fileWrapper: package))
    XCTAssertEqual(work.text.string, "Preserve this.")
    XCTAssertTrue(history.canUndo)
    XCTAssertThrowsError(try work.removeResource(withIdentifier: .make()))
    try await history.close()
  }

  func testOmittedSaveStagesCurrentWorkAndOnlySuccessfulPublicationClearsLiveHistory() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    let original = directory.appendingPathComponent("Original.flwrbundle")
    let omitted = directory.appendingPathComponent("Omitted.flwrbundle")
    try FileManager.default.createDirectory(at: original, withIntermediateDirectories: false)
    try FileManager.default.createDirectory(at: omitted, withIntermediateDirectories: false)
    let work = Work()
    let history = try work.enableHistory()
    try await history.submit(manuscript: manuscript(work, text: "Keep current wording"))
    try work.stageSave(from: nil, toEmptyPackageAt: original)
    try work.stageSave(from: original, toEmptyPackageAt: omitted, omittingHistory: true)
    XCTAssertEqual(try receiptCount(in: original), 1)
    XCTAssertEqual(try receiptCount(in: omitted), 0)
    XCTAssertTrue(history.canUndo, "A staged but unpublished omission preserves live history")
    XCTAssertTrue(FileManager.default.fileExists(atPath: original.appendingPathComponent("History").path))
    XCTAssertFalse(FileManager.default.fileExists(atPath: omitted.appendingPathComponent("History").path))
    let manifest = try String(contentsOf: omitted.appendingPathComponent("Package.json"), encoding: .utf8)
    XCTAssertFalse(manifest.contains("durable-history-v1"))
    let omittedWork = try Work(contentsOf: omitted)
    XCTAssertNil(omittedWork.history)
    XCTAssertEqual(omittedWork.text.string, "Keep current wording")
    try history.completeOmissionAfterSave()
    XCTAssertFalse(history.canUndo)
    XCTAssertTrue(history.canSave)
    XCTAssertEqual(work.text.string, "Keep current wording")
    try await history.close()
    try await omittedWork.history?.close()
  }

  func testFailedOmissionStagingPreservesSavedHistoryAndLiveUndo() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    let original = directory.appendingPathComponent("Original.flwrbundle")
    let failed = directory.appendingPathComponent("Failed.flwrbundle")
    try FileManager.default.createDirectory(at: original, withIntermediateDirectories: false)
    try FileManager.default.createDirectory(at: failed, withIntermediateDirectories: false)
    let work = Work()
    let history = try work.enableHistory()
    try await history.submit(manuscript: manuscript(work, text: "Saved original"))
    try work.stageSave(from: nil, toEmptyPackageAt: original)
    try Data("occupied".utf8).write(to: failed.appendingPathComponent("occupant"))
    XCTAssertThrowsError(try work.stageSave(
      from: original, toEmptyPackageAt: failed, omittingHistory: true))
    XCTAssertTrue(history.canUndo)
    XCTAssertTrue(FileManager.default.fileExists(atPath: original.appendingPathComponent("History").path))
    XCTAssertEqual(try receiptCount(in: original), 1)
    let reopened = try Work(contentsOf: original)
    XCTAssertNotNil(reopened.history)
    try await history.close()
    try await reopened.history?.close()
  }

  func testPostPublicationReceiptCleanupFailureFencesEditsUntilRetry() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    let omitted = directory.appendingPathComponent("Omitted.flwrbundle")
    let next = directory.appendingPathComponent("Next.flwrbundle")
    try FileManager.default.createDirectory(at: omitted, withIntermediateDirectories: false)
    try FileManager.default.createDirectory(at: next, withIntermediateDirectories: false)
    let work = Work()
    let history = try work.enableHistory()
    try await history.submit(manuscript: manuscript(work, text: "Current"))
    try work.stageSave(from: nil, toEmptyPackageAt: omitted, omittingHistory: true)
    let before = history.availability
    let heldStore = directory.appendingPathComponent("Held.sqlite")
    try FileManager.default.moveItem(at: history.hostStore, to: heldStore)
    XCTAssertThrowsError(try history.completeOmissionAfterSave())
    let fenced = history.availability
    XCTAssertNotEqual(fenced.generation, before.generation)
    XCTAssertGreaterThan(fenced.version, before.version)
    XCTAssertTrue(fenced.isSuspended)
    XCTAssertFalse(history.canSave)
    do {
      try await history.submit(manuscript: manuscript(work, text: "Cannot race cleanup"))
      XCTFail("A fenced session must reject a new command")
    } catch {}
    do {
      try await history.undo()
      XCTFail("A fenced session must reject Undo")
    } catch {}
    try FileManager.default.moveItem(at: heldStore, to: history.hostStore)
    try history.completeOmissionAfterSave()
    let resumed = history.availability
    XCTAssertGreaterThan(resumed.version, fenced.version)
    XCTAssertFalse(resumed.isSuspended)
    XCTAssertTrue(history.canSave)
    try work.stageSave(from: omitted, toEmptyPackageAt: next)
    XCTAssertEqual(try receiptCount(in: next), 0)
    try await history.close()
  }

  func testRecordingOffKeepsSessionUndoAndReenableUsesCurrentBaseline() async throws {
    let work = Work()
    let history = try work.enableHistory()
    try await history.submit(manuscript: manuscript(work, text: "Retained A"))
    try await history.setRecording(.off)
    try await history.submit(manuscript: manuscript(work, text: "Session B"))
    XCTAssertTrue(history.canUndo)
    try await history.undo()
    XCTAssertEqual(work.text.string, "Retained A")
    try await history.redo()
    XCTAssertEqual(work.text.string, "Session B")
    let offPackage = try work.fileWrapper()
    let reopenedOff = try Work(fileWrapper: offPackage)
    let reopenedHistory = try XCTUnwrap(reopenedOff.history)
    try await reopenedHistory.reconcile()
    XCTAssertEqual(reopenedOff.text.string, "Session B")
    XCTAssertFalse(reopenedHistory.canUndo)
    try await history.setRecording(.on)
    try await history.submit(manuscript: manuscript(work, text: "Retained C"))
    try await history.undo()
    XCTAssertEqual(work.text.string, "Session B")
    try await history.close()
    try await reopenedHistory.close()
  }

  func testPostPublicationGenerationClearRefusalKeepsFenceUntilRetry() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    let omitted = directory.appendingPathComponent("Omitted.flwrbundle")
    try FileManager.default.createDirectory(at: omitted, withIntermediateDirectories: false)
    let work = Work()
    let history = try work.enableHistory()
    try await history.submit(manuscript: manuscript(work, text: "Current"))
    let checkpoint = try await history.createCheckpoint(name: "Current")
    try work.stageSave(from: nil, toEmptyPackageAt: omitted, omittingHistory: true)
    let engine = try XCTUnwrap(history.engine)
    let plan = try engine.beginRecoveryPlan(to: .checkpoint(checkpoint), using: .acceptedEffects)
    let before = history.availability
    XCTAssertThrowsError(try history.completeOmissionAfterSave())
    let fenced = history.availability
    XCTAssertEqual(fenced.generation, before.generation)
    XCTAssertGreaterThan(fenced.version, before.version)
    XCTAssertTrue(fenced.isSuspended)
    XCTAssertFalse(history.canSave)
    engine.releaseRecoveryPlan(plan)
    try history.completeOmissionAfterSave()
    let resumed = history.availability
    XCTAssertNotEqual(resumed.generation, before.generation)
    XCTAssertGreaterThan(resumed.version, fenced.version)
    XCTAssertFalse(resumed.isSuspended)
    XCTAssertEqual(try receiptCount(in: omitted), 0)
    try await history.close()
  }

}
