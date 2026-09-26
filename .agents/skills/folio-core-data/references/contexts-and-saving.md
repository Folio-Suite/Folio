<!--
SPDX-FileCopyrightText: 2026 Antoine van der Lee
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Contexts and saving

## Confinement and handoff

Map each context's concurrency type and parent or coordinator. Run managed-object reads, mutations, fetches, and saves on that context's queue, using `performBlock:` or a justified `performBlockAndWait:`. Dispatching onto an arbitrary background queue does not enter a private context's queue. Check synchronous calls for queue cycles before introducing waits.

Transfer values or `NSManagedObjectID` between contexts, then resolve the ID in the destination context. An ID does not make the originating managed object safe to use elsewhere. For inserted objects, distinguish a temporary ID, a permanent ID, and data actually saved to a store visible to the destination. `obtainPermanentIDsForObjects:error:` is not a substitute for persistence. Handle a missing or deleted object through the adapter's error path; `existingObjectWithID:error:` can report lookup failure instead of deferring it to a fault.

Keep any context-owned object inspection inside its queue block, including preparation of UI values. Deliver domain values through the Kit's established boundary and update AppKit on the main thread. A shared framework loaded by multiple processes does not create a shared context or authorize another writer.

Primary reference: [Apple's Core Data concurrency guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreData/Concurrency.html).

## Saving and merging are separate operations

A child context save pushes changes into its parent. Trace the remaining saves to the persistent store and, where applicable, the document's package-writing operation before claiming durability. Preserve save errors, pending user edits, and the existing retry or recovery behavior. Logging an error and reporting success loses that distinction.

Automatic merging or save notifications can make another context observe persisted changes; choose the mechanism already used by the adapter and verify which contexts/stores it covers. Merging does not itself choose the product's conflict policy, establish cross-process authority, or guarantee that the destination's unsaved edits remain meaningful.

Primary reference: [NSManagedObjectContext](https://developer.apple.com/documentation/coredata/nsmanagedobjectcontext).

## Conflict policy follows the domain

Inspect the configured policy before changing it. The default error policy reports a failed save when conflicts cannot be resolved; a uniqueness constraint does not universally require store-trump merging and does not by itself imply an application crash. Store-trump and object-trump policies make different choices about persisted and pending values. Preserve the intended result for competing edits, related objects, and duplicate identities.

If the intended winner is unspecified, describe the choices before changing their meaning. Test the chosen policy using two contexts or a duplicate-constraint scenario, checking persisted values and pending changes after failure as well as success.

Primary reference: [NSMergePolicy.error](https://developer.apple.com/documentation/coredata/nsmergepolicy/error).

## External files and failed saves

`prepareForDeletion` and `willSave` can run before a save that subsequently fails. Removing an authored attachment there can leave the store referring to a missing file. Keep external-file changes within the document/store adapter's durable operation and recovery design; merely moving deletion to a different callback is not an atomic transaction. A child context's successful save also does not prove the persistent store was written.

For a change involving attachments or package members, verify that a failed save or cancelled operation preserves the original content, and that a successful save followed by close/reopen has the intended members.

Primary reference: [NSManagedObject.willSave](https://developer.apple.com/documentation/coredata/nsmanagedobject/willsave()).
