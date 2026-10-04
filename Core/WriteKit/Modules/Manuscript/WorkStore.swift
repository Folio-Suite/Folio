// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import CoreData
import FolioKit
import Foundation

/// Core Data stays behind the public Work snapshot boundary.
enum WorkStore {
  struct Snapshot: Sendable {
    let identifier: FolioIdentifier
    let manuscript: Manuscript
    let resourceMembership: [WorkResource]?
  }

  private final class BundleToken {}
  static var bundle: Bundle {
    Bundle(identifier: "dev.foliosuite.WriteKit") ?? Bundle(for: BundleToken.self)
  }

  private static func readError(_ reason: String) -> NSError {
    NSError(
      domain: NSCocoaErrorDomain, code: NSFileReadCorruptFileError,
      userInfo: [
        NSLocalizedDescriptionKey: NSLocalizedString(
          "work-package.read.error", tableName: nil, bundle: bundle,
          value: "Write cannot read this Work package.",
          comment:
            "Error summary when opening a native Work fails. Write is the app name; Work is a Folio domain term."
        ),
        NSLocalizedRecoverySuggestionErrorKey: reason,
      ])
  }

  static func model() throws -> NSManagedObjectModel {
    if let url = bundle.url(forResource: "Work", withExtension: "momd"),
      let model = NSManagedObjectModel(contentsOf: url) {
      return model
    }
    throw NSError(
      domain: NSCocoaErrorDomain, code: NSFileReadUnknownError,
      userInfo: [
        NSLocalizedDescriptionKey: NSLocalizedString(
          "work-model.load.error", tableName: nil, bundle: bundle,
          value: "WriteKit’s data model could not be loaded.",
          comment: "Error summary for a missing model resource; WriteKit is a framework name."),
        NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(
          "work-model.load.recovery", tableName: nil, bundle: bundle,
          value: "Rebuild or reinstall the application with its Work model resource.",
          comment:
            "Recovery advice for developers or users. Work is the compiled model resource name."),
      ])
  }

  private static func withStore<Result: Sendable>(
    package: FileWrapper?, writing: Bool,
    operation: @Sendable (NSManagedObjectContext) throws -> Result
  ) throws -> (Result, Data?) {
    let storeModel = try model()
    return try PackageStaging.withTemporaryDirectory { directory in
      let storeURL = directory.appendingPathComponent("Work.sqlite")
      if !writing {
        guard let files = package?.fileWrappers, files.count == 1,
          let file = files["Work.sqlite"], file.isRegularFile,
          let contents = file.regularFileContents
        else {
          throw readError(
            NSLocalizedString(
              "work-package.structure.recovery", tableName: nil, bundle: bundle,
              value:
                "Expected a native Work package containing Work.sqlite. "
                  + "Extra files and unfamiliar formats are left untouched.",
              comment: "Recovery advice for an invalid package. Preserve the filename Work.sqlite.")
          )
        }
        try contents.write(to: storeURL, options: .atomic)
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
          ofType: NSSQLiteStoreType, at: storeURL)
        guard storeModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        else {
          throw readError(
            NSLocalizedString(
              "work-package.version.recovery", tableName: nil, bundle: bundle,
              value:
                "This Work uses a different model version. Open it with a compatible version of Write.",
              comment:
                "Recovery advice for an unsupported Work model version. Write is the app name."))
        }
      }

      let coordinator = NSPersistentStoreCoordinator(managedObjectModel: storeModel)
      let store = try coordinator.addPersistentStore(
        ofType: NSSQLiteStoreType, configurationName: nil,
        at: storeURL,
        options: [
          NSReadOnlyPersistentStoreOption: !writing,
          NSSQLitePragmasOption: ["journal_mode": "DELETE"],
        ])
      var removed = false
      defer { if !removed { try? coordinator.remove(store) } }
      let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
      context.persistentStoreCoordinator = coordinator
      let result = try context.performAndWait { try operation(context) }
      try coordinator.remove(store)
      removed = true
      return (result, writing ? try Data(contentsOf: storeURL) : nil)
    }
  }

  private static func identifier(_ raw: String?, seen: inout Set<String>)
    throws -> FolioIdentifier {
    guard let raw, !seen.contains(raw),
      let value = try? FolioIdentifier(rawValue: raw)
    else {
      throw readError(
        NSLocalizedString(
          "work-package.manuscript.recovery", tableName: nil, bundle: bundle,
          value:
            "The store contains invalid or unsupported Manuscript structure; no content has been changed.",
          comment: "Recovery explanation for invalid data. Manuscript is a Folio domain term."))
    }
    seen.insert(raw)
    return value
  }

  static func ordered<Record: NSManagedObject>(_ values: NSOrderedSet?, as: Record.Type)
    throws -> [Record] {
    guard let values, let objects = values.array as? [Record]
    else { throw malformed() }
    return objects
  }

  static func fetch<Record: NSManagedObject>(
    _ type: Record.Type, entity: String, in context: NSManagedObjectContext
  ) throws -> [Record] {
    try context.fetch(NSFetchRequest<Record>(entityName: entity))
  }

  static func insert<Record: NSManagedObject>(
    _ type: Record.Type, entity: String, in context: NSManagedObjectContext
  ) throws -> Record {
    guard let record = NSEntityDescription.insertNewObject(forEntityName: entity, into: context)
      as? Record
    else { throw writeError() }
    return record
  }

  static func malformed() -> NSError {
    readError(
      NSLocalizedString(
        "work-package.manuscript.recovery", tableName: nil, bundle: bundle,
        value:
          "The store contains invalid or unsupported Manuscript structure; no content has been changed.",
        comment: "Recovery explanation for invalid data. Manuscript is a Folio domain term."))
  }

  static func readPackage(_ package: FileWrapper) throws -> Snapshot {
    try withStore(package: package, writing: false) { context in
      try decode(context)
    }.0
  }

  /// The URL path validates a closed store without copying its SQLite bytes into memory.
  static func readStore(at storeURL: URL) throws -> Snapshot {
    let storeModel = try model()
    let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
      ofType: NSSQLiteStoreType, at: storeURL)
    guard storeModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) else {
      throw readError(
        NSLocalizedString(
          "work-package.version.recovery", tableName: nil, bundle: bundle,
          value:
            "This Work uses a different model version. Open it with a compatible version of Write.",
          comment: "Recovery advice for an unsupported Work model version. Write is the app name."))
    }
    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: storeModel)
    let store = try coordinator.addPersistentStore(
      ofType: NSSQLiteStoreType, configurationName: nil,
      at: storeURL,
      options: [
        NSReadOnlyPersistentStoreOption: true,
        NSSQLitePragmasOption: ["journal_mode": "DELETE"],
      ])
    var removed = false
    defer { if !removed { try? coordinator.remove(store) } }
    let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
    context.persistentStoreCoordinator = coordinator
    let snapshot = try context.performAndWait { try decode(context) }
    try coordinator.remove(store)
    removed = true
    return snapshot
  }

}

