<!--
SPDX-FileCopyrightText: 2026 Matt Pocock
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Domain Docs

Adapted from [Matt Pocock's skill setup templates](https://github.com/mattpocock/skills), with Folio-specific conventions. See the retained [MIT notice](MATT-POCOCK-LICENSE) and [skill usage and attribution](../ai-skills.md).

How the engineering skills should consume this repository's domain documentation.

## Before exploring or changing code

1. Read the root `CONTEXT-MAP.md` and follow its pointers for each context involved in the task.
2. Read the relevant glossary, contracts, and ADRs for those contexts, together with applicable shared decisions in `docs/adr/`.
3. When changing code or project configuration, read `CONTRIBUTING.md` for workspace, validation, coordinated-change, and licensing guidance.

For work spanning a framework and its consumer, read both contexts. Keep framework concepts and host-owned meaning distinct using the boundaries recorded in the map and linked documents.

## File structure

This repository covers the Folio Suite and TypographyKit contexts. UndoKit is maintained in its own repository and checked out as the `UndoKit/` Git submodule. `CONTEXT-MAP.md` is the routing index. The Suite glossary remains at root `CONTEXT.md`; TypographyKit guidance belongs alongside its framework. Shared and Suite architecture decisions remain in `docs/adr/`; context-specific ADRs belong in their owning repository.

If a glossary or ADR directory does not exist, proceed silently using the existing documentation named in the map. The `domain-modeling` skill creates domain documents when vocabulary or decisions are resolved.

## Use the owning context's vocabulary

When naming a domain concept in an issue, proposal, hypothesis, or test, use the definition from its owning context. Preserve explicit distinctions when connecting concepts across contexts. If a needed concept has no agreed definition, raise the gap through `domain-modeling`.

## Flag ADR conflicts

If proposed work contradicts an existing ADR or accepted contract, surface the conflict explicitly rather than silently overriding the recorded decision. Use current accepted decisions to interpret imported design records; the map identifies the relevant historical index.
