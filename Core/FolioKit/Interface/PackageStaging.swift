// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import Foundation

/// Synchronous staging for native packages with scoped temporary-file ownership.
/// Return an independent result; the helper attempts cleanup as the operation exits.
public enum PackageStaging {
    /// Runs an operation in a newly created directory and attempts cleanup on every exit.
    ///
    /// The closure executes synchronously on the caller’s thread. Read or copy any
    /// output you need before it returns; a returned URL does not extend the files’ lifetime.
    ///
    /// - Parameter operation: Work to perform while the directory exists.
    /// - Returns: The closure’s result, which must remain usable after cleanup.
    /// - Throws: A directory-creation error or the error thrown by `operation`.
    ///   Cleanup is best effort and does not replace the operation’s result or error.
    public static func withTemporaryDirectory<Result>(
        _ operation: (URL) throws -> Result
    ) throws -> Result {
        let directory = try TemporaryDirectory.create()
        defer { TemporaryDirectory.remove(directory) }
        return try operation(directory)
    }
}
