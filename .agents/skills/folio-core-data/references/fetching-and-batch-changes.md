<!--
SPDX-FileCopyrightText: 2026 Antoine van der Lee
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Fetching and batch changes

## Diagnose the workload

Measure a representative slow operation before changing its fetch or storage model. Inspect predicates, sort descriptors, fetched properties, relationship faults, retained objects, and main-thread work. `fetchBatchSize` controls materialization; `fetchLimit` limits results. They solve different problems. Prefetch relationships only when the measured access pattern benefits, and use a count or dictionary result when the caller does not need full objects.

Keep work on the context's queue and deliver domain values through the existing Kit interface. When clearing an import context to bound memory, account for pending changes and every reference that a reset invalidates. Profile the changed workload and verify that ordering and result membership remain correct.

Primary reference: [Core Data performance](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreData/Performance.html).

## Decide whether a batch request fits

Batch requests operate at the persistent-store level and can bypass normal managed-object validation, lifecycle callbacks, observation, and undo behavior. Check support for the specific request and store type. Preserve domain invariants and relationship rules explicitly; use ordinary object operations when their behavior is required. In particular, a batch delete does not support the Deny deletion rule.

A successful batch request does not mean registered objects in every context have been updated. Identify all affected live contexts and select a propagation path:

- For known live contexts, request the affected object IDs and merge those changes with the correct inserted/updated/deleted keys through Core Data's merge API. For deletion, use `NSBatchDeleteResultTypeObjectIDs` and `NSDeletedObjectsKey`; for updates, use `NSUpdatedObjectIDsResultType` and `NSUpdatedObjectsKey`. Follow the API's queue contract.
- For consumers that must catch up later, including an existing cross-process pipeline, persistent history may be appropriate. Verify store options, transaction filtering, per-consumer progress, and retention before depending on it. Record progress only after changes are successfully consumed.

Persistent history is an alternative propagation mechanism, not a universal prerequisite for batch operations. A normal save notification is also not proof that SQL-level changes reached every observer. Keep Core Data persistent history distinct from Folio's durable semantic history: storage transactions do not by themselves implement Work history or cross-application authority.

Primary references: [NSBatchDeleteRequest](https://developer.apple.com/documentation/coredata/nsbatchdeleterequest), [NSBatchUpdateRequest](https://developer.apple.com/documentation/coredata/nsbatchupdaterequest), [consuming store changes](https://developer.apple.com/documentation/coredata/consuming-relevant-store-changes).

## Verify both persisted and live state

Use a temporary SQLite store and a receiving context that has already loaded affected objects. Execute the request, verify the receiving context and its UI-facing results, then close/reopen and inspect the stored result. Include pending edits or relationship constraints when they are relevant to the operation. If bypassing undo or callbacks changes user-visible behavior, resolve that difference before treating the optimization as equivalent.
