<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Domain Docs

How the engineering skills should consume this repository's domain documentation when exploring the codebase.

## Before exploring, read these

- **`CONTEXT.md`** at the repository root, or
- **`CONTEXT-MAP.md`** at the repository root if it exists: it points at one `CONTEXT.md` per context. Read each one relevant to the topic.
- **`docs/adr/`**: read ADRs that touch the area about to be changed. In multi-context repositories, also check `src/<context>/docs/adr/` for context-scoped decisions.

If any of these files do not exist, proceed silently. Do not flag their absence or suggest creating them upfront. The `/domain-modeling` skill creates them lazily when terms or decisions are actually resolved.

## File structure

Folio currently uses a single-context layout:

```text
/
├── CONTEXT.md
├── docs/adr/
└── src/
```

If a root `CONTEXT-MAP.md` is introduced later, it defines a multi-context layout and points to the relevant context-specific glossaries and decision records.

## Use the glossary's vocabulary

When output names a domain concept—in an issue title, refactor proposal, hypothesis, or test name—use the term as defined in `CONTEXT.md`. Do not drift to synonyms the glossary explicitly avoids.

If a needed concept is absent from the glossary, either reconsider whether the term belongs to Folio or note a genuine gap for `/domain-modeling`.

## Flag ADR conflicts

If proposed work contradicts an existing ADR, surface the conflict explicitly rather than silently overriding the recorded decision.
