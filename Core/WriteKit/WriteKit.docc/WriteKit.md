# ``WriteKit``

<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

Write's Work model, native editor, and persistence boundary.

## Overview

WriteKit owns supported Work and Manuscript behavior, private Core Data package persistence, and reusable AppKit editing. The Write application hosts the document lifecycle, saving, and the document's shared undo manager.

## Current support

``Work`` reads and writes the current native Core Data package and owns a FolioKit `Manuscript` value. A Manuscript contains a flat, ordered list of text Content Units. ``ManuscriptViewController`` provides a sidebar and retained per-unit editors. ``EditorViewController`` edits text and formatting on the main actor, and routes native typing and semantic formatting through the host's undo manager.

The editor supports semantic emphasis categories separately from explicit bold, italic, underline, and strikethrough. It provides formatting-conflict warnings, conversion and dismissal actions, and internal copy/paste that preserves supported formatting with independent text identities. External paste imports plain text.

### Embed the Manuscript editor

Create and use the editor on the main actor. Supply one `UndoManager` to all editors in a Work through ``ManuscriptViewController/make(work:undoManager:)``. The editor loads `Editor.storyboard` from WriteKit's bundle; its window factory supplies the reusable window and controls.

For durable hosting, use `NativeHistoryRouter.undoManager` and implement the settlement and accepted-outcome callbacks described below. `workDidChange` reports provisional input; it must not immediately advance the document's authoritative change count. Keep the provisional manager separate from NSDocument's automatic counting. The Write application's `WriteDocument` is the complete native host example.

For native saving, prepare a separate empty package with ``Work/stageSave(from:toEmptyPackageAt:omittingHistory:)`` and let the document host complete safe replacement. The original must be a closed package; preparation never writes into it. Reopen with ``Work/init(contentsOf:)``. ``Work/fileWrapper()`` provides complete in-memory serialization. Durable hosts must finish opening, settle input and finalize pending history before either save path.

To save without retained history, call
`WorkHistorySession.beginOmissionPublication()` after settling edits, then pass
`omittingHistory: true` while staging. The publication token fences new edits and
Undo until the save outcome is known. The
staged package keeps the current Work and resources, omits `History/` and removes
obsolete host history receipts from `Work.sqlite`. Keep live Undo until the host
confirms successful safe replacement, then call
`WorkHistorySession.completeOmissionAfterSave(_:)` with the token. On failed
staging or publication, call `cancelOmissionPublication(_:)` to restore live
Undo; the original remains intact. If post-publication reset or receipt cleanup
fails, the session stays fenced; retry completion with
`pendingOmissionPublication`. Write's `WriteDocument.saveOmittingHistory` and
`retryPublishedHistoryOmission` show the native save boundary.

The editor and host menus use ``FormattingImages`` for the semantic Emphasis symbols. The images live in WriteKit's asset catalog, so a host should request them through this API when configuring its own menu items.

### Formatting behavior

The italic E and bold E toolbar controls apply semantic Emphasis and Strong Emphasis. Option-click applies explicit Italic or Bold. The Format menu provides the same actions: Command-I/B applies semantic formatting, and Option-Command-I/B applies explicit formatting. Clear Formatting removes semantic and explicit character formatting while preserving paragraph alignment.

The Appearance popover provides independent Bold, Italic, Underline, and Strikethrough controls with on, off, and mixed states. Strikethrough preserves authored text and does not create a Proposed Revision. Formatting presentation survives native saving and internal copy/paste.

Semantic Emphasis is exclusive: None, Emphasis, Strong Emphasis, or Very Strong Emphasis. Explicit presentation survives semantic changes. Conflicting Bold/Italic presentation receives temporary highlighting and an inline warning. Conversion preserves words and decorations; dismissal is stored per Content Unit and can be undone. These diagnostics are editor-only and do not become authored text.

## Public interface and hosting

Swift callers import `WriteKit` and `FolioKit`. The Work's ``Work/manuscript`` and ``Work/text`` properties use native FolioKit values, including stable identifiers, paragraphs, runs, semantic emphasis, and explicit presentation. Apps and Kits ship as a coordinated Suite version; mixed versions are unsupported, and independent binary compatibility is not promised.

### Source map

The public declarations live in `Interface/`:

- `Work.swift` — Work identity, Manuscript access, persistence, resources, and save reports.
- `WorkHistorySession.swift` and `WorkHistorySession+Operations.swift` — durable
  history errors, checkpoints, and Work history session operations.
- `WorkHistoryMenuController.swift` — the native checkpoint menu.
- `ManuscriptViewController.swift` — the Manuscript sidebar and editor host.
- `EditorViewController.swift` and its `+Manuscript` and `+Formatting` extensions —
  the single Content Unit editor, native editing delegates, and formatting actions.
- `FormattingImages.swift` — semantic formatting menu images.

Implementation details are grouped in `Modules/Editor/`, `Modules/Manuscript/`,
and `Modules/WorkAdapter/`; resources are collected in `Resources/`.

