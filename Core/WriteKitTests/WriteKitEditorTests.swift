// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import FolioKit
@testable import WriteKit
import XCTest

@MainActor final class WriteKitEditorTests: XCTestCase {
    private func makeEditor(work: Work = Work()) -> (Work, UndoManager, EditorViewController) {
        let undo = UndoManager()
        undo.groupsByEvent = false
        let editor = EditorViewController.make(work: work, undoManager: undo)
        _ = editor.view
        return (work, undo, editor)
    }

    private func grouped(_ undo: UndoManager, _ action: () -> Void) {
        undo.beginUndoGrouping()
        action()
        undo.endUndoGrouping()
    }

    func testExclusiveEmphasisPreservesPresentationAndSplitsOnlyTheSelectedWord() throws {
        let (work, undo, editor) = makeEditor()
        grouped(undo) {
            editor.textView.insertText("before word after", replacementRange: NSRange(location: 0, length: 0))
            editor.textView.selectedRange = NSRange(location: 0, length: 17)
            editor.toggleEmphasis(nil)
        }
        editor.textView.selectedRange = NSRange(location: 7, length: 4)
        grouped(undo) { editor.toggleBold(nil) }
        let runs = try XCTUnwrap(work.text.paragraphs.first?.runs)
        XCTAssertEqual(runs.count, 3)
        XCTAssertEqual(runs.map(\.string), ["before ", "word", " after"])
        XCTAssertEqual(runs.map(\.presentation.bold), [false, true, false])
        XCTAssertTrue(runs.allSatisfy { $0.emphasis == .emphasis })
        let font = try XCTUnwrap(editor.textView.textStorage?.attribute(.font, at: 7, effectiveRange: nil) as? NSFont)
        let traits = NSFontManager.shared.traits(of: font)
        XCTAssertTrue(traits.contains(.boldFontMask))
        XCTAssertTrue(traits.contains(.italicFontMask))
        XCTAssertGreaterThan(editor.formattingMarkers.count, 0)
        XCTAssertNotNil(editor.textView.layoutManager?.temporaryAttribute(.backgroundColor,
            atCharacterIndex: 7, effectiveRange: nil))
        editor.textView.selectedRange = NSRange(location: 0, length: 17)
        grouped(undo) { editor.toggleStrongEmphasis(nil) }
        XCTAssertTrue(work.text.paragraphs[0].runs.allSatisfy { $0.emphasis == .strongEmphasis })
        XCTAssertTrue(work.text.paragraphs[0].runs[1].presentation.bold)
        undo.undo()
        XCTAssertTrue(work.text.paragraphs[0].runs.allSatisfy { $0.emphasis == .emphasis })
        grouped(undo) { editor.toggleVeryStrongEmphasis(nil) }
        XCTAssertTrue(work.text.paragraphs[0].runs.allSatisfy { $0.emphasis == .veryStrongEmphasis })
    }

    func testConflictConversionIsUndoableAndPersistsExclusiveMeaningAndBooleans() throws {
        let work = Work()
        let run = TextRun(string: "Keep these words", emphasis: .emphasis,
            presentation: TextPresentation(bold: true, underline: true, strikethrough: true))
        work.text = try TextUnit(identifier: work.text.identifier, title: work.text.title,
            paragraphs: [TextParagraph(identifier: try FolioIdentifier(rawValue: "p"),
                runs: [run], alignment: .center)])
        let (_, undo, editor) = makeEditor(work: work)
        editor.convertPresentationToEmphasis(nil)
        let converted = work.text.paragraphs[0].runs[0]
        XCTAssertEqual(converted.emphasis, .veryStrongEmphasis)
        XCTAssertFalse(converted.presentation.bold)
        XCTAssertFalse(converted.presentation.italic)
        XCTAssertTrue(converted.presentation.underline)
        XCTAssertTrue(converted.presentation.strikethrough)
        XCTAssertTrue(work.text.formattingWarningDismissed)
        XCTAssertEqual(editor.formattingMarkers.count, 0)
        undo.undo()
        XCTAssertEqual(work.text.paragraphs[0].runs[0].emphasis, .emphasis)
        XCTAssertTrue(work.text.paragraphs[0].runs[0].presentation.bold)
        XCTAssertFalse(work.text.formattingWarningDismissed)
        undo.redo()
        let loaded = try Work(fileWrapper: work.fileWrapper())
        XCTAssertTrue(loaded.text.formattingWarningDismissed)
        XCTAssertEqual(loaded.text.string, "Keep these words")
        XCTAssertEqual(loaded.text.paragraphs[0].alignment, .center)
        XCTAssertEqual(loaded.text.paragraphs[0].runs[0].emphasis, .veryStrongEmphasis)
        XCTAssertEqual(loaded.text.paragraphs[0].runs[0].presentation,
            TextPresentation(underline: true, strikethrough: true))
    }

