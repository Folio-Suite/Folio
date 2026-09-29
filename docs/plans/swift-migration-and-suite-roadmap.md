<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Core framework and Suite roadmap

**Status: Core framework structure accepted, 2026-09-28; Swift migration plan accepted, 2026-09-27.** The app and domain-Kit Swift ports are implemented, and TypographyKit now has a bounded controlled-composition API with a small ComposerKit preview. No production `.m` or `.mm` sources remain; Objective-C files are limited to prototypes and supporting scripts. Integrated signed verification for this implementation is pending; these source changes do not establish runtime acceptance. U0 (UndoKit source/design import) and T0 (TypographyKit scaffold) were implemented in merged PR #30. The canonical specification remains [#29](https://github.com/Folio-Suite/Folio/issues/29), including its 53 stories and confirmed test seams. [ADR 0015](../adr/0015-swift-suite-and-independent-frameworks.md) records the language and framework decision. Later capabilities and acceptance evidence remain tracked in the [backlog](accepted-backlog.md).

## Current implementation direction

The framework structure is in place: FolioKit, WriteKit, ResearchKit, and ComposerKit are separate targets in `Core/Core.xcodeproj`, with sources and unit tests under `Core/`. Application projects retain apps, services, and app/UI tests, and link all four frameworks. TypographyKit and UndoKit remain standalone independent frameworks. See [ADR 0016](../adr/0016-core-framework-project.md).

The Swift ports preserve app-specific workflows over domain-owned frameworks; deeper professional tools follow later. Domain ownership remains unchanged, and this work does not establish sandbox or App Store support.

The accepted Swift migration remains finite: it does not include a complete catalog, shared-host implementation, archive exchange, paragraph optimizer, or publishing engine. Those capabilities have separate tickets. The completed native typography evidence remains a reference; another engine-selection experiment and the retired broad storage prototype are not prerequisites.

## Accepted migration constraints

- Retain Write/WriteKit, Research/ResearchKit, Composer/ComposerKit, FolioKit, AppKit storyboards, Core Data, and Core Text through the idiomatic Swift ports. TypographyKit is an independent Swift framework with bounded controlled-composition behavior; paragraph optimization and production publishing remain future work.
- Fold UndoKit into Folio proper. Folio is its most urgent and demanding consumer, while other applications remain supported through a standalone public framework. Source location does not transfer Folio semantics or policies into UndoKit.
- Target macOS 14 Sonoma explicitly and retain Intel and Apple Silicon support. Use a maintained Swift toolchain; Swift 6 language mode with explicit isolation remains the specification's recommended configuration.
- Kits own domain capabilities and reusable editors, review, and history presentation. Applications host complete professional workspaces. Embedded editing identifies its actual Document, and deliberate handoff reveals the same Document and object.
- Native Documents retain independent authority, history, and Undo. Efficient Core Data working storage, shared on-demand domain hosts, compatibility prompts, verified upgrades, and restoration safeguards follow the [lifecycle contract](../architecture/document-lifecycle-contract.md).
- Retain per-app archives alongside Project `.folio`. Portable document semantics and history use extensively documented XML. Import creates independent native Documents; it does not silently reconnect them. A possible Folio Project utility and the treatment of small helper apps remain future design work. `.foliobundle` remains deferred.
- Offer a default user-wide Library; keep Work-local records sufficient for references. Richer reusable research belongs in a Library. Optional paired bibliographic sync preserves independent records, conflict resolution, and document-local Undo. Undo/Redo affecting shared fields pauses the pair without cascading or immediate reapplication.

## Deferred utility and external distribution work

Create a project for helper apps only if a concrete need arises. A possible Folio utility, persistent Project management, and `.foliobundle` remain deferred. Write, Research and Composer remain the professional workspaces.

External framework distribution, release artifacts and their compatibility policy will be revisited after a working Folio Suite 1.0. Swift module independence and preservation of KitchenMemory's requirements suffice for UndoKit's current architectural boundary. These deferrals do not relax ordinary Suite signing, packaging, installed-framework or runtime verification.

