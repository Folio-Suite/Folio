<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Compose publications from meaning, templates, and coordinated Streams

Folio will derive a shared Publication Plan from an Edition and compose it for each medium through a native engine in ComposerKit. Composer provides visual authoring of meaning, templates, and constraints; the engine makes placement decisions. This WYSIWYM direction protects writing from continual adjustment of individual rendered objects while supporting reusable page designs and coordinated text, translation, and Note Streams.

User-authorable Composer Profiles govern construction and layout; Themes govern shared appearance and typography. Both use versioned declarative definitions. Correspondence between passages is meaningful document information; a Profile determines its visual synchronization. The engine builds on Apple’s typography facilities behind a replaceable composition interface, with whole-paragraph composition as the minimum, whole-page composition as the goal, and even typographic color as the quality criterion.

Approved on 2026-09-26 through the design interview for [issue #12](https://github.com/Folio-Suite/Folio/issues/12), Q1–Q18 and final confirmation. The [composition and publication contract](../architecture/composition-publication-contract.md) records the behavior, staged proofs, and deferred questions. The [native paragraph research](../research/2026-09-26-native-paragraph-composition.md) establishes available controls and evidence limits; API availability does not establish the required composition quality.

## Consequences

- An Edition’s text and supporting material are independent of output medium. Production Configurations change presentation; editorial changes remain deliberate changes to the Edition or a derivative Arrangement.
- This refines the Theme/composition allocation in the semantic model contract and resolves the Profile authoring question left open by ADRs 0006 and 0011. Their ownership, preservation, and independent-history guarantees remain in force.
- XML schema evolution and migrations preserve the declared meaning of inputs. Versioned composition behavior and feature flags govern algorithm changes; exact historical appearance can be retained in the original Rendition without promising identical output from every future engine.
- Begin with controlled native typography experiments using the first question of the *Summa Theologiae*, then prove coordinated Streams and paged production before completing the separate HTML and EPUB output paths. Exact specimen sources and implementation choices remain to be established.
- This records architecture and experiment scope. The provisional Composer shell does not implement it; no composition, publication-conformance, or archival lifecycle proof is claimed.

[ADR 0015](0015-swift-suite-and-independent-frameworks.md) assigns reusable Core Text composition to TypographyKit, with ComposerKit retaining publication semantics and coordination. The native comparison evidence is complete in issue #22; further quality/control verification accompanies implementation.
