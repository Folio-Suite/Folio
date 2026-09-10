<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Domain Docs

How the engineering skills should consume this repository's domain documentation when exploring the codebase.

## Before exploring, read these

- **`CONTEXT.md`** at the repository root: the shared Suite vocabulary.
- **`docs/adr/`**: read ADRs that touch the area about to be changed.
- **`CONTRIBUTING.md`**: read the workspace, validation, and coordinated-change guidance when changing code or project configuration.

If a domain document does not exist, proceed silently. The `/domain-modeling` skill creates domain documents lazily when terms or decisions are resolved.

## File structure

Folio uses one shared domain context across its Xcode monorepo:

```text
/
├── CONTEXT.md
├── docs/adr/
├── Folio.xcworkspace/
├── FolioKit/
├── Write/
└── Research/
```

The root glossary and ADRs apply across all three components. Separate Xcode projects and module ownership do not require separate domain glossaries. Keep cross-Suite decisions here and symbol documentation alongside its owning code.

If a root `CONTEXT-MAP.md` is introduced later, follow its pointers to the relevant context-specific glossaries and decision records, together with system-wide ADRs in `docs/adr/`.

## Use the glossary's vocabulary

When output names a domain concept—in an issue title, refactor proposal, hypothesis, or test name—use the term as defined in `CONTEXT.md`. Do not drift to synonyms the glossary explicitly avoids.

If a needed concept is absent from the glossary, either reconsider whether the term belongs to Folio or note a genuine gap for `/domain-modeling`.

## Flag ADR conflicts

If proposed work contradicts an existing ADR, surface the conflict explicitly rather than silently overriding the recorded decision.
