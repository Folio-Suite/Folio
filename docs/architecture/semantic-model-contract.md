<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Semantic model and Profile contract

Approved on 2026-09-08 through the design interview for [issue #6](https://github.com/Folio-Suite/Folio/issues/6), Q1–Q45, followed by confirmation of the consolidated contract. [ADR 0006](../adr/0006-extensible-semantic-model-and-xml.md) records the architectural decision. This specifies the data-model contract; exact schemas, native classes, storage internals, and editing algorithms remain subsequent work.

## Work, Manuscript, and Content Units

The Work owns authored material. Its Manuscript is the primary assembled, ordered text, arranged from Content Units. A Content Unit can remain unplaced within the Work, retaining its identity, content, and relationships without contributing to the Manuscript's reading order. Ownership is hierarchical and unambiguous; placement and ownership are distinguishable, and non-owning relationships can cross the hierarchy.

Structural and independently meaningful objects have persistent identity from creation, including paragraphs, Notes, Figures, Citations, and editorial Comments. Identities survive editing and movement. The identity encoding is open: GUIDs are not mandated, and storage cost matters. Text positions require a separate attachment mechanism; this does not require giving every character its own persistent identity.

Unplacing a whole Content Unit removes it from the Manuscript's arrangement while retaining it in the Work. Deleting deliberately removes the authored object, subject to revision and dependency rules. Ordinary text deletion keeps its normal meaning. Unplaced content belongs in native preservation and a complete archival folio; it contributes to a Rendition only when selected by the relevant arrangement.

Live reuse of whole Content Units is an explicit advanced feature, separate from ordinary copy-paste. An original has one structural home, with identifiable reuse placements. Editing shared content changes the original; independent wording requires an explicit independent copy or version relationship, whose detailed design remains open. Arbitrary sentence-fragment reuse is outside the initial contract.

An advanced imposed arrangement can select, omit, repeat, and reorder existing Content Units without changing their underlying homes. Different Editions can use different arrangements. This is internal organization of one Work; the glossary's Assembly remains an arrangement of independently identified Works.

## Shared vocabulary and type contracts

A small document-aware foundation provides text, typed values and records, ordered containment, relationships, and asset references. A substantial common vocabulary is built on that foundation: sections and headings, paragraphs, lists, quotations, tables, Figures, Notes, Citations, Cross-references, mathematical expressions, code, verse, and common inline semantics. The exact element inventory and individual content models remain to be specified.

The boundary follows shared document meaning. Common structures should be sufficiently specific to carry useful semantics and sufficiently general for Profile specialization. Mathematics in prose, verse in a quotation, or code in an instructional chapter must not require a separate Work model. Specialized concepts such as proofs, dramatic speeches, or dictionary entries can exercise extension facilities. Both built-ins and extensions use the same primitives and definition facilities.

A type has one primary semantic superclass and may implement multiple composable declarative contracts. An implemented contract states required properties, relationships, and guarantees; it is not merely a capability label. A type definition includes named and typed properties, permitted contents and contexts, relationships, cardinalities, constraints, semantic prose, and examples.

Specialization can add properties and compatibly narrow constraints while honoring inherited meaning and guarantees. It cannot remove required inherited members or reinterpret their meaning. Needing a member gone means choosing an appropriate lower-level ancestor or defining a new semantic kind. New kinds are allowed and remain subject to declaration, preservation, and fallback requirements.

Conflicting composed requirements invalidate the definition. Compatible requirements may combine; import order, application preference, and silent overrides do not choose which meaning wins. Namespace qualification distinguishes otherwise identical short names.

The independently readable vocabulary specification is the contract. Native classes and validation artifacts implement it. Its practical purpose is to keep every modeled structure explicitly representable in a normal exchange format, including its identities, relationships, and requirements, rather than letting runtime implementation create an inexpressible model.

## Authored meaning and presentation

Meaning, composition, permitted contents, and permitted placement are distinct concerns. Inline and block placement do not by themselves establish different semantic kinds. An equation retains its mathematical meaning in either context; Profiles can impose context and content constraints.

The Work preserves authored logical/semantic structure and authored presentational intention, such as intentional line breaks, indentation, spacing, and spatial grouping. Themes and Edition settings impose medium-specific composition; explicit Edition overrides remain distinguishable from authored structure. Annotations form a separate layer over content rather than becoming its ownership hierarchy.

Emphasis and strong emphasis carry semantic intention and are interpreted contextually. Explicit bold and italic are also permitted. Authoring guidance should encourage meaning where appropriate without discarding deliberate typography. Meaning must not be inferred solely from appearance.

Historical-text preservation is not this contract's scope. Source-page milestones, competing historical reference systems, and scholarly transcription machinery are not required by the examples used in the interview.

## Notes and editorial annotations

Notes are authored content with attachments and semantic roles. Footnotes, endnotes, and marginalia are not editorial annotations; foot, end, and margin are presentation choices unless an explicit authorial requirement makes placement significant. Profiles can distinguish kinds such as explanatory or translator's Notes. Their numbering and marking remain separately configured.

Editorial annotations primarily cover office-document-style Comments and Proposed Revisions. They belong to a Work-owned editorial branch and refer to their targets. Targets may include text ranges, whole objects, relationships, and other annotations; types declare permitted targets and target roles, including multiple targets where appropriate. Replies may have their own hierarchy. Range attachments can overlap and cross textual structure.

An unresolved Comment whose discussed text disappears can retain a detached target and contextual information for resolution, reattachment, or deliberate removal. Edits must not silently attach it to unrelated replacement text. Deliberate removal of an attachment can remove the Comment, but an embedded insertion point is only a possible representation, not a required mechanism. Precise attachment and editing behavior remains to be designed.

Tracked revisions are explicit proposals for insertion, deletion, replacement, or structural change, retaining what is needed for acceptance or rejection. A view can show the proposed result, but the Work distinguishes proposals from editorially approved wording. Saving a proposal as accepted Work Session state does not imply editorial acceptance of its wording. Durable editing history and command behavior remain the subject of #8.

Quotations, Citations, authored Notes, and other semantic objects retain their own meanings even if they share range-targeting mechanisms with editorial material. General historical meta-commentary is not a required built-in annotation system.

## Numbering, marking, and composition

Keep object identity, Numbering Series identity and membership, sequence rules, ordinal, Mark, mark formatting, and placement distinct. Numbering Series are explicit objects with ordering rules and restart scopes. Note 1:1, Figure 1:1, and Table 1:1 remain distinct; two sets of Notes may use different series without becoming unrelated underlying types.

Formatting can use numbers, letters, ordered symbols, or explicit author labels. The displayed form is not the machine identity or necessarily a numeric string. A Note's callout and its displayed content use the appropriate corresponding mark. Explicit marks need not imply a numeric position.

Support independent sequences together, including footnotes with symbols restarting at each facing-page opening, endnotes with letters restarting by chapter or section, and an appendix collection of Notes numbered continuously across chapters. Ordinary chapter, page, section, opening, and continuous scopes must be expressible; page-dependent results cannot be determined before composition.

The Work records semantic kinds, meaningful groupings, series assignments, and explicit author requirements. Profiles provide defaults and constraints; Editions configure numbering, restart, and marking policies. Automatically resolved ordinals and Marks belong to a particular composed result. Cross-references identify their targets symbolically and resolve against that same result, so their labels agree with it. Recomposition must not silently replace explicit author requirements.

Authors configure these policies alongside the relevant Notes or other objects, in one coherent configuration surface rather than managing the internal object decomposition. Supply predefined configurations and style-guide-based sets, such as APA or Chicago. Exact presets, editions of those guides, scope interactions, and final controls remain to be specified.

## Profiles, vocabularies, and application responsibility

One governing Profile applies to a Work and composes reusable semantic vocabularies. It may specialize types, add new kinds, and constrain use in particular contexts without creating a separate Work model. Prefer common structures and preserve Content Unit identities through Profile changes wherever those structures remain applicable.

Changing Profile can leave authoring incompatibilities visible while preserving content and the definitions needed to interpret it. Selecting a Profile does not silently rewrite or discard content. A transformation of structure or meaning is an explicit conversion. Structural integrity remains mandatory; Profile conformance and publication completeness can remain unfinished during drafting.

Namespaces identify semantic vocabularies, not applications. Each vocabulary should ideally have a primary responsible application, allowing application specialties to follow natural semantic divisions. This is responsibility for vocabulary and editing surfaces; the helper-owned Work Session authority in ADR 0004 remains in force. Exact application names and framework divisions remain open.

Initially the Suite implements its vocabulary comprehensively. Plug-in contracts are planned extension facilities rather than an initial dependency for built-in semantics. An integration such as Zotero should be possible through the model's extension facilities; this does not commit a particular integration API or require a new semantic type for each integration.

## XML representation and validation

Serialize recognizable semantic elements named by their vocabularies, using XML with namespaces and consistent conventions for properties, containment, identity, and relationships. XML's hierarchy expresses ownership; references express relationships beyond that hierarchy. Generic object records are not the primary semantic serialization vocabulary.

Require a DTD expressing at least verifiable core structure. DTD validation is not sufficient semantic validation. The format contract additionally specifies typed-property checks, relationship-target compatibility, dependency requirements, version compatibility, and other semantic constraints. RELAX NG, Schematron, or other supplementary validation may be needed; no supplementary technology is selected yet. Restrict the modeled structures to explicitly representable XML forms rather than letting a particular validator dictate their meaning.

Prescribe canonical prefixes in Folio serialization for predictable DTD validation. Semantic type identity is the namespace URI and local name, not the prefix. Namespace identifiers and definition versions are explicit; URI naming and alternate-prefix import handling remain to be specified.

Readers preserve the complete structure and information of unfamiliar content, including qualified names, properties, ordering, relationships, and text. Handle unfamiliar whitespace conservatively. XML serialization need not remain byte-identical, while opaque embedded payloads retain their bytes. Do not discard unknown content or silently claim successful reconstruction after losing meaning.

The original extension data and durable, accurate standard fallbacks required by the [archival folio contract](archival-folio-contract.md) remain mandatory. Basic reconstruction does not require an installed original plug-in, executing embedded code, or an external service. Reader capabilities must state inspection, editing/reconstruction, and reproduction limits.

## Versioning and native representation

Semantic type identities are stable and vocabulary-qualified; exact definition versions are recorded separately. Each Work state resolves one active definition version per vocabulary. Frameworks may support older and newer representations, and historical Work states retain their corresponding definitions.

Compatible evolution retains semantic identity. Incompatible structural evolution can retain meaning and identity but requires deliberate migration and a corresponding version change in the implementing framework. Fundamental changes of meaning require a different semantic identity. Prefer to avoid incompatible structural changes; existing Works do not silently adopt new definitions. A migration produces a coherent new state rather than mixing incompatible versions within one state.

Objective-C is the leading code representation because the intended model benefits from message-based object orientation and dynamic behavior; Swift remains possible. No new framework, runtime mechanism, class inventory, identity encoding, or native storage technology is selected by this contract. The shared semantic and exchange contracts constrain any implementation.

## Dependencies and safe partial editing

Complete, programmatically inspectable declarations describe dependencies that affect editing safety, including cross-object relationships maintained by runtime behavior. Identify affected objects and, where practical, properties or parts, plus capabilities needed for maintenance. If precise declarations are unavailable, declare a conservative broader scope. Missing or unrecognized dependency information is not proof that an edit is safe.

Distinguish ordinary references, semantic dependencies, and presentation dependencies. A reference may only need to retain a target. A semantic dependency may require updating another object's meaningful state when its source changes. A presentation dependency may only require regenerating a preview or Rendition.

An installation may edit supported parts of an unfamiliar specialization only when it can validate the affected requirements, preserve the entire object faithfully, and maintain affected semantic dependencies. Recognizing a superclass is insufficient. A declarative definition may provide enough understanding without a specialized plug-in. Otherwise affected content remains read-only while unrelated supported content can remain editable.

An edit that would leave a semantic dependency inconsistent is blocked if the required maintenance is unavailable, including when the dependent object is elsewhere. For example, otherwise familiar text cannot be changed by a naive reader if an unsupported Figure requires a semantic update in response. Presentation outputs may instead become explicitly stale or unavailable; absence of a renderer alone must not prevent editing understood, output-independent content.

## Remaining specification and proof

This resolves the semantic core and Profile extension decision, not a complete element schema or production implementation. Remaining work includes exact element and contract inventories, serialized property and reference forms, identity/anchor encodings and storage cost, supplemental validators, detailed compatibility and migration rules, dependency propagation and cycle handling, and numbering algorithms and preset conformance. The safety promises above constrain those choices; their mechanisms remain unproven.

Detailed Content Unit reuse/version relationships, editorial attachment transformations, and command/history behavior remain further design work. The subsequent [Source Library contract](source-library-contract.md) resolves #7: independent Work-local Source records, deliberate reconciliation, shared research text foundations, structured Citations, and required evidence dependencies. #8 retains commands and durable history; #9 retains Assembly design; #10 retains application partition; #12 retains composition and publication architecture; #13 and #4 retain native package and lifecycle proofs. Plug-in execution and integration APIs remain unspecified. This contract does not authorize implementing those tickets or claim their proofs complete.

## Reference precedents

These informed the interview; Folio does not adopt either format wholesale.

- [TEI infrastructure and classes](https://tei-c.org/release/doc/tei-p5-doc/en/html/ST.html), [definition facilities](https://tei-c.org/release/doc/tei-p5-doc/en/html/TD.html), and [customization and conformance](https://tei-c.org/release/doc/tei-p5-doc/en/html/USE.html): useful distinctions between shared attributes, permitted placement, and semantic meaning. Model-class membership is not itself the semantic inheritance contract chosen here.
- [OpenDocument 1.4 Part 3](https://docs.oasis-open.org/office/OpenDocument/v1.4/os/part3-schema/OpenDocument-v1.4-os-part3-schema.pdf), sections 5.5, 6.3, 14.1–14.2, and 16.31.3: office-style revisions, Note body/citation separation, annotations, and numbering configuration. Its tracked-change interoperability caveat is a reason to specify Folio's behavior explicitly, not to infer editing behavior from markup alone.
- [XML 1.0](https://www.w3.org/TR/xml/), sections 3.2–3.3, and [Namespaces in XML](https://www.w3.org/TR/xml-names/), sections 2 and 5: DTD grammar, attribute and reference constraints, and the distinction between namespace identity and DTD matching of written names.
