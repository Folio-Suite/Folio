// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import CoreData
import Darwin
import FolioKit
import Foundation

extension WorkStore {
  static func writeError() -> NSError {
    NSError(
      domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError,
      userInfo: [
        NSLocalizedDescriptionKey: NSLocalizedString(
          "work-package.save-verification.error", tableName: nil, bundle: bundle,
          value:
            "The Work could not be saved without losing information. The previous saved package has not been replaced.",
          comment:
            "Error when save verification fails. Reassure the user that the previous package remains intact."
        ),
      ])
  }

  static func checkIdentifiers(workIdentifier: FolioIdentifier, manuscript: Manuscript) throws {
    var identifiers: Set<String> = [workIdentifier.rawValue, manuscript.identifier.rawValue]
    guard identifiers.count == 2 else { throw writeError() }
    for unit in manuscript.units {
      guard identifiers.insert(unit.identifier.rawValue).inserted else { throw writeError() }
      for paragraph in unit.paragraphs {
        guard identifiers.insert(paragraph.identifier.rawValue).inserted else { throw writeError() }
      }
    }
  }

  private static func checkEmptyDestination(_ url: URL) throws {
    let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
    guard values.isDirectory == true, values.isSymbolicLink != true,
      try FileManager.default.contentsOfDirectory(atPath: url.path).isEmpty
    else { throw writeError() }
  }

  static func cloneOrCopy(_ original: URL, to staged: URL) throws -> (cloned: Int64, copied: Int64) {
    let bytes = Int64(
      (try FileManager.default.attributesOfItem(atPath: original.path)[.size] as? NSNumber)?
        .int64Value ?? 0)
    let result = original.path.withCString { source in
      staged.path.withCString { destination in clonefile(source, destination, 0) }
    }
    if result == 0 { return (bytes, 0) }
    let failure = errno
    guard failure == ENOTSUP || failure == EOPNOTSUPP || failure == EXDEV || failure == ENOSYS
    else {
      throw NSError(domain: NSPOSIXErrorDomain, code: Int(failure))
    }
    try FileManager.default.copyItem(at: original, to: staged)
    return (0, bytes)
  }

