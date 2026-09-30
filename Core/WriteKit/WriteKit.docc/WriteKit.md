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

Create and use the editor on the main actor. Supply the document's undo manager so native typing and semantic formatting share its undo history.

```swift
let work = Work()
let editor = ManuscriptViewController.make(work: work, undoManager: document.undoManager!)
editor.workDidChange = { [weak document] in document?.updateChangeCount(.changeDone) }
let windowController = editor.makeWindowController()
document.addWindowController(windowController)
```

The editor loads its interface from WriteKit's bundled `Editor.storyboard`; the host does not provide a storyboard or construct the controls. The host supplies saving and edited-state tracking through ``ManuscriptViewController/workDidChange``. Capture the host weakly in that callback. For native saving, prepare a separate empty package with ``Work/stageSave(from:toEmptyPackageAt:)`` and let the document host complete safe replacement. The original must be a closed package; preparation never writes into it. Reopen with ``Work/init(contentsOf:)``. ``Work/fileWrapper()`` remains a complete in-memory serialization convenience, rather than the incremental native-save path. A document host passes one `UndoManager` to all editors in a Work.

The editor and host menus use ``FormattingImages`` for the semantic Emphasis symbols. The images live in WriteKit's asset catalog, so a host should request them through this API when configuring its own menu items.

### Formatting behavior

The italic E and bold E toolbar controls apply semantic Emphasis and Strong Emphasis. Option-click applies explicit Italic or Bold. The Format menu provides the same actions: Command-I/B applies semantic formatting, and Option-Command-I/B applies explicit formatting. Clear Formatting removes semantic and explicit character formatting while preserving paragraph alignment.

The Appearance popover provides independent Bold, Italic, Underline, and Strikethrough controls with on, off, and mixed states. Strikethrough preserves authored text and does not create a Proposed Revision. Formatting presentation survives native saving and internal copy/paste.

Semantic Emphasis is exclusive: None, Emphasis, Strong Emphasis, or Very Strong Emphasis. Explicit presentation survives semantic changes. Conflicting Bold/Italic presentation receives temporary highlighting and an inline warning. Conversion preserves words and decorations; dismissal is stored per Content Unit and can be undone. These diagnostics are editor-only and do not become authored text.

## Public interface and hosting

Swift callers import `WriteKit` and `FolioKit`. The Work's ``Work/manuscript`` and ``Work/text`` properties use native FolioKit values, including stable identifiers, paragraphs, runs, semantic emphasis, and explicit presentation. Apps and Kits ship as a coordinated Suite version; mixed versions are unsupported, and independent binary compatibility is not promised.

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

The text-only WorkV1 schema remains supported. Existing package readers still
reject unknown structure rather than dropping it on the next save.

## Opaque resources and compatibility

New and existing text-only Works retain package V1 until a host explicitly calls
``Work/upgradeStorage()``. ``Work/importResource(from:)`` requires that opt-in;
the pending change reaches the native package only after successful saving.
The authored Core Data model remains WorkV1.

Package V2 declares a bounded resource manifest alongside the store and immutable
resource files, with at most 4,096 resources and a 4 MiB manifest. ``Work/resources`` describes them; use
``Work/exportResource(withIdentifier:to:)`` to obtain an independent copy.
``Work/removeResource(withIdentifier:)`` changes the pending collection. These
operations attach no publication meaning to the bytes.

Use ``Work/init(contentsOf:)`` for native opening with large resources. The
FileWrapper convenience is still available when a complete in-memory package
is appropriate. Resource-capable UI must obtain explicit upgrade consent and
allow users to retain V1 editing or cancel; the existing editor has no resource
import command.
