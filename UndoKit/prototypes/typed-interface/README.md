<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Disposable UndoKit typed-interface proof

Question: can a small host adapter keep typed domain values and actor-owned models
on the application's side while UndoKit receives bounded, opaque, identifiable
messages through an independent Swift module?

**Result, 2026-09-29: feasible at the tested interface boundary.** All 50 checks
passed using Apple Swift 6.4, Swift language mode 6, complete concurrency checking
and warnings treated as errors on the current arm64 macOS 27 host. The writer
and reader run as separate processes. This is evidence for the design discussion
in [#43](https://github.com/Folio-Suite/Folio/issues/43), accepted by the maintainer as interface feasibility evidence on 2026-09-29.
The binary property-list extension is included; no production implementation
is claimed.

## Run

From this directory:

```sh
ruby run.rb
```

The script builds two separate Swift modules, runs the writer and a fresh reader
against disposable local fixture files, and checks that an intentionally unsafe
actor crossing fails compilation for a data-race diagnostic. Build artifacts
stay in ignored `.build`; temporary fixture files are removed after the run.
There are no external package dependencies. This native compiler and serialization
proof deliberately uses Swift rather than an interactive state-machine mockup.

## What crossed the interface

- `WriteAdapter` is MainActor-isolated and owns a non-Sendable text model and
  non-Sendable typed command values.
- `KitchenAdapter` is an ordinary actor with its own non-Sendable organization
  model. Its entire multi-recipe command stays intact and uses a custom codec;
  the command type does not conform to Codable or Sendable.
- Host codecs encode before crossing into the probe actor. The async endpoint
  receives Sendable identities and byte envelopes, decodes on its owning actor,
  performs its own domain operation and returns encoded evidence.
- A separate accepted-effect type records prior/resulting state. Compensation
  consumes that effect, and outcome lookup returns a protocol outcome without
  applying the command again.
- The public module uses Foundation and its own types; hashing is private
  CryptoKit implementation. It imports no Folio or KitchenMemory module and
  exposes no Collections/Algorithms types. The consumer uses ordinary public
  imports, without `@testable`, `@unchecked Sendable`, or `nonisolated(unsafe)`.

The operation names and payload models are illustrative, not production consumer
APIs. Host semantic code and in-memory receipts make the boundary observable;
those receipts do not meet the production durability contract.

## Caller sketches exercised

Main-actor text edit:

```swift
let request = try host.request(ReplaceText(unit: "chapter-1", replacement: "After"))
let evidence = try accepted(await probe.deliver(request))
```

Background-actor organization:

```swift
let request = try await kitchen.request(recipeIDs: ["recipe-1", "recipe-2"], destination: "Weekend")
let evidence = try accepted(await probe.deliver(request))
```

The app-owned request helpers contain fingerprint and codec choices. Application
results and rejection explanations remain outside the module's Outcome type.
`BoundaryProbe.deliver` is an experimental transport seam, not the final public
submission API. Final API naming, registration conveniences and structured
failure envelopes must preserve the accepted transaction contract.

## Evidence

See [results.md](results.md) for the captured run. The checks cover:

- JSON, XML property-list and binary property-list bytes with the same host intent fingerprint and
  distinct stored-byte integrity values;
- actor-owned domain state, independent command/effect payloads, compensation,
  Accepted/Rejected/Unresolved protocol outcomes and explicit outcome lookup;
- a host custom format for a non-Codable command containing coordinated changes;
- unknown schemas/codecs, malformed JSON/XML/binary-plist/custom data, corrupt integrity,
  illustrative size refusal and absent/duplicate registrations;
- no semantic handler invocation for invalid inputs;
- display metadata whose contents the module cannot interpret;
- fresh-process reconstruction of registrations, older-version decoding without
  rewriting source bytes, and inspection without domain changes;
- host-owned resource lookup by store/object identities, missing-resource failure,
  and a module-owned fixture loaded through SwiftPM's resource bundle; and
- an expected compiler rejection when a mutable domain object is passed directly
  across actors and then reused.

The 4096-byte payload bound is solely a fixture boundary; it is not a production
recommendation. #46 still owns measured limits.

## Findings and constraints

The proposed separation works without making every host value Sendable or
teaching the core about text, recipes or folder membership. A host can own all
semantic behavior while the framework owns its protocol and history structure.
The visible adapter includes domain effect/compensation logic, codecs and receipt
fixtures; these examples are not a claim that production host integration is
free or already minimal.

XML and binary property lists worked with Foundation's encoder and decoder. This establishes
optional Codable codecs, not an arbitrary XML-schema implementation or Folio
archival XML. The JSON helper rejected non-finite floating point by default;
codec profiles must document their supported values and settings. Custom codecs
remain available for different requirements. None of these serialization formats is
promised to provide canonical semantic identity.

The probe currently carries generic `throws` across the endpoint for convenience.
Production must classify pre-invocation failures and reconcile any exception
after possible host delivery under #41; a thrown callback must never be interpreted
as proof of no domain effect. Likewise, the probe does not enforce durable Command
identity/retry binding, serialize reentrant actor calls, or finalize accepted
outcomes. Those omissions are deliberate and must not be copied as engine behavior.

The small sample encoded to 42 JSON bytes, 281 XML property-list bytes, and 83
binary property-list bytes. This is one footprint observation, not a performance
benchmark or evidence that one representation is universally smaller. #46 must
measure representative payloads before selecting efficiency recommendations.

## Evidence limits

No Core Data history model or real application resource model was created; bundle
lookup uses a clearly named fixture. The run does not prove a production store,
FIFO or backpressure, crash/restart recovery, actual app integration, native Undo
routing, state reconstruction, protection during pruning, recovery-plan lifetime,
complete generic API design, performance, or runtime compatibility on macOS 14
or Intel. Property-list round trips cover the representative fixture, not all Codable shapes.

#44–#50 retain their design and proof responsibilities. The maintainer accepted
the interface design and its evidence limits; #43 records that design resolution. Production source and the main checkout
remain unchanged by this prototype.
