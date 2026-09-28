<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Organize professional workspaces around reusable domain capabilities

Approved on 2026-09-27 through [Partition the Suite by professional workflow](https://github.com/Folio-Suite/Folio/issues/10), Q1–Q16 and final confirmation. Retain Write, Research, and Composer as complete professional workspaces for their established domains. Kits provide reusable editors, review, and history interfaces; embedded presentation serves the immediate task, with an explicit handoff to the owning application's fuller workspace. Another application must earn its place through a sustained, independently useful activity. Object complexity or a helper process alone does not justify one.

Offer a default user-wide Source Library on first start. Work-local Source Records can contain all bibliographic information needed for correct references; richer reusable research belongs in a Library. Amend [ADR 0007](0007-independent-source-records-and-reconciliation.md) to permit persistent, explicitly enabled two-way synchronization of shared bibliographic information between a particular Work-local record and Library record. Independent ownership remains: conflicts require resolution, additional Library material does not automatically enter the Work, and unlinked records retain deliberate reconciliation.

## Consequences

- The edited Document determines command and history scope, regardless of the Kit supplying the interface. Crossing to a separate Document is explicit and visible; handing off its presentation does not copy or reconcile its content.
- Write hosts Work review and semantic Profile authoring. Composer hosts Arrangement/Edition review, production design, comprehensive Theme design, Page Templates, and output workflows. Research hosts fuller research, capture, and import. Detailed design-workspace boundaries and terminology can evolve during implementation.
- Incoming synchronization changes enter the receiving Document's history. Undo/Redo affecting synchronized fields pauses that record pair for reconciliation, without a cascading reversal or immediate reapplication. This preserves [ADR 0010](0010-document-undo-and-durable-history.md).
- Removing a record or disabling synchronization preserves its counterpart. Missing fields in a partial record are not deletions. An unavailable Library leaves the Work usable with its retained subset; the complete Library record remains unavailable and synchronization waits.
- Distinct editions remain distinct Sources. Synchronization does not retarget Citations, alter Composer's pinned snapshots, or reconnect independently imported Documents.

The [professional workflow contract](../architecture/professional-workflow-contract.md) and amended [Source Library contract](../architecture/source-library-contract.md) record the behavior. This resolves workflow partitioning without implementing those capabilities. [ADR 0015](0015-swift-suite-and-independent-frameworks.md) subsequently accepts the Swift migration sequence. A Project-management application remains deferred under [ADR 0013](0013-document-lifecycle-and-project-archives.md).