    func testWarningDismissalSurvivesEditsAndReopenWithoutChangingFormatting() throws {
        let work = Work()
        let paragraph = TextParagraph(identifier: .make(), runs: [TextRun(string: "Meaning", emphasis: .emphasis)])
        work.text = try TextUnit(identifier: work.text.identifier, title: work.text.title, paragraphs: [paragraph])
        let (_, undo, editor) = makeEditor(work: work)
        editor.textView.selectedRange = NSRange(location: 0, length: 5)
        grouped(undo) { editor.toggleBold(nil) }
        grouped(undo) { editor.dismissFormattingWarning(nil) }
        XCTAssertTrue(work.text.paragraphs[0].runs[0].presentation.bold)
        XCTAssertEqual(work.text.paragraphs[0].runs[0].emphasis, .emphasis)
        grouped(undo) { editor.toggleUnderline(nil) }
        XCTAssertTrue(work.text.formattingWarningDismissed)
        let loaded = try Work(fileWrapper: work.fileWrapper())
        let reopened = EditorViewController.make(work: loaded, undoManager: UndoManager())
        _ = reopened.view
        XCTAssertTrue(loaded.text.formattingWarningDismissed)
        XCTAssertEqual(reopened.formattingMarkers.count, 0)
        XCTAssertNil(reopened.textView.layoutManager?.temporaryAttribute(.backgroundColor,
            atCharacterIndex: 0, effectiveRange: nil))
        XCTAssertFalse(Work().text.formattingWarningDismissed)
    }

    func testAppearancePopoverCheckboxChangesSelectedText() throws {
        let work = Work()
        let run = TextRun(string: "Meaning", emphasis: .emphasis)
        work.text = try TextUnit(identifier: work.text.identifier, title: work.text.title,
            paragraphs: [TextParagraph(identifier: .make(), runs: [run])])
        let (_, undo, editor) = makeEditor(work: work)
        let window = editor.makeWindowController()
        window.showWindow(nil)
        defer { window.close() }
        editor.textView.selectedRange = NSRange(location: 0, length: 5)
        let button = try XCTUnwrap(window.window?.toolbar?.items.compactMap { item -> NSButton? in
            item.label == "Appearance" ? item.view as? NSButton : nil
        }.first)
        button.performClick(nil)
        let popover = try XCTUnwrap(editor.appearancePopover)
        XCTAssertTrue(popover.isShown)
        let bold = try XCTUnwrap((popover.contentViewController as? AppearanceViewController)?.boldButton)
        XCTAssertEqual(bold.state, .off)
        grouped(undo) { bold.performClick(nil) }
        XCTAssertEqual(work.text.paragraphs[0].runs[0].presentation, TextPresentation(bold: true))
        XCTAssertEqual(bold.state, .on)
        popover.close()
    }

