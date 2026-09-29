<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Captured interface proof, including binary property lists

Date: 2026-09-29. Command: `ruby run.rb`. Exit status: 0.

Apple Swift 6.4; Swift 6 language mode; complete concurrency checking; warnings as errors.
Two executable processes and one expected-failure compiler fixture. All 50 checks passed.

```text
Building for debugging...
[2 / 5] UndoKitInterfaceProbe
[5 / 8] UndoKitInterfaceProbe
[10 / 11] UndoKitInterfaceProbe
[18 / 22] InterfaceConsumer-product
[19 / 22] InterfaceConsumer-product
[21 / 22] InterfaceConsumer-product
Build complete! (2.13 sec)
PASS: binary codec emits a binary property list
PASS: binary plist preserves host intent while changing byte representation
SIZE OBSERVATION (one small fixture, not a benchmark): JSON=42, XML plist=281, binary plist=83 bytes
PASS: host intent identity stays stable across JSON/XML byte representations
PASS: XML codec emits a property list
PASS: main-actor non-Sendable model changes through public boundary
PASS: accepted-effect payload differs from Command payload
PASS: outcome lookup does not reapply the Command
PASS: compensation returns its own encoded effect
PASS: XML payload decodes and dispatches on the host actor
PASS: binary property-list payload decodes and dispatches on the host actor
PASS: host-owned resource resolves by store and object identity
PASS: missing host resource: correct failure
PASS: framework fixture resolves from its resource bundle
PASS: background actor accepts intact custom-coded organization command
PASS: custom-command host compensates from a separately typed effect
PASS: unknown schema: correct failure
PASS: unknown schema: original bytes retained
PASS: unknown codec: correct failure
PASS: unknown codec: original bytes retained
PASS: oversized bytes: correct failure
PASS: oversized bytes: original bytes retained
PASS: malformed XML property list: failure reported
PASS: malformed binary property list: failure reported
PASS: malformed custom payload: correct failure
PASS: malformed custom payload never reaches semantic application
PASS: malformed JSON: failure reported
PASS: integrity mismatch: correct failure
PASS: missing registration: correct failure
PASS: duplicate registration: correct failure
PASS: invalid inputs never reach semantic application
PASS: host rejection remains application-neutral
PASS: host rejection is available through outcome lookup
PASS: unknown outcome remains unresolved
PASS: uninterpretable display metadata does not prevent an otherwise valid operation
PASS: saved bounded fixture envelopes for a fresh reader process
WRITE PHASE COMPLETE
PASS: fresh registration decodes json fixture
PASS: fresh registration decodes xml fixture
PASS: fresh registration decodes binary fixture
PASS: fresh registration decodes old fixture
PASS: fresh background registration decodes custom fixture
PASS: fresh reader decodes accepted-effect fixture independently
PASS: reading and registration rebuilding perform no semantic edits
PASS: old source bytes unchanged after version adaptation and inspection
PASS: binary source bytes unchanged after version adaptation and inspection
PASS: json source bytes unchanged after version adaptation and inspection
PASS: custom source bytes unchanged after version adaptation and inspection
PASS: xml source bytes unchanged after version adaptation and inspection
PASS: fresh host resolves retained external resource identity
PASS: JSON rejects non-finite floating-point default: failure reported
READ PHASE COMPLETE
PASS: negative actor-crossing fixture rejected for a data-race risk

```
