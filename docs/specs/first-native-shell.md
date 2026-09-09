<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

## Problem Statement

> Repository update: the developer subsequently chose a monorepo. FolioKit, Write, and Research now share this repository while retaining their Xcode projects and module boundaries. This supersedes the submodule and separate-repository requirements below; the remaining shell requirements are unchanged.

Folio needs a maintainable native application shell that can grow into a Suite for substantial authored Works. Two small editors have demonstrated basic AppKit editing and Core Data package persistence in Objective-C and Swift, but their implementation shortcuts and experimental repository layouts are not a settled foundation.

The developer wants to retain the existing parent repository and Git submodules, put the working code into the existing domain frameworks and internal libraries, and use Objective-C and Swift where each makes the work easier to express and maintain. The first usable result must preserve the familiar macOS document experience and authored meaning while establishing module ownership that will survive later growth.

## Solution

Build the first Cocoa-first Folio shell by evolving the existing workspace and library targets. Repository rebuilding is not a prerequisite. Write provides a modest but usable native document editor: create a Work, enter text, apply basic semantic or explicit formatting, undo and redo, and save and reopen a Core Data-backed package. Research remains a runnable domain shell, without requiring a research workflow to make Write useful.

Objective-C establishes the initial application/document plumbing, AppKit integration, public Cocoa-facing interfaces, and Core Data adapter. Swift implements bounded text/model operations where its types and collection tools are useful. The language crossing is narrow and exercised by real application behavior. This is the first implementation milestone, not a commitment that every future UI or model object must use one language.

FolioKit provides shared foundations. WriteKit and ResearchKit provide their respective public domain interfaces and may include reusable UI. Internal libraries carry their assigned implementation responsibilities; the applications do not bypass the domain frameworks. The parent repository continues to coordinate the FolioKit, Write, and Research submodules, preserving their source and version ownership.

## User Stories

1. As an author, I want to launch Write independently, so that I can begin writing without starting another Folio application.
2. As an author, I want New to create a Work with an editable Content Unit placed in its Manuscript, so that a blank document has a useful initial structure.
3. As an author, I want to type and revise ordinary text, so that I can use the shell for a small piece of writing.
4. As an author, I want Unicode text, combining characters, and emoji to survive editing and reopening, so that my wording is preserved.
5. As an author, I want paragraph breaks and intentionally empty paragraphs to survive saving, so that the authored structure remains intact.
6. As an author, I want emphasis and strong emphasis to express meaning, so that a future Theme can determine their appearance.
7. As an author, I want explicit bold and italic when I intend a typographic choice, so that appearance remains available without being confused with meaning.
8. As an author, I want a concise explanation of semantic versus explicit formatting in the controls, so that I can choose deliberately.
9. As an author, I want paragraph alignment to remain separate from semantic type, so that presentation does not redefine the text's meaning.
10. As an author, I want to clear supported character formatting, so that I can revise formatting without deleting the text.
11. As an author, I want formatting at the insertion point to affect subsequent typing, so that native editing conventions remain familiar.
12. As an author, I want keyboard shortcuts and menu commands for the supported editing actions, so that I can work without relying on toolbar buttons.
13. As an author, I want typing and formatting to undo and redo coherently, so that correcting an action restores both the visible text and the state that will be saved.
14. As an author, I want copy and paste within Write to preserve supported meaning and appearance, so that reused wording retains its intent.
15. As an author, I want ordinary copy and paste to create independent content identities, so that editing a copy does not alter its source or create accidental links.
16. As an author, I want text pasted from other applications to have a predictable supported representation, so that unsupported formatting cannot silently become hidden document state.
17. As an author, I want to save a Work at a location I select, so that the document remains under my control.
18. As an author, I want the native Work to appear as one package, so that its working data is handled as a document rather than a loose collection of database files.
19. As an author, I want Open to recognize the shell's actual document type, so that reopening works through native dialogs and is not confused with another installed prototype.
20. As an author, I want Save, close, and reopen to preserve text, formatting, ordering, and identity, so that continued writing starts from the state I saved.
21. As an author, I want native Auto Save and edited-state indications to work for the supported local package, so that I understand whether changes need attention.
22. As an author, I want a failed save to preserve both my editable text and the last successful save, so that I can retry or choose another destination.
23. As an author, I want a failed open or revert to leave my existing document intact, so that an invalid file cannot replace work already in memory.
24. As an author, I want Close and Quit to respect native saving and cancellation behavior, so that I am not surprised by discarded text.
25. As an author, I want basic single-application Document Versions behavior to be verified, so that an enabled native restore command restores the visible and stored Work consistently.
26. As an author, I want separate open Works to have independent editing and undo state, so that an action in one window cannot change another Work.
27. As an author using assistive technology, I want meaningful control labels, normal keyboard focus, and an accessible text area, so that the first shell can be operated through native macOS interaction.
28. As an author, I want unfamiliar or incompatible content to produce an understandable response without destructive rewriting, so that the shell protects documents beyond its editing capabilities.
29. As a developer, I want the existing parent workspace and pinned submodules to build together, so that each domain retains its repository ownership without requiring another repository reorganization.
30. As a developer, I want each application to use its domain framework, so that UI entry points do not become alternate implementations of shared behavior.
31. As a developer, I want shared text and identity foundations to belong to FolioKit, so that Research can later reuse them without importing Write's editor.
32. As a developer, I want internal libraries to own actual implementation, so that the framework skeleton does not become an empty organizational promise.
33. As a developer, I want a small Objective-C/Swift interface around useful Swift operations, so that both languages can contribute without duplicating the entire semantic model.
34. As a developer, I want persistence ownership and queue rules expressed at the interface, so that moving code between languages does not obscure responsibility for state.
35. As a developer, I want the persistence implementation separable from the application executable, so that a later domain-owned persistence host does not require rewriting the editor's public interface.
36. As a developer, I want a semantic specialization defined outside the foundation module to survive a save/reload, so that the shared type system is demonstrably extensible.
37. As a developer, I want incompatible registrations and unsupported editing requirements to be rejected, so that extensions cannot silently change the meaning of existing content.
38. As a developer, I want external Swift packages confined to the implementation that uses them, so that package types and dependency choices do not spread through every public framework interface.
39. As a developer, I want a runnable Research shell and its framework to build beside Write, so that the initial Suite structure exercises more than one application domain.
40. As a developer, I want native tests and launches to run through Xcode in the workspace context, so that signing, resources, and document registration are included in the evidence.
41. As a developer, I want clearly stated limits and comparison notes, so that a successful small editor is not mistaken for proof of full-scale persistence, plugins, or cross-application authority.

