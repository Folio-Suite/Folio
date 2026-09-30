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
| WriteKit | Work model, private Core Data package adapter, reusable editor behavior, and the first host adapter for durable Manuscript history |
| ResearchKit | Source Library package support and reusable library window |
| ComposerKit | Bounded publication preview adapter, AppKit canvas, and reusable preview window; Arrangement/Edition persistence remains unimplemented |
| UndoKit | Independent Swift framework for durable history transactions, outcomes, checkpoints, and native Undo routing; Folio's first host operation is a Work Manuscript replacement |
| TypographyKit | Independent Swift Core Text realization of supplied Latin LTR breaks, with geometry, mappings and diagnostics |

The four Core Kits share an Xcode project, not a public module or domain model. Each framework keeps its deliberate public interface. Implementation declarations remain owned by their framework, and callers use public interfaces. Internal implementation groupings can be extracted into separate libraries only when actual reuse or a measured build/testing benefit supports that boundary.

## Finding interfaces and resources

Follow [ADR 0017](../adr/0017-discoverable-swift-interfaces-and-resources.md)
when navigating or extending the source tree:

- Each app starts at its root `AppDelegate.swift`, annotated with `@main`.
  Write and Research keep their document implementations in `Modules/Document/`.
- Each Kit collects its public declaration files in `Interface/`.
  Their DocC overviews map capabilities to those files and implementation folders.
- Capability implementations live beneath top-level `Modules/`. Small
  implementations may remain beside their public declarations where that keeps
  the code easier to follow.
- App resources remain at their source roots. Framework storyboards and models
  live under the owning framework's top-level `Resources/`; localization catalogs
  may also live at the framework root. UndoKit's Xcode and SwiftPM builds use the
  same `Resources/History.xcdatamodeld` model.

Resource lookup remains tied to the owning bundle. Extracting an internal library
later does not automatically create a new resource bundle or distribution boundary.

## Application integration

Write's application owns NSDocument; WriteKit owns the editor window and reusable content controllers. Research also uses NSDocument for package handling, with its library window, empty catalog store, and package validation in ResearchKit. ComposerKit owns its preview window and content. Each app retains its main-menu storyboard; Kit window factories load their storyboard from the owning framework bundle. Application identifiers use `dev.foliosuite`; document-type identifiers use `app.foliosuite`. Write and Research native formats are directory packages. Composer's `.flcpbundle` and `.flcp` types remain reserved; Arrangement/Edition package persistence is not implemented. See [document file types](../document-file-types.md). The approved [document lifecycle](document-lifecycle-contract.md) retains native bundle boundaries and per-app archives while adding a shared Project `.folio`, efficient Core Data working storage, and shared on-demand domain hosts. Write stages incremental native saves with opaque resources and a first durable Manuscript history operation; see [native Work storage](native-work-v1.md) and [the first history operation](work-history-first-operation.md). Shared domain hosting and archival exchange remain unimplemented by the current registrations and embedded service scaffolds. The Suite configuration uses shared frameworks; standalone builds embed the required frameworks in each sandboxed application. These layouts share the same Kit APIs and resources. See [build configuration guidance](../../CONTRIBUTING.md) and the [cleanup verification record](../verification/swift-cleanup.md). Issue #14 was accepted at pre-alpha scope on 2026-09-26; its broader lifecycle, failure-preservation, and semantic-specialization requirements were retired from that milestone, not verified.

The production apps and Kits now use Swift under [ADR 0015](../adr/0015-swift-suite-and-independent-frameworks.md). The Core project structure is recorded in [ADR 0016](../adr/0016-core-framework-project.md). TypographyKit provides bounded Latin LTR composition and ComposerKit hosts a controlled preview; the [acceptance record](../verification/swift-migration-acceptance.md) records passing signed native verification and maintainer acceptance, with temporary Sonoma and installation waivers and unverified Intel runtime. UndoKit and TypographyKit remain standalone independent frameworks. See UndoKit's [upstream provenance](../../UndoKit/UPSTREAM.md) and [dated design inventory](../../UndoKit/docs/imported-design/README.md). UndoKit stores application-neutral history while WriteKit keeps Work meaning and authoritative host receipts. The first operation does not establish the broader cross-application Work Session or archival history. Persistence remains an internal framework responsibility.

Use Xcode's shared Core scheme for framework tests and the shared app schemes to run each application and its app/UI tests. The earlier editor/document tests exercised retained behavior; durable history adds a separate persistence and native interaction verification boundary. Broader cross-app Work Session and archival behavior remain future work. Build the Folio scheme for coordinated Suite integration. `scripts/check-build.sh` checks the Suite build and published Kit interfaces; successful builds do not establish installed runtime behavior or the unimplemented capabilities described above. See [ADR 0009](../adr/0009-continue-cocoa-suite-with-domain-kits.md) for preference ownership, host configuration, and coordinated-version policy.

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
