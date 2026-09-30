// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import WriteKit
import XCTest
@testable import Write

@MainActor final class WriteHistoryTests: XCTestCase {
    private func manuscript(in document: WriteDocument) throws -> ManuscriptViewController {
        try XCTUnwrap(document.windowControllers.first?.contentViewController as? ManuscriptViewController)
    }

    private func save(_ document: WriteDocument, to url: URL,
                      operation: NSDocument.SaveOperationType = .saveAsOperation) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            document.save(to: url, ofType: workDocumentType, for: operation) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async -> Bool {
        for _ in 0..<500 {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    func testHistoryActionForwardsThroughOwnedEditorResponder() async throws {
        let document = WriteDocument()
        document.makeWindowControllers()
        defer { document.close() }
        try await document.flushHistory()
        let window = try XCTUnwrap(document.windowControllers.first?.window)
        let controller = try manuscript(in: document)
        let textView = try XCTUnwrap(controller.activeEditor.textView)
        XCTAssertTrue(window.makeFirstResponder(textView))
        XCTAssertNotNil(controller.historyRequested, "The Write document must install its History callback")
        XCTAssertNotNil(controller.activeEditor.historyRequested,
            "The active editor must forward History to the Manuscript controller")
        XCTAssertTrue(controller.activeEditor.work === document.work)
        var forwarded = 0
        controller.historyRequested = { forwarded += 1 }
        XCTAssertTrue(NSApp.sendAction(#selector(WriteDocument.showHistory(_:)), to: textView, from: nil))
        XCTAssertEqual(forwarded, 1)
    }

    func testCoalescedNativeTypingSurvivesSaveReopenAndOneUndoRedo() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("flwrbundle")
        defer { try? FileManager.default.removeItem(at: url) }
        let document = WriteDocument()
        document.makeWindowControllers()
        defer { document.close() }
        try await document.flushHistory()
        let editor = try XCTUnwrap(manuscript(in: document).activeEditor)
        let textView = try XCTUnwrap(editor.textView)
        textView.insertText("A", replacementRange: NSRange(location: 0, length: 0))
        textView.insertText("B", replacementRange: NSRange(location: 1, length: 0))
        try await document.flushHistory()
        XCTAssertEqual(document.work.text.string, "AB")
        XCTAssertTrue(try XCTUnwrap(document.work.history).canUndo)

        try await save(document, to: url)
        let reopened = try WriteDocument(contentsOf: url, ofType: workDocumentType)
        reopened.makeWindowControllers()
        defer { reopened.close() }
        try await reopened.flushHistory()
        XCTAssertFalse(reopened.isDocumentEdited, "Rebuilding native history must not dirty the Work")
        XCTAssertEqual(reopened.work.text.string, "AB")
        let reopenedEditor = try XCTUnwrap(manuscript(in: reopened).activeEditor)
        let manager = try XCTUnwrap(reopenedEditor.textView.undoManager)
        XCTAssertTrue(manager.canUndo)
        manager.undo()
        XCTAssertFalse(reopened.isDocumentEdited,
            "Dispatching native Undo must not count a change before the host outcome")
        let reversed = await waitUntil {
            reopened.work.text.string == "" && reopened.work.history?.canRedo == true &&
                reopenedEditor.textView.string == "" && reopened.isDocumentEdited && manager.canRedo
        }
        XCTAssertTrue(reversed, "One native Undo should reverse the settled typing group")
        XCTAssertTrue(reopened.isDocumentEdited)
        XCTAssertEqual(reopenedEditor.textView.string, "")
        manager.redo()
        let redone = await waitUntil {
            reopened.work.text.string == "AB" && reopened.work.history?.canUndo == true &&
                reopenedEditor.textView.string == "AB" && manager.canUndo
        }
        XCTAssertTrue(redone)
        XCTAssertEqual(reopenedEditor.textView.string, "AB")
    }

    func testImmediateTypingThenNativeUndoQueuesBehindAcceptance() async throws {
        let document = WriteDocument()
        document.makeWindowControllers()
        defer { document.close() }
        try await document.flushHistory()
        let editor = try XCTUnwrap(manuscript(in: document).activeEditor)
        let textView = try XCTUnwrap(editor.textView)
        let manager = try XCTUnwrap(textView.undoManager)
        textView.insertText("Immediate", replacementRange: NSRange(location: 0, length: 0))
        XCTAssertTrue(manager.canUndo, "Provisional text is eligible before its history result arrives")
        manager.undo()
        let reversed = await waitUntil {
            document.work.text.string == "" && document.work.history?.canRedo == true &&
                textView.string == "" && manager.canRedo
        }
        XCTAssertTrue(reversed, "Undo must wait behind the typing submission")
        XCTAssertEqual(textView.string, "")
    }

    func testCapacityRefusalAllowsCorrectedNativeInput() async throws {
        let document = WriteDocument()
        var reportedErrors: [Error] = []
        document.historyErrorHandler = { reportedErrors.append($0) }
        document.makeWindowControllers()
        defer { document.close() }
        try await document.flushHistory()
        let editor = try XCTUnwrap(manuscript(in: document).activeEditor)
        let textView = try XCTUnwrap(editor.textView)
        let overLimit = String(repeating: "A", count: 8 * 1_024 * 1_024 + 1_024)
        textView.insertText(overLimit, replacementRange: NSRange(location: 0, length: 0))
        do {
            try await document.flushHistory()
            XCTFail("The oversized history payload must be refused")
        } catch {
            let history = try XCTUnwrap(document.work.history)
            XCTAssertEqual(reportedErrors.count, 1)
            XCTAssertFalse(history.canUndo)
            XCTAssertEqual(history.committedManuscript.units[0].string, "")
            XCTAssertTrue(document.isDocumentEdited, "The provisional input remains available to correct")
        }

        textView.setSelectedRange(NSRange(location: 0, length: (textView.string as NSString).length))
        textView.insertText("Small", replacementRange: textView.selectedRange())
        try await document.flushHistory()
        XCTAssertEqual(document.work.text.string, "Small")
        let history = try XCTUnwrap(document.work.history)
        XCTAssertEqual(history.committedManuscript.units[0].string, "Small")
        XCTAssertTrue(history.canUndo)
        XCTAssertEqual(reportedErrors.count, 1, "Corrected input should not replay the prior refusal")
    }

    func testFormattingAndStructureRemainUndoableAfterReopen() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("flwrbundle")
        defer { try? FileManager.default.removeItem(at: url) }
        let document = WriteDocument()
        document.makeWindowControllers()
        defer { document.close() }
        try await document.flushHistory()
        let sourceController = try manuscript(in: document)
        let editor = try XCTUnwrap(sourceController.activeEditor)
        editor.textView.insertText("Bold", replacementRange: NSRange(location: 0, length: 0))
        try await document.flushHistory()
        editor.textView.setSelectedRange(NSRange(location: 0, length: 4))
        editor.toggleBold(nil)
        try await document.flushHistory()
        XCTAssertTrue(document.work.text.paragraphs.flatMap(\.runs).contains { $0.presentation.bold })
        sourceController.addContentUnit(nil)
        try await document.flushHistory()
        XCTAssertEqual(document.work.manuscript.units.count, 2)

        try await save(document, to: url)
        let reopened = try WriteDocument(contentsOf: url, ofType: workDocumentType)
        reopened.makeWindowControllers()
        defer { reopened.close() }
        try await reopened.flushHistory()
        XCTAssertEqual(reopened.work.manuscript.units.count, 2)
        XCTAssertTrue(reopened.work.manuscript.units[0].paragraphs.flatMap(\.runs)
            .contains { $0.presentation.bold })
        let reopenedController = try manuscript(in: reopened)
        let manager = try XCTUnwrap(reopenedController.activeEditor.textView.undoManager)
        manager.undo()
        let removed = await waitUntil {
            reopened.work.manuscript.units.count == 1 && manager.canRedo
        }
        XCTAssertTrue(removed, "The structural edit should be the latest durable group")
        manager.redo()
        let restored = await waitUntil {
            reopened.work.manuscript.units.count == 2 && manager.canUndo
        }
        XCTAssertTrue(restored)
    }
}
