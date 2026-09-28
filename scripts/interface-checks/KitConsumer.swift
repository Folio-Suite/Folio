// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import ComposerKit
import FolioKit
import ResearchKit
import TypographyKit
import UndoKit
import WriteKit

@MainActor
func exercisePublicInterfaces() throws {
    let identifier = try FolioIdentifier(rawValue: "unit-1")
    let paragraph = TextParagraph(identifier: try FolioIdentifier(rawValue: "paragraph-1"),
        runs: [TextRun(string: "Authored text", emphasis: .emphasis)])
    let unit = try TextUnit(identifier: identifier, title: "Chapter", paragraphs: [paragraph])
    let work = Work()
    work.manuscript = try Manuscript(identifier: work.manuscript.identifier, units: [unit])
    let reopened = try Work(fileWrapper: work.fileWrapper())
    precondition(reopened.text.string == "Authored text")
    let editor = EditorViewController.make(work: work, undoManager: UndoManager())
    _ = editor.makeWindowController()
    let library = try ResearchLibraryPackage.empty()
    try ResearchLibraryPackage.validate(library)
    let preview = ComposerPreview.compose(PublicationPreviewInput(sourceIdentifier: identifier.rawValue,
        text: unit.string, selectedBreaks: [unit.string.utf16.count], lineWidth: 400))
    precondition(preview.status == .complete)
}
