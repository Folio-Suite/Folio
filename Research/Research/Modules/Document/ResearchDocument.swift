// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import ResearchKit

/// AppKit’s registered document host for Research’s current Source Library shell.
/// The host retains the package; ResearchKit validates its store and supplies the window.
@MainActor
final class ResearchDocument: NSDocument {
    // Retaining the complete wrapper preserves additional package members. The
    // current shell has no catalog editing model that could reconstruct those members.
    private var libraryPackage: FileWrapper?

    override static var autosavesInPlace: Bool { true }

    // NSDocumentController invokes this after creating or reading the document.
    // Register the Kit-owned window with this document so AppKit can manage its lifecycle.
    override func makeWindowControllers() {
        MainActor.assumeIsolated {
            addWindowController(ResearchLibraryWindow.makeWindowController())
        }
    }

    // NSDocument requests bytes through this hook during saving. New documents lazily
    // create the empty store here; opened documents return their retained package.
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