extension WorkStore {

  private struct DecodedCounts {
    var paragraphs = 0
    var runs = 0
  }

  private static func decode(_ context: NSManagedObjectContext) throws -> Snapshot {
    let works = try fetch(WorkRecord.self, entity: "Work", in: context)
    guard works.count == 1, let work = works.first,
      work.formatVersion?.intValue == 1,
      let manuscriptObject = work.manuscript,
      let unitSet = work.units
    else { throw malformed() }
    let orderedUnits = try ordered(manuscriptObject.contentUnits, as: ContentUnitRecord.self)
    guard !orderedUnits.isEmpty, Set(orderedUnits) == unitSet else { throw malformed() }
    var seen: Set<String> = []
    let workID = try identifier(work.identifier, seen: &seen)
    let manuscriptID = try identifier(manuscriptObject.identifier, seen: &seen)
    var counts = DecodedCounts()
    let units = try orderedUnits.map { try decodeUnit($0, seen: &seen, counts: &counts) }
    try validateCounts(context, units: units.count, counts: counts)
    guard let manuscript = try? Manuscript(identifier: manuscriptID, units: units) else {
      throw malformed()
    }
    let membership = try work.resourceMembership.map {
      try PropertyListDecoder().decode([WorkResource].self, from: $0)
    }
    return Snapshot(identifier: workID, manuscript: manuscript, resourceMembership: membership)
  }

  private static func decodeUnit(
    _ object: ContentUnitRecord, seen: inout Set<String>, counts: inout DecodedCounts
  ) throws -> TextUnit {
    let unitID = try identifier(object.identifier, seen: &seen)
    guard let title = object.title,
      let dismissed = object.formattingWarningDismissed
    else { throw malformed() }
    let paragraphs = try ordered(object.paragraphs, as: ParagraphRecord.self).map {
      try decodeParagraph($0, seen: &seen, counts: &counts)
    }
    counts.paragraphs += paragraphs.count
    guard let unit = try? TextUnit(
      identifier: unitID, title: title, paragraphs: paragraphs,
      formattingWarningDismissed: dismissed.boolValue
    ) else { throw malformed() }
    return unit
  }

