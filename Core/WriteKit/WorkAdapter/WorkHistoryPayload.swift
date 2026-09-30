// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import FolioKit
import Foundation

/// Versioned host data. UndoKit never interprets this representation.
struct WorkHistoryPayload: Codable {
    struct Unit: Codable {
        struct Paragraph: Codable {
            struct Run: Codable {
                let string: String
                let emphasis: UInt
                let bold: Bool
                let italic: Bool
                let underline: Bool
                let strikethrough: Bool
            }
            let identifier: String
            let alignment: UInt
            let runs: [Run]
        }
        let identifier: String
        let title: String
        let dismissed: Bool
        let paragraphs: [Paragraph]
    }
    let identifier: String
    let units: [Unit]

    init(_ manuscript: Manuscript) {
        identifier = manuscript.identifier.rawValue
        units = manuscript.units.map { unit in
            Unit(identifier: unit.identifier.rawValue, title: unit.title,
                 dismissed: unit.formattingWarningDismissed,
                 paragraphs: unit.paragraphs.map { paragraph in
                Unit.Paragraph(identifier: paragraph.identifier.rawValue, alignment: paragraph.alignment.rawValue,
                    runs: paragraph.runs.map { run in
                        Unit.Paragraph.Run(string: run.string, emphasis: run.emphasis.rawValue,
                            bold: run.presentation.bold, italic: run.presentation.italic,
                            underline: run.presentation.underline, strikethrough: run.presentation.strikethrough)
                    })
            })
        }
    }

    func manuscript() throws -> Manuscript {
        var identifiers: Set<String> = [identifier]
        guard !identifier.isEmpty, !units.isEmpty, units.count <= 100_000 else { throw WorkStore.malformed() }
        let decoded = try units.map { unit in
            guard identifiers.insert(unit.identifier).inserted, !unit.paragraphs.isEmpty else {
                throw WorkStore.malformed()
            }
            let paragraphs = try unit.paragraphs.map { paragraph in
                guard identifiers.insert(paragraph.identifier).inserted,
                      let alignment = ParagraphAlignment(rawValue: paragraph.alignment) else { throw WorkStore.malformed() }
                let runs = try paragraph.runs.map { run in
                    guard let emphasis = TextEmphasis(rawValue: run.emphasis),
                          run.string.rangeOfCharacter(from: CharacterSet(charactersIn: "\r\n\u{2029}")) == nil else {
                        throw WorkStore.malformed()
                    }
                    return TextRun(string: run.string, emphasis: emphasis,
                        presentation: TextPresentation(bold: run.bold, italic: run.italic,
                            underline: run.underline, strikethrough: run.strikethrough))
                }
                return TextParagraph(identifier: try FolioIdentifier(rawValue: paragraph.identifier),
                                     runs: runs, alignment: alignment)
            }
            return try TextUnit(identifier: FolioIdentifier(rawValue: unit.identifier), title: unit.title,
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
