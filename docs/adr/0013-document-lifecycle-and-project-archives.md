<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Preserve native document boundaries and archive Projects together

Approved on 2026-09-27 through [issue #4](https://github.com/Folio-Suite/Folio/issues/4), Q1–Q22 and final shared-understanding confirmation. Retain app-native Documents for individual Works, Source Libraries, and Composer Arrangements. Their domain Kits use Core Data working stores and shared, on-demand hosts for the logged-in user, so another app can continue working after the owning app's interface quits. Efficient native saving and independently documented archival exchange have different representations and lifecycles.

Retain the per-app `.flwr`, `.flrs`, and `.flcp` archives for exports scoped to a native Document and add a Suite-wide `.folio` for a Project and its related Documents. The `.folio` initial top-level structure is one default-named Project recording the included parts and their relationships. Capture consistent, identified document and dependency revisions; serialize authored content and durable history/Undo into extensively documented XML. Import reconstructs independent native Documents and resources together in an ordinary folder. Both archive scopes use documented XML, declared dependencies, history policy, validation, and import/export semantics. Archives are never edited or saved in place.

## Consequences

- The Project supplies archival scope and relationships; it does not acquire document-wide Undo or domain authority. Existing Work, Source Library, Arrangement, Edition, and Rendition meanings remain. Layout is not a new domain object.
- One export gathers the selected documents and required dependencies across domain hosts. History is included by default; explicit omission applies throughout the exported Project, preserves required current snapshots, and does not change source Documents.
- Imported collections preserve archived identities, provenance, and history while becoming independent working instances. Matching identities do not reconnect them to existing Documents automatically.
- Supported released native formats retain a migration path. Older formats prompt for upgrade, supported compatibility mode, or cancellation; import performs necessary supported upgrades implicitly. Upgrade rollback protection lasts through verified success and need not be retained permanently.
- Preserve one authoritative Folio writer per Document and coordinate native file operations. Unexpected external replacement, when detected, pauses writes and preserves pending state. Uncoordinated modification of an open package is unsupported; advisory locks do not guarantee prevention.
- A Project-management app, persistent working Project management, and `.foliobundle` are deferred. Native package schemas remain domain-specific. The existing registrations and in-process snapshot implementations remain current until explicit implementation changes land.

This amends [ADR 0004](0004-helper-owned-work-sessions.md) and [ADR 0005](0005-native-packages-and-archival-folios.md), while retaining [ADR 0010](0010-document-undo-and-durable-history.md) and [ADR 0011](0011-composer-arrangements-and-editions.md). The [document lifecycle contract](../architecture/document-lifecycle-contract.md) and [archival folio contract](../architecture/archival-folio-contract.md) carry the behavior. Exact schemas, service packaging, and implementation checks remain follow-up work. This decision neither implements those capabilities nor introduces a broad storage qualification gate.