    func testAppearanceDecorationsSurviveUndoCopyAndSave() throws {
        let (work, undo, editor) = makeEditor()
        grouped(undo) {
            editor.textView.insertText("Retained words", replacementRange: NSRange(location: 0, length: 0))
            editor.textView.breakUndoCoalescing()
        }
        editor.textView.selectedRange = NSRange(location: 0, length: (editor.textView.string as NSString).length)
        grouped(undo) {
            editor.toggleEmphasis(nil)
            editor.toggleUnderline(nil)
            editor.toggleStrikethrough(nil)
        }
        let decorations = TextPresentation(underline: true, strikethrough: true)
        XCTAssertEqual(work.text.paragraphs[0].runs[0].presentation, decorations)
        XCTAssertEqual(editor.textView.textStorage?.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int, 1)
        XCTAssertEqual(editor.textView.textStorage?.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) as? Int, 1)
        undo.undo()
        XCTAssertEqual(work.text.paragraphs[0].runs[0].presentation, TextPresentation())
        undo.redo()
        let loaded = try Work(fileWrapper: work.fileWrapper())
        XCTAssertEqual(loaded.text.paragraphs[0].runs[0].presentation, decorations)
        XCTAssertEqual(loaded.text.paragraphs[0].runs[0].emphasis, .emphasis)
        XCTAssertEqual(loaded.text.string, "Retained words")
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        XCTAssertTrue(editor.textView.writeSelection(to: pasteboard, types: editor.textView.writablePasteboardTypes))
        grouped(undo) { XCTAssertTrue(editor.textView.readSelection(from: pasteboard)) }
        XCTAssertEqual(work.text.paragraphs[0].runs[0].presentation, decorations)
        editor.textView.selectedRange = NSRange(location: 0, length: (editor.textView.string as NSString).length)
        grouped(undo) { editor.clearFormatting(nil) }
        XCTAssertEqual(editor.textView.textStorage?.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int, 0)
        XCTAssertEqual(editor.textView.textStorage?.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) as? Int, 0)
        XCTAssertEqual(work.text.string, "Retained words")
    }

    func testEditorFormattingUndoAndParagraphIdentity() throws {
        let (work, undo, editor) = makeEditor()
        let paragraphID = work.text.paragraphs[0].identifier
        grouped(undo) {
            editor.textView.insertText("Hello world", replacementRange: NSRange(location: 0, length: 0))
            editor.textView.breakUndoCoalescing()
        }
        XCTAssertEqual(work.text.string, "Hello world")
        XCTAssertEqual(work.text.paragraphs[0].identifier, paragraphID)
        editor.textView.selectedRange = NSRange(location: 0, length: 5)
        grouped(undo) { editor.toggleEmphasis(nil) }
        XCTAssertEqual(work.text.paragraphs[0].runs[0].emphasis, .emphasis)
        XCTAssertEqual(work.text.paragraphs[0].runs[0].presentation, TextPresentation())
        XCTAssertTrue(editor.textView.undoManager === undo)
        XCTAssertTrue(undo.canUndo)
        undo.undo()
        XCTAssertEqual(editor.textView.textStorage?.attribute(NSAttributedString.Key("FolioTextEmphasis"),
            at: 0, effectiveRange: nil) as? Int, 0)
        XCTAssertEqual(work.text.paragraphs[0].runs[0].emphasis, .none)
        XCTAssertEqual(work.text.string, "Hello world")
        undo.redo()
        XCTAssertEqual(work.text.paragraphs[0].runs[0].emphasis, .emphasis)
    }

    func testTypingUndoRedoKeepsVisibleSemanticAndSavedTextInAgreement() throws {
        let (work, undo, editor) = makeEditor()
        let originalID = work.text.paragraphs[0].identifier
        let typed = "Café 👩🏽‍💻\nA second paragraph."
        grouped(undo) {
            editor.textView.insertText(typed, replacementRange: NSRange(location: 0, length: 0))
            editor.textView.breakUndoCoalescing()
        }
        let typedIDs = work.text.paragraphs.map(\.identifier)
        for step in 0..<3 {
            if step == 1 { undo.undo() }
            if step == 2 { undo.redo() }
            let expected = step == 1 ? "" : typed
            XCTAssertEqual(editor.textView.string, expected)
            XCTAssertEqual(work.text.string, expected)
            XCTAssertEqual(work.text.paragraphs[0].identifier, originalID)
            if step != 1 { XCTAssertEqual(work.text.paragraphs.map(\.identifier), typedIDs) }
            let loaded = try Work(fileWrapper: work.fileWrapper())
            XCTAssertEqual(loaded.text.string, expected)
            XCTAssertEqual(loaded.text.paragraphs.map(\.identifier), work.text.paragraphs.map(\.identifier))
        }
    }

    func testSplittingParagraphMakesDistinctIdentityAndRetainsOriginal() throws {
        let (work, undo, editor) = makeEditor()
        let paragraphID = work.text.paragraphs[0].identifier
        grouped(undo) {
            editor.textView.insertText("First\nSecond\n", replacementRange: NSRange(location: 0, length: 0))
        }
        XCTAssertEqual(work.text.string, "First\nSecond\n")
        XCTAssertEqual(work.text.paragraphs[0].identifier, paragraphID)
        XCTAssertEqual(Set(work.text.paragraphs.map(\.identifier)).count, 3)
        XCTAssertNotNil(try work.fileWrapper())
    }
}
