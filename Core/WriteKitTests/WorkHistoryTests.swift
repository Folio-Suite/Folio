// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import FolioKit
import Foundation
import WriteKit
import XCTest

@MainActor final class WorkHistoryTests: XCTestCase {
    private func manuscript(_ work: Work, text: String) throws -> Manuscript {
        let unit = work.text
        let paragraph = TextParagraph(identifier: unit.paragraphs[0].identifier,
            runs: [TextRun(string: text, emphasis: .none)])
        let changed = try TextUnit(identifier: unit.identifier, title: unit.title, paragraphs: [paragraph])
        return try Manuscript(identifier: work.manuscriptIdentifier, units: [changed])
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
        try work.upgradeStorage()
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
            try await history.submit(manuscript: manuscript(work, text: String(repeating: "x", count: 9 * 1_024 * 1_024)))
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

}