## Implementation Decisions

### Delivery scope and existing repository structure

- This specification is for the first implementation milestone in the existing skeleton. Begin with a focused reorganization of the current editor into the library targets already present; the remaining shell behaviors can follow. No repository cleanup or skeleton rebuild is required before implementation.
- Preserve the parent repository and the FolioKit, Write, and Research Git submodules. Xcode projects, framework targets, dynamic library targets, resources, and tests retain explicit ownership in those repositories. Coordinated changes must retain compatible submodule pins.
- Use `dev.foliosuite` as the primary namespace for application, framework, document-type, and other newly defined identifiers. Preserve the established FK, FW, and FR Objective-C naming conventions for their respective domains; Swift names need not duplicate Objective-C prefixes merely for symmetry.
- Start from the existing tested Xcode/macOS baseline unless a later implementation decision deliberately changes it. Record the actual toolchain, deployment minimum, and Swift language modes used for acceptance. A compiler-language change is an intentional target decision.
- Deliver Write's small editor and Research's runnable application/framework shell. Do not infer a complete Research editor or additional applications from the existence of future domain names.

### Frameworks and internal libraries

| Module | Ownership in this milestone | Delivery expectation |
| --- | --- | --- |
| FolioKit | Public shared identity, semantic text foundations, and genuinely common document facilities | Implement only the shared interfaces needed by this shell; remain independent of application domains |
| FKModelFoundations | Shared primitive implementation: identity, text runs, paragraph structure, semantic type identity, and capability contracts | Own working implementation consumed through FolioKit |
| FKPackageSupport | Reusable package inspection and safe package I/O facilities, without Write-specific schema knowledge | Implement facilities actually shared or used through FolioKit; do not absorb domain persistence |
| FKXMLSupport | Future XML exchange support | Retain the planned module place/target if included in the existing skeleton; no XML native persistence or speculative exporter is required |
| WriteKit | Public Work authoring/document interface, reusable editor entry points, and orchestration of Write's internals | Be the application's normal entry point for authoring and persistence behavior |
| FWManuscript | Work ownership of Content Units, Manuscript placement, and domain editing/model operations | Own the implemented Write model behavior |
| FWEditor | AppKit text adaptation, semantic formatting commands, selection, and undo integration | Own the implemented editor behavior behind WriteKit |
| FWPersistence | Write-specific Core Data schema, context/store ownership, snapshot conversion, and native persistence adapter | Proposed internal module name for the separate persistence responsibility already discussed; implement behind WriteKit |
| ResearchKit | Public Source Library domain framework and future reusable Research UI | Build and be used by the Research shell; shared text foundations come from FolioKit |

