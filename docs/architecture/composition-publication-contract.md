<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Composition and publication

Approved on 2026-09-26 through the design interview for [issue #12](https://github.com/Folio-Suite/Folio/issues/12), Q1–Q18 and final confirmation. [ADR 0012](../adr/0012-semantic-publication-and-native-composition.md) records the decision. This contract specifies behavior and the sequence of proofs; it does not describe implemented Composer capabilities.

The [semantic model](semantic-model-contract.md), [Arrangement](arrangement-contract.md), [history](semantic-history-contract.md), and [archival folio](archival-folio-contract.md) contracts remain authoritative for ownership, preservation, and document operations. This decision refines Profile and Theme responsibilities and supplies the composition architecture. The [publication standards research](../research/publication-and-accessibility-standards.md) informs output requirements; the [native paragraph research](../research/2026-09-26-native-paragraph-composition.md) distinguishes available Apple controls from unproved typography and integration behavior.

The subsequent [Swift migration and TypographyKit specification](https://github.com/Folio-Suite/Folio/issues/29) records the maintainer's selection of a compositor above Core Text and proposes its independent TypographyKit interface, with ComposerKit retaining publication meaning and page/Stream orchestration. Another TextKit-versus-Core Text selection prototype is not a prerequisite. The [proposed roadmap](../plans/swift-migration-and-suite-roadmap.md) places the controlled TypographyKit foundation before full paragraph optimization and the early coordinated-Stream proof; quality and integration still require evidence. The experimental stages below remain useful implementation checks rather than a requirement to reopen engine choice.

## Editions, Production Configurations, and the Publication Plan

An Edition identifies its selected text and supporting material independently of medium. It can have several named Production Configurations, such as print, EPUB, or static web, with different presentation choices. These configurations accommodate the Edition's content; they do not silently rewrite, omit, or reorder its intellectual content to make a layout fit. Different ways of navigating or displaying corresponding Streams can preserve that content and its relationships.

The current Edition remains deliberately editable under the Arrangement contract. Editorial changes belong to an explicit Edition change or a derivative Arrangement, rather than a hidden output-specific copy. Producing a Rendition does not change the Edition or its source Works. Retain the exact content and dependencies required by the Edition's declared Production Configurations.

Derive a shared Publication Plan from an exact Edition state and its declared inputs. It carries selected content, semantic structure, Stream order and roles, Correspondences, logical reading relationships, symbolic references, and publication metadata. Preserve the identity of selected occurrences and their source provenance, including repeated placements. Changed inputs produce a new derived plan; generation must not accidentally combine content from different accepted states.

The plan is medium-independent, not a universal page layout. Medium-specific composition resolves page or region geometry, reflow, navigation presentation, and any numbering and Marks that depend on those results. Cross-references resolve against the same composed result as their targets. Keep publication identifiers, metadata, and conformance evidence scoped to the entities and outputs they describe, as established by the standards research.

## Composer and its composition engine

Composer follows WYSIWYM: the author expresses meaning, relationships, and constraints, and inspects their composed consequences. Visual design remains useful for reusable templates and their regions. The normal workflow does not invite authors to nudge each rendered Figure or text fragment into a fixed position. Authored presentational intent, including meaningful line breaks, spacing, and spatial relationships, remains part of the semantic contract.

Composer's UI supplies the bounds and parameters; its engine makes composition decisions. Precisely positioned page regions receive content whose placement and continuation follow rules. Content-linked exceptions can express a required relationship or a permitted placement preference. They remain distinguishable from authored meaning, survive recomposition as declarations, and produce diagnostics when they cannot be satisfied.

The composition module belongs in ComposerKit and is callable through its public interface independently of a window. The same domain interface serves native UI and automation. It accepts the identified publication inputs and configuration and returns composed results, mappings to their originating content and rules, and diagnostics. The existing Kit ownership and document-history contracts remain unchanged.

Build on Apple's native shaping, font, and text-layout facilities. Keep publication composition separate from an editor text view's interactive layout. A replaceable engine implementation can be introduced if needed without redefining the Edition, Publication Plan, or declarative inputs. This does not select a new framework target, plug-in packaging mechanism, or independently stable binary interface.

## Profiles, Themes, and reusable templates

Profiles and Themes are user-authorable and shareable. Built-in and custom definitions use the same declaration facilities while preserving Folio's ownership, identity, derivation, and archival guarantees.

| Definition | Responsibility |
| --- | --- |
| Write Profile | Semantic structures, authoring constraints, and behavior within the shared Work model. |
| Composer Profile | Arrangement construction, Page Templates, regions, Stream assignment and continuation, synchronization, layout constraints, and production requirements. |
| Theme | Common appearance: typography, semantic styling, palette, and related presentation assets, with adaptations for supported media. |
| Production Configuration | An Edition's named selection and settings for the applicable Profile rules, Theme, target medium, and composition behavior. |

A Page Template describes repeatable designs such as recto and verso body pages, facing-page openings, and chapter pages. The interview's initial use of “signature” referred to these templates; it does not establish a press-sheet imposition feature.

Definitions can share common appearance and assets while supplying deliberate paged or reflowable variants. A Theme need not support every medium. Reflowable output has its own rules for flexible regions and presentation rather than inheriting fixed print coordinates. Profiles may recommend or include Themes, without requiring a particular Theme as part of their identity.

A Profile declares requirements and permitted flexibility; a Theme supplies appearance within those bounds. Where appropriate, layout constraints refer to typographic measurements, such as multiples of the body-text baseline, rather than independently duplicating the same decision. A 96-point heading in a region too short to accommodate it is a diagnosable conflict, not permission to silently discard text or alter a required type size. Explicit production settings remain recorded inputs.

Use composable, versioned declarations for Streams, regions, matching rules, synchronization, constraints, and styles. Visual tools edit these declarations, and advanced authors can work with their documented exchange representation. The engine supplies algorithms; definitions select and configure named, versioned capabilities. Executable composition algorithms are not embedded in ordinary Profile or Theme definitions. Exact element names, property inventories, and supplementary validation mechanisms remain specification work under the existing XML contract.

## Streams and Correspondence

Treat body text, translations, authored Notes, marginalia, and other suitable publication content as named, ordered Streams, with primary or alternate roles. Sharing this composition mechanism does not erase semantic kinds: a Note remains authored content with its role and attachment, and a Figure retains its caption, attribution, description, and numbering behavior. Streams do not introduce a second owner for the content.

Correspondence between identified passages is meaningful independently of presentation. Store it in the document where the relationship is authored: a Work can relate its own material, while an Arrangement can establish relationships between selected source snapshots. Preserve those relationships through derivation and archival capture.

Initial matching supports paragraph-by-paragraph or section-by-section relationships, including automatic inference rules. Inference may use declared structure and headings; established relationships must not depend solely on unchanged heading wording. Preserve explicit matches and expose ambiguity or missing counterparts rather than inventing a relationship. Advanced non-linear Correspondences, such as substantially rewritten passages whose order diverges, remain future work.

Profiles specify synchronization points at meaningful boundaries. Between points, Streams can flow independently. At required synchronization points, they align again, accepting whitespace beneath shorter material where needed. A common baseline grid governs vertical rhythm; Correspondence governs which passages are related. These are separate constraints and do not imply line-for-line equivalence between translations. A Profile can make a synchronization preference more permissive.

Multiple Streams must also retain their internal reading order and discoverable relationships in reflowable outputs. Detailed compact presentation remains deferred. Swipe-based navigation between parallel web views and separate EPUB text sequences linked at corresponding passages are candidates, not selected implementations. Alternating original and translated paragraphs is not an adopted default. Future interaction design must preserve access to the selected Streams and their relationships.

## Constraints and diagnostics

Distinguish preferences from requirements. Preferences guide choices and allow alternatives; requirements must be satisfied or reported as unmet. These decisions belong to the engine, while Composer exposes the declarations and explains the result.

Return diagnostics tied to the affected content, region, Profile rule, Theme value, or dependency. An inline warning marker with an explanation is an appropriate presentation, with text and keyboard/assistive access to the explanation. Examples include an oversized heading, an impossible synchronization requirement, missing font coverage, or an unsupported declared capability. The same information must be available to callers without the UI.

Useful incomplete previews remain available while problems are resolved. Final production requires resolution of unmet requirements for the selected configuration. Ordinary permitted compromises should not overwhelm the author with warnings. A failed composition must explain its unsatisfied requirements rather than silently relaxing them or claiming a complete result. Exact optimization priorities, diagnostic codes, and convergence mechanisms remain to be specified and tested.

## Typography and font dependencies

Whole-paragraph composition is the minimum intended capability; whole-page composition is the goal. Even typographic gray/color is the quality target: readable, balanced texture without distracting variations in spacing. Shaping text and justifying successive independently chosen lines is not, by itself, proof of meeting that target. Equally, Apple's internal behavior must not be dismissed merely because its complete optimization algorithm is undocumented.

Evaluate the native paragraph behavior first. The research identifies documented TextKit 2 improvements for justified paragraphs and explicit Core Text line-construction controls. Experiments must establish the useful range of those controls, the quality of the results, and whether Folio needs additional paragraph search or page coordination. No particular native algorithm, custom search implementation, or quality threshold is selected by API documentation alone.

Themes declare primary fonts and ordered default fallbacks by typographic role and script. Cases include serif body text, sans-serif text, monospaced material, and headings. Evaluate suitable Apple fonts as defaults, and explicitly support Computer Modern and Latin Modern OpenType fonts in the proof set. The families and their variants are not presumed interchangeable in metrics or features.

Record exact required font dependencies and typography settings, including selected faces, sizes, variations, and features; the composed result identifies the fonts actually used. The engine chooses within the declared fallback policy. Unavailable required fonts or missing character coverage produce diagnostics. A preview may disclose a temporary substitute, but final production uses resolved declared dependencies. Existing archival and redistribution requirements apply; availability on one Mac does not itself establish a complete portable dependency set.

## Versioned behavior, exchange, and Renditions

The working representation and the documented XML exchange representation remain distinct concerns. Specify the exchange form precisely, validate its structural and semantic requirements, and maintain deliberate migrations when schemas evolve. Preserve the existing rules for unknown data, exact dependency versions, and independently readable content.

Version composition behavior and record feature flags with the Production Configuration. New justification or layout behavior is adopted deliberately rather than silently replacing a stored choice through changed defaults. A reader or engine must disclose unsupported requirements. Schema validity establishes neither a particular pagination nor identical output from every future engine.

A Rendition records its exact Edition state, configuration, definition and dependency revisions, selected engine behavior, and production environment. Reproduction depends on support for those recorded inputs and capabilities. Retain the original published Rendition when its exact historical appearance matters. This contract does not require permanent support for every old implementation or promise byte-identical exports across changed production environments.

PDF, EPUB, and web have separate generation and final-artifact validation. Preserve semantic structure, accessibility information, language, relationships, and appropriately scoped metadata through each path. A successful layout or PDF drawing operation is not a conformance claim. Select and verify concrete conformance targets during the corresponding output work, with validation evidence attached to the generated artifact.

## Staged experiments and production proofs

The first question of the *Summa Theologiae* is the agreed typographic specimen. Exact Latin source, translation, edition, and any additional apparatus remain to be selected and recorded. No specimen has been imported or engine experiment run by this decision.

1. **Prepare controlled inputs and native baselines.** Record the specimen, semantic structure, languages, font files/versions, Profile and Theme settings, operating-system/SDK environment, and selected engine. Compare native paragraph layouts with the same inputs. Start with deliberate changes to measure, type size, leading, hyphenation, spacing, and available font features, then test useful interactions. Keep each comparison's settings and rendered results so improvements are attributable to particular controls.
2. **Establish paragraph capability and quality.** Inspect whole paragraphs, break choices, spacing variation, hyphenation, fallback, runtime, and sensitivity to small text or measure changes. Review typographic color on rendered pages as well as measurements. Evaluate a Folio-controlled sequence of breaks only where native behavior or control proves insufficient; retain native shaping. Set acceptance thresholds from the specimen and evidence, without claiming an undocumented global optimum.
3. **Prove coordinated Streams early.** Use unequal corresponding passages, shared baselines, section synchronization, footnote overflow, and competing marginalia. Change text length and font size to force recomposition, and include a deliberately impossible requirement. Demonstrate preserved content and anchors, understandable diagnostics, and bounded reconsideration when paragraph and page choices affect one another. This is part of the first engine milestone, not an enhancement postponed until a general template editor exists.
4. **Complete paged production and PDF output.** Build on the proven engine, then verify output structure, references, metadata, and the selected publication requirements in the final PDF. A specimen preview alone does not establish the PDF production path.
5. **Complete separate HTML and EPUB paths.** Consume the same Publication Plan, preserve content and relationships, and validate each output independently. Resolve medium-specific parallel-reading behavior during that work.

The [research report's bounded probe](../research/2026-09-26-native-paragraph-composition.md#recommended-bounded-proof--inference-not-a-decision) supplies the initial API comparisons and unanswered control questions. Its recommendations are experimental candidates, not substitutes for measured results or the agreed multi-stream milestone. Experiments should produce evidence and a recommendation before committing to the detailed text-layout integration or building a large template editor.

## Deferred specification and future fog

Exact XML schemas, definition composition syntax, native classes, engine interfaces, quality thresholds, algorithms, scale limits, and concrete validation tooling remain subsequent work constrained by this contract. Issue #4 resolves native lifecycle design through the [document lifecycle contract](document-lifecycle-contract.md); its implementation remains outstanding. Issue #13 was retired as superseded; focused Folio integration checks belong with the relevant implementation, rather than a broad prerequisite prototype.

Advanced non-linear Correspondence and detailed compact parallel-reading interactions remain deferred. Possible licensing of commercial fonts such as Adobe Minion Pro, their distribution terms, and potential paid Theme packs are pinned for future investigation. No licensing or business-model conclusion is implied.
