<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Give Work Session authority to a Suite helper

Folio will use a small menu bar helper to own authoritative Work Sessions shared by independently launched Suite applications. This lets the author edit through multiple applications without tying the Work's safety or lifetime to the application that opened it first, while embracing native macOS/Cocoa document behavior.

## Consequences

- Applications own presentation and transient interaction state; the Session safeguards accepted semantic changes and recoverable drafts. The single editorial baton belongs to the author, not one application.
- The Session mediates mutations, narrowly scoped editing locks, durable acceptance, and coordinated restoration. Local communication still requires stale-request checks and invalidation of failed connections.
- Durable restoration associations survive application exit without retaining locks, live connections, or resident Work state indefinitely.
- Native Auto Save, Document Versions, Save, Close, Quit, and restoration are architectural requirements. A private recovery store alone does not satisfy the native document experience.
- The helper's precise process supervision, transport, packaging, and visual design remain to be proven. Native packages and separate archival folio export are established by [ADR 0005](0005-native-packages-and-archival-folios.md); internal storage and native integration remain to be proven.

The approved behavior and remaining proofs are recorded in [the Work Session contract](../architecture/work-session-contract.md), resolving [issue #5](https://github.com/ctwelve/Folio/issues/5).
