<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# AI skill usage and attribution

Folio uses AI development skills to support architecture discussions, domain modeling, research, implementation, debugging, and review. Skills provide reusable instructions and references; project decisions and validation requirements remain in [CONTEXT.md](../CONTEXT.md), [the ADRs](adr/), and [CONTRIBUTING.md](../CONTRIBUTING.md).

## Global catalog

The maintainer keeps reusable, cross-project skills in `~/.agents/skills/` so their behavior stays consistent across projects. Folio-specific adaptations remain local. An audit on **26 September 2026** matched all 42 installed skill directories to the source records in `~/.agents/.skill-lock.json`:

| Upstream collection | Installed skills | Role |
| --- | ---: | --- |
| [Matt Pocock's skills](https://github.com/mattpocock/skills) | 38 | Engineering, architecture, writing, and collaboration workflows |
| [rgmez's Apple accessibility skills](https://github.com/rgmez/apple-accessibility-skills) | 3 | AppKit, SwiftUI, and UIKit accessibility audits |
| [Vercel Labs' skills](https://github.com/vercel-labs/skills) | 1 | `find-skills`: discovery of reusable agent skills |

This is a dated attribution inventory, not a requirement to install every skill or a guarantee that every agent exposes the entire catalog. The global source records and installed files are the inventory to consult when revisiting it.

## Matt Pocock's engineering skills

[Matt Pocock's `mattpocock/skills`](https://github.com/mattpocock/skills) is a substantial foundation of Folio's AI-assisted development workflow. We credit Matt for the composable engineering practices we use, including architecture and module design, shared domain vocabulary, focused research, debugging, test-driven development, and standards/specification review.

The maintainer installs these skills globally so the same workflows are available across software projects. They are no longer vendored as a second copy in Folio. Global installation changes where the instructions are maintained; their authorship remains Matt's. Contributors using these workflows can follow the [upstream installation guidance](https://github.com/mattpocock/skills#installation-30-second-setup), selecting their agent's user/global scope.

Folio retains its project-specific integration: [issue-tracker conventions](agents/issue-tracker.md), [triage-label mapping](agents/triage-labels.md), and [domain-document guidance](agents/domain.md). These documents adapt Matt's `setup-matt-pocock-skills` templates. Their source notices and a copy of his [MIT license](agents/MATT-POCOCK-LICENSE) remain in the repository.

## Additional global credits

**Vercel Labs** provides [`find-skills`](https://github.com/vercel-labs/skills/blob/main/skills/find-skills/SKILL.md), used to discover skill collections and inspect candidates for the shared development environment. Its source is [MIT-licensed](https://github.com/vercel-labs/skills/blob/main/LICENSE).

**Dex Horthy / HumanLayer** deserves credit within the Matt Pocock collection: the installed `pr` skill explicitly attributes its “shape of the change” section to Dex's [`show-me` skill](https://github.com/humanlayer/skills/blob/main/plugins/show-me/skills/show-me/SKILL.md). Matt's [credit note](https://github.com/mattpocock/skills/blob/main/skills/in-progress/pr/CREDITS.md) explains that the material is incorporated into the PR workflow. `show-me` is not separately installed in this catalog; this acknowledges the contribution carried through the installed skill.

## Apple-platform skills

| Source and author | How Folio uses the work | Location |
| --- | --- | --- |
| [rgmez's Apple accessibility skills](https://github.com/rgmez/apple-accessibility-skills) | The AppKit auditor supports focused VoiceOver, keyboard, and semantic-structure reviews. SwiftUI and UIKit auditors are also globally available for projects using those frameworks. | Contributor's global skills; upstream MIT license |
| [Antoine van der Lee's Core Data skill](https://github.com/AvdLee/Core-Data-Agent-Skill) | A condensed adaptation for Folio's Objective-C persistence adapters, with reviewed save, conflict, migration, and batch-operation guidance. | [`folio-core-data`](../.agents/skills/folio-core-data/SKILL.md), [provenance](../.agents/skills/folio-core-data/UPSTREAM.md), [MIT notice](../.agents/skills/folio-core-data/LICENSE) |
| [Charles Wiltgen's Axiom](https://github.com/CharlesWiltgen/Axiom) | Selected AppKit and TextKit material adapted for Folio's native interaction and reusable editors. | [`folio-appkit`](../.agents/skills/folio-appkit/SKILL.md), [provenance](../.agents/skills/folio-appkit/UPSTREAM.md), [MIT notice](../.agents/skills/folio-appkit/LICENSE) |

Apple's Xcode-supplied skills and documentation are additional first-party resources in the developer's Xcode environment. They are not vendored here, and their discovery depends on that environment. Xcode tool access for builds, tests, debugging, and documentation is configured separately from skill installation.

## Using and maintaining the setup

Use the skill that fits the task: general engineering workflows from the global collection, the local Core Data or AppKit guidance for Folio-specific work, and the AppKit auditor for accessibility reviews. The project-local adaptations preserve our Cocoa direction and refer back to the repository's current conventions.

A clone does not install global skills or pin their versions. Check the skills available to the active agent when following a workflow; a missing global skill is an environment setup issue, not a build dependency. These instructions are development tooling and are not shipped as application runtime components.

Maintain the local adaptations through their `UPSTREAM.md` records, which identify reviewed revisions, selected source files, local changes, and refresh checks. Preserve upstream authorship and license notices when revising imported material. Keep global collections in the contributor's shared setup rather than reinstalling duplicates in the project.

The [September 2026 research comparison](research/2026-09-26-apple-macos-agent-skills.md) records the evaluation that preceded this setup. This page describes the adopted arrangement; the research's installation counts and initial recommendations are historical observations.
