// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import ResearchKit

@MainActor
final class ResearchDocument: NSDocument {
    private var libraryPackage: FileWrapper?

    override class var autosavesInPlace: Bool { true }

    override func makeWindowControllers() {
        MainActor.assumeIsolated {
            addWindowController(ResearchLibraryWindow.makeWindowController())
        }
    }

    override func fileWrapper(ofType typeName: String) throws -> FileWrapper {
        if let libraryPackage { return libraryPackage }
        let package = try ResearchLibraryPackage.empty()
        libraryPackage = package
        return package
    }

    override func read(from fileWrapper: FileWrapper, ofType typeName: String) throws {
        // NSDocument concurrent reading remains disabled. This synchronous Cocoa
        // override runs on the main thread; no FileWrapper crosses a task boundary.
        nonisolated(unsafe) let input = fileWrapper
        try MainActor.assumeIsolated {
            try ResearchLibraryPackage.validate(input)
            libraryPackage = input
        }
    }
}
