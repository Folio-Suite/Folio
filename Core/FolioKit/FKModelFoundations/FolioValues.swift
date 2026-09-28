// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import Foundation

/// Invalid authored snapshots are rejected before they cross a Kit boundary.
public enum FolioValueError: Error, Equatable, Sendable {
    case emptyIdentifier
    case emptyParagraphs
    case emptyUnits
    case duplicateUnitIdentifier
}

/// A stable identity. Display labels and publication marks are separate values.
public struct FolioIdentifier: Hashable, Sendable {
    public let rawValue: String

    private init(uncheckedRawValue: String) { self.rawValue = uncheckedRawValue }

    public init(rawValue: String) throws {
        guard !rawValue.isEmpty else { throw FolioValueError.emptyIdentifier }
        self.rawValue = rawValue
    }

    public static func make() -> Self {
        // Keep the identifier spelling used by existing native Documents.
        Self(uncheckedRawValue: "o" + UUID().uuidString.lowercased())
    }
}

/// Authored emphasis is independent of font appearance.
public enum TextEmphasis: UInt, Sendable {
    case none = 0
    case emphasis = 1
    case strongEmphasis = 2
    case veryStrongEmphasis = 3
}

/// Visual choices can be combined without changing semantic emphasis.
public struct TextPresentation: Equatable, Hashable, Sendable {
    public let bold: Bool
    public let italic: Bool
    public let underline: Bool
    public let strikethrough: Bool

    public init(bold: Bool = false, italic: Bool = false, underline: Bool = false, strikethrough: Bool = false) {
        self.bold = bold
        self.italic = italic
        self.underline = underline
        self.strikethrough = strikethrough
    }
}

/// One immutable span of authored text.
public struct TextRun: Equatable, Sendable {
    public let string: String
    public let emphasis: TextEmphasis
    public let presentation: TextPresentation

    public init(string: String, emphasis: TextEmphasis, presentation: TextPresentation = .init()) {
        self.string = string
        self.emphasis = emphasis
        self.presentation = presentation
    }
}

public enum ParagraphAlignment: UInt, Sendable {
    case natural = 0
    case left = 1
    case center = 2
    case right = 3
    case justified = 4
}

/// An immutable paragraph whose identity survives text replacement.
public struct TextParagraph: Equatable, Sendable {
    public let identifier: FolioIdentifier
    public let runs: [TextRun]
    public let alignment: ParagraphAlignment

    public var string: String { runs.map(\.string).joined() }

    public init(identifier: FolioIdentifier, runs: [TextRun] = [], alignment: ParagraphAlignment = .natural) {
        self.identifier = identifier
        self.runs = runs
        self.alignment = alignment
    }
}

private final class FolioValueBundleToken {}

/// A text Content Unit. Its title is authored once and does not follow later locale changes.
public struct TextUnit: Equatable, Sendable {
    public let identifier: FolioIdentifier
    public let title: String
    public let paragraphs: [TextParagraph]
    public let formattingWarningDismissed: Bool

    public var string: String { paragraphs.map(\.string).joined(separator: "\n") }

    /// Starts a new, empty Content Unit with the FolioKit-owned authored title.
    public static func makeEmpty() -> Self {
        let bundle = Bundle(identifier: "dev.foliosuite.FolioKit") ?? Bundle(for: FolioValueBundleToken.self)
        let title = NSLocalizedString("content-unit.default-title", tableName: nil, bundle: bundle,
                                      value: "Untitled", comment: "Initial title of a newly created Content Unit. Stored as authored content at creation; never retranslate existing titles.")
        do { return try Self(identifier: .make(), title: title, paragraphs: [TextParagraph(identifier: .make())]) }
        catch { preconditionFailure("Invalid default Content Unit: \(error)") }
    }

    public init(identifier: FolioIdentifier, title: String, paragraphs: [TextParagraph],
                formattingWarningDismissed: Bool = false) throws {
        guard !paragraphs.isEmpty else { throw FolioValueError.emptyParagraphs }
        self.identifier = identifier
        self.title = title
        self.paragraphs = paragraphs
        self.formattingWarningDismissed = formattingWarningDismissed
    }
}

/// The reading order of text Content Units, independent of editor selection.
public struct Manuscript: Equatable, Sendable {
    public let identifier: FolioIdentifier
    public let units: [TextUnit]

    public init(identifier: FolioIdentifier, units: [TextUnit]) throws {
        guard !units.isEmpty else { throw FolioValueError.emptyUnits }
        guard Set(units.map(\.identifier)).count == units.count else {
            throw FolioValueError.duplicateUnitIdentifier
        }
        self.identifier = identifier
        self.units = units
    }
}

// The Objective-C consumers remain on their existing selectors until their Kit slices
// migrate. This bridge delegates validation and text assembly to the Swift values.
@objc(FKSwiftValueBridge) public final class SwiftValueBridge: NSObject {
    @objc public static func newIdentifier() -> String { FolioIdentifier.make().rawValue }
    @objc public static func validIdentifier(_ identifier: String) -> Bool {
        (try? FolioIdentifier(rawValue: identifier)) != nil
    }
    @objc public static func validParagraphCount(_ count: Int) -> Bool { count > 0 }
    @objc public static func validUnitIdentifiers(_ identifiers: [String]) -> Bool {
        !identifiers.isEmpty && Set(identifiers).count == identifiers.count
    }
    @objc public static func joinedRuns(_ strings: [String]) -> String { strings.joined() }
    @objc public static func joinedParagraphs(_ strings: [String]) -> String { strings.joined(separator: "\n") }
}