- The normal source and explicitly configured dependency direction is application → its domain framework → FolioKit. Owning frameworks use their internal libraries. Internal libraries do not import their containing framework or create reciprocal dependencies; foundational declarations must be allocated so the implementation graph remains acyclic.
- An application or another domain does not reach through a framework to consume its private libraries. Reusable model and UI declarations are exposed deliberately through the owning framework, with one authoritative implementation.
- Frameworks own the public interfaces; their internal implementations use dynamic libraries and explicit Clang module builds. Publish public declarations through the owning framework and configure library re-exports and runtime paths accordingly. Keep headers beside their implementation files, with one source for each declaration. A new framework is not required merely because an implementation changes language.
- Keep storyboards/nibs and other resources with the module that owns their controllers and load them from that module's bundle. A reused framework view must not depend on the caller's main bundle for its resources.
- Swift may record a transitive framework load dependency when public interfaces expose another framework's types. Document and inspect this behavior; a source dependency tree is not a promise that the final binary has only one direct framework load command.

### Language allocation and interoperability

- Use AppKit and Core Data for the shell. SwiftUI and SwiftData are not implementation dependencies of this milestone.
- Objective-C is the initial plumbing language for the application/document lifecycle, Cocoa-facing interfaces, AppKit integration, and the Core Data adapter. Use storyboards or nibs where they make those interfaces convenient to construct; programmatic AppKit remains available for locally appropriate controls and dynamic content.
- Swift implements at least one substantive text/model operation used by the real editor, such as validation, identity reconciliation, or semantic run coalescing. Do not satisfy the mixed-language requirement with an unused demonstration method.
- Keep language crossings at narrow module interfaces. Objective-C-compatible objects, protocols, collections, and error conventions define the shared interface; Swift-only values and generic implementation details may stay behind it.
- Do not maintain two independently mutable, complete semantic models for the two languages. Immutable transfer snapshots are allowed, with a defined authoritative model and explicit conversion responsibility.
- UI work remains on the main thread/main actor. Each Core Data context has explicit queue ownership. Managed objects do not cross arbitrary queues or leak out of the persistence adapter. A language bridge does not itself synchronize, isolate, or make a value safely transferable.
- Preserve useful compile-time checking in Swift. Any checked assumption at a Cocoa callback must be backed by an explicit lifecycle/threading policy and a test; broad suppression of concurrency diagnostics is not an interoperability design.
- This initial allocation does not require every future controller, model object, or library to use the same language as its first implementation.

### Authoring model and editor

- Represent a Work that owns authored Content Units separately from its Manuscript's ordered placement of them. The first editor needs exactly one editable Content Unit and its placement; multi-unit assembly UI is deferred.
- Use common text primitives beneath domain meaning. Keep stable object identity, vocabulary-qualified type identity, and definition/version information conceptually separate from presentation and any future numbering/marking.
- Support paragraphs, Unicode text runs, semantic emphasis and strong emphasis, independent explicit bold and italic, and paragraph alignment. Do not infer semantics back from a rendered font. Empty and trailing paragraphs are part of the supported structure.
- Preserve identity for retained content, assign distinct identities to new or copied content, and define paragraph split/join behavior. Ordinary copy/paste is independent copying; linked reuse is a separate future feature.
- Preserve supported formatting in internal copy/paste. External paste initially normalizes to plain text. Unsupported rich-text import is not silently promised.
- Use the native text system, menus, shortcuts, focus, selection, and UndoManager, with a semantic adapter that keeps the Work consistent with the displayed text after an entire native undo/redo group. Custom formatting needs explicit undo behavior where native text undo does not supply it.
- Do not use NSTextView attributes as the sole canonical representation. The editor maps between supported semantic state and AppKit presentation, and persistence saves the semantic state.
- Carry the prototype's semantic specialization probe into the mixed-language implementation: a separately defined specialization with an additional capability and persisted field must reconstruct with its identity and meaning intact. Conflicting definitions are rejected. This is an interface/serialization proof, not a plugin loader.
- The basic editor must not flatten specialized or unfamiliar content it cannot safely edit. Reject opening when required capabilities are absent, or provide a clearly limited read-only state that preserves the document. Do not advertise generic partial editing without satisfying the semantic dependency contract.

### Native documents and persistence

