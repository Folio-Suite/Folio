<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Current library layout

`Core/Core.xcodeproj` owns four separate framework targets: FolioKit, WriteKit, ResearchKit, and ComposerKit. Their source folders are `Core/FolioKit`, `Core/WriteKit`, `Core/ResearchKit`, and `Core/ComposerKit`; corresponding unit tests live in `Core/FolioKitTests`, `Core/WriteKitTests`, `Core/ResearchKitTests`, and `Core/ComposerKitTests`. The frameworks remain distinct public modules with separate domain responsibilities even though one project builds them.

The Write, Research, and Composer projects retain their applications, services, and app/UI tests. Each app links all four Core frameworks. This makes common capabilities available across the Suite while keeping application workflows above the Kits. Write owns Work behavior, Research owns Source Library behavior, Composer owns Arrangement behavior, and FolioKit supplies shared foundations. The first implementation wave builds common capabilities across the apps; deeper professional tools follow later. This organization does not change semantic ownership.

| Public framework | Current responsibility and implementation state |
| --- | --- |
| FolioKit | Shared identity, immutable text foundations, and package utilities |
| WriteKit | Work model, private Core Data package adapter, and reusable editor behavior |
| ResearchKit | Source Library package support for the Research shell |
| ComposerKit | Bounded publication preview adapter and AppKit canvas; Arrangement/Edition persistence remains unimplemented |
| UndoKit | Independent imported framework scaffold with design/research provenance; durable history behavior is not implemented |
| TypographyKit | Independent Swift Core Text realization of supplied Latin LTR breaks, with geometry, mappings and diagnostics |

The four Core Kits share an Xcode project, not a public module or domain model. Each framework keeps its deliberate public interface. Implementation declarations remain owned by their framework, and callers use public interfaces. Internal implementation groupings can be extracted into separate libraries only when actual reuse or a measured build/testing benefit supports that boundary.

Write's application owns NSDocument and its windows. Research also uses NSDocument for package handling, with its empty catalog store and package validation in ResearchKit. Application identifiers use `dev.foliosuite`; document-type identifiers use `app.foliosuite`. Write and Research native formats are directory packages. Composer's `.flcpbundle` and `.flcp` types remain reserved; Arrangement/Edition package persistence is not implemented. See [document file types](../document-file-types.md). The approved [document lifecycle](document-lifecycle-contract.md) retains native bundle boundaries and per-app archives while adding a shared Project `.folio`, efficient Core Data working storage, and shared on-demand domain hosts. Those changes are not implemented by current registrations, snapshot adapters, or embedded service scaffolds. Framework linking and building do not establish installed runtime resolution. Issue #14 was accepted at pre-alpha scope on 2026-09-26; its broader lifecycle, failure-preservation, and semantic-specialization requirements were retired from that milestone, not verified.

The production apps and Kits now use Swift under [ADR 0015](../adr/0015-swift-suite-and-independent-frameworks.md). The Core project structure is recorded in [ADR 0016](../adr/0016-core-framework-project.md). TypographyKit provides bounded Latin LTR composition and ComposerKit hosts a controlled preview; the [acceptance record](../verification/swift-migration-acceptance.md) tracks current verification and remaining human/platform evidence. UndoKit and TypographyKit remain standalone independent frameworks. See UndoKit's [upstream provenance](../../UndoKit/UPSTREAM.md) and [dated design inventory](../../UndoKit/docs/imported-design/README.md). UndoKit remains a scaffold without durable history behavior. Persistence remains an internal framework responsibility.

Use Xcode's shared Core scheme for framework tests and the shared app schemes to run each application and its app/UI tests. The current editor/document tests exercise retained behavior; broader cross-app Work Session and archival behavior remain future work. Build the Folio scheme for coordinated Suite integration. `scripts/check-build.sh` checks the Suite build and published Kit interfaces; successful builds do not establish installed runtime behavior or the unimplemented capabilities described above. See [ADR 0009](../adr/0009-continue-cocoa-suite-with-domain-kits.md) for preference ownership, host configuration, and coordinated-version policy.

## Bundled service scaffolding

Write, Research, and Composer each embed their own NSXPC service target. Each
contains a listener, a transport diagnostic ping, and an adapter reserved for
operations through the owning Kit's public interface. No service currently exposes
a domain operation or has an application client.

The completed WriteKit connection experiment demonstrated a per-app request/reply
path. Its diagnostic API, Research menu action, and duplicate Write helper in
Research have been removed. These service shells do not connect the applications
to a shared Work Session. Shared hosting follows a real cross-application editing
workflow in the [proposed migration and Suite roadmap](../plans/swift-migration-and-suite-roadmap.md).
The [professional workflow contract](professional-workflow-contract.md) supplies
embedded editing, capture, and handoff requirements; these are not implemented by
the service scaffolds. Installation and runtime resolution remain separate proof.
