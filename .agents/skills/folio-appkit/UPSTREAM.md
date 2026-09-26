<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# AppKit and TextKit source and maintenance

This is a selected, locally maintained derivative of [CharlesWiltgen/Axiom](https://github.com/CharlesWiltgen/Axiom), reviewed at commit [`c297598480e39d992044831ac0b895a431c7db51`](https://github.com/CharlesWiltgen/Axiom/tree/c297598480e39d992044831ac0b895a431c7db51). It is not a complete mirror or an upstream-endorsed Folio edition. Local adaptation date: 2026-09-26.

The original [MIT license](LICENSE) and Charles Wiltgen's copyright notice are retained unchanged. Folio's modifications carry their own SPDX notices and the repository's MIT license.

## Source selection

| Local file | Pinned upstream basis |
| --- | --- |
| `references/appkit-interaction.md` | [`axiom-codex/skills/axiom-macos/skills/appkit-modernization.md`](https://github.com/CharlesWiltgen/Axiom/blob/c297598480e39d992044831ac0b895a431c7db51/axiom-codex/skills/axiom-macos/skills/appkit-modernization.md) |
| `references/textkit.md` | [`axiom-codex/skills/axiom-uikit/skills/textkit-ref.md`](https://github.com/CharlesWiltgen/Axiom/blob/c297598480e39d992044831ac0b895a431c7db51/axiom-codex/skills/axiom-uikit/skills/textkit-ref.md) |

`SKILL.md` is a local entry point for these adapted references. The broad macOS router, SwiftUI/UIKit implementations, distribution and sandbox material, and unrelated SDK catalogs were not imported. The research comparison documents why the broader collection was not adopted unchanged.

## Local revisions

- Limit discovery to AppKit interaction and NSTextView/TextKit tasks in Folio; retain storyboard interfaces and owning Kit boundaries.
- Treat dedicated controls/delegates as preferred tools, while preserving justified custom input handling and intentional key-view loops.
- Connect command validation and restoration to the active document, undo, and failed-save behavior.
- Replace automatic modernization prescriptions with task-driven API selection and deployment checks.
- Retain TextKit compatibility-mode detection, range conversion, and viewport-layout reasoning; replace UIKit examples with AppKit-specific guidance.
- Distinguish text-system transactions from domain edits and undo groups, and preserve marked text and semantic attributes.
- Add primary Apple references and native verification criteria without duplicating the globally installed accessibility auditor.

Apple documentation and Xcode 27 AppKit headers were consulted for the retained APIs, including `NSTextView`, `NSTextContentManager`, and the compatibility-mode notifications. These files do not grant a migration to SDK-only behavior or establish runtime proof.

## Refreshing this derivative

Diff the two selected upstream files against the pinned revision; incorporate useful changes after checking their AppKit applicability and availability. Keep upstream attribution and local constraints, and update the reviewed revision here after validation. An upstream installer/update should not overwrite these locally named files.

Run the skill creator's frontmatter validator and check reference links. For behavioral revisions, exercise a representative responder/focus or text-editing scenario and inspect the proposed actions and verification plan. API name matching alone does not validate an interaction.
