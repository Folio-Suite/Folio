// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import ResearchKit

@objc(FRDocument)
final class FRDocument: NSDocument {
    private var libraryPackage: FileWrapper?

    override class var autosavesInPlace: Bool { true }

    override func makeWindowControllers() {
        MainActor.assumeIsolated {
            let storyboard = NSStoryboard(name: "Main", bundle: nil)
            if let controller = storyboard.instantiateController(withIdentifier: "Document Window Controller") as? NSWindowController {
                addWindowController(controller)
            }
        }
    }

    override func fileWrapper(ofType typeName: String) throws -> FileWrapper {
        if let libraryPackage { return libraryPackage }
        let package = try ResearchLibraryPackage.empty()
        libraryPackage = package
        return package
    }

    override func read(from fileWrapper: FileWrapper, ofType typeName: String) throws {
        try ResearchLibraryPackage.validate(fileWrapper)
        libraryPackage = fileWrapper
    }
}