## Framework responsibility allocation

| Public framework | Responsibility | Internal organization to begin with |
| --- | --- | --- |
| FolioKit | Shared semantic values and identity, immutable snapshots, implemented package utilities | Identity/values, staging, and exchange support as it becomes real |
| WriteKit | Work and Manuscript behavior, private persistence, reusable editor and native Undo integration | Work state, persistence adapter, semantic editing, AppKit presentation |
| ResearchKit | Source Libraries, record behavior and research presentation | Preserve the shell during migration; add catalog, reconciliation, capture, and presentation modules with their workflows |
| ComposerKit | Arrangements/ Editions, Publication Plans, production definitions, page/Stream orchestration, domain diagnostics | Publication inputs, TypographyKit adaptation, orchestration, eventual Rendition adapters |
| TypographyKit | Neutral text shaping, measurement, break realization and eventual optimization, source mappings, typographic geometry | Mapping, font resolution/shaping, discretionaries, paragraph search, geometry/drawing; math and specialized language support later |
| UndoKit | Durable history structure, ordering, branches/checkpoints as selected capabilities, native Undo integration, and history-storage safeguards | Core Data history storage, acceptance/recovery coordination, history operations, and platform-specific native adapters; no Folio model dependency |

The first four rows correspond to separate targets in `Core/Core.xcodeproj`, each with its own source and unit-test directory. UndoKit and TypographyKit remain standalone projects. Internal modules are not required by this target split. Extract another library when actual reuse, a dependency seam, or measured build/testing benefit justifies it. Keep public interfaces small and test through them.

TypographyKit depends on Foundation, Core Text, and Core Graphics, without FolioKit or domain-Kit dependencies. ComposerKit adapts Folio meaning to its inputs. Document ownership stays with the document-domain Kit even when another Kit supplies an editor. Cross-domain presentation integration must preserve this separation without circular framework dependencies; choose the concrete adapter where the first real workflow needs it.

## UndoKit incorporation and design track

UndoKit is developed in Folio as a Swift framework serving Folio first and KitchenMemory second. Keep its generic capability/storage boundary independent of FolioKit, domain Kits and TypographyKit. Host applications own semantics, validation, no-op filtering, compensation, authoritative accepted outcomes, recovery evidence and recording/retention policy. Folio maps one Document to one host-defined History Scope; other consumers retain their own scopes and bounded policies.

The [preservation record](../../UndoKit/UPSTREAM.md) and [design inventory](../../UndoKit/docs/imported-design/README.md) retain source, complete Git history, research, issue bodies/comments/events and original native relationships. Open recovery, branching, payload, native-routing, store and acceptance work continues in the [Folio backlog](accepted-backlog.md). The original Objective-C/XCFramework requirements are preserved as historical research and explicitly deferred for external distribution; they do not block current Swift work.

The imported framework remains a scaffold. Standalone builds and isolated imports establish build independence, not a working history engine. Preserve current native Undo during migration. Production recovery implementation gates durable history, shared-host recovery, archival history reconstruction and non-cascading Source sync.

## Accepted migration slices

The Swift migration sequence remains accepted and published with native dependencies. U0/T0 are complete and have no duplicate implementation tickets. The slices below retain their accepted dependencies and acceptance evidence; each carries its affected resources, tests, DocC, localization, and tooling. Temporary interoperability delegates to one implementation; shared integration files have one owner. See the [ticket index](accepted-backlog.md) for current identifiers and human-review gates.

