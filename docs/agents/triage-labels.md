<!--
SPDX-FileCopyrightText: 2026 Matt Pocock
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Triage Labels

Adapted from [Matt Pocock's skill setup templates](https://github.com/mattpocock/skills), with Folio-specific conventions. See the retained [MIT notice](MATT-POCOCK-LICENSE) and [skill usage and attribution](../ai-skills.md).

The skills speak in terms of five canonical triage roles. This file maps those roles to the actual strings used in this repository's issue tracker.

| Label in mattpocock/skills | Label in our tracker | Meaning                                  |
| -------------------------- | -------------------- | ---------------------------------------- |
| `needs-triage`             | `needs-triage`       | Maintainer needs to evaluate this issue  |
| `needs-info`               | `needs-info`         | Waiting on reporter for more information |
| `ready-for-agent`          | `ready-for-agent`    | Fully specified, ready for an AFK agent  |
| `ready-for-human`          | `ready-for-human`    | Requires human implementation            |
| `wontfix`                  | `wontfix`            | Will not be actioned                     |

When a skill mentions a role (for example, "apply the AFK-ready triage label"), use the corresponding label string from this table.

Edit the right-hand column to match whatever vocabulary the repository actually uses.
