<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Documentation guide

Start with [CONTEXT.md](../CONTEXT.md) for the shared vocabulary and [CONTRIBUTING.md](../CONTRIBUTING.md) for checkout, toolchain, build, and validation guidance. The [GitHub architecture map](https://github.com/Folio-Suite/Folio/issues/2) tracks decision and implementation work; an approved design does not establish that its implementation or acceptance checks are complete.

## Architecture and implementation

The [ADRs](adr/) record decisions and their rationale. Later amendments identify which earlier assumptions they replace. The contracts describe the intended behavior:

- [Semantic model and Profiles](architecture/semantic-model-contract.md)
- [Work Session authority](architecture/work-session-contract.md)
- [Native packages and archival folios](architecture/archival-folio-contract.md)
- [Source Libraries and evidence](architecture/source-library-contract.md)
- [Document history and Undo](architecture/semantic-history-contract.md)
- [Composer Arrangements and Editions](architecture/arrangement-contract.md)
- [Composition and publication](architecture/composition-publication-contract.md), including the staged typography and coordinated-Stream experiments

For the implementation that exists today, read the [current library layout](architecture/current-library-layout.md) and [first Write editor notes](architecture/native-work-v1.md). The [first native shell specification](specs/first-native-shell.md) defines the bounded milestone and its remaining acceptance obligations. Composer's framework and document shells do not yet implement the composition contract.

Public interface documentation lives with each Kit: [FolioKit](../FolioKit/FolioKit/FolioKit.docc/FolioKit.md), [WriteKit](../Write/WriteKit/WriteKit.docc/WriteKit.md), [ResearchKit](../Research/ResearchKit/ResearchKit.docc/ResearchKit.md), and [ComposerKit](../Composer/ComposerKit/ComposerKit.docc/ComposerKit.md). Build these DocC catalogs in Xcode for symbol navigation.

## Development and distribution

- [Development CI](development-ci.md): workflow triggers, native test signing, local checks, and dated validation evidence.
- [Suite version and build identity](release-numbering.md): configured identity and recording completed build candidates.
- [Suite installer](installer.md): package construction and the separate clean-install proof.
- [Localization](localization.md): source strings, catalogs, translation policy, and resource ownership.
- [AI skill usage and attribution](ai-skills.md): global workflows, local adaptations, and upstream credits.

## Research and evidence

[Research notes](research/) record their stated dates, sources, assumptions, and evidence limits. They may compare alternatives that a later ADR did not adopt. Use their primary-source links when revisiting a question; use the current contracts for Folio's decisions.

The [publication standards survey](research/publication-and-accessibility-standards.md) informs output requirements. The [native paragraph-composition report](research/2026-09-26-native-paragraph-composition.md) identifies Apple API controls and the experiments needed to assess their results. The [localization audit](localization-audit-2026-09.md) preserves a dated inventory and remaining UI checks.

Historical build, test, and package results apply to their recorded revisions and environments. They are not current runtime, minimum-OS, installation, or publication-conformance acceptance. Keep those records intact and add new evidence when repeating a proof.
