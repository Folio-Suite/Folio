<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Swift migration and Suite roadmap

**Status: bounded scaffold approval, 2026-09-27.** U0 (import UndoKit source and design provenance) and T0 (scaffold an independent Swift TypographyKit framework) are approved. This does not approve the full Swift migration, production behavior, or the remaining roadmap. The canonical migration specification is [Plan the Swift migration and TypographyKit foundation](https://github.com/Folio-Suite/Folio/issues/29), with 53 user stories and confirmed test seams. [Chart Folio's foundational architecture](https://github.com/Folio-Suite/Folio/issues/2) remains the decision index.

## Recommended route

The approved work is limited to U0 and T0: import UndoKit with its design provenance and scaffold TypographyKit as an independent Swift framework. The existing Folio production Suite remains Objective-C. A full Swift migration and usable compositor require separate approval and implementation. Preserve the working editor and supported packages in any later migration. Resolve UndoKit's remaining design before implementing durable history.

The migration is finite: it does not include a complete catalog, shared-host implementation, archive exchange, paragraph optimizer, or publishing engine. Those capabilities have explicit places after it. Prototype findings guide implementation; another TextKit-versus-Core Text selection experiment and the retired broad storage prototype are not prerequisites.

## Accepted constraints

- Retain Write/WriteKit, Research/ResearchKit, Composer/ComposerKit, FolioKit, AppKit storyboards, Core Data, and Core Text during the planned idiomatic Swift migration. Existing production code remains Objective-C at this scaffold stage. TypographyKit is an independent Swift framework; a working compositor remains future work.
- Fold UndoKit into Folio proper. Folio is its most urgent and demanding consumer, while other applications remain supported through a standalone public framework. Source location does not transfer Folio semantics or policies into UndoKit.
- Target macOS 14 Sonoma explicitly and retain Intel and Apple Silicon support. Use a maintained Swift toolchain; Swift 6 language mode with explicit isolation remains the specification's recommended configuration.
- Kits own domain capabilities and reusable editors, review, and history presentation. Applications host complete professional workspaces. Embedded editing identifies its actual Document, and deliberate handoff reveals the same Document and object.
- Native Documents retain independent authority, history, and Undo. Efficient Core Data working storage, shared on-demand domain hosts, compatibility prompts, verified upgrades, and restoration safeguards follow the [lifecycle contract](../architecture/document-lifecycle-contract.md).
- Retain per-app archives alongside Project `.folio`. Portable document semantics and history use extensively documented XML. Import creates independent native Documents; it does not silently reconnect them. A possible Folio Project utility and the treatment of small helper apps remain future design work. `.foliobundle` remains deferred.
- Offer a default user-wide Library; keep Work-local records sufficient for references. Richer reusable research belongs in a Library. Optional paired bibliographic sync preserves independent records, conflict resolution, and document-local Undo. Undo/Redo affecting shared fields pauses the pair without cascading or immediate reapplication.

## Small utilities and full Suite applications

The maintainer's current direction is that a possible Folio Project app would be
a small utility providing focused operations. Write, Research, and Composer
remain the full professional workspaces. FolioKit could be distributed alongside
this utility and other small helper apps; their exact placement is still open.

Before implementing such a utility, resolve:

- **Scope and discovery:** which operations deserve a utility, how users launch
  it, and when a task should hand off to a professional workspace.
- **Packaging:** whether helpers install beside a framework or in another shared
  location, how they are registered, and how optional installation works.
- **Lifecycle and ownership:** which component launches and manages a helper,
  what happens when it quits, and which existing domain host owns each Document
  it accesses. A utility interface does not by itself grant document authority.
- **Distribution:** signing, permissions, version compatibility, updates, and
  removal, including whether standalone framework consumers receive any helpers.

This is a design question for the roadmap. No utility target, persistent Project
store, or change to the accepted domain-host architecture is introduced here.

## Framework and internal module allocation

| Public framework | Responsibility | Internal organization to begin with |
| --- | --- | --- |
| FolioKit | Shared semantic values and identity, immutable snapshots, implemented package utilities | Identity/values, staging, and exchange support as it becomes real |
| WriteKit | Work and Manuscript behavior, private persistence, reusable editor and native Undo integration | Work state, persistence adapter, semantic editing, AppKit presentation |
| ResearchKit | Source Libraries, record behavior and research presentation | Preserve the shell during migration; add catalog, reconciliation, capture, and presentation modules with their workflows |
| ComposerKit | Arrangements/ Editions, Publication Plans, production definitions, page/Stream orchestration, domain diagnostics | Publication inputs, TypographyKit adaptation, orchestration, eventual Rendition adapters |
| TypographyKit | Neutral text shaping, measurement, break realization and eventual optimization, source mappings, typographic geometry | Mapping, font resolution/shaping, discretionaries, paragraph search, geometry/drawing; math and specialized language support later |
| UndoKit | Durable history structure, ordering, branches/checkpoints as selected capabilities, native Undo integration, and history-storage safeguards | Core Data history storage, acceptance/recovery coordination, history operations, and platform-specific native adapters; no Folio model dependency |

These are source and responsibility divisions, not one target per row or submodule. Extract a private library when actual reuse, a dependency seam, or measured build/testing benefit justifies it. Keep public interfaces small and test through them.

TypographyKit depends on Foundation, Core Text, and Core Graphics, without FolioKit or domain-Kit dependencies. ComposerKit adapts Folio meaning to its inputs. Document ownership stays with the document-domain Kit even when another Kit supplies an editor. Cross-domain presentation integration must preserve this separation without circular framework dependencies; choose the concrete adapter where the first real workflow needs it.

## UndoKit incorporation and design track

The maintainer's additional direction is to develop UndoKit within Folio, with Folio driving the demanding first integration and other applications remaining supported. Preserve the [existing UndoKit design map](https://github.com/ctwelve/UndoKit/issues/1), accepted vocabulary, research, issue relationships, and original license/attribution when incorporating its sources. Do not restart the design from an empty framework or silently retire its unresolved decisions. The separate repository has not been moved or changed by this plan.

The source and design snapshot is imported under [UndoKit](../../UndoKit/UPSTREAM.md), with the dated issue bodies, resolution comments, statuses, and dependency graph in its [design inventory](../../UndoKit/docs/imported-design/README.md). The original `ctwelve/UndoKit` repository and history remain untouched. The local framework is still a scaffold. Its standalone build and public-module import/link checks establish build independence; history behavior remains unimplemented. The next open decision is [Define durable acceptance, compensation, and interruption recovery](https://github.com/ctwelve/UndoKit/issues/6). It is currently open and unblocked because #3 and #5 are closed. Its design must settle recovery across host acceptance and the separate history store, whole-group compensation, duplicate-free retry, and storage refusal before the dependent contracts and proofs can establish production behavior.

UndoKit owns history capabilities and storage safeguards. Folio's domain Kits retain semantic meaning, no-op filtering, validation, compensation, authoritative accepted outcomes, dependency completeness, and recording/retention policy. One Folio Document maps to one host-defined History Scope. Other consumers may choose different scopes and bounded policies; they do not inherit Folio's document model or navigation behavior. No universal framework `Revision` replaces host vocabulary.

Preserve the existing requirements for idiomatic typed Swift use, independently usable Objective-C interfaces, and external XCFramework consumption. The Objective-C interface is deliberate external support, not a temporary Folio migration bridge. Keep UndoKit independent of FolioKit, the domain Kits, and TypographyKit, with native platform adapters isolated from the shared core. Shared generic history-browser UI remains deferred; Folio's domain Kits own the agreed reusable history presentation and may later share suitable components.

The source snapshot, standalone project scaffold, original MIT attribution, and design provenance are imported. The current scaffold can be imported and linked from isolated Swift and Objective-C consumers. Typed history operations, external XCFramework consumption, and a meaningful bounded non-Folio host remain requirements for implementation. External XCFramework release and version policy, artifact/export entry points, and any tracker consolidation remain future decisions; Folio's coordinated Suite-version policy alone does not settle external distribution.

UndoKit design can advance alongside the Swift migration. Its production acceptance/recovery implementation gates Folio's durable history, shared-host recovery, archival history reconstruction, and non-cascading Source sync. Preserve existing native Undo during the migration rather than prematurely routing it through an unfinished history engine.

## Approved scaffold slices and proposed migration work

U0 and T0 are the only approved implementation slices. Their approval covers project/source scaffolding and import provenance, not consumer behavior. Other codes below identify proposed work, not published implementation tickets. Each future slice includes its affected resource bindings, tests, DocC, localization, and tooling changes. Shared project/configuration files have one integration owner. Temporary interoperability may keep callers working; it must delegate to one implementation rather than establish a second mutable model.

| Slice | Depends on | Reviewable result and acceptance evidence |
| --- | --- | --- |
| **M0 — Capture the working baseline** | Plan acceptance | Reconcile branch/base and preserve existing typography evidence and documentation changes. Inventory production code, resources, tests, and justified exceptions. Capture actual old-writer Write/Research packages and current native behavior. Record available Sonoma/architecture verification environments. The already agreed public test seams remain. |
| **U0 — Import UndoKit source and design** | Approved bounded slice | Preserve the upstream source snapshot, MIT attribution, standalone project scaffold, design/research docs, original issue map, and dated issue/dependency inventory in Folio. Verify standalone builds and isolated Swift/Objective-C imports at the implemented scope. Durable history and a finished operation API remain future work. Keep the upstream repository untouched. |
| **T0 — Scaffold TypographyKit** | Approved bounded slice | Create an independent Swift framework target and public module/documentation scaffold. No composition, shaping, layout, or typography behavior is complete or claimed. |
| **M1 — Publish Swift FolioKit through working consumers** | M0 | Swift identity/value and staging behavior with preserved identifiers and cleanup semantics. Adapt isolated public-consumer checks for Swift while existing consumers remain functional through narrowly scoped transitional adapters. Check actual current callers and package behavior. |
| **M2 — Reopen and save Works through Swift model/persistence** | M1 | Swift Work state and private Core Data adapter drive the existing editor through a temporary adapter if needed. Old packages reopen and save with meaning, identity, order, and failure preservation intact. Keep current snapshot/schema policy for this baseline slice. |
| **M3 — Complete the Swift Write experience** | M2 | Swift reusable editor, native document/application hosting, and Write service scaffold. Preserve formatting, warnings, paste identity, Manuscript operations, chronological Undo, keyboard/accessibility behavior, menus, and reopening. Remove the Write transition adapter after all callers move. |
| **M4 — Preserve Research in Swift** | M1 | Swift ResearchKit, native shell, resources, and service scaffold reopen existing Library packages and preserve collected files through saves and failed opens. No catalog or synchronization feature is implied. |
| **M5 — Preserve Composer's current shell in Swift** | M1 | Swift ComposerKit shell, application/resources, and service scaffold retain current supported behavior and truthful document registrations. Unimplemented Arrangement persistence remains unadvertised. |
| **T1 — Realize controlled text through TypographyKit** | T0, M0 | A documented public composition operation accepts owned immutable inputs and caller-supplied break decisions, realizes supported shaping and geometry, and returns complete source mappings, selected fonts, and diagnostics. Verify the existing primitive-control cases through that interface; report unsupported/infeasible requests explicitly. |
| **C1 — Connect ComposerKit to TypographyKit** | M5, T1 | One small domain-to-typography adaptation exercised through ComposerKit's public interface, with an external TypographyKit consumer proving independence. Preserve diagnostics and source identity; do not invent a mature Composer UI or Arrangement store for this integration. |
| **I1 — Finish the coordinated Swift Suite** | M3, M4, C1, U0 | Remove obsolete production implementations and temporary bridges. Integrate framework products, signing, resources, localization, DocC, schemes, public/negative interface checks, Ruby tooling, and packaging. Keep UndoKit's external build/consumer path intact. Record every retained production interoperability exception. |
| **A1 — Verify migration acceptance** | I1 | Review against standards and all migration user stories. Run integrated signed native checks, public consumer checks, tooling and DocC checks, representative Sonoma workflows, and relevant installed-framework checks. Record architecture coverage and any missing runtime evidence precisely. |

U0 and T0 form the bounded scaffold batch. T1 supplies the first real compositor operation in the proposed migration. After M1, Write, Research, and Composer can progress separately where ownership is clear. UndoKit's remaining design proceeds independently of source import. C1 waits for T1 and its real inputs. Integration keeps the Suite coherent, and each slice carries its own focused checks; A1 establishes the combined result rather than postponing all verification until the end.

The Write model/editor split is a proposed work boundary. If a narrow temporary adapter cannot preserve native behavior cleanly, combine M2 and M3 in the integration checkout and report green status only for the combined result. Do not grow a permanent compatibility architecture to keep those two rows separate.

## Scaffold verification — 2026-09-27

U0 and T0 are implemented locally. The Folio scheme builds both independent
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

## Follow-on implementation route

These are bounded work areas to turn into specific vertical slices as their immediate inputs exist. They are not an authorization to implement the entire roadmap or a promise that every row fits one ticket.

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

1. **Architecture versus execution:** lifecycle and professional workflow agreements are accepted. Only U0 and T0 scaffolding are approved. The full migration, temporary adapter strategy, and T1/C1 behavior remain proposed and require separate approval.
2. **Existing behavior:** use the agreed public Kit interfaces and native document/UI flows. Preserve old-writer fixtures, semantic/presentation distinctions, stable identifiers, and the intentionally different current Write/Research package policies. Do not test private implementation shape.
3. **Native integration:** use signed Xcode application/UI testing for resources, menus, focus, Undo, saving, and accessibility. Verify affected installed products and supported runtime environments when claiming those behaviors. A deployment setting or unsigned build is insufficient evidence.
4. **Typography:** assert source coverage, legal boundaries, mappings, constraints, and geometry through TypographyKit's public interface, with independently derived expectations. Keep visual quality and native interaction as explicit human review during implementation.
5. **Delivery:** review and validate the integrated Suite before proposing a merge. Do not claim Sonoma or Intel runtime proof from another environment, and do not turn missing evidence into an implied pass.

Scaffolding U0 or T0 does not complete the migration or establish framework behavior. The full migration is complete only when its production inventory is Swift or a documented interoperability exception, existing behavior and supported package compatibility pass, the TypographyKit foundation is usable, public interfaces and DocC are verified, and native/platform evidence meets an approved scope. A historical Objective-C experiment may remain as reproducible evidence; it is not unfinished production migration.

## Remaining design at the relevant slice

Specify concrete operation signatures, Source and Arrangement schemas, UndoKit's history storage and Folio integration, host packaging/protocols, compatibility matrices, XML encodings, optimizer cost functions, language data, and mathematical representation when those slices are scoped. UndoKit's existing decision map records its unresolved questions and dependencies. The accepted contracts constrain those choices. None requires reopening the three apps, Core Data, Core Text, document-local history, or the selected archive lifecycle.

After separate plan acceptance, publish the agreed migration slices with native dependencies and bounded acceptance criteria. Keep later work as the roadmap until its immediate scope is clear. The existing [native paragraph probe](https://github.com/Folio-Suite/Folio/issues/22) remains open for evidence reconciliation; it is not a new engine-choice gate. Do not close it or the migration specification merely because this plan exists.