| Slice | Depends on | Reviewable result and acceptance evidence |
| --- | --- | --- |
| **M0 — Capture the working baseline** | Accepted plan; next work session | Reconcile branch/base and preserve existing typography evidence and documentation changes. Inventory production code, resources, tests, and justified exceptions. Capture actual old-writer Write/Research packages and current native behavior. Record available Sonoma/architecture verification environments. The already agreed public test seams remain. |
| **U0 — Import UndoKit source and design** | Completed in PR #30 | Preserve the upstream source snapshot, MIT attribution, standalone project scaffold, design/research docs, original issue map, and dated issue/dependency inventory in Folio. Verify standalone builds and isolated Swift/Objective-C imports at the implemented scope. Durable history and a finished operation API remain future work. Preserve its source, research and tracker provenance before authorized repository retirement. |
| **T0 — Scaffold TypographyKit** | Completed in PR #30 | Create an independent Swift framework target and public module/documentation scaffold. No composition, shaping, layout, or typography behavior is complete or claimed. |
| **M1 — Publish Swift FolioKit through working consumers** | M0 | Swift identity/value and staging behavior with preserved identifiers and cleanup semantics. Adapt isolated public-consumer checks for Swift while existing consumers remain functional through narrowly scoped transitional adapters. Check actual current callers and package behavior. |
| **M2 — Reopen and save Works through Swift model/persistence** | M1 | Swift Work state and private Core Data adapter drive the existing editor through a temporary adapter if needed. Old packages reopen and save with meaning, identity, order, and failure preservation intact. Keep current snapshot/schema policy for this baseline slice. |
| **M3 — Complete the Swift Write experience** | M2 | Swift reusable editor, native document/application hosting, and Write service scaffold. Preserve formatting, warnings, paste identity, Manuscript operations, chronological Undo, keyboard/accessibility behavior, menus, and reopening. Remove the Write transition adapter after all callers move. |
| **M4 — Preserve Research in Swift** | M1 | Swift ResearchKit, native shell, resources, and service scaffold reopen existing Library packages and preserve collected files through saves and failed opens. No catalog or synchronization feature is implied. |
| **M5 — Preserve Composer's current shell in Swift** | M1 | Swift ComposerKit shell, application/resources, and service scaffold retain current supported behavior and truthful document registrations. Unimplemented Arrangement persistence remains unadvertised. |
| **T1 — Realize controlled text through TypographyKit** | T0, M0 | A documented public composition operation accepts owned immutable inputs and caller-supplied break decisions, realizes supported shaping and geometry, and returns complete source mappings, selected fonts, and diagnostics. Verify the existing primitive-control cases through that interface; report unsupported/infeasible requests explicitly. |
| **C1 — Connect ComposerKit to TypographyKit** | M5, T1 | One small domain-to-typography adaptation exercised through ComposerKit's public interface, with an external TypographyKit consumer proving independence. Preserve diagnostics and source identity; do not invent a mature Composer UI or Arrangement store for this integration. |
| **I1 — Finish the coordinated Swift Suite** | M3, M4, C1, U0 | Remove obsolete production implementations and temporary bridges. Integrate framework products, signing, resources, localization, DocC, schemes, public/negative interface checks, Ruby tooling, and packaging. Keep UndoKit's independent Swift module boundary intact; external distribution is deferred. Record every retained production interoperability exception. |
| **A1 — Verify migration acceptance** | I1 | Review against standards and all migration user stories. Run integrated signed native checks, public consumer checks, tooling and DocC checks, representative Sonoma workflows, and relevant installed-framework checks. Record architecture coverage and any missing runtime evidence precisely. |

The implementation snapshot above covers the source ports and bounded preview only. I1/A1 verification remains pending; the migration is not accepted until its integrated signed checks and remaining review gates pass.

U0 and T0 are the completed scaffold batch. The bounded T1 API and C1 preview are now implemented; full paragraph optimization and publication workflows remain later work. Write, Research, and Composer ports are implemented, while UndoKit's remaining design proceeds independently of source import. I1 integrates the Suite checks, and A1 records the combined acceptance result.

The Write model/editor split is the accepted starting boundary. If a narrow temporary adapter cannot preserve native behavior cleanly, combine M2 and M3 in the integration checkout and report green status only for the combined result. Do not grow a permanent compatibility architecture to keep those two rows separate.

