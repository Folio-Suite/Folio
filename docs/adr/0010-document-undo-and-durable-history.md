<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Keep Undo and durable history with each document

Approved in [issue #8](https://github.com/Folio-Suite/Folio/issues/8): each independently saved document owns native Undo ordering and branching durable history, shared by interactive and automated edits. Document-wide ordering supersedes the earlier originating-context Undo rule so automation remains the author acting through another channel, without global reversal machinery.

Durable history is enabled by default, supports named checkpoints and reopening, and preserves reversals and displaced states. Explicit author intent may disable recording or omit existing history during saving (including overwrite) or export; this qualifies ADR 0005's mandatory-history requirement. Current content and editorial material remain preserved, and a history-omitted folio declares its reduced historical coverage.

See [the semantic history contract](../architecture/semantic-history-contract.md) for settings, recovery, atomic semantic operations, native automation conventions, attribution, and remaining proofs. These are approved behavioral requirements, not claims that the current editor implements them.
