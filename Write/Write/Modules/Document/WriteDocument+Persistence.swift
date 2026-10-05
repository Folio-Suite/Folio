// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import FolioKit
import WriteKit

extension WriteDocument {
    @discardableResult func importResource(from sourceURL: URL) async throws -> FolioIdentifier {
        try await performResourceChange { history in
            try await history.importResource(from: sourceURL)
        }
    }

    func removeResource(withIdentifier identifier: FolioIdentifier) async throws {
        try await performResourceChange { history in
            try await history.removeResource(withIdentifier: identifier)
        }
    }

    // NSDocument can request an in-memory representation through this hook. Our
    // disk-save override below uses staged package URLs to avoid copying all resources.
    override func fileWrapper(ofType typeName: String) throws -> FileWrapper {
        try work.fileWrapper()
    }

    override func write(to url: URL, ofType typeName: String,
                        for saveOperation: NSDocument.SaveOperationType,
                        originalContentsURL absoluteOriginalContentsURL: URL?) throws {
        // NSDocument creates a safe-save location and performs the final replacement,
        // backup, Versions, and change-count work after this hook returns.
        try MainActor.assumeIsolated {
            if omittingHistoryForCurrentSave && saveOperation != .saveOperation {
                throw WorkHistoryError.busy
            }
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
            try work.stageSave(from: absoluteOriginalContentsURL, toEmptyPackageAt: url,
                               omittingHistory: omittingHistoryForCurrentSave)
        }
    }

    // AppKit (or a caller supplying an in-memory package) invokes this decoding hook.
    // The URL overload below is the disk-backed path for opening packages by URL.
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
