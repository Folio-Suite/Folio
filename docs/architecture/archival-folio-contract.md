<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Native packages and archival folios

Initially approved in the follow-up design interview, Q26–Q35, and amended on 2026-09-27 by [issue #4](https://github.com/Folio-Suite/Folio/issues/4), Q1–Q22 and final confirmation. See [ADR 0005](../adr/0005-native-packages-and-archival-folios.md), [ADR 0013](../adr/0013-document-lifecycle-and-project-archives.md), and the [document lifecycle contract](document-lifecycle-contract.md). These are approved requirements; archive exchange and shared domain hosting are not yet implemented.

## Native working form

Native storage uses app-specific on-disk packages backed by Core Data. Retain one independently saved Work, Source Library, or Composer Arrangement per Document, including Editions as Arrangements. Kits own their domain schemas and persistence. Native saving avoids rebuilding unchanged content and rewriting unchanged large assets; converting the document and history into XML belongs to export. The current in-process snapshot packages remain the pre-alpha baseline while efficient working storage is implemented.

A native Work may reference assets, Profiles, Themes, settings, and research resources outside its package. Record the exact versions in use, detect newer versions, and adopt updates deliberately. Libraries support versioned objects, and authors may maintain multiple libraries for different topics or purposes. Investigate and prove native Document Versions and Time Machine integration rather than assuming they provide semantic object history automatically.

Save and Auto Save persist native state. Export produces a folio separately. Quitting an application's interface leaves other active clients working through shared, on-demand domain hosts. When clients no longer need a Document, safeguard it and release resident resources while retaining restoration associations. Closing or quitting never implicitly exports an archive. Native document behavior and the approved Work Session safety guarantees remain in force.

## Per-app archives and the Project folio

Retain `.flwr`, `.flrs`, and `.flcp` for per-app exports scoped to a native Document, alongside one Suite-wide `.folio` format for a Project and its related Documents. Retain the app-native `.flwrbundle`, `.flrsbundle`, and `.flcpbundle` Document boundaries. [Document file types](../document-file-types.md) distinguishes the approved target from existing registrations; changing this contract does not implement an importer or change application metadata.

The initial `.folio` contains one default-named Project as its top-level structure. The Project identifies the included parts and expresses their relationships. Its scope is declared during export, seeded by existing document associations and reviewed by the author. It adds no shared Save or Undo boundary. Works remain Write-owned; Source Libraries remain Research-owned; Arrangements, including Editions, remain Composer-owned. Layout is not a new domain object.

A per-app archive captures its Work, Source Library, or Arrangement and the exact dependencies needed to reconstruct that Document independently. It shares the portable XML, history, capability, validation, and import/export rules below. It declares its narrower scope and does not claim to archive the entire related Project. Associated Documents outside that scope remain relationships; required content snapshots and resources are still captured. The `.folio` operation gathers the selected Project and its archival associations.

A Project can select Documents across the Suite and include the exact settings, Profiles, Themes, fonts, and other resources required for independent reconstruction and reproduction. Declared complete document members remain distinguishable from captured dependency records or snapshots. A Library or Arrangement can be exported without inventing a Work to contain it. A dedicated Project-management app, persistent working Project management, and `.foliobundle` are deferred.

## Consistent export and portable representations

One export operation gathers snapshots through the relevant domain interfaces and presents one review of the included parts. Capture a consistent collection of identified accepted document revisions and exact dependency versions. A simultaneous transaction across independently owned Documents is not required. Once captured, continue editing while export serializes and validates those fixed inputs. Preserve an Arrangement's selected source revisions; do not refresh them to the latest Work text simply to make capture times match. Export does not mutate its source Documents.

Transform document semantics and durable historical/Undo content from private Core Data storage into extensively documented XML. Specify the meaning needed to reconstruct retained states, branches, action ordering and grouping, Undo/Redo position, attribution, and relationships. Opaque stores or runtime command objects are not a substitute for that representation. This does not mandate event sourcing or replaying original application code to obtain the current state. Resources use purpose-appropriate file representations.

## Archival completeness

A folio is the object preserved for posterity: a durable, fully serialized archive that reconstructs the declared Project from zero using compatible software, including the Folio Suite. Include each selected Document's complete owned content and retained durable history, subject to explicit omission. A selected Work includes its unplaced content and explicitly associated Composer Arrangements (including Editions), with exact dependencies required to inspect, edit, and reproduce them. Capture required Profiles, Themes, assets, settings, fonts, referenced library records, and necessary research materials, including dependencies unused by the current Edition. Entire unrelated libraries are not required. The [Arrangement contract](arrangement-contract.md) defines explicit archival associations: an unrelated publication does not enter the archive merely by referencing a Work. Capture associated Arrangements and their required dependency graphs; missing associated material requires resolution or explicit exclusion with reduced scope declared. Required current snapshots survive history omission.

Extensively document and specify the format so anyone can implement compatible software. Prefer highly standardized, purpose-appropriate internal formats. PDF/A and PDF/X were examples of the desired standards discipline, not a blanket choice for all content. The [semantic model contract](semantic-model-contract.md) establishes semantic XML with namespaces, a DTD for verifiable core structure, and supplementary validation where needed. Exact format versions, conformance requirements, element schemas, and archive encoding profile remain to be specified. The `.folio` decision selects the shared archival boundary without adopting every proposed convention in the earlier ZIP/XML research.

A complete export verifies its dependency inventory, exact versions, integrity hashes, and required fallback representations, then verifies reconstruction in an isolated context without the originating libraries, installed extensions, or original file locations. Include a machine-readable manifest and validation report. Define precise verification coverage as part of the later conformance specification.

If a dependency is missing, inaccessible, or cannot be redistributed, explain the unresolved requirement and allow resolution or replacement. Any explicitly reduced, redacted, or incomplete export is a separately identified operation and must not be represented as a complete folio.

## Author-directed history omission

The [semantic history contract](semantic-history-contract.md), approved in #8 and ADR 0010, qualifies default history preservation. Authors may explicitly omit history during native saving, including overwrite, and any folio export. For `.folio` export, Omit History applies to the entire Project and is declared for each affected Document. Per-app archives apply the same omission rule within their declared Document scope; source Documents remain unchanged. A history-omitted folio is valid and retains current owned content and required dependencies, but cannot claim complete historical reconstruction. Current Comments, unresolved Proposed Revisions, current-content attribution, and historical snapshots required by current Arrangements remain. Export preserves history by default. Existing external versions and backups are unaffected.

## Independent readers and extension preservation

Define reader capabilities explicitly: inspection/extraction, reconstruction/editing, and Rendition reproduction. New features declare their requirements at the relevant object or document scope. Prompt about unsupported requirements and the available safe actions; a higher version number alone does not decide compatibility. Preserve unfamiliar content when rewriting and restrict editing where its meaning cannot be preserved safely. A reader cannot claim complete reconstruction after dropping meaning. The [lifecycle contract](document-lifecycle-contract.md) defines upgrade, compatibility, and cancellation behavior.

Basic reconstruction does not require an original plug-in, execution of an embedded script, or an external service. Preserve declarative semantics and original structured extension data alongside durable, accurate standard representations, relevant text, accessibility information, and relationships. An unsupported object may be presented read-only while its original data remains available to a capable editor.

Identify extensions using publisher-qualified package identifiers, versions, and relevant schema identifiers. Specialized editing or reproduction may require declared capabilities; the absence of those capabilities must not make the underlying intellectual content inaccessible.

The [composition and publication contract](composition-publication-contract.md) specifies recorded production inputs, versioned engine behavior, and deliberate feature selection. Reproduction depends on support for those inputs and capabilities; XML validity alone does not establish identical pagination in a changed engine. Preserve the original published Rendition where its exact historical appearance matters.

## Import and reconstruction

Archives are imported and exported, never edited or saved in place. Double-clicking any supported archive type prompts for import into the corresponding native Document or collection of Documents. Import into a chosen ordinary folder and reconstruct the app-native Documents and resources as a coherent collection, preserving the enclosed relationships. No `.foliobundle` or Project-management app is required.

Enclosed dependency versions are authoritative; no prior library setup or original file location is required. Reconnection to existing libraries or Documents is optional and deliberate. Matching names, identities, or newer available versions never silently substitute content. Import performs necessary supported upgrades into current native formats without a separate native-upgrade prompt; unsupported requirements still receive the appropriate capability disclosure.

Retain archived content identities, provenance, and history within the imported collection while treating the resulting native Documents as independent working instances. Importing the same archive twice, or while its source Work is open, must not route edits into the other copy or silently merge them. Restore relationships among the newly imported parts. The Project is an archival relationship structure, not a new shared authority.

Prepare and validate the collection before presenting its Documents as ready. Cancellation or failure leaves existing Documents and the original archive untouched and must not present a partial set as a successful reconstruction. The original archive remains the archival artifact.

## Remaining work

Issue #4 is resolved at design scope by ADR 0013 and the document lifecycle contract. Issue #13 remains retired as superseded. Test Folio-owned save/restore coordination, immutable export capture, history omission, capability handling, independent repeated imports, failed reconstruction, and archival validation as their implementations arrive. Exact schemas, archive encoding/conformance details, migration algorithms, and host packaging remain follow-up work. Broad scale and File Provider qualification are not a prerequisite for lifecycle design; Core Data itself does not require a general durability qualification campaign.

Issue #6 is resolved by the [semantic model contract](semantic-model-contract.md) and [ADR 0006](../adr/0006-extensible-semantic-model-and-xml.md): independently specified semantics, XML representation, preservation of unknown structures, and capability and dependency declarations now have an approved contract. Exact schemas and conformance mechanisms remain further work.

Issue #7 is resolved by the [Source Library contract](source-library-contract.md) and [ADR 0007](../adr/0007-independent-source-records-and-reconciliation.md): Work-local Source records are independently editable subsets with retained identity and provenance, deliberate reconciliation, and dependencies scoped to the research material actually required. [ADR 0014](../adr/0014-professional-workspaces-and-optional-source-sync.md) adds opt-in paired bibliographic synchronization without automatic reconnection of imported copies. Source Library native versioning integration still requires implementation proof. Issue #8 is resolved by the [semantic history contract](semantic-history-contract.md) and [ADR 0010](../adr/0010-document-undo-and-durable-history.md). Storage mechanisms, scale, retention, automation integrations, and native lifecycle proofs remain further work.
