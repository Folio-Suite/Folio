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
    _ url: URL, workIdentifier: FolioIdentifier, manuscript: Manuscript
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
      if context.hasChanges { try context.save() }
      return changed
    }
    try coordinator.remove(store)
    removed = true
    return changed
  }

  private static func runValue(_ object: NSManagedObject) throws -> TextRun {
    guard let string = object.value(forKey: "text") as? String,
      let rawEmphasis = object.value(forKey: "emphasis") as? NSNumber,
      let emphasis = TextEmphasis(rawValue: rawEmphasis.uintValue),
      let bold = object.value(forKey: "bold") as? NSNumber,
      let italic = object.value(forKey: "italic") as? NSNumber,
      let underline = object.value(forKey: "underline") as? NSNumber,
      let strikethrough = object.value(forKey: "strikethrough") as? NSNumber
    else { throw malformed() }
    return TextRun(
      string: string, emphasis: emphasis,
      presentation: TextPresentation(
        bold: bold.boolValue, italic: italic.boolValue,
        underline: underline.boolValue, strikethrough: strikethrough.boolValue))
  }

  private static func apply(_ run: TextRun, to object: NSManagedObject) {
    object.setValuesForKeys([
      "text": run.string, "emphasis": run.emphasis.rawValue,
      "bold": run.presentation.bold, "italic": run.presentation.italic,
      "underline": run.presentation.underline, "strikethrough": run.presentation.strikethrough,
    ])
  }

  struct Changes {
    var units = 0
    var paragraphs = 0
    var runs = 0
  }

  private struct UnitUpdateState {
    let work: NSManagedObject
    let paragraphs: [String: NSManagedObject]
    let context: NSManagedObjectContext
    var retainedParagraphs: Set<String> = []
    var changes = Changes()
  }

  private static func objects(named entity: String, in context: NSManagedObjectContext) throws
    -> [String: NSManagedObject] {
    let fetched = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: entity))
    var byID: [String: NSManagedObject] = [:]
    for object in fetched {
      guard let identifier = object.value(forKey: "identifier") as? String,
        byID.updateValue(object, forKey: identifier) == nil
      else { throw malformed() }
    }
    return byID
  }

  static func update(
    _ context: NSManagedObjectContext, workIdentifier: FolioIdentifier,
    manuscript: Manuscript
  ) throws -> Changes {
    let works = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "Work"))
    let manuscripts = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "Manuscript"))
    guard works.count == 1, manuscripts.count == 1, let work = works.first,
      let storedManuscript = manuscripts.first,
      work.value(forKey: "identifier") as? String == workIdentifier.rawValue,
      storedManuscript.value(forKey: "identifier") as? String == manuscript.identifier.rawValue
    else {
      throw writeError()
    }
    let units = try objects(named: "ContentUnit", in: context)
    var state = UnitUpdateState(
      work: work, paragraphs: try objects(named: "Paragraph", in: context), context: context)
    var orderedUnits: [NSManagedObject] = []
    for text in manuscript.units {
      orderedUnits.append(
        try updateUnit(text, existing: units[text.identifier.rawValue], state: &state))
    }
    for (identifier, paragraph) in state.paragraphs
    where !state.retainedParagraphs.contains(identifier) {
      state.changes.runs += try ordered(paragraph, "runs").count
      context.delete(paragraph)
      state.changes.paragraphs += 1
    }
    if try ordered(storedManuscript, "contentUnits") != orderedUnits {
      storedManuscript.setValue(NSOrderedSet(array: orderedUnits), forKey: "contentUnits")
    }
    let retainedUnits = Set(manuscript.units.map { $0.identifier.rawValue })
    for (identifier, unit) in units where !retainedUnits.contains(identifier) {
      context.delete(unit)
      state.changes.units += 1
    }
    return state.changes
  }

  private static func updateUnit(
    _ text: TextUnit, existing: NSManagedObject?, state: inout UnitUpdateState
  ) throws -> NSManagedObject {
    let unit: NSManagedObject
    var unitChanged = false
    if let existing {
      unit = existing
      if existing.value(forKey: "title") as? String != text.title {
        existing.setValue(text.title, forKey: "title")
        unitChanged = true
      }
      if (existing.value(forKey: "formattingWarningDismissed") as? NSNumber)?.boolValue
        != text.formattingWarningDismissed {
        existing.setValue(text.formattingWarningDismissed, forKey: "formattingWarningDismissed")
        unitChanged = true
      }
    } else {
      unit = insert(
        "ContentUnit", in: state.context,
        values: [
        "identifier": text.identifier.rawValue,
        "title": text.title, "work": state.work,
          "formattingWarningDismissed": text.formattingWarningDismissed,
        ])
      unitChanged = true
    }
    var orderedParagraphs: [NSManagedObject] = []
    for paragraph in text.paragraphs {
      state.retainedParagraphs.insert(paragraph.identifier.rawValue)
      orderedParagraphs.append(
        try updateParagraph(
          paragraph, unit: unit,
          existing: state.paragraphs[paragraph.identifier.rawValue],
          context: state.context, changes: &state.changes))
    }
    if try ordered(unit, "paragraphs") != orderedParagraphs {
      unit.setValue(NSOrderedSet(array: orderedParagraphs), forKey: "paragraphs")
      unitChanged = true
    }
    if unitChanged { state.changes.units += 1 }
    return unit
  }

  private static func updateParagraph(
    _ paragraph: TextParagraph, unit: NSManagedObject,
    existing: NSManagedObject?, context: NSManagedObjectContext,
    changes: inout Changes
  ) throws -> NSManagedObject {
    let object: NSManagedObject
    var paragraphChanged = false
    if let existing {
      object = existing
      if (existing.value(forKey: "alignment") as? NSNumber)?.uintValue
        != paragraph.alignment.rawValue {
        existing.setValue(paragraph.alignment.rawValue, forKey: "alignment")
        paragraphChanged = true
      }
      if existing.value(forKey: "unit") as? NSManagedObject != unit {
        existing.setValue(unit, forKey: "unit")
        paragraphChanged = true
      }
    } else {
      object = insert(
        "Paragraph", in: context,
        values: [
          "identifier": paragraph.identifier.rawValue,
          "alignment": paragraph.alignment.rawValue, "unit": unit,
        ])
      paragraphChanged = true
    }
    let changedRuns = try updateRuns(paragraph.runs, in: object, context: context)
    changes.runs += changedRuns
    if paragraphChanged || changedRuns > 0 { changes.paragraphs += 1 }
    return object
  }

  private static func updateRuns(
    _ runs: [TextRun], in paragraph: NSManagedObject,
    context: NSManagedObjectContext
  ) throws -> Int {
    let oldRuns = try ordered(paragraph, "runs")
    var orderedRuns: [NSManagedObject] = []
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
        let inserted = insert("Run", in: context, values: ["paragraph": paragraph])
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
      paragraph.setValue(NSOrderedSet(array: orderedRuns), forKey: "runs")
    }
    return changed
  }

  static func stageSave(
    workIdentifier: FolioIdentifier, manuscript: Manuscript, resources: WorkResourceStore,
    from originalPackageURL: URL?, to destinationPackageURL: URL
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
      changed = try stagedStore(storeURL, workIdentifier: workIdentifier, manuscript: manuscript)
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
    let resourceBytes = try resources.write(to: destinationPackageURL)
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
