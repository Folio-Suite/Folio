// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import UniformTypeIdentifiers
import WriteKit
import XCTest
@testable import Write

@MainActor final class WriteTests: XCTestCase {
    func testDocumentWritesAndReopensNativePackage() throws {
        let document = WriteDocument()
        document.makeWindowControllers()
        defer { document.close() }
        let manuscript = try XCTUnwrap(document.windowControllers.first?.contentViewController as? ManuscriptViewController)
        let editor = try XCTUnwrap(manuscript.activeEditor)
        _ = editor.view
        editor.textView.insertText("A beginning.\nAnother paragraph.", replacementRange: NSRange(location: 0, length: 0))
        editor.textView.setSelectedRange(NSRange(location: 2, length: 9))
        editor.toggleBold(nil)
        manuscript.addContentUnit(nil)
        manuscript.unitTitle.stringValue = "Next Chapter"
        manuscript.renameContentUnit(nil)
        manuscript.activeEditor.textView.insertText("Independent second unit.",
            replacementRange: NSRange(location: 0, length: 0))
        let secondIdentifier = try XCTUnwrap(manuscript.selectedUnitIdentifier)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("flwrbundle")
        defer { try? FileManager.default.removeItem(at: url) }

        try document.write(to: url, ofType: workDocumentType)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.appendingPathComponent("Work.sqlite").path))
        let detectedType = try NSDocumentController.shared.typeForContents(of: url)
        let type = try XCTUnwrap(UTType(detectedType))
        XCTAssertEqual(type, UTType(workDocumentType))
        XCTAssertTrue(type.conforms(to: .package))
        XCTAssertTrue(type.conforms(to: .content))

        let loaded = try WriteDocument(contentsOf: url, ofType: detectedType)
        loaded.makeWindowControllers()
        defer { loaded.close() }
        let loadedManuscript = try XCTUnwrap(loaded.windowControllers.first?.contentViewController as? ManuscriptViewController)
        let reopened = try XCTUnwrap(loadedManuscript.activeEditor)
        _ = reopened.view
        XCTAssertEqual(reopened.textView.string, editor.textView.string)
        let font = try XCTUnwrap(reopened.textView.textStorage?.attribute(.font, at: 3, effectiveRange: nil) as? NSFont)
        XCTAssertTrue(NSFontManager.shared.traits(of: font).contains(.boldFontMask))
        loadedManuscript.selectUnit(withIdentifier: secondIdentifier)
        XCTAssertEqual(loadedManuscript.activeEditor.textView.string, "Independent second unit.")
        XCTAssertEqual(loadedManuscript.unitTitle.stringValue, "Next Chapter")
    }
}
