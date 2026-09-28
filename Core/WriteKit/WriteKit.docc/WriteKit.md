# ``WriteKit``

<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

Write's Work model, native editor, and persistence boundary.

## Overview

WriteKit owns supported Work and Manuscript behavior, private Core Data package persistence, and reusable AppKit editing. The Write application hosts the document lifecycle, saving, and the document's shared undo manager.

## Current support

``Work`` reads and writes the current native Core Data package and owns a FolioKit ``Manuscript`` value. A Manuscript contains a flat, ordered list of text Content Units. ``ManuscriptViewController`` provides a sidebar and retained per-unit editors. ``EditorViewController`` edits text and formatting on the main actor, and routes native typing and semantic formatting through the host's undo manager.

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

The editor loads its interface from WriteKit's bundled `Editor.storyboard`; the host does not provide a storyboard or construct the controls. The host supplies saving and edited-state tracking through ``ManuscriptViewController/workDidChange``. Capture the host weakly in that callback. Save with ``Work/fileWrapper()`` and handle the thrown error; producing an in-memory package does not write a destination file. Reopen with ``Work/init(fileWrapper:)``. A document host passes one `UndoManager` to all editors in a Work.

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
