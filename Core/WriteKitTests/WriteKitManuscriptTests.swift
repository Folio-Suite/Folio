// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import FolioKit
import XCTest

@testable import WriteKit

@MainActor final class WriteKitManuscriptTests: XCTestCase {
  private func grouped(_ undo: UndoManager, _ action: () -> Void) {
    undo.beginUndoGrouping()
    action()
    undo.endUndoGrouping()
  }

  private func formattingButton(named title: String, editor: EditorViewController) throws
    -> NSButton {
    var pending = editor.view.window?.toolbar?.items.compactMap(\.view) ?? []
    while let view = pending.popLast() {
      if let button = view as? NSButton, button.title == title { return button }
      pending.append(contentsOf: view.subviews)
    }
    XCTFail("Missing formatting control \(title)")
    throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadUnknownError)
  }

  func testInternalCopyPasteRetainsMeaningButCreatesIndependentParagraphs() throws {
    let work = Work()
    let editor = EditorViewController.make(work: work, undoManager: UndoManager())
    _ = editor.view
    editor.textView.insertText("Original", replacementRange: NSRange(location: 0, length: 0))
    editor.textView.selectedRange = NSRange(location: 0, length: 8)
    editor.toggleStrongEmphasis(nil)
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    XCTAssertTrue(
      editor.textView.writeSelection(to: pasteboard, types: editor.textView.writablePasteboardTypes)
    )
    editor.textView.selectedRange = NSRange(location: 8, length: 0)
    editor.textView.insertText("\n", replacementRange: editor.textView.selectedRange)
    let destinationID = work.text.paragraphs.last?.identifier
    XCTAssertTrue(editor.textView.readSelection(from: pasteboard))
    XCTAssertEqual(work.text.string, "Original\nOriginal")
    XCTAssertNotEqual(work.text.paragraphs[0].identifier, work.text.paragraphs[1].identifier)
    XCTAssertEqual(work.text.paragraphs[1].identifier, destinationID)
    XCTAssertEqual(work.text.paragraphs[1].runs[0].emphasis, .strongEmphasis)
    XCTAssertEqual(work.text.paragraphs[1].runs[0].presentation, TextPresentation())
  }

  func testInlineWarningsFollowWrappingWithoutChangingAuthoredText() {
    let work = Work()
    let editor = EditorViewController.make(work: work, undoManager: UndoManager())
    _ = editor.view
    let text = editor.textView!
    let words = "First several ordinary words between the conflicts Last"
    text.setFrameSize(NSSize(width: 800, height: 400))
    text.insertText(words, replacementRange: NSRange(location: 0, length: 0))
    for word in ["First", "Last"] {
      text.selectedRange = (words as NSString).range(of: word)
      editor.toggleEmphasis(nil)
      editor.toggleBold(nil)
    }
    XCTAssertEqual(editor.formattingMarkers.count, 1, "Conflicts on one visual line share a marker")
    let originalY = editor.formattingMarkers[0].view.frame.minY
    text.setFrameSize(NSSize(width: 220, height: 400))
    XCTAssertEqual(editor.formattingMarkers.count, 2)
    XCTAssertGreaterThan(editor.formattingMarkers.last!.view.frame.minY, originalY)
    for marker in editor.formattingMarkers {
      XCTAssertTrue(text.bounds.contains(marker.view.frame))
    }
    XCTAssertEqual(text.string, words)
    XCTAssertEqual(work.text.string, words)
    XCTAssertNil(text.textStorage?.attribute(.backgroundColor, at: 0, effectiveRange: nil))
    XCTAssertNotNil(
      text.layoutManager?.temporaryAttribute(
        .backgroundColor, atCharacterIndex: 0, effectiveRange: nil))
    XCTAssertNil(
      text.layoutManager?.temporaryAttribute(
        .backgroundColor, atCharacterIndex: 6, effectiveRange: nil))
    text.setFrameSize(NSSize(width: 800, height: 400))
    XCTAssertEqual(editor.formattingMarkers.count, 1)
    editor.dismissFormattingWarning(nil)
    XCTAssertEqual(editor.formattingMarkers.count, 0)
    XCTAssertNil(
      text.layoutManager?.temporaryAttribute(
        .backgroundColor, atCharacterIndex: 0, effectiveRange: nil))
  }

  func testFormattingControlsReflectMixedSelectionUndoAndReopenedWork() throws {
    let work = Work()
    let undo = UndoManager()
    undo.groupsByEvent = false
    let editor = EditorViewController.make(work: work, undoManager: undo)
    let window = editor.makeWindowController()
    _ = window.window
    XCTAssertEqual(editor.textView.textContainerInset, NSSize(width: 32, height: 28))
    let emphasis = try formattingButton(named: "Emphasis", editor: editor)
    XCTAssertNotNil(emphasis.image)
    XCTAssertEqual(emphasis.state, .off)
    grouped(undo) {
      editor.textView.insertText("One two", replacementRange: NSRange(location: 0, length: 0))
      editor.textView.breakUndoCoalescing()
    }
    editor.textView.selectedRange = NSRange(location: 0, length: 3)
    grouped(undo) { emphasis.performClick(nil) }
    XCTAssertEqual(emphasis.state, .on)
    XCTAssertEqual(work.text.paragraphs[0].runs[0].presentation, TextPresentation())
    editor.textView.selectedRange = NSRange(location: 0, length: 7)
    XCTAssertEqual(emphasis.state, .mixed)
    grouped(undo) { emphasis.performClick(nil) }
    XCTAssertEqual(emphasis.state, .on)
    undo.undo()
    XCTAssertEqual(emphasis.state, .mixed)
    undo.redo()
    XCTAssertEqual(emphasis.state, .on)
    let reopened = try Work(fileWrapper: work.fileWrapper())
    undo.removeAllActions()
    editor.work = reopened
    editor.textView.selectedRange = NSRange(location: 0, length: 7)
    XCTAssertEqual(emphasis.state, .on)
    grouped(undo) { try? formattingButton(named: "Clear", editor: editor).performClick(nil) }
    XCTAssertEqual(emphasis.state, .off)
    XCTAssertEqual(reopened.text.paragraphs[0].runs[0].emphasis, .none)
    undo.undo()
    XCTAssertEqual(emphasis.state, .on)
  }

  func testInsertionPointFormattingFeedbackAndClear() throws {
    let editor = EditorViewController.make(work: Work(), undoManager: UndoManager())
    let window = editor.makeWindowController()
    _ = window.window
    let emphasis = try formattingButton(named: "Emphasis", editor: editor)
    emphasis.performClick(nil)
    XCTAssertEqual(emphasis.state, .on)
    editor.toggleItalic(nil)
    XCTAssertEqual(emphasis.state, .on)
    XCTAssertEqual(editor.work.text.string, "")
    try formattingButton(named: "Clear", editor: editor).performClick(nil)
    XCTAssertEqual(emphasis.state, .off)
    editor.textView.insertText("Plain", replacementRange: NSRange(location: 0, length: 0))
    XCTAssertEqual(editor.work.text.paragraphs[0].runs[0].presentation, TextPresentation())
  }

  func testManuscriptUnitsRetainTextWarningsTitlesAndOrderAcrossSave() throws {
    let work = Work()
    let firstRuns = [
      TextRun(string: "Meaning", emphasis: .emphasis),
      TextRun(string: "strong", emphasis: .strongEmphasis),
    ]
    let first = try TextUnit(
      identifier: work.text.identifier, title: work.text.title,
      paragraphs: [TextParagraph(identifier: .make(), runs: firstRuns)])
    let second = try TextUnit(
      identifier: .make(), title: "Second unit",
      paragraphs: [TextParagraph(identifier: .make())], formattingWarningDismissed: true)
    work.manuscript = try Manuscript(identifier: work.manuscriptIdentifier, units: [second, first])
    let loaded = try Work(fileWrapper: work.fileWrapper())
    XCTAssertEqual(
      loaded.manuscript.units.map(\.identifier), [second.identifier, first.identifier])
    XCTAssertEqual(loaded.manuscript.units[0].title, "Second unit")
    XCTAssertTrue(loaded.manuscript.units[0].formattingWarningDismissed)
    XCTAssertFalse(loaded.manuscript.units[1].formattingWarningDismissed)
    XCTAssertEqual(loaded.manuscript.units[1].string, first.string)
    XCTAssertEqual(
      loaded.manuscript.units[1].paragraphs[0].runs[1].presentation,
      first.paragraphs[0].runs[1].presentation)
  }

  func testManuscriptUndoReturnsToTheUnitItChanges() throws {
    let work = Work()
    let undo = UndoManager()
    undo.groupsByEvent = false
    let controller = ManuscriptViewController.make(work: work, undoManager: undo)
    _ = controller.view
    let firstID = try XCTUnwrap(controller.selectedUnitIdentifier)
    grouped(undo) {
      controller.activeEditor.textView.insertText(
        "First words", replacementRange: NSRange(location: 0, length: 0))
      controller.activeEditor.textView.breakUndoCoalescing()
    }
    grouped(undo) { controller.addContentUnit(nil) }
    let secondID = try XCTUnwrap(controller.selectedUnitIdentifier)
    grouped(undo) {
      controller.activeEditor.textView.insertText(
        "Second words", replacementRange: NSRange(location: 0, length: 0))
      controller.activeEditor.textView.breakUndoCoalescing()
    }
    XCTAssertNotEqual(
      work.text(withIdentifier: firstID)?.paragraphs[0].identifier,
      work.text(withIdentifier: secondID)?.paragraphs[0].identifier)
    controller.selectUnit(withIdentifier: firstID)
    XCTAssertEqual(controller.activeEditor.textView.string, "First words")
    undo.undo()
    XCTAssertNotEqual(
      work.text(withIdentifier: firstID)?.paragraphs[0].identifier,
      work.text(withIdentifier: secondID)?.paragraphs[0].identifier)
    XCTAssertEqual(controller.selectedUnitIdentifier, secondID)
    XCTAssertEqual(controller.activeEditor.textView.string, "")
    XCTAssertEqual(work.text(withIdentifier: firstID)?.string, "First words")
    undo.undo()
    XCTAssertEqual(work.manuscript.units.count, 1)
    XCTAssertEqual(controller.selectedUnitIdentifier, firstID)
    undo.redo()
    undo.redo()
    XCTAssertEqual(controller.selectedUnitIdentifier, secondID)
    XCTAssertEqual(controller.activeEditor.textView.string, "Second words")
    XCTAssertEqual(work.text(withIdentifier: firstID)?.string, "First words")
    XCTAssertNotEqual(
      work.text(withIdentifier: firstID)?.paragraphs[0].identifier,
      work.text(withIdentifier: secondID)?.paragraphs[0].identifier)
    let loaded = try Work(fileWrapper: work.fileWrapper())
    XCTAssertEqual(loaded.manuscript.units.map(\.string), ["First words", "Second words"])
  }

  func testManuscriptRenameAndReorderAreUndoableAndPreserveUnitWarningState() throws {
    let work = Work()
    let undo = UndoManager()
    undo.groupsByEvent = false
    let controller = ManuscriptViewController.make(work: work, undoManager: undo)
    _ = controller.view
    let firstID = try XCTUnwrap(controller.selectedUnitIdentifier)
    grouped(undo) { controller.activeEditor.dismissFormattingWarning(nil) }
    grouped(undo) { controller.addContentUnit(nil) }
    let secondID = try XCTUnwrap(controller.selectedUnitIdentifier)
    controller.unitTitle.stringValue = "Chapter Two"
    grouped(undo) { controller.renameContentUnit(nil) }
    XCTAssertEqual(work.text(withIdentifier: secondID)?.title, "Chapter Two")
    grouped(undo) { controller.moveContentUnitUp(nil) }
    XCTAssertEqual(work.text.identifier, secondID)
    undo.undo()
    XCTAssertEqual(work.text.identifier, firstID)
    undo.undo()
    XCTAssertEqual(work.text(withIdentifier: secondID)?.title, "Untitled")
    undo.redo()
    undo.redo()
    XCTAssertEqual(work.text.title, "Chapter Two")
    XCTAssertFalse(work.text(withIdentifier: secondID)!.formattingWarningDismissed)
    XCTAssertTrue(work.text(withIdentifier: firstID)!.formattingWarningDismissed)
    controller.selectUnit(withIdentifier: firstID)
    XCTAssertEqual(controller.activeEditor.formattingMarkers.count, 0)
  }
}
