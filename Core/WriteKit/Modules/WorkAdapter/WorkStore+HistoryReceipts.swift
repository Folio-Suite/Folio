// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import CoreData
import FolioKit
import Foundation

extension WorkStore {
  /// Remove obsolete command evidence from a closed staged or reset host store.
  static func stripHistoryReceipts(at storeURL: URL) throws {
    let storeModel = try model()
    let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
      ofType: NSSQLiteStoreType, at: storeURL)
    guard storeModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) else {
      throw writeError()
    }
    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: storeModel)
    let store = try coordinator.addPersistentStore(
      ofType: NSSQLiteStoreType, configurationName: nil,
      at: storeURL, options: [NSSQLitePragmasOption: ["journal_mode": "DELETE"]])
    var removed = false
    defer { if !removed { try? coordinator.remove(store) } }
    let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
    context.persistentStoreCoordinator = coordinator
    try context.performAndWait {
      do {
        for receipt in try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "HistoryReceipt")) {
          context.delete(receipt)
        }
        if context.hasChanges { try context.save() }
      } catch {
        context.rollback()
        throw error
      }
    }
    try coordinator.remove(store)
    removed = true
  }

  /// Host-owned evidence of one authoritative Command outcome.
  struct HistoryReceipt: Sendable {
    let commandID: UUID
    let fingerprint: String
    let accepted: Bool
    let evidence: Data
  }

  /// Save the authored state and its outcome receipt in one SQLite transaction.
  /// The caller owns the private, closed working store and serializes access to it.
  static func commitHistory(
    at storeURL: URL, workIdentifier: FolioIdentifier,
    manuscript: Manuscript, receipt: HistoryReceipt
  ) throws {
    try checkIdentifiers(workIdentifier: workIdentifier, manuscript: manuscript)
    let storeModel = try model()
    let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
      ofType: NSSQLiteStoreType, at: storeURL)
    guard storeModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) else {
      throw writeError()
    }
    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: storeModel)
    let store = try coordinator.addPersistentStore(
      ofType: NSSQLiteStoreType, configurationName: nil,
      at: storeURL, options: [NSSQLitePragmasOption: ["journal_mode": "DELETE"]])
    var removed = false
    defer { if !removed { try? coordinator.remove(store) } }
    let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
    context.persistentStoreCoordinator = coordinator
    try context.performAndWait {
      do {
        let existing = NSFetchRequest<NSManagedObject>(entityName: "HistoryReceipt")
        existing.predicate = NSPredicate(format: "commandID == %@", receipt.commandID.uuidString)
        existing.fetchLimit = 1
        guard try context.fetch(existing).isEmpty else { throw writeError() }

        let works = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "Work"))
        guard works.count == 1, let work = works.first,
          work.value(forKey: "identifier") as? String == workIdentifier.rawValue
        else {
          throw writeError()
        }
        _ = try update(context, workIdentifier: workIdentifier, manuscript: manuscript)
        _ = insert(
          "HistoryReceipt", in: context,
          values: [
            "commandID": receipt.commandID.uuidString,
            "fingerprint": receipt.fingerprint,
            "accepted": receipt.accepted,
            "evidence": receipt.evidence,
            "work": work,
          ])
        try context.save()
      } catch {
        context.rollback()
        throw error
      }
    }
    try coordinator.remove(store)
    removed = true
  }

  /// A missing receipt is unresolved to the host; it never proves rejection.
  static func historyReceipt(at storeURL: URL, commandID: UUID) throws -> HistoryReceipt? {
    let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
      ofType: NSSQLiteStoreType, at: storeURL)
    let storeModel = try model()
    guard storeModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) else {
      throw malformed()
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
    let receipt: HistoryReceipt? = try context.performAndWait {
      let works = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "Work"))
      guard works.count == 1, let work = works.first,
        work.value(forKey: "identifier") is String
      else { throw malformed() }
      let request = NSFetchRequest<NSManagedObject>(entityName: "HistoryReceipt")
      request.predicate = NSPredicate(format: "commandID == %@", commandID.uuidString)
      request.fetchLimit = 2
      let matches = try context.fetch(request)
      guard matches.count <= 1 else { throw malformed() }
      guard let object = matches.first else { return nil }
      guard let rawID = object.value(forKey: "commandID") as? String,
        let storedID = UUID(uuidString: rawID), storedID == commandID,
        let fingerprint = object.value(forKey: "fingerprint") as? String,
        let accepted = object.value(forKey: "accepted") as? NSNumber,
        let evidence = object.value(forKey: "evidence") as? Data,
        object.value(forKey: "work") as? NSManagedObject == work
      else { throw malformed() }
      return HistoryReceipt(
        commandID: storedID, fingerprint: fingerprint,
        accepted: accepted.boolValue, evidence: evidence)
    }
    try coordinator.remove(store)
    removed = true
    return receipt
  }
}
