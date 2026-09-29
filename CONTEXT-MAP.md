<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Domain context map

Read the entry for each context touched by the task. For integration work, read both the framework and consumer entries. Shared architecture decisions live in [docs/adr/](docs/adr/); read those relevant to the change, including [ADR 0015](docs/adr/0015-swift-suite-and-independent-frameworks.md) for framework independence and Suite integration.

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

Covers generic durable-history capabilities and storage safeguards in `UndoKit/`.

- [UndoKit/CONTEXT.md](UndoKit/CONTEXT.md): history vocabulary and host/framework ownership.
- [UndoKit/docs/durable-acceptance-contract.md](UndoKit/docs/durable-acceptance-contract.md): accepted transaction and recovery boundary.
- [UndoKit/docs/history-retention-contract.md](UndoKit/docs/history-retention-contract.md): accepted restoration, Undo depth, checkpoint, hold and pruning behavior.
- [UndoKit/README.md](UndoKit/README.md): implementation status and integration guidance.
- For imported design or research, start with [the design index](UndoKit/docs/imported-design/README.md) and [provenance](UndoKit/UPSTREAM.md) to distinguish preserved records from current decisions.

Hosts own semantic meaning, validation, compensation, accepted outcomes, recovery evidence, and policy. Read the Folio Suite context when changing Folio's use of UndoKit. Add context-specific ADRs under `UndoKit/docs/adr/` when needed.
