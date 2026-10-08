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
- [Native document lifecycle](architecture/document-lifecycle-contract.md), including shared host lifetime, compatibility, upgrades, and native Versions
- [Native packages and archival folios](architecture/archival-folio-contract.md)
- [Source Libraries and evidence](architecture/source-library-contract.md)
- [Professional workflows and embedded editing](architecture/professional-workflow-contract.md), including capture destinations and handoff between applications
- [Document history and Undo](architecture/semantic-history-contract.md)
- [Composer Arrangements and Editions](architecture/arrangement-contract.md)
- [Composition and publication](architecture/composition-publication-contract.md), including the staged typography and coordinated-Stream experiments

For the implementation that exists today, read the [current library layout](architecture/current-library-layout.md) and [first Write editor notes](architecture/native-work-v1.md). The [first native shell specification](specs/first-native-shell.md) retains the historical specification and records acceptance at pre-alpha scope; its retired requirements are not current gates. Composer now hosts a bounded TypographyKit preview; Arrangement persistence and mature publication remain future work.

The [Core framework and Suite roadmap](plans/swift-migration-and-suite-roadmap.md) records the current framework structure and first implementation wave. The coordinated Swift migration implements [ADR 0015](adr/0015-swift-suite-and-independent-frameworks.md); [ADR 0016](adr/0016-core-framework-project.md) records the Core project decision. The [ticket handoff](plans/accepted-backlog.md) retains the migration stories and remaining design/proof work.

UndoKit is checked out as a Git submodule and retains an independently versioned native Xcode framework project; its Swift Package product remains available to other consumers. The current framework target supports macOS 14; iOS support requires separate qualification. See [ADR 0019](adr/0019-undokit-package-boundary.md), the submodule's [provenance record](../UndoKit/UPSTREAM.md), and [design inventory](../UndoKit/docs/imported-design/README.md) for its boundary and preserved research. Submodule checkout and tag-selection guidance is in [CONTRIBUTING.md](../CONTRIBUTING.md) and [Suite version and build identity](release-numbering.md).

TypographyKit now provides bounded, caller-selected Latin LTR composition through Core Text. Public interface documentation lives with each product: [FolioKit](../Core/FolioKit/FolioKit.docc/FolioKit.md), [WriteKit](../Core/WriteKit/WriteKit.docc/WriteKit.md), [ResearchKit](../Core/ResearchKit/ResearchKit.docc/ResearchKit.md), [ComposerKit](../Core/ComposerKit/ComposerKit.docc/ComposerKit.md), [UndoKit](../UndoKit/UndoKit/UndoKit.docc/UndoKit.md), and [TypographyKit](../TypographyKit/TypographyKit/TypographyKit.docc/TypographyKit.md). Build the local DocC catalogs in Xcode for symbol navigation. The older migration acceptance record covers the six frameworks before this submodule pin and is historical evidence.

## Development and distribution

- [Development CI](development-ci.md): workflow triggers, native test signing, local checks, and dated validation evidence.
- [Suite version and build identity](release-numbering.md): configured identity and recording completed build candidates.
- [Suite installer](installer.md): package construction and the separate clean-install proof.
- [Document file types](document-file-types.md): public names, bundle/ZIP extensions, UTIs, MIME types, legacy codes, and currently supported operations.
- [App and document icons](../Design/Icons/README.md): authoritative artwork, asset catalogs, accent colors, and regeneration.
- [Localization](localization.md): source strings, catalogs, translation policy, and resource ownership.
- [AI skill usage and attribution](ai-skills.md): global workflows, local adaptations, and upstream credits.

## Research and evidence

[Research notes](research/) record their stated dates, sources, assumptions, and evidence limits. They may compare alternatives that a later ADR did not adopt. Use their primary-source links when revisiting a question; use the current contracts for Folio's decisions.

The [publication standards survey](research/publication-and-accessibility-standards.md) informs output requirements. The [native paragraph-composition report](research/2026-09-26-native-paragraph-composition.md) identifies Apple API controls and the experiments needed to assess their results. The [localization audit](localization-audit-2026-09.md) preserves a dated inventory and remaining UI checks.

Historical build, test, and package results apply to their recorded revisions and environments. They are not current runtime, minimum-OS, installation, or publication-conformance acceptance. Keep those records intact and add new evidence when repeating a proof.