## Limitations

The Manuscript supports a flat list of text Content Units. Adding, renaming, and reordering are undoable; selection is transient. Nested and unplaced units are unsupported. The host must resolve pending edits and manage undo history before replacing a Work. The current in-process package adapter does not provide shared Work Session recovery or archival folio export. The interface is evolving and has no independent compatibility guarantee.

## Topics

### Authoring

- ``Work``
- ``EditorViewController``
- ``ManuscriptViewController``
- ``FormattingImages``

## Incremental native saving

The staging operation reuses a closed Core Data store and reconciles authored
identities and order. It updates changed values and relationships without
reinserting unaffected paragraphs or Content Units. The returned save report
records changed content and logical bytes cloned or copied. Successful filesystem
cloning avoids copying unchanged file data; a supported copy fallback preserves
correctness on other volumes.

Preparation does not mark an NSDocument clean or acknowledge final replacement.
Use the advanced NSDocument write hook so AppKit retains responsibility for
safe replacement, Auto Save, native Versions and change counts. A failed
preparation leaves the original package and the Work's pending edits available
for retry. Never pass the original itself or a directory inside it as staging.

Readers validate the single current pre-alpha schema and reject unknown
structure rather than dropping it on the next save.

## Opaque resources

Every Work supports opaque resources from creation. ``Work/importResource(from:)``
adds immutable retained bytes; the pending change reaches the native package
only after successful saving. There is one current storage model and no upgrade
API or legacy package mode.

The package declares a bounded resource manifest alongside the store and immutable
resource files, with at most 4,096 resources and a 4 MiB manifest.
``Work/resources`` describes them; use
``Work/exportResource(withIdentifier:to:)`` to obtain an independent copy.
``Work/removeResource(withIdentifier:)`` changes the pending collection. These
operations attach no publication meaning to the bytes.

Use ``Work/init(contentsOf:)`` for native opening with large resources. The
FileWrapper convenience is available when a complete in-memory package is
appropriate. The existing editor has no resource import command.

## Durable manuscript history

``Work/enableHistory()`` creates a ``WorkHistorySession`` for the current Work.
The session translates complete, settled Manuscript edits into UndoKit commands.
It owns semantic validation and writes a command receipt in the same Core Data
transaction as the authored change. UndoKit owns transaction ordering, history
relationships, and recovery. The implementation files live in `Modules/WorkAdapter/`;
no Folio value types enter UndoKit.

```swift
let history = try work.enableHistory()
try await history.reconcile()
try await history.submit(manuscript: editedManuscript)
// Settle all native editing and await submissions before native Save.
try await history.undo()
try await history.redo()
```

`submit` filters known no-ops. The host must serialize its intended edit order;
concurrent independent submissions cannot infer each other's intended prior state.
The Work's public Manuscript may contain provisional native input. The session's
``WorkHistorySession/committedManuscript`` identifies authoritative accepted state.
Saving refuses pending, suspended, or unsettled work. After reopening, await
``WorkHistorySession/reconcile()`` before enabling native history commands.
Attachment does not replay edits or mark the document changed.

`WorkHistorySession.setRecording(_:)` selects On or Off for new ordinary edits.
Off keeps Undo in this open session; the first accepted Off edit creates a gap
to older Undo. Turning On records the accepted current Manuscript as a new
baseline. For a failed outcome that cannot be reconciled, the host can establish
its coherent current Manuscript and call
`WorkHistorySession.resetUnresolvedHistory(adopting:quarantineAt:)`. The method
quarantines failed evidence before installing a new generation. Native hosts use
`WorkHistorySession.availability` for exact scope, generation and version, then
explicitly attach the router after a reset.
Recording preference belongs to the host. An omitted saved Work has no History
store to carry that preference, so the host persists its app or per-Work policy
separately and reapplies it when enabling history after reopening. Suite settings
UI and policy storage are separate work.

A checkpoint captures the complete supported Manuscript. The host must save the
document successfully before announcing a saved checkpoint. Restoring a checkpoint
submits a new edit: restoring A after A → B → C makes ordinary Undo return to C.
``WorkHistoryMenuController`` supplies a bounded dynamic checkpoint menu; its host
provides native saving and error presentation. Larger host interfaces can use
``WorkHistorySession/checkpoints(limit:)`` without reconstructing content.

This first operation retains every existing resource unchanged. Resource import
and removal are refused while history is enabled, so a checkpoint cannot refer to
an asset that the host has deleted. Resource-changing history, pruning, retention
schedules and cross-process Work Sessions are separate work.
Payloads are bounded complete Manuscript values; this is not a claim that every
large Work edit already uses a minimal text delta.

A history-bearing package declares `durable-history-v1` as a required capability
and includes the history database and registration in `History/`. This is the
first implementation format; it carries no migration or backward-compatibility
promise. Package-definition issue #89 remains deferred.
