// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import FolioKit
import Foundation

/// Versioned host data. UndoKit never interprets this representation.
private struct WorkHistoryPayloadRun: Codable {
  let string: String
  let emphasis: UInt
  let bold: Bool
  let italic: Bool
  let underline: Bool
  let strikethrough: Bool
}

private struct WorkHistoryPayloadParagraph: Codable {
  let identifier: String
  let alignment: UInt
  let runs: [WorkHistoryPayloadRun]
}

private struct WorkHistoryPayloadUnit: Codable {
  let identifier: String
  let title: String
  let dismissed: Bool
  let paragraphs: [WorkHistoryPayloadParagraph]
}

struct WorkHistoryPayload: Codable {
  private let identifier: String
  private let units: [WorkHistoryPayloadUnit]

  init(_ manuscript: Manuscript) {
    identifier = manuscript.identifier.rawValue
    units = manuscript.units.map { unit in
      WorkHistoryPayloadUnit(
        identifier: unit.identifier.rawValue, title: unit.title,
        dismissed: unit.formattingWarningDismissed,
        paragraphs: unit.paragraphs.map { paragraph in
          WorkHistoryPayloadParagraph(
            identifier: paragraph.identifier.rawValue, alignment: paragraph.alignment.rawValue,
            runs: paragraph.runs.map { run in
              WorkHistoryPayloadRun(
                string: run.string, emphasis: run.emphasis.rawValue,
                bold: run.presentation.bold, italic: run.presentation.italic,
                underline: run.presentation.underline, strikethrough: run.presentation.strikethrough
              )
            })
        })
    }
  }

  func manuscript() throws -> Manuscript {
    var identifiers: Set<String> = [identifier]
    guard !identifier.isEmpty, !units.isEmpty, units.count <= 100_000 else {
      throw WorkStore.malformed()
    }
    let decoded = try units.map { unit in
      guard identifiers.insert(unit.identifier).inserted, !unit.paragraphs.isEmpty else {
        throw WorkStore.malformed()
      }
      let paragraphs = try unit.paragraphs.map { paragraph in
        guard identifiers.insert(paragraph.identifier).inserted,
          let alignment = ParagraphAlignment(rawValue: paragraph.alignment)
        else { throw WorkStore.malformed() }
        let runs = try paragraph.runs.map { run in
          guard let emphasis = TextEmphasis(rawValue: run.emphasis),
            run.string.rangeOfCharacter(from: CharacterSet(charactersIn: "\r\n\u{2029}")) == nil
          else {
            throw WorkStore.malformed()
          }
          return TextRun(
            string: run.string, emphasis: emphasis,
            presentation: TextPresentation(
              bold: run.bold, italic: run.italic,
              underline: run.underline, strikethrough: run.strikethrough))
        }
        return TextParagraph(
          identifier: try FolioIdentifier(rawValue: paragraph.identifier),
          runs: runs, alignment: alignment)
      }
      return try TextUnit(
        identifier: FolioIdentifier(rawValue: unit.identifier), title: unit.title,
        paragraphs: paragraphs, formattingWarningDismissed: unit.dismissed)
    }
    return try Manuscript(identifier: FolioIdentifier(rawValue: identifier), units: decoded)
  }

  static func encode(_ manuscript: Manuscript) throws -> Data {
    let encoder = PropertyListEncoder()
    encoder.outputFormat = .binary
    return try encoder.encode(Self(manuscript))
  }

  static func decode(_ data: Data) throws -> Manuscript {
    guard data.count <= 16 * 1_024 * 1_024 else { throw WorkStore.malformed() }
    return try PropertyListDecoder().decode(Self.self, from: data).manuscript()
  }
}

/// A coherent Work checkpoint or command boundary; resource bytes stay out of history payloads.
struct WorkHistoryState: Equatable {
  let manuscript: Manuscript
  let resources: [WorkResource]
}

struct WorkHistoryStatePayload: Codable {
  let manuscript: WorkHistoryPayload
  let resources: [WorkResource]

  init(_ state: WorkHistoryState) {
    manuscript = WorkHistoryPayload(state.manuscript)
    resources = state.resources
  }

  func state() throws -> WorkHistoryState {
    guard resources.count <= 4_096,
      Set(resources.map(\.identifier)).count == resources.count,
      resources == resources.sorted(by: { $0.identifier.rawValue < $1.identifier.rawValue }) else {
      throw WorkStore.resourceError()
    }
    return WorkHistoryState(manuscript: try manuscript.manuscript(), resources: resources)
  }

  static func encode(_ state: WorkHistoryState) throws -> Data {
    let encoder = PropertyListEncoder()
    encoder.outputFormat = .binary
    return try encoder.encode(Self(state))
  }

  static func decode(_ data: Data) throws -> WorkHistoryState {
    guard data.count <= 16 * 1_024 * 1_024 else { throw WorkStore.malformed() }
    return try PropertyListDecoder().decode(Self.self, from: data).state()
  }
}
