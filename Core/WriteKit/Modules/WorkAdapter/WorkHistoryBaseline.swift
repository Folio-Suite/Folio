// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import Foundation

/// Keeps the original store identity and object IDs when a saved Work first enables history.
/// A private clone also survives a temporary FileWrapper import or replacement of its source.
final class WorkHistoryBaseline {
  let directory: URL

  init(packageURL: URL, resources: WorkResourceStore) throws {
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    do {
      _ = try WorkStore.cloneOrCopy(
        packageURL.appendingPathComponent("Work.sqlite"),
        to: directory.appendingPathComponent("Work.sqlite"))
      _ = try resources.write(to: directory)
    } catch {
      try? FileManager.default.removeItem(at: directory)
      throw error
    }
  }

  deinit { try? FileManager.default.removeItem(at: directory) }
}
