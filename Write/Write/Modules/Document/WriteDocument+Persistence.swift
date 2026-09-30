// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import FolioKit
import WriteKit

extension WriteDocument {
    @discardableResult func importResource(from sourceURL: URL) throws -> FolioIdentifier {
        let identifier = try work.importResource(from: sourceURL)
        updateChangeCount(.changeDone)
        return identifier
    }

    func removeResource(withIdentifier identifier: FolioIdentifier) throws {
        try work.removeResource(withIdentifier: identifier)
        updateChangeCount(.changeDone)
    }

    override func fileWrapper(ofType typeName: String) throws -> FileWrapper {
        try work.fileWrapper()
    }

    override func write(to url: URL, ofType typeName: String,
                        for saveOperation: NSDocument.SaveOperationType,
                        originalContentsURL absoluteOriginalContentsURL: URL?) throws {
        // NSDocument creates a safe-save location and performs the final replacement,
        // backup, Versions, and change-count work after this hook returns.
        try MainActor.assumeIsolated {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
            try work.stageSave(from: absoluteOriginalContentsURL, toEmptyPackageAt: url)
        }
    }

    override func read(from fileWrapper: FileWrapper, ofType typeName: String) throws {
        // NSDocument concurrent reading remains disabled. This synchronous Cocoa
        // override runs on the main thread; no FileWrapper crosses a task boundary.
        nonisolated(unsafe) let input = fileWrapper
        try MainActor.assumeIsolated {
            try adopt(Work(fileWrapper: input))
        }
    }

    override func read(from url: URL, ofType typeName: String) throws {
        // Keep package resources on disk while opening; Work verifies the closed
        // package and retains only its supported authored snapshot and resources.
        try MainActor.assumeIsolated {
            try adopt(Work(contentsOf: url))
        }
    }

}
