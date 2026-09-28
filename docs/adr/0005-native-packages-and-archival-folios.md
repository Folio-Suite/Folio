<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Use native packages and export archival folios

Folio uses on-disk packages as its native storage form, with distinct package types for Works, libraries, Profiles, and other concepts defined as needed. The 2026-09-27 lifecycle decision in [ADR 0013](0013-document-lifecycle-and-project-archives.md) retains app-native Document boundaries and Core Data working stores while broadening the archival folio to a Project. A Suite-wide `.folio` initially contains one default-named Project expressing the included parts and relationships, allowing reconstruction independently of the originating machine, libraries, and installed extensions. Retain the per-app `.flwr`, `.flrs`, and `.flcp` archives for native-Document scope alongside the Project archive; a working `.foliobundle` and Project-management app remain deferred.

[ADR 0010](0010-document-undo-and-durable-history.md) qualifies history preservation: explicit author-directed omission is supported on save (including overwrite) and export. A valid history-omitted folio declares the omission and cannot claim complete historical reconstruction; current Work and dependency preservation still apply.

## Consequences

- Save and Auto Save preserve native package state; exporting a folio is a separate operation. This supersedes the portable-checkpoint-on-Save assumption in the original #5 interview and the native package-versus-ZIP competition in #4 and #13.
- Native Works may reference external versioned resources. Changes to those resources are detected and adopted deliberately; archival export captures the exact dependency versions required for self-containment.
- Native Auto Save and Document Versions integrate with authoritative domain state. File-level versions, semantic history, and Source Library object versions have distinct roles. Core Data is the working-store foundation; precise domain schemas and implementation checks remain follow-up work.
- Native saving avoids rebuilding unchanged content and assets. Archival export separately serializes document semantics and durable history/Undo into documented XML, with purpose-appropriate resource files.
- Archives are imported and exported. Import reconstructs independent native Documents together in an ordinary folder; it does not edit the archive or reconnect to existing Documents automatically.
- The archival format must be extensively documented and specified for independent implementations, with purpose-appropriate standardized internal representations, explicit reader capabilities, and accurate fallbacks for extension content.
- A complete folio includes a dependency manifest and validation report, and must pass isolated reconstruction checks. Missing, inaccessible, or non-redistributable dependencies prevent a claim of completeness.

The approved details are in [the archival folio contract](../architecture/archival-folio-contract.md) and [document lifecycle contract](../architecture/document-lifecycle-contract.md). [Issue #4](https://github.com/Folio-Suite/Folio/issues/4) is resolved at design scope; implementation remains outstanding. [Issue #13](https://github.com/Folio-Suite/Folio/issues/13) remains retired as superseded. Use targeted experiments for concrete integration uncertainties and verify Folio-owned behavior as it is implemented; a broad storage qualification prototype is not a prerequisite.

[ADR 0011](0011-composer-arrangements-and-editions.md) subsequently establishes Composer-owned Arrangements and the self-contained Edition Profile, scoped Profiles, and explicit archival associations. It supersedes earlier Work-owned Arrangement/Edition assumptions while preserving independent document histories.
