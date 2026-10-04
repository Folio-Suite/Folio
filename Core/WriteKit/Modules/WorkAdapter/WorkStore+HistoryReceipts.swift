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
        for receipt in try fetch(WorkHistoryReceiptRecord.self, entity: "HistoryReceipt", in: context) {
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
    manuscript: Manuscript, resources: [WorkResource], receipt: HistoryReceipt
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
        let existing = NSFetchRequest<WorkHistoryReceiptRecord>(entityName: "HistoryReceipt")
        existing.predicate = NSPredicate(
          format: "%K == %@", #keyPath(WorkHistoryReceiptRecord.commandID),
          receipt.commandID.uuidString)
        existing.fetchLimit = 1
        guard try context.fetch(existing).isEmpty else { throw writeError() }

        let works = try fetch(WorkRecord.self, entity: "Work", in: context)
        guard works.count == 1, let work = works.first,
          work.identifier == workIdentifier.rawValue
        else {
          throw writeError()
        }
        _ = try update(context, workIdentifier: workIdentifier, manuscript: manuscript)
        work.resourceMembership = try PropertyListEncoder().encode(resources)
        let storedReceipt = try insert(
          WorkHistoryReceiptRecord.self, entity: "HistoryReceipt", in: context)
        storedReceipt.commandID = receipt.commandID.uuidString
        storedReceipt.fingerprint = receipt.fingerprint
        storedReceipt.accepted = NSNumber(value: receipt.accepted)
        storedReceipt.evidence = receipt.evidence
        storedReceipt.work = work
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
      let works = try fetch(WorkRecord.self, entity: "Work", in: context)
      guard works.count == 1, let work = works.first,
        work.identifier != nil
      else { throw malformed() }
      let request = NSFetchRequest<WorkHistoryReceiptRecord>(entityName: "HistoryReceipt")
      request.predicate = NSPredicate(
        format: "%K == %@", #keyPath(WorkHistoryReceiptRecord.commandID), commandID.uuidString)
      request.fetchLimit = 2
      let matches = try context.fetch(request)
      guard matches.count <= 1 else { throw malformed() }
      guard let object = matches.first else { return nil }
      guard let rawID = object.commandID,
        let storedID = UUID(uuidString: rawID), storedID == commandID,
        let fingerprint = object.fingerprint,
        let accepted = object.accepted,
        let evidence = object.evidence,
        object.work == work
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
