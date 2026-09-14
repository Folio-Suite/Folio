<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Composer Arrangements and revision selection

Approved through the design interview for [issue #9](https://github.com/Folio-Suite/Folio/issues/9). See [ADR 0011](../adr/0011-composer-arrangements-and-editions.md). These are behavioral and ownership decisions, not implemented storage or publication guarantees.

## One content mechanism, explicit ownership

Write owns the Work and its Manuscript, the supplied ordered collection of authored Content Units. Composer owns independently saved Arrangements beginning from Manuscript snapshots. Each Composer document owns its snapshots, elaborations, configuration, history, and document-wide Undo; source Works retain their independent ownership and histories.

An Arrangement is an ordered collection of Content Unit placements that may select content, retain snapshots, and develop revisions of those snapshots. Local and externally sourced content use the same underlying mechanism, with origin and ownership explicit. Inclusion defaults to the source Manuscript but can select identified Content Units. The containing publication governs presentation without silently redefining authored meaning or inheriting every source production choice.

Assembly is retired as a separate architectural primitive. The earlier proposals that a Work owns an Assembly or that Arrangements can have either Work-owned or independent storage are superseded. The Manuscript is not itself a Composer Arrangement; sharing ordered-content machinery does not merge their domain ownership.

## Snapshots and one-way derivation

Derivation identifies an exact source state and preserves provenance. An Arrangement can begin from a Manuscript or an exact state of another Arrangement, allowing later printings and adaptations to build on earlier production work. Changes to the parent do not silently rewrite a pinned derivative.

Each placement can develop its own revisions of a snapshot, including different elaborations of repeated appearances of the same source Content Unit. Editing included material does not modify the source Work. Authors may save an elaboration as new Content Units with new identities and retained provenance; these are independently owned and no longer follow the original. Creation need not replace the existing inclusion. Do not back-port elaborations into existing Content Units: the derivation path is one-way.

Nested inclusion is supported; circular inclusion is rejected. Exact representation, dependency resolution, and deduplication remain implementation choices.

## Revision selection and local retention

Revision selection and storage location are independent: a placement can follow its source or pin an exact accepted revision, and required content can remain external-only or be retained locally. A pin need not be a named checkpoint. Explain that an external-only pin relies on the source continuing to supply that revision; retaining a local copy is the prudent default and should be strongly encouraged by Profiles.

An initial snapshot supplies the starting state. Unpinned placements can subsequently adopt newer accepted source revisions automatically, with updates visible and undoable in the containing document. Authors may pin placements as they proceed. Pinned references change only through deliberate adoption.

When local elaborations exist, compare the previously selected revision, the elaboration, and the new source revision. Preserve unambiguous local changes and pause adoption for author resolution of overlaps. Adoption is one undoable action in the containing document; the existing usable state remains until adoption succeeds. Exact comparison and reconciliation algorithms remain open.

If a pinned revision disappears, use its retained local copy. Otherwise mark it unresolved and require the author to locate that revision or explicitly choose a replacement; never silently substitute the latest revision. Unrelated editing and saving remain available, but operations requiring missing content cannot claim complete results.

Whole-Manuscript selection can follow revised membership. An explicit selection retains its identified targets: if an update removes one, preserve the existing usable selection pending author resolution rather than silently dropping or substituting content.

When creating a snapshot with an unavailable following reference, offer a retained known revision explicitly without presenting it as current. If no usable revision exists, preserve an unresolved reference and disclose the incomplete snapshot. Preparation can continue, subject to the stricter Edition transition below.

## Profiles and Editions

Use one Profile concept with explicit domain scope. Write Profiles define semantic structures, constraints, and authoring behavior. Composer Profiles define Arrangement rules, pinning, retention, and production behavior within that semantic environment. Profiles may supply lightweight specializations but cannot redefine ownership, identity, one-way derivation, or preservation guarantees. Whether Profiles are user-authorable or supplied exclusively remains a separate decision informed by behavior design.

Edition is an included Composer Profile. An Edition is a self-contained production Arrangement: it pins and locally retains all selected content and the exact dependencies required by that content and its production configuration. This includes required Figures, research material, and other dependencies, not unrelated portions of external Works. Creating it from following references resolves those inputs to exact revisions.

An Edition starts from a coherent snapshot but remains deliberately editable. Subsequent source changes require explicit adoption. Producing a Rendition records the exact Edition state and dependency revisions used. Identified historical states are fixed; the current Edition is not permanently read-only.

Authors may apply Edition configuration to an existing Arrangement or create a separate derivative. Applying the Edition Profile succeeds only when all required content can be resolved and retained. Until then it remains an Arrangement being prepared for that transition, not a complete Edition. Self-contained production inputs do not by themselves establish archival folio conformance.

## History and archival inclusion

Snapshots and elaborations required by current Arrangements are current content dependencies, even when they preserve older wording. Omit History must retain them. Editing records and abandoned states can be omitted under the semantic history contract; provenance can remain without every intervening edit.

Explicitly associate Composer Arrangements with a Work for archival inclusion. A complete folio includes those associated Arrangements and their required dependency graph, including nested required material. Merely referencing a Work from an unrelated publication does not associate that publication with the Work's archive. Missing associated material requires resolution or explicit exclusion with reduced archival scope declared. This replaces the unqualified instruction to include all Editions with an explicit association rule; independent document ownership remains intact.

## Remaining work

Storage and transport, snapshot and revision encodings, scale and deduplication, reconciliation algorithms, reference monitoring, archive graph capture, migration, and UI remain implementation or further design work. Profile authoring policy remains open. #12 retains composition/publication design; #13 and #4 retain native lifecycle and archival proofs. The user has deferred #13 until its architectural prerequisites are settled. No implementation is authorized or claimed by this decision.
