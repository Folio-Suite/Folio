// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import CoreData

// These classes are private to WriteKit's store adapter. WorkV1 names each class
// explicitly; no generated managed-object interface is part of the Kit API.
@objc(WorkRecord)
final class WorkRecord: NSManagedObject {
  @NSManaged var identifier: String?
  @NSManaged var formatVersion: NSNumber?
  @NSManaged var resourceMembership: Data?
  @NSManaged var manuscript: ManuscriptRecord?
  @NSManaged var units: Set<ContentUnitRecord>?
  @NSManaged var historyReceipts: Set<WorkHistoryReceiptRecord>?
}

@objc(ManuscriptRecord)
final class ManuscriptRecord: NSManagedObject {
  @NSManaged var identifier: String?
  @NSManaged var work: WorkRecord?
  @NSManaged var contentUnits: NSOrderedSet?
}

@objc(ContentUnitRecord)
final class ContentUnitRecord: NSManagedObject {
  @NSManaged var identifier: String?
  @NSManaged var title: String?
  @NSManaged var formattingWarningDismissed: NSNumber?
  @NSManaged var manuscript: ManuscriptRecord?
  @NSManaged var paragraphs: NSOrderedSet?
  @NSManaged var work: WorkRecord?
}

@objc(ParagraphRecord)
final class ParagraphRecord: NSManagedObject {
  @NSManaged var identifier: String?
  @NSManaged var alignment: NSNumber?
  @NSManaged var runs: NSOrderedSet?
  @NSManaged var unit: ContentUnitRecord?
}

@objc(RunRecord)
final class RunRecord: NSManagedObject {
  @NSManaged var bold: NSNumber?
  @NSManaged var emphasis: NSNumber?
  @NSManaged var italic: NSNumber?
  @NSManaged var strikethrough: NSNumber?
  @NSManaged var text: String?
  @NSManaged var underline: NSNumber?
  @NSManaged var paragraph: ParagraphRecord?
}

@objc(WorkHistoryReceiptRecord)
final class WorkHistoryReceiptRecord: NSManagedObject {
  @NSManaged var accepted: NSNumber?
  @NSManaged var commandID: String?
  @NSManaged var evidence: Data?
  @NSManaged var fingerprint: String?
  @NSManaged var work: WorkRecord?
}