- The native working format is a Core Data store inside a package. XML belongs to later archival import/export. Neither experiment's native format or store schema is automatically the production compatibility contract.
- NSDocument initially supplies the application lifecycle. Write's persistence implementation is isolated in FWPersistence behind WriteKit and hosted in the Write process for this milestone. A later domain-owned executable is a planned hosting change, not part of this shell.
- Provide one controlled owner of each open Work's mutable state. Multiple Works may be open independently; do not introduce competing writers to one package or a Suite-wide editing mutex.
- Expose a small WriteKit interface for creating/opening a Work, accessing supported authoring behavior, producing/consuming native persistence state, and reporting failure. Keep Core Data entities, contexts, store options, and temporary filesystem machinery private.
- Store semantic structure, ordering, identity, meaning, appearance, and the supported extension information explicitly. Pin and retain the initial model version; future incompatible schema changes require deliberate migration/version decisions.
- Saving must produce a coherent package with all required store data. Never copy a live SQLite main file while silently omitting required journal/WAL state. Keep the last successfully saved package intact when a replacement fails.
- Read and validate a candidate before replacing the active Work. Unknown store versions, invalid ordering or identity, corrupt data, and unsupported package contents produce errors without destructive rewriting.
- Exercise explicit Save, native Auto Save, close/quit cancellation, edited-state tracking, reopening, and basic single-application Document Versions restoration. Return useful errors while retaining in-memory edits after a storage failure; offer the native retry or alternate-destination path.
- Select and document one namespace-owned Work type with a collision-free development extension in the evolving shell. Test native file-type discovery with the old prototypes present or explicitly absent. Do not rely on forcing a known type in tests, or silently claim compatibility with either prototype format.
- The prototype's full text recapture and temporary database rebuild are not permanent scalability commitments. Keep any retained snapshot implementation localized and document its cost. This milestone does not require an unmeasured rewrite of the text engine or promise large-Work performance.
- A successful native save is distinct from durable acceptance of every keystroke. Do not add a Suite recoverability indicator or claim helper-owned recovery semantics on the strength of ordinary NSDocument saving alone.

### Dependencies, build, and documentation

- Swift Collections and Swift Algorithms may remain implementation dependencies where they earn their place. The validated comparison used Collections 1.6.0 and Algorithms 1.2.1, with Numerics 1.1.1 resolved transitively. Record selected versions and retain the package lockfile; public framework interfaces must not expose these packages merely for implementation convenience.
- Use explicit, inspectable build dependencies and shared workspace schemes. A clean checkout must build the shell without first building an unrelated target by hand or relying on an older framework binary.
- Continue validating native app and test launches through Xcode in the workspace context with actual signing. Keep build output in the configured workspace-local DerivedData location and generated output out of version control.
- Preserve the current development scheme's installed-environment assumption as an explicit development arrangement. Distribution packaging remains separate: the interface design must not require one physical framework copy or access to another application's bundle. Do not implement an installer, App Store packaging, or runtime extension hosting in this slice.
- Provide concise module-entry-point documentation, the actual supported native format/version, launch/test instructions, language-crossing responsibilities, and known limitations. Retain the two experiments as comparison evidence; deleting or relocating them is not required.

### Relationship to earlier decisions

- ADRs 0001, 0002, 0005, 0006, and 0007 continue to define the semantic Work, desktop posture, native-package/archival distinction, semantic extension rules, and Source ownership respectively.
- The developer explicitly reversed the proposed repository consolidation: retain the existing Git submodules and skeleton. The `dev.foliosuite` namespace remains the intended namespace for the first shell; changing repository topology is not necessary to adopt it.
- ADR 0004 and the older Work Session contract specify a Suite helper. Later discussion moved toward Work authority in Write's domain and Source Library authority in Research's domain, with separately hosted domain persistence as a future step. This shell specifies only the bounded in-process NSDocument stage. Reconcile the architecture records to identify that stage and the superseded global-helper assumption during implementation; do not silently present the old and new process arrangements as simultaneous requirements.
- The exact mature persistence-host supervision, communication, recovery, and cross-application lifecycle remain unresolved work. This specification does not close or claim completion of the broader lifecycle and durable-history tickets.
- ADR 0003's distribution decision is not replaced by this implementation milestone. Keep direct versus sandboxed packaging and commercial distribution decisions separate from framework/source organization.

## Testing Decisions

