<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Core Data source and maintenance

This is a condensed, locally maintained derivative of [AvdLee/Core-Data-Agent-Skill](https://github.com/AvdLee/Core-Data-Agent-Skill), reviewed at commit [`855ca7d0df50e82b00c12881dd9cd23c19ef5f49`](https://github.com/AvdLee/Core-Data-Agent-Skill/tree/855ca7d0df50e82b00c12881dd9cd23c19ef5f49/core-data-expert). It is not a complete mirror or an upstream-endorsed Folio edition. Local adaptation date: 2026-09-26.

The original [MIT license](LICENSE) and Antoine van der Lee's copyright notice are retained unchanged. Folio's modifications carry their own SPDX notices and the repository's MIT license.

## Source selection

Paths below are relative to upstream `core-data-expert/` at the pinned revision. The local references combine selected guidance and corrections; they are not verbatim file copies.

| Local file | Upstream basis |
| --- | --- |
| `SKILL.md` | `SKILL.md`: inspect context/store facts, route by problem, verify changed behavior |
| `references/contexts-and-saving.md` | `references/threading.md`, `references/stack-setup.md`, `references/saving.md`, and lifecycle/conflict sections of `references/model-configuration.md` |
| `references/models-and-migrations.md` | `references/model-configuration.md`, `references/migration.md`, `references/testing.md` |
| `references/fetching-and-batch-changes.md` | Fetch/performance routing in `SKILL.md` and `references/batch-operations.md` |

The broader Swift concurrency, CloudKit, glossary, and project-audit branches and long sample implementations were not imported. The separate research comparison remains a historical source-audit snapshot, not the installed skill's current instructions.

## Local revisions

- Scope discovery to Core Data work in Folio; preserve Objective-C adapters, visually authored models, Kit resource ownership, and existing document lifecycles.
- Replace the universal store-trump requirement with explicit conflict semantics and save-error handling.
- Make persistent history one propagation option; preserve direct object-ID merging for known contexts.
- Distinguish permanent object IDs from committed data and child saves from durable persistence.
- Replace pre-save attachment deletion recipes with coordination at the durable operation and recovery boundary.
- Diagnose resource/model mismatches before assuming migration is required; preserve renaming identity across model versions.
- Use SQLite and native document evidence for claims that an in-memory store cannot establish.

Apple references are linked alongside the relevant guidance. They were checked with Apple's documentation and the selected Xcode SDK during adaptation.

## Refreshing this derivative

Compare the selected upstream paths with the pinned revision and review useful changes individually. Recheck altered API claims against current Apple documentation and the project's deployment target. Preserve the local ownership and behavior constraints, original license, and useful corrections; record a new reviewed revision here only after that review. An upstream installer/update should not overwrite these locally named files.

Run the skill creator's frontmatter validator and check reference links after revisions. For changes to decision-making guidance, exercise a representative queue/save/conflict or migration/batch scenario and inspect the proposed behavior, rather than testing for particular wording.
