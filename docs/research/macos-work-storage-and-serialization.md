# macOS Work storage and serialization for Folio

## Question

What current macOS facilities and format constraints should inform a later decision about Folio's live Work storage, portable serialization, autosave, recovery, indexing, cloud-file-provider behavior, and user-controlled document locations?

This report deliberately does **not** select Folio's architecture. It separates current supported APIs, archived Apple guidance that is still technically useful, inferences that require validation, and unresolved questions that need prototypes.

## Executive findings

1. A macOS document package is an ordinary directory presented by Finder as one document. It is a first-class `NSDocument` representation and is well suited to heterogeneous content and large assets. Apple's current `NSDocument` API still reads and writes files *or file packages*; its detailed package guidance is archived, however. [NSDocument](https://developer.apple.com/documentation/appkit/nsdocument/) [Document Packages (archived)](https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFBundles/DocumentPackages/DocumentPackages.html)
2. `NSDocument` currently supports autosave in place, autosave elsewhere for crash protection, Versions participation, safe writes, and asynchronous writes. These are lifecycle hooks, not a guarantee that an arbitrary database-plus-assets layout is transactionally consistent. [NSDocument](https://developer.apple.com/documentation/appkit/nsdocument/) [`autosavesInPlace`](https://developer.apple.com/documentation/appkit/nsdocument/autosavesinplace)
3. Core Data's SQLite store is a performant incremental **private implementation format**. Apple explicitly says not to manipulate it with SQLite APIs. It can provide undo, migration, background work, conflict handling, and persistent transaction history, but Core Data persistent history is not by itself Folio's durable, semantic authoring history. [Core Data](https://developer.apple.com/documentation/coredata/) [Persistent Store Types and Behaviors (archived)](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreData/PersistentStoreFeatures.html) [Persistent history](https://developer.apple.com/documentation/coredata/persistent-history)
4. File coordination is the supported primitive for coordinating file and directory access among processes that participate in the protocol. It does not observe uncoordinated low-level writes. Therefore coordination can protect checkpoints and react to moves/conflicts, but it does not replace a single authoritative Work-session command/transaction owner. [`NSFileCoordinator`](https://developer.apple.com/documentation/foundation/nsfilecoordinator) [`NSFilePresenter`](https://developer.apple.com/documentation/foundation/nsfilepresenter)
5. ZIP is a strong portable container, not a live random-update store. A new ZIP checkpoint should be built separately and replace the old item safely. Foundation exposes same-volume replacement machinery intended to avoid data loss. [PKWARE APPNOTE](https://support.pkware.com/pkzip/appnote) [`FileManager.replaceItem`](https://developer.apple.com/documentation/foundation/filemanager/replaceitem%28at%3Awithitemat%3Abackupitemname%3Aoptions%3Aresultingitemurl%3A%29)
6. Cloud locations cannot be assumed fully local. File Provider explicitly models dataless and materialized items, and providers may evict clean materialized content. iCloud and Dropbox likewise expose online-only states. Folio must establish local availability before opening a live store and must design for delayed upload, conflicts, eviction, and offline use. [Synchronizing a File Provider extension](https://developer.apple.com/documentation/fileprovider/synchronizing-the-file-provider-extension) [iCloud download status](https://developer.apple.com/documentation/foundation/urlresourcekey/ubiquitousitemdownloadingstatuskey) [Dropbox online-only files](https://help.dropbox.com/sync/online-only-mac)
7. A package-with-live-database located directly in a cloud-synced folder has a larger consistency risk than a flat, atomically replaced checkpoint. This is an **inference** from File Provider's item-by-item materialization model, SQLite's multi-file/locking requirements, and Apple's coordination model; it needs destructive prototypes against iCloud Drive, Dropbox/File Provider, and abrupt process termination.

## Status vocabulary

- **Current:** present in current Apple Developer Documentation or current vendor documentation.
- **Archived:** Apple documentation explicitly in the archive; useful evidence, not a current product guarantee.
- **Inference:** architectural consequence derived from documented behavior, requiring validation.
- **Uncertain:** not established by available primary documentation and therefore a prototype target.

## 1. Files, packages, and flat compound archives

### macOS document packages

**Current API:** `NSDocument` describes a document as an in-memory owner that can read from and write to a file or file package. It exposes `fileWrapper(ofType:)`, safe-write methods, and synchronous and asynchronous save entry points. [NSDocument](https://developer.apple.com/documentation/appkit/nsdocument/)

**Archived design guidance:** Apple defines a package as a directory Finder presents as a single file. A package type is registered with a filename extension and package declaration; Apple does not prescribe its internal structure. `NSFileWrapper` represents regular files, directories, and symbolic links and integrates with the Cocoa document architecture. Apple's file-wrapper guide says unchanged wrappers need not be rewritten, reducing disk and iCloud activity. [Document Packages](https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFBundles/DocumentPackages/DocumentPackages.html) [Using FileWrappers as File Containers](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/FileWrappers/FileWrappers.html)

Benefits relevant to Folio:

- Natural separation of semantic data, images, fonts or other licensed assets, previews, and derived/cache content.
- Individual large assets can be read or updated without decoding one giant archive.
- Finder retains a one-document presentation when the type is registered as a package.
- Quick Look and Spotlight extensions receive a URL and can inspect selected package contents without launching the authoring application.

Costs and caveats:

- A package is a directory, so a save can affect multiple filesystem items. Folio must define when the package as a whole is a consistent checkpoint.
- Third-party tools and cloud providers may process the children separately. Apple's archived iCloud guide specifically required correct package UTI registration so iCloud treats the wrapper as a package, but this does not establish transactionality for arbitrary providers. [iCloud File Management (archived)](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/iCloud/iCloud.html)
- A package's convenient Finder illusion does not make internal paths stable intellectual identifiers.

### ZIP plus XML

**Current specification:** PKWARE publishes and versions the ZIP APPNOTE for interoperability. ZIP supplies a portable hierarchy, compression, checksums, ZIP64 capacities, and broad tooling. The format's extensibility also means Folio should publish a deliberately constrained ZIP profile rather than say only “a ZIP file.” [PKWARE APPNOTE](https://support.pkware.com/pkzip/appnote) [APPNOTE archives](https://support.pkware.com/pkzip/application-note-archives)

XML namespaces provide a standard way to qualify extension vocabularies. Namespace names identify vocabularies; they do not themselves provide validation or dereferenceable schemas. A DTD can validate a vocabulary, but DTD and namespace processing are distinct specifications, so Folio must test any “core DTD plus namespaced profile extensions” design against real namespace-aware validators. [Namespaces in XML 1.0](https://www.w3.org/TR/REC-xml-names/)

Consequences:

- ZIP/XML is appropriate for a documented, language-neutral portable serialization and conformance fixtures.
- It is poor as the thing mutated for every keystroke: central-directory bookkeeping, compression, and whole-archive failure modes favor checkpoint production.
- A checkpoint writer can create a complete new archive, validate it, fsync as appropriate, then replace the previous archive. Foundation's replacement API recommends constructing the replacement in an OS-provided replacement directory on the destination volume and promises replacement “in a manner that ensures no data loss.” [`FileManager.replaceItem`](https://developer.apple.com/documentation/foundation/filemanager/replaceitem%28at%3Awithitemat%3Abackupitemname%3Aoptions%3Aresultingitemurl%3A%29)
- ZIP/XML alone does not define referential integrity, revision identity, asset addressing, signatures, history semantics, media types, or preservation of unknown namespaces. Those belong in Folio's own normative package specification.

## 2. Core Data and SQLite as a live store

**Current:** Core Data is an object-graph and persistence framework for offline data, undo, background work, conflict resolution, and migration. Persistent history can record store transactions and expose changes since a token. [Core Data](https://developer.apple.com/documentation/coredata/) [Consuming relevant store changes](https://developer.apple.com/documentation/coredata/consuming-relevant-store-changes)

**Archived but explicit:** Apple's persistent-store guide distinguishes atomic XML/binary stores from the incremental SQLite store. SQLite supports partial loading and updates, while the Core Data XML and binary stores load the full object graph and write atomically. Apple states that every native Core Data store format is private and must not be created or modified using native SQLite APIs. [Persistent Store Types and Behaviors](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreData/PersistentStoreFeatures.html)

This means:

- Core Data/SQLite is viable as Folio's private active-session persistence layer.
- It is not a suitable normative public Work format merely because SQLite is documented; Core Data's schema and store encoding are implementation-owned.
- Persistent history transactions are storage-level inserts, updates, and deletes. Folio still needs its own semantic command/change records if durable history must say that an author “moved Chapter 4 after Chapter 7,” preserve attribution and intent, or survive a future move away from Core Data.
- A checkpoint/export must use Core Data-supported APIs and a quiescent or transactionally consistent snapshot. Copying only the apparent `.sqlite` file while a store is open is not a supported backup design.

### Large assets

Apple's archived Core Data performance guide recommends care with BLOBs and says filesystem resources plus references are generally preferable for large image and sound data; it notes SQLite is the preferable built-in store when BLOB storage is necessary. [Core Data Performance](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreData/Performance.html)

For Folio, keeping large immutable or content-addressed assets as separate package files is therefore a credible design. The database can own identities, metadata, references, and integrity hashes. Whether Core Data's external binary-data storage option is sufficiently explicit and portable for Folio's needs is **uncertain** and should be benchmarked rather than assumed.

## 3. Autosave, Versions, undo, recovery, and checkpoints

### `NSDocument`

**Current:** `NSDocument` exposes:

- `autosavesInPlace`, whose default is false and whose override declares support;
- distinct autosave-in-place and autosave-elsewhere operations;
- `autosavesDrafts`, `preservesVersions`, autosaved-content and backup URLs;
- scheduled and explicit autosave APIs;
- safe and asynchronous writing;
- the Versions browser. [NSDocument](https://developer.apple.com/documentation/appkit/nsdocument/) [`autosavesInPlace`](https://developer.apple.com/documentation/appkit/nsdocument/autosavesinplace)

`autosavingFileType` can specify a representation optimized for autosave changes rather than full contents, but Apple warns that overriding it affects crash reopening and may require corresponding initialization logic. [`autosavingFileType`](https://developer.apple.com/documentation/appkit/nsdocument/autosavingfiletype)

**Inference:** A Folio application or session owner can integrate with `NSDocument` even when its active in-memory/transactional representation differs from its portable checkpoint. However, multi-application ownership and a broker process are beyond `NSDocument`'s default single-document-object model and will require an explicit adapter and lifecycle protocol.

### Versions versus Folio history

**Current:** `NSFileVersion` exposes current, other, and unresolved-conflict versions, persistent identifiers, version replacement, and conflict resolution. `NSDocument` exposes `preservesVersions` and Versions browsing. [`NSFileVersion`](https://developer.apple.com/documentation/foundation/nsfileversion) [NSDocument](https://developer.apple.com/documentation/appkit/nsdocument/)

The platform's file versions are whole-document checkpoints and conflict artifacts. They should not be conflated with Folio's semantic, attributed command history. A sound design may use both: Folio history for intellectual provenance and undo/review; OS Versions for user-facing recovery of saved document states.

### Undo and crash recovery

Core Data advertises undo support, and `NSDocument` participates in AppKit undo and autosave, but neither automatically defines suite-wide undo across several client applications. [Core Data](https://developer.apple.com/documentation/coredata/) [NSDocument](https://developer.apple.com/documentation/appkit/nsdocument/)

**Inference:** The session authority should assign command identities and commit semantic commands transactionally before acknowledging them to clients. Conventional per-window undo can request inverse operations through that authority. Crash recovery should replay or reopen a validated live store, while checkpoint recovery should retain the last known-good user document. Exact write-ahead logging and recovery rules require a prototype.

## 4. Coordination among apps, helpers, and external writers

**Current:** `NSFileCoordinator` coordinates reads and writes among file presenters in the same or different processes. `NSFilePresenter` receives move, change, deletion, and conflict notifications on its operation queue. Critically, Apple says presenters are **not** notified about low-level writes that bypass file coordination. [`NSFileCoordinator`](https://developer.apple.com/documentation/foundation/nsfilecoordinator) [`NSFilePresenter`](https://developer.apple.com/documentation/foundation/nsfilepresenter)

Implications:

- Use coordination around reads, checkpoint replacement, moves, deletion, and external-change handling at a user-visible Work URL.
- Require all Folio applications to send semantic work traffic to the session authority rather than each opening and mutating the store.
- Treat file coordination as cooperative arbitration with other well-behaved applications/providers, not a database lock or distributed transaction manager.
- If a user or external utility changes package internals without coordination, Folio needs integrity validation and a recovery/error path.

## 5. User-controlled locations and sandboxed processes

**Current:** A sandboxed macOS app can gain read/write access to files selected through `NSOpenPanel` or `NSSavePanel`, and can persist access with security-scoped bookmarks. It must balance `startAccessingSecurityScopedResource()` with `stopAccessingSecurityScopedResource()`. Apple also documents passing bookmark data between processes and document-relative bookmarks for project files that reference supporting files. [Accessing files from the macOS App Sandbox](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)

Consequences:

- Folio can remain document-centric and let users choose locations under App Sandbox, but every participating app/helper needs a deliberate access-grant protocol.
- Bookmark data can carry access between a primary app and a launch agent or XPC service. A shared App Group can hold suite-owned state, but it does not itself grant arbitrary access to the user's Work.
- Linked external Works/assets are a direct fit for document-relative bookmarks on macOS, but portable XML must not mistake opaque platform bookmark data for the only link representation.
- The directly distributed nonsandboxed Suite may have fewer access barriers, yet Folio should still use coordinated, user-visible document URLs and avoid making hidden shadow data the only recoverable copy.

## 6. Cloud locations, iCloud Drive, Dropbox, and File Provider

### Platform behavior

**Current:** File Provider maintains local metadata-only (dataless) and content-bearing (materialized) items. It can materialize content on demand and render clean materialized items dataless to reclaim space. Pending changed items are protected from eviction. Providers maintain a working set used for offline availability and Spotlight. [Synchronizing the File Provider Extension](https://developer.apple.com/documentation/fileprovider/synchronizing-the-file-provider-extension)

iCloud URL resource keys expose whether an item is ubiquitous, its download status, upload state/errors, and unresolved conflicts; `startDownloadingUbiquitousItem(at:)` requests local materialization/synchronization. [iCloud download-status key](https://developer.apple.com/documentation/foundation/urlresourcekey/ubiquitousitemdownloadingstatuskey) [`startDownloadingUbiquitousItem`](https://developer.apple.com/documentation/foundation/filemanager/startdownloadingubiquitousitem%28at%3A%29)

Apple's current user documentation says Optimize Mac Storage can leave older documents in iCloud and that users may explicitly download and keep items locally for offline work. [Store files in iCloud Drive](https://support.apple.com/en-gb/guide/mac-help/mchle5a61431/26/mac/26) [Work with iCloud Drive files](https://support.apple.com/en-ie/guide/mac-help/-mchl1a02d711/mac)

Dropbox's current documentation says its macOS File Provider implementation supports online-only files, which may appear as zero bytes until opened, and “Make available offline.” Dropbox also documents that some compound professional library/lock-file workflows are unsupported in its File Provider folder. [Dropbox online-only files](https://help.dropbox.com/sync/online-only-mac) [Dropbox File Provider changes](https://help.dropbox.com/installs/macos-support-for-expected-changes)

### Architectural consequences and unknowns

- Folio must check that the complete Work needed for an active session is materialized before claiming offline readiness.
- A live store in a File Provider location risks observing partially materialized children or provider-driven transitions. This is a stronger concern for a package than a flat archive, because the package contains separately addressable filesystem items. **This is an inference**, not an Apple guarantee of failure.
- Directly writing an open SQLite/Core Data store in a synchronized folder is unsafe to assume. Core Data's archived guide already conditions SQLite writes on filesystem locking behavior and rejects WebDAV writes; modern provider correctness still needs vendor-by-vendor testing. [Persistent Store Types and Behaviors](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreData/PersistentStoreFeatures.html)
- A safer candidate lifecycle is to materialize/import a checkpoint into suite-controlled local working storage, transact there, and coordinate atomic checkpoints back to the user URL. That design improves isolation but introduces shadow-copy identity, external-edit detection, disk-space, data-residency, and crash-recovery questions.
- “Next to the document but hidden” is not a robust universal assumption. The containing directory may be read-only, remote, synchronized, sandbox-restricted, or cleaned independently. Application Support/App Group storage is more controllable but less visible to the user. Both need explicit recovery UX.

## 7. Spotlight and Quick Look

**Current:** A Quick Look Thumbnail Extension can provide thumbnails for custom file types throughout the system and third-party apps. [Quick Look Thumbnailing](https://developer.apple.com/documentation/quicklookthumbnailing)

For search, current Core Spotlight APIs let a signed app or extension add app-specific semantic items to a private on-device index. Apple recommends named indexes for production and supports batched, restartable indexing. [Adding app content to Spotlight](https://developer.apple.com/documentation/corespotlight/adding-your-app-s-content-to-spotlight-indexes) [`CSSearchableIndex`](https://developer.apple.com/documentation/corespotlight/cssearchableindex)

The classic filesystem Spotlight `MDImporter` API remains in current reference documentation, but it is a CFPlugIn loaded by the Spotlight server and its detailed programming guidance is old. [MDImporter](https://developer.apple.com/documentation/coreservices/file_metadata/mdimporter) [`kMDItemTextContent`](https://developer.apple.com/documentation/coreservices/kmditemtextcontent)

Implications:

- A flat checkpoint with a cheap manifest/preview near the archive entry points can make Quick Look and metadata extraction bounded.
- A package can place manifest, cover thumbnail, and excerpt in predictable child paths, but extensions must tolerate incomplete materialization and untrusted data.
- Core Spotlight is attractive for deep, Work-internal search results while Folio is installed. Classic MDImporter may still be useful for Finder-level file metadata, but compatibility, sandboxing, performance limits, and deployment should be prototyped on the minimum supported macOS.
- Indexes are derived and rebuildable; they must not become authoritative Work content.

## 8. Backups and preservation

**Current user guarantee:** Time Machine backs up user files and documents, backs up changed files in later runs, and APFS local snapshots can recover earlier file states. Apple's user documentation does not promise application-level consistency for a multi-file database package captured during writes. [Back up with Time Machine](https://support.apple.com/en-us/104984) [Time Machine local snapshots](https://support.apple.com/en-gb/guide/mac-help/mh35860/26/mac/26)

Therefore:

- A durable, self-consistent user-visible checkpoint is the clearest backup unit.
- Folio should never require a cache, Core Spotlight index, or uncheckpointed Application Support shadow store to restore the last explicitly saved Work.
- The live store may allow recovery beyond the last checkpoint, but it needs integrity checking, versioning, and an export/rebuild path.
- The portable representation should include checksums or a manifest sufficient to detect truncation, missing assets, and inconsistent revision references. This is a Folio format responsibility, not supplied by ZIP or Time Machine automatically.

## 9. Viable architecture families to compare

The following remain candidates; this report does not select among them.

### A. User-visible live package

The `.folio` item is a package containing Core Data/SQLite, separate assets, history, and metadata. `NSDocument` and the session authority operate on it in place; portable ZIP/XML is a separate export.

Strengths: directness, incremental asset access, one obvious user-owned item, possible file-wrapper integration.

Risks: cloud/provider item-by-item sync, database sidecars and lock behavior, coherent backup/checkpoint boundaries, external package mutation, multi-process access discipline.

### B. User-visible portable archive plus local live store

The `.folio` item is a flat ZIP/XML checkpoint. Opening materializes and validates it into a suite-controlled working directory/store. Autosave protects the working store; explicit or automatic checkpoint operations generate and atomically replace the archive.

Strengths: clear portable contract, flat provider/back-up unit, private live-store freedom, explicit validation boundary.

Risks: potentially expensive checkpoint generation, shadow-copy identity and cleanup, disk duplication, delayed cloud upload, conflict reconciliation if the archive changes externally, explaining autosave versus checkpoint state.

### C. User-visible package checkpoint plus local live store

The `.folio` item is a documented package (XML plus assets); live Core Data resides in controlled local storage and checkpoints into the package.

Strengths: portable content remains inspectable and incrementally replaceable; live database stays out of provider locations.

Risks: multi-item checkpoint atomicity, provider/backup consistency, package materialization, more complex generation than a flat archive.

### D. Dual native package and exchange archive modes

A live package is the native macOS document; ZIP/XML is a deliberate exchange/preservation form. Conversion is explicit and each format has distinct UTTypes and lifecycle semantics.

Strengths: optimizes native workstation behavior independently from interchange; honest distinction between operational and archival needs.

Risks: two user-visible truths, confusing Save/Export behavior, lost history or capabilities during exchange, harder cross-platform/mobile story, conformance burden for both representations.

## 10. Required prototypes before deciding

1. **Package save/recovery probe:** `NSDocument` package containing SQLite/Core Data plus multi-gigabyte immutable assets; measure incremental autosave and safe replacement under forced termination.
2. **Live-store snapshot probe:** create a supported, consistent snapshot/checkpoint while mutations continue; verify all Core Data store companions, asset hashes, and semantic history agree after recovery.
3. **Cloud matrix:** iCloud Drive and current Dropbox/File Provider, with package and flat archive candidates; test online-only open, keep-downloaded behavior, rename/move, concurrent external replacement, out-of-space, offline edits, delayed upload, and conflict copies.
4. **Versions/Time Machine probe:** confirm how package versus flat checkpoint appears in Versions and restores under the chosen minimum macOS; do not infer whole-package transactionality from Finder presentation.
5. **Multi-process coordination probe:** one session authority, two client apps, and an external coordinated replacer; test move/delete/conflict callbacks and prove uncoordinated writes are detected by integrity checks.
6. **Indexing/preview probe:** Quick Look thumbnail/preview, Core Spotlight deep items, and (if retained) MDImporter against local, dataless, corrupt, old-version, and profile-extended Works.
7. **Sandbox access probe:** pass user-selected Work and linked-resource access to XPC/helper processes using bookmarks; test stale bookmarks, moved files, revoked permissions, and App Group recovery data.
8. **Scale probe:** representative 700-page book, tens of thousands of semantic nodes/history events, thousands of citations, and large figures; benchmark open, checkpoint, clone, compact, and validate.

## Conclusion

Current macOS APIs support every necessary *primitive*—document lifecycle, packages, safe replacement, Versions, file coordination, user-selected access, on-demand cloud materialization, Quick Look, and Spotlight—but they do not compose themselves into a safe compound-document architecture.

The decision ticket following this research should explicitly choose:

- the user-visible native representation;
- the authoritative active-session representation;
- the boundary and meaning of autosave, checkpoint/save, export, and recovery;
- where the working store lives;
- how a checkpoint is made consistent and replaced;
- what is guaranteed in cloud-provider locations and while offline;
- how portable semantic history differs from Core Data history and OS Versions.

The evidence most strongly rules out two casual assumptions: that a ZIP archive should be edited live, and that a Core Data SQLite file or multi-file package can simply be placed in any synchronized folder and treated as a coherent portable document. It does **not** yet rule in one of the four candidate lifecycle families.
