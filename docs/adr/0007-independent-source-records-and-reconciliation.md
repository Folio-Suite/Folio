<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Keep Work-local Source records independent and reconcile deliberately

A Work copies the immediately useful subset of Source data into an independently editable record, retaining Source identity and provenance linking it to its fuller library context. This supports focused, portable writing and multiple independently organized Source Libraries without allowing library edits to silently rewrite existing Works. Changes in either direction are offered for deliberate reconciliation against the last shared state.

## Consequences

- Source identity, record identity, and record revision are distinct. Partial copies do not imply deletion of omitted library fields, and matching metadata does not automatically merge identities.
- Shared text foundations let research commentary become independently editable Manuscript content while preserving Citations and their required Source and evidence dependencies.
- Native Works may use exact-version external materials. Complete archival folios gather required records and materials across the Work, history, and Editions; unrelated library contents do not automatically follow.
- Replacing or removing research material preserves existing controlled dependencies. Replacement does not promise to migrate annotations; unavailable external material remains an explicit missing dependency.

The approved [Source Library and portable evidence contract](../architecture/source-library-contract.md) resolves [issue #7](https://github.com/Folio-Suite/Folio/issues/7) and refines ADRs 0005 and 0006. Storage mechanisms, framework divisions, reconciliation algorithms, and operating-system versioning proofs remain further work.