  private static func stagedStore(
    _ url: URL, workIdentifier: FolioIdentifier, manuscript: Manuscript, resources: [WorkResource]
  ) throws
    -> Changes {
    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: try model())
    let store = try coordinator.addPersistentStore(
      ofType: NSSQLiteStoreType, configurationName: nil,
      at: url, options: [NSSQLitePragmasOption: ["journal_mode": "DELETE"]])
    var removed = false
    defer { if !removed { try? coordinator.remove(store) } }
    let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
    context.persistentStoreCoordinator = coordinator
    let changed = try context.performAndWait {
      let changed = try update(context, workIdentifier: workIdentifier, manuscript: manuscript)
      let works = try fetch(WorkRecord.self, entity: "Work", in: context)
      guard let work = works.first, works.count == 1 else { throw writeError() }
      work.resourceMembership = try PropertyListEncoder().encode(resources)
      if context.hasChanges { try context.save() }
      return changed
    }
    try coordinator.remove(store)
    removed = true
    return changed
  }

  private static func runValue(_ object: RunRecord) throws -> TextRun {
    guard let string = object.text,
      let rawEmphasis = object.emphasis,
      let emphasis = TextEmphasis(rawValue: rawEmphasis.uintValue),
      let bold = object.bold,
      let italic = object.italic,
      let underline = object.underline,
      let strikethrough = object.strikethrough
    else { throw malformed() }
    return TextRun(
      string: string, emphasis: emphasis,
      presentation: TextPresentation(
        bold: bold.boolValue, italic: italic.boolValue,
        underline: underline.boolValue, strikethrough: strikethrough.boolValue))
  }

  private static func apply(_ run: TextRun, to object: RunRecord) {
    object.text = run.string
    object.emphasis = NSNumber(value: run.emphasis.rawValue)
    object.bold = NSNumber(value: run.presentation.bold)
    object.italic = NSNumber(value: run.presentation.italic)
    object.underline = NSNumber(value: run.presentation.underline)
    object.strikethrough = NSNumber(value: run.presentation.strikethrough)
  }

  struct Changes {
    var units = 0
    var paragraphs = 0
    var runs = 0
  }

  private struct UnitUpdateState {
    let work: WorkRecord
    let paragraphs: [String: ParagraphRecord]
    let context: NSManagedObjectContext
    var retainedParagraphs: Set<String> = []
    var changes = Changes()
  }

  private static func objects<Record: NSManagedObject>(
    _ type: Record.Type, entity: String, in context: NSManagedObjectContext,
    identifier: (Record) -> String?
  ) throws -> [String: Record] {
    let fetched = try fetch(type, entity: entity, in: context)
    var byID: [String: Record] = [:]
    for object in fetched {
      guard let identifier = identifier(object), byID.updateValue(object, forKey: identifier) == nil
      else { throw malformed() }
    }
    return byID
  }

  static func update(
    _ context: NSManagedObjectContext, workIdentifier: FolioIdentifier,
    manuscript: Manuscript
  ) throws -> Changes {
    let works = try fetch(WorkRecord.self, entity: "Work", in: context)
    let manuscripts = try fetch(ManuscriptRecord.self, entity: "Manuscript", in: context)
    guard works.count == 1, manuscripts.count == 1, let work = works.first,
      let storedManuscript = manuscripts.first,
      work.identifier == workIdentifier.rawValue,
      storedManuscript.identifier == manuscript.identifier.rawValue
    else {
      throw writeError()
    }
    let units = try objects(ContentUnitRecord.self, entity: "ContentUnit", in: context) {
      $0.identifier
    }
    var state = UnitUpdateState(
      work: work,
      paragraphs: try objects(ParagraphRecord.self, entity: "Paragraph", in: context) {
        $0.identifier
      }, context: context)
    var orderedUnits: [ContentUnitRecord] = []
    for text in manuscript.units {
      orderedUnits.append(
        try updateUnit(text, existing: units[text.identifier.rawValue], state: &state))
    }
    for (identifier, paragraph) in state.paragraphs
    where !state.retainedParagraphs.contains(identifier) {
      state.changes.runs += try ordered(paragraph.runs, as: RunRecord.self).count
      context.delete(paragraph)
      state.changes.paragraphs += 1
    }
    if try ordered(storedManuscript.contentUnits, as: ContentUnitRecord.self) != orderedUnits {
      storedManuscript.contentUnits = NSOrderedSet(array: orderedUnits)
    }
    let retainedUnits = Set(manuscript.units.map { $0.identifier.rawValue })
    for (identifier, unit) in units where !retainedUnits.contains(identifier) {
      context.delete(unit)
      state.changes.units += 1
    }
    return state.changes
  }

  private static func updateUnit(
    _ text: TextUnit, existing: ContentUnitRecord?, state: inout UnitUpdateState
  ) throws -> ContentUnitRecord {
    let unit: ContentUnitRecord
    var unitChanged = false
    if let existing {
      unit = existing
      if existing.title != text.title {
        existing.title = text.title
        unitChanged = true
      }
      if existing.formattingWarningDismissed?.boolValue
        != text.formattingWarningDismissed {
        existing.formattingWarningDismissed = NSNumber(value: text.formattingWarningDismissed)
        unitChanged = true
      }
    } else {
      unit = try insert(ContentUnitRecord.self, entity: "ContentUnit", in: state.context)
      unit.identifier = text.identifier.rawValue
      unit.title = text.title
      unit.work = state.work
      unit.formattingWarningDismissed = NSNumber(value: text.formattingWarningDismissed)
      unitChanged = true
    }
    var orderedParagraphs: [ParagraphRecord] = []
    for paragraph in text.paragraphs {
      state.retainedParagraphs.insert(paragraph.identifier.rawValue)
      orderedParagraphs.append(
        try updateParagraph(
          paragraph, unit: unit,
          existing: state.paragraphs[paragraph.identifier.rawValue],
          context: state.context, changes: &state.changes))
    }
    if try ordered(unit.paragraphs, as: ParagraphRecord.self) != orderedParagraphs {
      unit.paragraphs = NSOrderedSet(array: orderedParagraphs)
      unitChanged = true
    }
    if unitChanged { state.changes.units += 1 }
    return unit
  }

  private static func updateParagraph(
    _ paragraph: TextParagraph, unit: ContentUnitRecord,
    existing: ParagraphRecord?, context: NSManagedObjectContext,
    changes: inout Changes
  ) throws -> ParagraphRecord {
    let object: ParagraphRecord
    var paragraphChanged = false
    if let existing {
      object = existing
      if existing.alignment?.uintValue
        != paragraph.alignment.rawValue {
        existing.alignment = NSNumber(value: paragraph.alignment.rawValue)
        paragraphChanged = true
      }
      if existing.unit != unit {
        existing.unit = unit
        paragraphChanged = true
      }
    } else {
      object = try insert(ParagraphRecord.self, entity: "Paragraph", in: context)
      object.identifier = paragraph.identifier.rawValue
      object.alignment = NSNumber(value: paragraph.alignment.rawValue)
      object.unit = unit
      paragraphChanged = true
    }
    let changedRuns = try updateRuns(paragraph.runs, in: object, context: context)
    changes.runs += changedRuns
    if paragraphChanged || changedRuns > 0 { changes.paragraphs += 1 }
    return object
  }

  private static func updateRuns(
    _ runs: [TextRun], in paragraph: ParagraphRecord,
    context: NSManagedObjectContext
  ) throws -> Int {
    let oldRuns = try ordered(paragraph.runs, as: RunRecord.self)
    var orderedRuns: [RunRecord] = []
    var changed = 0
    for (index, run) in runs.enumerated() {
      if index < oldRuns.count {
        let existing = oldRuns[index]
        if try runValue(existing) != run {
          apply(run, to: existing)
          changed += 1
        }
        orderedRuns.append(existing)
      } else {
        let inserted = try insert(RunRecord.self, entity: "Run", in: context)
        inserted.paragraph = paragraph
        apply(run, to: inserted)
        orderedRuns.append(inserted)
        changed += 1
      }
    }
    for removed in oldRuns.dropFirst(runs.count) {
      context.delete(removed)
      changed += 1
    }
    if oldRuns != orderedRuns {
      paragraph.runs = NSOrderedSet(array: orderedRuns)
    }
    return changed
  }

  static func stageSave(
    workIdentifier: FolioIdentifier, manuscript: Manuscript, resources: WorkResourceStore,
    from originalPackageURL: URL?, to destinationPackageURL: URL,
    omitHistoryReceipts: Bool = false
  ) throws -> WorkSaveReport {
    try checkIdentifiers(workIdentifier: workIdentifier, manuscript: manuscript)
    try checkEmptyDestination(destinationPackageURL)
    if let originalPackageURL {
      try validateOriginal(
        originalPackageURL, destination: destinationPackageURL,
        workIdentifier: workIdentifier, manuscript: manuscript)
    }
    let storeURL = destinationPackageURL.appendingPathComponent("Work.sqlite")
    var completed = false
    defer {
      if !completed {
        for suffix in ["", "-wal", "-shm", "-journal"] {
          try? FileManager.default.removeItem(atPath: storeURL.path + suffix)
        }
        try? FileManager.default.removeItem(
          at: destinationPackageURL.appendingPathComponent("Package.json"))
        try? FileManager.default.removeItem(
          at: destinationPackageURL.appendingPathComponent("Resources"))
      }
    }
    let changed: Changes
    let copied: (cloned: Int64, copied: Int64)
    if let originalPackageURL {
      copied = try cloneOrCopy(
        originalPackageURL.appendingPathComponent("Work.sqlite"), to: storeURL)
      changed = try stagedStore(storeURL, workIdentifier: workIdentifier, manuscript: manuscript,
                                resources: resources.resources)
    } else {
      let wrapper = try package(workIdentifier: workIdentifier, manuscript: manuscript)
      guard let data = wrapper.fileWrappers?["Work.sqlite"]?.regularFileContents else {
        throw writeError()
      }
      try data.write(to: storeURL, options: .atomic)
      changed = Changes(
        units: manuscript.units.count,
        paragraphs: manuscript.units.reduce(0) { $0 + $1.paragraphs.count },
        runs: manuscript.units.reduce(0) { $0 + $1.paragraphs.reduce(0) { $0 + $1.runs.count } }
      )
      copied = (0, 0)
    }
    if originalPackageURL == nil {
      _ = try stagedStore(storeURL, workIdentifier: workIdentifier, manuscript: manuscript,
                          resources: resources.resources)
    }
    if omitHistoryReceipts { try stripHistoryReceipts(at: storeURL) }
    let resourceBytes = try resources.write(to: destinationPackageURL, retainingHistory: !omitHistoryReceipts)
    let verified = try openPackage(at: destinationPackageURL)
    guard verified.snapshot.identifier == workIdentifier,
      verified.snapshot.manuscript == manuscript,
      verified.resources.resources == resources.resources
    else { throw writeError() }
    completed = true
    return WorkSaveReport(
      changedContentUnits: changed.units, changedParagraphs: changed.paragraphs,
      changedRuns: changed.runs, clonedStoreBytes: copied.cloned, copiedStoreBytes: copied.copied,
      clonedResourceBytes: resourceBytes.cloned, copiedResourceBytes: resourceBytes.copied)
  }

  private static func validateOriginal(
    _ originalURL: URL, destination: URL,
    workIdentifier: FolioIdentifier, manuscript: Manuscript
  ) throws {
    let sourcePath = originalURL.resolvingSymlinksInPath().standardizedFileURL.path
    let destinationPath = destination.resolvingSymlinksInPath().standardizedFileURL.path
    guard destinationPath != sourcePath, !destinationPath.hasPrefix(sourcePath + "/") else {
      throw writeError()
    }
    let original = try openPackage(at: originalURL)
    guard original.snapshot.identifier == workIdentifier,
      original.snapshot.manuscript.identifier == manuscript.identifier
    else { throw writeError() }
  }
}
