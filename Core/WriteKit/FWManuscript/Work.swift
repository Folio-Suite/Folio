// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import FolioKit
import Foundation

/// The current native Work document type.
public let workDocumentType = "app.foliosuite.Write.Doc"

@MainActor func verifiedValue<Value>(_ make: () throws -> Value) -> Value {
    do { return try make() }
    catch { preconditionFailure("Invalid internal Work value: \(error)") }
}

/// The main-actor authority for one open Work. Its authored snapshots use FolioKit values.
@MainActor public final class Work {
    public let identifier: FolioIdentifier
    public var manuscript: Manuscript {
        didSet { precondition(manuscript.identifier == oldValue.identifier) }
    }

    public var manuscriptIdentifier: FolioIdentifier { manuscript.identifier }

    /// The first Content Unit, independent of sidebar selection.
    public var text: TextUnit {
        get { manuscript.units[0] }
        set {
            var units = manuscript.units
            units[0] = newValue
            manuscript = verifiedValue { try Manuscript(identifier: manuscript.identifier, units: units) }
        }
    }

    public init() {
        identifier = .make()
        manuscript = verifiedValue { try Manuscript(identifier: .make(), units: [.makeEmpty()]) }
    }

    private init(identifier: FolioIdentifier, manuscript: Manuscript) {
        self.identifier = identifier
        self.manuscript = manuscript
    }

    public convenience init(fileWrapper: FileWrapper) throws {
        let snapshot = try WorkStore.readPackage(fileWrapper)
        self.init(identifier: snapshot.identifier, manuscript: snapshot.manuscript)
    }

    public func fileWrapper() throws -> FileWrapper {
        try WorkStore.package(workIdentifier: identifier, manuscript: manuscript)
    }

    public func text(withIdentifier identifier: FolioIdentifier) -> TextUnit? {
        manuscript.units.first { $0.identifier == identifier }
    }

    /// Replace an existing Content Unit while retaining Manuscript order.
    public func replaceText(_ text: TextUnit) {
        var units = manuscript.units
        guard let index = units.firstIndex(where: { $0.identifier == text.identifier }) else {
            preconditionFailure("Replacement must retain an existing Content Unit identity")
        }
        units[index] = text
        manuscript = verifiedValue { try Manuscript(identifier: manuscript.identifier, units: units) }
    }
}