## Scaffold verification — 2026-09-27

U0 and T0 are integrated through merged PR #30. The Folio scheme builds both independent
frameworks, and the shipping inventory includes their bundles. Their standalone
schemes use optional Suite configuration with independent version defaults.

- The universal Suite build and release-identity checks passed. The signed build
  also passed team-signature, Hardened Runtime, and library-validation checks.
- Each framework built in Release and generated DocC from a copied source
  directory outside Folio, without the Suite configuration or other Kits.
- Isolated consumers imported and linked UndoKit from Objective-C and Swift and
  TypographyKit from Swift; Swift checks covered arm64 and x86_64.
- The native Folio test plan passed on macOS 27 / Apple Silicon: 42 tests,
  105 executions including parameterized cases, with no failures or skips.
  The tool request timed out, but the completed Xcode result bundle confirmed
  the pass. The Ruby tooling suite passed 17 tests and 98 assertions.
- Standards review corrections are applied; specification review found no scope
  mismatch. Local documentation links and whitespace checks passed.

This evidence covers framework integration and existing Suite behavior. Sonoma
and Intel runtime testing, durable history, and composition behavior remain
outside this scaffold's acceptance evidence.

## TypographyKit foundation acceptance

The foundation is more than a target that builds. A consumer supplies text, opaque source identity, font and language/script information, geometry, constraints, and break/discretionary decisions. It receives measured line/run geometry, actual font resolution, source relationships, diagnostics, and an explicit completion/constraint status.

The supported subset must exercise controlled breaking, tracking/spacing and supported expansion/protrusion, source coverage, and discretionary mappings. Distinguish logical text, UTF-16 indices, shaping/grapheme boundaries, visual order, and glyph geometry. Preserve authored text and normalization. Reject invalid boundaries and unsatisfied required constraints explicitly. Core Text availability alone does not prove language coverage or correctness.

The foundation may realize supplied decisions before selecting whole-paragraph breaks itself. Its interface must permit reconsideration under new Composer constraints. Paragraph optimization, language opportunity generation, OpenType MATH layout, coordinated Streams, and production exports have separate completion criteria. Keep existing positive TextKit 2 observations as a quality reference.

## Later implementation areas

These work areas now have bounded successor tickets. Unsettled detailed designs retain maintainer review before production implementation; the roadmap does not imply that each whole area fits one implementation ticket.

| Work area | Concrete next result | Real prerequisites |
| --- | --- | --- |
| **Efficient native storage** | Save an edited Work without rebuilding unchanged content or large assets; preserve native open/save failure behavior. Extend the mechanism to Library and Arrangement stores as they acquire real content. | Migrated public persistence behavior; explicit format/version decision for any storage change |
| **UndoKit and durable document history** | Implement the accepted UndoKit core and Folio adapter together around a Work: reopen with accepted Undo history, create a checkpoint, and restore while retaining displaced history. Expose the owning Kit's history interface. Exercise interruption and whole-group failure through public operations; retain an independent bounded-host consumer. | U0, working storage, and resolved UndoKit acceptance/recovery, branching, payload, native routing, and store-lifecycle contracts; do not infer these from the scaffold |
| **Library and Work-local research** | Offer the default Library; create and cite a Work-local bibliographic record, save fuller research to a Library, and preserve the Work's sufficient subset. Start with deliberate reconciliation. | Migrated Write/Research and a focused Source schema; richer stored material uses the lifecycle guarantees |
| **Shared domain hosts and embedded editing** | Edit the same Work from two Suite contexts, visibly target commands, hand off to its owning app, and keep working after that app quits. Repeat with actual Library and Arrangement capabilities as they exist. | Recoverable accepted operations, durable receipts/history, and at least one meaningful cross-app workflow; selected registration and installed-host integration |
| **Optional paired Source sync** | Enable one Work/Library pair, exchange shared bibliographic edits, resolve a conflict, undo without cascading, and continue with the Work's subset while the Library is unavailable. | Real records in both Documents, independent durable histories, shared authority and reliable delivery/reconciliation |
| **Saved Arrangements and Editions** | Create, save, and reopen an Arrangement from selected Work snapshots; independently elaborate it and produce a self-contained Edition. | Migrated Composer and source snapshot interfaces; explicit Arrangement schema/history integration |
| **Portable XML exchange** | Export/import one Document with documented semantics and history, then its required dependencies. Extend the same contract to each domain, and finally gather a Project into `.folio` and reconstruct it independently. | Actual domain models/history, exact dependency capture, capability/compatibility rules, and documented schemas; Project export waits for the participating domain exporters |
| **Paragraph composition and coordinated pages** | Select whole-paragraph breaks, then prove unequal parallel Streams, Notes, synchronization points, and actionable infeasibility in a narrow Composer path. | T1/C1 plus controlled fixtures; early page/Stream work uses enough paragraph control to test reconsideration and need not wait for a general designer |
| **Language and mathematical typography** | Add one licensed language-pattern corpus or one explicitly scoped mathematical case at a time, with exceptions, mappings, and diagnostics. | Typography foundation, specified input subset, provenance/license review, independent expected results; math need not wait for every language |
| **Professional workspaces and final outputs** | Expand review and definition design around real capabilities; add production preflight and verified paged output before separate reflowable/web paths. | Relevant semantic models and composition behavior; validate actual generated artifacts and accessible interactions |

