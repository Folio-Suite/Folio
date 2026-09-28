// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import Foundation

/// Synchronous staging for native packages. Return an independent result because
/// the temporary directory is removed before this function returns.
public enum PackageStaging {
    public static func withTemporaryDirectory<Result>(
        _ operation: (URL) throws -> Result
    ) throws -> Result {
        let directory = try TemporaryDirectory.create()
        defer { TemporaryDirectory.remove(directory) }
        return try operation(directory)
    }
}

private enum TemporaryDirectory {
    static func create() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        return directory
    }

    static func remove(_ directory: URL) {
        try? FileManager.default.removeItem(at: directory)
    }
}
