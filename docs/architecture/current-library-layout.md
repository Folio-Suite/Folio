<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Current library layout

The workspace contains FolioKit, Write, Research, and Composer as directories in one repository, each retaining its own Xcode project. The public Kits expose deliberate interfaces while keeping implementation libraries private. It is the first part of [the native shell specification](https://github.com/Folio-Suite/Folio/issues/14), not completion of that larger milestone.

| Public framework | Internal dynamic library | Current implementation |
| --- | --- | --- |
| FolioKit | FKModelFoundations | Stable identity and immutable text, paragraph, and run objects |
| FolioKit | FKPackageSupport | Temporary package staging and cleanup |
| FolioKit | FKXMLSupport | Reserved for XML exchange; no native storage responsibility |
| WriteKit | FWManuscript | Work model and private Core Data package adapter |
| WriteKit | Framework implementation (no FWEditor dylib) | AppKit editing, formatting, selection, paste, and undo adaptation |
| ResearchKit | No additional implementation libraries yet | Source Library package support for the Research shell |
| ComposerKit | No additional implementation libraries yet | Edition framework skeleton; document hosting remains in Composer |

Each header lives next to its implementation. Xcode publishes the selected public headers through the owning framework; the source declaration is not duplicated or replaced with a forwarding header. FolioKit, WriteKit, ResearchKit, and ComposerKit are the public Clang modules. Each Kit’s own `<Kit>.modulemap`, visible alongside its umbrella header in Xcode, enumerates its supported headers; `Config/Suite.xcconfig` enables Clang modules and explicit module builds. The owning application uses the same public interface as any other host. Internal libraries do not import their own containing framework.

The frameworks re-export the dynamic libraries that implement their public classes. Libraries retain relocatable `@rpath` install names, and the framework's existing Embed Libraries phase places its libraries in its own Frameworks directory. WriteKit compiles the editor controllers directly and links FWManuscript for its model implementation. Both consume shared foundations through FolioKit. The `FWEditor` source folder is organizational, not a separate target. Its internal toolbar declaration is not published. Private Core Data declarations are not published as framework headers. No implementation is compiled a second time into its containing framework.

Write's application still owns NSDocument and its windows. Research also uses NSDocument for package handling, with its empty catalog store and package validation in ResearchKit. Application and document identifiers now use `dev.foliosuite`; Write and Research native formats are directory packages. Composer currently uses a provisional SQLite-backed NSPersistentDocument for `.fcedition`; Edition package persistence is not implemented. The application projects target an installed shared-framework arrangement; clean builds do not prove installed runtime dependency resolution. A separately named persistence library, Swift-backed operations, and the broader shell acceptance requirements remain subsequent work under #14.

Validate with the shared Write scheme's Test action in Xcode, which exercises public framework interfaces and the native application. Build the Folio scheme to check all three application domains together. The staging tests cover returned content, error propagation, independent nested directories, and cleanup after success, failure, or exception. The existing editor/document tests cover the behavior retained through this reorganization.

Run `scripts/check-build.sh` to build the Suite and validate the published Kit interfaces. For an existing build, run `python3 scripts/check-kit-interfaces.py <Build/Products/Debug-or-Release>`. The check compares headers against module maps, checks cross-Kit source imports, and compiles and links an isolated consumer with only framework bundles. Private header and library-module imports must fail. The fixture is not executed; native Xcode tests cover runtime behavior. See [ADR 0009](../adr/0009-continue-cocoa-suite-with-domain-kits.md) for preference ownership, host configuration, and coordinated-version policy.
