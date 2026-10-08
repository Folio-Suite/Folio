<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Domain context map

Read the entry for each context touched by the task. For integration work, read both the framework and consumer entries. Shared architecture decisions live in [docs/adr/](docs/adr/); read those relevant to the change, including [ADR 0015](docs/adr/0015-swift-suite-and-independent-frameworks.md) and its extraction refinement, [ADR 0019](docs/adr/0019-undokit-package-boundary.md).

## Folio Suite

Covers the Write, Research, and Composer applications and the FolioKit, WriteKit, ResearchKit, and ComposerKit frameworks under `Core/`.

- [CONTEXT.md](CONTEXT.md): Suite vocabulary, document ownership, authored content, research, and publication concepts.
- [docs/adr/](docs/adr/): Suite and shared architecture decisions.

The Suite owns publication meaning and application policy. Its integration contracts define how host concepts use the independent frameworks.

## TypographyKit

Covers reusable text composition above Core Text in `TypographyKit/`.

- [TypographyKit/README.md](TypographyKit/README.md): framework boundary, supported composition inputs and results, limitations, and validation.
- Read symbol documentation alongside the public interfaces being changed.

TypographyKit accepts neutral composition inputs and returns geometry, source mappings, and diagnostics. ComposerKit owns publication meaning. Read the Folio Suite context when changing that integration.

Use the existing framework documentation until vocabulary is agreed for a local `TypographyKit/CONTEXT.md`. Add context-specific ADRs under `TypographyKit/docs/adr/` when decisions require them.

## UndoKit

Covers generic durable-history capabilities and storage safeguards in the [UndoKit Git submodule](UndoKit/README.md), backed by the independently versioned [Folio-Suite/UndoKit repository](https://github.com/Folio-Suite/UndoKit).

- [UndoKit/CONTEXT.md](UndoKit/CONTEXT.md): history vocabulary and host/framework ownership.
- [Durable acceptance contract](UndoKit/docs/durable-acceptance-contract.md): accepted transaction and recovery boundary.
- [History retention contract](UndoKit/docs/history-retention-contract.md): accepted restoration, Undo depth, checkpoint, hold and pruning behavior.
- [Typed interface contract](UndoKit/docs/typed-interface-contract.md): accepted host adapters, codecs, asynchronous submission, bounded queries and interface proof.
- [Native routing contract](UndoKit/docs/native-routing-contract.md): accepted native bridge behavior, host integration obligations and AppKit proof requirements.
- [Store lifecycle contract](UndoKit/docs/store-lifecycle-contract.md): accepted storage registration, lifecycle, capacity and failure-preservation contract.
- [Acceptance measurement plan](UndoKit/docs/acceptance-measurement-plan.md): accepted workloads, candidate limits, runner safeguards and four-proof evidence matrix.
- [UndoKit README](UndoKit/README.md): framework and package usage guidance.
- For imported design or research, start with [the design index](UndoKit/docs/imported-design/README.md) and [provenance](UndoKit/UPSTREAM.md). The provenance record links historical source and research by immutable revision.

UndoKit owns generic history structure and storage safeguards. Hosts own semantic meaning, validation, compensation, accepted outcomes, recovery evidence, and policy. Read the Folio Suite context when changing Folio's use of UndoKit. Context-specific decisions belong in the submodule's `docs/adr/` directory.
