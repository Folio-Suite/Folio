// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import CoreData

// These internal class shells keep managed objects inside WriteKit. Xcode generates
// their properties from WorkV1 using Category/Extension code generation.
@objc(WorkRecord)
final class WorkRecord: NSManagedObject {
}

@objc(ManuscriptRecord)
final class ManuscriptRecord: NSManagedObject {
}

@objc(ContentUnitRecord)
final class ContentUnitRecord: NSManagedObject {
}

@objc(ParagraphRecord)
final class ParagraphRecord: NSManagedObject {
}

@objc(RunRecord)
final class RunRecord: NSManagedObject {
}

@objc(WorkHistoryReceiptRecord)
final class WorkHistoryReceiptRecord: NSManagedObject {
}
