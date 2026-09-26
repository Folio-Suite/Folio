<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Give Composer Arrangements a shared snapshot model

Approved in [issue #9](https://github.com/Folio-Suite/Folio/issues/9): Write owns Works and Manuscripts; Composer owns independently saved Arrangements composed of Content Unit placements, snapshots, and revisions. Retire Assembly as a separate primitive and keep derivation one-way, giving each Composer document its own history instead of supporting two ownership models.

Profiles have explicit domain scope. Edition is an included Composer Profile requiring pinned, locally retained, self-contained production inputs while allowing deliberate subsequent editing. Following references and local retention remain independent choices for general Arrangements. Profile authoring policy was left open by this decision and is subsequently settled by [ADR 0012](0012-semantic-publication-and-native-composition.md): supplied and user-authored Profiles share the same declarative facilities.

This amends the Arrangement/Edition ownership assumptions in ADRs 0006, 0009, and 0010, and qualifies ADR 0005's archive graph through explicit Work-to-Arrangement associations. See [the Arrangement contract](../architecture/arrangement-contract.md) for update, omission, dependency, and remaining-proof rules. Shared machinery does not imply implemented storage or publication guarantees.

ADR 0012 also clarifies that an Edition's editorial identity is independent of medium. Its named Production Configurations govern presentation, and generated Renditions do not silently introduce output-specific editorial changes.
