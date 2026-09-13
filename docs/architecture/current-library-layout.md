<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Current library layout

The workspace contains FolioKit, Write, Research, and Composer as directories in one repository, each retaining its own Xcode project. The public Kits expose deliberate interfaces while keeping implementation headers private. It is the first part of [the native shell specification](https://github.com/Folio-Suite/Folio/issues/14), not completion of that larger milestone.

| Public framework | Internal module | Current implementation |
| --- | --- | --- |
| FolioKit | FKModelFoundations | Stable identity and immutable text, paragraph, and run objects |
| FolioKit | FKPackageSupport | Temporary package staging and cleanup |
| FolioKit | FKXMLSupport | Reserved for XML exchange; no native storage responsibility |
| WriteKit | FWManuscript | Work model and private Core Data package adapter |
| WriteKit | FWEditor | AppKit editing, formatting, selection, paste, and undo adaptation |
| ResearchKit | Framework implementation | Source Library package support for the Research shell |
| ComposerKit | Framework implementation | Edition framework skeleton; document hosting remains in Composer |

Each header lives next to its implementation. Xcode publishes the selected public headers through the owning framework; the source declaration is not duplicated or replaced with a forwarding header. FolioKit, WriteKit, ResearchKit, and ComposerKit are the public Clang modules. Each Kit’s own `<Kit>.modulemap`, visible alongside its umbrella header in Xcode, enumerates its supported headers; `Config/Suite.xcconfig` enables Clang modules and explicit module builds. The owning application uses the same public interface as any other host.

Implementation sources compile once, directly into their owning frameworks. `FKModelFoundations`, `FKPackageSupport`, `FKXMLSupport`, `FWManuscript`, and `FWEditor` remain named internal modules with their own source folders and responsibilities. They share the owning framework’s build target; those boundaries can support later library extraction when useful. The editor’s internal toolbar declaration and the private Core Data adapter are not published. Independent libraries remain an option when demonstrated reuse justifies them.

Write's application still owns NSDocument and its windows. Research also uses NSDocument for package handling, with its empty catalog store and package validation in ResearchKit. Application and document identifiers now use `dev.foliosuite`; Write and Research native formats are directory packages. Composer currently uses a provisional SQLite-backed NSPersistentDocument for `.fcedition`; Edition package persistence is not implemented. The application projects target an installed shared-framework arrangement; clean builds do not prove installed runtime dependency resolution. Swift-backed operations and the broader shell acceptance requirements remain subsequent work under #14. Persistence remains an internal framework responsibility.

Validate with the shared Write scheme's Test action in Xcode, which exercises public framework interfaces and the native application. Build the Folio scheme to check all three application domains together. The staging tests cover returned content, error propagation, independent nested directories, and cleanup after success, failure, or exception. The existing editor/document tests cover the behavior retained through this reorganization.

Run `scripts/check-build.sh` to build the Suite and validate the published Kit interfaces. For an existing build, run `python3 scripts/check-kit-interfaces.py <Build/Products/Debug-or-Release>`. The check compares headers against module maps, checks cross-Kit source imports, and compiles and links an isolated consumer with only framework bundles. Private header and implementation-folder module imports must fail. The fixture is not executed; native Xcode tests cover runtime behavior. See [ADR 0009](../adr/0009-continue-cocoa-suite-with-domain-kits.md) for preference ownership, host configuration, and coordinated-version policy.

## Bundled service scaffolding

Write, Research, and Composer each embed their own NSXPC service target. Each
contains a listener, an empty transport protocol, and an adapter reserved for
operations through the owning Kit's public interface. No service currently exposes
a domain operation or has an application client.

The completed WriteKit connection experiment demonstrated a per-app request/reply
path. Its diagnostic API, Research menu action, and duplicate Write helper in
Research have been removed. These service shells do not connect the applications
to a shared Work Session. Shared hosting is deferred until Research has a usable
domain workflow that requires it; installation and runtime resolution remain
separate distribution work.
