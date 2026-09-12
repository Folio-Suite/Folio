<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Document the Kits to a public API standard

FolioKit, WriteKit, ResearchKit, and future Suite Kits use DocC for documentation suitable for a public API. These frameworks are likely to support external callers, so their documentation must let a developer use them correctly without reading their implementations. This standard applies while the interfaces are evolving; it does not itself promise API stability or binary compatibility.

## Consequences

- Document exposed symbols alongside their declarations: purpose, parameters and results, invariants, ownership and lifetime, threading requirements, side effects, failure behavior, and availability or limitations where applicable. Explain behavior rather than restating symbol names.
- Each Kit's DocC catalog introduces its responsibilities, principal types, and supported workflows. Include small, accurate examples for non-obvious usage and link related symbols so a newcomer can find an entry point.
- Keep implementation details private. Root documentation retains Suite architecture, governance, and development instructions; DocC explains the interface a caller consumes.
- New and changed interfaces carry their documentation in the same change. Bring existing surfaces up to this standard as they are developed, with remaining gaps treated as unfinished documentation rather than evidence of a stable public API.
- Validate generated documentation for affected Kits when changing catalogs or API documentation. Check examples and links against the actual interface, and fix documentation diagnostics introduced by the change.
