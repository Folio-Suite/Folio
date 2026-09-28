// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import WriteKit

private struct DocumentInput: @unchecked Sendable {
    let wrapper: FileWrapper
}

@MainActor @objc(FWDocument) final class WriteDocument: NSDocument {
    private(set) var work = Work()

    override init() {
        super.init()
        hasUndoManager = true
    }

    override class var autosavesInPlace: Bool { true }

    override func makeWindowControllers() {
        let editor = ManuscriptViewController.make(work: work, undoManager: undoManager!)
        editor.workDidChange = { [weak self] in
            guard let self, self.undoManager?.isUndoing != true, self.undoManager?.isRedoing != true else { return }
            self.updateChangeCount(.changeDone)
        }
        let controller = editor.makeWindowController()
        controller.window?.center()
        addWindowController(controller)
    }

    override func fileWrapper(ofType typeName: String) throws -> FileWrapper {
        try work.fileWrapper()
    }

    override func read(from fileWrapper: FileWrapper, ofType typeName: String) throws {
        let input = DocumentInput(wrapper: fileWrapper)
        try MainActor.assumeIsolated {
            let opened = try Work(fileWrapper: input.wrapper)
            undoManager?.removeAllActions()
            work = opened
            for controller in windowControllers {
                (controller.contentViewController as? ManuscriptViewController)?.work = opened
            }
        }
    }
}
