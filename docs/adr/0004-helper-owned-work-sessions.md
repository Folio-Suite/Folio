<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Give document authority to domain hosts

Amended on 2026-09-13 by [issue #15](https://github.com/Folio-Suite/Folio/issues/15). The original mandatory central menu bar helper topology is superseded; the filename is retained for existing links.

Write owns Work capabilities, Research owns Source Library capabilities, and Composer owns Edition capabilities. Their Kits define models, operations, persistence adapters, and reusable presentation; the owning domain's application or service host manages authoritative open instances. Applications primarily configure and host these capabilities. Other applications request operations through the owning domain's interfaces.

This preserves specialized desktop applications while removing the central menu bar application requirement. A framework loaded by multiple processes shares implementation, not in-memory authority. XPC is a candidate service transport; exact host packaging and supervision remain open.

The Undo rule is subsequently amended by [ADR 0010](0010-document-undo-and-durable-history.md): accepted edits follow document-wide ordering across applications and automation.

## Consequences

- Applications own presentation and transient interaction state; the Session safeguards accepted semantic changes and recoverable drafts. The single editorial baton belongs to the author, not one application.
- The Session mediates mutations, narrowly scoped editing locks, durable acceptance, and coordinated restoration. Local communication still requires stale-request checks and invalidation of failed connections.
- Durable restoration associations survive application exit without retaining locks, live connections, or resident Work state indefinitely.
- Native Auto Save, Document Versions, Save, Close, Quit, and restoration are architectural requirements. A private recovery store alone does not satisfy the native document experience.
- Owner startup, shutdown with active clients, recovery supervision, transport, and packaging remain to be proven. Safety does not depend on a particular presentation window remaining open. Native packages and separate archival folio export remain established by [ADR 0005](0005-native-packages-and-archival-folios.md).

The retained behavior and remaining proofs are recorded in [the Work Session contract](../architecture/work-session-contract.md). The current applications host documents in process; cross-application authority is not implemented by this amendment.