- Primary acceptance uses the public WriteKit document/authoring interface already present in the experiments. Create/open a Work, perform supported edits, undo/redo, persist, and reopen through the same interface used by the application. Assert observable semantic state and native document behavior rather than private entity layouts, method counts, or the presence of a particular language keyword.
- A small native application suite sits above that interface to test things the framework alone cannot prove: resource loading, document-type discovery, menus/shortcuts, first-responder behavior, window independence, accessible controls, native Save/Open, Auto Save and Document Versions integration. Use Xcode-managed signed test runners and a manual document smoke check where system UI is not suitably automatable.
- FolioKit's reusable primitive contracts may have focused tests at its public interface because they are independently consumed by multiple domains. Prefer this public seam to direct tests of private helper functions or package internals. Internal library behavior is otherwise exercised through its owning framework.
- Verify Unicode and combining characters, paragraph ordering, empty/trailing paragraphs, semantic versus explicit formatting, insertion-point formatting, paragraph split/join identity, and internal copy/paste identity independence. Assert semantic state and presentation agree after typing undo, formatting undo, redo, and save/reopen.
- Verify package round trips preserve supported identifiers and type information. Include corrupt/incompatible input, unknown package contents, conflicting type registration, a known specialization reconstructed across the module/language seam, and rejection/read-only behavior for editing requirements the basic editor cannot honor.
- Verify save failure preserves pending edits and the previous saved package, failed open/revert preserves the active Work, and close/quit cancellation does not discard pending work. Verify no required SQLite sidecar is omitted from the saved representation.
- Verify native type discovery rather than only constructing documents with a forced type identifier. The Swift prototype's extension collision is prior art for this acceptance condition.
- Exercise an actual Objective-C caller of the Swift-backed operation and a Swift caller of the intended Cocoa-facing model interface. Assert equivalent semantic behavior and propagated errors, without exposing implementation-only dependency types to application callers.
- Verify a clean workspace build of Write, Research, the domain frameworks, and implemented internal libraries. Check the source/target dependency graph for cycles and private-library bypasses. Inspect generated interfaces and linked products where needed to distinguish explicit dependencies from compiler-emitted transitive dependencies.
- Prior art consists of the Objective-C editor's package/editor/document tests and the Swift experiment's 17-test run, which added extension reconstruction, native typing undo synchronization, trailing-empty-paragraph alignment, and native type-detection coverage. Reuse the behavioral cases rather than treating the historical test count as an acceptance target or proof of equal language quality.
- Record any timings or document-size observations with their fixture and environment. No large-document latency or memory claim is accepted without measurement; this shell does not set an invented scale threshold.

## Out of Scope

- Consolidating or removing Git submodules, rebuilding the repository, deleting either experiment, or rewriting history.
- A complete Research Source Library workflow, citations/bibliographies, source reconciliation, Zotero integration, or additional mature Suite applications.
- Multi-Content-Unit assembly UI, Layout/composition, Editions and Renditions, publication/export, full semantic vocabularies, or complete Profile/Theme support.
- XML archival import/export, DTD/schema implementation, isolated folio reconstruction, and compatibility migration from the experimental formats.
- A general semantic command bus, durable Work history, editorial annotations/revisions, cross-application undo, or real-time collaboration.
- A separately hosted persistence executable, XPC transport, helper supervision, universal Work Session recovery, or proof of recoverable acceptance for every edit.
- Plugin discovery/loading, binary plugin compatibility, runtime method replacement, remote extension UI, and optional installed-app enhancements.
- App Store submission, installer/notarization/update tooling, DNS, product website implementation, or distribution/release claims.
- SwiftUI or SwiftData adoption, or a blanket rule assigning every future module to one language.
- Multi-gigabyte assets, File Provider/cloud-storage guarantees, mature indexing, performance optimization, or broad compatibility claims beyond the tested shell scope.

## Further Notes

- This spec synthesizes the September 2026 framework discussions and two editor experiments. The latest direction retains the existing submodules, dynamic library targets, and paired headers/implementations. First tidy the current editor into those libraries, then continue the shell implementation in place.
- Relevant open architecture work remains in [#2](https://github.com/Folio-Suite/Folio/issues/2), [#4](https://github.com/Folio-Suite/Folio/issues/4), [#8](https://github.com/Folio-Suite/Folio/issues/8), [#10](https://github.com/Folio-Suite/Folio/issues/10), and [#13](https://github.com/Folio-Suite/Folio/issues/13). This issue does not declare those broader questions resolved.
- The developer confirmed the testing interface: most acceptance tests use WriteKit's public document/authoring interface, with a small Xcode UI suite for native application integration. Internal libraries and language bridges are exercised through that interface.
- Acceptance requires the supported editor/document behaviors, a working mixed-language operation behind the intended interface, real use of the implemented internal libraries, and native Xcode validation. A successful empty launch or placeholder test suite is insufficient.