The typography work can continue alongside persistence, research, and hosting. XML schema design can begin once each domain's meaning and history representation are concrete; complete Project reconstruction waits for all included domains. Browser capture builds on a functioning Research capture operation. A full template designer should not precede the narrow composition and coordinated-Stream proof.

## Verification and review gates

1. **Architecture versus execution:** the lifecycle, workflow, and Swift migration plan remain accepted. U0/T0 are complete. The Core framework structure supports the first implementation wave of common capabilities across all apps, followed by app-specific workflows and deeper professional tools. This structural decision does not change the migration ticket dependencies. Specified implementation remains distinct from design and proof gates.
2. **Existing behavior:** use the agreed public Kit interfaces and native document/UI flows. Preserve old-writer fixtures, semantic/presentation distinctions, stable identifiers, and the intentionally different current Write/Research package policies. Do not test private implementation shape.
3. **Native integration:** use signed Xcode application/UI testing for resources, menus, focus, Undo, saving, and accessibility. Verify affected installed products and supported runtime environments when claiming those behaviors. A deployment setting or unsigned build is insufficient evidence.
4. **Typography:** assert source coverage, legal boundaries, mappings, constraints, and geometry through TypographyKit's public interface, with independently derived expectations. Keep visual quality and native interaction as explicit human review during implementation.
5. **Delivery:** review and validate the integrated Suite before proposing a merge. Do not claim Sonoma or Intel runtime proof from another environment, and do not turn missing evidence into an implied pass.

U0 and T0 alone did not complete the migration. The app and Kit source ports and bounded TypographyKit/ComposerKit preview are implemented, but migration acceptance still requires existing behavior and supported package compatibility checks, public-interface and DocC verification, and native/platform evidence within the approved scope. Historical Objective-C experiments may remain as reproducible evidence; they are not production implementations.

## Remaining design at the relevant slice

Specify concrete operation signatures, Source and Arrangement schemas, UndoKit's history storage and Folio integration, host packaging/protocols, compatibility matrices, XML encodings, optimizer cost functions, language data, and mathematical representation when those slices are scoped. UndoKit's existing decision map records its unresolved questions and dependencies. The accepted contracts constrain those choices. None requires reopening the three apps, Core Data, Core Text, document-local history, or the selected archive lifecycle.

The accepted migration and remaining work are published in the [ticket handoff](accepted-backlog.md), using native GitHub parents and blockers. The native paragraph probe #22 is complete. Planning issues #29 and #2 close with links to their successor work; closure records an accepted plan, not completed product capabilities.
