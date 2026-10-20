// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import FolioKit
import Foundation
import SQLite3
import WriteKit
import XCTest

@MainActor enum WorkPersistenceFixtures {
  static func id(_ raw: String) throws -> FolioIdentifier { try FolioIdentifier(rawValue: raw) }

  static func sampleWork() throws -> Work {
    let work = Work()
    let runs = [
      TextRun(string: "Meaning & <words> 👑 ", emphasis: .emphasis),
      TextRun(string: "strong", emphasis: .strongEmphasis),
      TextRun(
        string: " bold italic  ", emphasis: .none,
        presentation: TextPresentation(bold: true, italic: true)),
    ]
    let paragraphs = [
      TextParagraph(identifier: try id("paragraph-one"), runs: runs, alignment: .center),
      TextParagraph(identifier: .make()), TextParagraph(identifier: .make()),
    ]
    work.text = try TextUnit(
      identifier: work.text.identifier, title: work.text.title, paragraphs: paragraphs)
    return work
  }

  static func package(_ original: FileWrapper, updatingStore sql: String) throws -> FileWrapper {
    let packageURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try original.write(to: packageURL, options: .atomic, originalContentsURL: nil)
    defer { try? FileManager.default.removeItem(at: packageURL) }
    let storeURL = packageURL.appendingPathComponent("Work.sqlite")
    var database: OpaquePointer?
    guard sqlite3_open_v2(storeURL.path, &database, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK,
      let database
    else {
      if let database { sqlite3_close(database) }
      throw NSError(domain: "WriteKitPersistenceTests.SQLite", code: 1)
    }
    let update = sqlite3_exec(database, sql, nil, nil, nil)
    let changed = sqlite3_changes(database)
    let close = sqlite3_close(database)
    guard update == SQLITE_OK, changed == 1, close == SQLITE_OK
    else { throw NSError(domain: "WriteKitPersistenceTests.SQLite", code: 2) }
    return try FileWrapper(url: packageURL, options: .immediate)
  }

}
