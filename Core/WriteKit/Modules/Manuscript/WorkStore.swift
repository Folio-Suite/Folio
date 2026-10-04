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

  private static func identifier(_ object: NSManagedObject, _ key: String, seen: inout Set<String>)
    throws -> FolioIdentifier {
    guard let raw = object.value(forKey: key) as? String, !seen.contains(raw),
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

  static func ordered(_ object: NSManagedObject, _ key: String) throws -> [NSManagedObject] {
    guard let values = object.value(forKey: key) as? NSOrderedSet,
      let objects = values.array as? [NSManagedObject]
    else { throw malformed() }
    return objects
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
    let works = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "Work"))
    guard works.count == 1, let work = works.first,
      (work.value(forKey: "formatVersion") as? NSNumber)?.intValue == 1,
      let manuscriptObject = work.value(forKey: "manuscript") as? NSManagedObject,
      let unitSet = work.value(forKey: "units") as? Set<NSManagedObject>
    else { throw malformed() }
    let orderedUnits = try ordered(manuscriptObject, "contentUnits")
    guard !orderedUnits.isEmpty, Set(orderedUnits) == unitSet else { throw malformed() }
    var seen: Set<String> = []
    let workID = try identifier(work, "identifier", seen: &seen)
    let manuscriptID = try identifier(manuscriptObject, "identifier", seen: &seen)
    var counts = DecodedCounts()
    let units = try orderedUnits.map { try decodeUnit($0, seen: &seen, counts: &counts) }
    try validateCounts(context, units: units.count, counts: counts)
    guard let manuscript = try? Manuscript(identifier: manuscriptID, units: units) else {
      throw malformed()
    }
    let membership = try (work.value(forKey: "resourceMembership") as? Data).map {
      try PropertyListDecoder().decode([WorkResource].self, from: $0)
    }
    return Snapshot(identifier: workID, manuscript: manuscript, resourceMembership: membership)
  }

  private static func decodeUnit(
    _ object: NSManagedObject, seen: inout Set<String>, counts: inout DecodedCounts
  ) throws -> TextUnit {
    let unitID = try identifier(object, "identifier", seen: &seen)
    guard let title = object.value(forKey: "title") as? String,
      let dismissed = object.value(forKey: "formattingWarningDismissed") as? NSNumber
    else { throw malformed() }
    let paragraphs = try ordered(object, "paragraphs").map {
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
    _ object: NSManagedObject, seen: inout Set<String>, counts: inout DecodedCounts
  ) throws -> TextParagraph {
    let paragraphID = try identifier(object, "identifier", seen: &seen)
    guard let rawAlignment = object.value(forKey: "alignment") as? NSNumber,
      rawAlignment.doubleValue == Double(rawAlignment.uintValue),
      let alignment = ParagraphAlignment(rawValue: rawAlignment.uintValue)
    else { throw malformed() }
    let runs = try ordered(object, "runs").map(decodeRun)
    counts.runs += runs.count
    return TextParagraph(identifier: paragraphID, runs: runs, alignment: alignment)
  }

  private static func decodeRun(_ object: NSManagedObject) throws -> TextRun {
    guard let string = object.value(forKey: "text") as? String,
      string.rangeOfCharacter(from: CharacterSet(charactersIn: "\r\n\u{2029}")) == nil,
      let rawEmphasis = object.value(forKey: "emphasis") as? NSNumber,
      rawEmphasis.doubleValue == Double(rawEmphasis.uintValue),
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

  static func insert(
    _ entity: String, in context: NSManagedObjectContext,
    values: [String: Any]
  ) -> NSManagedObject {
    let object = NSEntityDescription.insertNewObject(forEntityName: entity, into: context)
    object.setValuesForKeys(values)
    return object
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
    let work = insert(
      "Work", in: context, values: ["identifier": workIdentifier.rawValue, "formatVersion": 1])
    let storedManuscript = insert(
      "Manuscript", in: context,
      values: ["identifier": manuscript.identifier.rawValue, "work": work])
    let storedUnits = try manuscript.units.map { text in
      try encode(text, under: work, in: context)
    }
    storedManuscript.setValue(NSOrderedSet(array: storedUnits), forKey: "contentUnits")
    try context.save()
  }

  private static func encode(
    _ text: TextUnit, under work: NSManagedObject, in context: NSManagedObjectContext
  ) throws -> NSManagedObject {
    let unit = insert(
      "ContentUnit", in: context,
      values: [
        "identifier": text.identifier.rawValue,
        "title": text.title, "work": work,
        "formattingWarningDismissed": text.formattingWarningDismissed,
      ])
    let paragraphs = try text.paragraphs.map { paragraph in
      try encode(paragraph, under: unit, in: context)
    }
    unit.setValue(NSOrderedSet(array: paragraphs), forKey: "paragraphs")
    return unit
  }

  private static func encode(
    _ paragraph: TextParagraph, under unit: NSManagedObject, in context: NSManagedObjectContext
  ) throws -> NSManagedObject {
    let object = insert(
      "Paragraph", in: context,
      values: [
        "identifier": paragraph.identifier.rawValue,
        "alignment": paragraph.alignment.rawValue, "unit": unit,
      ])
    let runs = paragraph.runs.map { run in
      insert(
        "Run", in: context,
        values: [
          "text": run.string,
          "emphasis": run.emphasis.rawValue, "bold": run.presentation.bold,
          "italic": run.presentation.italic, "underline": run.presentation.underline,
          "strikethrough": run.presentation.strikethrough, "paragraph": object,
        ])
    }
    object.setValue(NSOrderedSet(array: runs), forKey: "runs")
    return object
  }

}
