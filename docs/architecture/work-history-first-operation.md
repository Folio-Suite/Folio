<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# First durable Work history operation

This slice gives a Work one history operation: replace a settled Manuscript snapshot with another. It covers text, presentation, Content Unit titles and order, and the current formatting warning flags because those values belong to the Manuscript snapshot. `Work` exposes `enableHistory()` and a `history` session; the Write host settles native editing, submits the resulting Manuscript through `WorkHistorySession.submit(manuscript:)`, and refreshes its views after an accepted outcome. `undo()` and `redo()` use the same host acceptance path. Native routing for existing Manuscript edits belongs to this slice; signed AppKit interaction remains a distinct acceptance check.

## Ownership and delivery

`Core/WriteKit/Interface/WorkHistorySession.swift` is the public host session. Its typed handler lives in `Core/WriteKit/Modules/WorkAdapter/WorkHistoryAdapter.swift`, which builds a `HistoryOperationRegistration` for complete Manuscript replacements. The registration supplies stable command/effect/state codec identities and versions; UndoKit adds codec envelopes to produce opaque `HistoryPayload` values. `WorkHistoryPayload.swift` defines the host representation. UndoKit owns preparation, serialized delivery, the history graph, availability, and finalization. WriteKit owns the meaning and validation of a replacement, no-op filtering, compensation data, and the authoritative accepted or rejected outcome. Neither framework stores the other's managed objects.

An enabled Work has a private working directory containing `Host/Work.sqlite` and `History.sqlite`. Enabling history on a new Work creates the host SQLite store from its current Manuscript. A saved Work without history retains a private clone of its original store; enabling history updates that clone while preserving its store and object identities. Opening a saved Work with history copies its closed host store and history store into that directory and assigns a fresh working identity. The saved package remains the source snapshot until a later successful document save. `WorkHistorySession` holds the last host-accepted Manuscript separately from provisional edits. A submission whose decoded `before` state does not match that committed state is rejected without changing authored data. Each command has an identity and a fingerprint; the adapter records a compact host receipt in the Work store for outcome lookup.

`Core/WriteKit/Modules/WorkAdapter/WorkStore+HistoryReceipts.swift` writes the Manuscript change and the command receipt with **one Core Data context save**. The receipt stores command identity, fingerprint binding, accepted status, and bounded encoded effect evidence. A duplicate identity or failed validation leaves no new semantic change. A callback error or a missing receipt means the outcome is unresolved; it does not establish rejection. Reconciliation looks up the host receipt, checks the token binding and evidence, and reads the authoritative host snapshot while preserving any newer provisional input for resubmission. UndoKit's history store is separate, so this receipt is the bridge across an interrupted finalization rather than a distributed transaction.

## Native editing route

Write uses a document-scoped `UndoManager` subclass from `NativeHistoryRouter` as the text view's actual manager, so AppKit continues to register typing and formatting edits and coalesce provisional typing. The host breaks that coalescing and captures a full Manuscript snapshot at explicit Undo, save, selection, formatting, and structural boundaries. Closing an AppKit undo group is only evidence that registrations occurred: a text view can coalesce one edit across several run-loop groups. An unexplained registration pauses semantic Undo until the host reconciles it. Undo and Redo requests follow the ordered asynchronous history route; a pending reversal blocks further semantic edits. The document change count advances only after the host's authoritative outcome. Automatic saves wait for one second of idle typing before settlement; explicit Save and Undo settle immediately. This keeps an early NSDocument autosave from splitting the first character out of a native typing group. Edit > History forwards through the active editor to the owning Write document.

The signed Write document tests exercise settled typing, save/reopen, Undo/Redo, formatting, structure, corrected input after capacity refusal, autosave and failed-save retry. Public Work tests cover checkpoint restoration, displaced history, resources, temporary imports and missing-history refusal. Foreground Write UI tests cover the menu action and native responder behavior. These checks cover the first operation, not every composition, focus or scale scenario in the broader accepted design.

## Saving and reopening

The current native package keeps `Work.sqlite` at its root. A history-enabled package also has `History/History.sqlite` and `History/Registration.plist`; its `Package.json` declares the required `durable-history-v1` capability alongside the existing resource capability. The registration binds a Work identifier, history scope, and saved working identity. Unknown package members, unsupported capability declarations, and malformed registration are refused on open.

`Work.stageSave(from:toEmptyPackageAt:)` delegates to the session when history is enabled. The session stages the closed private host store through WriteKit's usual clone-or-copy save path, copies a consistent history-store snapshot, writes the registration, and marks the package capability. The staged package is prepared for NSDocument's safe replacement; preparation does not rewrite the original package. Save eligibility requires a finalized, unsuspended history and agreement between the visible Manuscript and the host-accepted Manuscript. Reopening reads the authored snapshot from the host store and opens UndoKit against the copied history store so it can reconcile any retained pending transaction before editing resumes.

## Checkpoints and scope

`createCheckpoint(name:)` records the current host Manuscript as a named recoverable state. `checkpoints(limit:)` returns bounded metadata for presentation. `restore(checkpointID:)` decodes the saved state and submits a new replacement command with the checkpoint as its restoration origin. The displaced continuation stays in the history graph; restoration does not erase it. Ordinary history browsing is likewise bounded and does not reconstruct every old Manuscript.

The resource set is preserved when saving a history-enabled Work, but resource import and removal are blocked for this first operation. Resource changes need their own semantic command and recovery evidence before they can join durable history. The current adapter does not claim durable operations for Source Libraries or Arrangements, cross-application Work Sessions, automation, archival folio reconstruction, or production release readiness. Its current storage schema and package capability are pre-alpha implementation choices, not a Folio 1.0 format promise. Broader behavior remains governed by [the semantic history contract](semantic-history-contract.md) and [UndoKit's acceptance contract](../../UndoKit/docs/durable-acceptance-contract.md).

## Successors

Further accepted capabilities outside this operation are tracked separately:

- [#92 — Store registration, multiple scopes and recovery lifecycle](https://github.com/Folio-Suite/Folio/issues/92).
- [#93 — Retention holds, pruning and consolidation](https://github.com/Folio-Suite/Folio/issues/93).
- [#94 — Paged reconstruction and host metadata, including persisted action names](https://github.com/Folio-Suite/Folio/issues/94).
- [#95 — Recording controls and explicit generation reset](https://github.com/Folio-Suite/Folio/issues/95).
- [#96 — Durable Work resource commands](https://github.com/Folio-Suite/Folio/issues/96).
- [#97 — Interrupted working-copy discovery and native Versions restoration](https://github.com/Folio-Suite/Folio/issues/97).

The first Write host uses generic Undo/Redo names and always records settled Manuscript edits. It refuses ordinary read/adopt replacement of an already history-enabled Work until restoration can retain the displaced continuation. Unresolved private copies remain available on disk; automatic discovery after a process interruption belongs to #97. UndoKit continues to extend native UndoManager grouping and routing; these successors do not transfer host semantics or document saving into the framework.
