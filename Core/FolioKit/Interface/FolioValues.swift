// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import Foundation

/// Validation failures reported by the shared authored-value initializers.
public enum FolioValueError: Error, Equatable, Sendable {
    /// An identity was constructed from an empty string.
    case emptyIdentifier
    /// A Content Unit was constructed without a paragraph, even an empty one.
    case emptyParagraphs
    /// A Manuscript was constructed without a Content Unit.
    case emptyUnits
    /// Two Content Units in one Manuscript share an identity.
    case duplicateUnitIdentifier
}

/// A stable identity. Display labels and publication marks are separate values.
public struct FolioIdentifier: Hashable, Sendable {
    /// The stored identity spelling; it is not a display label or a file path.
    public let rawValue: String

    private init(uncheckedRawValue: String) { self.rawValue = uncheckedRawValue }

    /// Accepts a nonempty identity without normalizing or otherwise rewriting it.
    ///
    /// - Parameter rawValue: An existing identity to preserve exactly.
    /// - Throws: ``FolioValueError/emptyIdentifier`` if the string is empty.
    public init(rawValue: String) throws {
        guard !rawValue.isEmpty else { throw FolioValueError.emptyIdentifier }
        self.rawValue = rawValue
    }

    /// Creates an identity using the native format’s `o` prefix and a lowercase UUID.
    public static func make() -> Self {
        // Keep the identifier spelling used by existing native Documents.
        Self(uncheckedRawValue: "o" + UUID().uuidString.lowercased())
    }
}

/// Authored emphasis is independent of font appearance.
public enum TextEmphasis: UInt, Sendable {
    /// No semantic emphasis; independent presentation flags can still be applied.
    case none = 0
    /// The first semantic emphasis level; the renderer chooses its appearance.
    case emphasis = 1
    /// The second semantic emphasis level.
    case strongEmphasis = 2
    /// The third semantic emphasis level.
    case veryStrongEmphasis = 3
}

/// Visual choices can be combined without changing semantic emphasis.
public struct TextPresentation: Equatable, Hashable, Sendable {
    /// Requests a bold appearance without changing semantic emphasis.
    public let bold: Bool
    /// Requests an italic appearance without changing semantic emphasis.
    public let italic: Bool
    /// Requests an underline decoration.
    public let underline: Bool
    /// Requests a strikethrough decoration.
    public let strikethrough: Bool

    /// Combines independent appearance flags; omitted flags are disabled.
    public init(bold: Bool = false, italic: Bool = false, underline: Bool = false, strikethrough: Bool = false) {
        self.bold = bold
        self.italic = italic
        self.underline = underline
        self.strikethrough = strikethrough
    }
}

/// One immutable span of authored text.
public struct TextRun: Equatable, Sendable {
    /// The authored characters, preserved without normalization.
    public let string: String
    /// The run’s exclusive semantic emphasis category.
    public let emphasis: TextEmphasis
    /// Appearance choices applied independently of ``emphasis``.
    public let presentation: TextPresentation

    /// Creates a run without validating paragraph boundaries or persistence constraints.
    ///
    /// Empty strings are allowed. A persistence adapter may reject embedded paragraph
    /// separators; construction of this shared value alone does not validate a Work.
    public init(string: String, emphasis: TextEmphasis, presentation: TextPresentation = .init()) {
        self.string = string
        self.emphasis = emphasis
        self.presentation = presentation
    }
}

/// The authored paragraph alignment, interpreted by the presentation layer.
public enum ParagraphAlignment: UInt, Sendable {
    /// Lets the renderer resolve alignment from the text’s writing direction.
    case natural = 0
    /// Aligns text to the left edge.
    case left = 1
    /// Centers text within the available line width.
    case center = 2
    /// Aligns text to the right edge.
    case right = 3
    /// Requests justified alignment from the renderer.
    case justified = 4
}

/// An immutable paragraph whose identity survives text replacement.
public struct TextParagraph: Equatable, Sendable {
    /// Stable identity to retain when replacing this value with an edited snapshot.
    public let identifier: FolioIdentifier
    /// Runs in reading order; an empty array represents an empty paragraph.
    public let runs: [TextRun]
    /// The paragraph’s authored alignment.
    public let alignment: ParagraphAlignment

    /// Concatenates the run strings without inserting separators.
    public var string: String { runs.map(\.string).joined() }

    /// Creates a paragraph, retaining its supplied identity and ordered runs.
    ///
    /// This initializer does not check that the identity is unique in a containing
    /// Content Unit; the owning adapter enforces that wider invariant.
    public init(identifier: FolioIdentifier, runs: [TextRun] = [], alignment: ParagraphAlignment = .natural) {
        self.identifier = identifier
        self.runs = runs
        self.alignment = alignment
    }
}

private final class FolioValueBundleToken {}

/// A text Content Unit. Its title is authored once and does not follow later locale changes.
public struct TextUnit: Equatable, Sendable {
    /// Stable identity to retain when replacing this value with an edited snapshot.
    public let identifier: FolioIdentifier
    /// Authored title, stored independently of the body text and current UI language.
    public let title: String
    /// Nonempty paragraph sequence in authored order.
    public let paragraphs: [TextParagraph]
    /// Whether the author has dismissed this unit’s formatting warning.
    public let formattingWarningDismissed: Bool

    /// Joins paragraph strings with one newline between adjacent paragraphs.
    public var string: String { paragraphs.map(\.string).joined(separator: "\n") }

    /// Starts a new, empty Content Unit with the FolioKit-owned authored title.
    public static func makeEmpty() -> Self {
        let bundle = Bundle(identifier: "dev.foliosuite.FolioKit") ?? Bundle(for: FolioValueBundleToken.self)
        let title = NSLocalizedString(
            "content-unit.default-title",
            tableName: nil,
            bundle: bundle,
            value: "Untitled",
            comment: "Initial title of a newly created Content Unit. " +
                "Stored as authored content at creation; never retranslate existing titles."
        )
        do {
            return try Self(identifier: .make(), title: title, paragraphs: [TextParagraph(identifier: .make())])
        } catch {
            preconditionFailure("Invalid default Content Unit: \(error)")
        }
    }

    /// Creates a Content Unit with at least one paragraph.
    ///
    /// - Throws: ``FolioValueError/emptyParagraphs`` for an empty paragraph array.
    /// - Note: Paragraph identity uniqueness is checked by the owning persistence
    ///   adapter, not by this value initializer.
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
    /// Stable identity to retain when replacing this value with an edited snapshot.
    public let identifier: FolioIdentifier
    /// Nonempty Content Unit sequence, with distinct identities, in reading order.
    public let units: [TextUnit]

    /// Creates a reading-order snapshot without changing the supplied identities.
    ///
    /// - Throws: ``FolioValueError/emptyUnits`` for no units, or
    ///   ``FolioValueError/duplicateUnitIdentifier`` for repeated unit identities.
    public init(identifier: FolioIdentifier, units: [TextUnit]) throws {
        guard !units.isEmpty else { throw FolioValueError.emptyUnits }
        guard Set(units.map(\.identifier)).count == units.count else {
            throw FolioValueError.duplicateUnitIdentifier
        }
        self.identifier = identifier
        self.units = units
    }
}
