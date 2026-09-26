---
name: folio-core-data
description: Diagnose and change Core Data persistence in Folio domain Kits. Use for context confinement, save conflicts, model changes, migrations, fetch performance, and batch-change propagation.
---

<!--
SPDX-FileCopyrightText: 2026 Antoine van der Lee
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Folio Core Data

A scoped adaptation of AvdLee's Core Data skill for Folio's Cocoa persistence adapters. Read [CONTRIBUTING.md](../../../CONTRIBUTING.md#data-modeling) for the current model-authoring, Kit-boundary, and validation requirements; read relevant architecture records through [domain.md](../../../docs/agents/domain.md) when ownership or compatibility is involved.

## Establish the persistence path

Inspect the affected code and configuration before proposing a stack or policy change. Identify the owning Kit and store adapter, compiled model and owning bundle, store type and location, context queues and parent/coordinator relationships, existing merge policy, and the caller that makes a save durable. Obtain an error and reproduction for a diagnosis, or a representative workload for a performance change. Infer these facts from the project before asking for missing information.

Keep managed objects and context-specific IDs inside the persistence implementation. Cross-context work resolves object IDs on the receiving context; public Kit callers continue to use the established domain interface. Retain the host's existing NSDocument/NSPersistentDocument or snapshot lifecycle when changing its adapter.

## Read the relevant branch

- Queue violations, object-ID handoff, failed saves, or conflicting edits: [contexts and saving](references/contexts-and-saving.md).
- Constraints, model resources, schema compatibility, or store-opening errors: [models and migrations](references/models-and-migrations.md).
- Slow fetches, memory growth, batch operations, or stale observers: [fetching and batch changes](references/fetching-and-batch-changes.md).

Use Objective-C Cocoa APIs at the existing implementation boundary. CloudKit adoption, a Swift concurrency layer, and replacement of the document architecture are separate design work. Consult current Apple documentation or the selected SDK headers for API contracts and availability that affect the change; upstream examples are inputs to review.

## Complete the task

Explain the affected ownership/queue or store-format boundary and preserve the task's existing conflict and undo semantics. Match evidence to the claim: a context save, a durable store save, and a document package reopening are different results. Use the repository's native validation workflow for implementation changes, with focused failure/reopen or concurrency coverage where the behavior changed. Report any runtime scenario that remains unverified.

For provenance, source selection, or an upstream refresh, read [UPSTREAM.md](UPSTREAM.md).
