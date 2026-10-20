// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import CoreData
import FolioKit
import Foundation

extension WorkStore {
  /// Ask the store whether required scalar values are in the supported domain
  /// sets before Core Data projects them through generated scalar accessors.
  static func validateRequiredScalars(
    _ context: NSManagedObjectContext, onlyEntity: String? = nil,
    matching: NSPredicate? = nil
  ) throws {
    guard let entities = context.persistentStoreCoordinator?.managedObjectModel.entities else {
      throw malformed()
    }
    var matchedEntity = onlyEntity == nil
    for entity in entities {
      guard let name = entity.name else { throw malformed() }
      if let onlyEntity, name != onlyEntity { continue }
      matchedEntity = true
      let attributes = entity.attributesByName.values.filter {
        !$0.isOptional
          && ($0.attributeType == .booleanAttributeType
            || $0.attributeType == .integer16AttributeType)
      }
      guard !attributes.isEmpty else { continue }
      let invalid = try attributes.flatMap { attribute in
        [NSPredicate(format: "%K == nil", attribute.name),
         NSPredicate(format: "NOT (%K IN %@)", attribute.name,
                     try allowedScalarValues(attribute, entity: name)),
        ]
      }
      let invalidValue = NSCompoundPredicate(orPredicateWithSubpredicates: invalid)
      let request = NSFetchRequest<NSFetchRequestResult>(entityName: name)
      request.predicate = matching.map {
        NSCompoundPredicate(andPredicateWithSubpredicates: [$0, invalidValue])
      } ?? invalidValue
      guard try context.count(for: request) == 0 else { throw malformed() }
    }
    guard matchedEntity else { throw malformed() }
  }

  private static func allowedScalarValues(
    _ attribute: NSAttributeDescription, entity: String
  ) throws -> [NSNumber] {
    if attribute.attributeType == .booleanAttributeType { return [0, 1] }
    switch (entity, attribute.name) {
    case ("Work", "formatVersion"): return [1]
    case ("Paragraph", "alignment"):
      return [ParagraphAlignment.natural, .left, .center, .right, .justified]
        .map { NSNumber(value: $0.rawValue) }
    case ("Run", "emphasis"):
      return [TextEmphasis.none, .emphasis, .strongEmphasis, .veryStrongEmphasis]
        .map { NSNumber(value: $0.rawValue) }
    default: throw malformed()
    }
  }
}