  private static func decodeParagraph(
    _ object: ParagraphRecord, seen: inout Set<String>, counts: inout DecodedCounts
  ) throws -> TextParagraph {
    let paragraphID = try identifier(object.identifier, seen: &seen)
    guard let rawAlignment = object.alignment,
      rawAlignment.doubleValue == Double(rawAlignment.uintValue),
      let alignment = ParagraphAlignment(rawValue: rawAlignment.uintValue)
    else { throw malformed() }
    let runs = try ordered(object.runs, as: RunRecord.self).map(decodeRun)
    counts.runs += runs.count
    return TextParagraph(identifier: paragraphID, runs: runs, alignment: alignment)
  }

  private static func decodeRun(_ object: RunRecord) throws -> TextRun {
    guard let string = object.text,
      string.rangeOfCharacter(from: CharacterSet(charactersIn: "\r\n\u{2029}")) == nil,
      let rawEmphasis = object.emphasis,
      rawEmphasis.doubleValue == Double(rawEmphasis.uintValue),
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

  private static func validateCounts(
    _ context: NSManagedObjectContext, units: Int, counts: DecodedCounts
  ) throws {
    let expected = [
      "Work": 1, "Manuscript": 1, "ContentUnit": units,
      "Paragraph": counts.paragraphs, "Run": counts.runs,
    ]
    for (entity, count) in expected {
      guard try context.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: entity)) == count
      else { throw malformed() }
    }
  }

  static func package(workIdentifier: FolioIdentifier, manuscript: Manuscript) throws -> FileWrapper {
    let (_, data) = try withStore(package: nil, writing: true) { context in
      try encode(workIdentifier: workIdentifier, manuscript: manuscript, in: context)
    }
    guard let data else { throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError) }
    let wrapper = FileWrapper(directoryWithFileWrappers: [
      "Work.sqlite": FileWrapper(regularFileWithContents: data)
    ])
    // A save is accepted only if this reader reconstructs the exact authored snapshot.
    let loaded = try readPackage(wrapper)
    guard loaded.identifier == workIdentifier, loaded.manuscript == manuscript else {
      throw NSError(
        domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError,
        userInfo: [
          NSLocalizedDescriptionKey: NSLocalizedString(
            "work-package.save-verification.error", tableName: nil, bundle: bundle,
            value:
              "The Work could not be saved without losing information. "
                + "The previous saved package has not been replaced.",
            comment:
              "Error when save verification fails. Reassure the user that the previous package remains intact."
          ),
        ])
    }
    return wrapper
  }

  private static func encode(
    workIdentifier: FolioIdentifier, manuscript: Manuscript,
    in context: NSManagedObjectContext
  ) throws {
    let work = try insert(WorkRecord.self, entity: "Work", in: context)
    work.identifier = workIdentifier.rawValue
    work.formatVersion = 1
    let storedManuscript = try insert(ManuscriptRecord.self, entity: "Manuscript", in: context)
    storedManuscript.identifier = manuscript.identifier.rawValue
    storedManuscript.work = work
    let storedUnits = try manuscript.units.map { text in
      try encode(text, under: work, in: context)
    }
    storedManuscript.contentUnits = NSOrderedSet(array: storedUnits)
    try context.save()
  }

  private static func encode(
    _ text: TextUnit, under work: WorkRecord, in context: NSManagedObjectContext
  ) throws -> ContentUnitRecord {
    let unit = try insert(ContentUnitRecord.self, entity: "ContentUnit", in: context)
    unit.identifier = text.identifier.rawValue
    unit.title = text.title
    unit.work = work
    unit.formattingWarningDismissed = NSNumber(value: text.formattingWarningDismissed)
    let paragraphs = try text.paragraphs.map { paragraph in
      try encode(paragraph, under: unit, in: context)
    }
    unit.paragraphs = NSOrderedSet(array: paragraphs)
    return unit
  }

  private static func encode(
    _ paragraph: TextParagraph, under unit: ContentUnitRecord, in context: NSManagedObjectContext
  ) throws -> ParagraphRecord {
    let object = try insert(ParagraphRecord.self, entity: "Paragraph", in: context)
    object.identifier = paragraph.identifier.rawValue
    object.alignment = NSNumber(value: paragraph.alignment.rawValue)
    object.unit = unit
    let runs = try paragraph.runs.map { run in
      let record = try insert(RunRecord.self, entity: "Run", in: context)
      record.text = run.string
      record.emphasis = NSNumber(value: run.emphasis.rawValue)
      record.bold = NSNumber(value: run.presentation.bold)
      record.italic = NSNumber(value: run.presentation.italic)
      record.underline = NSNumber(value: run.presentation.underline)
      record.strikethrough = NSNumber(value: run.presentation.strikethrough)
      record.paragraph = object
      return record
    }
    object.runs = NSOrderedSet(array: runs)
    return object
  }

}
